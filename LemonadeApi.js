function baseUrl(value) {
    var url = String(value || "").trim().replace(/\/+$/, "");
    if (!/^https?:\/\/[^\s/?#@]+(?:\/[^\s?#]*)?$/.test(url))
        throw new Error("Set baseUrl to an HTTP(S) server URL without credentials, query, or fragment.");
    return url.replace(/\/(?:api\/)?v[01]$/, "");
}

function health(value) {
    if (!value || value.status !== "ok" || typeof value.version !== "string"
            || !Array.isArray(value.all_models_loaded))
        throw new Error("Unexpected Lemonade health response.");
    return value;
}

function models(value) {
    if (!value || !Array.isArray(value.data)
            || value.data.some(function(model) { return !model || typeof model.id !== "string"; }))
        throw new Error("Unexpected Lemonade models response.");
    return value.data;
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
