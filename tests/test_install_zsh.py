"""Installation et déploiement dans un HOME temporaire ; paquets/Git/Stow/Fontconfig
simulés. Les fichiers sont réellement copiés/liés dans la fixture, Zsh et le moteur
Python sont réels. Aucun changement système ni téléchargement.
"""
import argparse
import contextlib
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
REAL_ZSH = shutil.which('zsh')
SPEC = importlib.util.spec_from_file_location('zsh_deploy', ROOT / 'scripts/zsh_deploy.py')
ENGINE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ENGINE)
FAKE = r'''
import json, os, sys
from pathlib import Path
root = Path(os.environ['ZSH_FIXTURE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
config = json.loads((root / 'scenario.json').read_text())
with (root / 'calls').open('a') as log: log.write(json.dumps([name] + args) + '\n')
if name == 'id': print('fixture' if args == ['-un'] else '1000'); sys.exit(0)
if name == 'getent':
    print('fixture:x:1000:1000:Fixture:' + str(root / 'home') + ':' + (root / 'shell').read_text()); sys.exit(0)
if name == 'pacman':
    if args[0] == '-Q':
        if args[1] in ['fzf-tab', 'zsh-fzf-tab', 'fzf-tab-git']:
            mode = config.get('fzf_mode', 'installed')
            sys.exit(0 if args[1] == config.get('fzf_package', 'fzf-tab') and (mode == 'installed' or (mode == 'repo' and (root / 'installed').exists())) else 1)
        sys.exit(1 if args[1] in config.get('missing', []) and not (root / 'installed').exists() else 0)
    if args[0] == '-Si':
        if args[1] in ['fzf-tab', 'zsh-fzf-tab', 'fzf-tab-git']:
            sys.exit(0 if config.get('fzf_mode', 'installed') != 'external' and args[1] == config.get('fzf_package', 'fzf-tab') else 1)
        sys.exit(1 if config.get('unavailable') else 0)
    if args[0] == '-Ql':
        if not config.get('missing_fzf_source'): print(args[1] + ' ' + str(root / 'packaged-fzf-tab/fzf-tab.plugin.zsh'))
        sys.exit(0)
    if args[0] == '-Syu':
        if config.get('install_failure'): sys.exit(1)
        (root / 'installed').touch()
    sys.exit(0)
if name == 'sudo': os.execvp(args[0], args)
if name == 'zsh':
    if '-n' in args:
        if config.get('syntax_failure'): sys.exit(1)
        os.execv(os.environ['REAL_ZSH'], [os.environ['REAL_ZSH']] + args)
    sys.exit(0)
if name == 'git':
    if args[:2] == ['config', '--global']: print('delta'); sys.exit(0)
    if args and args[0] == 'clone':
        repo = Path(args[-1]); (repo / '.git').mkdir(parents=True)
        (repo / 'fzf-tab.plugin.zsh').write_text('typeset -g FZF_TAB_READY=1\n')
        sys.exit(1 if config.get('clone_failure') else 0)
    if 'rev-parse' in args: print('wrong' if config.get('wrong_commit') else 'd7e0234614dbe5369fdd760907d12c0e05a4dccc')
    if 'status' in args and config.get('dirty_repo'): print(' M fzf-tab.plugin.zsh')
    sys.exit(0)
if name == 'fc-match': print('DejaVu Sans' if config.get('wrong_font') else 'JetBrainsMono Nerd Font'); sys.exit(0)
if name == 'tldr': sys.exit(1 if config.get('cache_failure') else 0)
if name == 'chsh':
    if config.get('chsh_failure'): sys.exit(1)
    if not config.get('chsh_no_effect'): (root / 'shell').write_text(args[-1])
    sys.exit(0)
if name == 'stow':
    directory = Path(next(arg.split('=', 1)[1] for arg in args if arg.startswith('--dir=')))
    home = Path(next(arg.split('=', 1)[1] for arg in args if arg.startswith('--target=')))
    packages = args[args.index('--stow') + 1:]
    if '--simulate' in args: sys.exit(1 if config.get('stow_preview_failure') else 0)
    count = 0
    for package in packages:
        for file in sorted((directory / package).rglob('*')):
            if not file.is_file(): continue
            target = home / file.relative_to(directory / package)
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.is_symlink(): target.symlink_to(file)
            count += 1
            if config.get('stow_partial_failure') and count == 2: sys.exit(1)
    sys.exit(0)
if name in ['fzf', 'zoxide', 'starship']: print(':'); sys.exit(0)
if name == 'yazi':
    for arg in args:
        if arg.startswith('--cwd-file='): Path(arg.split('=', 1)[1]).write_text(config.get('yazi_target', ''))
    sys.exit(config.get('yazi_status', 0))
'''


