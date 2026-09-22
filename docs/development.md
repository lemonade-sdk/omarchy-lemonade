# Development guidance

Keep this repository a thin Omarchy integration. Server behavior, model registries, downloads, backend selection, service lifecycle, inference, and package installation belong in lemonade-sdk/lemonade.

Use only Lemonade's public APIs. Keep client settings local and credentials out of settings, logs, and command arguments. Do not stop or upgrade the user's server as a plugin lifecycle action.

Explicit first-run Install/Start buttons may invoke the existing package manager and systemd service through a confirmed terminal action. Do not build a separate package installer or start a second daemon when an existing service is running.

Run the QML client tests and release-watcher tests for relevant changes. UI changes also need Omarchy session validation. Do not describe parser checks or hosted API tests as hardware/desktop validation.

The default branch is directly installable through Omarchy. Keep a valid root manifest and runnable QML entry points, with no symlinks or generated dependency directories committed. Hardware jobs must never execute untrusted pull request code.
