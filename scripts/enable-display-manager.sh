#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -eq 0 ]]; then
    printf 'Run this script as the normal user, not root.\n' >&2
    exit 1
fi
if ! command -v sddm >/dev/null 2>&1; then
    printf 'SDDM is not installed. Run scripts/install-packages.sh first.\n' >&2
    exit 1
fi
if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
    printf 'The Hyprland Wayland session file is missing.\n' >&2
    exit 1
fi
if [[ ! -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    printf 'Caelestia does not appear to be installed and tested yet.\n' >&2
    printf 'Expected: ~/.config/hypr/hyprland.lua\n' >&2
    exit 1
fi

sudo install -Dm644 "$ROOT/etc/sddm.conf.d/10-momiji.conf" \
    /etc/sddm.conf.d/10-momiji.conf

# Remove remnants of the former tty1 autologin design, if they exist.
sudo rm -f \
    /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f "$HOME/.config/fish/conf.d/10-tty1-hyprland.fish"

sudo systemctl daemon-reload
sudo systemctl set-default graphical.target
sudo systemctl enable sddm.service

printf '\nSDDM is enabled for the next boot.\n'
printf 'At the first login screen, select the Hyprland session and sign in as %s.\n' \
    "$(id -un)"
printf 'SDDM will remember the last user and session. Autologin is disabled.\n'
