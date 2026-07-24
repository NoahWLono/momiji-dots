#!/usr/bin/env bash
set -Eeuo pipefail

THEME_DST=/usr/share/sddm/themes/momiji-maple
THEME_CONF_DST=/etc/sddm.conf.d/20-momiji-theme.conf

if [[ $EUID -eq 0 ]]; then
    printf 'Run this as the normal user. The script uses sudo where needed.\n' >&2
    exit 1
fi

sudo rm -f "$THEME_CONF_DST"
sudo rm -rf "$THEME_DST"

printf 'Removed the Momiji Maple SDDM theme override.\n'
printf 'The existing no-autologin SDDM configuration was left untouched.\n'
printf 'Reboot, or restart SDDM from a tty when it is safe to end the session.\n'
