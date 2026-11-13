#!/usr/bin/env bash
# Configurer un firewalld déjà actif ; installation et migration restent séparées.
set -Eeuo pipefail
DRY_RUN=false
DEFAULT_ZONE=home
ALLOWED_SERVICES=()
SERVICES_ARG=''
SESSION=''
ROLLBACK_READY=false
CONFIG_DIR=/etc/firewalld

info() { printf '[INFO] %s\n' "$*"; }
fatal() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage : bash "02 - firewalld_settings.sh" --services ssh,samba|ssh|samba|none [options]
  --zone ZONE    Zone par défaut à définir (home par défaut).
  --services LISTE Services à ajouter, sélection explicite obligatoire.
  --dry-run      Lire et présenter le plan sans écriture ni élévation.
  --help, -h     Afficher cette aide.

Firewalld doit être installé et actif. Aucune installation, désinstallation,
activation de service ni migration UFW automatique. Les règles sont ajoutées
aux configurations active et permanente, sans rechargement global. Les règles
existantes non sélectionnées sont conservées ; none n'en ajoute aucune.
Une confirmation précède la sauvegarde privée et les modifications.
HELP
}
while (( $# > 0 )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --zone|-z|--services)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || fatal "Valeur manquante : $1"
      case "$1" in
        --zone|-z) DEFAULT_ZONE="$2" ;;
        --services) [[ -z "$SERVICES_ARG" ]] || fatal '--services répété.'; SERVICES_ARG="$2" ;;
      esac
      shift 2 ;;
    *) fatal "Option inconnue : $1" ;;
  esac
