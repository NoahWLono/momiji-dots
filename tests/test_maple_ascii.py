"""Run with: python3 -B -m unittest discover -s tests -v"""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('maple_ascii', ROOT / 'scripts/maple_ascii.py')
maple = importlib.util.module_from_spec(spec)
spec.loader.exec_module(maple)


class JsoncTests(unittest.TestCase):
    def test_preserves_comments_and_modules(self):
        text = '{\n// mine\n"logo": "arch",\n"modules": ["os", "cpu",],\n"display": {"separator": "// : /* not a comment */"},\n}\n'
        result = maple.replace_logo(text, {'type': 'file', 'source': '/tmp/art.txt'})
        self.assertIn('// mine', result)
        self.assertIn('"modules": ["os", "cpu",]', result)
        self.assertEqual(maple.parse_jsonc(result)['display']['separator'], '// : /* not a comment */')

    def test_adds_logo_to_empty_object(self):
        self.assertEqual(maple.parse_jsonc(maple.replace_logo('{/*keep*/}', {'type': 'file'})), {'logo': {'type': 'file'}})

    def test_adds_logo_without_changing_other_values(self):
        source = '{"modules": ["os"], "data": "quoted \\\"text\\\""}'
        out = maple.parse_jsonc(maple.replace_logo(source, {'type': 'file'}))
        self.assertEqual(out['modules'], ['os'])
        self.assertEqual(out['data'], 'quoted "text"')

    def test_duplicate_keys_rejected(self):
        with self.assertRaises(ValueError):
            maple.replace_logo('{"logo": {}, "logo": {}}', {})

    def test_invalid_json_rejected(self):
        for source in ('[]', '{bad}', '{"logo":', '{"x": 1,,}'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                maple.replace_logo(source, {})

    def test_literal_path_quoted(self):
        from shlex import quote, split
        path = "/tmp/Noah's config/$(not-a-command)/maple-ascii.txt"
        result = maple.replace_logo('{}', {'source': quote(path)})
        self.assertEqual(split(maple.parse_jsonc(result)['logo']['source']), [path])


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='maple-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.config = self.base / 'config with spaces'
        self.state = self.base / 'state'
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.config), 'XDG_STATE_HOME': str(self.state)})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.cfg = self.config / 'fastfetch/config.jsonc'
        self.cfg.parent.mkdir(parents=True)
        self.original = '// original\n{"logo": "arch", "modules": ["os", "memory",]}\n'
        self.cfg.write_text(self.original)

    def test_install_and_idempotence(self):
        backup = maple.install(ROOT)
        self.assertTrue(backup.is_dir())
        cfg = maple.parse_jsonc(self.cfg.read_text())
        self.assertEqual(cfg['modules'], ['os', 'memory'])
        self.assertEqual(cfg['logo']['type'], 'file')
        self.assertTrue((self.config / 'fastfetch/maple-ascii.txt').is_file())
        self.assertIsNone(maple.install(ROOT))

    def test_restore_original_and_remove_created_files(self):
        self.cfg.chmod(0o600)
        maple.install(ROOT)
        maple.restore()
        self.assertEqual(self.cfg.read_text(), self.original)
        self.assertEqual(self.cfg.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.config / 'fastfetch/maple-ascii.txt').exists())
        self.assertFalse((self.config / 'fish/conf.d/20-greeting.fish').exists())

    def test_restore_preserves_symlink_destination(self):
        actual = self.base / 'upstream.jsonc'
        self.cfg.rename(actual)
        self.cfg.symlink_to(actual)
        maple.install(ROOT)
        self.assertFalse(self.cfg.is_symlink())
        self.assertEqual(actual.read_text(), self.original)
        maple.restore()
        self.assertTrue(self.cfg.is_symlink())
        self.assertEqual(self.cfg.resolve(), actual)

    def test_invalid_config_makes_no_changes(self):
        self.cfg.write_text('{broken')
        with self.assertRaises(ValueError):
            maple.install(ROOT)
        self.assertFalse((self.config / 'fastfetch/maple-ascii.txt').exists())
        self.assertFalse(self.state.exists())

    def test_restore_refuses_to_overwrite_later_edits(self):
        maple.install(ROOT)
        self.cfg.write_text(self.cfg.read_text() + '// later edit\n')
        with self.assertRaises(ValueError):
            maple.restore()
        self.assertIn('// later edit', self.cfg.read_text())

    def test_ambiguous_config_is_rejected(self):
        (self.config / 'fastfetch/config.json').write_text('{}')
        with self.assertRaises(ValueError):
            maple.install(ROOT)

    def test_existing_json_filename_is_respected(self):
        other = self.cfg.with_suffix('.json')
        self.cfg.rename(other)
        maple.install(ROOT)
        self.assertFalse(self.cfg.exists())
        self.assertEqual(maple.parse_jsonc(other.read_text())['logo']['type'], 'file')

    def test_directory_collision_is_rejected(self):
        (self.config / 'fastfetch/maple-ascii.txt').mkdir()
        with self.assertRaises(ValueError):
            maple.install(ROOT)
        self.assertEqual(self.cfg.read_text(), self.original)


class AssetTests(unittest.TestCase):
    def test_shipped_art(self):
        maple.validate_art((ROOT / 'rice/fastfetch/maple-ascii.txt').read_text())

    def test_bad_art_rejected(self):
        for text in ('\tcat\n', 'cat\x1b[31m\n', '$9cat\n', 'x' * 46 + '\n', '', 'no newline'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                maple.validate_art(text)

    @unittest.skipUnless(shutil.which('fish'), 'Fish is not installed in this test environment')
    def test_fish_syntax(self):
        for path in ('scripts/momiji-maple.fish', 'home/fish/20-greeting.fish'):
            subprocess.run(['fish', '-n', str(ROOT / path)], check=True)

    @unittest.skipUnless(shutil.which('fastfetch'), 'Fastfetch is not installed in this test environment')
    def test_real_fastfetch_render(self):
        with tempfile.TemporaryDirectory() as temp:
            import json
            import shlex
            cfg = maple.parse_jsonc((ROOT / 'rice/fastfetch/config-maple-ascii.jsonc').read_text())
            cfg['logo']['source'] = shlex.quote(str(ROOT / 'rice/fastfetch/maple-ascii.txt'))
            cfg['modules'] = ['title']
            path = Path(temp) / 'config.jsonc'
            path.write_text(json.dumps(cfg))
            result = subprocess.run(['fastfetch', '--config', str(path), '--pipe', 'false', '--show-errors'], capture_output=True, text=True, check=True)
            import re
            rendered = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', result.stdout)
            self.assertIn('MAPLE NEKOKAMI', rendered)
            self.assertNotIn('$1', rendered)
            self.assertFalse(result.stderr.strip(), result.stderr)


if __name__ == '__main__':
    unittest.main()