@unittest.skipUnless(REAL_ZSH, 'Zsh absent ; aucun téléchargement')
class InstallZshTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir='/private/tmp' if Path('/private/tmp').is_dir() else None, prefix="zsh 'fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        shutil.copytree(ROOT / 'Dotfiles', self.repo / 'Dotfiles')
        (self.repo / 'scripts').mkdir()
        shutil.copyfile(ROOT / 'scripts/zsh_deploy.py', self.repo / 'scripts/zsh_deploy.py')
        source = (ROOT / '04 - install_zsh.sh').read_text().replace('[[ $EUID -ne 0 ]]', '[[ 1 -eq 1 ]]', 1)
        import shlex
        self.shells = self.root / 'shells'
        source = source.replace("SHELLS_FILE='/etc/shells'", 'SHELLS_FILE=' + shlex.quote(str(self.shells)))
        self.script = self.repo / '04 - install_zsh.sh'
        self.script.write_text(source)
        self.home = self.root / 'home'; self.home.mkdir()
        self.conf = self.home / '.zshrc'; self.conf.write_text('# Ma configuration\nexport ORIGINAL=1\n'); self.conf.chmod(0o640)
        self.original = self.conf.read_text()
        self.aliases = self.home / '.config/cachyos-zsh/aliases.zsh'
        self.theme = self.home / '.config/starship.toml'
        self.backups = self.home / '.local/state/cachyos-zsh/backups'
        self.bin = self.root / 'bin'; self.bin.mkdir()
        fake = self.root / 'fake'; fake.write_text('#!' + sys.executable + '\n' + FAKE); fake.chmod(0o755)
        for name in ['id', 'getent', 'flock', 'pacman', 'sudo', 'zsh', 'starship', 'chsh', 'fzf', 'zoxide', 'git',
                     'yazi', 'btop', 'tldr', 'bat', 'eza', 'rg', 'fd', 'delta', 'lazygit', 'kitty', 'foot', 'duf', 'fc-match', 'stow']:
            (self.bin / name).symlink_to(fake)
        (self.root / 'shell').write_text('/bin/bash')
        self.shells.write_text(str(self.bin / 'zsh') + '\n/bin/bash\n')
        (self.root / 'packaged-fzf-tab').mkdir()
        (self.root / 'packaged-fzf-tab/fzf-tab.plugin.zsh').write_text('typeset -g FZF_TAB_READY=1\n')
        self.env = dict(os.environ, HOME=str(self.home), ZSH_FIXTURE=str(self.root), REAL_ZSH=REAL_ZSH,
                        PATH=str(self.bin) + ':' + os.environ['PATH'])
        for name in ['XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'XDG_DATA_HOME', 'ZDOTDIR', 'STARSHIP_CONFIG',
                     'CACHYOS_ZSH_FZF_TAB_SOURCE', 'CACHYOS_ZSH_REPLACE_COMMANDS', 'CACHYOS_ZSH_USE_THEME']:
            self.env.pop(name, None)
        self.scenario = {}
        (self.root / 'scenario.json').write_text('{}')

    def run_script(self, *args, answers='o\nn\nn\n'):
        (self.root / 'scenario.json').write_text(json.dumps(self.scenario))
        return subprocess.run(['/bin/bash', str(self.script), *args], env=self.env, input=answers, text=True, capture_output=True)

    def calls(self):
        file = self.root / 'calls'
        return [json.loads(line) for line in file.read_text().splitlines()] if file.exists() else []

    def session(self):
        files = list(self.backups.glob('deployment.*/journal.json'))
        self.assertEqual(len(files), 1)
        return files[0].parent

    def undo(self, answer='o\n'):
        return subprocess.run(['/bin/bash', str(self.session() / 'restaurer.sh')], env=self.env,
                              input=answer, text=True, capture_output=True)

    def engine_args(self, packages='zsh,yazi,starship', mode='copy'):
        return argparse.Namespace(command='deploy', repo=str(self.repo), home=str(self.home), mode=mode,
            packages=packages, replace_commands='false', use_theme='true', fzf_source='', expected='',
            state_root=str(self.backups))

    def test_full_copy_deploys_all_tools_and_both_fonts(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.theme.is_file())
        self.assertIn("alias gs='git status -sb'", self.aliases.read_text())
        self.assertIn('JetBrainsMono Nerd Font', (self.home / '.config/kitty/kitty.conf').read_text())
        self.assertIn('JetBrainsMono Nerd Font', (self.home / '.config/foot/foot.ini').read_text())
        self.assertTrue((self.home / '.config/git/config').is_file())
        self.assertEqual(self.conf.stat().st_mode & 0o777, 0o640)
        self.assertFalse(self.conf.is_symlink())
        self.assertFalse(any(call[0] == 'tldr' for call in self.calls()))
        self.assertEqual(json.loads((self.session() / 'journal.json').read_text())['status'], 'ready')

    def test_dry_run_writes_nothing_and_does_not_download(self):
        self.scenario['missing'] = ['kitty']
        result = self.run_script('--dry-run', answers='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.backups.exists())
        self.assertFalse(self.aliases.exists())
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertTrue(all(call[0] in ['pacman', 'id', 'getent'] for call in self.calls()))

    def test_unknown_or_malformed_selections_are_rejected(self):
        for args in [('--unknown',), ('--only',), ('--mode', 'bad'), ('--only', 'zsh,'), ('--only', 'zsh,zsh'), ('--only', '../tmp')]:
            self.assertNotEqual(self.run_script(*args).returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertFalse(self.backups.exists())

    def test_help_does_not_call_system_tools(self):
        self.assertEqual(self.run_script('--help').returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_refused_or_missing_consent_does_not_deploy(self):
        for answer in ['n\n', '']:
            self.assertNotEqual(self.run_script(answers=answer).returncode, 0)
            self.assertEqual(self.conf.read_text(), self.original)
            self.assertFalse(self.backups.exists())

    def test_selection_does_not_install_or_deploy_unselected_tools(self):
        result = self.run_script('--only', 'btop', answers='o\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / '.config/btop/btop.conf').exists())
        self.assertFalse(self.aliases.exists())
        self.assertFalse(self.theme.exists())
        self.assertFalse(any(call[:2] == ['pacman', '-Q'] and call[-1] in ['kitty', 'foot', 'tealdeer'] for call in self.calls()))

    def test_package_installation_requires_separate_consent(self):
        self.scenario['missing'] = ['kitty']
        self.assertNotEqual(self.run_script(answers='n\n').returncode, 0)
        self.assertFalse((self.root / 'installed').exists())
        self.assertFalse(self.backups.exists())
        self.assertEqual(self.run_script(answers='o\no\nn\nn\n').returncode, 0)
        self.assertIn(['pacman', '-Syu', '--needed', 'kitty'], self.calls())
        self.assertFalse(any('--noconfirm' in call for call in self.calls()))

    def test_duf_is_selected_by_default_and_installation_requires_consent(self):
        self.scenario['missing'] = ['duf']
        result = self.run_script('--dry-run', answers='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('pacman -Syu --needed duf', result.stdout)
        self.assertFalse(self.backups.exists())
        self.assertNotEqual(self.run_script('--only', 'duf', answers='n\n').returncode, 0)
        self.assertFalse((self.root / 'installed').exists())
        result = self.run_script('--only', 'duf', answers='o\no\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['pacman', '-Syu', '--needed', 'duf'], self.calls())
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertEqual(json.loads((self.session() / 'journal.json').read_text())['files'], [])

    def test_duf_does_not_require_a_stow_package(self):
        result = self.run_script('--mode', 'stow', '--only', 'duf', answers='o\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[0] == 'stow' for call in self.calls()))
        self.assertEqual(self.conf.read_text(), self.original)
        result = self.run_script('--mode', 'stow', '--only', 'duf,btop', answers='o\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / '.config/btop/btop.conf').is_symlink())
        stow_calls = [call for call in self.calls() if call[0] == 'stow']
        self.assertEqual(len(stow_calls), 2)
        for call in stow_calls:
            self.assertEqual(call[call.index('--stow') + 1:], ['btop'])

    def test_stow_is_proposed_and_installed_in_copy_mode_without_creating_links(self):
        self.scenario['missing'] = ['stow']
        result = self.run_script('--dry-run', '--only', 'btop', answers='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('pacman -Syu --needed stow', result.stdout)
        self.assertFalse((self.root / 'installed').exists())
        self.assertNotEqual(self.run_script('--only', 'btop', answers='n\n').returncode, 0)
        self.assertFalse((self.root / 'installed').exists())
        result = self.run_script('--only', 'btop', answers='o\no\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['pacman', '-Syu', '--needed', 'stow'], self.calls())
        self.assertFalse(any(call[0] == 'stow' for call in self.calls()))
        self.assertFalse((self.home / '.config/btop/btop.conf').is_symlink())

    def test_package_or_repository_failure_keeps_configs(self):
        for failure in ['unavailable', 'install_failure']:
            self.scenario = {'missing': ['kitty'], failure: True}
            self.assertNotEqual(self.run_script(answers='o\no\n').returncode, 0)
            self.assertEqual(self.conf.read_text(), self.original)
            self.assertFalse(self.backups.exists())

    def test_terminal_merge_preserves_preferences_and_font_size(self):
        kitty = self.home / '.config/kitty/kitty.conf'; kitty.parent.mkdir(parents=True)
        kitty.write_text('# user\nfont_family Old Font\nfont_size 14\nbackground #123456\n')
        foot = self.home / '.config/foot/foot.ini'; foot.parent.mkdir(parents=True)
        foot.write_text('font=Old Font:size=13\n[colors-dark]\nbackground=123456\n')
        result = self.run_script('--only', 'kitty,foot', answers='o\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('font_size 14', kitty.read_text())
        self.assertIn('background #123456', kitty.read_text())
        self.assertIn('font_family JetBrainsMono Nerd Font', kitty.read_text())
        self.assertIn('background=123456', foot.read_text())
        self.assertIn('font=JetBrainsMono Nerd Font:size=13', foot.read_text())
        first = foot.read_text()
        self.assertEqual(self.run_script('--only', 'kitty,foot', answers='o\n').returncode, 0)
        self.assertEqual(foot.read_text(), first)

    def test_restore_recovers_files_removes_new_configs_and_restores_shell(self):
        self.aliases.parent.mkdir(parents=True)
        self.aliases.write_text('# personal aliases\n')
        result = self.run_script(answers='o\nn\no\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'shell').read_text(), str(self.bin / 'zsh'))
        result = self.undo()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertEqual(self.aliases.read_text(), '# personal aliases\n')
        self.assertFalse(self.theme.exists())
        self.assertEqual((self.root / 'shell').read_text(), '/bin/bash')

    def test_restore_refuses_edits_made_after_deployment(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.conf.write_text('# later changes\n')
        result = self.undo()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.conf.read_text(), '# later changes\n')
        self.assertTrue(self.theme.exists())

    def test_delta_preserves_identity_and_restores_personal_gitconfig(self):
        config = self.home / '.gitconfig'
        original = '# personal\n[user]\n    name = Maison\n[core]\n    pager = less\n'
        config.write_text(original)
        result = self.run_script('--only', 'delta', answers='o\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('name = Maison', config.read_text())
        self.assertIn('pager = delta', config.read_text())
        real_git = shutil.which('git')
        if real_git:
            parsed = subprocess.run([real_git, 'config', '--file', str(config), '--get', 'core.pager'], capture_output=True, text=True)
            self.assertEqual(parsed.returncode, 0, parsed.stderr)
            self.assertEqual(parsed.stdout.strip(), 'delta')
        self.assertEqual(self.undo().returncode, 0)
        self.assertEqual(config.read_text(), original)

    def test_external_symlink_is_refused_before_packages(self):
        self.conf.unlink(); other = self.home / 'other'; other.write_text('preserve\n'); self.conf.symlink_to(other)
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(other.read_text(), 'preserve\n')
        self.assertFalse(any(call[0] == 'pacman' for call in self.calls()))

    def test_stow_links_sources_and_restore_restores_previous_files(self):
        result = self.run_script('--mode', 'stow')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.conf.is_symlink())
        self.assertEqual(self.conf.resolve(), self.repo / 'Dotfiles/zsh/.zshrc')
        self.assertTrue(self.theme.is_symlink())
        self.assertFalse((self.home / '.config/cachyos-zsh/install-settings.zsh').is_symlink())
        stow_calls = [call for call in self.calls() if call[0] == 'stow']
        self.assertEqual(len(stow_calls), 2)
        self.assertIn('--simulate', stow_calls[0])
        self.assertIn('--no-folding', stow_calls[1])
        self.assertEqual(self.undo().returncode, 0)
        self.assertFalse(self.conf.is_symlink())
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertFalse(self.theme.exists())

    def test_stow_partial_failure_rolls_back_and_preserves_sources(self):
        source = self.repo / 'Dotfiles/zsh/.zshrc'; before = source.read_bytes()
        self.scenario['stow_partial_failure'] = True
        result = self.run_script('--mode', 'stow')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.conf.is_symlink())
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertEqual(source.read_bytes(), before)
        self.assertFalse(self.theme.exists())

    def test_stow_rules_and_custom_xdg_are_refused_before_actions(self):
        (self.home / '.stowrc').write_text('--adopt\n')
        self.assertNotEqual(self.run_script('--mode', 'stow').returncode, 0)
        self.assertFalse(any(call[0] == 'pacman' for call in self.calls()))
        (self.home / '.stowrc').unlink()
        self.env['XDG_CONFIG_HOME'] = str(self.home / 'custom-config')
        self.assertNotEqual(self.run_script('--mode', 'stow').returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)

    def test_reapplying_owned_stow_links_does_not_modify_sources(self):
        self.assertEqual(self.run_script('--mode', 'stow').returncode, 0)
        source = self.conf.resolve(); original = source.read_bytes()
        self.assertEqual(self.run_script('--mode', 'stow').returncode, 0)
        self.assertEqual(source.read_bytes(), original)

    def test_tldr_download_only_after_its_own_consent(self):
        result = self.run_script('--only', 'tealdeer', answers='o\no\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['tldr', '--update'], self.calls())

    def test_cache_and_font_failures_are_reported_without_claiming_success(self):
        self.scenario['cache_failure'] = True
        self.assertNotEqual(self.run_script('--only', 'tealdeer', answers='o\no\n').returncode, 0)
        self.assertTrue((self.home / '.config/tealdeer/config.toml').exists())
        self.scenario = {'wrong_font': True}
        self.assertNotEqual(self.run_script('--only', 'kitty', answers='o\n').returncode, 0)

    def test_missing_fzf_plugin_source_or_download_failure_keeps_configs(self):
        self.scenario['missing_fzf_source'] = True
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.scenario = {'fzf_mode': 'external', 'clone_failure': True}
        self.assertNotEqual(self.run_script(answers='o\no\n').returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertFalse(list((self.home / '.local/share/cachyos-zsh').glob('.fzf-tab-download.*')))

    def test_fzf_fixed_download_has_dedicated_consent_and_no_update_on_rerun(self):
        self.scenario['fzf_mode'] = 'external'
        self.assertNotEqual(self.run_script(answers='n\n').returncode, 0)
        self.assertFalse(any(call[:2] == ['git', 'clone'] for call in self.calls()))
        self.assertEqual(self.run_script(answers='o\no\nn\nn\n').returncode, 0)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(len([call for call in self.calls() if call[:2] == ['git', 'clone']]), 1)
        self.assertFalse(any('pull' in call for call in self.calls()))

    def test_wrong_fzf_commit_is_rejected(self):
        self.scenario = {'fzf_mode': 'external', 'wrong_commit': True}
        self.assertNotEqual(self.run_script(answers='o\no\n').returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)

    def test_chsh_failures_are_reported_and_configs_kept(self):
        self.scenario['chsh_no_effect'] = True
        result = self.run_script('--only', 'zsh', answers='o\no\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.aliases.exists())
        self.assertEqual((self.root / 'shell').read_text(), '/bin/bash')

    def test_generated_settings_activate_aliases_and_selected_fzf_source(self):
        self.assertEqual(self.run_script('--replace-commands').returncode, 0)
        result = subprocess.run([REAL_ZSH, '-dfi', '-c',
            'source "$HOME/.zshrc"; [[ "$FZF_TAB_READY" == 1 ]] || exit 21; '
            '[[ "${aliases[cat]}" == "bat --paging=never" ]] || exit 22; '
            '[[ "$STARSHIP_CONFIG" == "$HOME/.config/starship.toml" ]] || exit 23',
            ], env=self.env, input='', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_no_theme_and_custom_paths_in_copy_mode(self):
        self.env['XDG_CONFIG_HOME'] = str(self.home / 'configuration')
        self.env['ZDOTDIR'] = str(self.home / 'zsh-home')
        result = self.run_script('--only', 'zsh,starship', '--no-theme', answers='o\nn\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / 'zsh-home/.zshrc').is_file())
        self.assertTrue((self.home / 'configuration/cachyos-zsh/aliases.zsh').is_file())
        self.assertFalse((self.home / 'configuration/starship.toml').exists())

    def test_preview_token_rejects_later_source_changes(self):
        args = self.engine_args()
        with patch.dict(os.environ, self.env, clear=True):
            plan, token = ENGINE.prepare(args)
            (self.repo / 'Dotfiles/zsh/.zshrc').write_text('# changed after preview\n')
            args.expected = token
            with self.assertRaises(ENGINE.Refused): ENGINE.deploy(args)
        self.assertFalse(self.backups.exists())
        self.assertEqual(self.conf.read_text(), self.original)

    def test_real_atomic_write_failure_rolls_back_prior_files(self):
        args = self.engine_args()
        real = ENGINE.atomic_bytes
        failed = False
        def fail_once(path, data, mode=0o600):
            nonlocal failed
            if path == self.aliases and not failed:
                failed = True
                raise OSError('simulated atomic write failure')
            return real(path, data, mode)
        with patch.dict(os.environ, self.env, clear=True), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            _, args.expected = ENGINE.prepare(args)
            with patch.object(ENGINE, 'atomic_bytes', side_effect=fail_once):
                with self.assertRaises(OSError): ENGINE.deploy(args)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertFalse(self.aliases.exists())
        self.assertFalse(self.theme.exists())

    def test_invalid_zsh_source_does_not_deploy(self):
        (self.repo / 'Dotfiles/zsh/.config/cachyos-zsh/aliases.zsh').write_text('if\n')
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.conf.read_text(), self.original)
        self.assertFalse(self.aliases.exists())


if __name__ == '__main__':
    unittest.main()
