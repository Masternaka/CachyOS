"""Scénarios isolés : aucune commande système réelle n'est appelée.

Sur macOS, seule une copie temporaire contourne la garde root pour tester les
branches d'application. La garde du script original est testée séparément.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '01 - systemd_services.sh'
UNITS = ['bluetooth.service', 'fstrim.timer', 'paccache.timer', 'sshd.service']
FAKE = r'''#!/usr/bin/env python3
import json, os, sys, tempfile
from pathlib import Path
root = Path(os.environ['FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
config = json.loads((root / 'config').read_text())
states = json.loads((root / 'states').read_text())
with (root / 'calls').open('a') as log:
    log.write(json.dumps([name] + args) + '\n')
if name == 'pacman':
    sys.exit(1 if args[-1] == config.get('missing_pkg') else 0)
if name == 'mktemp':
    if config.get('journal_failure'): sys.exit(1)
    fd, path = tempfile.mkstemp(dir=root, prefix='undo-')
    os.close(fd)
    print(path)
    sys.exit(0)
if name != 'systemctl': sys.exit(0)
if '--property=Version' in args:
    if config.get('bus_failure'):
        print('Bus unavailable', file=sys.stderr)
        sys.exit(1)
    print('260')
    sys.exit(0)
unit = args[-1] if args[0] != 'show' else args[1]
if args[0] == 'show':
    if unit == config.get('read_failure'): sys.exit(1)
    for key, val in states[unit].items(): print(key + '=' + val)
    sys.exit(0)
if unit == config.get('action_failure'):
    if args[0] == 'enable':
        states[unit]['UnitFileState'] = 'enabled'
        (root / 'states').write_text(json.dumps(states))
    sys.exit(1)
if not config.get('no_effect'):
    if args[0] == 'enable':
        states[unit]['UnitFileState'] = 'enabled-runtime' if '--runtime' in args else 'enabled'
        if '--now' in args: states[unit]['ActiveState'] = 'active'
    if args[0] == 'disable': states[unit]['UnitFileState'] = 'disabled'
    if args[0] in ('start', 'stop'):
        states[unit]['ActiveState'] = 'active' if args[0] == 'start' else 'inactive'
(root / 'states').write_text(json.dumps(states))
'''


class ServicesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "scripts").mkdir()
        (self.root / "scripts/bilan.sh").write_text((SCRIPT.parent / "scripts/bilan.sh").read_text())
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.fake = self.root / 'fake'
        self.fake.write_text(FAKE)
        self.fake.chmod(0o755)
        # Absolutiser l'interpréteur pour ne dépendre d'aucune commande système simulée.
        import sys
        self.fake.write_text(FAKE.replace('/usr/bin/env python3', sys.executable, 1))
        for name in ['systemctl', 'pacman', 'paccache', 'fstrim', 'mktemp']:
            (self.bin / name).symlink_to(self.fake)
        self.env = dict(os.environ, FIXTURE=str(self.root), PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.states = {unit: dict(LoadState='loaded', UnitFileState='disabled', ActiveState='inactive') for unit in UNITS}
        self.config = {}
        self.copy = self.root / 'script.sh'
        self.copy.write_text(SCRIPT.read_text().replace('[[ $EUID -ne 0 ]]', '[[ 1 -eq 0 ]]', 1))

    def run_script(self, *args, original=False, answers='o\no\n'):
        (self.root / 'config').write_text(json.dumps(self.config))
        (self.root / 'states').write_text(json.dumps(self.states))
        return subprocess.run(['/bin/bash', str(SCRIPT if original else self.copy), *args], env=self.env, input=answers, text=True, capture_output=True)

    def calls(self):
        file = self.root / 'calls'
        return [json.loads(line) for line in file.read_text().splitlines()] if file.exists() else []

    def actions(self):
        return [call for call in self.calls() if call[0] == 'systemctl' and call[1] != 'show']

    def test_invalid_arguments_never_call_system_tools(self):
        for args in [('--dryrun',), ('--dry-run', 'extra'), ('',)]:
            self.assertEqual(self.run_script(*args, original=True).returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_help_needs_no_root_or_system_tools(self):
        self.assertEqual(self.run_script('--help', original=True).returncode, 0)
        self.assertEqual(self.calls(), [])

    @unittest.skipIf(os.geteuid() == 0, 'Exécution déjà root')
    def test_original_requires_root(self):
        self.assertEqual(self.run_script(original=True).returncode, 1)
        self.assertEqual(self.calls(), [])

    def test_original_dry_run_never_writes(self):
        self.states[UNITS[0]]['UnitFileState'] = 'enabled'
        result = self.run_script('--dry-run', original=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('serait démarré (déjà activé', result.stdout)
        self.assertEqual(self.actions(), [])
        self.assertFalse(list(self.root.glob('undo-*')))

    def test_declining_plan_leaves_units_and_undo_files_untouched(self):
        result = self.run_script(answers='o\n\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(result.stdout.index('sshd.service — serait'), result.stdout.index('Appliquer les actions'))
        self.assertIn('Résultat     : Annulé', result.stderr)
        self.assertEqual(self.actions(), [])
        self.assertFalse(any(call[0] == 'mktemp' for call in self.calls()))

    def test_default_selection_leaves_ssh_alone(self):
        self.config['missing_pkg'] = 'openssh'
        result = self.run_script(answers='\no\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.actions()), len(UNITS) - 1)
        self.assertTrue(all(call[-1] != 'sshd.service' for call in self.actions()))
        self.assertFalse(any(['pacman', '-Q', 'openssh'] == call for call in self.calls()))

    def test_enabled_but_stopped_gets_started(self):
        self.states[UNITS[0]]['UnitFileState'] = 'enabled'
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['systemctl', 'start', UNITS[0]], self.actions())
        self.assertEqual(len(self.actions()), len(UNITS))

    def test_already_ready_is_noop(self):
        for state in self.states.values():
            state.update(UnitFileState='enabled', ActiveState='active')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Résultat     : Déjà conforme', result.stderr)
        self.assertEqual(self.actions(), [])
        self.assertFalse(list(self.root.glob('undo-*')))

    def test_partial_failure_is_nonzero_and_other_units_continue(self):
        self.config['action_failure'] = UNITS[0]
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.actions()), len(UNITS))
        self.assertIn("échec de l'activation/démarrage", result.stderr)
        self.assertEqual(result.stderr.count('── Bilan de l’opération'), 1)
        self.assertIn('Résultat     : Partiellement réussi', result.stderr)

    def test_missing_package_only_blocks_its_unit(self):
        self.config['missing_pkg'] = 'bluez'
        self.assertEqual(self.run_script().returncode, 1)
        self.assertEqual(len(self.actions()), len(UNITS) - 1)
        self.assertTrue(all(call[-1] != UNITS[0] for call in self.actions()))

    def test_masked_missing_unstable_and_read_errors(self):
        for key, val in [('UnitFileState', 'masked'), ('LoadState', 'not-found'), ('ActiveState', 'activating')]:
            with self.subTest(state=val):
                initial = self.states[UNITS[0]][key]
                self.states[UNITS[0]][key] = val
                result = self.run_script('--dry-run', original=True)
                self.assertEqual(result.returncode, 1)
                self.states[UNITS[0]][key] = initial
        self.config['read_failure'] = UNITS[0]
        self.assertEqual(self.run_script('--dry-run', original=True).returncode, 1)
        self.assertEqual(self.actions(), [])

    def test_bus_failure_stops_before_modifications(self):
        self.config['bus_failure'] = True
        result = self.run_script('--dry-run', original=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('gestionnaire systemd', result.stderr)
        self.assertEqual(self.actions(), [])

    def test_journal_failure_prevents_all_actions(self):
        self.config['journal_failure'] = True
        self.assertEqual(self.run_script().returncode, 1)
        self.assertEqual(self.actions(), [])

    def test_successful_command_without_effect_is_detected(self):
        self.config['no_effect'] = True
        self.assertEqual(self.run_script().returncode, 1)

    def test_undo_restores_initial_activation_and_running_states(self):
        self.states[UNITS[1]].update(UnitFileState='enabled-runtime', ActiveState='active')
        self.states[UNITS[2]].update(UnitFileState='enabled', ActiveState='inactive')
        self.assertEqual(self.run_script().returncode, 0)
        journals = list(self.root.glob('undo-*'))
        self.assertEqual(len(journals), 1)
        journal = journals[0]
        self.assertEqual(journal.stat().st_mode & 0o777, 0o600)
        undo = self.root / 'undo-test.sh'
        undo.write_text(journal.read_text().replace('[[ $EUID -eq 0 ]]', '[[ 1 -eq 1 ]]', 1))
        result = subprocess.run(['/bin/bash', str(undo)], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.root / 'states').read_text()), self.states)


if __name__ == '__main__':
    unittest.main()
