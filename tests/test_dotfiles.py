"""Vérifications des paquets Stow, sans déploiement dans le HOME réel."""
import importlib
import configparser
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

DOTFILES = Path(__file__).resolve().parents[1] / 'Dotfiles'
PACKAGES = tuple(sorted(path.name for path in DOTFILES.iterdir() if path.is_dir()))
ZSH = shutil.which('zsh')
STOW = shutil.which('stow')
RUBY = shutil.which('ruby')
GIT = shutil.which('git')
try:
    toml = importlib.import_module('tomllib')
except ImportError:
    try:
        toml = importlib.import_module('pip._vendor.tomli')
    except ImportError:
        toml = None


def package_files():
    for package in PACKAGES:
        for file in sorted((DOTFILES / package).rglob('*')):
            if file.is_file() or file.is_symlink():
                yield package, file, file.relative_to(DOTFILES / package)


class DotfilesTests(unittest.TestCase):
    def setUp(self):
        temp_parent = '/private/tmp' if Path('/private/tmp').is_dir() else None
        self.temp = tempfile.TemporaryDirectory(dir=temp_parent, prefix="dotfiles 'fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / 'home'
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'))
        for name in ['ZDOTDIR', 'STARSHIP_CONFIG', 'FZF_DEFAULT_OPTS', 'EZA_COLORS',
                     'RIPGREP_CONFIG_PATH', '_ZO_ECHO', 'CACHYOS_ZSH_REPLACE_COMMANDS',
                     'CACHYOS_ZSH_FZF_TAB_SOURCE', 'CACHYOS_ZSH_USE_THEME', 'XDG_DATA_HOME']:
            self.env.pop(name, None)

    def link_fixture(self):
        # Mappage explicite de fichiers pour le test de chargement seulement.
        # GNU Stow est testé séparément lorsqu'il est disponible.
        for _, source, relative in package_files():
            target = self.home / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source)

    def test_packages_do_not_conflict_or_contain_runtime_data(self):
        self.assertEqual(len(PACKAGES), 15)
        targets = set()
        for package, file, relative in package_files():
            with self.subTest(package=package, file=str(relative)):
                self.assertFalse(file.is_symlink(), 'Les sources doivent être des fichiers versionnés ordinaires')
                self.assertTrue(relative == Path('.zshrc') or relative.parts[0] == '.config')
                self.assertNotIn(str(relative), targets, 'Deux paquets ne doivent pas déployer le même fichier')
                targets.add(str(relative))
                self.assertFalse(any(part in ['.git', '.cache', '__pycache__'] for part in relative.parts))
                self.assertNotIn(file.suffix, ['.zwc', '.pyc'])

    @unittest.skipUnless(toml, 'Parseur TOML absent ; aucun téléchargement')
    def test_toml_files_parse_and_themes_are_self_contained(self):
        for file in DOTFILES.rglob('*.toml'):
            with self.subTest(file=str(file)):
                # loads(str) convient aussi au tomli déjà fourni avec pip sur Python 3.9.
                data = toml.loads(file.read_text())
                if file.parent.name == 'tealdeer':
                    self.assertFalse(data['updates']['auto_update'])
                if file.name == 'starship.toml':
                    self.assertIn(data['palette'], data['palettes'])
                if file.name == 'theme.toml':
                    self.assertNotIn('flavor', data, 'Aucun flavor externe ne doit être nécessaire')

    @unittest.skipUnless(RUBY, 'Parseur YAML Ruby absent ; aucun téléchargement')
    def test_lazygit_yaml_disables_automatic_network_operations(self):
        file = DOTFILES / 'lazygit/.config/lazygit/config.yml'
        result = subprocess.run([RUBY, '-ryaml', '-rjson', '-e',
                                 'puts JSON.generate(YAML.safe_load(File.read(ARGV[0])))', str(file)],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertFalse(data['git']['autoFetch'])
        self.assertEqual(data['update']['method'], 'never')

    def test_btop_file_contains_only_simple_assignments(self):
        # Contrôle du format, pas validation par le binaire btop.
        file = DOTFILES / 'btop/.config/btop/btop.conf'
        for line in file.read_text().splitlines():
            if line.strip() and not line.startswith('#'):
                self.assertRegex(line, r'^[a-z_]+ = ("[^"\n]*"|True|False|[0-9]+)$')

    def test_terminal_font_files_select_jetbrains_nerd_font(self):
        kitty = (DOTFILES / 'kitty/.config/kitty/kitty.conf').read_text()
        self.assertIn('font_family JetBrainsMono Nerd Font', kitty)
        foot = configparser.ConfigParser()
        foot.read(DOTFILES / 'foot/.config/foot/foot.ini')
        self.assertEqual(foot['main']['font'], 'JetBrainsMono Nerd Font:size=11')

    @unittest.skipUnless(GIT, 'Git absent')
    def test_delta_git_configuration_is_parseable_and_contains_no_identity(self):
        file = DOTFILES / 'delta/.config/git/config'
        result = subprocess.run([GIT, 'config', '--file', str(file), '--list'],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('core.pager=delta', result.stdout)
        self.assertNotIn('user.', result.stdout)
        self.assertNotIn('credential.', result.stdout)

    @unittest.skipUnless(ZSH, 'Zsh absent ; aucun téléchargement')
    def test_all_zsh_files_parse_without_rendering_or_placeholders(self):
        files = [DOTFILES / 'zsh/.zshrc'] + list(DOTFILES.rglob('*.zsh'))
        for file in files:
            with self.subTest(file=str(file)):
                self.assertNotRegex(file.read_text(), r'@[A-Z_]+@')
                result = subprocess.run([ZSH, '-f', '-n', str(file)], env=self.env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def prepare_shell(self):
        self.link_fixture()
        commands = self.root / 'bin'
        commands.mkdir()
        script = '#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$DOTFILES_FIXTURE_LOG"\nprintf ":\\n"\n'
        for command in ['fzf', 'zoxide', 'starship']:
            file = commands / command
            file.write_text(script)
            file.chmod(0o755)
        self.env['PATH'] = str(commands) + ':/usr/bin:/bin'
        self.env['DOTFILES_FIXTURE_LOG'] = str(self.root / 'calls')
        # Point d'entrée local factice : aucun code externe n'est téléchargé.
        (self.home / 'plugin.zsh').write_text('typeset -g FZF_TAB_READY=1\n')
        (self.home / '.zshrc.local.pre').write_text('export CACHYOS_ZSH_FZF_TAB_SOURCE="$HOME/plugin.zsh"\n')
        (self.home / '.zshrc.local').write_text("alias gs='git status --porcelain'\n")

    @unittest.skipUnless(ZSH, 'Zsh absent ; aucun téléchargement')
    def test_shell_loads_stowed_aliases_and_environment_fragments(self):
        self.prepare_shell()
        command = ('source "$HOME/.zshrc"; '
                   '[[ "${aliases[gs]}" == "git status --porcelain" ]] || exit 21; '
                   '[[ "${aliases[d]}" == "dirs -v" ]] || exit 22; '
                   '[[ "$FZF_DEFAULT_OPTS" == *--height=60%* ]] || exit 23; '
                   '[[ "$_ZO_ECHO" == 1 ]] || exit 24; '
                   '[[ "$EZA_COLORS" == *di=* ]] || exit 25; '
                   '[[ "$RIPGREP_CONFIG_PATH" == "$HOME/.config/ripgrep/config" ]] || exit 26; '
                   '[[ "$STARSHIP_CONFIG" == "$HOME/.config/starship.toml" ]] || exit 27; '
                   '[[ "$FZF_TAB_READY" == 1 ]] || exit 28; '
                   '(( ${+aliases[cat]} == 0 )) || exit 29')
        result = subprocess.run([ZSH, '-dfi', '-c', command], env=self.env, input='', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'calls').read_text().splitlines()
        self.assertEqual(len(calls), 3)
        self.assertTrue(all(line.endswith(('fzf --zsh', 'zoxide init zsh', 'starship init zsh')) for line in calls))

    @unittest.skipUnless(ZSH, 'Zsh absent ; aucun téléchargement')
    def test_explicit_environment_preferences_are_preserved(self):
        self.prepare_shell()
        self.env.update(FZF_DEFAULT_OPTS='--height=30%', EZA_COLORS='di=31',
                        RIPGREP_CONFIG_PATH='personal-rg', STARSHIP_CONFIG='personal-starship')
        command = ('source "$HOME/.zshrc"; [[ "$FZF_DEFAULT_OPTS" == --height=30% ]] || exit 21; '
                   '[[ "$EZA_COLORS" == di=31 ]] || exit 22; '
                   '[[ "$RIPGREP_CONFIG_PATH" == personal-rg ]] || exit 23; '
                   '[[ "$STARSHIP_CONFIG" == personal-starship ]] || exit 24')
        result = subprocess.run([ZSH, '-dfi', '-c', command], env=self.env, input='', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(STOW, 'GNU Stow absent : déploiement natif non vérifié ; aucun outil installé')
    def test_real_stow_simulate_apply_and_delete_in_temporary_target(self):
        base = [STOW, '--dir=' + str(DOTFILES), '--target=' + str(self.home), '--no-folding']
        result = subprocess.run(base + ['--simulate', '--stow'] + list(PACKAGES),
                                cwd=self.root, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])
        result = subprocess.run(base + ['--stow'] + list(PACKAGES), cwd=self.root, env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for _, source, relative in package_files():
            target = self.home / relative
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), source)
        result = subprocess.run(base + ['--delete'] + list(PACKAGES), cwd=self.root, env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(path.is_symlink() for path in self.home.rglob('*')))


if __name__ == '__main__':
    unittest.main()
