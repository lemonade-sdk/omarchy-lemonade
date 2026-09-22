import QtQuick

Item {
    id: root
    property var xhr: null
    readonly property bool busy: xhr !== null
    property int timeoutMs: 10000
    // Content-Length is compared in bytes; the streaming guard counts responseText
    // characters, which is what actually grows in memory as the body arrives.
    property int maxResponseBytes: 1048576
    property bool overflowed: false
    property int responseStatus: 0
    signal finished(var data, string error)

    function cancel() {
        deadline.stop();
        overflow.stop();
        var previous = xhr;
        xhr = null;
        if (previous) {
            previous.onreadystatechange = function () {};
            previous.abort();
        }
    }

    // Aborting a request from inside its own readyState callback re-enters the
    // object that is still dispatching, so the abort is deferred by one turn.
    function rejectOversized() {
        if (overflowed)
            return;
        overflowed = true;
        overflow.restart();
    }

    function tooLarge(request) {
        return String(request.responseText || "").length > root.maxResponseBytes;
    }

    function send(method, url, token, body) {
        cancel();
        responseStatus = 0;
        overflowed = false;
        var request = new XMLHttpRequest();
        xhr = request;
        request.onreadystatechange = function () {
            if (root.xhr !== request || root.overflowed)
                return;
            if (request.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                if (Number(request.getResponseHeader("Content-Length")) > root.maxResponseBytes)
                    root.rejectOversized();
                return;
            }
            if (request.readyState === XMLHttpRequest.LOADING) {
                if (root.tooLarge(request))
                    root.rejectOversized();
                return;
            }
            if (request.readyState !== XMLHttpRequest.DONE)
                return;
            deadline.stop();
            root.responseStatus = request.status;
            root.xhr = null;
            if (request.status < 200 || request.status >= 300) {
                root.finished(null, request.status === 401 || request.status === 403 ? "Authentication failed. Check the API key in the shell environment." : request.status === 0 ? "Cannot reach Lemonade." : "Request failed (HTTP " + request.status + "). Open Lemonade for details.");
                return;
            }
            if (root.tooLarge(request)) {
                root.finished(null, "Server response is too large.");
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
        id: overflow
        interval: 0
        onTriggered: {
            root.cancel();
            root.finished(null, "Server response is too large.");
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
