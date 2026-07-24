#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
THEME="Momiji-Paw"
SIZE=32
SOURCE="$ROOT/rice/cursors/momiji-paw/src"
DEST="$HOME/.local/share/icons/$THEME"
STAMP=$(date +%Y%m%d-%H%M%S)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/momiji-paw.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

if [[ $EUID -eq 0 ]]; then
    printf 'Run this as your normal user, not root.\n' >&2
    exit 1
fi

missing=()
for cmd in rsvg-convert xcursorgen hyprcursor-util; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if ((${#missing[@]})); then
    printf 'Missing build tools: %s\n' "${missing[*]}" >&2
    printf 'Install them with:\n' >&2
    printf '  sudo pacman -S --needed xorg-xcursorgen librsvg hyprcursor\n' >&2
    exit 1
fi

for svg in default link text wait forbidden move; do
    [[ -f "$SOURCE/$svg.svg" ]] || {
        printf 'Missing cursor source: %s\n' "$SOURCE/$svg.svg" >&2
        exit 1
    }
done

if [[ -e "$DEST" ]]; then
    mv "$DEST" "$DEST.bak.$STAMP"
    printf 'Backed up old theme to %s\n' "$DEST.bak.$STAMP"
fi

BASE_THEME=Adwaita
if [[ ! -d /usr/share/icons/Adwaita/cursors && ! -d "$HOME/.local/share/icons/Adwaita/cursors" ]]; then
    BASE_THEME=default
fi

XROOT="$TMP/xcursor/$THEME"
mkdir -p "$XROOT/cursors" "$TMP/png"

render_shape() {
    local shape=$1
    local hotspot_x=$2
    local hotspot_y=$3
    local config="$TMP/$shape.cursor"
    : >"$config"

    for size in 24 32 48 64; do
        local png="$TMP/png/${shape}-${size}.png"
        rsvg-convert \
            --width="$size" \
            --height="$size" \
            --output="$png" \
            "$SOURCE/$shape.svg"
        printf '%s %s %s %s\n' \
            "$size" \
            "$((hotspot_x * size / 64))" \
            "$((hotspot_y * size / 64))" \
            "$png" >>"$config"
    done

    xcursorgen "$config" "$XROOT/cursors/$shape"
}

render_shape default 2 2
render_shape link 2 2
render_shape text 32 31
render_shape wait 32 32
render_shape forbidden 32 32
render_shape move 32 32

cat >"$XROOT/index.theme" <<EOF
[Icon Theme]
Name=Momiji Paw
Comment=Maple Nekokami paw cursor for Momiji
Inherits=$BASE_THEME
EOF

link_aliases() {
    local target=$1
    shift
    local alias
    for alias in "$@"; do
        ln -sfn "$target" "$XROOT/cursors/$alias"
    done
}

mv "$XROOT/cursors/default" "$XROOT/cursors/left_ptr"
mv "$XROOT/cursors/link" "$XROOT/cursors/hand2"
mv "$XROOT/cursors/text" "$XROOT/cursors/xterm"
mv "$XROOT/cursors/wait" "$XROOT/cursors/watch"
mv "$XROOT/cursors/forbidden" "$XROOT/cursors/not-allowed"
mv "$XROOT/cursors/move" "$XROOT/cursors/fleur"

link_aliases left_ptr \
    arrow default top_left_arrow left-arrow dnd-none
link_aliases hand2 \
    pointer hand hand1 link openhand closedhand dnd-link
link_aliases xterm \
    text ibeam vertical-text
link_aliases watch \
    wait progress left_ptr_watch half-busy
link_aliases not-allowed \
    forbidden no-drop dnd-no-drop crossed_circle
link_aliases fleur \
    move all-scroll grab grabbing dnd-move size_all

WORK="$TMP/hypr-work"
mkdir -p "$WORK/hyprcursors"

cat >"$WORK/manifest.hl" <<'EOF'
name = Momiji-Paw
description = Maple Nekokami paw cursor for Momiji
version = 1.0
cursors_directory = hyprcursors
EOF

make_hypr_shape() {
    local shape=$1
    local hx=$2
    local hy=$3
    shift 3
    local dir="$WORK/hyprcursors/$shape"
    mkdir -p "$dir"
    cp "$SOURCE/$shape.svg" "$dir/image.svg"

    {
        printf 'resize_algorithm = bilinear\n'
        printf 'hotspot_x = %s\n' "$hx"
        printf 'hotspot_y = %s\n' "$hy"
        local override
        for override in "$@"; do
            printf 'define_override = %s\n' "$override"
        done
        printf 'define_size = 32, image.svg\n'
    } >"$dir/meta.hl"
}

make_hypr_shape default 0.03125 0.03125 \
    arrow default left_ptr top_left_arrow
make_hypr_shape link 0.03125 0.03125 \
    pointer hand hand1 hand2 link
make_hypr_shape text 0.5 0.484375 \
    text xterm ibeam vertical-text
make_hypr_shape wait 0.5 0.5 \
    wait progress watch
make_hypr_shape forbidden 0.5 0.5 \
    not-allowed forbidden no-drop
make_hypr_shape move 0.5 0.5 \
    move all-scroll grab grabbing

mkdir -p "$TMP/hypr-output"
hyprcursor-util --create "$WORK" --output "$TMP/hypr-output"

HYPR_THEME=$(find "$TMP/hypr-output" -mindepth 1 -maxdepth 1 -type d -name 'theme_*' -print -quit)
if [[ -z ${HYPR_THEME:-} ]]; then
    printf 'hyprcursor-util did not produce a compiled theme.\n' >&2
    exit 1
fi

mkdir -p "$DEST"
cp -a "$HYPR_THEME"/. "$DEST"/
cp -a "$XROOT/index.theme" "$DEST/index.theme"
cp -a "$XROOT/cursors" "$DEST/cursors"

mkdir -p "$HOME/.icons"
ln -sfn "$DEST" "$HOME/.icons/$THEME"

DEFAULT_DIR="$HOME/.icons/default"
mkdir -p "$DEFAULT_DIR"
if [[ -f "$DEFAULT_DIR/index.theme" ]]; then
    cp -a "$DEFAULT_DIR/index.theme" "$DEFAULT_DIR/index.theme.bak.$STAMP"
fi
cat >"$DEFAULT_DIR/index.theme" <<EOF
[Icon Theme]
Inherits=$THEME
EOF

ACTIVE_VARS="$HOME/.config/caelestia/hypr-vars.lua"
TRACKED_VARS="$ROOT/home/caelestia/hypr-vars.lua"
mkdir -p "$(dirname "$ACTIVE_VARS")"

if [[ -f "$ACTIVE_VARS" ]]; then
    cp -a "$ACTIVE_VARS" "$ACTIVE_VARS.bak.$STAMP"
fi
install -Dm644 "$TRACKED_VARS" "$ACTIVE_VARS"

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME" || true
    gsettings set org.gnome.desktop.interface cursor-size "$SIZE" || true
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl setcursor "$THEME" "$SIZE" || true
fi

printf '\nMomiji-Paw installed successfully.\n'
printf 'Theme: %s\n' "$DEST"
printf 'Caelestia variables: %s\n' "$ACTIVE_VARS"
printf '\nLog out and back in, or reboot, so XWayland and every toolkit inherit it.\n'
