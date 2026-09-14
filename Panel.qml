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
    readonly property var available: client ? client.models : []
    readonly property color foreground: bar ? bar.foreground : Color.foreground

    function activate() {
        if (!client || selectedIndex < 0 || selectedIndex >= available.length)
            return;
        var name = available[selectedIndex].id;
        client.changeModel(client.isLoaded(name) ? "unload" : "load", name);
    }
    onAvailableChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, available.length - 1))

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
            onCloseRequested: root.close()
            onMoveRequested: function (dx, dy) {
                root.selectedIndex = Math.max(0, Math.min(root.available.length - 1, root.selectedIndex + dy));
                list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            }
            onActivateRequested: root.activate()
            onTextKey: function (text) {
                if (text === "r" && root.client)
                    root.client.refresh();
                if (text === "o" && root.service)
                    root.service.openApp();
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
                    visible: text !== ""
                    text: !root.client ? "Connecting to the plugin service…" : root.client.error || root.client.actionError || root.client.modelsError || (root.client.busy ? "Waiting for Lemonade…" : "")
                }
                Label {
                    width: parent.width
                    visible: root.client && root.client.updateAvailable
                    text: root.client ? "Lemonade " + root.client.latestVersion + " is available. Update through your package manager." : ""
                }
                Label {
                    width: parent.width
                    visible: root.client && root.client.online && root.available.length === 0
                    text: "No installed models. Open Lemonade to get started."
                }
                ListView {
                    id: list
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
                    text: "Click / Enter: load or unload · R: refresh"
                    font.pixelSize: Style.font.bodySmall
                }
                Rectangle {
                    width: parent.width
                    height: openLabel.implicitHeight + Style.space(16)
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    Label {
                        id: openLabel
                        anchors.centerIn: parent
                        text: "Open Lemonade  [O]"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !!root.service
                        onClicked: root.service.openApp()
                    }
                }
            }
        }
    }
}
