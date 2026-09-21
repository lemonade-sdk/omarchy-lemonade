# Lemonade for Omarchy

[![Plugin checks](https://github.com/lemonade-sdk/omarchy-lemonade/actions/workflows/check.yml/badge.svg)](https://github.com/lemonade-sdk/omarchy-lemonade/actions/workflows/check.yml)
[![Lemonade compatibility](https://github.com/lemonade-sdk/omarchy-lemonade/actions/workflows/compatibility.yml/badge.svg)](https://github.com/lemonade-sdk/omarchy-lemonade/actions/workflows/compatibility.yml)

A thin [Omarchy](https://omarchy.org/) Quattro plugin for [Lemonade](https://github.com/lemonade-sdk/lemonade).

The bar shows server availability. Its panel lists installed models and forwards load/unload requests to Lemonade. **Open Lemonade** launches the server's existing web app for chat, downloads, backend setup, and every other feature.

Lemonade owns inference, model discovery, downloads, configuration, and its service lifecycle. This repository contains only the Omarchy UI, HTTP glue, and integration tests. Disabling or removing the plugin leaves Lemonade and its models intact.

## Install

Requires Omarchy's Quattro shell with the built-in bar. Custom replacement bars may not expose the shared-service interface this plugin needs.

1. Install the plugin:

   ```sh
   omarchy plugin add https://github.com/lemonade-sdk/omarchy-lemonade.git --enable
   ```

2. Click the lemon in the bar. If Lemonade is missing, choose **Install Lemonade**. A terminal explains the package installation, asks for confirmation, and runs `omarchy pkg add lemonade-server`. Omarchy's package helper handles installation and dependencies; the script enables the packaged service if no Lemonade service is already running.
3. If Lemonade is already installed but stopped, choose **Start Lemonade**. This starts an existing service without reinstalling, restarting, or enabling it at boot. An already-enabled user service takes precedence over the system service.
4. After setup, the panel connects automatically; **Refresh** / `R` retries immediately. Choose **Open Lemonade** to download models and configure backends in the existing app.

For a remote server or a custom local address, choose **Connection settings** / `C`, enter its HTTP(S) address, and select **Save and connect**. Authentication errors offer connection settings rather than local installation. Install/Start shortcuts are limited to the default local address (localhost, 127.0.0.1, or ::1 on HTTP port 13305); other addresses must be managed through their existing server setup.

Setup is always an explicit action. A failed or cancelled package command stays visible in the terminal, and a failed installation never starts the service. Plugin removal does not interrupt a setup terminal already opened. The plugin does not implement package downloads or dependency resolution; see Lemonade's [Arch installation instructions](https://lemonade-server.ai/docs/guide/install/arch/).

Right-click opens Lemonade when connected and opens the setup panel when offline; middle-click refreshes status.

In the panel, click a model or use Up/Down and Enter to load/unload it. `R` refreshes, `O` opens Lemonade, and Escape closes the panel. Model actions affect the shared server and therefore its other clients too.

## Settings

Settings live on this widget's entry in `~/.config/omarchy/shell.json`. Use Omarchy's settings commands:

```sh
omarchy bar set io.github.lemonade-sdk.lemonade baseUrl http://localhost:13305
omarchy bar set io.github.lemonade-sdk.lemonade pollSeconds 15 --json
omarchy bar set io.github.lemonade-sdk.lemonade checkUpdates false --json
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `baseUrl` | `http://localhost:13305` | Server URL; an optional `/v1` or `/api/v1` suffix is normalized |
| `apiKeyEnv` | Admin key, then regular key | Override the key variable name; otherwise prefer `LEMONADE_ADMIN_API_KEY`, then `LEMONADE_API_KEY` |
| `pollSeconds` | `15` | Status refresh interval, minimum 5 seconds |
| `checkUpdates` | `true` | Check GitHub for the latest stable Lemonade release at activation and hourly |

For authentication, provide the key in the environment of the Omarchy shell before starting it. In **Connection settings**, enter its environment variable name (for example `MY_LEMONADE_KEY`), not the secret itself. Leave that field blank to use the default key variables. You can also select it with `omarchy bar set io.github.lemonade-sdk.lemonade apiKeyEnv MY_LEMONADE_KEY`. Keys are never placed in plugin settings, URLs, or process arguments. The browser app handles its own authentication. GitHub release checks never receive the Lemonade key.

Use HTTPS for remote authenticated connections. The plugin connects only to the configured server, plus GitHub when update checks are enabled. A failed update check does not prevent local use.

## Updates and compatibility

The supported target is the **latest stable Lemonade release**. The panel reports the running version and shows an update notice when GitHub reports a newer stable release. Install server updates through your package manager; Arch can lag upstream. The plugin never upgrades or restarts a shared server automatically.

```sh
omarchy plugin update io.github.lemonade-sdk.lemonade
omarchy plugin remove io.github.lemonade-sdk.lemonade
```

Omarchy's Git installer follows the repository's default branch, so `main` must stay usable. Plugin versions and releases are independent of Lemonade's version number.

The release watcher checks every six hours for the latest stable release and every stable release published since this repository was created. It dispatches compatibility runs for untested releases and retries failures. The workflow also accepts an immediate `repository_dispatch` event from upstream; see [CI and hardware runners](docs/testing.md).

## Development

```sh
python -m venv /tmp/omarchy-lemonade-tests
. /tmp/omarchy-lemonade-tests/bin/activate
pip install -r tests/requirements.txt
python -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/*.test.cjs
omarchy plugin validate .
```

Keep virtual environments outside the plugin checkout: Omarchy rejects plugin directories containing symlinks. The QML client tests run without Omarchy on Windows or Linux; rendering and shell lifecycle tests require a real Omarchy session. See [testing](docs/testing.md) for coverage and remaining manual checks.

## Layout

- `BarWidget.qml`, `Panel.qml`: Omarchy presentation and keyboard/mouse actions.
- `Service.qml`, `Onboarding.js`: one client shared across monitors, environment authentication, first-run state, local settings, launcher, status IPC.
- `scripts/local-server.sh`: read-only installation probes and explicit terminal actions delegating to pacman/systemd.
- `Controller.qml`, `Request.qml`, `LemonadeApi.js`: asynchronous public API requests and response presentation.
- `tests/`, `.github/workflows/`: shim tests and compatibility with published Lemonade releases.

No server source, model catalog, backend rules, package-management implementation, or inference implementation is copied here. API additions belong upstream in Lemonade.

Apache-2.0 licensed. Hardware-runner validation is pending runner provisioning.
