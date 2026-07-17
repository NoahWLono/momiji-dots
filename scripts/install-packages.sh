#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -eq 0 ]]; then
    printf 'Run this script as the normal user, not root. It uses sudo when needed.\n' >&2
    exit 1
fi
if [[ ! -r /etc/arch-release ]]; then
    printf 'This installer is intended for Arch Linux.\n' >&2
    exit 1
fi

read_list() {
    awk '
        /^[[:space:]]*($|#)/ { next }
        {
            sub(/[[:space:]]+#.*$/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        }
        length { print }
    ' "$1"
}

repo_packages=()
while IFS= read -r pkg; do
    repo_packages[${#repo_packages[@]}]=$pkg
done < <(read_list "$ROOT/packages.txt")

printf 'Updating the complete system and installing %d repository packages...\n' \
    "${#repo_packages[@]}"
sudo pacman -Syu --needed "${repo_packages[@]}"

if ! command -v paru >/dev/null 2>&1; then
    build_dir=$(mktemp -d)
    trap 'rm -rf "$build_dir"' EXIT
    git clone https://aur.archlinux.org/paru-bin.git "$build_dir/paru-bin"
    (
        cd "$build_dir/paru-bin"
        makepkg -si
    )
fi

aur_packages=()
while IFS= read -r pkg; do
    aur_packages[${#aur_packages[@]}]=$pkg
done < <(read_list "$ROOT/aur-packages.txt")

if ((${#aur_packages[@]})); then
    printf 'Installing %d application package(s) through paru...\n' \
        "${#aur_packages[@]}"
    paru -S --needed "${aur_packages[@]}"
fi

sudo install -Dm644 "$ROOT/etc/zram-generator.conf" \
    /etc/systemd/zram-generator.conf
sudo systemctl daemon-reload

sudo systemctl enable --now \
    bluetooth.service power-profiles-daemon.service
sudo systemctl enable fstrim.timer

printf '\nPackage stage complete.\n'
printf 'zram will be created automatically on the next boot.\n'
printf 'Next:\n'
printf '  paru -S --needed caelestia-cli\n'
printf '  caelestia install --aur-helper paru\n'
printf '  scripts/deploy-configs.sh\n'
printf 'After a manual Hyprland test, run scripts/enable-display-manager.sh.\n'
