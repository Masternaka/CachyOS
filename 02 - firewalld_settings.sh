#!/usr/bin/env bash
# Gérer UFW ou firewalld, ou configurer les règles d'un firewalld déjà actif.
set -Eeuo pipefail
DRY_RUN=false
INTERACTIVE=false
DEFAULT_ZONE=home
ALLOWED_SERVICES=()
SERVICES_ARG=''
SESSION=''
ROLLBACK_READY=false
CONFIG_DIR=/etc/firewalld
UFW_DIR=/etc/ufw
REPORT=()

GREEN='' YELLOW='' CYAN='' BLUE='' STATE_RED='' VIOLET='' BOLD='' RESET='' RED='' ERROR_RESET=''
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
  if [[ -t 1 ]]; then
    GREEN='\033[1;32m' YELLOW='\033[1;33m' CYAN='\033[1;36m' BLUE='\033[1;94m'
    STATE_RED='\033[1;31m' VIOLET='\033[1;95m' BOLD='\033[1m' RESET='\033[0m'
  fi
  if [[ -t 2 ]]; then
    RED='\033[1;31m' ERROR_RESET='\033[0m'
  fi
fi

info()  { printf '  %b%-12s%b %s\n' "$BOLD" 'Info' "$RESET" "$*"; }
ok()    { printf '  %b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '  %b[Attention]%b %s\n' "$YELLOW" "$RESET" "$*"; }
error() { printf '  %b[Échec]%b %s\n' "$RED" "$ERROR_RESET" "$*" >&2; }
fatal() { error "$*"; exit 1; }
dry()   { printf '  %b[Simulation]%b %s\n' "$CYAN" "$RESET" "$*"; }
step()  { printf '\n%b── %s/4  %s%b\n' "$CYAN" "$1" "$2" "$RESET"; }

print_report() {
  local status="$1" entry
  step 4 'Rapport final'
  for entry in ${REPORT[@]+"${REPORT[@]}"}; do info "$entry"; done
  if [[ -n "$SESSION" ]]; then printf '  %b[Sauvegarde]%b %s\n' "$VIOLET" "$RESET" "$SESSION"; fi
  if (( status != 0 )); then
    error "Opération interrompue ou incomplète (code $status). Consultez les détails ci-dessus."
  elif $DRY_RUN; then
    dry 'Simulation terminée.'
  else
    ok 'Opération terminée.'
  fi
}

usage() {
  cat <<'HELP'
Usage : bash "02 - firewalld_settings.sh" [--interactive] [--dry-run]
        bash "02 - firewalld_settings.sh" --services ssh,samba|ssh|samba|none [options]
  --interactive  Détecte UFW et firewalld, puis propose une désactivation
                 et l’installation de Gufw ou Firewall Config.
  --zone ZONE    Zone par défaut à définir (home par défaut).
  --services LISTE  Configure les règles d’un firewalld déjà actif.
  --dry-run      Lire et présenter le plan sans écriture ni élévation.
  --help, -h     Afficher cette aide.

Sans --services, le menu s’ouvre dans un terminal. Avec --services,
les règles sont ajoutées aux configurations active et permanente,
sans rechargement global. La valeur none conserve les règles existantes.
Une confirmation précède chaque plan de modifications. L’installation
d’une interface graphique ne démarre aucun pare-feu via ce script.
HELP
}
ZONE_SET=false
while (( $# > 0 )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --interactive) INTERACTIVE=true; shift ;;
    --zone|-z|--services)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || fatal "Valeur manquante : $1"
      case "$1" in
        --zone|-z) DEFAULT_ZONE="$2"; ZONE_SET=true ;;
        --services) [[ -z "$SERVICES_ARG" ]] || fatal '--services répété.'; SERVICES_ARG="$2" ;;
      esac
      shift 2 ;;
    *) fatal "Option inconnue : $1" ;;
  esac
