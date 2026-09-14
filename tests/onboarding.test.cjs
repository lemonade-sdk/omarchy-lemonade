const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const onboarding = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../Onboarding.js'), 'utf8'), onboarding);

const url = 'http://localhost:13305';
const empty = {installed: false, arch: true, systemActive: false, userActive: false, systemUnit: false, userUnit: false};

test('first run offers install, start, and connected states', () => {
    assert.equal(onboarding.state(url, false, false, 0, empty), 'checking');
    assert.equal(onboarding.state(url, false, true, 0, null), 'checking-local');
    assert.equal(onboarding.state(url, false, true, 0, empty), 'install');
    assert.equal(onboarding.state(url, false, true, 0, {...empty, installed: true, systemUnit: true}), 'start');
    assert.equal(onboarding.state(url, true, true, 200, empty), 'connected');
});

test('a responding server never offers installation or starting another service', () => {
    for (const code of [401, 403]) assert.equal(onboarding.state(url, false, true, code, empty), 'authentication');
    for (const code of [200, 404, 500]) assert.equal(onboarding.state(url, false, true, code, empty), 'responding');
    for (const key of ['systemActive', 'userActive'])
        assert.equal(onboarding.state(url, false, true, 0, {...empty, [key]: true}), 'running');
});

test('remote hosts, other ports, proxies, and HTTPS never offer local installation', () => {
    for (const address of ['http://192.168.1.2:13305', 'http://localhost', 'http://localhost:13306',
        'http://localhost.evil:13305', 'http://localhost:13305/proxy', 'https://localhost:13305', '']) {
        assert.equal(onboarding.localEndpoint(address), false);
        assert.equal(onboarding.state(address, false, true, 0, empty), 'connection');
    }
    for (const address of [url, 'http://127.0.0.1:13305', 'http://[::1]:13305'])
        assert.equal(onboarding.localEndpoint(address), true);
});

test('unsupported and unmanaged installations do not offer a broken start action', () => {
    assert.equal(onboarding.state(url, false, true, 0, {...empty, arch: false}), 'unsupported');
    assert.equal(onboarding.state(url, false, true, 0, {...empty, installed: true}), 'unmanaged');
});

test('connection changes preserve other settings and accept only environment variable names', () => {
    const previous = {baseUrl: url, apiKeyEnv: 'OLD_KEY', pollSeconds: 30, checkUpdates: false};
    const updated = onboarding.connectionSettings(previous, 'https://server.example', ' REMOTE_KEY ');
    assert.equal(updated.pollSeconds, 30);
    assert.equal(updated.checkUpdates, false);
    assert.equal(updated.apiKeyEnv, 'REMOTE_KEY');
    assert.equal(previous.baseUrl, url);
    assert.equal(onboarding.connectionSettings(previous, url, '').apiKeyEnv, undefined);
    for (const key of ['sk-secret-key', 'Bearer key', 'KEY;echo nope', '1KEY'])
        assert.throws(() => onboarding.connectionSettings(previous, url, key), /variable name/);
});
