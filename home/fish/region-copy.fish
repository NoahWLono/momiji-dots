#!/usr/bin/env fish
# Select region and copy PNG to Wayland clipboard.
set -l region (slurp)
test -n "$region"; or exit 0
grim -g "$region" - | wl-copy --type image/png
