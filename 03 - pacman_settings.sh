#!/usr/bin/env bash

set -Eeuo pipefail

PACMAN_CONF="/etc/pacman.conf"
BACKUP_DIR="/etc/pacman.conf.backups"
LOG_FILE="${ARCH_CUSTOM_LOGFILE:-/var/log/pacman_parallel_downloads.log}"
MODE=''
VALUE=''
RESTORE_FILE=''
SILENT_MODE=false
DRY_RUN=false
SNAPSHOT=''
CANDIDATE=''
BACKUP_FILE=''
LATEST_CANDIDATE=''
COMMIT_PENDING=false

# Fonction d'affichage d'aide
show_help() {
    cat <<'HELP'
Usage : bash "03 - pacman_settings.sh" [OPTIONS]

  --restore [FICHIER]  Restaure une sauvegarde précise, sinon la plus récente
  --auto               Estime une valeur selon le CPU et la RAM (pas le réseau)
  --silent             Supprime les messages ordinaires, jamais les erreurs
  --value N            Définit la valeur décimale N (0-20)
  --dry-run            Affiche le résultat prévu sans aucune écriture
  --help, -h           Affiche cette aide

Les modes --restore, --auto et --value sont exclusifs.
Sans mode explicite, une saisie interactive est nécessaire.
0 désactive la directive locale ; la valeur effective attendue est 1.

Exemples :
  sudo bash "03 - pacman_settings.sh"                    # Mode interactif
  bash "03 - pacman_settings.sh" --dry-run --auto         # Simulation
  sudo bash "03 - pacman_settings.sh" --auto             # Estimation matérielle
  sudo bash "03 - pacman_settings.sh" --value 5           # Définir à 5
  sudo bash "03 - pacman_settings.sh" --silent --value 3  # Sans interaction
  sudo bash "03 - pacman_settings.sh" --restore           # Dernière sauvegarde
HELP
}

# L'affichage va sur stderr pour réserver stdout à l'aperçu de pacman.conf.
GREEN='' YELLOW='' RED='' CYAN='' BOLD='' RESET=''
if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    GREEN='\033[32m' YELLOW='\033[33m' RED='\033[1;31m'
    CYAN='\033[1;36m' BOLD='\033[1m' RESET='\033[0m'
fi

status_line() {
    if ! $SILENT_MODE; then printf '  %b%-12s%b %s\n' "$1" "$RESET" "$2" "$3" >&2; fi
}
detail() { status_line "$BOLD" "$1" "$2"; }
ok() { status_line "$GREEN" 'OK' "$*"; }
dry() { status_line "$CYAN" 'Simulation' "$*"; }
warn() { status_line "$YELLOW" 'Attention' "$*"; }
step() {
    if ! $SILENT_MODE; then printf '\n%b── %s/3  %s%b\n' "$CYAN" "$1" "$2" "$RESET" >&2; fi
}
error() { printf '  %b%-12s%b %s\n' "$RED" 'ERREUR' "$RESET" "$*" >&2; }
fatal() { error "$1"; exit "${2:-1}"; }

# Fonction de journalisation : jamais sur stdout, jamais d'écriture en dry-run.
# Un défaut du journal est signalé sans interrompre une transaction déjà validée.
log_message() {
    local message
    message="$(date '+%Y-%m-%d %H:%M:%S') : $3"
    status_line "$1" "$2" "$3"
    if ! $DRY_RUN; then
        if [[ -L "$LOG_FILE" || ( -e "$LOG_FILE" && ! -f "$LOG_FILE" ) || "$LOG_FILE" -ef "$PACMAN_CONF" ]]; then
            error "Journal inaccessible ou destination refusée : $LOG_FILE. $3"
            return 0
        fi
        if ! printf '%s\n' "$message" >> "$LOG_FILE"; then
            error "Journal inaccessible : $LOG_FILE. $1"
        fi
    fi
}

select_mode() {
    [[ -z "$MODE" ]] || fatal 'Choisissez un seul mode : --value, --auto ou --restore.' 2
    MODE="$1"
}

