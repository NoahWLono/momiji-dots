#!/usr/bin/env bash
set -Eeuo pipefail

THEME="Momiji-Paw"
DEST="$HOME/.local/share/icons/$THEME"

if [[ $EUID -eq 0 ]]; then
    printf 'Run this as your normal user, not root.\n' >&2
    exit 1
fi

rm -rf "$DEST"
rm -f "$HOME/.icons/$THEME"

if [[ -f "$HOME/.icons/default/index.theme" ]] \
    && grep -Fxq "Inherits=$THEME" "$HOME/.icons/default/index.theme"; then
    rm -f "$HOME/.icons/default/index.theme"
fi

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme Adwaita || true
    gsettings set org.gnome.desktop.interface cursor-size 24 || true
fi

printf 'Removed Momiji-Paw. Restore a previous hypr-vars.lua backup or edit:\n'
printf '  ~/.config/caelestia/hypr-vars.lua\n'
printf 'Then log out and back in.\n'
