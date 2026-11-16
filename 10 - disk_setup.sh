#!/usr/bin/env bash
# Labels et propriété des quatre volumes de données ext4 de Gabriel.
set -euo pipefail
export LC_ALL=C PATH=/usr/bin:/bin

OWNER=gabriel
UUIDS=(
    58cdcfb4-b7c7-45aa-9d27-97d3567e77ba
    7c61158b-ac8c-42e6-90ed-1f659acf4335
    cab0291d-9a2a-4110-a02f-6783238dcda3
    d594fd69-fb7d-485a-aab4-272da6bee7e0
)
LABELS=('Backup Medias' 'Disque Samsung' 'Medias' 'SSD')

CYAN='' GREEN='' YELLOW='' RED='' RESET=''
if [[ -t 1 && -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    CYAN='\033[1;36m' GREEN='\033[1;32m' YELLOW='\033[1;33m' RED='\033[1;31m' RESET='\033[0m'
fi
step() { printf '\n%b── %s%b\n' "$CYAN" "$1" "$RESET"; }
status() { printf '  %b[%s]%b %s\n' "$1" "$2" "$RESET" "$3"; }
fatal() { status "$RED" 'Échec' "$1" >&2; exit 1; }
usage() {
    cat <<'HELP'
Usage : bash "10 - disk_setup.sh" [--dry-run]

Sans option : affiche les quatre volumes et propose de continuer dans un terminal.
--dry-run   Affiche seulement l’inventaire et le plan, sans sudo.
--apply     Ancienne commande conservée pour un lancement direct avec sudo.

Le script demande sudo avant les vérifications administrateur. Les volumes
doivent être démontés et toute modification exige la saisie d’APPLIQUER.
HELP
}

MODE=interactive
case "$#:${1:-}" in
    0:) ;;
    1:--dry-run) MODE=preview ;;
    1:--apply) MODE=apply ;;
    1:--help|1:-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

step 'CachyOS · Volumes secondaires'
if [[ "$MODE" == apply ]]; then
    status "$YELLOW" 'Privilèges' 'Les droits administrateur sont requis pour modifier les labels et la propriété.'
    (( EUID == 0 )) || fatal 'Lancer sans option pour suivre le menu, ou avec sudo pour --apply.'
    [[ -t 0 && -t 1 ]] || fatal 'Un terminal interactif est requis pour appliquer.'
elif [[ "$MODE" == preview || ! -t 0 || ! -t 1 ]]; then
    MODE=preview
    status "$CYAN" 'Simulation' 'Aucun sudo nécessaire. L’inventaire sera lu sans monter les volumes.'
else
    status "$CYAN" 'Privilèges' 'L’inventaire est en lecture seule. Les modifications nécessitent sudo et une confirmation.'
fi

[[ "$(uname -s)" == Linux ]] || fatal 'Ce script nécessite Linux.'
OWNER_UID=$(id -u "$OWNER") || fatal "Compte introuvable : $OWNER."
(( OWNER_UID != 0 )) || fatal 'Le compte cible doit avoir un UID différent de 0.'
for tool in lsblk findmnt; do
    command -v "$tool" >/dev/null || fatal "Outil manquant : $tool."
done

mounted_device_numbers() {
    findmnt --kernel --noheadings --raw -o MAJ:MIN
}

