"""Cohérence statique et lecture seule : listes, références et liens locaux."""
import ast
from pathlib import Path
import re
import subprocess
import unittest
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


class RepositoryTests(unittest.TestCase):
    def test_native_catalogue_matches_the_groups_in_help(self):
        command = ['bash', str(ROOT / '05 - package_install.sh')]
        help_text = subprocess.check_output([*command, '--help'], text=True)
        groups = help_text.split('Groupes disponibles :\n', 1)[1].split()
        self.assertTrue(groups)
        self.assertEqual(len(groups), len(set(groups)))

        packages = subprocess.check_output([*command, '--list'], text=True).splitlines()
        self.assertTrue(packages)
        self.assertEqual(len(packages), len(set(packages)))
        combined = []
        for group in groups:
            with self.subTest(group=group):
                listing = subprocess.check_output([*command, '--groups', group, '--list'], text=True)
                combined.extend(listing.splitlines())
        self.assertEqual(packages, combined)
        selected = subprocess.check_output([*command, '--groups', ','.join(groups), '--list'], text=True)
        self.assertEqual(selected.splitlines(), packages)

    def test_zsh_module_list_matches_engine(self):
        shell = (ROOT / '04 - install_zsh.sh').read_text()
        modules = re.search(r'^ALL_MODULES=\(([^)]+)\)', shell, re.M).group(1).split()
        tree = ast.parse((ROOT / 'scripts/zsh_deploy.py').read_text())
        engine = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign)
                      and any(isinstance(t, ast.Name) and t.id == 'MODULES' for t in node.targets))
        self.assertEqual(modules, list(engine))
        self.assertIn(','.join(modules), (ROOT / 'docs/zsh.md').read_text())
        self.assertIn(f'{len(modules)} modules', (ROOT / 'README.md').read_text())

    def test_test_script_references_exist(self):
        for file in (ROOT / 'tests').glob('test_*.py'):
            for node in ast.parse(file.read_text()).body:
                if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'SCRIPT' for t in node.targets):
                    names = [n.value for n in ast.walk(node.value) if isinstance(n, ast.Constant)
                             and isinstance(n.value, str) and n.value.endswith('.sh')]
                    for name in names:
                        self.assertTrue((ROOT / name).is_file(), f'{file.name} : {name}')

    def test_markdown_local_links_exist(self):
        for file in ROOT.rglob('*.md'):
            if '.git' in file.relative_to(ROOT).parts:
                continue
            for raw in re.findall(r'\[[^\]\n]+\]\(([^)\n]+)\)', file.read_text()):
                target = raw.strip('<>').split('#', 1)[0]
                if not target or re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', target):
                    continue
                self.assertTrue((file.parent / unquote(target)).exists(), f'{file.relative_to(ROOT)} : {target}')

    def test_archives_are_identified_and_preserved(self):
        text = (ROOT / 'docs/dotfiles.md').read_text()
        self.assertIn('archives', text)
        self.assertTrue((ROOT / 'config/zsh/zshrc.zsh').is_file())
        self.assertTrue((ROOT / 'config/zsh/aliases.zsh').is_file())


if __name__ == '__main__': unittest.main()
