#!/usr/bin/env bash
# Applications personnelles Flathub ; lancer sans sudo dans la session utilisateur.
set -euo pipefail
export LC_ALL=C
DRY_RUN=false
SHOW_LIST=false
CLEANUP=false
SNAPSHOT=''
FLATHUB_DESCRIPTOR=https://flathub.org/repo/flathub.flatpakrepo

# ─── Liste des applications Flatpak à installer ───────────────────────────────
# Format : "app.id.flatpak:Description"
applications=(

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

info() { printf '%s\n' "$*"; }
fatal() { printf 'Erreur : %s\n' "$1" >&2; exit "${2:-1}"; }
flatpak_user() { flatpak "$@" --user; }
show_applications_list() {
    local entry
    for entry in "${applications[@]}"; do
        printf '  %-45s %s\n' "${entry%%:*}" "${entry#*:}"
    done
}
show_help() {
    cat <<'EOF'
Usage : bash "09 - flatpak_install.sh" [options]
Lancer sans sudo, avec le compte qui utilisera les applications.

  --help, -h  Afficher l'aide sans Flatpak ni privilèges.
  --list      Afficher les identifiants et descriptions sans Flatpak.
  --dry-run   Examiner seulement l'état local : aucun ajout de dépôt,
              téléchargement, inventaire écrit ou nettoyage.
  --cleanup   Proposer séparément le nettoyage des runtimes personnels
              inutilisés après une installation sans erreur.

Après aperçu et confirmation : inventaire privé sous /var/tmp, ajout éventuel
de Flathub personnel, vérification en ligne des 13 références stables, puis
installation ou mise à jour des seules applications sélectionnées.
Les dialogues natifs de Flatpak restent actifs. Aucun retry automatique.
Les installations système et les autres applications ne sont pas mises à jour.
L'inventaire ne sauvegarde pas les données personnelles ni les anciens runtimes.
EOF
}
for arg in "$@"; do
    case "$arg" in
        --help|-h) show_help; exit 0 ;;
        --list) SHOW_LIST=true ;;
        --dry-run) DRY_RUN=true ;;
        --cleanup) CLEANUP=true ;;
        *) fatal "Option inconnue : $arg. Utiliser --help." 2 ;;
    esac
done
if $SHOW_LIST; then show_applications_list; exit 0; fi

on_exit() {
    local status=$1
    if (( status != 0 )); then
        printf 'Opération interrompue ou en échec (code %s).\n' "$status" >&2
        if [[ -n "$SNAPSHOT" ]]; then
            printf 'Inventaire conservé : %s. Des changements ont pu être effectués ; aucun retour arrière automatique.\n' "$SNAPSHOT" >&2
        fi
    fi
}
trap 'on_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
[[ $(uname -s) == Linux ]] || fatal 'Ce script nécessite Linux.'
[[ $EUID -ne 0 ]] || fatal 'Lancer sans sudo, depuis la session de l’utilisateur concerné.'
for tool in flatpak awk; do
    command -v "$tool" >/dev/null 2>&1 || fatal "Commande requise absente : $tool. Aucun outil installé automatiquement."
done
# BoxBuddy utilise ces outils sur l'hôte. Ne pas réinstaller ceux déjà préparés.
for tool in distrobox podman; do
    command -v "$tool" >/dev/null 2>&1 || fatal "BoxBuddy nécessite $tool sur l’hôte. Vérifier l’installation prévue par le script de paquets."
done
ARCH=$(flatpak --default-arch) || fatal 'Architecture Flatpak indisponible.'
[[ "$ARCH" =~ ^[a-zA-Z0-9_]+$ ]] || fatal 'Architecture Flatpak invalide.'

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

read_local_state
check_origins
info 'Applications sélectionnées (installation personnelle, branche stable) :'
show_applications_list
if ! $HAS_FLATHUB; then info 'Ajout prévu : Flathub personnel depuis son descripteur HTTPS officiel.'; fi
for entry in "${applications[@]}"; do
    ref="app/${entry%%:*}/$ARCH/stable"
    if [[ -n "$(origin_for "$ref")" ]]; then
        info "À vérifier pour mise à jour : $ref"
    else
        info "À installer : $ref"
    fi
done
info 'Une application présente uniquement au niveau système aura une copie personnelle.'
if $DRY_RUN; then
    info 'Simulation locale terminée : aucun fichier écrit et aucune installation effectuée.'
    info 'La disponibilité distante et les nouvelles versions seront contrôlées après accord, en exécution réelle.'
    if $CLEANUP; then info 'Nettoyage : serait proposé séparément, aucune suppression simulée comme réussie.'; fi
    exit 0
fi

