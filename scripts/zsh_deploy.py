#!/usr/bin/env python3
"""Déployer les configurations explicitement sélectionnées, sans installation.

preview n'écrit rien. deploy exige le jeton du plan approuvé. Les sources restent
intactes. Le journal et une copie de ce moteur permettent une restauration future.
"""
import argparse
import contextlib
import fcntl
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import tempfile

MODULES = ('zsh', 'starship', 'yazi', 'btop', 'tealdeer', 'bat', 'fzf', 'zoxide',
           'eza', 'ripgrep', 'fd', 'delta', 'lazygit', 'kitty', 'foot')
FONT = 'JetBrainsMono Nerd Font'
START = '# >>> cachyos-zsh-font'
END = '# <<< cachyos-zsh-font'


class Refused(RuntimeError):
    pass


def info(message):
    print(message, file=sys.stderr)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def signature(path):
    if path.is_symlink():
        return {'kind': 'link', 'link': os.readlink(path)}
    if not path.exists():
        return {'kind': 'missing'}
    if not path.is_file():
        raise Refused('Cible non régulière : ' + str(path))
    return {'kind': 'file', 'sha256': digest(path.read_bytes()),
            'mode': stat.S_IMODE(path.stat().st_mode)}


def check_parents(target, home):
    if target == home or home not in target.parents:
        raise Refused('Cible en dehors du dossier personnel : ' + str(target))
    parent = target.parent
    while parent != home:
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise Refused('Parent redirigé ou non répertoire : ' + str(parent))
        parent = parent.parent


def terminal_font(data, terminal):
    """Modifier seulement les polices en copie ; préserver les autres réglages."""
    text = data.decode('utf-8')
    size = 'size=11'
    if terminal == 'foot':
        # Lire aussi la taille du bloc géré précédent avant de le retirer.
        section = 'main'
        for original in text.splitlines():
            header = re.match(r'\s*\[([^]]+)\]\s*$', original)
            if header:
                section = header.group(1)
            if section == 'main' and re.match(r'^\s*font\s*=', original):
                previous_size = re.search(r':((?:pixel)?size=[0-9]+(?:\.[0-9]+)?)', original)
                if previous_size:
                    size = previous_size.group(1)
    text = re.sub(r'(?ms)^' + re.escape(START) + r'\n.*?^' + re.escape(END) + r'\n?', '', text)
    lines, section = [], 'main'
    keys = ('font_family', 'bold_font', 'italic_font', 'bold_italic_font') if terminal == 'kitty' else (
        'font', 'font-bold', 'font-italic', 'font-bold-italic')
    for line in text.splitlines():
        match = re.match(r'\s*\[([^]]+)\]\s*$', line)
        if match:
            section = match.group(1)
        active = re.match(r'^\s*(' + '|'.join(map(re.escape, keys)) + r')(?:\s*=\s*|\s+)(.*)$', line)
        if active and (terminal == 'kitty' or section == 'main'):
            if active.group(1) == 'font':
                found = re.search(r':((?:pixel)?size=[0-9]+(?:\.[0-9]+)?)', active.group(2))
                if found:
                    size = found.group(1)
            line = '# Ancien réglage de police : ' + line
        lines.append(line)
    if terminal == 'kitty':
        block = f'font_family {FONT}\nbold_font auto\nitalic_font auto\nbold_italic_font auto'
    else:
        block = (f'[main]\nfont={FONT}:{size}\nfont-bold={FONT}:style=Bold:{size}\n'
                 f'font-italic={FONT}:style=Italic:{size}\nfont-bold-italic={FONT}:style=Bold Italic:{size}')
    return ('\n'.join(lines).rstrip() + '\n\n' + START + '\n' + block + '\n' + END + '\n').encode()


def settings(args):
    return (f'# Réglages de cette installation ; surcharges : ~/.zshrc.local.pre\n'
            f'typeset -g CACHYOS_ZSH_REPLACE_COMMANDS=${{CACHYOS_ZSH_REPLACE_COMMANDS:-{args.replace_commands}}}\n'
            f'typeset -g CACHYOS_ZSH_USE_THEME=${{CACHYOS_ZSH_USE_THEME:-{args.use_theme}}}\n'
            'if [[ -z ${CACHYOS_ZSH_FZF_TAB_SOURCE:-} ]]; then\n'
            f'    typeset -g CACHYOS_ZSH_FZF_TAB_SOURCE={shlex.quote(args.fzf_source)}\nfi\n').encode()


