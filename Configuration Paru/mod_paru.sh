#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
TARGET_FILE="/etc/paru.conf"
TEMP_FILE=""

log_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
log_error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; }

fatal() {
  log_error "$1"
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Active l'option BottomUp dans la configuration de paru.
Par defaut, le script modifie:
  ${TARGET_FILE}

Options:
  -t, --target FILE   Fichier paru.conf a modifier
  --dry-run           Affiche les actions sans les executer
  -h, --help          Affiche cette aide
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

run_privileged() {
  if [[ -w "$TARGET_FILE" ]]; then
    run "$@"
  else
    command -v sudo >/dev/null || fatal "sudo est introuvable"
    run sudo "$@"
  fi
}

build_updated_config() {
  local source_file="$1"
  local output_file="$2"

  if grep -Eq '^[[:space:]]*#[[:space:]]*BottomUp[[:space:]]*$' "$source_file"; then
    awk '
      /^[[:space:]]*#[[:space:]]*BottomUp[[:space:]]*$/ && !done {
        print "BottomUp"
        done = 1
        next
      }
      { print }
    ' "$source_file" > "$output_file"
    return
  fi

  awk '
    {
      print
      if (!inserted && $0 ~ /^[[:space:]]*\[options\][[:space:]]*$/) {
        print "BottomUp"
        inserted = 1
      }
    }
    END {
      if (!inserted) {
        print ""
        print "[options]"
        print "BottomUp"
      }
    }
  ' "$source_file" > "$output_file"
}

enable_bottomup() {
  local backup_file

  [[ -f "$TARGET_FILE" ]] || fatal "Fichier de configuration introuvable: $TARGET_FILE"

  if grep -Eq '^[[:space:]]*BottomUp[[:space:]]*$' "$TARGET_FILE"; then
    log_info "BottomUp est deja actif dans: $TARGET_FILE"
    return
  fi

  backup_file="${TARGET_FILE}.backup.$(date +%Y%m%d%H%M%S)"
  TEMP_FILE="$(mktemp)"
  trap 'rm -f "$TEMP_FILE"' EXIT

  log_warn "Sauvegarde de la configuration vers: $backup_file"
  run_privileged cp -p "$TARGET_FILE" "$backup_file"

  build_updated_config "$TARGET_FILE" "$TEMP_FILE"

  log_info "Activation de BottomUp dans: $TARGET_FILE"
  run_privileged cp "$TEMP_FILE" "$TARGET_FILE"
  log_info "Configuration paru mise a jour"
}

main() {
  parse_args "$@"
  enable_bottomup
}

main "$@"