done
[[ "$DEFAULT_ZONE" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || fatal 'Nom de zone invalide.'
if [[ -z "$SERVICES_ARG" ]] && [[ -t 0 ]]; then INTERACTIVE=true; fi
if $INTERACTIVE; then
  [[ -z "$SERVICES_ARG" ]] && ! $ZONE_SET || fatal 'Le menu interactif s’utilise sans --services ni --zone.'
else
  [[ -n "$SERVICES_ARG" ]] || fatal 'Choisir --interactive ou --services ssh,samba, ssh, samba ou none.'
fi
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
has_property() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }

unit_value() {
  local key value
  while IFS='=' read -r key value; do
    if [[ "$key" == "$2" ]]; then printf '%s' "$value"; return; fi
  done <<< "$1"
  printf 'inconnu'
}

detect_firewalls() {
  local output
  FIREWALLD_UNIT=$(systemctl show firewalld.service --property=LoadState,ActiveState,UnitFileState) ||
    fatal 'Lecture de firewalld.service impossible.'
  UFW_UNIT=$(systemctl show ufw.service --property=LoadState,ActiveState,UnitFileState) ||
    fatal 'Lecture de ufw.service impossible.'
  UFW_RULES='commande absente'
  if command -v ufw >/dev/null; then
    UFW_RULES='indéterminé'
    if output=$(LC_ALL=C ufw status 2>/dev/null); then
      case "${output%%$'\n'*}" in
        'Status: active') UFW_RULES=actif ;;
        'Status: inactive') UFW_RULES=inactif ;;
      esac
    fi
  fi
}

state_badge() {
  local value="$1" color="$YELLOW"
  case "$value" in
    active|actif) color="$GREEN" ;;
    enabled) color="$BLUE" ;;
    failed|masked|masked-runtime) color="$STATE_RED" ;;
  esac
  printf '%b[%s]%b' "$color" "$value" "$RESET"
}

describe_firewalls() {
  local unit name state
  for name in firewalld ufw; do
    if [[ "$name" == firewalld ]]; then unit="$FIREWALLD_UNIT"; else unit="$UFW_UNIT"; fi
    if has_property "$unit" 'LoadState=not-found'; then
      state=$(state_badge 'unité absente')
    else
      state="service $(state_badge "$(unit_value "$unit" ActiveState)") · démarrage $(state_badge "$(unit_value "$unit" UnitFileState)")"
    fi
    if [[ "$name" == ufw ]]; then state="$state · règles UFW $(state_badge "$UFW_RULES")"; fi
    printf '%s\n' "$name — $state"
  done
}

select_disable_target() {
  local name="$1"
  if [[ "$name" == ufw ]]; then
    TARGET_STATE="$UFW_UNIT"
    [[ "$UFW_RULES" == actif || "$UFW_RULES" == inactif ]] ||
      fatal 'État des règles UFW indisponible. Vérifiez l’installation et utilisez un accès local avec les droits nécessaires.'
  else
    TARGET_STATE="$FIREWALLD_UNIT"
  fi
  TARGET_ACTIVE=$(unit_value "$TARGET_STATE" ActiveState)
  TARGET_BOOT=$(unit_value "$TARGET_STATE" UnitFileState)
  if [[ "$name" == ufw ]] && has_property "$TARGET_STATE" 'LoadState=not-found'; then
    TARGET_ACTIVE=inactive TARGET_BOOT=disabled
  else
    [[ "$name" == firewalld ]] && has_property "$TARGET_STATE" 'LoadState=not-found' &&
      fatal 'firewalld.service est absent.'
    case "$TARGET_ACTIVE" in active|inactive|failed) ;; *) fatal "État instable ou inconnu pour $name : $TARGET_ACTIVE." ;; esac
    case "$TARGET_BOOT" in
      enabled|enabled-runtime|disabled|masked|masked-runtime) ;;
      *) fatal "État de démarrage non pris en charge pour $name : $TARGET_BOOT." ;;
    esac
  fi
  if [[ "$name" == ufw && ! -f "$UFW_DIR/ufw.conf" ]]; then
    fatal "Configuration UFW introuvable : $UFW_DIR/ufw.conf."
  fi
}

preview_action() {
  local command
  printf -v command '%q ' "$@"
  if $DRY_RUN; then dry "${command% }"; else printf '  %b[Action]%b %s\n' "$CYAN" "$RESET" "${command% }"; fi
}

perform_action() {
  local command
  printf -v command '%q ' "$@"
  info "Exécution : ${command% }"
  if "$@"; then
    ok "Commande réussie : ${command% }"
    REPORT+=("Commande réussie : ${command% }")
  else
    REPORT+=("Échec : ${command% }. Une modification partielle est possible.")
    fatal "La commande a échoué : ${command% }"
  fi
}