def prepare(args):
    repo = Path(args.repo).resolve()
    home = Path(os.path.abspath(args.home))
    if not home.is_dir() or home.is_symlink():
        raise Refused('Dossier personnel absent ou symbolique.')
    config = Path(os.path.abspath(os.environ.get('XDG_CONFIG_HOME', str(home / '.config'))))
    zdotdir = Path(os.path.abspath(os.environ.get('ZDOTDIR', str(home))))
    if args.mode == 'stow':
        if config != home / '.config' or zdotdir != home:
            raise Refused('Stow exige ici ~/.config et ~/.zshrc ; utiliser le mode copy pour les chemins XDG personnalisés.')
        for rc in (home / '.stowrc', repo / '.stowrc', home / '.stow-global-ignore', Path('/etc/stowrc')):
            if rc.exists() or rc.is_symlink():
                raise Refused('Règle Stow implicite à examiner avant application : ' + str(rc))
    modules = args.packages.split(',')
    if not modules or len(set(modules)) != len(modules) or any(module not in MODULES for module in modules):
        raise Refused('Liste de paquets vide, inconnue ou dupliquée.')
    files, seen = [], set()
    for module in modules:
        base = repo / 'Dotfiles' / module
        if not base.is_dir() or base.is_symlink():
            raise Refused('Paquet source absent ou symbolique : ' + str(base))
        for source in sorted(base.rglob('*')):
            if source.is_symlink():
                raise Refused('Source symbolique refusée : ' + str(source))
            if source.is_dir():
                continue
            if not source.is_file() or source.name == '.stow-local-ignore':
                raise Refused('Source spéciale ou règle implicite : ' + str(source))
            relative = source.relative_to(base)
            if relative == Path('.zshrc'):
                target = zdotdir / '.zshrc'
            elif relative.parts[0] == '.config':
                target = config.joinpath(*relative.parts[1:])
            else:
                raise Refused('Chemin source non pris en charge : ' + str(relative))
            check_parents(target, home)
            if target in seen:
                raise Refused('Cible dupliquée : ' + str(target))
            seen.add(target)
            before = signature(target)
            if before['kind'] == 'link' and target.resolve() != source.resolve():
                raise Refused('Lien externe conservé, migration manuelle requise : ' + str(target))
            content = source.read_bytes()
            if args.mode == 'copy' and module in ('kitty', 'foot') and before['kind'] != 'missing':
                content = terminal_font(target.read_bytes(), module)
            files.append({'target': str(target), 'source': str(source), 'module': module,
                          'content': content.hex(), 'source_hash': digest(source.read_bytes()),
                          'before': before, 'method': args.mode})
    if 'zsh' in modules:
        target = config / 'cachyos-zsh/install-settings.zsh'
        check_parents(target, home)
        if target in seen or target.is_symlink():
            raise Refused('Fichier de réglages redirigé ou en conflit : ' + str(target))
        files.append({'target': str(target), 'source': None, 'module': 'zsh',
                      'content': settings(args).hex(), 'source_hash': None,
                      'before': signature(target), 'method': 'copy'})
    if 'delta' in modules:
        target = home / '.gitconfig'
        # ~/.gitconfig est prioritaire sur ~/.config/git/config. Ne modifier que
        # la présentation, en conservant intégralement les sections personnelles.
        if target.exists() or target.is_symlink():
            if target.is_symlink():
                raise Refused('.gitconfig symbolique : intervention manuelle requise, aucun écrasement.')
            original = target.read_text()
            marker = '# >>> cachyos-zsh-delta'
            original = re.sub(r'(?ms)^' + re.escape(marker) + r'\n.*?^# <<< cachyos-zsh-delta\n?', '', original)
            content = (original.rstrip() + '\n\n' + marker + '\n[core]\n    pager = delta\n'
                       '[interactive]\n    diffFilter = delta --color-only\n# <<< cachyos-zsh-delta\n').encode()
            files.append({'target': str(target), 'source': None, 'module': 'delta',
                          'content': content.hex(), 'source_hash': None,
                          'before': signature(target), 'method': 'copy'})
    plan = {'home': str(home), 'repo': str(repo), 'mode': args.mode, 'modules': modules, 'files': files}
    token = digest(json.dumps(plan, sort_keys=True).encode())
    return plan, token


def wanted(entry):
    if entry['method'] == 'stow':
        return {'kind': 'link', 'resolved': str(Path(entry['source']).resolve())}
    return {'kind': 'file', 'sha256': digest(bytes.fromhex(entry['content']))}


def matches(path, desired):
    if desired['kind'] == 'link' and 'resolved' in desired:
        return path.is_symlink() and str(path.resolve()) == desired['resolved']
    actual = signature(path)
    return all(actual.get(key) == value for key, value in desired.items())


