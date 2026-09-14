import QtQuick

Item {
    id: root
    property var xhr: null
    readonly property bool busy: xhr !== null
    property int timeoutMs: 10000
    property int responseStatus: 0
    signal finished(var data, string error)

    function cancel() {
        deadline.stop();
        var previous = xhr;
        xhr = null;
        if (previous) {
            previous.onreadystatechange = function () {};
            previous.abort();
        }
    }

    function send(method, url, token, body) {
        cancel();
        responseStatus = 0;
        var request = new XMLHttpRequest();
        xhr = request;
        request.onreadystatechange = function () {
            if (root.xhr !== request || request.readyState !== XMLHttpRequest.DONE)
                return;
            deadline.stop();
            root.responseStatus = request.status;
            root.xhr = null;
            if (request.status < 200 || request.status >= 300) {
                root.finished(null, request.status === 401 || request.status === 403 ? "Authentication failed. Check the API key in the shell environment." : request.status === 0 ? "Cannot reach Lemonade." : "Request failed (HTTP " + request.status + "). Open Lemonade for details.");
                return;
            }
            var data;
            try {
                data = JSON.parse(request.responseText);
            } catch (error) {
                root.finished(null, "Server returned invalid JSON.");
                return;
            }
            root.finished(data, "");
        };
        try {
            request.open(method, url);
            request.setRequestHeader("Accept", "application/json");
            if (token)
                request.setRequestHeader("Authorization", "Bearer " + token);
            if (body !== undefined && body !== null)
                request.setRequestHeader("Content-Type", "application/json");
            deadline.restart();
            request.send(body === undefined || body === null ? "" : JSON.stringify(body));
        } catch (error) {
            cancel();
            finished(null, "Could not send request. Check the connection settings.");
        }
    }

    Timer {
        id: deadline
        interval: root.timeoutMs
        onTriggered: {
            root.cancel();
            root.finished(null, "Request timed out. The server may still be processing it; refresh before retrying.");
        }
    }
    Component.onDestruction: cancel()
}
