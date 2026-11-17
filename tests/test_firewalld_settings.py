"""Pare-feu simulé dans une fixture ; aucun accès aux règles ni à /etc réels."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '02 - firewalld_settings.sh'
FAKE = r'''
import json, os, sys, tempfile
from pathlib import Path
root = Path(os.environ['FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
config = json.loads((root / 'config').read_text())
with (root / 'calls').open('a') as log: log.write(json.dumps([name] + args) + '\n')
state_path = root / 'state'
state = json.loads(state_path.read_text())
if name == 'mktemp':
    if config.get('backup_failure'): sys.exit(1)
    print(tempfile.mkdtemp(prefix='snapshot-', dir=root)); sys.exit(0)
if name == 'systemctl':
    if config.get('unit_failure'): sys.exit(1)
    if args[1] == 'firewalld.service':
        print('LoadState=loaded\nActiveState=' + ('active' if config.get('running', True) else 'inactive'))
    else:
        print('LoadState=' + ('loaded' if config.get('ufw') else 'not-found'))
        print('ActiveState=' + config.get('ufw_active', 'inactive'))
        print('UnitFileState=' + config.get('ufw_enabled', 'disabled'))
    sys.exit(0)
if name == 'firewall-cmd':
    permanent = '--permanent' in args
    key = 'permanent' if permanent else 'runtime'
    if '--state' in args: sys.exit(0 if config.get('running', True) else 1)
    if '--get-zones' in args: print('home public work-home'); sys.exit(0)
    if '--get-default-zone' in args:
        reads = state.get('reads', 0) + 1; state['reads'] = reads
        state_path.write_text(json.dumps(state))
        print('work-home' if config.get('concurrent') and reads > 1 else state['zone']); sys.exit(0)
    if '--list-all-zones' in args:
        if config.get('inventory_failure'): sys.exit(1)
        print(json.dumps(state)); sys.exit(0)
    service = next((a.split('=', 1)[1] for a in args if '-service=' in a), '')
    if any(a.startswith('--query-service=') for a in args):
        if config.get('query_failure'): sys.exit(2)
        sys.exit(0 if service in state[key] else 1)
    if any(a.startswith('--add-service=') for a in args):
        if service == config.get('add_failure'): sys.exit(1)
        if not config.get('ignore_add') and service not in state[key]: state[key].append(service)
    if any(a.startswith('--remove-service=') for a in args) and service in state[key]: state[key].remove(service)
    if any(a.startswith('--set-default-zone=') for a in args):
        if config.get('zone_failure') and args[-1].endswith('home'): sys.exit(1)
        state['zone'] = args[-1].split('=', 1)[1]
    state_path.write_text(json.dumps(state)); sys.exit(0)
sys.exit(9)
'''


class FirewallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "scripts").mkdir()
        (self.root / "scripts/bilan.sh").write_text((SCRIPT.parent / "scripts/bilan.sh").read_text())
        self.bin = self.root / 'bin'; self.bin.mkdir()
        fake = self.root / 'fake'; fake.write_text('#!' + sys.executable + '\n' + FAKE); fake.chmod(0o755)
        for name in ['firewall-cmd', 'systemctl', 'mktemp']:
            (self.bin / name).symlink_to(fake)
        self.config_dir = self.root / 'firewalld'; self.config_dir.mkdir()
        (self.config_dir / 'custom.xml').write_text('configuration personnelle')
        self.script = self.root / 'script.sh'
        source = SCRIPT.read_text().replace('CONFIG_DIR=/etc/firewalld', 'CONFIG_DIR=' + shlex.quote(str(self.config_dir)))
        source = source.replace('[[ $EUID -eq 0 ]]', '[[ 1 -eq 1 ]]')
        self.script.write_text(source)
        self.env = dict(os.environ, FIXTURE=str(self.root), PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.initial = {'zone': 'public', 'runtime': [], 'permanent': []}
        self.reset()

    def reset(self):
        (self.root / 'state').write_text(json.dumps(self.initial))
        (self.root / 'calls').write_text('')

    def run_script(self, *args, config=None, answer='o\n', original=False):
        (self.root / 'config').write_text(json.dumps(config or {}))
        return subprocess.run(['/bin/bash', str(SCRIPT if original else self.script), *args], env=self.env,
                              input=answer, text=True, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in (self.root / 'calls').read_text().splitlines()]

    def state(self):
        state = json.loads((self.root / 'state').read_text()); state.pop('reads', None); return state

    def mutations(self):
        return [c for c in self.calls() if any(a.startswith(('--add-service=', '--remove-service=', '--set-default-zone=')) for a in c)]

    def test_services_runtime_and_permanent_before_zone(self):
        result = self.run_script('--services', 'ssh,samba')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.mutations()
        self.assertEqual(len(calls), 5)
        self.assertTrue(calls[-1][-1].startswith('--set-default-zone='))
        self.assertEqual(self.state(), {'zone': 'home', 'runtime': ['ssh', 'samba'], 'permanent': ['ssh', 'samba']})
        self.assertFalse(any(c[0] in ['pacman', 'ufw'] or '--reload' in c for c in self.calls()))
        snapshot, = self.root.glob('snapshot-*')
        self.assertEqual(snapshot.stat().st_mode & 0o777, 0o700)
        self.assertEqual((snapshot / 'configuration/custom.xml').read_text(), 'configuration personnelle')
        result = subprocess.run(['/bin/bash', str(snapshot / 'restaurer.sh')], env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.state(), self.initial)

    def test_explicit_selection_and_none_preserve_existing_services(self):
        self.initial = {'zone': 'home', 'runtime': ['samba'], 'permanent': ['samba']}; self.reset()
        result = self.run_script('--services', 'ssh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()['runtime'], ['samba', 'ssh'])
        self.assertFalse(any('--add-service=samba' in c for c in self.mutations()))
        self.reset()
        result = self.run_script('--services', 'none')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [])

    def test_missing_invalid_or_duplicate_selection_stops_before_commands(self):
        for args in [(), ('--services', 'http'), ('--services', 'ssh,ssh'), ('--services', 'ssh,'),
                     ('--services', 'none,ssh'), ('--zone', '--dry-run'), ('--unknown',)]:
            self.reset()
            self.assertNotEqual(self.run_script(*args).returncode, 0)
            self.assertEqual(self.calls(), [])

    def test_ufw_active_or_enabled_blocks_changes(self):
        for options in [{'ufw_active': 'active'}, {'ufw_enabled': 'enabled'},
                        {'ufw_enabled': 'masked-runtime'}, {'ufw_active': 'failed'}]:
            self.reset()
            result = self.run_script('--services', 'ssh', config=dict(ufw=True, **options))
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.mutations(), [])
            self.assertFalse(list(self.root.glob('snapshot-*')))

    def test_stopped_firewalld_is_not_started(self):
        result = self.run_script('--services', 'ssh', config={'running': False})
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(all(c[:2] == ['systemctl', 'show'] for c in self.calls()))

    def test_dry_run_refusal_and_eof_write_nothing(self):
        for args, answer in [(('--dry-run',), ''), ((), 'n\n'), ((), '')]:
            self.reset()
            result = self.run_script('--services', 'ssh', *args, answer=answer)
            if args: self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.mutations(), [])
            self.assertFalse(list(self.root.glob('snapshot-*')))

    def test_errors_and_concurrent_change_block_application(self):
        for config in [{'query_failure': True}, {'unit_failure': True}, {'concurrent': True},
                       {'backup_failure': True}, {'inventory_failure': True}]:
            self.reset()
            self.assertNotEqual(self.run_script('--services', 'ssh', config=config).returncode, 0)
            self.assertEqual(self.mutations(), [])

    def test_partial_failure_restores_only_additions(self):
        self.initial = {'zone': 'public', 'runtime': ['ssh'], 'permanent': ['ssh']}
        for config in [{'add_failure': 'samba'}, {'ignore_add': True}, {'zone_failure': True}]:
            self.reset()
            result = self.run_script('--services', 'ssh,samba', config=config)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(self.state(), self.initial)
            self.assertFalse(any('--remove-service=ssh' in c for c in self.calls()))
            self.assertEqual(result.stderr.count('── Bilan de l’opération'), 1)
            self.assertIn('Résultat     : Échoué', result.stderr)
            self.assertIn('Retour arrière ciblé exécuté', result.stderr)

    def test_help_needs_no_system_tools(self):
        self.assertEqual(self.run_script('--help', original=True).returncode, 0)
        self.assertEqual(self.calls(), [])

    @unittest.skipIf(os.geteuid() == 0, 'La garde root exige un hôte non root')
    def test_original_requires_root_to_apply(self):
        result = self.run_script('--services', 'ssh', original=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.mutations(), [])


if __name__ == '__main__': unittest.main()
