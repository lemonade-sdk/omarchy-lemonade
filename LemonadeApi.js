function baseUrl(value) {
    var url = String(value || "").trim().replace(/\/+$/, "");
    if (!/^https?:\/\/[^\s/?#@]+(?:\/[^\s?#]*)?$/.test(url))
        throw new Error("Set baseUrl to an HTTP(S) server URL without credentials, query, or fragment.");
    return url.replace(/\/(?:api\/)?v[01]$/, "");
}

// A response that parses is still untrusted: bound how much of it reaches QML.
var MAX_VERSION_LENGTH = 64;
var MAX_NAME_LENGTH = 256;
var MAX_LOADED_MODELS = 100;
var MAX_MODELS = 2000;

function named(value, limit) {
    return typeof value === "string" && value.length > 0 && value.length <= limit;
}

function health(value) {
    if (!value || value.status !== "ok" || !named(value.version, MAX_VERSION_LENGTH)
            || !Array.isArray(value.all_models_loaded)
            || value.all_models_loaded.length > MAX_LOADED_MODELS
            || value.all_models_loaded.some(function(model) {
                return !model || !named(model.model_name, MAX_NAME_LENGTH);
            }))
        throw new Error("Unexpected Lemonade health response.");
    return value;
}

function models(value) {
    if (!value || !Array.isArray(value.data) || value.data.length > MAX_MODELS
            || value.data.some(function(model) { return !model || !named(model.id, MAX_NAME_LENGTH); }))
        throw new Error("Unexpected Lemonade models response.");
    return value.data;
}

function releaseTag(value) {
    if (!value || value.prerelease || value.draft || !named(value.tag_name, MAX_VERSION_LENGTH))
        return "";
    return value.tag_name;
}

function newerVersion(latest, installed) {
    var pattern = /^v?(\d+)\.(\d+)\.(\d+)$/;
    var a = pattern.exec(latest);
    var b = pattern.exec(installed);
    if (!a || !b) return false;
    for (var i = 1; i <= 3; i++) {
        if (Number(a[i]) !== Number(b[i])) return Number(a[i]) > Number(b[i]);
    }
    return false;
}
