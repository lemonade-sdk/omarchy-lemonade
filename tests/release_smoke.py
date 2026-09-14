import hashlib
import json
import os
import platform
import re
import subprocess
import tarfile
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

from live import main as test_live


def main():
    tag = os.environ["LEMONADE_RELEASE"]
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Expected a stable release tag")
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "omarchy-lemonade-ci",
    }
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    request = urllib.request.Request(
        f"https://api.github.com/repos/lemonade-sdk/lemonade/releases/tags/{tag}",
        headers=headers,
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    assert not release["draft"] and not release["prerelease"]
    system = (
        "windows-x64.zip" if platform.system() == "Windows" else "ubuntu-x64.tar.gz"
    )
    asset_name = f"lemonade-embeddable-{tag[1:]}-{system}"
    asset = next(asset for asset in release["assets"] if asset["name"] == asset_name)
    digest = asset.get("digest", "")
    if not digest or not digest.startswith("sha256:"):
        raise RuntimeError("Release asset lacks a SHA-256 digest")
    results = Path(".test-results")
    results.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="omarchy-lemonade-") as directory:
        folder = Path(directory)
        archive = folder / asset_name
        with urllib.request.urlopen(
            asset["browser_download_url"], timeout=120
        ) as response:
            with archive.open("wb") as target:
                while chunk := response.read(1024 * 1024):
                    target.write(chunk)
        with archive.open("rb") as source:
            assert (
                hashlib.file_digest(source, "sha256").hexdigest() == digest[7:]
            ), "Release asset checksum mismatch"
        extracted = folder / "release"
        if system.endswith(".zip"):
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(extracted)
        else:
            with tarfile.open(archive) as bundle:
                bundle.extractall(extracted, filter="data")
        binary = next(
            extracted.rglob(
                "lemond.exe" if platform.system() == "Windows" else "lemond"
            )
        )
        cache = folder / "cache"
        config = folder / "config"
        cache.mkdir()
        config.mkdir()
        with (results / "lemond.log").open("w", encoding="utf-8") as log:
            server = subprocess.Popen(
                [
                    str(binary),
                    str(cache),
                    str(config),
                    "--host",
                    "127.0.0.1",
                    "--port",
                    "13389",
                ],
                stdout=log,
                stderr=subprocess.STDOUT,
            )
            try:
                for _ in range(60):
                    if server.poll() is not None:
                        raise RuntimeError("Release server exited; see lemond.log")
                    try:
                        request = urllib.request.Request(
                            os.environ["LEMONADE_URL"] + "/v1/health",
                            headers={
                                "Authorization": "Bearer "
                                + os.environ["LEMONADE_API_KEY"]
                            },
                        )
                        with urllib.request.urlopen(request, timeout=1):
                            break
                    except (OSError, TimeoutError):
                        time.sleep(1)
                else:
                    raise RuntimeError("Release server did not start")
                test_live()
            finally:
                server.terminate()
                try:
                    server.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()


if __name__ == "__main__":
    main()
