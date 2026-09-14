import json
import os
import subprocess
import time
from pathlib import Path

PLUGIN_ID = "io.github.lemonade-sdk.lemonade"
ROOT = Path(__file__).resolve().parents[1]


def run(*argv):
    return subprocess.check_output(argv, text=True, timeout=30).strip()


def wait_online():
    deadline = time.monotonic() + 60
    last = ""
    while time.monotonic() < deadline:
        try:
            last = run("omarchy-shell", PLUGIN_ID, "status")
            state = json.loads(last)
            if state["online"] and state["version"].removeprefix("v") == os.environ[
                "LEMONADE_RELEASE"
            ].removeprefix("v"):
                return state
        except (subprocess.SubprocessError, ValueError, KeyError):
            pass
        time.sleep(1)
    raise AssertionError(
        f"Shell plugin did not connect to the expected release: {last}"
    )


def main():
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    if config.resolve() != (Path.home() / ".config").resolve():
        raise RuntimeError(
            "Omarchy's plugin removal command requires the standard ~/.config location"
        )
    plugins = (config / "omarchy" / "plugins").resolve()
    destination = plugins / PLUGIN_ID
    if destination.exists() or destination.is_symlink():
        raise RuntimeError(
            "Use a dedicated test session without an existing Lemonade plugin"
        )
    run("omarchy-shell", "shell", "ping")
    plugins.mkdir(parents=True, exist_ok=True)
    run("git", "clone", "--no-hardlinks", str(ROOT), str(destination))
    try:
        run("omarchy", "plugin", "validate", str(destination))
        run("omarchy-shell", "shell", "rescanPlugins")
        run("omarchy", "plugin", "enable", PLUGIN_ID)
        run(
            "omarchy",
            "bar",
            "set",
            PLUGIN_ID,
            "baseUrl",
            os.environ.get("LEMONADE_URL", "http://localhost:13305"),
        )
        run("omarchy", "bar", "set", PLUGIN_ID, "checkUpdates", "false", "--json")
        wait_online()
        run("omarchy-shell", "shell", "summon", PLUGIN_ID, "{}")
        run("omarchy-shell", "shell", "hide", PLUGIN_ID)
        run("omarchy", "plugin", "disable", PLUGIN_ID)
        run("omarchy", "plugin", "enable", PLUGIN_ID)
        wait_online()
        print(
            "Omarchy plugin installed, connected, accepted panel IPC, and re-enabled successfully"
        )
    finally:
        run("omarchy", "plugin", "remove", PLUGIN_ID, "--yes")


if __name__ == "__main__":
    main()
