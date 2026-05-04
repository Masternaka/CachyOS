#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
CONFIG_FILE=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FLATPAK_PACKAGES=()
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

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
Usage: $(basename "$0") [options] [app-id...]

Installe le support Flatpak si necessaire, active Flathub, puis installe
des applications Flatpak depuis Flathub.
Sans app-id en argument, le script charge liste des paquets/flatpak-packages.conf.

Options:
  -c, --config FILE   Fichier de configuration a charger
  --dry-run           Affiche les commandes sans les executer
  -h, --help          Affiche cette aide
EOF
}

load_config() {
  local file="${CONFIG_FILE:-$SCRIPT_DIR/liste des paquets/flatpak-packages.conf}"

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

install_flatpak_support() {
  if command -v flatpak >/dev/null; then
    log_info "flatpak est deja installe"
  else
    log_info "Installation du support Flatpak"
    run sudo pacman -S --needed --noconfirm flatpak
  fi
}

enable_flathub() {
  if command -v flatpak >/dev/null && flatpak remotes --columns=name | grep -qx flathub; then
    log_info "Flathub est deja active"
    return
  fi

  log_info "Activation du depot Flathub"
  run flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"
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
  install_flatpak_support
  enable_flathub

  if [[ ${#packages[@]} -eq 0 ]]; then
    load_config
    packages=("${FLATPAK_PACKAGES[@]}")
  fi

  [[ ${#packages[@]} -gt 0 ]] || fatal "Aucun Flatpak a installer"

  log_info "Installation des Flatpak depuis Flathub"
  run flatpak install -y flathub "${packages[@]}"
}

main "$@"
