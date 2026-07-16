#!/bin/sh
set -eu

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    printf 'PASS: %s\n' "$*"
}

[ -f packages.txt ] || fail "packages.txt is missing"
[ -f RUNBOOK.md ] || fail "RUNBOOK.md is missing"
[ ! -e aur-packages.txt ] || fail "aur-packages.txt exists, but Proton VPN is now an official package"

blank_lines=$(grep -n '^[[:space:]]*$' packages.txt || true)
[ -z "$blank_lines" ] || {
    printf '%s\n' "$blank_lines" >&2
    fail "packages.txt contains blank lines"
}

duplicates=$(LC_ALL=C sort packages.txt | uniq -d)
[ -z "$duplicates" ] || {
    printf '%s\n' "$duplicates" >&2
    fail "packages.txt contains duplicate packages"
}

package_count=$(awk 'NF { count++ } END { print count + 0 }' packages.txt)
[ "$package_count" -eq 78 ] ||
    fail "packages.txt has $package_count packages, expected 78"

for package in \
    libreoffice-fresh \
    hunspell-en_ca \
    wireguard-tools \
    obsidian \
    proton-vpn-gtk-app
do
    grep -qxF "$package" packages.txt ||
        fail "$package is missing from packages.txt"
done

required_files="
README.md
RUNBOOK.md
packages.txt
boot/loader.conf
boot/arch.conf.template
etc/hosts
etc/getty-autolog.conf
home/fish/10-tty1-hyprland.fish
home/fish/20-greeting.fish
home/caelestia/hypr-vars.lua
rice/fun-packages.txt
rice/snippets/neko-sounds.conf
rice/sounds/login-chime.wav
rice/sounds/nya-open.wav
rice/sounds/purr-close.wav
wallpapers/maple.png
"

for file in $required_files
do
    [ -s "$file" ] || fail "required file is missing or empty: $file"
done

if grep -Eq \
    'momiji-rice-merge\.zip|momiji-clock-pack\.zip|aur-packages\.txt' \
    RUNBOOK.md
then
    fail "RUNBOOK.md still contains obsolete staging instructions"
fi

if grep -q 'ships finished and validated' RUNBOOK.md &&
   [ ! -s rice/ponies/clockwork-relativity.pony ]
then
    fail "RUNBOOK.md claims Clock is finished, but the pony file is absent"
fi

if command -v fish >/dev/null 2>&1
then
    find home -type f -name '*.fish' -print |
    while IFS= read -r file
    do
        fish -n "$file" || fail "Fish syntax failed: $file"
    done
    pass "Fish configuration syntax"
else
    printf 'SKIP: fish is not installed on this machine\n'
fi

git diff --check
git diff --cached --check

pass "package manifest structure"
pass "required provisioning files"
pass "Momiji local preflight complete"
