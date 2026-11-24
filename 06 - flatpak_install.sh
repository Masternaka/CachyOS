#!/usr/bin/env bash
# Applications personnelles Flathub ; lancer sans sudo dans la session utilisateur.
set -euo pipefail

# Bilan commun ; conserver le dossier scripts/ à côté de ce fichier.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts/bilan.sh"
bilan_init "06 · Applications Flatpak" "$@"
export LC_ALL=C
DRY_RUN=false
SHOW_LIST=false
CLEANUP=false
SELECTION=''
SNAPSHOT=''
HOST_CHANGED=false
FLATHUB_DESCRIPTOR=https://flathub.org/repo/flathub.flatpakrepo

# ─── Liste des applications Flatpak à installer ───────────────────────────────
# Format : "app.id.flatpak:Description"
catalogue=(

    # Appstore pour Flatpak
    "io.github.kolunmi.Bazaar:Bazaar — magasin Flatpak"
    #"org.dupot.easyflatpak"

    # Logiciels pour gestion des flatpaks
    "io.github.flattool.Warehouse:Warehouse — gestion des applications"
    "com.github.tchx84.Flatseal:Flatseal — permissions"
    "io.github.giantpinkrobots.flatsweep:Flatsweep — nettoyage des données résiduelles"

    # Logiciels pour installation de logiciels windows et distrobox
    "com.usebottles.bottles:Bottles — applications Windows"
    "io.github.dvlv.boxbuddyrs:BoxBuddy — interface Distrobox"

    # Utilitaires pour service systemd
    "io.github.plrigaux.sysd-manager:SysD Manager — unités systemd"

    # Utilitaire pour la gestion du son
    "com.github.wwmm.easyeffects:Easy Effects — effets audio"

    # Utilitaire pour gestion des polices
    "io.github.getnf.embellish:Embellish — polices Nerd Fonts"

    # Utilitaire pour git
    "com.github.Murmele.Gittyup:Gittyup — interface Git"

    # Utilitaire de transfert de fichiers
    "org.localsend.localsend_app:LocalSend — transfert de fichiers"

    # Utilitaire de monitoring et de gestion de système
    "io.missioncenter.MissionCenter:Mission Center — surveillance système"

    # Utilitaire de sauvegarde
    "org.gnome.World.PikaBackup:Pika Backup — sauvegarde personnelle"

    # Utilitaire de communication
    #"dev.vencord.Vesktop"
)

# Présentation du plan et du bilan dans le terminal.
bilan_couleurs 1
info() { printf '  %s\n' "$*"; }
status_line() { printf '  %b[%s]%b %s\n' "$1" "$2" "$RESET" "$3"; }
ok() { status_line "$GREEN" 'OK' "$*"; }
warn() { status_line "$YELLOW" 'Attention' "$*"; }
error() { bilan_erreur "$*"; printf '  %b[Échec]%b %s\n' "$RED" "$ERROR_RESET" "$*" >&2; }
fatal() { error "$1"; exit "${2:-1}"; }
step() { BILAN_ETAPE="$*"; printf '\n%b── %s/%s  %s%b\n' "$CYAN" "$1" "$STEPS" "$2" "$RESET"; }
flatpak_user() { flatpak "$@" --user; }
# Les glyphes de progression de Flatpak nécessitent une locale UTF-8.
flatpak_progress() { LC_ALL=C.UTF-8 flatpak_user "$@"; }
show_applications_list() {
    local entry
    for entry in "$@"; do
        printf '  %-45s %s\n' "${entry%%:*}" "${entry#*:}"
    done
}
show_help() {
    cat <<'EOF'
Usage : bash "06 - flatpak_install.sh" [options]
Lancer sans sudo, avec le compte qui utilisera les applications.
Le script utilise sudo seulement si des prérequis natifs doivent être installés.

  --help, -h  Afficher l'aide sans Flatpak ni privilèges.
  --list      Afficher les identifiants et descriptions sans Flatpak.
  --all       Choisir toutes les applications du catalogue.
  --only LISTE Choisir des numéros ou identifiants exacts séparés par des virgules.
  --dry-run   Examiner seulement l'état local : aucun ajout de dépôt,
              téléchargement, inventaire écrit ou nettoyage.
  --cleanup   Proposer séparément le nettoyage des runtimes personnels
              inutilisés après une installation sans erreur.

Dans un terminal, choisir les applications ou tout le catalogue au début.
Un seul accord couvre l'installation des prérequis natifs manquants et la
mise à jour complète éventuelle, puis Flathub, les applications sélectionnées
et leurs runtimes. Pacman et Flatpak utilisent ensuite leurs réponses par défaut.
Le nettoyage facultatif reste soumis à un accord séparé.
Les installations système et les autres applications ne sont pas mises à jour.
L'inventaire ne sauvegarde pas les données personnelles ni les anciens runtimes.
EOF
}
while (( $# > 0 )); do
    case "$1" in
        --help|-h) show_help; exit 0 ;;
        --list) SHOW_LIST=true ;;
        --all)
            [[ -z "$SELECTION" ]] || fatal 'Choisir --all ou --only, une seule fois.' 2
            SELECTION=tout ;;
        --only)
            [[ -z "$SELECTION" && $# -ge 2 && -n "$2" && "$2" != -* ]] ||
                fatal 'Indiquer une liste après --only, sans répéter --only ou --all.' 2
            SELECTION="$2"
            shift ;;
        --dry-run) DRY_RUN=true ;;
        --cleanup) CLEANUP=true ;;
        *) fatal "Option inconnue : $1. Utiliser --help." 2 ;;
    esac
    shift
