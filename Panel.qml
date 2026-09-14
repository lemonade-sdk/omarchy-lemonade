import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.Panel {
    id: root
    moduleName: "io.github.lemonade-sdk.lemonade"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property var service: null
    readonly property var client: service ? service.client : null
    property int selectedIndex: 0
    property bool editingConnection: false
    readonly property var available: client ? client.models : []
    readonly property color foreground: bar ? bar.foreground : Color.foreground

    function activate() {
        if (client && !client.online && service) {
            service.beginSetup();
            return;
        }
        if (!client || selectedIndex < 0 || selectedIndex >= available.length)
            return;
        var name = available[selectedIndex].id;
        client.changeModel(client.isLoaded(name) ? "unload" : "load", name);
    }
    onAvailableChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, available.length - 1))
    onOpenedChanged: if (!opened)
        editingConnection = false

    function editConnection() {
        if (!service)
            return;
        urlField.text = client.baseUrl;
        keyField.text = service.settings && service.settings.apiKeyEnv ? service.settings.apiKeyEnv : "";
        service.settingsError = "";
        editingConnection = true;
        Qt.callLater(function () {
            urlField.forceActiveFocus();
            urlField.selectAll();
        });
    }

    function cancelConnection() {
        editingConnection = false;
        keys.forceActiveFocus();
    }

    function connect() {
        if (service && service.saveConnection(urlField.text, keyField.text))
            cancelConnection();
    }

    component Label: Text {
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }

    Ui.KeyboardPanel {
        id: surface
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keys
        contentWidth: surface.fittedContentWidth(Style.space(380))
        contentHeight: surface.fittedContentHeight(content.implicitHeight)

        Ui.PanelKeyCatcher {
            id: keys
            anchors.fill: parent
            blocked: root.editingConnection
            onCloseRequested: root.close()
            onMoveRequested: function (dx, dy) {
                root.selectedIndex = Math.max(0, Math.min(root.available.length - 1, root.selectedIndex + dy));
                list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            }
            onActivateRequested: root.activate()
            onTextKey: function (text) {
                if (text === "r" && root.service)
                    root.service.refresh();
                if (text === "o" && root.service)
                    root.service.openApp();
                if (text === "c")
                    root.editConnection();
            }
            onTabRequested: function (direction) {
                if (root.bar && typeof root.bar.switchPanelFrom === "function")
                    root.bar.switchPanelFrom(root.hostWidget || root, direction);
            }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(10)
                Label {
                    width: parent.width
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    text: "Lemonade" + (root.client && root.client.online ? " " + root.client.health.version : " · Offline")
                }
                Label {
                    width: parent.width
                    visible: !root.editingConnection && root.client && !root.client.online
                    text: root.service ? root.service.setupDescription : "Connecting…"
                }
                Ui.Button {
                    width: parent.width
                    visible: !root.editingConnection && root.service && (root.service.setupState === "install" || root.service.setupState === "start")
                    enabled: root.service && !root.service.setupBusy
                    text: root.service && root.service.setupState === "install" ? "Install Lemonade" : "Start Lemonade"
                    foreground: root.foreground
                    bordered: true
                    onClicked: root.service.beginSetup()
                }
                Label {
                    width: parent.width
                    visible: !root.editingConnection && text !== ""
                    text: root.service ? root.service.setupMessage : ""
                }
                Column {
                    visible: root.editingConnection
                    width: parent.width
                    spacing: Style.space(8)
                    Label {
                        text: "Server address"
                    }
                    Ui.TextField {
                        id: urlField
                        width: parent.width
                        foreground: root.foreground
                        placeholderText: "http://localhost:13305"
                        onAccepted: root.connect()
                        Keys.onEscapePressed: root.cancelConnection()
                        KeyNavigation.tab: keyField
                    }
                    Label {
                        text: "API key environment variable (optional)"
                    }
                    Ui.TextField {
                        id: keyField
                        width: parent.width
                        foreground: root.foreground
                        placeholderText: "LEMONADE_API_KEY"
                        onAccepted: root.connect()
                        Keys.onEscapePressed: root.cancelConnection()
                        KeyNavigation.tab: connectButton
                    }
                    Label {
                        width: parent.width
                        text: "For authentication, set the key in the shell's environment before starting Omarchy. Enter only the variable name here. Leave blank to use Lemonade's default key variables."
                        font.pixelSize: Style.font.bodySmall
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: root.service ? root.service.settingsError : ""
                    }
                    Ui.Button {
                        id: connectButton
                        width: parent.width
                        text: "Save and connect"
                        foreground: root.foreground
                        bordered: true
                        focusable: true
                        onClicked: root.connect()
                        Keys.onEscapePressed: root.cancelConnection()
                        KeyNavigation.tab: cancelButton
                    }
                    Ui.Button {
                        id: cancelButton
                        width: parent.width
                        text: "Cancel"
                        foreground: root.foreground
                        focusable: true
                        onClicked: root.cancelConnection()
                        Keys.onEscapePressed: root.cancelConnection()
                        KeyNavigation.tab: urlField
                    }
                }
                Label {
                    width: parent.width
                    visible: !root.editingConnection && text !== ""
                    text: !root.client ? "Connecting to the plugin service…" : root.client.error || root.client.actionError || root.client.modelsError || (root.client.busy ? "Waiting for Lemonade…" : "")
                }
                Label {
                    width: parent.width
                    visible: !root.editingConnection && root.client && root.client.updateAvailable
                    text: root.client ? "Lemonade " + root.client.latestVersion + " is available. Update through your package manager." : ""
                }
                Label {
                    width: parent.width
                    visible: !root.editingConnection && root.client && root.client.online && root.available.length === 0
                    text: "No installed models. Open Lemonade to get started."
                }
                ListView {
                    id: list
                    visible: !root.editingConnection && root.client && root.client.online
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(240))
                    clip: true
                    model: root.available
                    currentIndex: root.selectedIndex
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: modelLabel.implicitHeight + Style.space(16)
                        color: index === root.selectedIndex ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
                        Label {
                            id: modelLabel
                            anchors.centerIn: parent
                            width: parent.width - Style.space(16)
                            text: (root.client && root.client.isLoaded(modelData.id) ? "● " : "○ ") + modelData.id
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.client && root.client.online && !root.client.busy
                            onClicked: {
                                root.selectedIndex = index;
                                root.activate();
                            }
                        }
                    }
                }
                Label {
                    width: parent.width
                    visible: !root.editingConnection && root.client && root.client.online
                    text: "Click / Enter: load or unload · R: refresh"
                    font.pixelSize: Style.font.bodySmall
                }
                Ui.Button {
                    width: parent.width
                    visible: !root.editingConnection && root.client && root.client.online
                    text: "Open Lemonade  [O]"
                    foreground: root.foreground
                    bordered: true
                    onClicked: root.service.openApp()
                }
                Ui.Button {
                    width: parent.width
                    visible: !root.editingConnection
                    enabled: !!root.service
                    text: "Connection settings  [C]"
                    foreground: root.foreground
                    onClicked: root.editConnection()
                }
                Ui.Button {
                    width: parent.width
                    visible: !root.editingConnection && root.client && !root.client.online
                    text: "Refresh  [R]"
                    foreground: root.foreground
                    onClicked: root.service.refresh()
                }
            }
        }
    }
}
