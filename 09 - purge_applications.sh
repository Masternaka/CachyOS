#!/usr/bin/env bash
# Purge ciblée des paquets et des configurations du compte courant.
set -euo pipefail
export LC_ALL=C

APPLY=false
EXPLICIT_DRY_RUN=false
LIST=false
CATALOGUE_MODE=false
NATIVE=()
FLATPAKS=()
CONFIGS=()
SNAPSHOT=''

# Paquets natifs : nom Pacman, puis chemin facultatif sous XDG_CONFIG_HOME.
NATIVE_CATALOGUE=(
    'haruna:haruna'
)

# Flatpaks : identifiants des applications personnelles.
FLATPAK_CATALOGUE=(
    'org.kde.haruna'
)

CYAN='' GREEN='' YELLOW='' BLUE='' VIOLET='' RED='' RESET='' ERROR_RESET=''
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    if [[ -t 1 ]]; then
        CYAN='\033[1;36m' GREEN='\033[1;32m' YELLOW='\033[1;33m' BLUE='\033[1;94m'
        VIOLET='\033[1;95m' RESET='\033[0m'
    fi
    if [[ -t 2 ]]; then RED='\033[1;31m' ERROR_RESET='\033[0m'; fi
fi
step() { printf '\n%b── %s%b\n' "$CYAN" "$1" "$RESET"; }
info() { printf '  %s\n' "$*"; }
status_line() { printf '  %b[%s]%b %s\n' "$1" "$2" "$RESET" "$3"; }
ok() { status_line "$GREEN" 'OK' "$*"; }
warn() { status_line "$YELLOW" 'Attention' "$*"; }
fatal() { printf '  %b[Échec]%b %s\n' "$RED" "$ERROR_RESET" "$*" >&2; exit 1; }
show_command() { printf ' '; printf ' %q' "$@"; printf '\n'; }
show_help() {
    cat <<'HELP'
Usage : bash "09 - purge_applications.sh" [--dry-run | --apply] [cibles]

  --pacman NOM       Paquet natif installé, nom exact (option répétable).
  --flatpak ID       Application Flatpak personnelle, identifiant exact.
  --config CHEMIN    Chemin relatif à XDG_CONFIG_HOME (~/.config par défaut).
  --list             Affiche l’état du catalogue sans demander de sélection.
  --dry-run          Affiche le plan sans sudo ni écriture (mode par défaut).
  --apply            Présente le plan puis demande confirmation.
  --help, -h         Affiche cette aide.

Sans cible en argument, choisir dans un seul menu avec les numéros ou les noms.
« tout » sélectionne toutes les entrées installées et admissibles des deux catalogues.
Lancer sans sudo. Avec --apply, le script utilise sudo pour les paquets natifs.
Une purge native archive d’abord les fichiers /etc déclarés par les paquets.
Les configurations personnelles sont mises de côté après la désinstallation.
Pour Flatpak, seule la configuration config/ de l’application est ciblée.
HELP
}

relative_path() {
    case "/$1/" in
        *'//'*|*'/./'*|*'/../'*|*$'\n'*|*$'\r'*|*$'\t'*) return 1 ;;
    esac
}

while (( $# > 0 )); do
    case "$1" in
        --help|-h) show_help; exit 0 ;;
        --dry-run) EXPLICIT_DRY_RUN=true; shift ;;
        --apply) APPLY=true; shift ;;
        --list) LIST=true; shift ;;
        --pacman|--flatpak|--config)
            (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || fatal "Valeur manquante : $1."
            case "$1" in
                --pacman)
                    [[ "$2" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.+@-]*$ ]] || fatal "Nom de paquet invalide : $2."
                    NATIVE+=("$2") ;;
                --flatpak)
                    [[ "$2" =~ ^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z0-9_-]+){2,}$ ]] ||
                        fatal "Identifiant Flatpak invalide : $2."
                    FLATPAKS+=("$2") ;;
                --config)
                    relative_path "$2" || fatal "Chemin de configuration invalide : $2."
                    CONFIGS+=("$2") ;;
            esac
            shift 2 ;;
        *) fatal "Option inconnue : $1. Utiliser --help." ;;
    esac
