"""Contrôles isolés : Pacman, sudo et le système cible sont simulés.

Aucune installation ou lecture de configuration personnelle. La copie de test
redirige uniquement os-release ; mktemp est simulé vers la fixture privée.
"""
import errno
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / '05 - package_install.sh'
FAKE = r'''
import json, os, sys, tempfile
from pathlib import Path
root = Path(os.environ['PACKAGE_FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
config = json.loads((root / 'config.json').read_text())
with (root / 'calls').open('a') as log:
    log.write(json.dumps([name] + args) + '\n')
packages = json.loads((root / 'packages.json').read_text())
repos = config.get('repos', ['cachyos-extra-v3', 'cachyos', 'core', 'extra'])
if name == 'uname': print(config.get('os', 'Linux')); sys.exit(0)
if name == 'sudo': os.execvp(args[0], args)
if name == 'mktemp':
    if config.get('snapshot_failure'): sys.exit(1)
    print(tempfile.mkdtemp(prefix='snapshot-', dir=root)); sys.exit(0)
if name == 'pacman-conf':
    if config.get('config_failure'): sys.exit(1)
    if args == ['--repo-list']:
        count = int((root / 'repo_reads').read_text()) if (root / 'repo_reads').exists() else 0
        (root / 'repo_reads').write_text(str(count + 1))
        if count and config.get('repo_change'): repos = ['extra', 'cachyos']
        print('\n'.join(repos))
    else:
        changed = config.get('config_change') and (root / 'repo_reads').read_text() != '1'
        print('[options]\nSigLevel = ' + ('Never' if changed else 'Required') + '\n' + '\n'.join('[' + x + ']' for x in repos))
    sys.exit(0)
if name != 'pacman': sys.exit(9)
if args == ['-Sl']:
    if config.get('listing_failure'): sys.exit(1)
    changed = config.get('target_change') and (root / 'repo_reads').read_text() != '1'
    for repo in repos:
        for package in packages:
            if package != config.get('missing') and not (changed and repo == repos[0] and package == 'git'):
                print(repo, package, '1.0')
    sys.exit(0)
if args and args[0] == '-Syu':
    (root / 'attempted').touch()
    if config.get('transaction_failure'): sys.exit(42)
    (root / 'installed').touch(); sys.exit(0)
if args == ['-Qqm']:
    if config.get('foreign_inventory_failure'): print('database error', file=sys.stderr)
    sys.exit(1)  # Sélection vide, cas normal en l'absence de diagnostic.
if args == ['-Qqe']: print('git'); sys.exit(0)
if args == ['-Q']:
    if config.get('inventory_failure') and not (root / 'attempted').exists(): sys.exit(1)
    installed = packages if (root / 'installed').exists() else ['git']
    for package in installed: print(package, '1.0')
    sys.exit(0)
if len(args) == 2 and args[0] == '-Q':
    sys.exit(1 if args[1] == config.get('absent_after') else 0)
sys.exit(8)
'''


class PackageInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "scripts").mkdir()
        (self.root / "scripts/bilan.sh").write_text((SCRIPT.parent / "scripts/bilan.sh").read_text())
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fake = self.bin / 'fake'
        fake.write_text('#!' + sys.executable + '\n' + FAKE)
        fake.chmod(0o755)
        for tool in ('pacman', 'pacman-conf', 'sudo', 'uname', 'mktemp'):
            (self.bin / tool).symlink_to(fake)
        self.os_release = self.root / 'os-release'
        self.os_release.write_text('ID=cachyos\n')
        self.copy = self.root / 'script.sh'
        self.copy.write_text(SCRIPT.read_text().replace('/etc/os-release', str(self.os_release)))
        self.env = dict(os.environ, PACKAGE_FIXTURE=str(self.root),
                        PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.config = {}
        self.packages = subprocess.check_output(
            ['/bin/bash', str(SCRIPT), '--list'], text=True).splitlines()
        (self.root / 'packages.json').write_text(json.dumps(self.packages))

    def run_script(self, *args, terminal=False, answer='o\n', original=False):
        (self.root / 'config.json').write_text(json.dumps(self.config))
        cmd = ['/bin/bash', str(SCRIPT if original else self.copy), *args]
        if not terminal:
            return subprocess.run(cmd, env=self.env, capture_output=True, text=True)
        master, slave = pty.openpty()
        proc = subprocess.Popen(cmd, env=self.env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b''
        sent = False
        deadline = time.monotonic() + 15
        try:
            while True:
                if time.monotonic() > deadline:
                    proc.kill()
                    self.fail('Délai dépassé dans la fixture interactive')
                ready, _, _ = select.select([master], [], [], 0.1)
                if ready:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as exc:
                        if exc.errno != errno.EIO:
                            raise
                        break
                    if not chunk:
                        break
                    output += chunk
                    if b'[o/N]' in output and not sent:
                        os.write(master, answer.encode())
                        sent = True
                elif proc.poll() is not None:
                    break
            proc.wait(timeout=3)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            os.close(master)
        return subprocess.CompletedProcess(cmd, proc.returncode, output.decode(), '')

    def calls(self):
        log = self.root / 'calls'
        return [json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []

    def assert_no_mutation(self):
        self.assertFalse(list(self.root.glob('snapshot-*')))
        self.assertFalse((self.root / 'attempted').exists())
        self.assertFalse(any(c[0] in ('sudo', 'mktemp') for c in self.calls()))

    def test_help_needs_no_system_tools(self):
        self.assertEqual(self.run_script('--help', original=True).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_exact_active_catalogue(self):
        expected = """flameshot gnome-disk-utility gparted qbittorrent transmission-qt stow
        ttf-jetbrains-mono-nerd ttf-meslo-nerd ttf-firacode-nerd firefox-i18n-fr
        thunderbird-i18n-fr bitwarden proton-pass ufw gufw firefox thunderbird
        brave-origin-bin floorp-bin strawberry mpv vesktop-bin libreoffice-fresh
        libreoffice-fresh-fr obsidian distrobox podman kitty fastfetch git curl
        wget starship micro code github-desktop meld zed openai-codex
        claude-desktop claude-code""".split()
        self.assertEqual(self.packages, expected)
        self.assertEqual(len(set(self.packages)), len(self.packages))

    def test_empty_group_lists_nothing_and_does_not_start_a_transaction(self):
        result = self.run_script('--groups', 'kde', '--list', original=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')
        result = self.run_script('--groups', 'kde')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('Aucun paquet actif', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_groups_are_explicit_and_default_list_is_their_union(self):
        groups = self.run_script('--list-groups', original=True).stdout.splitlines()
        expected_groups = ['utilitaires', 'polices', 'langues', 'securite', 'internet',
                           'multimedia', 'communication', 'bureautique', 'virtualisation',
                           'terminaux', 'terminal', 'developpement', 'ia', 'kde']
        self.assertEqual(groups, expected_groups)
        combined = []
        for group in groups:
            result = self.run_script('--groups', group, '--list', original=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            combined.extend(result.stdout.splitlines())
        self.assertEqual(combined, self.packages)
        result = self.run_script('--groups', 'virtualisation,terminal', '--list', original=True)
        self.assertEqual(result.stdout.splitlines(), ['distrobox', 'podman', 'fastfetch', 'git',
                         'curl', 'wget', 'starship'])
        self.assertEqual(self.calls(), [])

    def test_group_selection_limits_transaction_targets(self):
        result = self.run_script('--groups', 'virtualisation', terminal=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        transactions = [c for c in self.calls() if c[:2] == ['pacman', '-Syu']]
        self.assertEqual(transactions[0][3:], ['cachyos-extra-v3/' + p for p in
                         ['distrobox', 'podman']])

    def test_invalid_groups_fail_without_system_calls(self):
        for args in [('--groups',), ('--groups', ''), ('--groups', 'kde,'),
                     ('--groups', 'terminal,terminal'), ('--groups', 'unknown'),
                     ('--groups', 'terminal', '--groups', 'kde')]:
            result = self.run_script(*args)
            self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(self.calls(), [])

    def test_unknown_option_is_rejected(self):
        self.assertEqual(self.run_script('--yes').returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_foreign_os_is_rejected(self):
        self.config['os'] = 'Darwin'
        self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_mutation()

    def test_arch_without_cachyos_identity_is_rejected(self):
        self.os_release.write_text('ID=arch\n')
        self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_mutation()

    def test_quoted_cachyos_identity(self):
        self.os_release.write_text('ID="cachyos"\n')
        self.assertEqual(self.run_script('--dry-run').returncode, 0)

    def test_dry_run_has_no_writes_or_privilege_escalation(self):
        result = self.run_script('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('cachyos-extra-v3/git', result.stdout)
        self.assert_no_mutation()

    def test_third_party_or_testing_repository_is_rejected(self):
        for repo in ('chaotic-aur', 'custom', 'extra-testing', 'cachyos-v3-testing'):
            self.config['repos'] = ['cachyos', 'extra', repo]
            self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_mutation()

    def test_no_cachyos_repository_is_rejected(self):
        self.config['repos'] = ['core', 'extra']
        self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_mutation()

    def test_missing_package_is_blocking_even_if_other_packages_exist(self):
        self.config['missing'] = 'brave-origin-bin'
        result = self.run_script('--dry-run')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('brave-origin-bin', result.stderr)
        self.assert_no_mutation()

    def test_unreadable_repository_configuration_or_database(self):
        for key in ('config_failure', 'listing_failure'):
            self.config = {key: True}
            self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_mutation()

    def test_noninteractive_application_is_refused(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('terminal interactif', result.stderr)
        self.assert_no_mutation()

    def test_confirmation_declined_writes_nothing(self):
        result = self.run_script(terminal=True, answer='n\n')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assert_no_mutation()

    def test_changed_repository_priority_invalidates_confirmation(self):
        self.config['repo_change'] = True
        result = self.run_script(terminal=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assert_no_mutation()

    def test_changed_effective_configuration_invalidates_confirmation(self):
        self.config['config_change'] = True
        result = self.run_script(terminal=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assert_no_mutation()

    def test_changed_package_source_invalidates_confirmation(self):
        self.config['target_change'] = True
        result = self.run_script(terminal=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assert_no_mutation()

    def test_foreign_package_query_error_is_not_an_empty_selection(self):
        self.config['foreign_inventory_failure'] = True
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
        self.assertFalse((self.root / 'attempted').exists())

    def test_snapshot_creation_or_inventory_failure_blocks_transaction(self):
        for key in ('snapshot_failure', 'inventory_failure'):
            self.config = {key: True}
            self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
            self.assertFalse((self.root / 'attempted').exists())

    def test_one_pinned_transaction_and_honest_summary(self):
        result = self.run_script(terminal=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        transactions = [c for c in self.calls() if c[:2] == ['pacman', '-Syu']]
        self.assertEqual(len(transactions), 1)
        self.assertEqual(transactions[0][2], '--needed')
        self.assertEqual(transactions[0][3:], ['cachyos-extra-v3/' + p for p in self.packages])
        # Git est le seul paquet déjà installé dans cette fixture.
        self.assertIn(f'{len(self.packages) - 1} nouvellement installés', result.stdout)
        snapshot, = self.root.glob('snapshot-*')
        self.assertEqual(snapshot.stat().st_mode & 0o777, 0o700)
        self.assertTrue((snapshot / 'paquets-apres.txt').exists())
        self.assertTrue((snapshot / 'etrangers-avant.txt').exists())
        self.assertFalse(any('--noconfirm' in c or '-Sc' in c for c in self.calls()))

    def test_failed_transaction_preserves_failure_status_and_inventory(self):
        self.config['transaction_failure'] = True
        result = self.run_script(terminal=True)
        self.assertEqual(result.returncode, 42, result.stdout)
        self.assertNotIn('Transaction terminée', result.stdout)
        snapshot, = self.root.glob('snapshot-*')
        self.assertTrue((snapshot / 'paquets-apres.txt').exists())

    def test_missing_package_after_transaction_is_not_success(self):
        self.config['absent_after'] = 'kitty'
        result = self.run_script(terminal=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('kitty', result.stdout)
        self.assertNotIn('Transaction terminée', result.stdout)


if __name__ == '__main__':
    unittest.main()
