#!/usr/bin/env python3
"""Diagnostic en lecture seule : aucun sudo, téléchargement ni création de fichier."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]


def read_command(command):
    try:
        result = subprocess.run(command, text=True, capture_output=True, timeout=10)
        return result.returncode, result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return 2, ''


def target_state(source, target):
    try:
        parent = target.parent
        while parent != parent.parent:
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                return 'À EXAMINER : parent redirigé ou non répertoire'
            parent = parent.parent
        if target.is_symlink():
            return 'lien vers le dépôt' if target.resolve() == source.resolve() else 'À EXAMINER : lien externe'
        if not target.exists():
            return 'absent'
        if not target.is_file():
            return 'À EXAMINER : cible spéciale'
        if target.stat().st_size != source.stat().st_size:
            return 'À EXAMINER : fichier différent'
        return 'identique' if target.read_bytes() == source.read_bytes() else 'À EXAMINER : fichier différent'
    except (OSError, RuntimeError):
        return 'À EXAMINER : cible illisible ou lien circulaire'


def inspect_targets(repo, home, config, zdotdir):
    """Lister les conflits potentiels sans lire le contenu dans le compte rendu."""
    entries = []
    for source in sorted((repo / 'Dotfiles').glob('*/**/*')):
        if not source.is_file() or source.is_symlink():
            continue
        relative = source.relative_to(repo / 'Dotfiles').parts[1:]
        if relative == ('.zshrc',):
            target = zdotdir / '.zshrc'
        elif relative and relative[0] == '.config':
            target = config.joinpath(*relative[1:])
        else:
            continue
        entries.append((target, target_state(source, target)))
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, help='Dossier à examiner ; défaut : compte courant.')
    args = parser.parse_args()
    home = (args.home or Path.home()).absolute()
    # Un HOME explicite sert aussi aux diagnostics isolés : ignorer alors les
    # chemins XDG personnels de l'environnement.
    config = home / '.config' if args.home else Path(os.environ.get('XDG_CONFIG_HOME', str(home / '.config')))
    zdotdir = home if args.home else Path(os.environ.get('ZDOTDIR', str(home)))
    if not config.is_absolute() or not zdotdir.is_absolute():
        parser.error('XDG_CONFIG_HOME et ZDOTDIR doivent être absolus.')
    print('Diagnostic en lecture seule ; aucun changement ni validation native complète.')
    print('Hôte : ' + platform.system())
    missing = []
    incomplete = False
    tools = ('bash', 'python3', 'pacman', 'pacman-conf', 'systemctl', 'firewall-cmd',
             'flatpak', 'distrobox', 'podman', 'flock', 'git', 'stow', 'zsh', 'fc-match',
             'starship', 'yazi', 'btop', 'tldr', 'bat', 'fzf', 'zoxide', 'eza', 'rg',
             'fd', 'delta', 'lazygit', 'kitty', 'foot', 'duf')
    for tool in tools:
        present = shutil.which(tool) is not None
        print(f"{'présent' if present else 'absent'} : {tool}")
        if not present:
            missing.append(tool)
    if platform.system() == 'Linux':
        if shutil.which('pacman-conf'):
            code, output = read_command(['pacman-conf', '--repo-list'])
            incomplete |= code != 0 or not output
            print('Dépôts configurés : ' + (', '.join(output.splitlines()) if code == 0 else 'lecture impossible'))
        if shutil.which('systemctl'):
            for unit in ('bluetooth.service', 'fstrim.timer', 'paccache.timer', 'firewalld.service', 'ufw.service'):
                code, output = read_command(['systemctl', 'show', unit, '--property=LoadState,ActiveState,UnitFileState'])
                incomplete |= code != 0 or not output
                print(unit + ' : ' + (output.replace('\n', '; ') if code == 0 else 'lecture impossible'))
        if shutil.which('pacman'):
            code, output = read_command(['bash', str(REPO / '05 - package_install.sh'), '--list'])
            packages = output.splitlines() if code == 0 else []
            if not packages:
                incomplete = True
                print('Catalogue natif illisible ; inventaire non effectué.')
            absent = [p for p in packages if read_command(['pacman', '-Q', p])[0] != 0]
            incomplete |= bool(absent)
            if packages:
                print('Paquets natifs absents ou illisibles : ' + (', '.join(absent) if absent else 'aucun dans la liste examinée'))
    else:
        print('Contrôles Pacman et systemd ignorés : hôte hors Linux.')
    if not home.is_dir():
        print('Dossier personnel absent ; examen des configurations impossible.')
        return 1
    conflicts = 0
    for target, state in inspect_targets(REPO, home, config, zdotdir):
        if state != 'absent':
            print(f'{state} : {target}')
        if state.startswith('À EXAMINER'):
            conflicts += 1
    print(f'{conflicts} cible(s) à examiner ; les fichiers absents ne sont pas des conflits.')
    print('Ce relevé ne teste ni les connexions, ni le rendu graphique, ni la restauration système.')
    return 1 if conflicts or missing or incomplete else 0


if __name__ == '__main__':
    raise SystemExit(main())
