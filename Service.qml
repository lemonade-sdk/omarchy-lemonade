import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var settings: null
    readonly property alias client: client
    readonly property string pluginId: "io.github.lemonade-sdk.lemonade"

    Controller {
        id: client
        active: root.settings !== null
        baseUrl: root.settings && root.settings.baseUrl ? String(root.settings.baseUrl) : "http://localhost:13305"
        apiKey: root.settings && root.settings.apiKeyEnv ? Quickshell.env(String(root.settings.apiKeyEnv)) || "" : Quickshell.env("LEMONADE_ADMIN_API_KEY") || Quickshell.env("LEMONADE_API_KEY") || ""
        pollSeconds: root.settings && Number(root.settings.pollSeconds) > 0 ? Number(root.settings.pollSeconds) : 15
        checkUpdates: !root.settings || root.settings.checkUpdates !== false
    }

    function openApp() {
        try {
            Qt.openUrlExternally(client.appUrl());
        } catch (error) {
            client.actionError = error.message;
        }
    }

    IpcHandler {
        target: root.pluginId
        function refresh(): void {
            client.refresh();
        }
        function status(): string {
            return JSON.stringify({
                online: client.online,
                version: client.health ? client.health.version : "",
                loadedModels: client.loadedModels.map(function (model) {
                    return model.model_name;
                }),
                error: client.error,
                busy: client.busy
            });
        }
    }
}
