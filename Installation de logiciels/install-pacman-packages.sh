#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
UPDATE_SYSTEM=true
CONFIG_FILE=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_PACKAGES=()

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
Usage: $(basename "$0") [options] [paquet...]

Installe des paquets depuis les depots officiels avec pacman.
Sans paquet en argument, le script charge liste des paquets/pacman-packages.conf.

Options:
  -c, --config FILE   Fichier de configuration a charger
  --dry-run           Affiche les commandes sans les executer
  --no-update         Ne lance pas pacman -Syu avant l'installation
  -h, --help          Affiche cette aide
EOF
}

load_config() {
  local file="${CONFIG_FILE:-$SCRIPT_DIR/liste des paquets/pacman-packages.conf}"

  [[ -f "$file" ]] || fatal "Fichier de configuration introuvable: $file"
  # shellcheck source=/dev/null
  source "$file"
}

check_prereqs() {
  command -v pacman >/dev/null || fatal "pacman est introuvable"
  command -v sudo >/dev/null || fatal "sudo est introuvable"

  if [[ "$DRY_RUN" == false ]]; then
    sudo -v || fatal "Impossible d'obtenir les droits sudo"
  fi
}

main() {
  local packages=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)
        shift
        [[ $# -gt 0 ]] || fatal "Option --config: fichier manquant"
        CONFIG_FILE="$1"
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      --no-update)
        UPDATE_SYSTEM=false
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        packages+=("$@")
        break
        ;;
      -*)
        fatal "Option inconnue: $1"
        ;;
      *)
        packages+=("$1")
        ;;
    esac
    shift
  done

  check_prereqs

  if [[ ${#packages[@]} -eq 0 ]]; then
    load_config
    packages=("${PACMAN_PACKAGES[@]}")
  fi

  [[ ${#packages[@]} -gt 0 ]] || fatal "Aucun paquet pacman a installer"

  if [[ "$UPDATE_SYSTEM" == true ]]; then
    log_info "Mise a jour du systeme"
    run sudo pacman -Syu --noconfirm
  fi

  log_info "Installation des paquets pacman"
  run sudo pacman -S --needed --noconfirm "${packages[@]}"
}

main "$@"
