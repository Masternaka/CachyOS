"""Flatpak et Linux simulés ; aucune installation, aucun accès réseau.

Les confirmations utilisent un pseudo-terminal, les inventaires une fixture.
Le faux `list` reproduit les références sans préfixe app/ du client Flatpak.
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
SCRIPT = ROOT / '06 - flatpak_install.sh'
FAKE = r'''
import json, os, sys, tempfile
from pathlib import Path
root = Path(os.environ['FLATPAK_FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
c = json.loads((root / 'config.json').read_text())
with (root / 'calls').open('a') as log: log.write(json.dumps([name] + args) + '\n')
if name == 'uname': print('Linux'); sys.exit(0)
if name == 'mktemp':
    if c.get('snapshot_failure'): sys.exit(1)
    print(tempfile.mkdtemp(prefix='snapshot-', dir=root)); sys.exit(0)
if name == 'sudo': os.execvp(args[0], args)
if name == 'pacman-conf': print('core\nextra\ncachyos'); sys.exit(0)
if name == 'pacman':
    packages = ('flatpak', 'xdg-desktop-portal', 'distrobox', 'podman', 'pipewire-audio', 'wireplumber',
                'xdg-desktop-portal-gtk', 'xdg-desktop-portal-gnome', 'gnome-keyring')
    missing = c.get('host_missing', []) if not (root / 'host-installed').exists() else []
    if args == ['-Qq']: print('\n'.join(pkg for pkg in packages if pkg not in missing)); sys.exit(0)
    if args == ['-Q']: print('\n'.join(pkg + ' 1' for pkg in packages if pkg not in missing)); sys.exit(0)
    if args == ['-Sl']: print('\n'.join('extra ' + pkg + ' 1' for pkg in packages)); sys.exit(0)
    if args[0] == '-Syu':
        if c.get('host_install_failure'): sys.exit(1)
        (root / 'host-installed').touch()
        sys.exit(0)
    sys.exit(8)
if name != 'flatpak': sys.exit(9)
if args == ['--default-arch']: print('x86_64'); sys.exit(0)
if '--user' not in args: sys.exit(99)
args.remove('--user')
state_file = root / 'state.json'
s = json.loads(state_file.read_text())
cmd = args[0]
if cmd == 'remotes':
    if c.get('remotes_failure'): sys.exit(1)
    reads = int((root / 'remote_reads').read_text()) if (root / 'remote_reads').exists() else 0
    (root / 'remote_reads').write_text(str(reads + 1))
    if s['remote']:
        url = 'https://bad.example/repo/' if c.get('remote_change') and reads else c.get('url', 'https://dl.flathub.org/repo/')
        print('flathub\t' + url + '\t' + c.get('options', ''))
    sys.exit(0)
if cmd == 'list':
    if c.get('list_failure'): sys.exit(1)
    for ref, data in s['apps'].items():
        if 'active' in ' '.join(args): print(ref.removeprefix('app/') + '\t' + data[0] + '\t' + data[1][:12])
        else: print(ref.removeprefix('app/') + '\t' + data[0])
    sys.exit(0)
if cmd == 'remote-add':
    if c.get('remote_add_failure'): sys.exit(1)
    s['remote'] = True
if cmd == 'remote-info':
    ref = args[-1]
    if c.get('missing') in (ref, '*'): sys.exit(1)
    print('unexpected/ref' if c.get('wrong_ref') else ref); sys.exit(0)
if cmd in ('install', 'update'):
    ref = args[-1]
    if c.get('failed_app') == ref: sys.exit(3)
    if ref != c.get('unchanged_app'):
        s['apps'][ref] = ['flathub', 'b' * 64]
if cmd == 'info':
    ref = args[-1]
    if ref not in s['apps'] or c.get('info_failure'): sys.exit(1)
    if '--show-commit' in args: print(s['apps'][ref][1])
    elif '--show-origin' in args: print('other' if c.get('wrong_origin_after') else s['apps'][ref][0])
    else: sys.exit(8)
    sys.exit(0)
if cmd == 'uninstall' and c.get('cleanup_failure'): sys.exit(1)
state_file.write_text(json.dumps(s))
'''


class FlatpakTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fake = self.root / 'fake'
        fake.write_text('#!' + sys.executable + '\n' + FAKE)
        fake.chmod(0o755)
        for name in ('flatpak', 'uname', 'mktemp', 'distrobox', 'podman', 'pacman', 'pacman-conf', 'sudo'):
            (self.bin / name).symlink_to(fake)
        self.env = dict(os.environ, FLATPAK_FIXTURE=str(self.root),
                        PATH=str(self.bin) + ':' + os.environ['PATH'], XDG_CURRENT_DESKTOP='')
        self.config = {}
        self.state = {'remote': True, 'apps': {}}
        lines = subprocess.check_output(['/bin/bash', str(SCRIPT), '--list'], text=True).splitlines()
        self.apps = [line.split()[0] for line in lines]
        self.refs = ['app/' + app + '/x86_64/stable' for app in self.apps]

    def run_script(self, *args, terminal=False, answers=('o',), selection=None, path=SCRIPT):
        (self.root / 'config.json').write_text(json.dumps(self.config))
        (self.root / 'state.json').write_text(json.dumps(self.state))
        choices = ['--all'] if terminal and selection is None else []
        cmd = ['/bin/bash', str(path), *choices, *args]
        if not terminal:
            return subprocess.run(cmd, env=self.env, capture_output=True, text=True)
        master, slave = pty.openpty()
        proc = subprocess.Popen(cmd, env=self.env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b''
        sent = 0
        selection_sent = selection is None
        deadline = time.monotonic() + 20
        try:
            while True:
                if time.monotonic() > deadline:
                    self.fail('Délai dépassé dans le pseudo-terminal')
                ready, _, _ = select.select([master], [], [], 0.1)
                if ready:
                    try: chunk = os.read(master, 65536)
                    except OSError as exc:
                        if exc.errno != errno.EIO: raise
                        break
                    if not chunk: break
                    output += chunk
                    if not selection_sent and b'q = quitter] : ' in output:
                        os.write(master, (selection + '\n').encode())
                        selection_sent = True
                    if output.count(b'[o/N]') > sent and sent < len(answers):
                        os.write(master, (answers[sent] + '\n').encode())
                        sent += 1
                elif proc.poll() is not None: break
            proc.wait(timeout=3)
        finally:
            if proc.poll() is None: proc.kill(); proc.wait()
            os.close(master)
        return subprocess.CompletedProcess(cmd, proc.returncode, output.decode(), '')

    def calls(self):
        path = self.root / 'calls'
        return [json.loads(x) for x in path.read_text().splitlines()] if path.exists() else []

    def operations(self):
        return [c for c in self.calls() if c[0] == 'flatpak' and c[1] in ('install', 'update', 'remote-add', 'uninstall')]

    def assert_no_changes(self):
        self.assertEqual(self.operations(), [])
        self.assertFalse(list(self.root.glob('snapshot-*')))
        self.assertFalse(any(c[:2] == ['flatpak', 'remote-info'] for c in self.calls()))
        self.assertFalse(any(c[:2] == ['pacman', '-Syu'] for c in self.calls()))

    def test_help_and_list_need_no_tools(self):
        for args in (('--help',), ('--list',)):
            self.assertEqual(self.run_script(*args).returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertEqual(len(self.apps), 13)

    def test_unknown_option_is_rejected(self):
        self.assertEqual(self.run_script('--yes').returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_root_is_refused(self):
        copy = self.root / 'root-script.sh'
        copy.write_text(SCRIPT.read_text().replace('[[ $EUID -ne 0 ]]', '[[ 0 -ne 0 ]]', 1))
        self.assertNotEqual(self.run_script('--dry-run', path=copy).returncode, 0)
        self.assert_no_changes()

    def test_dry_run_has_no_network_or_writes(self):
        self.state['remote'] = False
        result = self.run_script('--dry-run', '--cleanup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('disponibilité distante', result.stdout)
        self.assert_no_changes()

    def test_dry_run_reports_missing_native_packages(self):
        self.config['host_missing'] = ['flatpak', 'podman']
        result = self.run_script('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('extra/flatpak extra/podman', result.stdout)
        self.assert_no_changes()

    def test_native_install_and_flatpak_follow_one_confirmation(self):
        self.config['host_missing'] = ['podman']
        result = self.run_script(terminal=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout.count('[o/N]'), 1)
        self.assertIn(['pacman', '-Syu', '--needed', '--noconfirm', '--', 'extra/podman'], self.calls())
        self.assertEqual(sum(c[1] == 'install' for c in self.operations()), 13)
        snapshot, = self.root.glob('snapshot-*')
        self.assertTrue((snapshot / 'paquets-hote-apres.txt').exists())

    def test_menu_selects_only_requested_apps_and_prerequisites(self):
        self.config['host_missing'] = ['podman', 'pipewire-audio']
        result = self.run_script(terminal=True, selection='2,3,2')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout.count('[o/N]'), 1)
        installed = [c[-2] for c in self.operations() if c[1] == 'install']
        self.assertEqual(installed, self.refs[1:3])
        self.assertFalse(any(c[:2] == ['pacman', '-Syu'] for c in self.calls()))

    def test_only_accepts_ids_and_rejects_apps_outside_catalogue(self):
        result = self.run_script('--dry-run', '--only', self.apps[2])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(self.refs[2], result.stdout)
        self.assertNotIn(self.refs[1], result.stdout)
        result = self.run_script('--dry-run', '--only', '99')
        self.assertEqual(result.returncode, 2)
        self.assert_no_changes()

    def test_invalid_remote_is_blocking(self):
        self.config['url'] = 'https://example.org/repo/'
        self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_changes()

    def test_disabled_or_unverified_remote_is_blocking(self):
        for options in ('disabled', 'no-gpg-verify', 'oci'):
            self.config['options'] = options
            self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_changes()

    def test_local_query_failure_is_not_treated_as_absence(self):
        for key in ('remotes_failure', 'list_failure'):
            self.config = {key: True}
            self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_changes()

    def test_different_existing_origin_is_not_migrated(self):
        self.state['apps'][self.refs[0]] = ['other', 'a' * 64]
        self.assertNotEqual(self.run_script('--dry-run').returncode, 0)
        self.assert_no_changes()

    def test_noninteractive_execution_is_refused(self):
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assert_no_changes()

    def test_decline_does_not_add_remote(self):
        self.state['remote'] = False
        self.assertEqual(self.run_script(terminal=True, answers=('n',)).returncode, 0)
        self.assert_no_changes()

    def test_changed_remote_during_confirmation_blocks_all_changes(self):
        self.config['remote_change'] = True
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
        self.assert_no_changes()

    def test_missing_ref_is_reported_and_other_applications_install(self):
        self.config['missing'] = self.refs[2]
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
        self.assertEqual(sum(c[1] == 'install' for c in self.operations()), 12)
        self.assertFalse(any(self.refs[2] in c for c in self.operations()))
        self.assertIn('1 erreurs', result.stdout)

    def test_unexpected_resolved_ref_is_blocking(self):
        self.config['wrong_ref'] = True
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
        self.assertEqual(self.operations(), [])

    def test_add_remote_then_install_only_after_confirmation(self):
        self.state['remote'] = False
        result = self.run_script(terminal=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.operations()[0][1], 'remote-add')
        self.assertEqual(sum(c[1] == 'install' for c in self.operations()), 13)
        self.assertIn('13 nouvelles', result.stdout)
        snapshot, = self.root.glob('snapshot-*')
        self.assertEqual(snapshot.stat().st_mode & 0o777, 0o700)
        self.assertEqual(len((snapshot / 'nouvelles-applications.txt').read_text().splitlines()), 13)
        self.assertTrue((snapshot / 'references-apres.txt').exists())
        for c in self.calls():
            if c[0] == 'flatpak' and c[1] != '--default-arch': self.assertIn('--user', c)
            if c[0] == 'flatpak' and c[1] in ('install', 'update'): self.assertIn('--assumeyes', c)
            self.assertNotIn('-y', c)
            self.assertNotIn('--system', c)

    def test_existing_applications_update_and_are_counted_correctly(self):
        self.state['apps'] = {self.refs[0]: ['flathub', 'a' * 64], self.refs[1]: ['flathub', 'a' * 64]}
        self.config['unchanged_app'] = self.refs[1]
        result = self.run_script(terminal=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('11 nouvelles, 1 mises à jour, 1 inchangées, 0 erreurs', result.stdout)
        self.assertEqual(sum(c[1] == 'update' for c in self.operations()), 2)

    def test_failed_install_returns_error_without_retry_or_cleanup(self):
        self.config['failed_app'] = self.refs[0]
        result = self.run_script('--cleanup', terminal=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('1 erreurs', result.stdout)
        self.assertEqual(sum(c[1] == 'install' and self.refs[0] in c for c in self.operations()), 1)
        self.assertFalse(any(c[1] == 'uninstall' for c in self.operations()))

    def test_incorrect_post_install_origin_is_failure(self):
        self.config['wrong_origin_after'] = True
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)

    def test_cleanup_is_optional_and_separately_confirmed(self):
        result = self.run_script('--cleanup', terminal=True, answers=('o', 'n'))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse(any(c[1] == 'uninstall' for c in self.operations()))

    def test_cleanup_failure_is_reported(self):
        self.config['cleanup_failure'] = True
        result = self.run_script('--cleanup', terminal=True, answers=('o', 'o'))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(c[1] == 'uninstall' for c in self.operations()))

    def test_snapshot_or_remote_creation_failure_blocks_installation(self):
        self.state['remote'] = False
        self.config['snapshot_failure'] = True
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
        self.assertEqual(self.operations(), [])
        self.config = {'remote_add_failure': True}
        self.assertNotEqual(self.run_script(terminal=True).returncode, 0)
        self.assertFalse(any(c[1] in ('install', 'update') for c in self.operations()))


if __name__ == '__main__': unittest.main()