done
if $APPLY && $EXPLICIT_DRY_RUN; then fatal 'Choisir --apply ou --dry-run.'; fi
if (( ${#NATIVE[@]} + ${#FLATPAKS[@]} + ${#CONFIGS[@]} == 0 )); then CATALOGUE_MODE=true; fi
if $LIST && { $APPLY || ! $CATALOGUE_MODE; }; then
    fatal 'Utiliser --list sans cible ni --apply.'
fi
if $APPLY; then
    status_line "$CYAN" 'Privilèges' 'Lancer sans sudo. Le script utilise sudo seulement pour retirer des paquets natifs.'
elif ! $LIST; then
    status_line "$CYAN" 'Simulation' 'Aucun sudo nécessaire.'
fi
[[ "$(uname -s)" == Linux ]] || fatal 'Lancer sur la machine CachyOS.'
[[ $EUID -ne 0 ]] || fatal 'Lancer avec le compte concerné, sans sudo.'
[[ -n "${HOME:-}" && "$HOME" == /* && -d "$HOME" && "$HOME" != / && ! -L "$HOME" ]] ||
    fatal 'Dossier personnel non pris en charge.'
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
check_config_home() {
    [[ "$CONFIG_HOME" == "$HOME/"* ]] && relative_path "${CONFIG_HOME#"$HOME/"}" ||
        fatal 'XDG_CONFIG_HOME doit être un chemin normalisé sous HOME.'
}

contains_line() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }
matching_refs() {
    local ref
    MATCHES=()
    while IFS= read -r ref; do
        ref="${ref#app/}"
        [[ "${ref%%/*}" != "$2" ]] || MATCHES+=("app/$ref")
    done <<< "$1"
}

show_catalogue() {
    local installed user_refs system_refs entry id label i number system_count
    local pacman_readable=false flatpak_readable=false
    NATIVE_AVAILABLE=()
    FLATPAK_AVAILABLE=()
    CATALOGUE_NAMES=()
    if command -v pacman >/dev/null && installed=$(pacman -Qq); then
        pacman_readable=true
    fi
    if command -v flatpak >/dev/null &&
        user_refs=$(flatpak list --user --app --columns=ref) &&
        system_refs=$(flatpak list --system --app --columns=ref); then
        flatpak_readable=true
    fi

    step 'Catalogue · Paquets natifs (Pacman)'
    for i in "${!NATIVE_CATALOGUE[@]}"; do
        entry="${NATIVE_CATALOGUE[i]%%:*}"
        number=$((i + 1))
        CATALOGUE_NAMES[number]="$entry"
        label="$number. $entry"
        if ! $pacman_readable; then
            status_line "$YELLOW" 'État inconnu' "$label"
        elif contains_line "$installed" "$entry"; then
            status_line "$GREEN" 'Installé' "$label"
            NATIVE_AVAILABLE+=("$number")
        else
            status_line "$BLUE" 'Absent' "$label"
        fi
    done

    step 'Catalogue · Applications Flatpak'
    for i in "${!FLATPAK_CATALOGUE[@]}"; do
        id="${FLATPAK_CATALOGUE[i]}"
        number=$((${#NATIVE_CATALOGUE[@]} + i + 1))
        CATALOGUE_NAMES[number]="$id"
        label="$number. $id"
        if ! $flatpak_readable; then
            status_line "$YELLOW" 'État inconnu' "$label"
            continue
        fi
        matching_refs "$system_refs" "$id"
        system_count=${#MATCHES[@]}
        matching_refs "$user_refs" "$id"
        case "${#MATCHES[@]}" in
            0)
                if (( system_count > 0 )); then
                    status_line "$YELLOW" 'Installé au niveau système' "$label"
                else
                    status_line "$BLUE" 'Absent' "$label"
                fi ;;
            1)
                if (( system_count > 0 )); then
                    status_line "$GREEN" 'Installé dans ton compte et au niveau système' "$label"
                else
                    status_line "$GREEN" 'Installé dans ton compte' "$label"
                fi
                FLATPAK_AVAILABLE+=("$number") ;;
            *) status_line "$YELLOW" 'Plusieurs installations personnelles' "$label" ;;
        esac
    done
}

select_catalogue_entries() {
    local answer item number match
    local -a requested available
    SELECTED=()
    available=(
        ${NATIVE_AVAILABLE[@]+"${NATIVE_AVAILABLE[@]}"}
        ${FLATPAK_AVAILABLE[@]+"${FLATPAK_AVAILABLE[@]}"}
    )
    if (( ${#available[@]} == 0 )); then
        info 'Aucune application du catalogue ne peut être sélectionnée.'
        return 0
    fi
    step 'Choisir les applications à retirer'
    info 'Saisir les numéros ou les noms exacts, séparés par des espaces ou des virgules.'
    info 'tout = les deux listes · pacman = les paquets natifs · flatpak = les Flatpaks personnels'
    info 'Ces choix visent les entrées installées et admissibles des catalogues affichés.'
    while true; do
        SELECTED=()
        printf '\n  Sélection (Entrée ou q pour annuler) : '
        if ! IFS= read -r answer; then answer=''; fi
        IFS=$' \t' read -r -a requested <<< "${answer//,/ }"
        if (( ${#requested[@]} == 0 )); then return 0; fi
        if (( ${#requested[@]} == 1 )); then
            case "${requested[0]}" in
                q|Q) return 0 ;;
                tout|TOUT) SELECTED=("${available[@]}"); return 0 ;;
                pacman) SELECTED=(${NATIVE_AVAILABLE[@]+"${NATIVE_AVAILABLE[@]}"}); return 0 ;;
                flatpak) SELECTED=(${FLATPAK_AVAILABLE[@]+"${FLATPAK_AVAILABLE[@]}"}); return 0 ;;
            esac
        fi
        for item in "${requested[@]}"; do
            match=''
            for number in "${available[@]}"; do
                if [[ "$item" == "$number" || "$item" == "${CATALOGUE_NAMES[number]}" ]]; then
                    match="$number"
                    break
                fi
            done
            if [[ -z "$match" ]]; then
                warn "Entrée indisponible : $item. Refaire la sélection."
                continue 2
            fi
            if ! contains_line "$(printf '%s\n' ${SELECTED[@]+"${SELECTED[@]}"})" "$match"; then
                SELECTED+=("$match")
            fi
        done
        return 0
    done
}

if $CATALOGUE_MODE; then
    if $APPLY && [[ ! -t 0 || ! -t 1 ]]; then
        fatal 'Un terminal interactif est requis pour appliquer.'
    fi
    show_catalogue
    if $LIST || [[ ! -t 0 || ! -t 1 ]]; then exit 0; fi
    select_catalogue_entries
    for number in ${SELECTED[@]+"${SELECTED[@]}"}; do
        if (( number <= ${#NATIVE_CATALOGUE[@]} )); then
            NATIVE+=("${CATALOGUE_NAMES[number]}")
        else
            FLATPAKS+=("${CATALOGUE_NAMES[number]}")
        fi
    done
    if (( ${#NATIVE[@]} + ${#FLATPAKS[@]} == 0 )); then info 'Aucune cible sélectionnée.'; exit 0; fi
fi
if (( ${#CONFIGS[@]} > 0 )); then check_config_home; fi

check_config_parents() {
    local parent="${1%/*}"
    while [[ "$parent" != "$HOME" ]]; do
        [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] ||
            fatal "Dossier parent redirigé ou non valide : $parent."
        parent="${parent%/*}"
    done
}
add_config() {
    local path="$1" planned
    check_config_parents "$path"
    for planned in ${CONFIG_TARGETS[@]+"${CONFIG_TARGETS[@]}"}; do
        [[ "$path" != "$planned" ]] || return 0
        [[ "$path" != "$planned/"* && "$planned" != "$path/"* ]] ||
            fatal "Chemins de configuration imbriqués : $planned et $path."
    done
    if [[ -e "$path" || -L "$path" ]]; then
        [[ -f "$path" || -d "$path" || -L "$path" ]] || fatal "Fichier spécial refusé : $path."
        CONFIG_TARGETS+=("$path")
        CONFIG_IDS+=("$(stat -c '%d:%i:%f' -- "$path")")
    else
        status_line "$BLUE" 'Configuration absente' "$path"
    fi
}

preview_native_removal() {
    # Pacman accepte --nosave (-n) uniquement pour la désinstallation réelle.
    pacman -R --print --print-format '%n %v' -- "$@"
}

read_plan() {
    local installed target files path user_refs system_refs ref id entry
    NATIVE_TARGETS=()
    ETC_TARGETS=()
    FLATPAK_TARGETS=()
    CONFIG_TARGETS=()
    CONFIG_IDS=()
    NATIVE_TRANSACTION=''
    if (( ${#NATIVE[@]} > 0 )); then
        command -v pacman >/dev/null || fatal 'Pacman est requis pour les paquets natifs.'
        installed=$(pacman -Qq) || fatal 'Lecture de la base Pacman impossible.'
        for target in "${NATIVE[@]}"; do
            contains_line "$installed" "$target" || { status_line "$BLUE" 'Paquet absent' "$target"; continue; }
            if ! contains_line "$(printf '%s\n' "${NATIVE_TARGETS[@]}")" "$target"; then NATIVE_TARGETS+=("$target"); fi
        done
        if (( ${#NATIVE_TARGETS[@]} > 0 )); then
            NATIVE_TRANSACTION=$(preview_native_removal "${NATIVE_TARGETS[@]}") ||
                fatal 'Pacman n’a pas pu préparer le plan de suppression. Voir le diagnostic ci-dessus.'
            files=$(pacman -Qlq -- "${NATIVE_TARGETS[@]}") || fatal 'Inventaire des fichiers Pacman impossible.'
            while IFS= read -r path; do
                [[ "$path" == /etc/* && "$path" != */ ]] || continue
                relative_path "${path#/}" || fatal "Chemin système non valide : $path."
                ETC_TARGETS+=("$path")
            done <<< "$files"
        fi
    fi
    if (( ${#FLATPAKS[@]} > 0 )); then
        command -v flatpak >/dev/null || fatal 'Flatpak est requis.'
        user_refs=$(flatpak list --user --app --columns=ref) || fatal 'Lecture des applications personnelles impossible.'
        system_refs=$(flatpak list --system --app --columns=ref) || fatal 'Lecture des applications système impossible.'
        for id in "${FLATPAKS[@]}"; do
            matching_refs "$user_refs" "$id"
            case "${#MATCHES[@]}" in
                0) status_line "$BLUE" 'Flatpak absent' "$id"; continue ;;
                1) ref="${MATCHES[0]}" ;;
                *) fatal "Plusieurs branches ou architectures personnelles pour $id. Examiner flatpak list." ;;
            esac
            [[ "$ref" =~ ^app/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]] || fatal "Référence Flatpak invalide : $ref."
            if ! contains_line "$(printf '%s\n' "${FLATPAK_TARGETS[@]}")" "$ref"; then FLATPAK_TARGETS+=("$ref"); fi
            matching_refs "$system_refs" "$id"
            if (( ${#MATCHES[@]} == 0 )); then
                add_config "$HOME/.var/app/$id/config"
            else
                warn "Configuration Flatpak conservée pour l’installation système de $id."
            fi
        done
    fi
    if $CATALOGUE_MODE; then
        for entry in "${NATIVE_CATALOGUE[@]}"; do
            [[ "$entry" == *:* ]] || continue
            contains_line "$(printf '%s\n' "${NATIVE_TARGETS[@]}")" "${entry%%:*}" || continue
            path="${entry#*:}"
            relative_path "$path" || fatal "Chemin de configuration invalide dans le catalogue : $path."
            check_config_home
            add_config "$CONFIG_HOME/$path"
        done
    fi
    for path in ${CONFIGS[@]+"${CONFIGS[@]}"}; do add_config "$CONFIG_HOME/$path"; done
}

plan_signature() {
    printf '%s\0' "$NATIVE_TRANSACTION" "${ETC_TARGETS[@]}" '' "${FLATPAK_TARGETS[@]}" '' "${CONFIG_TARGETS[@]}" '' "${CONFIG_IDS[@]}" |
        sha256sum
}

step '1 · Examiner les cibles'
read_plan
if (( ${#NATIVE_TARGETS[@]} > 0 )); then
    printf '%s\n' "$NATIVE_TRANSACTION"
    show_command sudo pacman -Rn -- "${NATIVE_TARGETS[@]}"
    for path in ${ETC_TARGETS[@]+"${ETC_TARGETS[@]}"}; do status_line "$VIOLET" 'À archiver si présent' "$path"; done
fi
if (( ${#FLATPAK_TARGETS[@]} > 0 )); then
    show_command flatpak uninstall --user --app --no-related -- "${FLATPAK_TARGETS[@]}"
fi
for path in ${CONFIG_TARGETS[@]+"${CONFIG_TARGETS[@]}"}; do status_line "$CYAN" 'À mettre de côté' "$path"; done
if (( ${#NATIVE_TARGETS[@]} + ${#FLATPAK_TARGETS[@]} + ${#CONFIG_TARGETS[@]} == 0 )); then
    status_line "$BLUE" 'Déjà absentes' 'Aucune cible à retirer.'
    exit 0
fi
if ! $APPLY; then status_line "$CYAN" 'Simulation' 'Utiliser --apply pour revoir puis confirmer ce plan.'; exit 0; fi

[[ -t 0 && -t 1 ]] || fatal 'Un terminal interactif est requis pour appliquer.'
if (( ${#NATIVE_TARGETS[@]} > 0 )); then command -v sudo >/dev/null || fatal 'sudo est requis pour les paquets natifs.'; fi
warn 'Fermer les applications concernées avant la purge. Une désinstallation peut affecter une application ou un service en cours d’utilisation.'
printf 'Taper PURGER pour confirmer le plan : '
IFS= read -r answer || fatal 'Confirmation non reçue.'
if [[ "$answer" != PURGER ]]; then info 'Purge annulée.'; exit 0; fi
approved=$(plan_signature)
read_plan
[[ "$(plan_signature)" == "$approved" ]] || fatal 'Le plan a changé. Relancer pour le vérifier.'

on_exit() {
    local status=$1
    if (( status != 0 )) && [[ -n "$SNAPSHOT" ]]; then
        warn "Purge incomplète. Consulter le rapport et les sauvegardes : $SNAPSHOT"
    fi
}
trap 'on_exit "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

step '2 · Créer la sauvegarde'
umask 077
SNAPSHOT=$(mktemp -d "$HOME/.cachyos-purge.XXXXXXXX") || fatal 'Création du dossier de sauvegarde impossible.'
status_line "$VIOLET" 'Sauvegarde' "$SNAPSHOT"
printf '%s\n' "$NATIVE_TRANSACTION" > "$SNAPSHOT/paquets.txt"
printf '%s\n' "${FLATPAK_TARGETS[@]}" > "$SNAPSHOT/flatpaks.txt"
printf '%s\n' "${CONFIG_TARGETS[@]}" > "$SNAPSHOT/configurations.txt"
if (( ${#ETC_TARGETS[@]} > 0 )); then
    # Les chemins proviennent de Pacman. Refuser les parents symboliques avant la lecture root.
    printf '%s\0' "${ETC_TARGETS[@]}" | sudo bash -c '
        set -euo pipefail
        candidates() {
            while IFS= read -r -d "" file; do
                parent=${file%/*}
                while [[ -n "$parent" ]]; do
                    [[ ! -L "$parent" ]] || { printf "Parent symbolique : %s\n" "$parent" >&2; exit 1; }
                    parent=${parent%/*}
                done
                if [[ -L "$file" || -f "$file" ]]; then
                    printf "%s\0" "${file#/}"
                elif [[ -e "$file" && ! -d "$file" ]]; then
                    printf "Fichier spécial : %s\n" "$file" >&2
                    exit 1
                fi
            done
        }
        candidates | tar -C / --acls --xattrs --no-recursion --null -T - -czf -
    ' > "$SNAPSHOT/etc.tar.gz.stage" ||
        fatal 'Archivage système incomplet. Aucune désinstallation lancée.'
    mv -- "$SNAPSHOT/etc.tar.gz.stage" "$SNAPSHOT/etc.tar.gz"
fi

step '3 · Désinstaller les applications'
if (( ${#FLATPAK_TARGETS[@]} > 0 )); then
    flatpak uninstall --user --app --no-related -- "${FLATPAK_TARGETS[@]}" ||
        fatal 'La désinstallation Flatpak a échoué ou a été annulée.'
    installed=$(flatpak list --user --app --columns=ref) || fatal 'État Flatpak final indisponible.'
    for target in "${FLATPAK_TARGETS[@]}"; do
        if contains_line "$installed" "$target" || contains_line "$installed" "${target#app/}"; then
            fatal "Application Flatpak encore installée : $target."
        fi
        status_line "$GREEN" 'Flatpak retiré' "$target"
    done
fi
if (( ${#NATIVE_TARGETS[@]} > 0 )); then
    current_transaction=$(preview_native_removal "${NATIVE_TARGETS[@]}") ||
        fatal 'La suppression des paquets natifs est devenue impossible.'
    [[ "$current_transaction" == "$NATIVE_TRANSACTION" ]] || fatal 'Le plan Pacman a changé depuis la sauvegarde.'
    sudo pacman -Rn -- "${NATIVE_TARGETS[@]}" || fatal 'La désinstallation Pacman a échoué ou a été annulée.'
    installed=$(pacman -Qq) || fatal 'Lecture de l’état Pacman après la tentative impossible.'
    for target in "${NATIVE_TARGETS[@]}"; do
        if contains_line "$installed" "$target"; then fatal "Paquet encore installé : $target."; fi
        status_line "$GREEN" 'Paquet retiré' "$target"
    done
fi

step '4 · Mettre de côté les configurations et afficher le bilan'
for index in "${!CONFIG_TARGETS[@]}"; do
    path="${CONFIG_TARGETS[index]}"
    check_config_parents "$path"
    if [[ ! -e "$path" && ! -L "$path" ]]; then status_line "$BLUE" 'Configuration déjà absente' "$path"; continue; fi
    [[ "$(stat -c '%d:%i:%f' -- "$path")" == "${CONFIG_IDS[index]}" ]] ||
        fatal "Configuration remplacée depuis l’aperçu : $path."
    destination="$SNAPSHOT/fichiers/${path#"$HOME/"}"
    mkdir -p -- "${destination%/*}"
    [[ "$(stat -c '%d' -- "$path")" == "$(stat -c '%d' -- "$SNAPSHOT")" ]] ||
        fatal "Mettre de côté manuellement, sur le même système de fichiers : $path."
    mv -T -- "$path" "$destination"
    status_line "$VIOLET" 'Configuration sauvegardée' "$path"
done
ok "${#NATIVE_TARGETS[@]} paquet(s) Pacman et ${#FLATPAK_TARGETS[@]} application(s) Flatpak retirés."
status_line "$VIOLET" 'Rapport et sauvegardes' "$SNAPSHOT"