# Traitement des arguments avant toute écriture ou demande de privilèges.
while (( $# > 0 )); do
    case "$1" in
        --restore)
            select_mode restore
            shift
            if (( $# > 0 )) && [[ "$1" != -* ]]; then
                RESTORE_FILE="$1"
                [[ -n "$RESTORE_FILE" ]] || fatal 'Chemin de sauvegarde vide.' 2
                shift
            fi
            ;;
        --auto) select_mode auto; shift ;;
        --value)
            select_mode value
            (( $# >= 2 )) || fatal 'Option --value : valeur manquante.' 2
            VALUE="$2"; shift 2 ;;
        --silent) SILENT_MODE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) fatal "Argument inconnu : $1" 2 ;;
    esac
done

# Mode interactif uniquement sur un terminal ; aucune activation automatique
# implicite depuis une tâche planifiée, un pipe ou une entrée redirigée.
if [[ -z "$MODE" ]]; then
    if $SILENT_MODE || [[ ! -t 0 ]]; then
        fatal 'Indiquez explicitement --value N, --auto ou --restore.' 2
    fi
    MODE=value
    read -r -p 'Nombre de téléchargements parallèles (1-20, ou 0 pour désactiver) : ' VALUE \
        || fatal 'Saisie interrompue.'
fi

# Validation décimale sans dépassement arithmétique ni interprétation octale.
normalize_value() {
    [[ "$VALUE" =~ ^[0-9]+$ ]] || fatal 'La valeur doit être un entier décimal de 0 à 20.' 2
    while [[ ${#VALUE} -gt 1 && "$VALUE" == 0* ]]; do VALUE="${VALUE#0}"; done
    [[ ${#VALUE} -le 2 ]] || fatal 'Valeur hors limites (0-20).' 2
    VALUE=$((10#$VALUE))
    (( VALUE <= 20 )) || fatal 'Valeur hors limites (0-20).' 2
}
if [[ "$MODE" == value ]]; then normalize_value; fi

# Vérifier les permissions et les dépendances avant de modifier quoi que ce soit.
if ! $SILENT_MODE; then printf '%bCachyOS · Réglages de Pacman%b\n' "$BOLD" "$RESET" >&2; fi
if $DRY_RUN; then dry 'Aucune modification ne sera appliquée.'; fi
case "$MODE" in
    value) detail 'Mode' "Valeur manuelle ($VALUE)" ;;
    auto) detail 'Mode' 'Estimation CPU/RAM' ;;
    restore) detail 'Mode' 'Restauration d’une sauvegarde' ;;
esac
step 1 'Vérifier les prérequis'
if ! $DRY_RUN && [[ $EUID -ne 0 ]]; then
    fatal 'Exécutez avec sudo pour appliquer ; utilisez --dry-run pour examiner.'
fi
for cmd in pacman-conf awk; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "Commande requise absente : $cmd. Aucun outil installé automatiquement."
done
if ! $DRY_RUN; then
    for cmd in mktemp cp mv cmp mkdir rm flock date touch; do
        command -v "$cmd" >/dev/null 2>&1 || fatal "Commande requise absente : $cmd."
    done
fi
[[ -f "$PACMAN_CONF" && ! -L "$PACMAN_CONF" && -r "$PACMAN_CONF" ]] \
    || fatal "Configuration absente, illisible ou lien symbolique : $PACMAN_CONF"
ok "Configuration lisible : $PACMAN_CONF"

if [[ "$MODE" == restore ]]; then
    step 2 'Préparer la restauration'
else
    step 2 'Préparer le réglage de ParallelDownloads'
fi

# Fonction de détection automatique : estimation matérielle, pas un optimum mesuré.
detect_optimal_value() {
    local cpu_count mem_gb
    for cmd in nproc free; do
        command -v "$cmd" >/dev/null 2>&1 || fatal "Commande requise pour --auto : $cmd."
    done
    cpu_count=$(nproc) || fatal 'Lecture du nombre de CPU impossible.'
    mem_gb=$(free -g | awk '/^Mem:/{print $2}') || fatal 'Lecture de la RAM impossible.'
    [[ "$cpu_count" =~ ^[1-9][0-9]*$ && "$mem_gb" =~ ^[0-9]+$ ]] \
        || fatal 'Informations CPU/RAM invalides.'
    if (( cpu_count >= 8 )); then VALUE=8
    elif (( cpu_count >= 4 )); then VALUE=6
    elif (( cpu_count >= 2 )); then VALUE=4
    else VALUE=2
    fi
    # La RAM totale en Gio limite cette estimation sur les petites machines.
    if (( mem_gb < 4 && VALUE > 3 )); then VALUE=3; fi
    detail 'Estimation' "$VALUE téléchargements (CPU : $cpu_count, RAM totale : ${mem_gb} Gio)."
}
if [[ "$MODE" == auto ]]; then detect_optimal_value; fi

# Fonction de validation de syntaxe Pacman et de lecture de la valeur effective.
# Les avertissements sont conservés et rendent la validation non concluante.
validate_pacman_syntax() {
    local file="$1" output
    if ! output=$(pacman-conf --config "$file" ParallelDownloads 2>&1); then
        error "Configuration refusée par pacman-conf : $output"
        return 1
    fi
    if [[ ! "$output" =~ ^[1-9][0-9]*$ ]]; then
        error "Valeur effective ou diagnostics Pacman inattendus : $output"
        return 1
    fi
    EFFECTIVE_VALUE="$output"
}

# Modifier seulement [options]. Garder les commentaires et exemples existants.
# Les directives actives en double sont commentées, jamais supprimées.
render_config() {
    awk -v value="$VALUE" '
    function finish_options() {
        if (inside && !written && value != 0) {
            print "ParallelDownloads = " value
            written=1
        }
    }
    /^[ \t]*\[/ {
        finish_options()
        inside=($0 ~ /^[ \t]*\[options\][ \t]*$/)
        if (inside) sections++
    }
    inside && /^[ \t]*ParallelDownloads[ \t]*=/ {
        if (value == 0 || written) print "# " $0
        else { print "ParallelDownloads = " value; written=1 }
        next
    }
    { print }
    END {
        finish_options()
        if (sections != 1) {
            print "ERREUR : une seule section [options] est requise." > "/dev/stderr"
            exit 1
        }
    }' "$1"
}

# Fonction de restauration : choisir avant de créer une nouvelle sauvegarde.
find_backup() {
    local file latest_name ambiguous=false
    if [[ -z "$RESTORE_FILE" && ( -e "$BACKUP_DIR/.latest" || -L "$BACKUP_DIR/.latest" ) ]]; then
        [[ -f "$BACKUP_DIR/.latest" && ! -L "$BACKUP_DIR/.latest" ]] || fatal 'Index de dernière sauvegarde refusé.'
        IFS= read -r latest_name < "$BACKUP_DIR/.latest" || fatal 'Index de dernière sauvegarde illisible.'
        [[ "$latest_name" == pacman.conf.bak.* && "$latest_name" != */* ]] || fatal 'Nom de dernière sauvegarde invalide.'
        RESTORE_FILE="$BACKUP_DIR/$latest_name"
    fi
    if [[ -z "$RESTORE_FILE" ]]; then
        shopt -s nullglob
        for file in "$BACKUP_DIR"/pacman.conf.bak.*; do
            [[ -f "$file" && ! -L "$file" ]] || continue
            if [[ -z "$RESTORE_FILE" || "$file" -nt "$RESTORE_FILE" ]]; then
                RESTORE_FILE="$file"
                ambiguous=false
            elif [[ ! "$RESTORE_FILE" -nt "$file" ]]; then
                ambiguous=true
            fi
        done
        shopt -u nullglob
        if $ambiguous; then fatal 'Dates de sauvegardes indiscernables : choisir explicitement --restore FICHIER.'; fi
    fi
    [[ -n "$RESTORE_FILE" && -f "$RESTORE_FILE" && ! -L "$RESTORE_FILE" && -r "$RESTORE_FILE" ]] \
        || fatal "Aucune sauvegarde utilisable : ${RESTORE_FILE:-$BACKUP_DIR}"
}

# Gestion des interruptions : restaurer l'instantané exact de cette transaction.
# Aucun choix de sauvegarde par date n'intervient dans ce retour arrière.
cleanup() {
    local status=$? file
    trap - EXIT HUP INT TERM
    if $COMMIT_PENDING; then
        if mv -f -- "$SNAPSHOT" "$PACMAN_CONF"; then
            error 'Application interrompue ou invalide : configuration précédente rétablie.'
        else
            error "RESTAURATION AUTOMATIQUE IMPOSSIBLE. Sauvegarde : $BACKUP_FILE ; instantané : $SNAPSHOT"
            # Conserver les fichiers pour une récupération manuelle.
            exit 1
        fi
        status=1
    fi
    for file in "$SNAPSHOT" "$CANDIDATE" "$LATEST_CANDIDATE"; do
        if [[ -n "$file" ]]; then rm -f -- "$file" || status=1; fi
    done
    exit "$status"
}

# Simulation : lectures et rendu sur stdout seulement, même pour --restore.
if $DRY_RUN; then
    if [[ "$MODE" == restore ]]; then
        find_backup
        validate_pacman_syntax "$RESTORE_FILE" || exit 1
        dry "Restauration depuis $RESTORE_FILE (valeur effective : $EFFECTIVE_VALUE)."
        dry 'La configuration courante serait sauvegardée avant restauration.'
    else
        validate_pacman_syntax "$PACMAN_CONF" || exit 1
        detail 'Avant' "Valeur effective : $EFFECTIVE_VALUE"
        dry "Valeur demandée : $VALUE"
        render_config "$PACMAN_CONF" || exit 1
        warn 'La configuration candidate et les Include seront validés lors de l’application.'
    fi
    step 3 'Bilan de la simulation'
    ok 'Simulation terminée.'
    exit 0
fi

# Verrouiller les exécutions de ce script, y compris restauration et sauvegardes.
# Les autres éditeurs ne prennent pas ce verrou : une comparaison précède le remplacement.
umask 077
[[ ! -L "$BACKUP_DIR" ]] || fatal "Répertoire de sauvegarde symbolique refusé : $BACKUP_DIR"
mkdir -p -- "$BACKUP_DIR"
[[ ! -L "$BACKUP_DIR/.lock" ]] || fatal 'Fichier de verrou symbolique refusé.'
exec 9>"$BACKUP_DIR/.lock"
flock -n 9 || fatal 'Une autre exécution du script est en cours.'
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$MODE" == restore ]]; then find_backup; fi

# Préparer sur le même système de fichiers pour un remplacement atomique.
SNAPSHOT=$(mktemp "${PACMAN_CONF}.snapshot.XXXXXXXX")
cp -p -- "$PACMAN_CONF" "$SNAPSHOT"
CANDIDATE=$(mktemp "${PACMAN_CONF}.candidate.XXXXXXXX")
if [[ "$MODE" == restore ]]; then
    detail 'Source' "$RESTORE_FILE"
    cp -p -- "$RESTORE_FILE" "$CANDIDATE"
else
    validate_pacman_syntax "$SNAPSHOT" || exit 1
    detail 'Avant' "Valeur effective : $EFFECTIVE_VALUE"
    cp -p -- "$SNAPSHOT" "$CANDIDATE"
    render_config "$SNAPSHOT" > "$CANDIDATE"
fi
validate_pacman_syntax "$CANDIDATE" || exit 1
if [[ "$MODE" != restore ]]; then
    EXPECTED_VALUE="$VALUE"
    if [[ "$VALUE" == 0 ]]; then EXPECTED_VALUE=1; fi
    [[ "$EFFECTIVE_VALUE" == "$EXPECTED_VALUE" ]] \
        || fatal "Valeur effective $EFFECTIVE_VALUE au lieu de $EXPECTED_VALUE. Vérifiez notamment les directives Include ; aucun fichier inclus n'est modifié."
else
    EXPECTED_VALUE="$EFFECTIVE_VALUE"
fi
ok "Configuration préparée et validée. Valeur effective prévue : $EXPECTED_VALUE"
if cmp -s -- "$CANDIDATE" "$SNAPSHOT"; then
    step 3 'Vérifier le résultat'
    ok 'La configuration correspond déjà au résultat demandé.'
    exit 0
fi

# Fonction pour créer une sauvegarde horodatée unique, même dans la même seconde.
step 3 'Sauvegarder, appliquer et vérifier'
BACKUP_FILE=$(mktemp "$BACKUP_DIR/pacman.conf.bak.$(date '+%Y%m%d_%H%M%S').XXXXXXXX")
if ! cp -p -- "$SNAPSHOT" "$BACKUP_FILE"; then
    rm -f -- "$BACKUP_FILE"
    fatal 'Échec de la sauvegarde ; configuration conservée.'
fi
# Le choix « plus récente » doit suivre la création de la sauvegarde, pas
# l'ancienne date du fichier source préservée par cp -p.
touch -- "$BACKUP_FILE"
# Les comparaisons -nt de certains Bash ne distinguent pas deux créations dans
# la même seconde. Enregistrer l'ordre des opérations sous le verrou existant.
[[ ! -L "$BACKUP_DIR/.latest" && ( ! -e "$BACKUP_DIR/.latest" || -f "$BACKUP_DIR/.latest" ) ]] \
    || fatal 'Index de dernière sauvegarde refusé ; configuration conservée.'
LATEST_CANDIDATE=$(mktemp "$BACKUP_DIR/.latest.XXXXXXXX")
printf '%s\n' "${BACKUP_FILE##*/}" > "$LATEST_CANDIDATE"
mv -f -- "$LATEST_CANDIDATE" "$BACKUP_DIR/.latest"
log_message "$BOLD" 'Sauvegarde' "Sauvegarde avant modification : $BACKUP_FILE"
# Vérifier que personne n'a remplacé ou modifié la configuration entre-temps.
[[ ! -L "$PACMAN_CONF" ]] && cmp -s -- "$PACMAN_CONF" "$SNAPSHOT" \
    || fatal 'Configuration modifiée pendant la préparation ; application annulée.'

COMMIT_PENDING=true
mv -f -- "$CANDIDATE" "$PACMAN_CONF"
validate_pacman_syntax "$PACMAN_CONF" || exit 1
[[ "$EFFECTIVE_VALUE" == "$EXPECTED_VALUE" ]] || fatal 'Valeur effective différente après remplacement.'
COMMIT_PENDING=false
log_message "$GREEN" 'OK' "Modification validée. ParallelDownloads effectif : $EFFECTIVE_VALUE"
detail 'Restauration' "sudo bash \"$0\" --restore \"$BACKUP_FILE\""
