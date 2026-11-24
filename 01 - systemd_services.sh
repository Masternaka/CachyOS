#!/usr/bin/env bash

set -euo pipefail

# Bilan commun ; conserver le dossier scripts/ à côté de ce fichier.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts/bilan.sh"
bilan_init "01 · Services systemd" "$@"

# ─── Affichage ───────────────────────────────────────────────────────────────
bilan_couleurs 1

info()   { printf '  %b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
warn()   { printf '  %b[Attention]%b %s\n' "$YELLOW" "$RESET" "$*"; }
error()  { bilan_erreur "$*"; printf '  %b[Échec]%b %s\n' "$RED" "$ERROR_RESET" "$*" >&2; }
detail() { printf '  %b%-12s%b %s\n' "$BOLD" "$1" "$RESET" "$2"; }
dry()    { printf '  %b[Simulation]%b %s\n' "$CYAN" "$RESET" "$*"; }
step()   { BILAN_ETAPE="$*"; printf '\n%b── %s/3  %s%b\n' "$CYAN" "$1" "$2" "$RESET"; }
backup() { printf '  %b[Sauvegarde]%b %s\n' "$VIOLET" "$RESET" "$*"; }

show_state() {
  local label="$1" boot="$2" active="$3" boot_color="$YELLOW" active_color="$YELLOW"
  if [[ "$boot" == enabled ]]; then boot_color="$BLUE"; fi
  case "$active" in
    active) active_color="$GREEN" ;;
    failed) active_color="$STATE_RED" ;;
  esac
  printf '  %s  Démarrage %b[%s]%b  ·  État %b[%s]%b\n' \
    "$label" "$boot_color" "$boot" "$RESET" "$active_color" "$active" "$RESET"
}

# ─── Dry-run et arguments ────────────────────────────────────────────────────
usage() {
  printf 'Usage : bash "%s" [--dry-run | --help]\n' "${0##*/}"
  printf '%s\n' 'Prépare Bluetooth, fstrim.timer, paccache.timer et SSH sur demande.' \
    'Lancer avec sudo bash pour examiner puis confirmer les changements.' \
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
  dry 'Aucun sudo nécessaire et aucune modification appliquée.'
else
  detail 'Privilèges' 'Lancer avec sudo bash pour modifier les services systemd.'
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
UNITS=(bluetooth.service fstrim.timer paccache.timer)
WITH_SSH=false
if ! $DRY_RUN || [[ -t 0 ]]; then
  warn 'Activer SSH peut rendre la machine accessible sur le réseau selon sa configuration et le pare-feu.'
  printf 'Inclure le serveur SSH dans le plan ? [o/N] '
  if ! IFS= read -r answer; then
    bilan_annule 'Saisie interrompue avant le plan.'
    exit 0
  fi
  case "$answer" in
    o|O|oui|OUI) WITH_SSH=true; UNITS+=(sshd.service) ;;
  esac
fi
if ! $WITH_SSH; then
  detail 'SSH' 'Conserver l’état et les réglages actuels.'
  bilan_ignore 'SSH : laissé tel quel.'
fi
FAILURES=0
UNDO_FILE=''
PLAN_UNITS=()
PLAN_ENABLED=()
PLAN_ACTIVE=()

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
    error "$unit — paquet requis absent : $pkg. Vérifiez sa disponibilité avec pacman -Si $pkg. Voir docs/systemd-services.md."
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
    backup "Retour arrière enregistré dans : $UNDO_FILE"
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

# ─── Plan et activation ──────────────────────────────────────────────────────
plan_unit() {
  local unit="$1"
  check_deps "$unit" || return 1
  read_state "$unit" || return 1
  show_state 'Avant' "$ENABLED_STATE" "$ACTIVE_STATE"
  if [[ "$ENABLED_STATE" == enabled && "$ACTIVE_STATE" == active ]]; then
    bilan_ignore "$unit : déjà actif et activé."
    info "$unit — déjà activé durablement et actif."
    return 0
  fi
  if [[ "$ENABLED_STATE" == enabled ]]; then
    detail 'Prévu' "$unit — serait démarré (déjà activé durablement)."
  else
    detail 'Prévu' "$unit — serait activé durablement et démarré."
  fi
  PLAN_UNITS+=("$unit")
  PLAN_ENABLED+=("$ENABLED_STATE")
  PLAN_ACTIVE+=("$ACTIVE_STATE")
}

enable_unit() {
  local unit="$1" initial_enabled="$2" initial_active="$3"
  check_deps "$unit" || return 1
  read_state "$unit" || return 1
  if [[ "$ENABLED_STATE" != "$initial_enabled" || "$ACTIVE_STATE" != "$initial_active" ]]; then
    error "$unit — état modifié depuis le plan, relancez le script."
    return 1
  fi
  if ! record_undo "$unit" "$initial_enabled" "$initial_active"; then
    error "$unit — impossible d'enregistrer le retour arrière ; aucune action sur cette unité."
    return 1
  fi
  bilan_debut
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

step 2 'Inspecter les unités et présenter le plan'
warn 'Les timers peuvent déclencher leurs tâches dès leur démarrage selon leur configuration.'
unit_number=0
for unit in "${UNITS[@]}"; do
  unit_number=$((unit_number + 1))
  case "$unit" in
    bluetooth.service) description='Bluetooth' ;;
    sshd.service) description='Serveur SSH (OpenSSH)' ;;
    fstrim.timer) description='TRIM périodique des SSD' ;;
    paccache.timer) description='Nettoyage périodique du cache Pacman' ;;
    *) description='Unité systemd' ;;
  esac
  printf '\n%b[%s/%s] %s%b · %s\n' "$BOLD" "$unit_number" "${#UNITS[@]}" "$description" "$RESET" "$unit"
  if ! plan_unit "$unit"; then
    FAILURES=$((FAILURES + 1))
  fi
done

if $DRY_RUN; then
  step 3 'Bilan de la simulation'
elif [[ -n ${PLAN_UNITS[0]:-} ]]; then
  if (( FAILURES > 0 )); then
    warn 'Le plan ne couvre que les unités dont les contrôles ont réussi.'
  fi
  printf 'Appliquer les actions annoncées ? [o/N] '
  if ! IFS= read -r answer; then answer=''; fi
  case "$answer" in
    o|O|oui|OUI) ;;
    *)
      bilan_annule 'Application refusée avant toute modification.'
      if (( FAILURES > 0 )); then exit 1; fi
      exit 0
      ;;
  esac

  step 3 'Appliquer et vérifier les unités du plan'
  for index in "${!PLAN_UNITS[@]}"; do
    unit="${PLAN_UNITS[index]}"
    if ! enable_unit "$unit" "${PLAN_ENABLED[index]}" "${PLAN_ACTIVE[index]}"; then
      FAILURES=$((FAILURES + 1))
      continue
    fi
    if ! read_state "$unit"; then
      FAILURES=$((FAILURES + 1))
      continue
    fi
    show_state "$unit" "$ENABLED_STATE" "$ACTIVE_STATE"
    if [[ "$ENABLED_STATE" != enabled || "$ACTIVE_STATE" != active ]]; then
      error "$unit — objectif non atteint : activation=$ENABLED_STATE, état=$ACTIVE_STATE."
      FAILURES=$((FAILURES + 1))
    else
      bilan_action "$unit : actif et activé, état final vérifié."
    fi
  done
elif (( FAILURES == 0 )); then
  bilan_conforme
fi
if ! $DRY_RUN && $WITH_SSH; then
  bilan_note 'Vérifier l’accès SSH depuis un autre poste.'
fi
(( FAILURES == 0 ))
