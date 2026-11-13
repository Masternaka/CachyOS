"""Lecture des conflits dans des dossiers temporaires, sans outils système réels."""
import importlib.util
import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('diagnostic', ROOT / 'scripts/diagnostic.py')
MODULE = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(MODULE)


class DiagnosticTests(unittest.TestCase):
    def test_conflicts_links_and_redirected_parents_are_reported_without_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            repo = root / 'repo'; home = root / 'home'; home.mkdir()
            sources = repo / 'Dotfiles/zsh/.config/zsh'; sources.mkdir(parents=True)
            for name in ('identique', 'different', 'lien', 'externe', 'absent'):
                (sources / name).write_text('source')
            target = home / '.config/zsh'; target.mkdir(parents=True)
            (target / 'identique').write_text('source')
            (target / 'different').write_text('personnel')
            (target / 'lien').symlink_to(sources / 'lien')
            (target / 'externe').symlink_to(root / 'ailleurs')
            entries = dict((p.name, state) for p, state in MODULE.inspect_targets(repo, home, home / '.config', home))
            self.assertEqual(entries['identique'], 'identique')
            self.assertIn('fichier différent', entries['different'])
            self.assertEqual(entries['lien'], 'lien vers le dépôt')
            self.assertIn('lien externe', entries['externe'])
            self.assertEqual(entries['absent'], 'absent')
            self.assertEqual((target / 'different').read_text(), 'personnel')
            (home / 'redirected').symlink_to(home / '.config', target_is_directory=True)
            entries = MODULE.inspect_targets(repo, home, home / 'redirected', home)
            self.assertTrue(all('parent redirigé' in state for _, state in entries))
            self.assertFalse((target / 'absent').exists())

    def test_command_timeout_is_a_read_failure(self):
        import subprocess
        with patch.object(MODULE.subprocess, 'run', side_effect=subprocess.TimeoutExpired('test', 10)):
            self.assertEqual(MODULE.read_command(['test']), (2, ''))

    def test_incomplete_native_inventory_returns_failure_without_mutations(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp).resolve()
            calls = []

            def read(command):
                calls.append(command)
                if command[0] == 'pacman-conf':
                    return 0, 'cachyos\nextra'
                if command[0] == 'bash':
                    return 0, 'git'
                if command[0] == 'systemctl':
                    return 0, 'LoadState=loaded\nActiveState=inactive\nUnitFileState=disabled'
                return 1, ''

            with patch('sys.argv', ['diagnostic.py', '--home', str(home)]), \
                    patch.object(MODULE.platform, 'system', return_value='Linux'), \
                    patch.object(MODULE.shutil, 'which', return_value='/fixture/tool'), \
                    patch.object(MODULE, 'read_command', side_effect=read), \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(MODULE.main(), 1)
            self.assertTrue(all(c[0] in ('pacman-conf', 'systemctl', 'bash', 'pacman') for c in calls))
            self.assertTrue(all(c[:2] == ['systemctl', 'show'] for c in calls if c[0] == 'systemctl'))
            self.assertTrue(all(c[:2] == ['pacman', '-Q'] for c in calls if c[0] == 'pacman'))
            self.assertEqual(list(home.iterdir()), [])


if __name__ == '__main__': unittest.main()
