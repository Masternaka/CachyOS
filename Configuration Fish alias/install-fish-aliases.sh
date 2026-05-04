#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
SOURCE_FILE=""
TARGET_FILE="${HOME}/.config/fish/conf.d/personal_aliases.fish"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
log_error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; }

fatal() {
  log_error "$1"
  exit 1
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Installe les alias fish depuis un fichier separe.
Par defaut, le script charge aliases.fish dans ce dossier et l'installe dans:
  ${TARGET_FILE}

Options:
  -c, --config FILE   Fichier d'alias fish a installer
  -t, --target FILE   Destination a ecrire
  --dry-run           Affiche les actions sans les executer
  -h, --help          Affiche cette aide
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)
        shift
        [[ $# -gt 0 ]] || fatal "Option --config: fichier manquant"
        SOURCE_FILE="$1"
        ;;
      -t|--target)
        shift
        [[ $# -gt 0 ]] || fatal "Option --target: fichier manquant"
        TARGET_FILE="$1"
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        fatal "Option inconnue: $1"
        ;;
      *)
        fatal "Argument inattendu: $1"
        ;;
    esac
    shift
  done
}

validate_aliases() {
  local file="$1"

  [[ -f "$file" ]] || fatal "Fichier d'alias introuvable: $file"

  if command -v fish >/dev/null; then
    fish -n "$file" || fatal "Le fichier d'alias contient une erreur de syntaxe fish"
  else
    log_warn "fish est introuvable: validation de syntaxe ignoree"
  fi
}

install_aliases() {
  local source_file="$1"
  local target_dir
  local backup_file

  target_dir="$(dirname -- "$TARGET_FILE")"

  log_info "Installation des alias fish"
  run mkdir -p "$target_dir"

  if [[ -f "$TARGET_FILE" ]] && ! cmp -s "$source_file" "$TARGET_FILE"; then
    backup_file="${TARGET_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Un fichier d'alias existe deja; sauvegarde vers: $backup_file"
    run cp "$TARGET_FILE" "$backup_file"
  fi

  run cp "$source_file" "$TARGET_FILE"
  log_info "Alias installes dans: $TARGET_FILE"
}

main() {
  local source_file

  parse_args "$@"
  source_file="${SOURCE_FILE:-$SCRIPT_DIR/aliases.fish}"

  validate_aliases "$source_file"
  install_aliases "$source_file"
}

main "$@"
