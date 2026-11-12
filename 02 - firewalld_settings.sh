#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
DEFAULT_ZONE="home"
ALLOWED_SERVICES=(ssh samba)

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

Configure la zone par defaut et y autorise SSH et Samba.
Les autorisations sont immediates et permanentes lorsque firewalld est actif.
Les serveurs SSH et Samba ne sont ni installes ni demarres par ce script.

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
  [[ "$DEFAULT_ZONE" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] \
    || fatal "Nom de zone invalide: $DEFAULT_ZONE"
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
  local zones zone

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

  for zone in $zones; do
    [[ "$zone" == "$DEFAULT_ZONE" ]] && return 0
  done
  fatal "Zone firewalld introuvable: $DEFAULT_ZONE"
}

allow_services() {
  local service

  validate_zone
  if firewalld_is_running || [[ "$DRY_RUN" == true ]]; then
    for service in "${ALLOWED_SERVICES[@]}"; do
      log_info "Autorisation de $service dans la zone $DEFAULT_ZONE (permanente et immediate)"
      # Modifier explicitement les deux configurations sans rechargement global :
      # les autres regles temporaires sont ainsi conservees.
      run_privileged firewall-cmd --permanent --zone="$DEFAULT_ZONE" --add-service="$service"
      run_privileged firewall-cmd --zone="$DEFAULT_ZONE" --add-service="$service"
      if [[ "$DRY_RUN" != true ]]; then
        run_privileged firewall-cmd --permanent --zone="$DEFAULT_ZONE" --query-service="$service" \
          || fatal "Autorisation permanente de $service non confirmee"
        run_privileged firewall-cmd --zone="$DEFAULT_ZONE" --query-service="$service" \
          || fatal "Autorisation immediate de $service non confirmee"
      fi
    done
  else
    fatal "firewalld doit etre actif avant d'autoriser les services"
  fi
}

set_default_zone() {
  local current_zone

  validate_zone

  if firewalld_is_running || [[ "$DRY_RUN" == true ]]; then
    current_zone=''
    if firewalld_is_running; then
      current_zone="$(firewall-cmd --get-default-zone)"
    fi
    if [[ "$current_zone" == "$DEFAULT_ZONE" ]]; then
      log_info "La zone par defaut est deja: $DEFAULT_ZONE"
      return
    fi

    log_info "Definition de la zone par defaut firewalld: $DEFAULT_ZONE"
    run_privileged firewall-cmd --set-default-zone="$DEFAULT_ZONE"
    if [[ "$DRY_RUN" != true ]]; then log_info "Zone par defaut mise a jour"; fi
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
  else
    log_info "Installation de: ${missing_packages[*]}"
    run_privileged pacman -S --noconfirm --needed "${missing_packages[@]}"
  fi

  # Demarrer aussi firewalld lorsqu'il est deja installe mais arrete.
  run_privileged systemctl enable --now firewalld.service
  if [[ "$DRY_RUN" != true ]]; then
    firewalld_is_running || fatal "firewalld n'est pas actif apres son demarrage"
    log_info "firewalld activé et démarré"
  fi
}

main() {
  parse_args "$@"
  uninstall_ufw
  install_firewalld
  # Ouvrir les services avant de basculer la zone par defaut.
  allow_services
  set_default_zone
}

main "$@"
