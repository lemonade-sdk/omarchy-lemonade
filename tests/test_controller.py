import json
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from qml_client import Client


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        self.reply()

    def do_POST(self):
        self.reply()

    def reply(self):
        state = self.server.state
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        state["requests"].append((self.command, self.path, self.headers.get("Authorization"), body))
        code = 200
        if self.headers.get("Authorization") != "Bearer test-key":
            code, result = 401, {"error": "unauthorized"}
        elif self.path == "/v1/health":
            result = {"status": "ok", "version": state["version"],
                      "all_models_loaded": [{"model_name": name} for name in state["loaded"]]}
            if state.get("delay"):
                time.sleep(state["delay"])
            if state.get("invalid"):
                result = {"status": "ok"}
        elif self.path == "/v1/models":
            result = {"data": [{"id": "test-model", "downloaded": True}]}
        elif self.path in ("/v1/load", "/v1/unload"):
            name = json.loads(body)["model_name"]
            if state.get("reject"):
                code, result = 409, {"error": "busy"}
            else:
                state["loaded"] = [name] if self.path == "/v1/load" else []
                result = {"status": "success"}
        else:
            code, result = 404, {}
        payload = b"not json" if state.get("malformed") else json.dumps(result).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.state = {"requests": [], "loaded": [], "version": "11.9.0"}
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.client = Client(f"http://127.0.0.1:{self.server.server_port}", "test-key")

    def tearDown(self):
        self.client.close()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def test_health_and_installed_models(self):
        self.client.start()
        self.assertTrue(self.client.get("online"))
        self.assertEqual(self.client.get("health")["version"], "11.9.0")
        self.assertEqual(self.client.get("models")[0]["id"], "test-model")
        self.assertTrue(all(row[2] == "Bearer test-key" for row in self.server.state["requests"]))

    def test_authentication_failure_and_reconnect(self):
        self.client.set("apiKey", "wrong")
        self.client.start()
        self.assertFalse(self.client.get("online"))
        self.assertIn("Authentication", self.client.get("error"))
        self.client.set("apiKey", "test-key")
        self.client.wait(lambda: self.client.get("online"))

    def test_model_actions_are_forwarded(self):
        self.client.start()
        self.client.call("changeModel", "load", "test-model")
        self.client.wait(lambda: len(self.client.get("loadedModels")) == 1)
        self.client.call("changeModel", "unload", "test-model")
        self.client.wait(lambda: len(self.client.get("loadedModels")) == 0 and not self.client.get("busy"))
        requests = [row for row in self.server.state["requests"] if row[0] == "POST"]
        self.assertEqual([row[1] for row in requests], ["/v1/load", "/v1/unload"])
        self.assertTrue(all(json.loads(row[3]) == {"model_name": "test-model"} for row in requests))

    def test_empty_model_cannot_unload_everything(self):
        self.client.start()
        self.client.call("changeModel", "unload", "")
        self.assertFalse(self.client.get("busy"))
        self.assertFalse(any(row[0] == "POST" for row in self.server.state["requests"]))

    def test_action_failure_remains_visible(self):
        self.client.start()
        self.server.state["reject"] = True
        self.client.call("changeModel", "load", "test-model")
        self.client.wait(lambda: not self.client.get("busy"))
        self.assertIn("409", self.client.get("actionError"))

    def test_timeout_and_recovery(self):
        self.server.state["delay"] = 0.3
        self.client.set("requestTimeoutMs", 50)
        self.client.start()
        self.assertIn("timed out", self.client.get("error"))
        self.server.state["delay"] = 0
        self.client.set("requestTimeoutMs", 1000)
        self.client.call("refresh")
        self.client.wait(lambda: self.client.get("online"))

    def test_invalid_health_contract(self):
        self.server.state["invalid"] = True
        self.client.start()
        self.assertFalse(self.client.get("online"))
        self.assertIn("Unexpected", self.client.get("error"))

    def test_malformed_json(self):
        self.server.state["malformed"] = True
        self.client.start()
        self.assertIn("invalid JSON", self.client.get("error"))

    def test_disabling_cancels_late_response(self):
        self.server.state["delay"] = 0.2
        self.client.set("active", True)
        self.client.wait(lambda: self.client.get("refreshing"))
        self.client.set("active", False)
        time.sleep(0.3)
        self.client.wait(lambda: not self.client.get("refreshing"))
        self.assertFalse(self.client.get("online"))

    def test_url_normalization_and_validation(self):
        url = self.client.get("baseUrl")
        self.client.set("baseUrl", url + "/api/v1/")
        self.client.start()
        self.assertTrue(self.client.get("online"))
        self.client.set("baseUrl", "file:///etc/passwd")
        self.client.wait(lambda: bool(self.client.get("error")))
        self.assertFalse(self.client.get("online"))

    def test_release_comparison(self):
        self.client.start()
        self.client.set("latestVersion", "v11.10.0")
        self.assertTrue(self.client.get("updateAvailable"))
        for version in ("v11.9.0", "v11.8.0", "v11.10.0-rc1", "garbage"):
            self.client.set("latestVersion", version)
            self.assertFalse(self.client.get("updateAvailable"))


if __name__ == "__main__":
    unittest.main()