disable_commands() {
  local action="$1" name="$2"
  if [[ "$TARGET_BOOT" == enabled ]]; then
    "$action" systemctl disable "$name.service"
  elif [[ "$TARGET_BOOT" == enabled-runtime ]]; then
    "$action" systemctl --runtime disable "$name.service"
  fi
  if [[ "$TARGET_ACTIVE" == active ]]; then
    "$action" systemctl stop "$name.service"
  fi
  if [[ "$name" == ufw ]]; then "$action" ufw disable; fi
}

backup_before_disable() {
  local name="$1" config="$CONFIG_DIR" undo
  if [[ "$name" == ufw ]]; then config="$UFW_DIR"; fi
  umask 077
  SESSION=$(mktemp -d /var/tmp/cachyos-firewall.XXXXXXXX)
  printf '%s\n' "$TARGET_STATE" > "$SESSION/etat-systemd.txt"
  if [[ -d "$config" ]]; then cp -a -- "$config" "$SESSION/configuration"; fi
  if [[ "$name" == ufw ]]; then
    if [[ -f /etc/default/ufw ]]; then cp -a -- /etc/default/ufw "$SESSION/ufw-default"; fi
    LC_ALL=C ufw status verbose > "$SESSION/etat-ufw.txt"
  elif [[ "$TARGET_ACTIVE" == active ]]; then
    firewall-cmd --list-all-zones > "$SESSION/zones-actives.txt"
  fi
  undo="$SESSION/restaurer.sh"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
      '# À examiner depuis un accès local avant toute autre modification du pare-feu.' \
      '# Les règles temporaires de firewalld peuvent nécessiter une restauration manuelle.' \
      '[[ $EUID -eq 0 ]] || { echo "sudo requis" >&2; exit 1; }'
    if [[ "$name" == ufw ]]; then
      if [[ "$UFW_RULES" == actif ]]; then printf '%s\n' 'ufw --force enable'; fi
      printf 'cp -a -- %q %q\n' "$SESSION/configuration/ufw.conf" "$UFW_DIR/ufw.conf"
    fi
    case "$TARGET_BOOT" in
      enabled) printf 'systemctl enable %q\n' "$name.service" ;;
      enabled-runtime) printf 'systemctl --runtime enable %q\n' "$name.service" ;;
    esac
    if [[ "$TARGET_ACTIVE" == active ]]; then printf 'systemctl start %q\n' "$name.service"; fi
  } > "$undo"
  REPORT+=("Retour arrière du pare-feu : examiner puis lancer sudo bash \"$undo\".")
  printf '  %b[Sauvegarde]%b %s\n' "$VIOLET" "$RESET" "$SESSION"
}

