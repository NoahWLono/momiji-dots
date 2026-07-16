#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if ! command -v paru >/dev/null 2>&1; then
    printf 'paru is required. Run scripts/install-packages.sh first.\n' >&2
    exit 1
fi

packages=()
while IFS= read -r pkg; do
    packages[${#packages[@]}]=$pkg
done < <(awk '
    /^[[:space:]]*($|#)/ { next }
    {
        sub(/[[:space:]]+#.*$/, "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    }
    length { print }
' "$ROOT/rice/fun-packages.txt")

failed=()
for pkg in "${packages[@]}"; do
    printf '\n==> Installing optional package: %s\n' "$pkg"
    if ! paru -S --needed "$pkg"; then
        failed[${#failed[@]}]=$pkg
    fi
done

install -Dm644 "$ROOT/home/fish/20-greeting.fish" \
    "$HOME/.config/fish/conf.d/20-greeting.fish"

if [[ -f "$ROOT/rice/ponies/clockwork-relativity.pony" ]]; then
    install -Dm644 "$ROOT/rice/ponies/clockwork-relativity.pony" \
        "$HOME/.local/share/momiji/ponies/clockwork-relativity.pony"
fi

if ((${#failed[@]})); then
    printf '\nOptional packages that did not install: %s\n' \
        "${failed[*]}" >&2
    printf 'The desktop install is unaffected. Check those names individually.\n' >&2
    exit 1
fi

printf '\nOptional terminal extras installed.\n'
