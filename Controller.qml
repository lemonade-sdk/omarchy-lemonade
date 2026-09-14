import QtQuick
import "LemonadeApi.js" as Api

Item {
    id: root
    property string baseUrl: "http://localhost:13305"
    property string apiKey: ""
    property bool active: false
    property bool checkUpdates: true
    property int pollSeconds: 15
    property int requestTimeoutMs: 10000
    property var health: null
    property var models: []
    property string error: ""
    property string actionError: ""
    property string modelsError: ""
    property string latestVersion: ""
    readonly property bool online: health !== null
    readonly property bool refreshing: healthRequest.busy || modelsRequest.busy
    readonly property bool busy: actionRequest.busy
    readonly property bool updateAvailable: online && Api.newerVersion(latestVersion, health.version)
    readonly property var loadedModels: online ? health.all_models_loaded : []

    function reset() {
        healthRequest.cancel();
        modelsRequest.cancel();
        actionRequest.cancel();
        health = null;
        models = [];
        error = "";
        actionError = "";
        modelsError = "";
        if (active)
            Qt.callLater(refresh);
    }

    function refresh() {
        if (!active || refreshing)
            return;
        var url;
        try {
            url = Api.baseUrl(baseUrl);
        } catch (failure) {
            error = failure.message;
            return;
        }
        healthRequest.send("GET", url + "/v1/health", apiKey, null);
        modelsRequest.send("GET", url + "/v1/models", apiKey, null);
    }

    function isLoaded(name) {
        return loadedModels.some(function (model) {
            return model.model_name === name;
        });
    }

    function changeModel(action, name) {
        if (!active || !online || busy || (action !== "load" && action !== "unload"))
            return;
        if (typeof name !== "string" || !name.length)
            return;
        actionError = "";
        actionRequest.send("POST", Api.baseUrl(baseUrl) + "/v1/" + action, apiKey, {
            model_name: name
        });
    }

    function checkRelease() {
        if (active && checkUpdates && !releaseRequest.busy)
            releaseRequest.send("GET", "https://api.github.com/repos/lemonade-sdk/lemonade/releases/latest", "", null);
    }

    function appUrl() {
        return Api.baseUrl(baseUrl) + "/app";
    }

    onBaseUrlChanged: reset()
    onApiKeyChanged: reset()
    onActiveChanged: {
        reset();
        if (active)
            checkRelease();
        else
            releaseRequest.cancel();
    }
    onCheckUpdatesChanged: {
        if (checkUpdates)
            checkRelease();
        else {
            releaseRequest.cancel();
            latestVersion = "";
        }
    }

    Timer {
        interval: Math.max(5, root.pollSeconds) * 1000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }
    Timer {
        interval: 3600000
        repeat: true
        running: root.active && root.checkUpdates
        onTriggered: root.checkRelease()
    }
    Request {
        id: healthRequest
        timeoutMs: root.requestTimeoutMs
        onFinished: function (data, failure) {
            try {
                if (failure)
                    throw new Error(failure);
                root.health = Api.health(data);
                root.error = "";
            } catch (problem) {
                root.health = null;
                root.error = problem.message;
            }
        }
    }
    Request {
        id: modelsRequest
        timeoutMs: root.requestTimeoutMs
        onFinished: function (data, failure) {
            try {
                if (failure)
                    throw new Error(failure);
                root.models = Api.models(data);
                root.modelsError = "";
            } catch (problem) {
                root.models = [];
                root.modelsError = problem.message;
            }
        }
    }
    Request {
        id: actionRequest
        timeoutMs: 300000
        onFinished: function (data, failure) {
            root.actionError = failure || (data && data.status === "error" ? "Lemonade rejected the operation. Open the app for details." : "");
            healthRequest.cancel();
            modelsRequest.cancel();
            root.refresh();
        }
    }
    Request {
        id: releaseRequest
        onFinished: function (data, failure) {
            if (!failure && data && !data.prerelease && !data.draft && typeof data.tag_name === "string")
                root.latestVersion = data.tag_name;
        }
    }
}
