"""Cohérence statique et lecture seule : listes, références et liens locaux."""
import ast
from pathlib import Path
import re
import subprocess
import unittest
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


class RepositoryTests(unittest.TestCase):
    def test_native_catalogue_matches_documentation(self):
        packages = subprocess.check_output(['bash', str(ROOT / '05 - package_install.sh'), '--list'], text=True).splitlines()
        text = (ROOT / 'docs/package-install.md').read_text()
        catalogue = text.split('### Catalogue actuel\n', 1)[1].split('## Provenance', 1)[0]
        rows = re.findall(r'^\| `[^`]+` \| (.*?) \|$', catalogue, re.M)
        documented = [item for row in rows for item in re.findall(r'`([^`]+)`', row)]
        self.assertEqual(documented, packages)
        for filename in ('README.md', 'docs/package-install.md', 'docs/flatpak-install.md'):
            self.assertIn(f'{len(packages)} paquets', (ROOT / filename).read_text(), filename)

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