discover() {
    local inventory mounted wanted uuid device fs kind node found actual label_plan i
    inventory=$(lsblk -lpn -o UUID,PATH,FSTYPE,TYPE,MAJ:MIN) ||
        fatal 'Inventaire des volumes indisponible.'
    mounted=$(mounted_device_numbers) ||
        fatal 'Table des montages indisponible.'
    DEVICES=() NODES=()
    ALL_OFFLINE=true
    for i in "${!UUIDS[@]}"; do
        wanted="${UUIDS[i]}" found=0
        while read -r uuid device fs kind node; do
            [[ "$uuid" == "$wanted" ]] || continue
            (( found += 1 ))
            [[ "$fs" == ext4 && "$kind" == part && "$device" == /dev/* &&
               -b "$device" && "$node" =~ ^[0-9]+:[0-9]+$ ]] ||
                fatal "La cible $wanted doit être une partition ext4."
            DEVICES[i]="$device" NODES[i]="$node"
        done <<< "$inventory"
        (( found == 1 )) || fatal "Une seule partition est attendue pour ${LABELS[i]} ($wanted), relevé : $found."
        actual=$(lsblk --nodeps --noheadings -o LABEL -- "${DEVICES[i]}") ||
            fatal "Lecture du label impossible sur ${DEVICES[i]}."
        if [[ "$actual" == "${LABELS[i]}" ]]; then
            label_plan="label « $actual » déjà correct"
        else
            label_plan="label « ${actual:-sans label} » → « ${LABELS[i]} »"
        fi
        if [[ $'\n'"$mounted"$'\n' == *$'\n'"${NODES[i]}"$'\n'* ]]; then
            ALL_OFFLINE=false
            status "$YELLOW" 'Monté' "${DEVICES[i]} · $label_plan"
        else
            status "$CYAN" 'Démonté' "${DEVICES[i]} · $label_plan"
        fi
    done
}

step '1 · Examiner les quatre partitions'
discover
printf '  Propriétaire prévu pour la racine et son contenu : %s (UID %s).\n' "$OWNER" "$OWNER_UID"
if [[ "$MODE" == preview ]]; then exit 0; fi
while ! $ALL_OFFLINE; do
    status "$YELLOW" 'Montage' 'Fermer les fichiers ouverts et démonter les volumes signalés depuis le gestionnaire de fichiers.'
    printf '  Entrée pour actualiser, q pour quitter : '
    if ! IFS= read -r answer || [[ "$answer" == [qQ] ]]; then
        printf '  Opération annulée.\n'
        exit 0
    fi
    discover
done
if (( EUID != 0 )); then
    printf '  Continuer vers les vérifications avec sudo ? [o/N] '
    if ! IFS= read -r answer || [[ "$answer" != [oO] && "$answer" != oui ]]; then
        printf '  Opération annulée.\n'
        exit 0
    fi
    command -v sudo >/dev/null || fatal 'Outil manquant : sudo.'
    script_path=$(realpath -e -- "${BASH_SOURCE[0]}") || fatal 'Chemin du script introuvable.'
    exec sudo -- /usr/bin/bash -- "$script_path" --apply
fi

for tool in blkid blockdev chown e2label find flock mkdir mktemp mount mountpoint rmdir umount; do
    command -v "$tool" >/dev/null || fatal "Outil manquant : $tool."
done

require_offline_device() {
    local device="$1" expected_uuid="$2" node="$3" mounted actual_uuid actual_type actual_node read_only
    actual_uuid=$(blkid -p -s UUID -o value -- "$device") ||
        fatal "Impossible de lire l’UUID sur $device."
    [[ "$actual_uuid" == "$expected_uuid" ]] ||
        fatal "UUID inattendu sur $device : $actual_uuid (attendu : $expected_uuid)."
    actual_type=$(blkid -p -s TYPE -o value -- "$device") ||
        fatal "Impossible de lire le type de système de fichiers sur $device."
    [[ "$actual_type" == ext4 ]] || fatal "Type inattendu sur $device : $actual_type (attendu : ext4)."
    # La présentation tabulaire de lsblk ajoute des espaces autour de MAJ:MIN.
    actual_node=$(lsblk --nodeps --noheadings --raw -o MAJ:MIN -- "$device") ||
        fatal "Impossible de lire le numéro de périphérique de $device."
    [[ "$actual_node" == "$node" ]] ||
        fatal "Numéro de périphérique inattendu sur $device : $actual_node (attendu : $node)."
    mounted=$(mounted_device_numbers) ||
        fatal 'Table des montages indisponible.'
    [[ $'\n'"$mounted"$'\n' != *$'\n'"$node"$'\n'* ]] || fatal "$device est monté."
    # Certaines versions de blockdev traitent le séparateur -- comme une commande.
    read_only=$(blockdev --getro "$device") || fatal "Impossible de vérifier l’accès en écriture sur $device."
    [[ "$read_only" == 0 ]] || fatal "$device est en lecture seule."
}

verify_targets() {
    local i
    for i in "${!UUIDS[@]}"; do
        require_offline_device "${DEVICES[i]}" "${UUIDS[i]}" "${NODES[i]}"
    done
}

step '2 · Confirmer les changements'
verify_targets
status "$GREEN" 'Prêt' 'Les quatre partitions ext4 sont identifiées par UUID, démontées et accessibles en écriture.'
status "$YELLOW" 'Attention' 'Le changement de propriétaire touche tous les fichiers, y compris les fichiers cachés. Il peut modifier les droits d’accès et effacer certains bits spéciaux ou capacités.'
printf '  Les groupes sont conservés. Un relevé des propriétaires d’origine précède chaque changement.\n'
printf '  Taper APPLIQUER pour continuer : '
IFS= read -r answer || fatal 'Confirmation interrompue.'
if [[ "$answer" != APPLIQUER ]]; then printf '  Opération annulée.\n'; exit 0; fi

umask 077
exec 9>/run/cachyos-disk-setup.lock || fatal 'Impossible d’ouvrir le verrou.'
flock -n 9 || fatal 'Une autre exécution est déjà en cours.'
# Revalider toutes les cibles avant d’ouvrir la première en écriture.
verify_targets

SNAPSHOT=$(mktemp -d /var/tmp/cachyos-disques.XXXXXXXX) || fatal 'Création du relevé impossible.'
MOUNT_DIR="$SNAPSHOT/volume"
cleanup() {
    local result=$?
    if mountpoint -q -- "$MOUNT_DIR"; then
        if ! umount -- "$MOUNT_DIR"; then
            status "$RED" 'Échec' "Montage encore actif : $MOUNT_DIR." >&2
            result=1
        fi
    fi
    if [[ -d "$MOUNT_DIR" ]] && ! mountpoint -q -- "$MOUNT_DIR"; then rmdir -- "$MOUNT_DIR" || result=1; fi
    printf '  Relevé et journal : %s\n' "$SNAPSHOT"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -- "$MOUNT_DIR"
printf 'État\tUUID\tPériphérique\tLabel prévu\n' > "$SNAPSHOT/journal.tsv"

for i in "${!UUIDS[@]}"; do
    uuid="${UUIDS[i]}" device="${DEVICES[i]}" label="${LABELS[i]}" node="${NODES[i]}"
    step "3 · Traiter $label ($device)"
    require_offline_device "$device" "$uuid" "$node"
    old_label=$(e2label "$device") || fatal "Lecture du label de $device impossible."
    printf '%s\n' "$old_label" > "$SNAPSHOT/$uuid.label"
    mount -t ext4 -o nosuid,nodev,noexec -- "$device" "$MOUNT_DIR" ||
        fatal "Montage temporaire impossible : $device."
    mount_identity=$(findmnt --kernel --noheadings --raw --mountpoint "$MOUNT_DIR" -o MAJ:MIN,FSTYPE,FSROOT) ||
        fatal 'Identité du montage temporaire indisponible.'
    [[ "$mount_identity" == "$node ext4 /" ]] || fatal 'Le montage temporaire ne correspond pas au volume attendu.'

    # Relevé des entrées qui changent : UID, GID, mode, inode et chemin relatif,
    # avec séparateurs NUL pour conserver aussi les caractères spéciaux.
    status "$CYAN" 'Relevé' 'Lecture des propriétaires sur ce volume.'
    find -P "$MOUNT_DIR" -xdev ! -uid "$OWNER_UID" -printf '%U\0%G\0%m\0%i\0%P\0' > "$SNAPSHOT/$uuid.proprietaires" ||
        fatal "Relevé des propriétaires incomplet pour $label."
    if [[ -s "$SNAPSHOT/$uuid.proprietaires" ]]; then
        printf 'Propriété en cours\t%s\t%s\t%s\n' "$uuid" "$device" "$label" >> "$SNAPSHOT/journal.tsv"
        status "$CYAN" 'Propriété' "Attribution des entrées concernées à $OWNER."
        find -P "$MOUNT_DIR" -xdev ! -uid "$OWNER_UID" -execdir chown -h -- "+$OWNER_UID" '{}' + ||
            fatal "Changement de propriétaire incomplet pour $label. Voir le relevé."
    else
        status "$GREEN" 'Propriété' "Toutes les entrées appartiennent déjà à $OWNER."
    fi
    remaining=$(find -P "$MOUNT_DIR" -xdev ! -uid "$OWNER_UID" -print -quit) ||
        fatal "Vérification de la propriété impossible pour $label."
    [[ -z "$remaining" ]] || fatal "Une entrée appartient encore à un autre compte : $remaining."
    umount -- "$MOUNT_DIR" || fatal "Démontage temporaire impossible : $device."

    require_offline_device "$device" "$uuid" "$node"
    if [[ "$old_label" != "$label" ]]; then
        e2label "$device" "$label" || fatal "Impossible d’appliquer le label « $label »."
    fi
    [[ "$(e2label "$device")" == "$label" ]] || fatal "Le label final de $device est inattendu."
    printf 'Vérifié\t%s\t%s\t%s\n' "$uuid" "$device" "$label" >> "$SNAPSHOT/journal.tsv"
    status "$GREEN" 'Vérifié' "Label « $label » et propriétaire $OWNER."
done

step '4 · Bilan'
status "$GREEN" 'Terminé' "${#UUIDS[@]} volumes vérifiés. Ils peuvent être remontés depuis le gestionnaire de fichiers."
