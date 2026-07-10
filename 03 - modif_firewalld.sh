#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
DEFAULT_ZONE="home"

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

Configure firewalld pour utiliser la zone home par defaut.

Options:
  -z, --zone ZONE     Zone a definir par defaut (defaut: ${DEFAULT_ZONE})
  --dry-run           Affiche les commandes sans les executer
  -h, --help          Affiche cette aide
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -z|--zone)
        shift
        [[ $# -gt 0 ]] || fatal "Option --zone: zone manquante"
        DEFAULT_ZONE="$1"
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
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    run "$@"
  else
    command -v sudo >/dev/null || fatal "sudo est introuvable"
    run sudo "$@"
  fi
}

firewalld_is_running() {
  command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1
}

validate_zone() {
  local zones

  if [[ "$DRY_RUN" == true ]]; then
    return
  fi

  if firewalld_is_running; then
    zones="$(firewall-cmd --get-zones)"
  elif command -v firewall-offline-cmd >/dev/null; then
    zones="$(firewall-offline-cmd --get-zones)"
  else
    fatal "firewalld est introuvable: installez le paquet firewalld"
  fi

  grep -qw -- "$DEFAULT_ZONE" <<< "$zones" || fatal "Zone firewalld introuvable: $DEFAULT_ZONE"
}

set_default_zone() {
  local current_zone

  validate_zone

  if firewalld_is_running; then
    current_zone="$(firewall-cmd --get-default-zone)"
    if [[ "$current_zone" == "$DEFAULT_ZONE" ]]; then
      log_info "La zone par defaut est deja: $DEFAULT_ZONE"
      return
    fi

    log_info "Definition de la zone par defaut firewalld: $DEFAULT_ZONE"
    run_privileged firewall-cmd --set-default-zone="$DEFAULT_ZONE"
    log_info "Zone par defaut mise a jour"
    return
  fi

  if command -v firewall-offline-cmd >/dev/null || [[ "$DRY_RUN" == true ]]; then
    log_warn "firewalld ne semble pas actif; modification de la configuration hors ligne"
    run_privileged firewall-offline-cmd --set-default-zone="$DEFAULT_ZONE"
    log_info "Zone par defaut mise a jour"
    return
  fi

  fatal "firewalld n'est pas actif et firewall-offline-cmd est introuvable"
}

uninstall_ufw() {
  if ! command -v ufw &>/dev/null; then
    log_info "ufw n'est pas installé, rien à désinstaller"
    return
  fi

  log_info "Désinstallation de ufw..."
  if firewalld_is_running; then
    log_warn "firewalld est déjà actif, désactivation de ufw..."
  fi

  if [[ "$DRY_RUN" == true ]]; then
    run_privileged ufw disable
    run_privileged pacman -Rns --noconfirm ufw
    return
  fi

  run_privileged ufw disable 2>/dev/null || true
  run_privileged systemctl disable --now ufw.service 2>/dev/null || true
  run_privileged pacman -Rns --noconfirm ufw && log_info "ufw désinstallé" || log_warn "Échec de la désinstallation de ufw"
}

install_firewalld() {
  local missing_packages=()

  if ! command -v firewall-cmd &>/dev/null; then
    missing_packages+=(firewalld)
  fi
  if ! command -v firewall-config &>/dev/null; then
    missing_packages+=(firewall-config)
  fi

  if [[ ${#missing_packages[@]} -eq 0 ]]; then
    log_info "firewalld et firewall-config sont déjà installés"
    return
  fi

  log_info "Installation de: ${missing_packages[*]}"
  run_privileged pacman -S --noconfirm --needed "${missing_packages[@]}"

  if [[ "$DRY_RUN" == true ]]; then
    run_privileged systemctl enable --now firewalld.service
    return
  fi

  run_privileged systemctl enable --now firewalld.service
  log_info "firewalld activé et démarré"
}

main() {
  parse_args "$@"
  uninstall_ufw
  install_firewalld
  set_default_zone
}

main "$@"
