#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

if [[ $EUID -eq 0 ]]; then
    printf 'Run this script as the normal user, not root.\n' >&2
    exit 1
fi
if [[ ! -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    printf 'Caelestia does not appear to be installed yet.\n' >&2
    printf 'Expected: ~/.config/hypr/hyprland.lua\n' >&2
    printf 'Install it with: paru -S caelestia-cli && caelestia install --aur-helper paru\n' >&2
    exit 1
fi

deploy_file() {
    src=$1
    target=$2
    if [[ -e "$target" ]] && ! cmp -s "$src" "$target"; then
        cp -a "$target" "$target.bak.$STAMP"
        printf 'Backed up %s\n' "$target"
    fi
    install -Dm644 "$src" "$target"
}

deploy_file "$ROOT/home/caelestia/hypr-vars.lua" \
    "$HOME/.config/caelestia/hypr-vars.lua"
deploy_file "$ROOT/home/caelestia/hypr-user.lua" \
    "$HOME/.config/caelestia/hypr-user.lua"
deploy_file "$ROOT/home/fish/20-greeting.fish" \
    "$HOME/.config/fish/conf.d/20-greeting.fish"

for wav in "$ROOT"/rice/sounds/*.wav; do
    install -Dm644 "$wav" \
        "$HOME/.local/share/momiji/sounds/$(basename "$wav")"
done

if [[ -f "$ROOT/rice/ponies/clockwork-relativity.pony" ]]; then
    install -Dm644 "$ROOT/rice/ponies/clockwork-relativity.pony" \
        "$HOME/.local/share/momiji/ponies/clockwork-relativity.pony"
fi

install -Dm644 "$ROOT/wallpapers/maple.png" \
    "$HOME/Pictures/Wallpapers/maple.png"

if command -v caelestia >/dev/null 2>&1 \
    && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    caelestia wallpaper -f "$HOME/Pictures/Wallpapers/maple.png"
    caelestia scheme set -n dynamic
    hyprctl reload
else
    printf 'Not currently inside Hyprland. After starting it, run:\n'
    printf '  caelestia wallpaper -f %q\n' \
        "$HOME/Pictures/Wallpapers/maple.png"
    printf '  caelestia scheme set -n dynamic\n'
fi

printf '\nConfigs deployed. Start Hyprland manually and test it before enabling SDDM.\n'
