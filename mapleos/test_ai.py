"""Offline tests. Provider-network integration is intentionally not exercised with real credentials."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('maple_ai', Path(__file__).with_name('maple_ai.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class AgentTests(unittest.TestCase):
    def test_https(self):
        self.assertEqual(m.validate_endpoint('https://example.org/v1/'), 'https://example.org/v1')
    def test_loopback(self):
        for url in ('http://127.0.0.1:11434/v1', 'http://[::1]:8080/v1', 'http://localhost:1234/v1'):
            self.assertEqual(m.validate_endpoint(url), url)
    def test_bad_endpoints(self):
        for url in ('http://example.org/v1', 'file:///etc/passwd', 'https://a:b@example.org/v1', 'https://example.org/?key=secret', 'https://example.org/#x'):
            with self.assertRaises(ValueError): m.validate_endpoint(url)
    def test_terminal_controls(self):
        self.assertEqual(m.clean('\x1b[31mhello\x1b[0m\x00'), 'hello')
    def test_sandbox_namespace(self):
        args = m.sandbox_argv(Path('/home/u/Maple/Workspaces/demo'), 'pwd')
        for item in ('--unshare-all', '--new-session', '--clearenv', '--cap-drop'):
            self.assertIn(item, args)
        self.assertNotIn('--share-net', args)
        self.assertNotIn('/etc', args)
        self.assertNotIn('/run', args)
        self.assertNotIn('--ro-bind-try', args)
        self.assertEqual(args.count('--bind'), 1)
    def test_empty_command(self):
        with self.assertRaises(ValueError): m.sandbox_argv(Path('/tmp/a'), '')
    def test_root_refused(self):
        with patch.object(m.os, 'geteuid', return_value=0):
            with self.assertRaises(ValueError): m.sandbox(Path('/tmp/a'), 'true')
    def test_workspace_traversal(self):
        for name in ('../secrets', '/etc', '.', '..', 'a/b', '-bad', 'x'*65):
            with self.assertRaises(ValueError): m.workspace_path(name)
    def test_workspace_creation(self):
        with tempfile.TemporaryDirectory() as home, patch.object(m.Path, 'home', return_value=Path(home)):
            p = m.workspace_path('demo')
            self.assertEqual(p, Path(home) / 'Maple/Workspaces/demo')
            self.assertTrue(p.is_dir())
    def test_workspace_symlink(self):
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as outside, patch.object(m.Path, 'home', return_value=Path(home)):
            (Path(home)/'Maple').symlink_to(outside)
            with self.assertRaises(ValueError): m.workspace_path('demo')
    def test_redirects_refused(self):
        with self.assertRaises(ValueError): m.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://elsewhere')
    def test_tool_schema(self):
        schema = m.TOOL['function']['parameters']
        self.assertFalse(schema['additionalProperties'])
        self.assertEqual(schema['required'], ['command'])

if __name__ == '__main__': unittest.main()
