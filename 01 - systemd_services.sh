#!/usr/bin/env bash

set -euo pipefail

# ─── Affichage ───────────────────────────────────────────────────────────────
GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
RED='' ERROR_RESET=''
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
  if [[ -t 1 ]]; then
    GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[1;36m' BOLD='\033[1m' RESET='\033[0m'
  fi
  if [[ -t 2 ]]; then
    RED='\033[1;31m' ERROR_RESET='\033[0m'
  fi
fi

info()   { printf '  %b%-12s%b %s\n' "$GREEN" 'OK' "$RESET" "$*"; }
warn()   { printf '  %b%-12s%b %s\n' "$YELLOW" 'Attention' "$RESET" "$*"; }
error()  { printf '  %b%-12s%b %s\n' "$RED" 'Erreur' "$ERROR_RESET" "$*" >&2; }
detail() { printf '  %b%-12s%b %s\n' "$BOLD" "$1" "$RESET" "$2"; }
dry()    { printf '  %b%-12s%b %s\n' "$CYAN" 'Simulation' "$RESET" "$*"; }
step()   { printf '\n%b── %s/3  %s%b\n' "$CYAN" "$1" "$2" "$RESET"; }

# ─── Dry-run et arguments ────────────────────────────────────────────────────
usage() {
  printf 'Usage : bash "%s" [--dry-run | --help]\n' "${0##*/}"
  printf '%s\n' 'Active et démarre Bluetooth, le serveur SSH, fstrim.timer et paccache.timer.' \
    '  --dry-run  Inspecte et décrit les actions sans modification.' \
    '  --help     Affiche cette aide.'
}
DRY_RUN=false
if (( $# > 1 )); then
  error 'Un seul argument au maximum est accepté.'
  usage >&2
  exit 2
fi
case "${1:-}" in
  '') if (( $# != 0 )); then error 'Argument vide interdit.'; exit 2; fi ;;
  --dry-run) DRY_RUN=true ;;
  --help|-h) usage; exit 0 ;;
  *) error "Option inconnue : $1"; usage >&2; exit 2 ;;
esac

# ─── Vérification root et environnement ──────────────────────────────────────
printf '%bCachyOS · Services systemd%b\n' "$BOLD" "$RESET"
if $DRY_RUN; then
  dry 'Mode dry-run : aucune modification ne sera appliquée.'
else
  detail 'Mode' 'Application des changements'
fi
step 1 'Vérifier les prérequis'
if [[ $EUID -ne 0 ]] && ! $DRY_RUN; then
  error 'Ce script doit être exécuté en tant que root (sudo).'
  exit 1
fi
for cmd in systemctl pacman; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "Commande requise introuvable : $cmd (CachyOS/Arch avec systemd requis)."
    exit 1
  fi
done
# Distinguer une panne du gestionnaire d'une unité absente.
if ! systemctl show --property=Version --value >/dev/null; then
  error 'Impossible de joindre le gestionnaire systemd système.'
  exit 1
fi
info 'systemctl et pacman disponibles, gestionnaire systemd joignable.'

# ─── Listes ──────────────────────────────────────────────────────────────────
SERVICES=(bluetooth.service sshd.service)
TIMERS=(fstrim.timer paccache.timer)
UNITS=("${SERVICES[@]}" "${TIMERS[@]}")
FAILURES=0
UNDO_FILE=''

# ─── Dépendances requises ────────────────────────────────────────────────────
# Vérifier le paquet et l'unité ; bluetoothctl (bluez-utils) n'est pas requis
# pour démarrer bluetooth.service, fourni par bluez.
check_deps() {
  local unit="$1" pkg cmd=''
  case "$unit" in
    bluetooth.service) pkg=bluez ;;
    sshd.service) pkg=openssh ;;
    fstrim.timer) pkg=util-linux; cmd=fstrim ;;
    paccache.timer) pkg=pacman-contrib; cmd=paccache ;;
    *) error "Unité sans dépendance déclarée : $unit"; return 1 ;;
  esac
  if ! pacman -Q "$pkg" >/dev/null 2>&1; then
    error "$unit — paquet requis absent : $pkg. Installez-le avant de relancer."
    return 1
  fi
  if [[ -n "$cmd" ]] && ! command -v "$cmd" >/dev/null 2>&1; then
    error "$unit — commande $cmd absente malgré le paquet $pkg ; vérifiez l'installation."
    return 1
  fi
}

# Propriétés nommées : aucun filtrage approximatif du nom de l'unité.
read_state() {
  local unit="$1" output key value
  LOAD_STATE=''; ENABLED_STATE=''; ACTIVE_STATE=''
  if ! output=$(systemctl show "$unit" --property=LoadState,UnitFileState,ActiveState); then
    error "$unit — échec de lecture de l'état systemd."
    return 1
  fi
  while IFS='=' read -r key value; do
    case "$key" in
      LoadState) LOAD_STATE="$value" ;;
      UnitFileState) ENABLED_STATE="$value" ;;
      ActiveState) ACTIVE_STATE="$value" ;;
    esac
  done <<< "$output"
  if [[ "$LOAD_STATE" != loaded ]]; then
    error "$unit — unité indisponible (LoadState=${LOAD_STATE:-inconnu})."
    return 1
  fi
  case "$ENABLED_STATE" in
    enabled|enabled-runtime|disabled) ;;
    *) error "$unit — activation ${ENABLED_STATE:-inconnue} ; intervention manuelle requise (aucun démasquage automatique)."; return 1 ;;
  esac
  case "$ACTIVE_STATE" in
    active|inactive|failed) ;;
    *) error "$unit — état ${ACTIVE_STATE:-inconnu} ; attendez un état stable et relancez."; return 1 ;;
  esac
}