done
[[ "$DEFAULT_ZONE" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || fatal 'Nom de zone invalide.'
[[ -n "$SERVICES_ARG" ]] || fatal 'Choisir --services ssh,samba, ssh, samba ou none.'
if [[ "$SERVICES_ARG" != none ]]; then
  [[ "$SERVICES_ARG" != ,* && "$SERVICES_ARG" != *, && "$SERVICES_ARG" != *,,* ]] || fatal 'Liste de services mal formée.'
  IFS=, read -r -a ALLOWED_SERVICES <<< "$SERVICES_ARG"
  seen=' '
  for service in ${ALLOWED_SERVICES[@]+"${ALLOWED_SERVICES[@]}"}; do
    [[ "$service" == ssh || "$service" == samba ]] || fatal "Service non pris en charge : $service"
    [[ "$seen" != *" $service "* ]] || fatal "Service dupliqué : $service"
    seen+="$service "
  done
fi
for cmd in systemctl firewall-cmd; do
  command -v "$cmd" >/dev/null || fatal "Commande absente : $cmd. Préparer les paquets avec 08 - package_install.sh --groups securite."
done
has_property() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }
read_units() {
  local fw ufw
  fw=$(systemctl show firewalld.service --property=LoadState,ActiveState) || fatal 'Lecture de firewalld impossible.'
  has_property "$fw" 'LoadState=loaded' && has_property "$fw" 'ActiveState=active' || fatal 'Firewalld doit déjà être actif. Son démarrage ou une migration réseau demande une action distincte.'
  ufw=$(systemctl show ufw.service --property=LoadState,ActiveState,UnitFileState) || fatal 'Lecture de UFW impossible.'
  if ! has_property "$ufw" 'LoadState=not-found'; then
    has_property "$ufw" 'ActiveState=inactive' && { has_property "$ufw" 'UnitFileState=disabled' || has_property "$ufw" 'UnitFileState=masked'; } \
      || fatal 'UFW actif, activé ou dans un état non pris en charge : migration distincte requise. Aucun arrêt ni retrait automatique.'
  fi
  UNIT_STATE="$fw|$ufw"
}
# -query-service : 0 = présent, 1 = absent ; les autres codes sont des erreurs.
query_service() {
  local status=0
  firewall-cmd "$@" >/dev/null || status=$?
  case "$status" in 0|1) printf '%s' "$status" ;; *) fatal "Lecture des règles impossible (code $status)." ;; esac
}
read_plan() {
  local zones service scope exists state
  read_units
  firewall-cmd --state >/dev/null || fatal 'Firewalld ne répond pas correctement.'
  zones=$(firewall-cmd --get-zones) || fatal 'Lecture des zones impossible.'
  zones=${zones//$'\n'/ }
  [[ " $zones " == *" $DEFAULT_ZONE "* ]] || fatal "Zone inexistante : $DEFAULT_ZONE"
  OLD_ZONE=$(firewall-cmd --get-default-zone) || fatal 'Lecture de la zone par défaut impossible.'
  [[ "$OLD_ZONE" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || fatal 'Zone initiale invalide.'
  PLAN="$UNIT_STATE|$OLD_ZONE|$DEFAULT_ZONE"
  MISSING_RUNTIME=(); MISSING_PERMANENT=()
  for service in ${ALLOWED_SERVICES[@]+"${ALLOWED_SERVICES[@]}"}; do
    state=$(query_service --zone="$DEFAULT_ZONE" --query-service="$service") || exit 1
    PLAN+="|$service:runtime:$state"
    if [[ "$state" == 1 ]]; then MISSING_RUNTIME+=("$service"); fi
    state=$(query_service --permanent --zone="$DEFAULT_ZONE" --query-service="$service") || exit 1
    PLAN+="|$service:permanent:$state"
    if [[ "$state" == 1 ]]; then MISSING_PERMANENT+=("$service"); fi
  done
}
read_plan
info "Zone : $OLD_ZONE -> $DEFAULT_ZONE ; services à ajouter si absents : $SERVICES_ARG."
info 'Les ouvertures concernent toute la zone. Les affectations explicites des interfaces restent inchangées.'
info 'Les serveurs SSH et Samba ne sont ni installés ni démarrés.'
if $DRY_RUN; then
  for service in ${MISSING_PERMANENT[@]+"${MISSING_PERMANENT[@]}"}; do printf '[DRY-RUN] firewall-cmd --permanent --zone=%s --add-service=%s\n' "$DEFAULT_ZONE" "$service"; done
  for service in ${MISSING_RUNTIME[@]+"${MISSING_RUNTIME[@]}"}; do printf '[DRY-RUN] firewall-cmd --zone=%s --add-service=%s\n' "$DEFAULT_ZONE" "$service"; done
  if [[ "$OLD_ZONE" != "$DEFAULT_ZONE" ]]; then printf '[DRY-RUN] firewall-cmd --set-default-zone=%s\n' "$DEFAULT_ZONE"; fi
  info 'Aucune écriture ; disponibilité et droits à revalider lors de l’application.'
  exit 0
fi
[[ $EUID -eq 0 ]] || fatal 'Application avec sudo requise ; examiner d’abord --dry-run.'
if [[ "$OLD_ZONE" == "$DEFAULT_ZONE" && ${#MISSING_RUNTIME[@]} -eq 0 && ${#MISSING_PERMANENT[@]} -eq 0 ]]; then
  info 'Configuration déjà conforme ; aucune modification.'; exit 0
fi
for cmd in mktemp chmod cp bash; do command -v "$cmd" >/dev/null || fatal "Commande absente : $cmd"; done
info 'Une modification de zone peut interrompre une connexion. Prévoir un accès local.'
info 'Sauvegarde sous /var/tmp ; retour arrière ciblé avant toute autre modification volontaire.'
printf 'Autoriser la sauvegarde puis les modifications annoncées ? [o/N] '
IFS= read -r answer || fatal 'Confirmation non reçue.'
case "$answer" in o|O|oui|OUI) ;; *) info 'Annulé sans modification.'; exit 0 ;; esac
APPROVED_PLAN="$PLAN"
read_plan
[[ "$PLAN" == "$APPROVED_PLAN" ]] || fatal 'État modifié depuis l’aperçu ; relancer.'
umask 077
SESSION=$(mktemp -d /var/tmp/cachyos-firewall.XXXXXXXX)
chmod 700 "$SESSION"
# Copie de référence et inventaires : le retour arrière automatique reste ciblé,
# sans reload qui effacerait les autres règles temporaires.
if [[ -e "$CONFIG_DIR" ]]; then cp -a -- "$CONFIG_DIR" "$SESSION/configuration"; fi
firewall-cmd --list-all-zones > "$SESSION/zones-actives.txt"
firewall-cmd --permanent --list-all-zones > "$SESSION/zones-permanentes.txt"
UNDO="$SESSION/restaurer.sh"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' \
    '# À utiliser avant toute autre modification volontaire du pare-feu.' \
    '[[ $EUID -eq 0 ]] || { echo "sudo requis" >&2; exit 1; }' \
    'status=0'
  if [[ "$OLD_ZONE" != "$DEFAULT_ZONE" ]]; then
    printf 'firewall-cmd --set-default-zone=%q || status=1\n' "$OLD_ZONE"
  fi
  for service in ${MISSING_RUNTIME[@]+"${MISSING_RUNTIME[@]}"}; do
    printf 'firewall-cmd --zone=%q --remove-service=%q || status=1\n' "$DEFAULT_ZONE" "$service"
  done
  for service in ${MISSING_PERMANENT[@]+"${MISSING_PERMANENT[@]}"}; do
    printf 'firewall-cmd --permanent --zone=%q --remove-service=%q || status=1\n' "$DEFAULT_ZONE" "$service"
  done
  printf '%s\n' 'exit "$status"'
} > "$UNDO"
rollback_on_exit() {
  local status=$?
  trap - EXIT INT TERM
  if (( status != 0 )) && $ROLLBACK_READY; then
    info "Échec : tentative de retour arrière ; sauvegarde conservée : $SESSION"
    if ! bash "$UNDO"; then printf 'Retour arrière incomplet ; examiner %s depuis un accès local.\n' "$UNDO" >&2; fi
  fi
  exit "$status"
}
trap rollback_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ROLLBACK_READY=true
info "Sauvegarde : $SESSION ; retour arrière : sudo bash \"$UNDO\""
for service in ${MISSING_PERMANENT[@]+"${MISSING_PERMANENT[@]}"}; do
  firewall-cmd --permanent --zone="$DEFAULT_ZONE" --add-service="$service"
done
for service in ${MISSING_RUNTIME[@]+"${MISSING_RUNTIME[@]}"}; do
  firewall-cmd --zone="$DEFAULT_ZONE" --add-service="$service"
done
# Ouvrir les services avant de basculer la zone par défaut.
if [[ "$OLD_ZONE" != "$DEFAULT_ZONE" ]]; then firewall-cmd --set-default-zone="$DEFAULT_ZONE"; fi
read_plan
[[ "$OLD_ZONE" == "$DEFAULT_ZONE" && ${#MISSING_RUNTIME[@]} -eq 0 && ${#MISSING_PERMANENT[@]} -eq 0 ]] || fatal 'Configuration finale non confirmée.'
ROLLBACK_READY=false
info 'Règles et zone vérifiées ; accès SSH/Samba réels à valider séparément.'
