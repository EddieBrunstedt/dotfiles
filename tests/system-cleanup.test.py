#!/usr/bin/env python3
"""F05 regressions: isolated PATH and HOME; no real cleanup or desktop commands."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Also support verifying a staged copy before installation.
SCRIPTS = ROOT / '.local/bin' if (ROOT / '.local/bin/system-cleanup').exists() else Path(__file__).parent

DOUBLE = r'''
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['CALL_LOG'], 'a') as stream:
    stream.write(json.dumps([name, *args]) + '\n')
if name in os.environ.get('FAIL_COMMANDS', '').split(','):
    sys.exit(7)
if name == 'sudo':
    sys.exit(subprocess.run(args).returncode)
if name == 'df':
    print('Filesystem 1024-blocks Used Available Capacity Mounted on')
    print('/dev/test 10000 1000 9000 10% /')
elif name == 'rofi':
    rows = sys.stdin.read().splitlines()
    pathlib.Path(os.environ['MENU_ROWS']).write_text(json.dumps(rows))
    if os.environ.get('ROFI_CANCEL') == '1':
        sys.exit(1)
    print(os.environ.get('MENU_CHOICE', ''))
elif name == 'ghostty':
    assert args[:3] == ['-e', 'sh', '-c'], args
    sys.exit(subprocess.run(args[1:]).returncode)
elif name in ('rm', 'find', 'paru'):
    sys.exit('Forbidden broad cleanup command')
'''


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-f05-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.home = self.root / 'home with spaces'
        (self.home / '.local/bin').mkdir(parents=True)
        for name in ('system-cleanup', 'system-menu'):
            shutil.copy2(SCRIPTS / name, self.home / '.local/bin' / name)
        self.cleanup = self.home / '.local/bin/system-cleanup'
        self.menu = self.home / '.local/bin/system-menu'
        # Only these harmless utilities can reach the host. All mutators are
        # doubles, and no host PATH fallback is present, including under sudo.
        for name in ('sh', 'awk', 'numfmt', 'sed', 'wc'):
            (self.bin / name).symlink_to(shutil.which(name))
        for name in ('sudo', 'paccache', 'docker', 'pnpm', 'npm', 'go', 'tldr',
                     'df', 'wpctl', 'rofi', 'ghostty', 'rm', 'find', 'paru'):
            path = self.bin / name
            path.write_text(f'#!{sys.executable}\n' + DOUBLE)
            path.chmod(0o755)
        self.log = self.root / 'calls.jsonl'
        self.env = {
            'PATH': str(self.bin), 'HOME': str(self.home), 'LC_ALL': 'C',
            'CALL_LOG': str(self.log), 'MENU_ROWS': str(self.root / 'rows.json'),
            'XDG_CACHE_HOME': str(self.home / 'custom cache'),
        }
        self.sentinels = []
        for folder in (self.home / '.cache/paru/clone/work', Path(self.env['XDG_CACHE_HOME']) / 'app'):
            folder.mkdir(parents=True)
            path = folder / 'unfinished-work'
            path.write_text('preserve me')
            self.sentinels.append(path)

    def run_script(self, *args, menu=False, input='', **env):
        result = subprocess.run(
            [str(self.bin / 'sh'), str(self.menu if menu else self.cleanup), *args],
            env=self.env | env, input=input, text=True, capture_output=True, timeout=10,
        )
        self.calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result

    def operations(self):
        return [call for call in self.calls if call[0] not in ('df', 'wpctl', 'rofi', 'ghostty')]

    def assert_cache_operations(self):
        self.assertEqual(self.operations(), [
            ['sudo', 'paccache', '--remove', '--keep', '3'],
            ['paccache', '--remove', '--keep', '3'],
            ['docker', 'builder', 'prune', '--all', '--force'],
            ['pnpm', 'store', 'prune'], ['npm', 'cache', 'verify'],
            ['go', 'clean', '-cache', '-testcache'], ['tldr', '--clear-cache'],
        ])
        for path in self.sentinels:
            self.assertEqual(path.read_text(), 'preserve me')

    def test_default_and_explicit_cache_operations(self):
        for args in ((), ('caches',)):
            with self.subTest(args=args):
                self.log.unlink(missing_ok=True)
                result = self.run_script(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('all requested steps succeeded', result.stdout)
                self.assert_cache_operations()

    def test_partial_failures_continue_and_summarize(self):
        result = self.run_script(FAIL_COMMANDS='paccache,docker')
        self.assertEqual(result.returncode, 1)
        self.assert_cache_operations()
        summary = result.stderr.split('Cleanup incomplete:')[1]
        self.assertIn('2 step(s) failed', summary)
        self.assertIn('Pacman archives (keep three versions) (exit 7)', summary)
        self.assertIn('Unused Docker build cache (exit 7)', summary)
        self.assertNotIn('all requested steps succeeded', result.stdout)

    def test_denied_sudo_continues(self):
        result = self.run_script(FAIL_COMMANDS='sudo')
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(call[0] == 'paccache' for call in self.calls))
        self.assertIn(['tldr', '--clear-cache'], self.calls)
        self.assertIn('1 step(s) failed', result.stderr)

    def test_missing_tool_is_failure(self):
        (self.bin / 'pnpm').unlink()
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn('Unreferenced pnpm store packages (exit 127)', result.stderr)
        self.assertIn(['tldr', '--clear-cache'], self.calls)

    def test_docker_cancel_and_eof_do_nothing(self):
        for answer in ('', '\n', 'n\n', 'yes\n', 'DELETE\n', ' delete\n', 'delete \n', 'delete'):
            with self.subTest(answer=answer):
                result = self.run_script('docker-data', input=answer)
                self.assertEqual(result.returncode, 0)
                self.assertIn('Cancelled', result.stdout)
                self.assertEqual(self.calls, [])

    def test_docker_confirmation_only_runs_broad_prune(self):
        result = self.run_script('docker-data', input='delete\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.operations(), [['docker', 'system', 'prune', '--all', '--force']])
        self.assertIn('writable layers', result.stdout)
        self.assertIn('Volumes are not pruned', result.stdout)

    def test_docker_failure_is_reported(self):
        result = self.run_script('docker-data', input='delete\n', FAIL_COMMANDS='docker')
        self.assertEqual(result.returncode, 1)
        self.assertIn('1 step(s) failed', result.stderr)
        self.assertIn('Stopped containers and unused Docker images', result.stderr)

    def test_help_and_invalid_args_have_no_effect(self):
        for args, status in ((('--help',), 0), (('--force',), 2), (('caches', 'docker-data'), 2)):
            with self.subTest(args=args):
                result = self.run_script(*args)
                self.assertEqual(result.returncode, status)
                self.assertEqual(self.calls, [])

    def test_menu_cancel_empty_and_unknown_selection(self):
        for env in ({'ROFI_CANCEL': '1'}, {}, {'MENU_CHOICE': 'Disk: Reclaim space'}):
            with self.subTest(env=env):
                self.log.unlink(missing_ok=True)
                result = self.run_script(menu=True, **env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(any(call[0] == 'ghostty' for call in self.calls))
                self.assertEqual(self.operations(), [])

    def test_menu_cache_selection(self):
        choice = 'Disk: Clean package and build caches'
        result = self.run_script(menu=True, MENU_CHOICE=choice, input='\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(choice, json.loads(Path(self.env['MENU_ROWS']).read_text()))
        self.assert_cache_operations()

    def test_menu_docker_selection_still_requires_confirmation(self):
        choice = 'Docker: Delete stopped containers and unused images'
        for answer, expected in (('\n\n', []), ('delete\n\n', [['docker', 'system', 'prune', '--all', '--force']])):
            with self.subTest(answer=answer):
                self.log.unlink(missing_ok=True)
                result = self.run_script(menu=True, MENU_CHOICE=choice, input=answer)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(choice, json.loads(Path(self.env['MENU_ROWS']).read_text()))
                self.assertEqual(self.operations(), expected)


if __name__ == '__main__':
    unittest.main(verbosity=2)
