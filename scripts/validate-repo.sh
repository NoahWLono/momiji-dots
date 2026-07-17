#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK_ARCH=false
CHECK_AUR=false

usage() {
    cat <<'USAGE'
Usage: scripts/validate-repo.sh [--arch] [--aur]

  --arch  Verify every package in packages.txt with current pacman databases.
  --aur   Verify application and optional lists through pacman or the AUR RPC.
USAGE
}

while (($#)); do
    case "$1" in
        --arch) CHECK_ARCH=true ;;
        --aur) CHECK_AUR=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

failures=0
warns=0

pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*" >&2; warns=$((warns + 1)); }
fail() { printf 'FAIL  %s\n' "$*" >&2; failures=$((failures + 1)); }

list_packages() {
    awk '
        { sub(/\r$/, "") }
        /^[[:space:]]*($|#)/ { next }
        {
            sub(/[[:space:]]+#.*$/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if (length($0)) print
        }
    ' "$1"
}

required=(
    README.md
    RUNBOOK.md
    CHECKLIST.md
    packages.txt
    aur-packages.txt
    boot/loader.conf
    boot/arch.conf.template
    etc/hosts
    etc/mkinitcpio.conf.d/momiji-encryption.conf
    etc/sddm.conf.d/10-momiji.conf
    etc/zram-generator.conf
    home/fish/20-greeting.fish
    home/caelestia/hypr-vars.lua
    home/caelestia/hypr-user.lua
    rice/RICING.md
    rice/fastfetch/config-maple.jsonc
    rice/fun-packages.txt
    rice/ponies/README.md
    rice/snippets/neko-lid-sounds.lua
    rice/snippets/paw-cursor.md
    rice/sounds/login-chime.wav
    rice/sounds/nya-open.wav
    rice/sounds/purr-close.wav
    wallpapers/maple.png
    scripts/install-packages.sh
    scripts/deploy-configs.sh
    scripts/enable-display-manager.sh
    scripts/install-fun.sh
)

for rel in "${required[@]}"; do
    [[ -e "$ROOT/$rel" ]] || fail "missing required path: $rel"
done
if ((failures == 0)); then
    pass "required repository paths exist"
fi

retired=(
    scripts/preflight.sh
    etc/getty-autologin.conf
    etc/logind-lid.conf
    etc/sleep-hibernate.conf
    home/fish/10-tty1-hyprland.fish
    scripts/enable-autologin.sh
    rice/snippets/hypr-cursor.conf
    rice/snippets/neko-sounds.conf
)

for rel in "${retired[@]}"; do
    [[ ! -e "$ROOT/$rel" ]] || fail "retired path still exists: $rel"
done

repo_packages=()
while IFS= read -r pkg; do
    repo_packages[${#repo_packages[@]}]=$pkg
done < <(list_packages "$ROOT/packages.txt")

if ((${#repo_packages[@]} == 95)); then
    pass "packages.txt contains 95 package entries"
else
    fail "packages.txt contains ${#repo_packages[@]} entries, expected 95"
fi

for required_pkg in \
    curl git openssh alsa-utils libreoffice-fresh hunspell hunspell-en_ca \
    wireguard-tools cryptsetup sddm zram-generator dosfstools \
    mesa hyprpolkitagent obsidian; do
    if ! printf '%s\n' "${repo_packages[@]}" | grep -Fxq "$required_pkg"; then
        fail "packages.txt is missing required package: $required_pkg"
    fi
done

for list in packages.txt aur-packages.txt rice/fun-packages.txt; do
    file="$ROOT/$list"
    [[ -f "$file" ]] || continue

    dupes=$(list_packages "$file" | sort | uniq -d)
    if [[ -n "$dupes" ]]; then
        fail "$list has duplicate entries: $(printf '%s' "$dupes" | tr '\n' ' ')"
    else
        pass "$list has no duplicate entries"
    fi

    invalid=$(list_packages "$file" | grep -Ev '^[A-Za-z0-9@._+:-]+$' || true)
    if [[ -n "$invalid" ]]; then
        fail "$list has malformed entries: $(printf '%s' "$invalid" | tr '\n' ' ')"
    fi
done

crlf_files=""
while IFS= read -r -d '' file; do
    case "$file" in
        *.wav|*.png|*/.git/*) continue ;;
    esac
    if LC_ALL=C grep -q $'\r' "$file"; then
        crlf_files="${crlf_files}${file#"$ROOT/"} "
    fi
done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -print0)

if [[ -n "$crlf_files" ]]; then
    fail "CRLF line endings found: $crlf_files"
else
    pass "text files use Unix line endings"
fi

bad_markers='YOURUSER|YOURREPO|momiji-rice-merge\.zip|momiji-clock-pack\.zip|not yet pushed|73-line list|hypr-cursor\.conf|neko-sounds\.conf|scripts/preflight\.sh'
stale_file=$(mktemp "${TMPDIR:-/tmp}/momiji-stale.XXXXXX")
placeholder_file=$(mktemp "${TMPDIR:-/tmp}/momiji-placeholder.XXXXXX")
trap 'rm -f "$stale_file" "$placeholder_file"' EXIT

while IFS= read -r -d '' file; do
    case "$file" in
        *.wav|*.png|*/.git/*|*/scripts/validate-repo.sh) continue ;;
    esac
    if grep -nE "$bad_markers" "$file" >/dev/null 2>&1; then
        printf '%s:\n' "${file#"$ROOT/"}" >>"$stale_file"
        grep -nE "$bad_markers" "$file" >>"$stale_file"
    fi
    if grep -n 'FILL-ME-IN' "$file" >/dev/null 2>&1; then
        printf '%s:\n' "${file#"$ROOT/"}" >>"$placeholder_file"
        grep -n 'FILL-ME-IN' "$file" >>"$placeholder_file"
    fi
done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -print0)

if [[ -s "$stale_file" ]]; then
    fail "stale install markers found:
$(cat "$stale_file")"
else
    pass "no stale install markers or local zip dependencies"
fi

if [[ -s "$placeholder_file" ]]; then
    fail "unresolved placeholder found:
$(cat "$placeholder_file")"
else
    pass "no unresolved FILL-ME-IN placeholders"
fi

boot="$ROOT/boot/arch.conf.template"
luks_count=$(awk '{ n += gsub(/LUKS_UUID_PLACEHOLDER/, "") } END { print n + 0 }' "$boot")
if [[ "$luks_count" -ne 1 ]]; then
    fail "boot template must contain one LUKS UUID placeholder"
elif ! grep -Fq \
    'rd.luks.name=LUKS_UUID_PLACEHOLDER=cryptroot' "$boot"; then
    fail "boot template does not name the encrypted mapping cryptroot"
elif ! grep -Fq 'root=/dev/mapper/cryptroot' "$boot"; then
    fail "boot template does not use the decrypted root mapping"
elif ! grep -Fq 'rd.luks.options=discard' "$boot"; then
    fail "boot template does not pass discards through LUKS for fstrim"
else
    pass "encrypted boot entry structure is valid"
fi

loader="$ROOT/boot/loader.conf"
if grep -Fxq 'editor no' "$loader"; then
    pass "systemd-boot kernel command line editor is disabled"
else
    fail "loader.conf must contain: editor no"
fi

hooks=$(tr '\n' ' ' < \
    "$ROOT/etc/mkinitcpio.conf.d/momiji-encryption.conf")
case "$hooks" in
    *systemd*sd-vconsole*block*sd-encrypt*filesystems*)
        pass "mkinitcpio hook order includes sd-encrypt before filesystems"
        ;;
    *)
        fail "mkinitcpio hook order is missing the systemd encryption path"
        ;;
esac

sddm="$ROOT/etc/sddm.conf.d/10-momiji.conf"
if grep -Fq 'DisplayServer=x11' "$sddm" \
    && grep -Eq '^User=$' "$sddm" \
    && grep -Eq '^Session=$' "$sddm" \
    && grep -Fq 'Relogin=false' "$sddm"; then
    pass "SDDM configuration has a graphical greeter and no autologin"
else
    fail "SDDM configuration is incomplete or enables autologin"
fi

zram="$ROOT/etc/zram-generator.conf"
if grep -Fq '[zram0]' "$zram" \
    && grep -Eq '^zram-size[[:space:]]*=' "$zram"; then
    pass "zram swap configuration exists"
else
    fail "zram configuration is incomplete"
fi

for script in "$ROOT"/scripts/*.sh; do
    [[ -e "$script" ]] || continue
    if bash -n "$script"; then
        pass "Bash syntax: ${script#"$ROOT/"}"
    else
        fail "Bash syntax failed: ${script#"$ROOT/"}"
    fi
done

if command -v fish >/dev/null 2>&1; then
    for fish_file in "$ROOT"/home/fish/*.fish; do
        [[ -e "$fish_file" ]] || continue
        if fish -n "$fish_file"; then
            pass "Fish syntax: ${fish_file#"$ROOT/"}"
        else
            fail "Fish syntax failed: ${fish_file#"$ROOT/"}"
        fi
    done
else
    warn "fish is unavailable, skipping Fish parser checks"
fi

if command -v luac >/dev/null 2>&1; then
    while IFS= read -r -d '' lua_file; do
        if luac -p "$lua_file"; then
            pass "Lua syntax: ${lua_file#"$ROOT/"}"
        else
            fail "Lua syntax failed: ${lua_file#"$ROOT/"}"
        fi
    done < <(find "$ROOT/home" "$ROOT/rice" -type f -name '*.lua' -print0)
else
    warn "luac is unavailable, skipping Lua parser checks"
fi

if command -v python3 >/dev/null 2>&1; then
    if python3 - "$ROOT/rice/fastfetch/config-maple.jsonc" <<'PY'
import json
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = "\n".join(
    line for line in path.read_text(encoding="utf-8").splitlines()
    if not re.match(r"^\s*//", line)
)
json.loads(text)
PY
    then
        pass "fastfetch JSONC parses"
    else
        fail "fastfetch JSONC does not parse"
    fi
else
    warn "python3 is unavailable, skipping JSONC parse check"
fi

if command -v file >/dev/null 2>&1; then
    for wav in "$ROOT"/rice/sounds/*.wav; do
        [[ -e "$wav" ]] || continue
        desc=$(file -b "$wav")
        case "$desc" in
            *WAVE*audio*|*RIFF*WAVE*) pass "WAV asset: ${wav#"$ROOT/"}" ;;
            *) fail "invalid WAV asset ${wav#"$ROOT/"}: $desc" ;;
        esac
    done
else
    warn "file is unavailable, skipping WAV checks"
fi

if $CHECK_ARCH; then
    if ! command -v pacman >/dev/null 2>&1; then
        fail "--arch requires pacman"
    else
        arch_failed=0
        for pkg in "${repo_packages[@]}"; do
            if ! pacman -Si "$pkg" >/dev/null 2>&1; then
                fail "not found in current pacman databases: $pkg"
                arch_failed=1
            fi
        done
        if [[ "$arch_failed" -eq 0 ]]; then
            pass "all packages.txt entries resolve in current pacman databases"
        fi
    fi
fi

package_exists_anywhere() {
    pkg=$1
    if command -v pacman >/dev/null 2>&1 \
        && pacman -Si "$pkg" >/dev/null 2>&1; then
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi
    response=$(curl -fsS --get \
        --data-urlencode 'v=5' \
        --data-urlencode 'type=info' \
        --data-urlencode "arg[]=$pkg" \
        https://aur.archlinux.org/rpc/ 2>/dev/null || true)
    printf '%s' "$response" \
        | grep -Eq '"resultcount"[[:space:]]*:[[:space:]]*[1-9][0-9]*'
}

if $CHECK_AUR; then
    for list in aur-packages.txt rice/fun-packages.txt; do
        while IFS= read -r pkg; do
            if package_exists_anywhere "$pkg"; then
                pass "package resolves: $pkg"
            else
                fail "package not found in pacman or AUR: $pkg"
            fi
        done < <(list_packages "$ROOT/$list")
    done
fi

printf '\nValidation complete: %d failure(s), %d warning(s).\n' \
    "$failures" "$warns"
((failures == 0))