run_interactive() {
  local target='' gui='' answer output before before_target before_ufw after_target
  step 1 'Détecter les pare-feu'
  detect_firewalls
  before=$(describe_firewalls)
  while IFS= read -r answer; do info "$answer"; done <<< "$before"
  if [[ "$UFW_RULES" == indéterminé ]]; then
    warn 'Le statut des règles UFW peut nécessiter les droits root, même en simulation.'
  fi
  step 2 'Choisir la désactivation et l’interface graphique'
  printf '%s\n' '  0  Garder les deux états actuels' '  1  Désactiver UFW' '  2  Désactiver firewalld'
  printf '%bPare-feu à désactiver [0] :%b ' "$BOLD" "$RESET"
  IFS= read -r answer || fatal 'Choix du pare-feu non reçu.'
  case "$answer" in
    ''|0) ;;
    1) target=ufw ;;
    2) target=firewalld ;;
    *) fatal 'Choisissez 0, 1 ou 2 pour le pare-feu.' ;;
  esac
  printf '%s\n' '  0  Passer cette étape' '  1  Gufw (UFW)' '  2  Firewall Config (firewalld)'
  printf '%bInterface à installer [0] :%b ' "$BOLD" "$RESET"
  IFS= read -r answer || fatal 'Choix de l’interface non reçu.'
  case "$answer" in
    ''|0) ;;
    1) gui=gufw ;;
    2) gui=firewall-config ;;
    *) fatal 'Choisissez 0, 1 ou 2 pour l’interface.' ;;
  esac

  step 3 'Examiner le plan et appliquer les choix'
  if [[ -n "$gui" ]]; then
    command -v pacman >/dev/null || fatal 'Commande absente : pacman.'
    if pacman -Q "$gui" >/dev/null 2>&1; then
      REPORT+=("$gui est déjà installé.")
      printf '  %b[Déjà installé]%b %s\n' "$BLUE" "$RESET" "$gui"
      gui=''
    else
      pacman -Si "$gui" >/dev/null || fatal "Paquet introuvable dans les dépôts configurés : $gui."
      info 'Pacman peut télécharger l’interface et installer ses dépendances. Il affichera sa transaction.'
      preview_action pacman -S --needed -- "$gui"
    fi
  fi
  if [[ -n "$target" ]]; then
    select_disable_target "$target"
    before_target="$TARGET_STATE"
    before_ufw="$UFW_RULES"
    if [[ "$target" == firewalld && "$TARGET_ACTIVE" != active &&
          "$TARGET_BOOT" != enabled && "$TARGET_BOOT" != enabled-runtime ]]; then
      REPORT+=('firewalld est déjà arrêté et désactivé au démarrage.')
      target=''
    fi
  fi
  if [[ -n "$target" ]]; then
    if [[ "$target" == firewalld && "$TARGET_ACTIVE" == active ]]; then
      command -v firewall-cmd >/dev/null || fatal 'Commande absente : firewall-cmd.'
      warn 'L’arrêt de firewalld peut faire perdre ses règles temporaires.'
    fi
    if [[ "$target" == firewalld ]]; then
      warn 'Un autre service peut relancer firewalld à la demande après sa désactivation.'
      info 'Avec CleanupOnExit=no, les règles firewalld peuvent rester chargées après l’arrêt.'
    fi
    warn 'L’arrêt peut interrompre des connexions ou laisser la machine sans l’un de ces pare-feu actifs. Utilisez un accès local.'
    info "Sauvegarde de $target sous /var/tmp avant sa désactivation."
    disable_commands preview_action "$target"
  fi
  if [[ -z "$target" && -z "$gui" ]]; then
    REPORT+=('Aucune modification demandée.')
  elif $DRY_RUN; then
    REPORT+=('Actions prévues affichées à l’étape 3. Aucune modification appliquée.')
  else
    [[ $EUID -eq 0 ]] || fatal 'Application avec sudo requise ; examinez d’abord --interactive --dry-run.'
    printf '%bAutoriser les actions annoncées ? [o/N]%b ' "$BOLD" "$RESET"
    IFS= read -r answer || fatal 'Confirmation non reçue.'
    case "$answer" in
      o|O|oui|OUI) ;;
      *) REPORT+=('Annulé. Aucune modification appliquée.' "$before"); return 0 ;;
    esac
    detect_firewalls
    [[ "$(describe_firewalls)" == "$before" ]] || fatal 'État modifié depuis l’aperçu ; relancez le script.'
    if [[ -n "$gui" ]]; then
      perform_action pacman -S --needed -- "$gui"
      pacman -Q "$gui" >/dev/null || fatal "Installation de $gui non confirmée."
      ok "Interface installée et vérifiée : $gui"
      REPORT+=("Interface installée et vérifiée : $gui.")
    fi
    if [[ -n "$target" ]]; then
      detect_firewalls
      select_disable_target "$target"
      [[ "$TARGET_STATE" == "$before_target" ]] || fatal "État de $target modifié depuis l’aperçu."
      if [[ "$target" == ufw ]]; then
        [[ "$UFW_RULES" == "$before_ufw" ]] || fatal 'État des règles UFW modifié depuis l’aperçu.'
      fi
      backup_before_disable "$target"
      disable_commands perform_action "$target"
      detect_firewalls
      select_disable_target "$target"
      after_target="$TARGET_ACTIVE/$TARGET_BOOT"
      case "$after_target" in
        inactive/disabled|inactive/masked|inactive/masked-runtime|failed/disabled|failed/masked|failed/masked-runtime) ;;
        *) fatal "Désactivation de $target non confirmée : $after_target." ;;
      esac
      if [[ "$target" == ufw ]]; then
        [[ "$UFW_RULES" == inactif ]] || fatal 'Arrêt des règles UFW non confirmé.'
      fi
      REPORT+=("Désactivation vérifiée pour $target : service=$TARGET_ACTIVE, démarrage=$TARGET_BOOT.")
    else
      detect_firewalls
    fi
  fi
  REPORT+=('Dernier état observé des pare-feu')
  output=$(describe_firewalls)
  while IFS= read -r answer; do REPORT+=("$answer"); done <<< "$output"
}