# ─── Retour arrière ──────────────────────────────────────────────────────────
# Enregistrer AVANT chaque modification. Ce fichier n'est jamais exécuté ici.
# Il restaure l'activation et l'état démarré/arrêté, pas les effets des tâches
# déjà exécutées (TRIM ou nettoyage du cache), ni un ancien état « failed ».
record_undo() {
  local unit="$1" enabled="$2" active="$3" candidate
  if [[ -z "$UNDO_FILE" ]]; then
    candidate=$(mktemp /var/tmp/cachyos-systemd-undo.XXXXXXXX) || return 1
    chmod 600 "$candidate" || return 1
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
      '# À examiner puis lancer avec sudo bash ; ne pas utiliser après d’autres changements volontaires.' \
      '# Ne restaure ni le cache supprimé, ni les effets du TRIM, ni un état failed.' \
      '[[ $EUID -eq 0 ]] || { echo "Exécutez avec sudo bash." >&2; exit 1; }' > "$candidate" || return 1
    UNDO_FILE="$candidate"
    detail 'Sauvegarde' "Retour arrière enregistré dans : $UNDO_FILE"
  fi
  {
    printf '\n# %s : activation=%s, état=%s\n' "$unit" "$enabled" "$active" || return 1
    if [[ "$enabled" != enabled ]]; then
      printf 'systemctl disable %q\n' "$unit" || return 1
      if [[ "$enabled" == enabled-runtime ]]; then
        printf 'systemctl enable --runtime %q\n' "$unit" || return 1
      fi
    fi
    if [[ "$active" == active ]]; then
      printf 'systemctl start %q\n' "$unit" || return 1
    else
      printf 'systemctl stop %q\n' "$unit" || return 1
    fi
  } >> "$UNDO_FILE"
}

# ─── Fonction d'activation ───────────────────────────────────────────────────
enable_unit() {
  local unit="$1" initial_enabled initial_active
  check_deps "$unit" || return 1
  read_state "$unit" || return 1
  initial_enabled="$ENABLED_STATE"; initial_active="$ACTIVE_STATE"
  detail 'Avant' "activation=$initial_enabled, état=$initial_active"
  if [[ "$initial_enabled" == enabled && "$initial_active" == active ]]; then
    info "$unit — déjà activé durablement et actif, aucune action."
    return 0
  fi
  if $DRY_RUN; then
    if [[ "$initial_enabled" != enabled ]]; then
      dry "$unit — serait activé durablement et démarré."
    else
      dry "$unit — serait démarré (déjà activé durablement)."
    fi
    return 0
  fi
  if ! record_undo "$unit" "$initial_enabled" "$initial_active"; then
    error "$unit — impossible d'enregistrer le retour arrière ; aucune action sur cette unité."
    return 1
  fi
  if [[ "$initial_enabled" == enabled ]]; then
    detail 'Action' "Démarrer $unit."
    if ! systemctl start "$unit"; then
      error "$unit — échec du démarrage."
      return 1
    fi
  else
    detail 'Action' "Activer durablement et démarrer $unit."
    if ! systemctl enable --now "$unit"; then
      error "$unit — échec de l'activation/démarrage ; modification partielle possible."
      return 1
    fi
  fi
}

# ─── Activation des services et timers ────────────────────────────────────────
if $DRY_RUN; then
  step 2 'Inspecter les unités et présenter les actions prévues'
else
  step 2 'Inspecter et configurer les unités'
fi
warn 'Les timers peuvent déclencher leurs tâches dès leur démarrage selon leur configuration.'
for unit in "${UNITS[@]}"; do
  case "$unit" in
    bluetooth.service) description='Bluetooth' ;;
    sshd.service) description='Serveur SSH (OpenSSH)' ;;
    fstrim.timer) description='TRIM périodique des SSD' ;;
    paccache.timer) description='Nettoyage périodique du cache Pacman' ;;
    *) description='Unité systemd' ;;
  esac
  printf '\n%b%s%b · %s\n' "$BOLD" "$description" "$RESET" "$unit"
  if ! enable_unit "$unit"; then
    FAILURES=$((FAILURES + 1))
  fi
done

# ─── Résumé ──────────────────────────────────────────────────────────────────
if $DRY_RUN; then
  step 3 'Bilan de la simulation'
else
  step 3 'Vérifier le statut final'
  for unit in "${UNITS[@]}"; do
    if ! read_state "$unit"; then
      FAILURES=$((FAILURES + 1))
    elif [[ "$ENABLED_STATE" == enabled && "$ACTIVE_STATE" == active ]]; then
      info "$unit — activé durablement et actif."
    else
      error "$unit — objectif non atteint : activation=$ENABLED_STATE, état=$ACTIVE_STATE."
      FAILURES=$((FAILURES + 1))
    fi
  done
fi
if [[ -n "$UNDO_FILE" ]]; then
  printf '\n'
  detail 'Sauvegarde' "Examinez $UNDO_FILE avant tout retour arrière."
  detail 'Commande' "sudo bash $UNDO_FILE"
fi
if (( FAILURES > 0 )); then
  error 'Terminé avec des erreurs : consultez les détails ci-dessus. Les unités indépendantes ont été traitées.'
  exit 1
fi
if $DRY_RUN; then
  info 'Dry-run terminé — aucune modification effectuée.'
else
  info 'Terminé — toutes les unités sont activées durablement et actives.'
fi
