#!/usr/bin/env bash
# Purge ciblée des paquets et des configurations du compte courant.
set -euo pipefail
export LC_ALL=C

APPLY=false
EXPLICIT_DRY_RUN=false
NATIVE=()
FLATPAKS=()
CONFIGS=()
SNAPSHOT=''

CYAN='' GREEN='' YELLOW='' RED='' RESET='' ERROR_RESET=''
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    if [[ -t 1 ]]; then CYAN='\033[1;36m' GREEN='\033[32m' YELLOW='\033[33m' RESET='\033[0m'; fi
    if [[ -t 2 ]]; then RED='\033[1;31m' ERROR_RESET='\033[0m'; fi
fi
step() { printf '\n%b── %s%b\n' "$CYAN" "$1" "$RESET"; }
info() { printf '  %s\n' "$*"; }
ok() { printf '  %bOK%b  %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '  %bAttention%b  %s\n' "$YELLOW" "$RESET" "$*"; }
fatal() { printf '  %bErreur%b  %s\n' "$RED" "$ERROR_RESET" "$*" >&2; exit 1; }
show_command() { printf ' '; printf ' %q' "$@"; printf '\n'; }
show_help() {
    cat <<'HELP'
Usage : bash "09 - purge_applications.sh" [--dry-run | --apply] [cibles]

  --pacman NOM       Paquet natif installé, nom exact (option répétable).
  --flatpak ID       Application Flatpak personnelle, identifiant exact.
  --config CHEMIN    Chemin relatif à XDG_CONFIG_HOME (~/.config par défaut).
  --dry-run          Affiche le plan sans sudo ni écriture (mode par défaut).
  --apply            Présente le plan puis demande confirmation.
  --help, -h         Affiche cette aide.

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
if (( ${#NATIVE[@]} + ${#FLATPAKS[@]} + ${#CONFIGS[@]} == 0 )); then show_help; exit 0; fi
[[ "$(uname -s)" == Linux ]] || fatal 'Lancer sur la machine CachyOS.'
[[ $EUID -ne 0 ]] || fatal 'Lancer avec le compte concerné, sans sudo.'
[[ -n "${HOME:-}" && "$HOME" == /* && -d "$HOME" && "$HOME" != / && ! -L "$HOME" ]] ||
    fatal 'Dossier personnel non pris en charge.'
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
if (( ${#CONFIGS[@]} > 0 )); then
    [[ "$CONFIG_HOME" == "$HOME/"* ]] && relative_path "${CONFIG_HOME#"$HOME/"}" ||
        fatal 'XDG_CONFIG_HOME doit être un chemin normalisé sous HOME.'
fi

contains_line() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }
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
        info "Configuration absente : $path"
    fi
}

read_plan() {
    local installed target files path own user_refs system_refs refs ref id
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
            contains_line "$installed" "$target" || { info "Paquet absent : $target"; continue; }
            if ! contains_line "$(printf '%s\n' "${NATIVE_TARGETS[@]}")" "$target"; then NATIVE_TARGETS+=("$target"); fi
        done
        if (( ${#NATIVE_TARGETS[@]} > 0 )); then
            NATIVE_TRANSACTION=$(pacman -Rn --print --print-format '%n %v' -- "${NATIVE_TARGETS[@]}") ||
                fatal 'Pacman refuse la suppression. Examiner les dépendances.'
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
            refs=()
            while IFS= read -r ref; do
                ref="${ref#app/}"
                [[ "${ref%%/*}" != "$id" ]] || refs+=("app/$ref")
            done <<< "$user_refs"
            case "${#refs[@]}" in
                0) info "Application Flatpak personnelle absente : $id"; continue ;;
                1) ref="${refs[0]}" ;;
                *) fatal "Plusieurs branches ou architectures personnelles pour $id. Examiner flatpak list." ;;
            esac
            [[ "$ref" =~ ^app/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]] || fatal "Référence Flatpak invalide : $ref."
            if ! contains_line "$(printf '%s\n' "${FLATPAK_TARGETS[@]}")" "$ref"; then FLATPAK_TARGETS+=("$ref"); fi
            own=true
            while IFS= read -r ref; do
                ref="${ref#app/}"
                if [[ "${ref%%/*}" == "$id" ]]; then own=false; break; fi
            done <<< "$system_refs"
            if $own; then
                add_config "$HOME/.var/app/$id/config"
            else
                warn "Configuration Flatpak conservée pour l’installation système de $id."
            fi
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
    for path in ${ETC_TARGETS[@]+"${ETC_TARGETS[@]}"}; do info "Archiver si présent : $path"; done
fi
if (( ${#FLATPAK_TARGETS[@]} > 0 )); then
    show_command flatpak uninstall --user --app --no-related -- "${FLATPAK_TARGETS[@]}"
fi
for path in ${CONFIG_TARGETS[@]+"${CONFIG_TARGETS[@]}"}; do info "Mettre de côté : $path"; done
if (( ${#NATIVE_TARGETS[@]} + ${#FLATPAK_TARGETS[@]} + ${#CONFIG_TARGETS[@]} == 0 )); then
    ok 'Les cibles sont déjà absentes.'
    exit 0
fi
if ! $APPLY; then ok 'Simulation terminée. Utiliser --apply pour revoir puis confirmer ce plan.'; exit 0; fi

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
info "Sauvegarde : $SNAPSHOT"
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
    done
fi
if (( ${#NATIVE_TARGETS[@]} > 0 )); then
    current_transaction=$(pacman -Rn --print --print-format '%n %v' -- "${NATIVE_TARGETS[@]}") ||
        fatal 'La suppression des paquets natifs est devenue impossible.'
    [[ "$current_transaction" == "$NATIVE_TRANSACTION" ]] || fatal 'Le plan Pacman a changé depuis la sauvegarde.'
    sudo pacman -Rn -- "${NATIVE_TARGETS[@]}" || fatal 'La désinstallation Pacman a échoué ou a été annulée.'
    installed=$(pacman -Qq) || fatal 'Lecture de l’état Pacman après la tentative impossible.'
    for target in "${NATIVE_TARGETS[@]}"; do
        if contains_line "$installed" "$target"; then fatal "Paquet encore installé : $target."; fi
    done
fi

step '4 · Mettre de côté les configurations et afficher le bilan'
for index in "${!CONFIG_TARGETS[@]}"; do
    path="${CONFIG_TARGETS[index]}"
    check_config_parents "$path"
    if [[ ! -e "$path" && ! -L "$path" ]]; then info "Configuration déjà absente : $path"; continue; fi
    [[ "$(stat -c '%d:%i:%f' -- "$path")" == "${CONFIG_IDS[index]}" ]] ||
        fatal "Configuration remplacée depuis l’aperçu : $path."
    destination="$SNAPSHOT/fichiers/${path#"$HOME/"}"
    mkdir -p -- "${destination%/*}"
    [[ "$(stat -c '%d' -- "$path")" == "$(stat -c '%d' -- "$SNAPSHOT")" ]] ||
        fatal "Mettre de côté manuellement, sur le même système de fichiers : $path."
    mv -T -- "$path" "$destination"
    ok "Configuration mise de côté : $path"
done
ok "${#NATIVE_TARGETS[@]} paquet(s) Pacman et ${#FLATPAK_TARGETS[@]} application(s) Flatpak retirés."
info "Rapport et sauvegardes : $SNAPSHOT"
