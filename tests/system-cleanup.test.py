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
# The one path system-cleanup does not take from HOME. Its removal goes through
# the rm double, so nothing is touched, but whether it is attempted depends on
# the host.
ARCHBUILD = Path('/var/lib/archbuild')
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
elif name == 'systemctl':
    # The runner's cgroup, relative to /sys/fs/cgroup; unset means no runner.
    if 'RUNNER_CGROUP' not in os.environ:
        sys.exit(1)
    print(os.environ['RUNNER_CGROUP'])
elif name == 'pgrep':
    sys.exit(1)  # no devtools build running
elif name == 'rm':
    pass  # logged only; nothing is removed
elif name in ('find', 'paru'):
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
                     'kondo', 'systemctl', 'pgrep',
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
        self.doorman = self.home / '.cache/doorman-ci/target'
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
        return [call for call in self.calls
                if call[0] not in ('df', 'wpctl', 'rofi', 'ghostty', 'systemctl', 'pgrep')]

    def expected_operations(self, doorman=False):
        archbuild = [
            ['sudo', 'rm', '-rf', '--one-file-system', '--', str(ARCHBUILD)],
            ['rm', '-rf', '--one-file-system', '--', str(ARCHBUILD)],
        ] if ARCHBUILD.exists() else []
        return [
            ['sudo', 'paccache', '--remove', '--keep', '1'],
            ['paccache', '--remove', '--keep', '1'],
            ['sudo', 'paccache', '--remove', '--uninstalled', '--keep', '0'],
            ['paccache', '--remove', '--uninstalled', '--keep', '0'],
            *archbuild,
            ['docker', 'system', 'prune', '--all', '--force'],
            ['docker', 'volume', 'prune', '--force'],
            ['pnpm', 'store', 'prune'], ['npm', 'cache', 'verify'],
            ['go', 'clean', '-cache', '-testcache'], ['tldr', '--clear-cache'],
            ['kondo', '--all', str(self.home)],
            *([['rm', '-rf', '--', str(self.doorman)]] if doorman else []),
        ]

    def assert_cleanup_operations(self, doorman=False):
        self.assertEqual(self.operations(), self.expected_operations(doorman))
        for path in self.sentinels:
            self.assertEqual(path.read_text(), 'preserve me')

    def test_cleanup_operations(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('all requested steps succeeded', result.stdout)
        self.assert_cleanup_operations()

    def test_doorman_ci_cache_is_removed(self):
        self.doorman.mkdir(parents=True)
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_cleanup_operations(doorman=True)

    def test_doorman_ci_cache_kept_while_runner_busy(self):
        cgroup = self.root / 'runner cgroup'
        cgroup.mkdir()
        (cgroup / 'cgroup.procs').write_text('100\n200\n')
        self.doorman.mkdir(parents=True)
        # /sys/fs/cgroup/../../.. is /, so this lands on the fake cgroup.
        result = self.run_script(RUNNER_CGROUP='/../../..' + str(cgroup))
        self.assertEqual(result.returncode, 1)
        self.assert_cleanup_operations()
        self.assertIn('A Forgejo CI job is running', result.stderr)
        self.assertIn('Doorman CI build cache (exit 1)', result.stderr)

    def test_partial_failures_continue_and_summarize(self):
        result = self.run_script(FAIL_COMMANDS='paccache,docker')
        self.assertEqual(result.returncode, 1)
        self.assert_cleanup_operations()
        summary = result.stderr.split('Cleanup incomplete:')[1]
        self.assertIn('4 step(s) failed', summary)
        self.assertIn('Pacman archives (keep one version) (exit 7)', summary)
        self.assertIn('Pacman archives of uninstalled packages (exit 7)', summary)
        self.assertIn('Stopped containers and unused Docker images, networks and build cache (exit 7)', summary)
        self.assertIn('Unused anonymous Docker volumes (exit 7)', summary)
        self.assertNotIn('all requested steps succeeded', result.stdout)

    def test_denied_sudo_continues(self):
        result = self.run_script(FAIL_COMMANDS='sudo')
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(call[0] == 'paccache' for call in self.calls))
        self.assertIn(['tldr', '--clear-cache'], self.calls)
        self.assertIn('Pacman archives (keep one version) (exit 7)', result.stderr)
        self.assertIn('Pacman archives of uninstalled packages (exit 7)', result.stderr)

    def test_missing_tool_is_failure(self):
        (self.bin / 'pnpm').unlink()
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn('Unreferenced pnpm store packages (exit 127)', result.stderr)
        self.assertIn(['tldr', '--clear-cache'], self.calls)

    def test_help_and_invalid_args_have_no_effect(self):
        for args, status in ((('--help',), 0), (('--force',), 2), (('caches',), 2),
                             (('docker-data',), 2)):
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

    def test_menu_cleanup_selection(self):
        choice = 'Disk: Clean caches, build artifacts and Docker data'
        result = self.run_script(menu=True, MENU_CHOICE=choice, input='\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(choice, json.loads(Path(self.env['MENU_ROWS']).read_text()))
        self.assert_cleanup_operations()

if __name__ == '__main__':
    unittest.main(verbosity=2)