def atomic_bytes(path, data, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=path.name + '.stage.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def write_journal(session, journal):
    atomic_bytes(session / 'journal.json', (json.dumps(journal, ensure_ascii=False, indent=2) + '\n').encode())


def validate_zsh(plan):
    for entry in plan['files']:
        if Path(entry['target']).name == '.zshrc' or entry['target'].endswith('.zsh'):
            result = subprocess.run(['zsh', '-f', '-n'], input=bytes.fromhex(entry['content']), capture_output=True)
            if result.returncode:
                raise Refused('Syntaxe Zsh invalide : ' + entry['target'] + '\n' + result.stderr.decode(errors='replace'))
    documents = [entry for entry in plan['files'] if entry['target'].endswith('.toml')]
    if documents:
        try:
            parser = importlib.import_module('tomllib')
        except ImportError:
            try:
                parser = importlib.import_module('pip._vendor.tomli')
            except ImportError:
                raise Refused('Un parseur TOML existant est requis (tomllib avec Python 3.11+, ou tomli fourni par pip). Aucun outil installé automatiquement.')
        for entry in documents:
            try:
                parser.loads(bytes.fromhex(entry['content']).decode('utf-8'))
            except ValueError as error:
                raise Refused('Syntaxe TOML invalide : ' + entry['target'] + ' : ' + str(error))


def restore_files(session, journal, finish=True):
    # Tout vérifier avant de restaurer : ne jamais écraser une édition ultérieure.
    active = [entry for entry in journal['files'] if entry.get('started')]
    for entry in active:
        target = Path(entry['target'])
        check_parents(target, Path(journal['home']))
        if not (matches(target, entry['before']) or matches(target, wanted(entry)) or
                (entry['method'] == 'stow' and signature(target)['kind'] == 'missing')):
            raise Refused('Fichier modifié depuis le déploiement, restauration refusée : ' + str(target))
    for entry in reversed(active):
        target, before = Path(entry['target']), entry['before']
        if matches(target, before):
            continue
        if before['kind'] == 'file':
            atomic_bytes(target, (session / entry['backup']).read_bytes(), before['mode'])
        elif before['kind'] == 'link':
            if target.exists() or target.is_symlink():
                target.unlink()
            target.symlink_to(before['link'])
        elif target.exists() or target.is_symlink():
            target.unlink()
    journal['status'] = 'restored' if finish else 'files-restored'
    write_journal(session, journal)


def deploy(args):
    plan, token = prepare(args)
    if args.command == 'preview':
        for entry in plan['files']:
            state = entry['before']['kind']
            action = 'déjà conforme' if matches(Path(entry['target']), wanted(entry)) else entry['method']
            info(f"[{action}] {entry['target']} (état initial : {state})")
        if any(module in plan['modules'] for module in ('kitty', 'foot')):
            info('Police : JetBrainsMono Nerd Font pour les terminaux choisis. En copie, les autres réglages sont conservés ; en Stow, les configurations canoniques sont liées après sauvegarde.')
        if any(entry['module'] == 'delta' and entry['source'] is None for entry in plan['files']):
            info('Delta : compléter le .gitconfig existant uniquement pour le pager et diffFilter ; identité et autres réglages conservés, fichier intégralement sauvegardé.')
        print(token)
        return
    if token != args.expected:
        raise Refused('Sources ou cibles modifiées depuis le plan approuvé ; relancer la préparation.')
    validate_zsh(plan)
    if args.mode == 'stow' and not shutil.which('stow'):
        raise Refused('GNU Stow absent ; aucune configuration modifiée.')
    home = Path(plan['home'])
    state_root = Path(os.path.abspath(args.state_root))
    check_parents(state_root / 'placeholder', home)
    state_root.mkdir(parents=True, exist_ok=True)
    lock_path = state_root / '.deployment.lock'
    if lock_path.is_symlink():
        raise Refused('Verrou symbolique refusé.')
    with lock_path.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Refused('Une autre configuration est en cours.')
        # Revalider après acquisition du verrou, sans réutiliser un état ancien.
        fresh, fresh_token = prepare(args)
        if fresh_token != token:
            raise Refused('Configuration modifiée pendant la préparation.')
        session = Path(tempfile.mkdtemp(prefix='deployment.', dir=state_root))
        session.chmod(0o700)
        journal = dict(fresh, uid=os.getuid(), status='preparing')
        for index, entry in enumerate(journal['files']):
            entry['backup'] = f'original.{index}'
            entry['started'] = False
            if entry['before']['kind'] == 'file':
                shutil.copy2(entry['target'], session / entry['backup'])
        shutil.copyfile(__file__, session / 'restore_engine.py')
        undo = '#!/usr/bin/env bash\nset -euo pipefail\nexec python3 -B ' + shlex.quote(str(session / 'restore_engine.py')) + ' restore ' + shlex.quote(str(session)) + '\n'
        atomic_bytes(session / 'restaurer.sh', undo.encode())
        write_journal(session, journal)
        info('Sauvegardes et retour arrière : ' + str(session))
        try:
            for entry in journal['files']:
                target = Path(entry['target'])
                check_parents(target, home)
                if not matches(target, entry['before']):
                    raise Refused('Cible modifiée avant remplacement : ' + str(target))
                if matches(target, wanted(entry)):
                    continue
                entry['started'] = True
                write_journal(session, journal)
                if entry['method'] == 'copy':
                    atomic_bytes(target, bytes.fromhex(entry['content']), entry['before'].get('mode', 0o600))
                elif target.exists() or target.is_symlink():
                    target.unlink()
            if args.mode == 'stow':
                command = ['stow', '--dir=' + str(Path(args.repo).resolve() / 'Dotfiles'),
                           '--target=' + str(home), '--no-folding', '--verbose']
                for operation in (['--simulate', '--stow'], ['--stow']):
                    result = subprocess.run(command + operation + plan['modules'], cwd=session, capture_output=True, text=True)
                    info(result.stdout + result.stderr)
                    if result.returncode:
                        raise Refused('Échec Stow ; restauration des fichiers sauvegardés.')
            for entry in journal['files']:
                if entry['source'] and digest(Path(entry['source']).read_bytes()) != entry['source_hash']:
                    raise Refused('Source modifiée pendant le déploiement : ' + entry['source'])
                if not matches(Path(entry['target']), wanted(entry)):
                    raise Refused('Vérification après déploiement impossible : ' + entry['target'])
            validate_zsh(journal)
            journal['status'] = 'ready'
            write_journal(session, journal)
        except BaseException:
            try:
                restore_files(session, journal)
            except BaseException as recovery:
                info('Restauration incomplète : ' + str(recovery) + '. Voir ' + str(session / 'restaurer.sh'))
            raise
        print(session)


def load_session(path):
    session = Path(path).resolve()
    if session.stat().st_uid != os.getuid():
        raise Refused('Session appartenant à un autre utilisateur.')
    journal = json.loads((session / 'journal.json').read_text())
    if journal['uid'] != os.getuid():
        raise Refused('Compte différent de celui du déploiement.')
    return session, journal


def current_shell(user):
    result = subprocess.run(['getent', 'passwd', user], check=True, capture_output=True, text=True)
    return result.stdout.strip().split(':')[-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('preview', 'deploy'):
        item = sub.add_parser(name)
        item.add_argument('--repo', required=True)
        item.add_argument('--home', required=True)
        item.add_argument('--mode', choices=('copy', 'stow'), default='copy')
        item.add_argument('--packages', required=True)
        item.add_argument('--fzf-source', default='')
        item.add_argument('--replace-commands', choices=('true', 'false'), default='false')
        item.add_argument('--use-theme', choices=('true', 'false'), default='true')
        if name == 'deploy':
            item.add_argument('--expected', required=True)
            item.add_argument('--state-root', required=True)
    restore = sub.add_parser('restore')
    restore.add_argument('session')
    mark = sub.add_parser('mark-shell')
    mark.add_argument('session')
    mark.add_argument('--user', required=True)
    mark.add_argument('--old', required=True)
    mark.add_argument('--new', required=True)
    args = parser.parse_args()
    if args.command in ('preview', 'deploy'):
        deploy(args)
    else:
        session, journal = load_session(args.session)
        if args.command == 'mark-shell':
            journal['shell'] = {'user': args.user, 'old': args.old, 'new': args.new}
            write_journal(session, journal)
            return
        if journal.get('status') == 'restored':
            info('Cette session a déjà été restaurée.')
            return
        info('Fichiers concernés :\n' + '\n'.join(entry['target'] for entry in journal['files'] if entry.get('started')))
        shell = journal.get('shell')
        if shell:
            found = current_shell(shell['user'])
            if found not in (shell['old'], shell['new']):
                raise Refused('Shell changé depuis cette installation ; restauration manuelle requise.')
            info('Ancien shell : ' + shell['old'])
        if input('Restaurer cette session ? Les fichiers modifiés ensuite seront refusés. [o/N] ') not in ('o', 'O', 'oui', 'OUI'):
            raise Refused('Restauration refusée.')
        restore_files(session, journal, finish=False)
        if shell and current_shell(shell['user']) != shell['old']:
            subprocess.run(['chsh', '-s', shell['old']], check=True)
        journal['status'] = 'restored'
        write_journal(session, journal)
        info('Fichiers restaurés. Les paquets, le cache tldr et les téléchargements ne sont pas désinstallés.')


if __name__ == '__main__':
    def interrupted(number, frame):
        raise Refused('Interruption reçue : ' + str(number))
    for number in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(number, interrupted)
    try:
        main()
    except (Refused, OSError, subprocess.SubprocessError, ValueError, EOFError, KeyboardInterrupt) as error:
        info('ERREUR : ' + str(error))
        sys.exit(1)