done
if $SHOW_LIST; then show_applications_list "${catalogue[@]}"; exit 0; fi

select_applications() {
    local choice="$1" item index count="${#catalogue[@]}" seen=' '
    local items=()
    if [[ "$choice" == tout ]]; then applications=("${catalogue[@]}"); return; fi
    choice=${choice//[[:space:]]/}
    [[ -n "$choice" && "$choice" != ,* && "$choice" != *, && "$choice" != *,,* ]] ||
        fatal 'Liste de sélection invalide. Exemples : 2,3 ou tout.' 2
    IFS=, read -r -a items <<< "$choice"
    applications=()
    for item in "${items[@]}"; do
        if [[ "$item" =~ ^[0-9]+$ ]]; then
            [[ ${#item} -le ${#count} ]] || fatal "Numéro hors catalogue : $item." 2
            index=$((10#$item - 1))
        else
            for index in "${!catalogue[@]}"; do
                [[ "${catalogue[index]%%:*}" != "$item" ]] || break
            done
            [[ "${catalogue[index]%%:*}" == "$item" ]] || fatal "Application hors catalogue : $item." 2
        fi
        (( index >= 0 && index < count )) || fatal "Numéro hors catalogue : $item." 2
        if [[ "$seen" != *" $index "* ]]; then
            applications+=("${catalogue[index]}")
            seen+="$index "
        fi
    done
}

selected() {
    local entry
    for entry in "${applications[@]}"; do
        if [[ "${entry%%:*}" == "$1" ]]; then return 0; fi
    done
    return 1
}

on_exit() {
    local status=$1
    if (( status != 0 )); then
        printf 'Opération interrompue ou en échec (code %s).\n' "$status" >&2
        if [[ -n "$SNAPSHOT" ]]; then
            printf 'Inventaire conservé : %s. Des changements ont pu être effectués ; aucun retour arrière automatique.\n' "$SNAPSHOT" >&2
        fi
        if $HOST_CHANGED; then warn 'La transaction Pacman a pu modifier l’hôte. Consulter /var/log/pacman.log.'; fi
    fi
    bilan_print "$status"
}
trap 'on_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
STEPS=4
printf '%bCachyOS · Applications Flatpak personnelles%b\n' "$BOLD" "$RESET"
if $DRY_RUN; then
    STEPS=3
    status_line "$CYAN" 'Simulation' 'Aucun sudo nécessaire.'
else
    status_line "$BOLD" 'Privilèges' 'Lancer sans sudo. Le script utilise sudo seulement pour installer les prérequis natifs manquants.'
fi
[[ $(uname -s) == Linux ]] || fatal 'Ce script nécessite Linux.'
[[ $EUID -ne 0 ]] || fatal 'Lancer sans sudo, depuis la session de l’utilisateur concerné.'
if ! $DRY_RUN; then
    [[ -t 0 && -t 1 ]] || fatal 'Exécution réelle refusée sans terminal interactif. Utiliser --dry-run.'
fi
step 1 'Choisir les applications'
if [[ -z "$SELECTION" ]]; then
    if [[ -t 0 && -t 1 ]]; then
        for index in "${!catalogue[@]}"; do
            entry="${catalogue[index]}"
            printf '  %b%2s%b  %s\n' "$CYAN" "$((index + 1))" "$RESET" "${entry#*:}"
        done
        printf 'Numéros séparés par des virgules [Entrée = tout, q = quitter] : '
        IFS= read -r SELECTION || fatal 'Sélection interrompue.'
        if [[ "$SELECTION" == q ]]; then bilan_annule 'Sélection annulée.'; info 'Installation annulée.'; exit 0; fi
    fi
    SELECTION="${SELECTION:-tout}"
fi
select_applications "$SELECTION"
status_line "$BLUE" 'Sélection' "${#applications[@]} application(s) sur ${#catalogue[@]}."
step 2 'Examiner les applications et leurs prérequis'
for tool in pacman pacman-conf awk; do
    command -v "$tool" >/dev/null 2>&1 || fatal "Commande requise absente : $tool."
done

read_host_plan() {
    local installed listing pkg target
    local required=(flatpak xdg-desktop-portal)
    installed=$(pacman -Qq) || fatal 'Lecture des paquets natifs impossible.'
    if selected io.github.dvlv.boxbuddyrs; then required+=(distrobox podman); fi
    if selected com.github.wwmm.easyeffects; then
        required+=(pipewire-audio)
        if [[ $'\n'"$installed"$'\n' != *$'\npipewire-media-session\n'* ]]; then
            required+=(wireplumber)
        fi
    fi
    case ":${XDG_CURRENT_DESKTOP:-}:" in
        *:[Nn][Ii][Rr][Ii]:*)
            required+=(xdg-desktop-portal-gtk xdg-desktop-portal-gnome)
            if [[ $'\n'"$installed"$'\n' != *$'\noo7-portal\n'* ]]; then
                required+=(gnome-keyring)
            fi
            ;;
    esac
    HOST_TARGETS=()
    HOST_MISSING=()
    HOST_REPOS=''
    for pkg in "${required[@]}"; do
        if [[ $'\n'"$installed"$'\n' != *$'\n'"$pkg"$'\n'* ]]; then HOST_MISSING+=("$pkg"); fi
    done
    (( ${#HOST_MISSING[@]} > 0 )) || return 0
    HOST_REPOS=$(pacman-conf --repo-list) || fatal 'Lecture des dépôts Pacman impossible.'
    listing=$(pacman -Sl) || fatal 'Bases Pacman locales indisponibles.'
    for pkg in "${HOST_MISSING[@]}"; do
        target=$(awk -v pkg="$pkg" '$2 == pkg && !found {print $1 "/" $2; found=1}' <<< "$listing")
        case "${target%%/*}" in
            core|extra|multilib|cachyos|cachyos-v3|cachyos-v4|cachyos-znver4|\
            cachyos-core-v3|cachyos-extra-v3|cachyos-core-v4|cachyos-extra-v4|\
            cachyos-core-znver4|cachyos-extra-znver4) HOST_TARGETS+=("$target") ;;
            *) fatal "Paquet $pkg introuvable dans les dépôts officiels configurés ou masqué par un dépôt tiers." ;;
        esac
    done
}

read_host_plan
if (( ${#HOST_TARGETS[@]} > 0 )); then
    warn 'Paquets hôte manquants. Leur installation entraîne une mise à jour système complète.'
    printf '  sudo pacman -Syu --needed --noconfirm --'; printf ' %q' "${HOST_TARGETS[@]}"; printf '\n'
    info "Dépôts actifs pour la mise à jour : ${HOST_REPOS//$'\n'/, }"
else
    ok 'Prérequis natifs déjà présents.'
fi

read_flatpak_arch() {
    ARCH=$(flatpak --default-arch) || fatal 'Architecture Flatpak indisponible.'
    [[ "$ARCH" =~ ^[a-zA-Z0-9_]+$ ]] || fatal 'Architecture Flatpak invalide.'
}

read_local_state() {
    local row url options
    REMOTES=$(flatpak_user remotes --columns=name,url,options) || fatal 'Lecture des dépôts personnels impossible.'
    INSTALLED=$(flatpak_user list --app --columns=ref,origin) || fatal 'Lecture des applications personnelles impossible.'
    row=$(printf '%s\n' "$REMOTES" | awk '$1 == "flathub" {print}')
    HAS_FLATHUB=false
    if [[ -n "$row" ]]; then
        HAS_FLATHUB=true
        url=$(printf '%s\n' "$row" | awk '{print $2}')
        case "$url" in
            https://dl.flathub.org/repo|https://dl.flathub.org/repo/|https://flathub.org/repo|https://flathub.org/repo/) ;;
            *) fatal "Le dépôt personnel flathub utilise une URL inattendue : $url. Aucune correction automatique." ;;
        esac
        options=$(printf '%s\n' "$row" | awk '{$1=""; $2=""; print}')
        case "$options" in
            *disabled*|*no-gpg-verify*|*oci*) fatal 'Le dépôt flathub est désactivé ou ses options ne sont pas prises en charge.' ;;
        esac
    fi
}
origin_for() {
    # La colonne ref de `flatpak list` omet le préfixe app/.
    printf '%s\n' "$INSTALLED" | awk -v ref="${1#app/}" '$1 == ref {print $2}'
}
check_origins() {
    local entry ref origin
    for entry in "${applications[@]}"; do
        ref="app/${entry%%:*}/$ARCH/stable"
        origin=$(origin_for "$ref")
        [[ -z "$origin" || "$origin" == flathub ]] || fatal "Origine différente pour $ref : $origin. Aucune migration automatique."
    done
}
confirm() {
    local answer
    printf '%s [o/N] ' "$1"
    IFS= read -r answer || return 1
    case "$answer" in o|O|oui|Oui|y|Y|yes) return 0 ;; *) return 1 ;; esac
}

show_flatpak_plan() {
    local entry ref
    read_flatpak_arch
    read_local_state
    check_origins
    if ! $HAS_FLATHUB; then info 'Ajout prévu : Flathub personnel depuis son descripteur HTTPS officiel.'; fi
    for entry in "${applications[@]}"; do
        ref="app/${entry%%:*}/$ARCH/stable"
        if [[ -n "$(origin_for "$ref")" ]]; then
            status_line "$BLUE" 'Déjà installée' "$ref · mise à jour à vérifier"
        else
            status_line "$CYAN" 'À installer' "$ref"
        fi
    done
}

create_snapshot() {
    umask 077
    SNAPSHOT=$(mktemp -d /var/tmp/cachyos-flatpak.XXXXXXXX) || fatal 'Création du dossier d’inventaire impossible.'
}

recheck_flatpak_plan() {
    read_flatpak_arch
    read_local_state
    check_origins
    [[ "$PREVIEW_ARCH" == "$ARCH" && "$PREVIEW_REMOTES" == "$REMOTES" &&
       "$PREVIEW_INSTALLED" == "$INSTALLED" ]] ||
        fatal 'État Flatpak modifié depuis l’aperçu. Relancer pour le vérifier.'
}

info 'Applications sélectionnées (installation personnelle, branche stable) :'
show_applications_list "${applications[@]}"
FLATPAK_PREVIEW=false
if command -v flatpak >/dev/null 2>&1; then
    show_flatpak_plan
    FLATPAK_PREVIEW=true
    PREVIEW_ARCH=$ARCH
    PREVIEW_REMOTES=$REMOTES
    PREVIEW_INSTALLED=$INSTALLED
else
    info 'Le dépôt et les applications existantes pourront être lus après installation de Flatpak.'
fi
info 'Flatpak installe automatiquement les runtimes et extensions nécessaires.'
info 'Une application présente uniquement au niveau système aura une copie personnelle.'
if $DRY_RUN; then
    step 3 'Bilan de la simulation'
    status_line "$CYAN" 'Simulation' 'Simulation locale terminée : aucun fichier écrit et aucune installation effectuée.'
    info 'La disponibilité distante et les nouvelles versions seront contrôlées après accord, en exécution réelle.'
    if $CLEANUP; then info 'Nettoyage : serait proposé séparément, aucune suppression simulée comme réussie.'; fi
    exit 0
fi

step 3 'Confirmer et lancer l’installation'
if (( ${#HOST_TARGETS[@]} > 0 )); then
    command -v sudo >/dev/null 2>&1 || fatal 'sudo est requis pour installer les prérequis natifs.'
    warn 'L’accord inclut la mise à jour complète de Pacman avec ses réponses par défaut.'
fi
warn 'L’accord couvre l’ajout éventuel de Flathub, les applications sélectionnées, leurs runtimes et extensions.'
info 'Les applications déjà présentes pourront être mises à jour. Les questions d’installation recevront leurs réponses par défaut.'
if ! confirm 'Autoriser toute cette installation ?'; then bilan_annule 'Installation refusée avant application.'; info 'Installation annulée.'; exit 0; fi

APPROVED_HOST=$(printf '%s\n' ${HOST_TARGETS[@]+"${HOST_TARGETS[@]}"} "$HOST_REPOS")
read_host_plan
[[ "$APPROVED_HOST" == "$(printf '%s\n' ${HOST_TARGETS[@]+"${HOST_TARGETS[@]}"} "$HOST_REPOS")" ]] ||
    fatal 'Le plan Pacman a changé. Relancer pour examiner les nouvelles cibles.'
if $FLATPAK_PREVIEW; then recheck_flatpak_plan; fi
if (( ${#HOST_TARGETS[@]} > 0 )); then
    create_snapshot
    pacman -Q > "$SNAPSHOT/paquets-hote-avant.txt"
    bilan_debut
    HOST_CHANGED=true
    sudo pacman -Syu --needed --noconfirm -- "${HOST_TARGETS[@]}" ||
        fatal 'La transaction Pacman a échoué ou a été annulée.'
    pacman -Q > "$SNAPSHOT/paquets-hote-apres.txt"
    read_host_plan
    (( ${#HOST_MISSING[@]} == 0 )) || fatal "Prérequis encore manquants : ${HOST_MISSING[*]}"
    bilan_action 'Transaction Pacman terminée ; prérequis natifs vérifiés.'
    ok 'Prérequis natifs vérifiés après la transaction.'
    if $FLATPAK_PREVIEW; then recheck_flatpak_plan; fi
fi
command -v flatpak >/dev/null 2>&1 || fatal 'Commande attendue absente : flatpak.'
if selected io.github.dvlv.boxbuddyrs; then
    for tool in distrobox podman; do
        command -v "$tool" >/dev/null 2>&1 || fatal "Commande attendue pour BoxBuddy absente : $tool."
    done
fi
if ! $FLATPAK_PREVIEW; then show_flatpak_plan; fi

if [[ -z "$SNAPSHOT" ]]; then create_snapshot; fi
printf '%s\n' "$REMOTES" > "$SNAPSHOT/depots-avant.txt"
flatpak_user list --all --columns=ref,origin,active > "$SNAPSHOT/references-avant.txt"
printf '%s\n' "${applications[@]}" > "$SNAPSHOT/selection.txt"
: > "$SNAPSHOT/nouvelles-applications.txt"
cat > "$SNAPSHOT/LIRE-MOI.txt" <<'EOF'
Inventaire personnel Flatpak, pas une sauvegarde des données ni des runtimes.
references-avant/apres.txt : références, origines et commits actifs abrégés.
depots-avant/apres.txt : dépôts personnels, URL et options.
nouvelles-applications.txt : références nouvellement installées et vérifiées.
Le nettoyage éventuel peut retirer des runtimes inutilisés.

Pour retirer une nouvelle application, examiner nouvelles-applications.txt puis
exécuter manuellement flatpak uninstall --user REFERENCE (sans --delete-data).
Ne pas désinstaller une application précédemment présente pour annuler sa mise à jour.
Un retour à un ancien commit dépend de sa disponibilité et de la compatibilité
des runtimes et des données ; il n'est jamais automatisé ici.
Un dépôt ajouté peut être retiré manuellement avec flatpak remote-delete --user
flathub, uniquement lorsqu'il n'est plus utilisé et après examen.
EOF
status_line "$VIOLET" 'Inventaire' "$SNAPSHOT"
if ! $HAS_FLATHUB; then
    bilan_debut
    flatpak_user remote-add --if-not-exists flathub "$FLATHUB_DESCRIPTOR" || fatal 'Ajout de Flathub personnel en échec.'
fi
read_local_state
$HAS_FLATHUB || fatal 'Flathub personnel absent après son ajout.'
check_origins

# Vérifier les références sélectionnées avant la première installation.
# Ne pas utiliser --cached en simulation : cette option préfère le cache,
# mais ne garantit pas l'absence de requêtes réseau.
unavailable=0
verified_refs=()
for entry in "${applications[@]}"; do
    ref="app/${entry%%:*}/$ARCH/stable"
    if resolved=$(flatpak_user remote-info --show-ref flathub "$ref"); then
        if [[ "$resolved" == "$ref" ]]; then
            verified_refs+=("$ref")
        else
            error "Référence inattendue : $resolved (attendue : $ref)"
            unavailable=$((unavailable + 1))
        fi
    else
        error "Référence indisponible ou non vérifiable : $ref"
        unavailable=$((unavailable + 1))
    fi
done

installed_count=0
updated_count=0
unchanged_count=0
failed_count=$unavailable
for ref in ${verified_refs[@]+"${verified_refs[@]}"}; do
    id="${ref#app/}"
    id="${id%%/*}"
    before_commit=''
    bilan_debut
    if [[ -n "$(origin_for "$ref")" ]]; then
        if ! before_commit=$(flatpak_user info --show-commit "$ref") || [[ -z "$before_commit" ]]; then
            error "Lecture du commit installé impossible : $ref."
            failed_count=$((failed_count + 1)); continue
        fi
        status_line "$CYAN" 'Vérification' "$id"
        if ! flatpak_progress update --assumeyes "$ref"; then
            error "Mise à jour échouée ou annulée : $ref"
            failed_count=$((failed_count + 1)); continue
        fi
    else
        status_line "$CYAN" 'Installation' "$id"
        if ! flatpak_progress install --assumeyes flathub "$ref"; then
            error "Échec ou annulation de l’installation : $ref"
            failed_count=$((failed_count + 1)); continue
        fi
    fi
    if ! after_commit=$(flatpak_user info --show-commit "$ref") ||
       ! after_origin=$(flatpak_user info --show-origin "$ref") ||
       [[ -z "$after_commit" || "$after_origin" != flathub ]]; then
        error "État final non conforme ou non vérifiable : $ref"
        failed_count=$((failed_count + 1)); continue
    fi
    if [[ -z "$before_commit" ]]; then
        status_line "$GREEN" 'Installée' "$id"
        bilan_action "$id : installation vérifiée."
        installed_count=$((installed_count + 1))
        printf '%s\n' "$ref" >> "$SNAPSHOT/nouvelles-applications.txt"
    elif [[ "$before_commit" != "$after_commit" ]]; then
        status_line "$GREEN" 'Mise à jour' "$id"
        bilan_action "$id : mise à jour vérifiée."
        updated_count=$((updated_count + 1))
    else
        status_line "$BLUE" 'Inchangée' "$id"
        bilan_ignore "$id : déjà à jour."
        unchanged_count=$((unchanged_count + 1))
    fi
done
if $CLEANUP && (( failed_count == 0 )); then
    if confirm 'Proposer à Flatpak de supprimer les runtimes personnels inutilisés ?'; then
        bilan_debut
        if ! flatpak_progress uninstall --unused; then
            error 'Nettoyage échoué ou annulé. Examiner les messages Flatpak.'
            failed_count=$((failed_count + 1))
        fi
    else
        status_line "$BLUE" 'Ignoré' 'Nettoyage des runtimes.'
    fi
fi
step 4 'Afficher le bilan'
flatpak_user list --all --columns=ref,origin,active > "$SNAPSHOT/references-apres.txt"
flatpak_user remotes --columns=name,url,options > "$SNAPSHOT/depots-apres.txt"
printf -v totals '%s nouvelles, %s mises à jour, %s inchangées, %s erreurs.' \
    "$installed_count" "$updated_count" "$unchanged_count" "$failed_count"
if (( failed_count == 0 )); then
    status_line "$GREEN" 'Bilan' "$totals"
else
    status_line "$SUMMARY_RED" 'Bilan en échec' "$totals"
fi
status_line "$VIOLET" 'Inventaires' "$SNAPSHOT"
if (( installed_count > 0 )); then
    user_exports="${FLATPAK_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak}/exports/share"
    if [[ ":${XDG_DATA_DIRS:-}:" != *":$user_exports:"* ]]; then
        bilan_note 'Fermer puis rouvrir la session graphique si les lanceurs Flatpak manquent dans le menu.'
        warn 'Les lanceurs Flatpak peuvent manquer dans le menu. Fermez puis rouvrez la session graphique pour actualiser XDG_DATA_DIRS.'
        info 'Les applications installées se lancent aussi avec flatpak run IDENTIFIANT.'
    fi
fi
(( failed_count == 0 )) || fatal 'Exécution terminée avec des erreurs ; consulter les messages ci-dessus.'
ok 'Installation et vérification terminées sans erreur.'
