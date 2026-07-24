#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
THEME_NAME=momiji-maple
THEME_SRC="$ROOT/rice/sddm/$THEME_NAME"
THEME_DST="/usr/share/sddm/themes/$THEME_NAME"
THEME_CONF_SRC="$ROOT/etc/sddm.conf.d/20-momiji-theme.conf"
THEME_CONF_DST="/etc/sddm.conf.d/20-momiji-theme.conf"
BACKGROUND_SRC="$ROOT/wallpapers/maple.png"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/backups/momiji-sddm/$STAMP"

if [[ $EUID -eq 0 ]]; then
    printf 'Run this as the normal user. The script uses sudo where needed.\n' >&2
    exit 1
fi

for required in \
    "$THEME_SRC/Main.qml" \
    "$THEME_SRC/metadata.desktop" \
    "$THEME_SRC/theme.conf" \
    "$THEME_CONF_SRC" \
    "$BACKGROUND_SRC"; do
    if [[ ! -r $required ]]; then
        printf 'Missing required file: %s\n' "$required" >&2
        exit 1
    fi
done

if ! command -v sddm-greeter >/dev/null 2>&1; then
    printf 'sddm-greeter is unavailable. Install the sddm package first.\n' >&2
    exit 1
fi

avatar_src=""
for candidate in "$HOME/.face" "$HOME/.face.icon"; do
    if [[ -r $candidate ]]; then
        avatar_src=$candidate
        break
    fi
done

if [[ -z $avatar_src ]]; then
    avatar_src=$BACKGROUND_SRC
    printf 'WARN  No readable ~/.face or ~/.face.icon was found.\n' >&2
    printf '      Using the Maple wallpaper as the temporary avatar.\n' >&2
    printf '      Set ~/.face to the image used by Caelestia, then rerun this script.\n' >&2
fi

sudo install -d -m 700 "$BACKUP_DIR"
if [[ -e $THEME_DST ]]; then
    sudo cp -a "$THEME_DST" "$BACKUP_DIR/"
fi
if [[ -e $THEME_CONF_DST ]]; then
    sudo cp -a "$THEME_CONF_DST" "$BACKUP_DIR/"
fi

sudo rm -rf "$THEME_DST"
sudo install -d -m 755 "$THEME_DST"
sudo install -m 644 \
    "$THEME_SRC/Main.qml" \
    "$THEME_SRC/metadata.desktop" \
    "$THEME_SRC/theme.conf" \
    "$THEME_DST/"
sudo install -m 644 "$BACKGROUND_SRC" "$THEME_DST/background.png"
sudo install -m 644 "$avatar_src" "$THEME_DST/avatar.png"
sudo install -Dm644 "$THEME_CONF_SRC" "$THEME_CONF_DST"
sudo chown -R root:root "$THEME_DST" "$THEME_CONF_DST"
sudo chmod -R a+rX "$THEME_DST"

printf '\nMomiji Maple SDDM theme installed.\n'
printf 'Backup: %s\n' "$BACKUP_DIR"
printf '\nPreview it without logging out:\n'
printf '  sddm-greeter --test-mode --theme %q\n' "$THEME_DST"
printf '\nAfter a successful preview, reboot to see it after LUKS unlock.\n'
printf 'Autologin remains disabled. Your Linux password is still required.\n'
