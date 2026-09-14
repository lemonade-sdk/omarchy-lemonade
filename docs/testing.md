# Compatibility testing

## Pull requests and main

`check.yml` runs the real `Controller.qml` and `Request.qml` through Qt against a local HTTP fixture. It covers authentication, health/models responses, load/unload forwarding, errors, timeouts, cancellation, reconnects, URL validation, and release comparison. It parses all QML and uses Omarchy's own manifest validator at a pinned upstream revision. These tests do not simulate a rendered Omarchy desktop.

Node tests check first-run decisions and connection-setting validation. Linux tests execute the actual setup script with fixture package/service commands, covering read-only probing, cancellation, failed installation, existing running services, and user-service preference. They do not install system packages on CI hosts.

## Every Lemonade release

`watch-releases.yml` polls the official release feed every six hours. It discovers all stable releases since this repository was created, plus the latest stable release for the initial baseline. Successful or active runs for a tag are skipped; failed runs are retried. GitHub schedules can be delayed, so this is eventual detection, not an immediate release hook.

`compatibility.yml` validates the tag against a published, non-prerelease release. Its hosted job downloads the official Ubuntu x64 embeddable artifact, verifies GitHub's SHA-256 digest, and starts an isolated server with authentication. The shipped QML client must successfully read health and installed models, and the server must report the exact release version. There is no source rebuild or substitute server implementation.

Run it manually:

```sh
gh workflow run compatibility.yml --repo lemonade-sdk/omarchy-lemonade -f release=v11.9.0
```

For immediate upstream notifications, the publishing workflow in `lemonade-sdk/lemonade` can send:

```json
{
  "event_type": "lemonade-release",
  "client_payload": {"release": "v11.9.0"}
}
```

Send this to `POST /repos/lemonade-sdk/omarchy-lemonade/dispatches` with a GitHub App installation token scoped to this repository with Contents: write. An upstream repository's ordinary `GITHUB_TOKEN` cannot write to this repository. The polling workflow needs no cross-repository secret and is the default integration. No upstream workflow modification is required.

## Self-hosted hardware

Hardware jobs remain skipped until the repository variable `HARDWARE_RUNNERS` is set. A hosted pass does **not** certify Omarchy rendering or accelerator compatibility.

Example variable:

```json
[
  {"name":"amd-gpu", "labels":["self-hosted","Linux","X64","omarchy","amd-gpu"]},
  {"name":"amd-npu", "labels":["self-hosted","Linux","X64","omarchy","amd-npu"]}
]
```

Each runner must provide:

1. A dedicated Arch/Omarchy Quattro desktop session with the built-in bar, an unlocked display, and the GitHub runner using that session's user, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, and `DBUS_SESSION_BUS_ADDRESS`. The Lemonade plugin must not already be installed in that account.
2. Python with `tests/requirements.txt` installed, Node.js, Git, Omarchy CLI, and the hardware's existing Lemonade backend dependencies.
3. A runner-admin-owned executable `/usr/local/bin/omarchy-lemonade-prepare-release TAG`. It must provision the requested official stable Lemonade version using Lemonade's existing packaging/build process, start a dedicated test server, and prepare a small model using Lemonade's existing CLI. Exit nonzero if the requested release is unavailable. Do not silently leave an older Arch package running. Provisioning is external to the plugin because OS updates and hardware setup already belong to Lemonade and runner administration.
4. Environment variables `LEMONADE_URL`, optional `LEMONADE_API_KEY`, `LEMONADE_TEST_MODEL`, and `LEMONADE_TEST_DEVICE` (`gpu` or `npu`). Set them in the runner's environment before starting it. The shell must receive the same API key. The preparation hook cannot export variables back into its parent runner process.

Only trusted default-branch compatibility runs reach hardware. Pull requests run on GitHub-hosted machines. Jobs serialize per hardware name, have a timeout, and check the exact server version before changing any models.

The hardware test loads the preinstalled model through the actual QML client, verifies the model and expected device appear in health, and unloads that model. It requires an initially idle test server. This checks the shim's model lifecycle; upstream Lemonade owns inference correctness and performance suites.

The shell smoke test installs the checked-out plugin into the dedicated session, validates it using the installed Omarchy version, connects to the expected server version, sends panel open/hide commands, disables/re-enables it, and removes its installation in cleanup. It refuses to replace an existing plugin. It does not assert pixels or simulate keyboard/mouse input.

After adding hardware, manually dispatch the latest release once: the watcher will have already recorded its earlier hosted-only pass. Then subsequent releases automatically include every configured runner.

## Manual desktop acceptance

Before declaring desktop support validated, check theme changes, horizontal/vertical bars, multi-monitor placement, click and keyboard navigation, scrolling a long model list, Escape, popup switching, browser launch, shell restart, and removal. Verify that stopping/restarting Lemonade reconnects, and that removing the plugin leaves the server and model cache intact.

For first-run acceptance, use a fresh Omarchy VM or test account: install the plugin before Lemonade, cancel the Install prompt once, then complete it. Verify the terminal remains available on failure, the panel connects after success, and model downloads open the existing app. Also test an installed/stopped service, an already-running user service, a remote URL, a wrong API key, and editing/cancelling/saving connection settings with the keyboard. Package installation and the real Omarchy form still require this desktop test.
