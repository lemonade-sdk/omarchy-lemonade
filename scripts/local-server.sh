#!/usr/bin/env bash
set -euo pipefail

has_unit() {
    [[ $(systemctl "$@" show lemond.service --property=LoadState --value 2>/dev/null) == loaded ]]
}

active() {
    systemctl "$@" is-active --quiet lemond.service 2>/dev/null
}

installed() {
    command -v lemond >/dev/null 2>&1 || pacman -Q lemonade-server >/dev/null 2>&1
}

arch() {
    command -v pacman >/dev/null 2>&1
}

boolean() {
    if "$@"; then printf true; else printf false; fi
}

if [[ ${1:-} == probe ]]; then
    printf '{"installed":%s,"arch":%s,"systemActive":%s,"userActive":%s,"systemUnit":%s,"userUnit":%s}\n' \
        "$(boolean installed)" "$(boolean arch)" \
        "$(boolean active)" "$(boolean active --user)" \
        "$(boolean has_unit)" "$(boolean has_unit --user)"
    exit 0
fi

case ${1:-} in
    install|start) action=$1 ;;
    *) printf 'Usage: %s probe|install|start\n' "$0" >&2; exit 2 ;;
esac

finish() {
    result=$?
    if (( result != 0 )); then printf '\nSetup failed. Review the output above, then retry from the plugin.\n'; fi
    printf '\nReturn to the Lemonade panel and press R to refresh.\n'
    read -r -p 'Press Enter to close this terminal. ' _ || true
    exit "$result"
}
trap finish EXIT

exec 9>"${XDG_RUNTIME_DIR:?No desktop runtime directory}/omarchy-lemonade-setup.lock"
flock -n 9 || { printf 'Another Lemonade setup is already running.\n'; exit 1; }

if [[ $action == install ]]; then
    command -v pacman >/dev/null 2>&1 || { printf 'This setup requires Arch Linux.\n'; exit 1; }
    printf 'Install Lemonade using pacman and enable its service at startup.\n'
    printf 'This performs the full system upgrade required by Arch (sudo pacman -Syu --needed lemonade-server).\n'
else
    installed || { printf 'Lemonade is not installed. Use Install Lemonade first.\n'; exit 1; }
    printf 'Start the existing Lemonade service. No running service will be restarted.\n'
fi
read -r -p 'Continue? [y/N] ' answer || exit 0
[[ $answer == y || $answer == Y ]] || { printf 'Cancelled.\n'; exit 0; }

if [[ $action == install ]]; then
    sudo pacman -Syu --needed lemonade-server
fi

if active --user || active; then
    printf 'A Lemonade service is already running.\n'
elif has_unit --user && systemctl --user is-enabled --quiet lemond.service 2>/dev/null; then
    systemctl --user start lemond.service
elif [[ $action == install ]] && has_unit; then
    sudo systemctl enable --now lemond.service
elif has_unit; then
    sudo systemctl start lemond.service
elif has_unit --user; then
    systemctl --user start lemond.service
else
    printf 'No usable lemond service was found. Start Lemonade using your existing installation.\n'
    exit 1
fi
