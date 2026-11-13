"""Tests isolés avec un faux pacman-conf, sans configuration système réelle.

Une copie temporaire remplace les trois chemins fixes et contourne uniquement
la garde root. cp/mv/awk manipulent de vrais fichiers dans la fixture temporaire.
La garde du script original est vérifiée séparément sur un hôte non root.
"""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '03 - pacman_settings.sh'
FAKE = r'''
import json, os, sys
from pathlib import Path
root = Path(os.environ['PACMAN_FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
config = json.loads((root / 'mock.json').read_text())
with (root / 'calls').open('a') as log: log.write(json.dumps([name] + args) + '\n')
if name == 'flock': sys.exit(1 if config.get('locked') else 0)
if name == 'nproc': print('8'); sys.exit(0)
if name == 'free': print('Mem: 16 2 14'); sys.exit(0)
path = Path(args[args.index('--config') + 1])
if path.name.startswith('pacman.conf.candidate.') and config.get('candidate_failure'):
    print('invalid candidate', file=sys.stderr); sys.exit(1)
if path.name.startswith('pacman.conf.candidate.') and config.get('change_during_prepare'):
    (root / 'pacman.conf').write_text('[options]\nParallelDownloads = 17\n')
if path.name == 'pacman.conf' and config.get('post_failure') and list(root.glob('backups/pacman.conf.bak.*')):
    print('post validation failed', file=sys.stderr); sys.exit(1)
if path.name == 'pacman.conf' and config.get('interrupt_post') and list(root.glob('backups/pacman.conf.bak.*')):
    import signal
    os.kill(os.getppid(), signal.SIGTERM)
if config.get('warning'):
    print('warning: unknown directive', file=sys.stderr)
value = '1'
def parse(file, inside=False):
    global value
    for line in file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#') or line == 'Color': continue
        if line.startswith('['): inside = line == '[options]'; continue
        if '=' not in line:
            print('invalid configuration', file=sys.stderr); sys.exit(1)
        key, val = (item.strip() for item in line.split('=', 1))
        if key == 'Include':
            parse(Path(val), inside)
        if key == 'ParallelDownloads':
            if not inside:
                print('warning: option outside [options]', file=sys.stderr)
            elif not val.isdecimal() or int(val) < 1:
                print('invalid value', file=sys.stderr); sys.exit(1)
            else: value = str(int(val))
parse(path)
print(value)
'''


class PacmanSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.conf = self.root / 'pacman.conf'
        self.original = '[options]\n# Exemple conservé\n# ParallelDownloads = 5\nParallelDownloads=2\n[core]\nServer = https://example.invalid\n'
        self.conf.write_text(self.original)
        self.conf.chmod(0o640)
        self.backups = self.root / 'backups'
        self.log = self.root / 'log'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fake = self.root / 'fake'
        fake.write_text('#!' + sys.executable + '\n' + FAKE)
        fake.chmod(0o755)
        for command in ['pacman-conf', 'flock', 'nproc', 'free']:
            (self.bin / command).symlink_to(fake)
        self.env = dict(os.environ, PACMAN_FIXTURE=str(self.root), PATH=str(self.bin) + ':' + os.environ['PATH'])
        source = SCRIPT.read_text()
        for old, new in [('PACMAN_CONF="/etc/pacman.conf"', 'PACMAN_CONF=' + shlex.quote(str(self.conf))),
                         ('BACKUP_DIR="/etc/pacman.conf.backups"', 'BACKUP_DIR=' + shlex.quote(str(self.backups))),
                         ('LOG_FILE="${ARCH_CUSTOM_LOGFILE:-/var/log/pacman_parallel_downloads.log}"', 'LOG_FILE=' + shlex.quote(str(self.log))),
                         ('[[ $EUID -ne 0 ]]', '[[ 1 -eq 0 ]]')]:
            assert source.count(old) == 1, old
            source = source.replace(old, new, 1)
        self.script = self.root / 'script.sh'
        self.script.write_text(source)
        self.config = {}

    def run_script(self, *args, original=False):
        (self.root / 'mock.json').write_text(json.dumps(self.config))
        return subprocess.run(['/bin/bash', str(SCRIPT if original else self.script), *args],
                              env=self.env, input='', text=True, capture_output=True)

    def saved(self):
        return list(self.backups.glob('pacman.conf.bak.*'))

    def assert_clean(self):
        self.assertEqual(list(self.root.glob('pacman.conf.snapshot.*')), [])
        self.assertEqual(list(self.root.glob('pacman.conf.candidate.*')), [])

    def test_decimal_value_comments_sections_and_permissions(self):
        result = self.run_script('--value', '0008')
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.conf.read_text()
        self.assertIn('# Exemple conservé\n# ParallelDownloads = 5', text)
        self.assertIn('ParallelDownloads = 8\n[core]', text)
        self.assertEqual(self.conf.stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.saved()[0].read_text(), self.original)
        self.assert_clean()

    def test_absent_setting_is_inserted_inside_options(self):
        self.conf.write_text('[options]\nColor\n[core]\nServer = test\n')
        result = self.run_script('--value', '5')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ParallelDownloads = 5\n[core]', self.conf.read_text())

    def test_duplicates_are_preserved_as_comments(self):
        self.conf.write_text('[options]\n  ParallelDownloads = 2\nParallelDownloads=3\n[core]\n')
        self.assertEqual(self.run_script('--value', '6').returncode, 0)
        self.assertEqual(self.conf.read_text().count('\nParallelDownloads = 6\n'), 1)
        self.assertIn('# ParallelDownloads=3', self.conf.read_text())

    def test_zero_comments_local_directives(self):
        result = self.run_script('--value', '0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('# ParallelDownloads=2', self.conf.read_text())
        self.assertIn('effectif : 1', result.stderr)

    def test_auto_with_and_without_silent(self):
        for extra in [(), ('--silent',)]:
            with self.subTest(extra=extra):
                self.conf.write_text(self.original)
                result = self.run_script('--auto', *extra)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('ParallelDownloads = 8', self.conf.read_text())
                if extra: self.assertEqual(result.stderr, '')

    def test_noninteractive_missing_and_conflicting_arguments(self):
        for args in [(), ('--silent',), ('--value',), ('--value', '08x'), ('--value', '21'),
                     ('--value', '-1'), ('--value', '99999999999999999999999'),
                     ('--auto', '--value', '5'), ('--restore', '--auto'),
                     ('--value', '5', '--value', '6'), ('--restore', ''), ('--unknown',)]:
            with self.subTest(args=args):
                self.assertEqual(self.run_script(*args).returncode, 2)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertFalse(self.backups.exists())
        self.assertFalse(self.log.exists())

    def test_dry_run_does_not_create_any_files(self):
        before = sorted(str(path.relative_to(self.root)) for path in self.root.rglob('*'))
        result = self.run_script('--dry-run', '--value', '8')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ParallelDownloads = 8', result.stdout)
        self.assertFalse(self.backups.exists())
        self.assertFalse(self.log.exists())
        self.assertEqual(self.conf.read_text(), self.original)
        # Seuls les outils simulés créent leurs propres journaux dans la fixture.
        after = sorted(str(path.relative_to(self.root)) for path in self.root.rglob('*') if path.name not in ['mock.json', 'calls'])
        self.assertEqual(after, before)

    def test_include_override_is_detected_without_modifying_live_config(self):
        include = self.root / 'included.conf'
        include.write_text('ParallelDownloads = 9\n')
        text = '[options]\nParallelDownloads = 2\nInclude = ' + str(include) + '\n[core]\n'
        self.conf.write_text(text)
        for value in ['0', '5']:
            result = self.run_script('--value', value)
            self.assertEqual(result.returncode, 1)
            self.assertIn('Include', result.stderr)
            self.assertEqual(self.conf.read_text(), text)
            self.assertEqual(include.read_text(), 'ParallelDownloads = 9\n')
        self.assertEqual(self.saved(), [])
        self.assert_clean()

    def test_candidate_failure_and_warnings_leave_config_untouched(self):
        for config in [{'candidate_failure': True}, {'warning': True}]:
            self.config = config
            result = self.run_script('--value', '8')
            self.assertEqual(result.returncode, 1)
            self.assertEqual(self.conf.read_text(), self.original)
            self.assert_clean()

    def test_missing_or_duplicate_options_section_is_rejected(self):
        for text in ['[core]\nServer = test\n', '[options]\n[options]\n']:
            self.conf.write_text(text)
            self.assertEqual(self.run_script('--value', '8').returncode, 1)
            self.assertEqual(self.conf.read_text(), text)
            self.assert_clean()

    def test_post_validation_failure_restores_exact_snapshot(self):
        self.config['post_failure'] = True
        result = self.run_script('--value', '8')
        self.assertEqual(result.returncode, 1)
        self.assertIn('configuration précédente rétablie', result.stderr)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertEqual(self.saved()[0].read_text(), self.original)
        self.assert_clean()

    def test_external_change_is_preserved(self):
        self.config['change_during_prepare'] = True
        self.assertEqual(self.run_script('--value', '8').returncode, 1)
        self.assertIn('17', self.conf.read_text())
        self.assert_clean()

    def test_restore_saves_current_config_and_supports_explicit_backup(self):
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        backup = self.saved()[0]
        changed = self.conf.read_text()
        self.assertEqual(self.run_script('--restore', str(backup)).returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertEqual(len(self.saved()), 2)
        self.assertTrue(any(path.read_text() == changed for path in self.saved()))
        self.assert_clean()

    def test_latest_restore_and_invalid_or_missing_backup(self):
        self.assertEqual(self.run_script('--restore').returncode, 1)
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        self.assertEqual(self.run_script('--restore').returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        bad = self.root / 'invalid'
        bad.write_text('[options]\nParallelDownloads = 0\n')
        self.assertEqual(self.run_script('--restore', str(bad)).returncode, 1)
        self.assertEqual(self.conf.read_text(), self.original)

    def test_latest_means_latest_operation_after_restores(self):
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        first = self.saved()[0]
        self.assertEqual(self.run_script('--restore', str(first)).returncode, 0)
        self.assertEqual(self.run_script('--value', '7').returncode, 0)
        self.assertEqual(self.run_script('--restore').returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)

    def test_interrupt_after_replacement_rolls_back(self):
        self.config['interrupt_post'] = True
        result = self.run_script('--value', '8')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertIn('configuration précédente rétablie', result.stderr)
        self.assert_clean()

    def test_latest_index_disambiguates_equal_backup_times(self):
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        self.assertEqual(self.run_script('--value', '7').returncode, 0)
        expected = (self.backups / (self.backups / '.latest').read_text().strip()).read_text()
        for backup in self.saved():
            os.utime(backup, (1000, 1000))
        self.assertEqual(self.run_script('--restore').returncode, 0)
        self.assertEqual(self.conf.read_text(), expected)

    def test_legacy_tied_dates_require_explicit_backup(self):
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        self.assertEqual(self.run_script('--value', '7').returncode, 0)
        (self.backups / '.latest').unlink()
        for backup in self.saved():
            os.utime(backup, (1000, 1000))
        before = self.conf.read_text()
        result = self.run_script('--restore')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('indiscernables', result.stderr)
        self.assertEqual(self.conf.read_text(), before)
        self.assertEqual(self.run_script('--restore', str(self.saved()[0])).returncode, 0)

    def test_invalid_latest_index_never_follows_external_paths(self):
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        marker = self.backups / '.latest'
        marker.write_text('../pacman.conf\n')
        before = self.conf.read_text()
        self.assertNotEqual(self.run_script('--restore').returncode, 0)
        self.assertEqual(self.conf.read_text(), before)
        marker.unlink(); marker.symlink_to(self.conf)
        self.assertNotEqual(self.run_script('--restore').returncode, 0)
        self.assertEqual(self.conf.read_text(), before)

    def test_restore_can_recover_invalid_current_configuration(self):
        backup = self.root / 'valid-backup'
        backup.write_text(self.original)
        invalid = '[options]\nParallelDownloads = 0\n'
        self.conf.write_text(invalid)
        self.assertEqual(self.run_script('--restore', str(backup)).returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertEqual(self.saved()[0].read_text(), invalid)

    def test_restore_dry_run_is_read_only(self):
        backup = self.root / 'valid-backup'
        backup.write_text(self.original)
        self.assertEqual(self.run_script('--dry-run', '--restore', str(backup)).returncode, 0)
        self.assertFalse(self.backups.exists())
        self.assertFalse(self.log.exists())

    def test_lock_failure_and_unwritable_log(self):
        self.config['locked'] = True
        self.assertEqual(self.run_script('--value', '8').returncode, 1)
        self.assertEqual(self.conf.read_text(), self.original)
        self.config.clear()
        self.log.mkdir()
        result = self.run_script('--value', '8')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Journal inaccessible', result.stderr)
        self.assertIn('ParallelDownloads = 8', self.conf.read_text())

    def test_backup_names_are_unique_and_noop_does_not_add_backup(self):
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        first = self.saved()
        self.assertEqual(self.run_script('--value', '8').returncode, 0)
        self.assertEqual(self.saved(), first)
        self.assertEqual(self.run_script('--value', '7').returncode, 0)
        self.assertEqual(len(self.saved()), 2)

    @unittest.skipIf(os.geteuid() == 0, 'Hôte déjà root')
    def test_original_root_guard(self):
        result = self.run_script('--value', '8', original=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('sudo', result.stderr)

    def test_help_requires_no_system_commands(self):
        result = self.run_script('--help', original=True)
        self.assertEqual(result.returncode, 0)
        self.assertFalse((self.root / 'calls').exists())


if __name__ == '__main__':
    unittest.main()
