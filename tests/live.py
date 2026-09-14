import os
import re

from qml_client import Client


def main():
    expected = os.environ["LEMONADE_RELEASE"].removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", expected):
        raise ValueError("LEMONADE_RELEASE must identify a stable release")
    client = Client(os.environ.get("LEMONADE_URL", "http://localhost:13305"),
                    os.environ.get("LEMONADE_API_KEY", ""), timeout_ms=10000)
    model = os.environ.get("LEMONADE_TEST_MODEL", "")
    loaded_here = False
    try:
        client.start()
        assert client.get("online"), client.get("error")
        assert client.get("health")["version"].removeprefix("v") == expected, "Runner is not using the requested Lemonade release"
        assert not client.get("actionError"), client.get("actionError")
        assert not client.get("modelsError"), client.get("modelsError")
        if model:
            assert any(item["id"] == model for item in client.get("models")), "Provision the test model through Lemonade before running"
            assert not client.get("loadedModels"), "Use an idle, dedicated test server"
            loaded_here = True
            client.call("changeModel", "load", model)
            client.wait(lambda: not client.get("busy"), timeout=330)
            client.wait(lambda: not client.get("refreshing"))
            assert not client.get("actionError"), client.get("actionError")
            loaded = client.get("loadedModels")
            assert any(item["model_name"] == model for item in loaded), "Model not reflected in the plugin"
            device = os.environ.get("LEMONADE_TEST_DEVICE", "")
            if device:
                assert any(item["model_name"] == model and device in item.get("device", "").split() for item in loaded), "Expected accelerator was not reported"
        print(f"QML client compatible with Lemonade {expected}; model={model or '(API only)'}")
    finally:
        if loaded_here:
            client.call("changeModel", "unload", model)
            client.wait(lambda: not client.get("busy"), timeout=330)
            client.wait(lambda: not client.get("refreshing"))
            assert not client.get("actionError"), client.get("actionError")
            assert not any(item["model_name"] == model for item in client.get("loadedModels")), "Test model did not unload"
        client.close()


if __name__ == "__main__":
    main()
