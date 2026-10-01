#!/usr/bin/env python3
"""Local-only Maple ASCII installer/editor. Python standard library only."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
# Match strings FIRST so comment-looking text inside them survives.
TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/')
TRAILING = re.compile(r'"(?:\\.|[^"\\])*"|,(?=\s*[}\]])')


def unique_object(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise ValueError(f"Duplicate JSON key: {key}")
        obj[key] = value
    return obj


def clean_jsonc(text: str) -> str:
    """Remove comments/trailing commas without changing character offsets."""
    text = TOKENS.sub(lambda m: m[0] if m[0].startswith('"') else
                      re.sub(r'[^\r\n]', ' ', m[0]), text)
    return TRAILING.sub(lambda m: ' ' if m[0] == ',' else m[0], text)


def parse_jsonc(text: str) -> dict:
    value = json.loads(clean_jsonc(text), object_pairs_hook=unique_object)
    if not isinstance(value, dict):
        raise ValueError("Fastfetch configuration must be a JSON object.")
    return value


def replace_logo(text: str, logo: dict) -> str:
    """Replace just the logo value, preserving unrelated settings and comments."""
    parsed = parse_jsonc(text)
    clean = clean_jsonc(text)
    decoder = json.JSONDecoder()
    position = clean.index('{') + 1
    start = position
    value_text = json.dumps(logo, indent=4, ensure_ascii=False).replace('\n', '\n    ')
    while position < len(clean):
        while position < len(clean) and clean[position] in ' \t\r\n,':
            position += 1
        if clean[position] == '}':
            break
        key, position = decoder.raw_decode(clean, position)
        position = clean.index(':', position) + 1
        while clean[position].isspace():
            position += 1
        value_start = position
        _, position = decoder.raw_decode(clean, position)
        if key == 'logo':
            result = text[:value_start] + value_text + text[position:]
            parse_jsonc(result)
            return result
    comma = ',' if parsed else ''
    result = text[:start] + '\n    "logo": ' + value_text + comma + '\n' + text[start:]
    parse_jsonc(result)
    return result


def validate_art(text: str) -> None:
    # Editable literal text plus documented Fastfetch $1..$4 color markers.
    plain = re.sub(r'\$[1-4]', '', text)
    if not plain.strip() or not text.endswith('\n'):
        raise ValueError("The art must be nonempty and end with a newline.")
    if any(ch != '\n' and not (' ' <= ch <= '~') for ch in plain) or '$' in plain:
        raise ValueError("Use printable ASCII, LF newlines and only $1..$4 color tags. No tabs/escapes.")
    if len(plain.splitlines()) > 35 or max(map(len, plain.splitlines())) > 45:
        raise ValueError("Keep the portrait within 45 columns and 35 rows, excluding color tags.")


def xdg(name: str, fallback: str) -> Path:
    value = os.environ.get(name)
    # XDG paths must be absolute; ignore invalid relative values.
    return Path(value) if value and Path(value).is_absolute() else Path.home() / fallback


def locations() -> tuple[Path, Path]:
    return xdg('XDG_CONFIG_HOME', '.config'), xdg('XDG_STATE_HOME', '.local/state') / 'momiji/maple-ascii'


def atomic_write(path: Path, data: bytes, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
        os.chmod(tmp, mode)
        os.replace(tmp, path)  # Replace a symlink itself; never modify its destination.
    finally:
        Path(tmp).unlink(missing_ok=True)


def restore_entries(folder: Path, entries: list[dict]) -> None:
    for entry in reversed(entries):
        target = Path(entry['target'])
        if entry['kind'] == 'file':
            atomic_write(target, (folder / entry['saved']).read_bytes(), entry['mode'])
        elif entry['kind'] == 'symlink':
            target.unlink(missing_ok=True)
            target.symlink_to(entry['link'])
        else:
            target.unlink(missing_ok=True)


def install(root: Path = ROOT) -> Path | None:
    config, state = locations()
    asset = config / 'fastfetch/maple-ascii.txt'
    candidates = [config / 'fastfetch/config.jsonc', config / 'fastfetch/config.json']
    existing = [p for p in candidates if p.exists() or p.is_symlink()]
    if len(existing) > 1:
        raise ValueError("Both config.json and config.jsonc exist. Keep one active config before installing.")
    destination = existing[0] if existing else candidates[0]
    art = (root / 'rice/fastfetch/maple-ascii.txt').read_text(encoding='utf-8')
    validate_art(art)
    logo = parse_jsonc((root / 'rice/fastfetch/config-maple-ascii.jsonc').read_text())['logo']
    if logo.get('type') != 'file':
        raise ValueError("Maple ASCII requires logo.type = file.")
    # Fastfetch expands source using wordexp on Unix. Quote the literal path.
    logo['source'] = shlex.quote(str(asset))
    current = destination.read_text(encoding='utf-8') if destination.exists() else '{}\n'
    updated = replace_logo(current, logo)
    planned = {
        asset: art.encode(),
        destination: updated.encode(),
        config / 'fish/conf.d/20-greeting.fish': (root / 'home/fish/20-greeting.fish').read_bytes(),
    }
    changes = {}
    for target, data in planned.items():
        if target.exists() and not target.is_file():
            raise ValueError(f"Expected a regular file, not a directory: {target}")
        if target.is_symlink() or not target.exists() or target.read_bytes() != data:
            changes[target] = data
    if not changes:
        print('Maple is already installed. Nothing changed. :3')
        return None

    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = Path(tempfile.mkdtemp(prefix='backup-', dir=state))
    entries = []
    for index, (target, data) in enumerate(changes.items()):
        entry = {'target': str(target), 'installed_sha256': hashlib.sha256(data).hexdigest()}
        if target.is_symlink():
            entry.update(kind='symlink', link=os.readlink(target))
        elif target.exists():
            name = str(index)
            shutil.copy2(target, backup / name)
            entry.update(kind='file', saved=name, mode=target.stat().st_mode & 0o777)
        else:
            entry.update(kind='absent')
        entries.append(entry)
    previous = (state / 'latest').read_text() if (state / 'latest').exists() else ''
    manifest = {'entries': entries, 'previous': previous}
    atomic_write(backup / 'manifest.json', json.dumps(manifest, indent=2).encode(), 0o600)
    written = []
    try:
        for entry, (target, data) in zip(entries, changes.items()):
            atomic_write(target, data, entry.get('mode', 0o644))
            written.append(entry)
        atomic_write(state / 'latest', backup.name.encode(), 0o600)
    except OSError:
        restore_entries(backup, written)
        raise
    print(f'Maple installed. Backup: {backup}')
    print('Your Fastfetch modules and unrelated settings are preserved.')
    print('Open a new Fish terminal to load the greeting.')
    return backup


def restore() -> None:
    _, state = locations()
    pointer = state / 'latest'
    if not pointer.exists():
        raise ValueError('No Maple installation backup is available.')
    name = pointer.read_text()
    if Path(name).name != name or not name.startswith('backup-'):
        raise ValueError('Invalid backup pointer.')
    backup = state / name
    manifest = json.loads((backup / 'manifest.json').read_text())
    # Do not silently discard edits made after installation.
    for entry in manifest['entries']:
        target = Path(entry['target'])
        if target.is_symlink() or not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != entry['installed_sha256']:
            raise ValueError(f'Changed since install: {target}. Save your edits and restore manually from {backup}.')
    restore_entries(backup, manifest['entries'])
    if manifest['previous']:
        atomic_write(pointer, manifest['previous'].encode(), 0o600)
    else:
        pointer.unlink()
    print(f'Restored the files from: {backup}')
    print('Open a new Fish terminal to reload the previous greeting.')


def preview() -> None:
    art_path = ROOT / 'rice/fastfetch/maple-ascii.txt'
    text = art_path.read_text()
    validate_art(text)
    if not shutil.which('fastfetch'):
        print(re.sub(r'\$[1-4]', '', text), end='')
        print('\nInstall fastfetch for a colored system-info preview.', file=sys.stderr)
        return
    cfg = parse_jsonc((ROOT / 'rice/fastfetch/config-maple-ascii.jsonc').read_text())
    cfg['logo']['source'] = shlex.quote(str(art_path))
    with tempfile.TemporaryDirectory(prefix='momiji-maple-') as directory:
        path = Path(directory) / 'config.jsonc'
        path.write_text(json.dumps(cfg))
        args = ['fastfetch', '--config', str(path)]
        if shutil.get_terminal_size().columns < 95:
            args += ['--logo-position', 'top']
        subprocess.run(args, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', default='preview', choices=['preview', 'install', 'edit', 'colors', 'restore'])
    parser.add_argument('--no-preview', action='store_true', help='Skip the post-install preview.')
    args = parser.parse_args()
    try:
        if args.action == 'preview':
            preview()
            return 0
        if hasattr(os, 'geteuid') and os.geteuid() == 0:
            raise ValueError('Run as your normal user, not root. No sudo is needed.')
        if args.action == 'restore':
            restore()
            return 0
        if not shutil.which('fastfetch'):
            raise ValueError('Install fastfetch first: sudo pacman -S --needed fastfetch')
        if args.action in ('edit', 'colors'):
            filename = 'maple-ascii.txt' if args.action == 'edit' else 'config-maple-ascii.jsonc'
            editor = os.environ.get('VISUAL') or os.environ.get('EDITOR')
            if not editor:
                editor = next((name for name in ('vim', 'nvim', 'nano', 'vi') if shutil.which(name)), '')
            command = shlex.split(editor)
            if not command:
                raise ValueError('Set VISUAL or EDITOR to an installed editor, for example vim.')
            subprocess.run(command + [str(ROOT / 'rice/fastfetch' / filename)], check=True)
        install()
        if not args.no_preview:
            preview()
        return 0
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'Maple: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
