# Changelog

## 0.3.0

- Install delegates to Omarchy's package helper (`omarchy pkg add lemonade-server`) instead of running a pacman system upgrade, which Omarchy's update guard aborts whenever the system has pending updates.
- System upgrades are left to `omarchy update`, matching first-party Omarchy installers.
- Linux command tests assert the setup script never combines pacman sync and sysupgrade, a state CI cannot reach because the guard hook is absent from containers.

## 0.2.0

- First-run Install/Start controls delegate to pacman and the existing Lemonade systemd service with terminal confirmation.
- Connection settings form saves local or remote server addresses and API-key environment variable names.
- Missing installations, stopped services, authentication failures, and remote connection errors have distinct setup states.
- Linux command tests cover cancellation, install failures, and preserving existing services; desktop validation remains pending.

## 0.1.0

- Omarchy bar status and installed-model shortcuts through Lemonade's public API.
- Existing Lemonade web app launcher, local connection settings, and update notices.
- QML client tests, published-release API checks, and opt-in self-hosted Omarchy hardware tests.
- Hardware/session validation pending runner provisioning.
