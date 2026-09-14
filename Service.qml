import QtQuick
import Quickshell
import Quickshell.Io
import "LemonadeApi.js" as Api
import "Onboarding.js" as Onboarding

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var settings: null
    readonly property alias client: client
    readonly property string pluginId: "io.github.lemonade-sdk.lemonade"
    property var localInstallation: null
    property string setupMessage: ""
    property string settingsError: ""
    readonly property string normalizedUrl: {
        try {
            return Api.baseUrl(client.baseUrl);
        } catch (error) {
            return "";
        }
    }
    readonly property string setupState: Onboarding.state(normalizedUrl, client.online, client.healthChecked, client.healthStatus, localInstallation)
    readonly property string setupDescription: Onboarding.message(setupState)
    readonly property bool setupBusy: setupCooldown.running
    readonly property string setupScript: decodeURIComponent(Qt.resolvedUrl("scripts/local-server.sh").toString().replace(/^file:\/\//, ""))

    function probeLocal() {
        if (Onboarding.localEndpoint(normalizedUrl) && !client.online && !probe.running)
            probe.running = true;
    }

    function beginSetup() {
        if (setupBusy || (setupState !== "install" && setupState !== "start"))
            return;
        Quickshell.execDetached(["omarchy-launch-terminal", "bash", setupScript, setupState]);
        setupCooldown.restart();
        setupMessage = "Complete setup in the terminal, then press R to refresh.";
    }

    function saveConnection(url, keyVariable) {
        try {
            var next = Onboarding.connectionSettings(settings, Api.baseUrl(url), keyVariable);
            if (JSON.stringify(next) !== JSON.stringify(settings || {}) && (!shell || typeof shell.updateEntryInline !== "function" || !shell.updateEntryInline(pluginId, next)))
                throw new Error("Could not save settings through Omarchy. Try reopening the panel.");
            settingsError = "";
            settings = next;
            client.refresh();
            setupMessage = "";
            localInstallation = null;
            Qt.callLater(probeLocal);
            return true;
        } catch (error) {
            settingsError = error.message;
            return false;
        }
    }

    function refresh() {
        client.refresh();
        probeLocal();
    }

    onNormalizedUrlChanged: {
        localInstallation = null;
        Qt.callLater(probeLocal);
    }
    onSettingsChanged: Qt.callLater(probeLocal)

    Timer {
        id: setupCooldown
        interval: 3000
    }
    Timer {
        interval: 15000
        running: root.settings !== null && !client.online && Onboarding.localEndpoint(root.normalizedUrl)
        repeat: true
        onTriggered: root.probeLocal()
    }
    Process {
        id: probe
        command: ["timeout", "5", "bash", root.setupScript, "probe"]
        stdout: StdioCollector {
            id: probeOutput
        }
        onExited: function (code, status) {
            try {
                if (code !== 0)
                    throw new Error("Could not check the local installation. Press R to retry.");
                root.localInstallation = JSON.parse(probeOutput.text);
            } catch (error) {
                root.setupMessage = error.message;
            }
        }
    }

    Controller {
        id: client
        active: root.settings !== null
        baseUrl: root.settings && root.settings.baseUrl ? String(root.settings.baseUrl) : "http://localhost:13305"
        apiKey: root.settings && root.settings.apiKeyEnv ? Quickshell.env(String(root.settings.apiKeyEnv)) || "" : Quickshell.env("LEMONADE_ADMIN_API_KEY") || Quickshell.env("LEMONADE_API_KEY") || ""
        pollSeconds: root.settings && Number(root.settings.pollSeconds) > 0 ? Number(root.settings.pollSeconds) : 15
        checkUpdates: !root.settings || root.settings.checkUpdates !== false
        onOnlineChanged: if (online)
            root.setupMessage = ""
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
            root.refresh();
        }
        function status(): string {
            return JSON.stringify({
                online: client.online,
                version: client.health ? client.health.version : "",
                loadedModels: client.loadedModels.map(function (model) {
                    return model.model_name;
                }),
                error: client.error,
                busy: client.busy,
                setupState: root.setupState
            });
        }
    }
}
