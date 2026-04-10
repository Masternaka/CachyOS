#!/usr/bin/env bash

set -Eeuo pipefail

#######################################
# CONFIGURATION
#######################################

# Options par défaut
DRY_RUN=false
INSTALL_AUR=true
LOAD_PACMAN_CONFIG=true
LOAD_AUR_CONFIG=true

# Fichiers de configuration par défaut
PACMAN_CONFIG_FILE="${PACMAN_CONFIG_FILE:-pacman-packages.conf}"
AUR_CONFIG_FILE="${AUR_CONFIG_FILE:-aur-packages.conf}"

# Charger la configuration des paquets PACMAN si activé
if [[ "$LOAD_PACMAN_CONFIG" == true ]]; then
  if [[ -f "$PACMAN_CONFIG_FILE" ]]; then
    log_info "Chargement des paquets PACMAN depuis $PACMAN_CONFIG_FILE..."
    source "$PACMAN_CONFIG_FILE"
  else
    fatal "Fichier de configuration PACMAN $PACMAN_CONFIG_FILE introuvable"
  fi
else
  log_warn "Chargement de la configuration PACMAN désactivé"
  PACMAN_PACKAGES=()
fi

# Charger la configuration des paquets AUR si activé
if [[ "$LOAD_AUR_CONFIG" == true ]]; then
  if [[ -f "$AUR_CONFIG_FILE" ]]; then
    log_info "Chargement des paquets AUR depuis $AUR_CONFIG_FILE..."
    source "$AUR_CONFIG_FILE"
  else
    log_warn "Fichier de configuration AUR $AUR_CONFIG_FILE introuvable, aucun paquet AUR ne sera installé"
    AUR_PACKAGES=()
  fi
else
  log_warn "Chargement de la configuration AUR désactivé"
  AUR_PACKAGES=()
fi

#######################################
# UTILITAIRES
#######################################

log_info()  { echo -e "\e[34m[INFO]\e[0m $*"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

fatal() {
  log_error "$1"
  exit 1
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

#######################################
# GESTION ERREURS
#######################################

trap 'fatal "Erreur à la ligne $LINENO"' ERR

#######################################
# ARGUMENTS
#######################################

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --dry-run        Affiche les commandes sans les exécuter
  --no-aur         Ne pas installer les paquets AUR
  --no-pacman-config      Ne pas charger le fichier de configuration PACMAN
  --no-aur-config         Ne pas charger le fichier de configuration AUR
  --pacman-config FILE    Fichier de configuration des paquets PACMAN
  --aur-config FILE       Fichier de configuration des paquets AUR
  -h, --help       Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --no-aur) INSTALL_AUR=false ;;
    --no-pacman-config) LOAD_PACMAN_CONFIG=false ;;
    --no-aur-config) LOAD_AUR_CONFIG=false ;;
    --pacman-config) 
      shift
      PACMAN_CONFIG_FILE="$1"
      if [[ ! -f "$PACMAN_CONFIG_FILE" ]]; then
        fatal "Fichier de configuration PACMAN $PACMAN_CONFIG_FILE introuvable"
      fi
      ;;
    --aur-config) 
      shift
      AUR_CONFIG_FILE="$1"
      if [[ ! -f "$AUR_CONFIG_FILE" ]]; then
        fatal "Fichier de configuration AUR $AUR_CONFIG_FILE introuvable"
      fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) fatal "Option inconnue: $1" ;;
  esac
  shift
done

# Recharger la configuration si des fichiers personnalisés ont été spécifiés
if [[ "$LOAD_PACMAN_CONFIG" == true ]]; then
  if [[ -f "$PACMAN_CONFIG_FILE" ]]; then
    log_info "Chargement des paquets PACMAN depuis $PACMAN_CONFIG_FILE..."
    source "$PACMAN_CONFIG_FILE"
  else
    fatal "Fichier de configuration PACMAN $PACMAN_CONFIG_FILE introuvable"
  fi
fi

if [[ "$LOAD_AUR_CONFIG" == true ]]; then
  if [[ -f "$AUR_CONFIG_FILE" ]]; then
    log_info "Chargement des paquets AUR depuis $AUR_CONFIG_FILE..."
    source "$AUR_CONFIG_FILE"
  else
    log_warn "Fichier de configuration AUR $AUR_CONFIG_FILE introuvable, aucun paquet AUR ne sera installé"
    AUR_PACKAGES=()
  fi
fi

#######################################
# PRÉREQUIS
#######################################

check_prereqs() {
  log_info "Vérification des prérequis..."

  command -v pacman >/dev/null || fatal "pacman introuvable"
  command -v sudo >/dev/null || fatal "sudo introuvable"

  if [[ "$DRY_RUN" == false ]]; then
    sudo -v || fatal "Impossible d’obtenir les droits sudo"
  fi
}

#######################################
# PACMAN
#######################################

install_pacman() {
  log_info "Mise à jour du système (pacman)..."
  run sudo pacman -Syu --noconfirm

  log_info "Installation des paquets officiels..."
  run sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

#######################################
# YAY / AUR
#######################################

install_yay() {
  if command -v yay >/dev/null; then
    log_info "yay est déjà installé"
    return
  fi

  log_info "Installation de yay..."
  run sudo pacman -S --needed --noconfirm git base-devel
  run git clone https://aur.archlinux.org/yay.git /tmp/yay
  run bash -c "cd /tmp/yay && makepkg -si --noconfirm"
}

install_aur() {
  [[ "$INSTALL_AUR" == false ]] && {
    log_warn "Installation AUR désactivée"
    return
  }

  install_yay

  log_info "Installation des paquets AUR..."
  run yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

#######################################
# MAIN
#######################################

main() {
  check_prereqs
  install_pacman
  install_aur

  log_info "Installation terminée avec succès ✅"
}

main