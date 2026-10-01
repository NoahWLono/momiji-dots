#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run in the documented disposable privileged Arch container.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'x86_64 builder required.' >&2; exit 1; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${MAPLE_BUILD_DIR:-/build}
OUT=${MAPLE_OUT_DIR:-$ROOT/mapleos-out}
mkdir -p "$BUILD" "$OUT"
[[ ! -e $BUILD/profile && ! -e $BUILD/work ]] || { echo 'Use an empty build directory.' >&2; exit 1; }
pacman -S --needed --noconfirm git
MAPLE_SOURCE_COMMIT=$(git -c "safe.directory=$ROOT" -C "$ROOT" rev-parse HEAD)
export MAPLE_SOURCE_COMMIT
python -m unittest discover -s "$ROOT/mapleos" -p 'test_*.py' -v
for file in "$ROOT"/mapleos/*.sh; do bash -n "$file"; done
python "$ROOT/mapleos/profile.py" --root "$BUILD/profile" --upstream "$ROOT"
# Faster preview rebuilds. Linux's squashfs reader supports this compression;
# the publication step splits the ISO if it exceeds GitHub's per-asset size limit.
cat >>"$BUILD/profile/profiledef.sh" <<'EOF'
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-processors' '2')
EOF
mapfile -t packages <"$BUILD/profile/packages.x86_64"
pacman -Si "${packages[@]}" >"$OUT/package-resolution.txt"
tar -czf "$OUT/mapleos-source.tar.gz" -C "$ROOT" mapleos .github/workflows/mapleos.yml wallpapers/maple.png rice/fastfetch/maple-ascii.txt home/caelestia/hypr-user.lua home/caelestia/hypr-vars.lua
tar -czf "$OUT/mapleos-generated-profile.tar.gz" -C "$BUILD" profile
mkarchiso -v -w "$BUILD/work" -o "$OUT" "$BUILD/profile" 2>&1 | tee "$OUT/build.log"
image_root="$BUILD/work/x86_64/airootfs"
test -d "$image_root/var/lib/pacman/local"
pacman --root "$image_root" -Q >"$OUT/packages.txt"
pacman --root "$image_root" -Qi >"$OUT/package-metadata.txt"
python - "$OUT" "$ROOT" <<'PY'
import hashlib, json, os, subprocess, sys
from pathlib import Path
out, root = map(Path, sys.argv[1:])
isos = list(out.glob('*.iso'))
assert len(isos) == 1, isos
iso = isos[0]
with iso.open('rb') as f: h = hashlib.file_digest(f, 'sha256').hexdigest()
(out/'ISO-SHA256SUMS').write_text(f'{h}  {iso.name}\n')
assets = {name:hashlib.file_digest((root/name).open('rb'),'sha256').hexdigest() for name in ['wallpapers/maple.png','rice/fastfetch/maple-ascii.txt']}
(out/'build-info.json').write_text(json.dumps({'version':(root/'mapleos/VERSION').read_text().strip(),'source_commit':os.environ['MAPLE_SOURCE_COMMIT'],'iso':iso.name,'bytes':iso.stat().st_size,'sha256':h,'momiji_asset_baseline':'654d2ddf4c45dd40afece7a52b4b93f4e7445d63','asset_sha256':assets,'archiso':subprocess.check_output(['pacman','-Q','archiso'],text=True).strip(),'source_date_epoch':os.environ.get('SOURCE_DATE_EPOCH'),'rootfs_compression':'zstd level 15','reproducibility':'Source-pinned; rolling Arch package versions recorded. Not byte-for-byte reproducibility certified.','release_status':'Unverified build until boot-tests.json is present and passing.'},indent=2)+'\n')
PY
cp "$ROOT/mapleos/README.md" "$ROOT/mapleos/THIRD_PARTY.md" "$OUT/"
chmod -R a+rX "$OUT"
