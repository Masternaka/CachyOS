"""Tests avec commandes simulées ; aucune règle réelle n'est modifiée."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '03 - firewalld_settings.sh'
FAKE = r'''
import json, os, sys
from pathlib import Path
root = Path(os.environ['FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
with (root / 'calls').open('a') as log: log.write(json.dumps([name] + args) + '\n')
if name == 'sudo': os.execvp(args[0], args)
config = json.loads((root / 'config').read_text())
if name == 'systemctl' and not config.get('start_failure'):
    (root / 'running').touch()
if name == 'firewall-cmd':
    if '--state' in args: sys.exit(0 if (root / 'running').exists() else 1)
    if '--get-zones' in args: print('home public work-home'); sys.exit(0)
    if '--get-default-zone' in args: print(config.get('current_zone', 'public')); sys.exit(0)
    if '--add-service=samba' in args and config.get('add_failure'): sys.exit(1)
    if any(arg.startswith('--query-service=') for arg in args) and config.get('query_failure'): sys.exit(1)
if name == 'systemctl' and config.get('start_failure'): sys.exit(1)
'''


class FirewallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.fake = self.root / 'fake'
        self.fake.write_text('#!' + sys.executable + '\n' + FAKE)
        self.fake.chmod(0o755)
        for name in ['firewall-cmd', 'firewall-config', 'firewall-offline-cmd', 'pacman', 'systemctl', 'sudo', 'ufw']:
            (self.bin / name).symlink_to(self.fake)
        self.env = dict(os.environ, FIXTURE=str(self.root), PATH=str(self.bin) + ':' + os.environ['PATH'])

    def run_script(self, *args, config=None, running=True):
        (self.root / 'config').write_text(json.dumps(config or {}))
        if running: (self.root / 'running').touch()
        return subprocess.run(['/bin/bash', str(SCRIPT), *args], env=self.env, text=True, capture_output=True)

    def calls(self):
        path = self.root / 'calls'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def firewall_calls(self):
        return [call[1:] for call in self.calls() if call[0] == 'firewall-cmd']

    def test_both_services_runtime_and_permanent_before_default_change(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.firewall_calls()
        for service in ['ssh', 'samba']:
            for prefix in [[], ['--permanent']]:
                action = prefix + ['--zone=home', '--add-service=' + service]
                self.assertIn(action, calls)
                self.assertIn(prefix + ['--zone=home', '--query-service=' + service], calls)
                self.assertLess(calls.index(action), calls.index(['--set-default-zone=home']))
        self.assertFalse(any('--reload' in call for call in calls))

    def test_custom_zone_and_already_default_still_adds_services(self):
        result = self.run_script('--zone', 'work-home', config={'current_zone': 'work-home'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['--zone=work-home', '--add-service=samba'], self.firewall_calls())
        self.assertNotIn(['--set-default-zone=work-home'], self.firewall_calls())

    def test_installed_but_stopped_gets_started(self):
        result = self.run_script(running=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['systemctl', 'enable', '--now', 'firewalld.service'], self.calls())

    def test_dry_run_only_reads_even_when_initially_stopped(self):
        result = self.run_script('--dry-run', running=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--add-service=ssh', result.stdout)
        self.assertIn('--add-service=samba', result.stdout)
        self.assertTrue(all(call[0] == 'firewall-cmd' and call[1] in ['--state', '--get-default-zone'] for call in self.calls()))

    def test_invalid_zone_stops_before_any_command(self):
        for args in [('--zone', ''), ('--zone', '--dry-run'), ('--zone', 'home public'), ('--zone',), ('--unknown',)]:
            self.assertNotEqual(self.run_script(*args).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_exact_zone_validation(self):
        result = self.run_script('--zone', 'work')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(any(arg.startswith('--add-service=') for arg in call) for call in self.firewall_calls()))

    def test_add_query_and_start_failures_abort(self):
        for config in [{'add_failure': True}, {'query_failure': True}, {'start_failure': True}]:
            with self.subTest(config=config):
                (self.root / 'calls').write_text('')
                result = self.run_script(config=config)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn(['--set-default-zone=home'], self.firewall_calls())


if __name__ == '__main__':
    unittest.main()