[[ -t 0 && -t 1 ]] || fatal 'Exécution réelle refusée sans terminal interactif. Utiliser --dry-run.'
info 'Effets : inventaire privé, accès réseau et cache Flatpak, dépôt personnel éventuel, applications et runtimes nécessaires.'
info 'Les applications déjà présentes pourront être mises à jour ; une liste ne remplace pas une sauvegarde de leurs données.'
if ! confirm 'Autoriser ces opérations ?'; then info 'Opération annulée ; aucun fichier écrit.'; exit 0; fi
PREVIEW_REMOTES=$REMOTES
PREVIEW_INSTALLED=$INSTALLED
read_local_state
check_origins
[[ "$PREVIEW_REMOTES" == "$REMOTES" && "$PREVIEW_INSTALLED" == "$INSTALLED" ]] || fatal 'État local modifié pendant la confirmation. Relancer pour examiner le nouvel aperçu.'

umask 077
SNAPSHOT=$(mktemp -d /var/tmp/cachyos-flatpak.XXXXXXXX) || fatal 'Création de l’inventaire impossible.'
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
info "Inventaire : $SNAPSHOT"
if ! $HAS_FLATHUB; then
    flatpak_user remote-add --if-not-exists flathub "$FLATHUB_DESCRIPTOR" || fatal 'Ajout de Flathub personnel en échec.'
fi
read_local_state
$HAS_FLATHUB || fatal 'Flathub personnel absent après son ajout.'
check_origins

# Vérifier toutes les références distantes avant la première installation.
# Ne pas utiliser --cached en simulation : cette option préfère le cache,
# mais ne garantit pas l'absence de requêtes réseau.
unavailable=0
for entry in "${applications[@]}"; do
    ref="app/${entry%%:*}/$ARCH/stable"
    if resolved=$(flatpak_user remote-info --show-ref flathub "$ref"); then
        if [[ "$resolved" != "$ref" ]]; then
            printf 'Référence inattendue : %s (attendue : %s)\n' "$resolved" "$ref" >&2
            unavailable=$((unavailable + 1))
        fi
    else
        printf 'Référence indisponible ou non vérifiable : %s\n' "$ref" >&2
        unavailable=$((unavailable + 1))
    fi
done
(( unavailable == 0 )) || fatal "$unavailable référence(s) non vérifiable(s). Aucune application installée ; le dépôt et le cache ont pu être créés."

installed_count=0
updated_count=0
unchanged_count=0
failed_count=0
for entry in "${applications[@]}"; do
    ref="app/${entry%%:*}/$ARCH/stable"
    before_commit=''
    if [[ -n "$(origin_for "$ref")" ]]; then
        before_commit=$(flatpak_user info --show-commit "$ref") || fatal "Lecture du commit installé impossible : $ref."
        if ! flatpak_user update "$ref"; then
            printf 'Échec ou annulation de la mise à jour : %s\n' "$ref" >&2
            failed_count=$((failed_count + 1)); continue
        fi
    elif ! flatpak_user install flathub "$ref"; then
        printf 'Échec ou annulation de l’installation : %s\n' "$ref" >&2
        failed_count=$((failed_count + 1)); continue
    fi
    if ! after_commit=$(flatpak_user info --show-commit "$ref") ||
       ! after_origin=$(flatpak_user info --show-origin "$ref") ||
       [[ -z "$after_commit" || "$after_origin" != flathub ]]; then
        printf 'État final non conforme ou non vérifiable : %s\n' "$ref" >&2
        failed_count=$((failed_count + 1)); continue
    fi
    if [[ -z "$before_commit" ]]; then
        installed_count=$((installed_count + 1))
        printf '%s\n' "$ref" >> "$SNAPSHOT/nouvelles-applications.txt"
    elif [[ "$before_commit" != "$after_commit" ]]; then
        updated_count=$((updated_count + 1))
    else
        unchanged_count=$((unchanged_count + 1))
    fi
done
if $CLEANUP && (( failed_count == 0 )); then
    if confirm 'Proposer à Flatpak de supprimer les runtimes personnels inutilisés ?'; then
        if ! flatpak_user uninstall --unused; then
            info 'Le nettoyage a échoué ou a été annulé ; examiner les messages Flatpak.'
            failed_count=$((failed_count + 1))
        fi
    else
        info 'Nettoyage ignoré.'
    fi
fi
flatpak_user list --all --columns=ref,origin,active > "$SNAPSHOT/references-apres.txt"
flatpak_user remotes --columns=name,url,options > "$SNAPSHOT/depots-apres.txt"
printf 'Bilan : %s nouvelles, %s mises à jour, %s inchangées, %s erreurs.\n' "$installed_count" "$updated_count" "$unchanged_count" "$failed_count"
info "Inventaires : $SNAPSHOT"
(( failed_count == 0 )) || fatal 'Exécution terminée avec des erreurs ; consulter les messages ci-dessus.'
info 'Installation et vérification terminées sans erreur.'
