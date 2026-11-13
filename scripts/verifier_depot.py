#!/usr/bin/env python3
"""Vérifier le dépôt avec les outils présents ; tests dans des fixtures temporaires."""
import argparse
import ast
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--statique', action='store_true', help='Syntaxes et cohérence documentaire seulement, sans tests écrivant des fixtures.')
    args = parser.parse_args()
    failures = 0
    for source in sorted(ROOT.glob('*.sh')):
        result = subprocess.run(['bash', '-n', str(source)])
        failures += result.returncode != 0
    for folder in ('scripts', 'tests'):
        for source in sorted((ROOT / folder).glob('*.py')):
            try:
                ast.parse(source.read_text(), filename=str(source))
            except SyntaxError as exc:
                print(exc, file=sys.stderr)
                failures += 1
    if shutil.which('zsh'):
        for source in sorted((ROOT / 'Dotfiles').rglob('*')):
            if source.is_file() and (source.suffix == '.zsh' or source.name == '.zshrc'):
                failures += subprocess.run(['zsh', '-n', str(source)]).returncode != 0
    else:
        print('IGNORÉ : syntaxe Zsh (outil absent).')
    # Les tests de cohérence ne créent aucun fichier, même en mode statique.
    result = subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_repository.py', '-v'], cwd=ROOT)
    failures += result.returncode != 0
    if not args.statique and not failures:
        # Exécuter la suite entière seulement après les contrôles statiques.
        result = subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-v'], cwd=ROOT)
        failures += result.returncode != 0
    print('Contrôles terminés ; les tests ignorés ne constituent pas des validations.', flush=True)
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