trap 'print_report "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf '%bCachyOS · Pare-feu%b\n' "$BOLD" "$RESET"
if $DRY_RUN; then dry 'Aucune modification ne sera appliquée.'; fi
command -v systemctl >/dev/null || fatal 'Commande absente : systemctl.'
if $INTERACTIVE; then
  run_interactive
  exit 0
fi

step 1 'Vérifier les prérequis firewalld'
command -v firewall-cmd >/dev/null ||
  fatal 'Commande absente : firewall-cmd. Préparer les paquets avec 05 - package_install.sh --groups securite.'
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
step 2 'Présenter le plan firewalld'
info "Zone : $OLD_ZONE -> $DEFAULT_ZONE ; services à ajouter si absents : $SERVICES_ARG."
info 'Les ouvertures concernent toute la zone. Les affectations explicites des interfaces restent inchangées.'
info 'Les serveurs SSH et Samba ne sont ni installés ni démarrés.'
if $DRY_RUN; then
  step 3 'Simuler les changements'
  for service in ${MISSING_PERMANENT[@]+"${MISSING_PERMANENT[@]}"}; do preview_action firewall-cmd --permanent --zone="$DEFAULT_ZONE" --add-service="$service"; done
  for service in ${MISSING_RUNTIME[@]+"${MISSING_RUNTIME[@]}"}; do preview_action firewall-cmd --zone="$DEFAULT_ZONE" --add-service="$service"; done
  if [[ "$OLD_ZONE" != "$DEFAULT_ZONE" ]]; then preview_action firewall-cmd --set-default-zone="$DEFAULT_ZONE"; fi
  REPORT+=('Aucune modification appliquée.')
  exit 0
fi
[[ $EUID -eq 0 ]] || fatal 'Application avec sudo requise ; examiner d’abord --dry-run.'
if [[ "$OLD_ZONE" == "$DEFAULT_ZONE" && ${#MISSING_RUNTIME[@]} -eq 0 && ${#MISSING_PERMANENT[@]} -eq 0 ]]; then
  REPORT+=('Configuration déjà conforme.'); exit 0
fi
step 3 'Sauvegarder et appliquer les règles'
for cmd in mktemp chmod cp bash; do command -v "$cmd" >/dev/null || fatal "Commande absente : $cmd"; done
info 'Une modification de zone peut interrompre une connexion. Prévoir un accès local.'
info 'Sauvegarde sous /var/tmp ; retour arrière ciblé avant toute autre modification volontaire.'
printf 'Autoriser la sauvegarde puis les modifications annoncées ? [o/N] '
IFS= read -r answer || fatal 'Confirmation non reçue.'
case "$answer" in o|O|oui|OUI) ;; *) REPORT+=('Annulé. Aucune modification appliquée.'); exit 0 ;; esac
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
    if bash "$UNDO"; then
      REPORT+=('Retour arrière exécuté après l’échec.')
    else
      REPORT+=("Retour arrière incomplet. Examiner $UNDO depuis un accès local.")
    fi
  fi
  print_report "$status"
  exit "$status"
}
trap rollback_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ROLLBACK_READY=true
REPORT+=("Retour arrière : sudo bash \"$UNDO\"")
info "Sauvegarde : $SESSION ; retour arrière : sudo bash \"$UNDO\""
for service in ${MISSING_PERMANENT[@]+"${MISSING_PERMANENT[@]}"}; do
  perform_action firewall-cmd --permanent --zone="$DEFAULT_ZONE" --add-service="$service"
done
for service in ${MISSING_RUNTIME[@]+"${MISSING_RUNTIME[@]}"}; do
  perform_action firewall-cmd --zone="$DEFAULT_ZONE" --add-service="$service"
done
# Ouvrir les services avant de basculer la zone par défaut.
if [[ "$OLD_ZONE" != "$DEFAULT_ZONE" ]]; then perform_action firewall-cmd --set-default-zone="$DEFAULT_ZONE"; fi
read_plan
[[ "$OLD_ZONE" == "$DEFAULT_ZONE" && ${#MISSING_RUNTIME[@]} -eq 0 && ${#MISSING_PERMANENT[@]} -eq 0 ]] || fatal 'Configuration finale non confirmée.'
ROLLBACK_READY=false
REPORT+=("Zone $DEFAULT_ZONE et règles sélectionnées vérifiées. Accès SSH/Samba à valider sur le réseau.")
