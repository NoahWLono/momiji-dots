#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run in the documented disposable privileged Arch container.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'x86_64 builder required.' >&2; exit 1; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${MAPLE_BUILD_DIR:-/build}
OUT=${MAPLE_OUT_DIR:-$ROOT/mapleos-out}
mkdir -p "$BUILD" "$OUT"
[[ ! -e $BUILD/profile && ! -e $BUILD/work ]] || { echo 'Use an empty build directory.' >&2; exit 1; }
python -m unittest discover -s "$ROOT/mapleos" -p 'test_*.py' -v
for file in "$ROOT"/mapleos/*.sh; do bash -n "$file"; done
python "$ROOT/mapleos/profile.py" --root "$BUILD/profile" --upstream "$ROOT"
mapfile -t packages <"$BUILD/profile/packages.x86_64"
pacman -Si "${packages[@]}" >"$OUT/package-resolution.txt"
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
h = hashlib.file_digest(iso.open('rb'), 'sha256').hexdigest()
(out/'ISO-SHA256SUMS').write_text(f'{h}  {iso.name}\n')
commit = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
assets = {name:hashlib.file_digest((root/name).open('rb'),'sha256').hexdigest() for name in ['wallpapers/maple.png','rice/fastfetch/maple-ascii.txt']}
(out/'build-info.json').write_text(json.dumps({'version':(root/'mapleos/VERSION').read_text().strip(),'source_commit':commit,'iso':iso.name,'bytes':iso.stat().st_size,'sha256':h,'momiji_asset_baseline':'654d2ddf4c45dd40afece7a52b4b93f4e7445d63','asset_sha256':assets,'archiso':subprocess.check_output(['pacman','-Q','archiso'],text=True).strip(),'source_date_epoch':os.environ.get('SOURCE_DATE_EPOCH'),'reproducibility':'Source-pinned; rolling Arch package versions recorded. Not byte-for-byte reproducibility certified.','release_status':'Unverified build until boot-tests.json is present and passing.'},indent=2)+'\n')
PY
cp "$ROOT/mapleos/README.md" "$ROOT/mapleos/THIRD_PARTY.md" "$OUT/"
# Source archive deliberately excludes the parent repository's unrelated configuration.
tar -czf "$OUT/mapleos-source.tar.gz" -C "$ROOT" mapleos .github/workflows/mapleos.yml wallpapers/maple.png rice/fastfetch/maple-ascii.txt home/caelestia/hypr-user.lua home/caelestia/hypr-vars.lua
chmod -R a+rX "$OUT"
