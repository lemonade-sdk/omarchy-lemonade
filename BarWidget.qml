import QtQuick
import qs.Ui as Ui

Ui.BarWidget {
    id: root
    moduleName: "io.github.lemonade-sdk.lemonade"
    property var service: null
    readonly property var client: service ? service.client : null
    readonly property bool opened: panel.opened
    readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing

    function bindService() {
        if (!bar || !bar.shell || typeof bar.shell.serviceFor !== "function")
            return;
        var candidate = bar.shell.serviceFor(moduleName);
        if (!candidate && typeof bar.shell.ensureService === "function")
            candidate = bar.shell.ensureService(moduleName);
        service = candidate || null;
        if (service)
            service.settings = settings;
    }
    function open() {
        panel.open();
        if (client)
            client.refresh();
    }
    function close() {
        panel.close();
    }
    function toggle() {
        opened ? close() : open();
    }
    function closeForPopoutSwitch() {
        panel.closeForPopoutSwitch();
    }

    onBarChanged: bindService()
    onSettingsChanged: {
        if (service)
            service.settings = settings;
    }
    Component.onCompleted: bindService()
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Timer {
        interval: 1000
        repeat: true
        running: !root.service && !!root.bar
        onTriggered: root.bindService()
    }
    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.vertical ? "🍋" : "🍋 " + (root.client && root.client.online ? "Lemonade" : "Offline")
        tooltipText: root.client && root.client.online ? "Lemonade " + root.client.health.version + " · " + root.client.loadedModels.length + " loaded" : "Lemonade: " + (root.client ? root.client.error : "connecting")
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.RightButton && root.service)
                root.service.openApp();
            else if (mouseButton === Qt.MiddleButton && root.client)
                root.client.refresh();
            else
                root.toggle();
        }
    }
    Panel {
        id: panel
        bar: root.bar
        service: root.service
        anchorItem: button
        hostWidget: root
    }
}
