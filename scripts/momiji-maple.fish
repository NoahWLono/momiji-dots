#!/usr/bin/env fish
# Fish entry point. Local files only; no sudo, downloads, git operations or eval.
# Usage: fish scripts/momiji-maple.fish [preview|install|edit|colors|restore]
set -l script_dir (path dirname (status filename))
if not command -q python3
    printf '%s\n' 'Maple needs python3: sudo pacman -S --needed python' >&2
    exit 1
end
command python3 -B "$script_dir/maple_ascii.py" $argv
exit $status
