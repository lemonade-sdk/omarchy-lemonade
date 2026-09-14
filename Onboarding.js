function localEndpoint(url) {
    return /^http:\/\/(localhost|127\.0\.0\.1|\[::1\]):13305$/i.test(url);
}

function state(url, online, checked, httpStatus, local) {
    if (online) return "connected";
    if (!checked) return "checking";
    if (httpStatus === 401 || httpStatus === 403) return "authentication";
    if (httpStatus > 0) return "responding";
    if (!localEndpoint(url)) return "connection";
    if (!local) return "checking-local";
    if (local.systemActive || local.userActive) return "running";
    if (!local.installed) return local.arch ? "install" : "unsupported";
    return local.systemUnit || local.userUnit ? "start" : "unmanaged";
}

function message(value) {
    var messages = {
        "connected": "Connected to Lemonade.",
        "checking": "Connecting to Lemonade…",
        "checking-local": "Checking the local Lemonade installation…",
        "install": "Install Lemonade on this computer, or connect to a server on another computer.",
        "start": "Lemonade is installed. Start its existing service to connect.",
        "authentication": "The server requires a valid API key. Choose the key's environment variable in Connection settings.",
        "responding": "The address responds, but is not returning Lemonade health data. Check Connection settings.",
        "connection": "Cannot connect to this address. Check the server and Connection settings.",
        "running": "A Lemonade service is running. It may still be starting, or use a different address. Refresh or check Connection settings.",
        "unsupported": "Install Lemonade using its installation guide, or connect to an existing server.",
        "unmanaged": "Lemonade is installed without a usable service. Start it using your existing setup, or check Connection settings."
    };
    return messages[value] || "Check Connection settings.";
}

function connectionSettings(current, url, keyVariable) {
    var key = String(keyVariable || "").trim();
    if (key && !/^[A-Za-z_][A-Za-z0-9_]*$/.test(key))
        throw new Error("Enter an environment variable name, not an API key.");
    var next = {};
    Object.keys(current || {}).forEach(function(name) { next[name] = current[name]; });
    next.baseUrl = url;
    if (key) next.apiKeyEnv = key;
    else delete next.apiKeyEnv;
    return next;
}
