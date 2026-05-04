#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
CONFIG_FILE=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AUR_PACKAGES=()

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
Usage: $(basename "$0") [options] [paquet-aur...]

Installe yay si necessaire, puis installe des paquets AUR.
Sans paquet en argument, le script charge liste des paquets/aur-packages.conf.

Options:
  -c, --config FILE   Fichier de configuration a charger
  --dry-run           Affiche les commandes sans les executer
  -h, --help          Affiche cette aide
EOF
}

load_config() {
  local file="${CONFIG_FILE:-$SCRIPT_DIR/liste des paquets/aur-packages.conf}"

  [[ -f "$file" ]] || fatal "Fichier de configuration introuvable: $file"
  # shellcheck source=/dev/null
  source "$file"
}

check_prereqs() {
  [[ ${EUID:-$(id -u)} -ne 0 ]] || fatal "Ne lancez pas ce script en root: makepkg refuse de compiler en root"
  command -v pacman >/dev/null || fatal "pacman est introuvable"
  command -v sudo >/dev/null || fatal "sudo est introuvable"
  command -v git >/dev/null || log_warn "git sera installe avec les prerequis de yay"

  if [[ "$DRY_RUN" == false ]]; then
    sudo -v || fatal "Impossible d'obtenir les droits sudo"
  fi
}

install_yay() {
  local build_dir

  if command -v yay >/dev/null; then
    log_info "yay est deja installe"
    return
  fi

  log_info "Installation des prerequis pour yay"
  run sudo pacman -S --needed --noconfirm git base-devel

  build_dir="$(mktemp -d)"
  trap 'rm -rf "$build_dir"' EXIT

  log_info "Compilation et installation de yay depuis l'AUR"
  run git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  run bash -c "cd \"\$1\" && makepkg -si --noconfirm" bash "$build_dir/yay"
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
  install_yay

  if [[ ${#packages[@]} -eq 0 ]]; then
    load_config
    packages=("${AUR_PACKAGES[@]}")
  fi

  [[ ${#packages[@]} -gt 0 ]] || fatal "Aucun paquet AUR a installer"

  log_info "Installation des paquets AUR"
  run yay -S --needed --noconfirm "${packages[@]}"
}

main "$@"
