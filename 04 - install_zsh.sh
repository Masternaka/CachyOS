#!/usr/bin/env bash

set -Eeuo pipefail

# =============================================================================
# Sélection et aide : aucune modification avant les confirmations dédiées
# =============================================================================
DRY_RUN=false
INTERACTIVE=false
USE_THEME=true
REPLACE_COMMANDS=false
MODE=copy
MODE_GIVEN=false
ONLY=''
RESTORE=''
FZF_TAB_URL='https://github.com/Aloxaf/fzf-tab.git'
FZF_TAB_VERSION='v1.3.0'
FZF_TAB_COMMIT='d7e0234614dbe5369fdd760907d12c0e05a4dccc'
FZF_TAB_PACKAGE=''
FZF_TAB_SOURCE=''
SHELLS_FILE='/etc/shells'
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DEPLOY_ENGINE="$SCRIPT_DIR/scripts/zsh_deploy.py"
ALL_MODULES=(zsh starship yazi btop tealdeer bat fzf zoxide eza ripgrep fd delta lazygit kitty foot duf)
REPORT=()
SESSION=''
PHASE=''

GREEN='' YELLOW='' RED='' CYAN='' BOLD='' RESET=''
if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    GREEN='\033[32m' YELLOW='\033[33m' RED='\033[1;31m'
    CYAN='\033[1;36m' BOLD='\033[1m' RESET='\033[0m'
fi

status_line() { printf '  %b%-12s%b %s\n' "$1" "$RESET" "$2" "$3" >&2; }
info() { status_line "$BOLD" 'Info' "$*"; }
ok() { status_line "$GREEN" 'OK' "$*"; }
warn() { status_line "$YELLOW" 'Attention' "$*"; }
dry() { status_line "$CYAN" 'Simulation' "$*"; }
error() { status_line "$RED" 'Erreur' "$*"; }
fatal() { error "$1"; exit "${2:-1}"; }
step() {
    PHASE="$2"
    printf '\n%b── %s/6  %s%b\n' "$CYAN" "$1" "$2" "$RESET" >&2
}
print_report() {
    local status="$1" entry
    (( BASH_SUBSHELL == 0 )) || return 0
    printf '\n%b── Rapport final%b\n' "$CYAN" "$RESET" >&2
    for entry in ${REPORT[@]+"${REPORT[@]}"}; do info "$entry"; done
    if [[ -n "$SESSION" ]]; then
        info "Sauvegarde : $SESSION"
        info "Retour arrière : bash \"$SESSION/restaurer.sh\""
    fi
    if (( status != 0 )); then
        error "Arrêt à l’étape « $PHASE » (code $status). Consultez les détails ci-dessus."
    elif $DRY_RUN; then
        ok 'Simulation terminée. Aucune modification appliquée.'
    else
        ok 'Opération terminée.'
    fi
}
confirm() {
    local reply=''
    printf '%s [o/N] ' "$1" >&2
    IFS= read -r reply || return 1
    [[ "$reply" == o || "$reply" == O || "$reply" == oui || "$reply" == OUI ]]
}
read_choice() {
    printf '%b%s%b ' "$BOLD" "$1" "$RESET" >&2
    IFS= read -r CHOICE || fatal 'Saisie interrompue avant application.'
    if [[ "$CHOICE" == q || "$CHOICE" == Q ]]; then
        REPORT+=('Annulé depuis le menu. Aucune modification appliquée.')
        exit 0
    fi
}
show_help() {
    cat <<'HELP'
Usage : bash "04 - install_zsh.sh" [options]

Installe les outils choisis puis prépare leur intégration depuis Dotfiles.
Utilisateur normal uniquement. Kitty et Foot utilisent JetBrainsMono Nerd Font.
Depuis Fish, lancer avec bash comme dans les exemples. Fish peut rester
le shell de connexion.

  --interactive        Ouvre le menu de sélection (aussi sans argument dans un terminal)
  --dry-run, -n        Plan sans écriture, téléchargement ou installation
  --mode copy|stow     Copies (défaut) ou liens GNU Stow
  --only LISTE         Modules séparés par virgules ; défaut : les 16 modules
  --no-theme           Conserver le thème existant ; ne pas déployer starship
  --replace-commands   Activer les alias remplaçant ls/cat/cp/mv/rm/etc.
  --extras             Compatibilité : fd, delta, lazygit sont inclus par défaut
  --restore DOSSIER    Restaurer une session sauvegardée (confirmation requise)
  --help, -h           Afficher l'aide

Modules : zsh,starship,yazi,btop,tealdeer,bat,fzf,zoxide,eza,ripgrep,fd,delta,
          lazygit,kitty,foot,duf
duf affiche l'espace disque sans configuration à déployer ni alias pour df.
Exemples :
  bash "04 - install_zsh.sh" --interactive --dry-run
  bash "04 - install_zsh.sh" --mode stow --only zsh,starship,kitty,foot

Accords distincts : paquets/mise à jour système, téléchargement éventuel fzf-tab,
déploiement sauvegardé, cache tldr et changement du shell.
GNU Stow est prévu dans les deux modes pour pouvoir être utilisé ultérieurement.
Aucun paquet manquant n'est installé sans confirmation ni --noconfirm.
HELP
}
if (( $# == 0 )) && [[ -t 0 ]]; then INTERACTIVE=true; fi
while (( $# > 0 )); do
    case "$1" in
        --interactive) INTERACTIVE=true; shift ;;
        --dry-run|-n) DRY_RUN=true; shift ;;
        --no-theme) USE_THEME=false; shift ;;
        --replace-commands) REPLACE_COMMANDS=true; shift ;;
        --extras) shift ;;
        --mode|--only|--restore)
            (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || fatal "Valeur manquante pour $1" 2
            case "$1" in --mode) MODE="$2"; MODE_GIVEN=true ;; --only) ONLY="$2" ;; --restore) RESTORE="$2" ;; esac
            shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) fatal "Argument inconnu : $1" 2 ;;
    esac
done
[[ "$MODE" == copy || "$MODE" == stow ]] || fatal 'Mode attendu : copy ou stow.' 2
if [[ -n "$RESTORE" ]] && $INTERACTIVE; then fatal '--restore ouvre sa propre confirmation.' 2; fi
trap 'print_report "$?"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
printf '%bCachyOS · Outils et configuration du terminal%b\n' "$BOLD" "$RESET" >&2
if $DRY_RUN; then dry 'Aucune modification ne sera appliquée.'; fi
step 1 'Vérifier les prérequis'
[[ $EUID -ne 0 ]] || fatal 'Ne lancez pas ce script avec sudo/root : il configure votre compte personnel.'
command -v python3 >/dev/null 2>&1 || fatal 'Python 3 est requis pour préparer les sauvegardes ; aucun outil installé automatiquement.'
[[ -r "$DEPLOY_ENGINE" ]] || fatal "Moteur introuvable : $DEPLOY_ENGINE"
if [[ -n "$RESTORE" ]]; then
    $DRY_RUN && fatal 'Pour restaurer, examiner le journal de la session puis utiliser --restore sans --dry-run.' 2
    PHASE='Restaurer la session'
    info "Session à restaurer : $RESTORE"
    python3 -B "$DEPLOY_ENGINE" restore "$RESTORE"
    REPORT+=("Restauration terminée : $RESTORE")
    exit 0
fi

# =============================================================================
# Identité et chemins : ne jamais confondre cette machine avec la cible CachyOS
# =============================================================================
[[ -n ${HOME:-} && "$HOME" == /* && -d "$HOME" && -w "$HOME" ]] || fatal 'HOME doit désigner un dossier personnel absolu et accessible.'
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BACKUP_ROOT="$STATE_HOME/cachyos-zsh/backups"
FZF_TAB_DIR="$DATA_HOME/cachyos-zsh/fzf-tab-$FZF_TAB_VERSION"
for dir in "$CONFIG_HOME" "$STATE_HOME" "$DATA_HOME" "${ZDOTDIR:-$HOME}"; do
    [[ "$dir" == /* ]] || fatal "Chemin absolu requis : $dir"
done
for cmd in pacman getent id mktemp mkdir rm dirname flock; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "Commande requise absente : $cmd. Aucun outil installé automatiquement."
done
check_target() {
    local target="$1" parent
    [[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || fatal "Cible symbolique ou spéciale refusée : $target"
    parent=$(dirname -- "$target")
    while [[ "$parent" != / ]]; do
        [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] || fatal "Parent redirigé ou non répertoire : $parent"
        parent=$(dirname -- "$parent")
    done
}
check_target "$FZF_TAB_DIR/fzf-tab.plugin.zsh"
USER_NAME=$(id -un)
USER_ID=$(id -u)
PASSWD_ENTRY=$(getent passwd "$USER_NAME") || fatal 'Impossible de lire le compte utilisateur.'
IFS=: read -r ACCOUNT_NAME _ ACCOUNT_ID _ _ ACCOUNT_HOME OLD_SHELL <<< "$PASSWD_ENTRY"
[[ "$ACCOUNT_NAME" == "$USER_NAME" && "$ACCOUNT_ID" == "$USER_ID" && "$ACCOUNT_HOME" == "$HOME" && "$OLD_SHELL" == /* ]] \
    || fatal 'HOME ou identité ne correspond pas au compte courant.'
ok "Compte : $USER_NAME · Shell de connexion : $OLD_SHELL"
for shell_name in fish zsh; do
    if shell_path=$(type -P "$shell_name"); then
        info "$shell_name disponible : $shell_path"
    else
        info "$shell_name introuvable dans le PATH."
    fi
done

step 2 'Choisir les modules et préparer le plan'
if $INTERACTIVE; then
    info 'Entrée garde le choix par défaut. Tapez q pour quitter.'
    if ! $MODE_GIVEN; then
        read_choice 'Déploiement [1 = copies, 2 = liens GNU Stow, défaut 1] :'
        case "$CHOICE" in
            ''|1) MODE=copy ;;
            2) MODE=stow ;;
            *) fatal 'Choisissez 1 pour les copies ou 2 pour Stow.' 2 ;;
        esac
    fi
    if [[ -z "$ONLY" ]]; then
        info "Modules disponibles : ${ALL_MODULES[*]}"
        read_choice 'Modules séparés par des virgules [Entrée = tous] :'
        ONLY="$CHOICE"
    fi
fi
if [[ -n "$ONLY" ]]; then
    [[ "$ONLY" != *, && "$ONLY" != ,* && "$ONLY" != *,,* ]] || fatal 'Liste de modules mal formée.' 2
    IFS=, read -r -a REQUESTED <<< "$ONLY"
else
    REQUESTED=("${ALL_MODULES[@]}")
fi
SELECTED=()
SELECTION=''
contains() { local needle="$1" item; shift; for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done; return 1; }
if $INTERACTIVE; then
    if $USE_THEME && contains starship "${REQUESTED[@]}"; then
        read_choice 'Thème Starship [1 = déployer, 2 = garder la sélection actuelle, défaut 1] :'
        case "$CHOICE" in
            ''|1) ;;
            2) USE_THEME=false ;;
            *) fatal 'Choisissez 1 ou 2 pour le thème.' 2 ;;
        esac
    fi
    if ! $REPLACE_COMMANDS && contains zsh "${REQUESTED[@]}"; then
        read_choice 'Alias Zsh [1 = raccourcis distincts, 2 = remplacer ls/cat/cp/mv/rm…, défaut 1] :'
        case "$CHOICE" in
            ''|1) ;;
            2) REPLACE_COMMANDS=true ;;
            *) fatal 'Choisissez 1 ou 2 pour les alias.' 2 ;;
        esac
    fi
fi
for module in "${REQUESTED[@]}"; do
    contains "$module" "${ALL_MODULES[@]}" || fatal "Module inconnu : $module" 2
    if [[ "$module" == starship ]] && ! $USE_THEME; then continue; fi
    # Cette boucle évite aussi les doublons de la sélection explicite.
    if [[ -n "$SELECTION" ]] && contains "$module" "${SELECTED[@]}"; then fatal "Module dupliqué : $module" 2; fi
    SELECTED+=("$module")
    SELECTION+="${SELECTION:+,}$module"
done
[[ -n "$SELECTION" ]] || fatal 'Aucun module sélectionné.' 2
REPORT+=("Compte : $USER_NAME · Shell initial : $OLD_SHELL" "Mode : $MODE · Modules : $SELECTION")
info "Mode : $MODE · Modules : $SELECTION"
DEPLOY_ARGS=(--repo "$SCRIPT_DIR" --home "$HOME" --mode "$MODE" --packages "$SELECTION"
             --replace-commands "$REPLACE_COMMANDS" --use-theme "$USE_THEME")
# Premier contrôle sans écriture, avant de proposer une installation de paquets.
PLAN_TOKEN=$(python3 -B "$DEPLOY_ENGINE" preview "${DEPLOY_ARGS[@]}") || fatal 'Plan de configuration refusé.'

# =============================================================================
# Paquets des modules sélectionnés : confirmation, puis confirmation Pacman
# =============================================================================
step 3 'Vérifier les paquets et fzf-tab'
# Préparer aussi Stow en mode copie, sans créer de liens dans ce mode.
PKGS=(git stow)
add_package() { if ! contains "$1" "${PKGS[@]}"; then PKGS+=("$1"); fi; }
for module in "${SELECTED[@]}"; do
    case "$module" in
        zsh)
            for pkg in zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fzf zoxide; do add_package "$pkg"; done ;;
        delta) add_package git-delta ;;
        tealdeer) add_package tealdeer ;;
        fzf|zoxide|eza) add_package "$module"; add_package zsh ;;
        kitty|foot) add_package "$module"; add_package fontconfig; add_package ttf-jetbrains-mono-nerd ;;
        *) add_package "$module" ;;
    esac
done
if contains zsh "${SELECTED[@]}"; then
    for pkg in fzf-tab zsh-fzf-tab fzf-tab-git; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then FZF_TAB_PACKAGE="$pkg"; break; fi
    done
    if [[ -z "$FZF_TAB_PACKAGE" ]]; then
        for pkg in fzf-tab zsh-fzf-tab fzf-tab-git; do
            if pacman -Si "$pkg" >/dev/null 2>&1; then FZF_TAB_PACKAGE="$pkg"; break; fi
        done
    fi
    if [[ -n "$FZF_TAB_PACKAGE" ]]; then add_package "$FZF_TAB_PACKAGE"; fi
fi
MISSING=()
for pkg in "${PKGS[@]}"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        pacman -Si "$pkg" >/dev/null || fatal "Paquet absent des dépôts configurés : $pkg. Aucun recours automatique à l'AUR."
        MISSING+=("$pkg")
    fi
done
if (( ${#MISSING[@]} > 0 )); then
    warn "Installation ET mise à jour système proposées : ${MISSING[*]}"
    printf ' sudo pacman -Syu --needed'; printf ' %q' "${MISSING[@]}"; printf '\n'
    warn 'Les paquets et mises à jour ne sont pas annulés par la restauration des configurations.'
else
    ok 'Tous les paquets requis sont déjà installés.'
fi
if contains zsh "${SELECTED[@]}" && [[ -z "$FZF_TAB_PACKAGE" && ! -d "$FZF_TAB_DIR" ]]; then
    info "fzf-tab proposé séparément : $FZF_TAB_URL ; $FZF_TAB_VERSION ; commit $FZF_TAB_COMMIT ; destination $FZF_TAB_DIR"
    if $DRY_RUN; then REPORT+=("Téléchargement fzf-tab $FZF_TAB_VERSION à confirmer."); fi
fi
if $DRY_RUN; then
    if (( ${#MISSING[@]} > 0 )); then
        REPORT+=("Paquets à installer avec la mise à jour système : ${MISSING[*]}")
    else
        REPORT+=('Paquets requis déjà présents.')
    fi
    if contains tealdeer "${SELECTED[@]}"; then dry 'Cache Tealdeer proposé après le déploiement.'; fi
    if contains zsh "${SELECTED[@]}"; then
        dry "Shell de connexion : $OLD_SHELL. Le passage à Zsh fait l’objet d’un choix après le déploiement."
    fi
    exit 0
fi
if (( ${#MISSING[@]} > 0 )); then
    command -v sudo >/dev/null 2>&1 || fatal 'sudo est requis pour installer les paquets manquants.'
    if ! confirm 'Autorisez-vous ces paquets et la mise à jour complète du système ?'; then
        REPORT+=('Installation des paquets refusée ou confirmation absente.')
        fatal 'Installation refusée ; configurations conservées.'
    fi
    REPORT+=("Transaction Pacman demandée : ${MISSING[*]}")
    sudo pacman -Syu --needed "${MISSING[@]}" || fatal 'Transaction Pacman interrompue ou échouée. Vérifiez son résultat avant de relancer.' "$?"
    for pkg in "${PKGS[@]}"; do pacman -Q "$pkg" >/dev/null || fatal "Paquet toujours absent : $pkg"; done
    REPORT+=('Transaction Pacman terminée, présence des paquets vérifiée.')
else
    REPORT+=('Paquets requis déjà présents.')
fi
for module in "${SELECTED[@]}"; do
    case "$module" in tealdeer) binary=tldr ;; ripgrep) binary=rg ;; *) binary="$module" ;; esac
    command -v "$binary" >/dev/null 2>&1 || fatal "Commande attendue absente : $binary"
done
# Le moteur contrôle toujours les sources Zsh sélectionnées avant application.
if contains zsh "${SELECTED[@]}"; then
# fzf-tab est une extension locale, pas un gestionnaire. Les lectures de Git
# existant désactivent ses verrous optionnels ; aucun pull/update n'est exécuté.
verify_fzf_tab() {
    local directory="$1" head changes
    [[ -d "$directory/.git" && -r "$directory/fzf-tab.plugin.zsh" ]] \
        || fatal "Copie fzf-tab incomplète : $directory"
    head=$(git --no-optional-locks -C "$directory" rev-parse HEAD) || fatal 'Lecture du commit fzf-tab impossible.'
    [[ "$head" == "$FZF_TAB_COMMIT" ]] || fatal 'Version locale de fzf-tab différente ; aucun écrasement automatique.'
    changes=$(git --no-optional-locks -C "$directory" status --porcelain) || fatal 'État de fzf-tab illisible.'
    [[ -z "$changes" ]] || fatal 'Modifications locales dans fzf-tab ; copie conservée sans écrasement.'
    zsh -f -n "$directory/fzf-tab.plugin.zsh"
}
download_fzf_tab() (
    # Ce répertoire temporaire est créé uniquement après la confirmation dédiée.
    # Le trap retire seulement ce répertoire appartenant à cette opération.
    local download_stage
    umask 077
    mkdir -p -- "$(dirname -- "$FZF_TAB_DIR")"
    check_target "$(dirname -- "$FZF_TAB_DIR")/.fzf-tab.lock"
    exec 8>"$(dirname -- "$FZF_TAB_DIR")/.fzf-tab.lock"
    flock -n 8 || fatal 'Un autre téléchargement fzf-tab est en cours.'
    if [[ -d "$FZF_TAB_DIR" ]]; then verify_fzf_tab "$FZF_TAB_DIR"; exit 0; fi
    download_stage=$(mktemp -d "$(dirname -- "$FZF_TAB_DIR")/.fzf-tab-download.XXXXXXXX")
    trap 'rm -rf -- "$download_stage"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    git clone --depth 1 --branch "$FZF_TAB_VERSION" -- "$FZF_TAB_URL" "$download_stage/repo"
    verify_fzf_tab "$download_stage/repo"
    [[ ! -e "$FZF_TAB_DIR" && ! -L "$FZF_TAB_DIR" ]] || fatal 'Une copie fzf-tab est apparue ; installation annulée.'
    mv -- "$download_stage/repo" "$FZF_TAB_DIR"
)
if [[ -n "$FZF_TAB_PACKAGE" ]]; then
    package_files=$(pacman -Ql "$FZF_TAB_PACKAGE") || fatal 'Liste des fichiers fzf-tab illisible.'
    while IFS= read -r package_line; do
        file="${package_line#* }"
        if [[ "$file" == */fzf-tab.plugin.zsh && -f "$file" && -r "$file" ]]; then
            FZF_TAB_SOURCE="$file"
            break
        fi
    done <<< "$package_files"
    [[ -n "$FZF_TAB_SOURCE" ]] || fatal "Le paquet $FZF_TAB_PACKAGE ne fournit pas de fzf-tab.plugin.zsh lisible."
    zsh -f -n "$FZF_TAB_SOURCE"
    REPORT+=("fzf-tab vérifié depuis le paquet $FZF_TAB_PACKAGE.")
else
    command -v git >/dev/null 2>&1 || fatal 'Git est requis pour la copie locale de fzf-tab.'
    if [[ ! -d "$FZF_TAB_DIR" ]]; then
        confirm "Autorisez-vous le téléchargement de fzf-tab $FZF_TAB_VERSION depuis GitHub vers $FZF_TAB_DIR ?" \
            || fatal 'Téléchargement refusé ; aucune configuration remplacée.'
        download_fzf_tab
        REPORT+=("Copie locale de fzf-tab $FZF_TAB_VERSION vérifiée : $FZF_TAB_DIR")
    else
        verify_fzf_tab "$FZF_TAB_DIR"
        REPORT+=("Copie locale existante de fzf-tab vérifiée : $FZF_TAB_DIR")
    fi
    FZF_TAB_SOURCE="$FZF_TAB_DIR/fzf-tab.plugin.zsh"
fi
fi

# =============================================================================
# Configurations : plan revalidé, sauvegarde et application copy/Stow
# =============================================================================
step 4 'Sauvegarder et déployer les configurations'
DEPLOY_ARGS+=(--fzf-source "$FZF_TAB_SOURCE")
PLAN_TOKEN=$(python3 -B "$DEPLOY_ENGINE" preview "${DEPLOY_ARGS[@]}") || fatal 'Préparation finale refusée.'
confirm 'Autorisez-vous la sauvegarde puis le déploiement des fichiers annoncés ?' || fatal 'Déploiement refusé ; configurations conservées.'
SESSION=$(python3 -B "$DEPLOY_ENGINE" deploy "${DEPLOY_ARGS[@]}" --expected "$PLAN_TOKEN" --state-root "$BACKUP_ROOT") \
    || fatal 'Déploiement échoué ; consulter les messages et le dossier de sauvegarde affiché.'
REPORT+=("Configurations déployées et vérifiées en mode $MODE.")
ok 'Déploiement vérifié.'

# =============================================================================
# Vérification des intégrations, de la police, puis actions facultatives
# =============================================================================
step 5 'Vérifier les intégrations et proposer le cache Tealdeer'
if contains delta "${SELECTED[@]}"; then
    GIT_PAGER_EFFECTIVE=$(git config --global --get core.pager) || fatal "Pager Git non confirmé ; voir $SESSION/restaurer.sh"
    [[ "$GIT_PAGER_EFFECTIVE" == delta ]] || fatal "Un réglage prioritaire empêche l'activation de Delta : $GIT_PAGER_EFFECTIVE. Voir $SESSION/restaurer.sh"
    REPORT+=('Pager Git vérifié : Delta.')
fi
if contains kitty "${SELECTED[@]}" || contains foot "${SELECTED[@]}"; then
    FONT_MATCH=$(fc-match -f '%{family}\n' 'JetBrainsMono Nerd Font') || fatal 'Lecture Fontconfig impossible ; configurations sauvegardées.'
    [[ "$FONT_MATCH" == *JetBrainsMono* && ( "$FONT_MATCH" == *Nerd* || "$FONT_MATCH" == *NF* ) ]] \
        || fatal "Police Nerd Font non confirmée par Fontconfig : $FONT_MATCH. Voir $SESSION/restaurer.sh"
    info "Police trouvée : $FONT_MATCH. Rouvrir Kitty et Foot pour utiliser la nouvelle configuration."
    REPORT+=("Police vérifiée : $FONT_MATCH")
fi
if contains tealdeer "${SELECTED[@]}"; then
    info 'Tealdeer : tldr --update télécharge le cache des exemples et peut mettre à jour un cache existant.'
    if confirm 'Autorisez-vous le téléchargement du cache Tealdeer maintenant ?'; then
        tldr --update || fatal "Échec du cache Tealdeer ; configurations conservées. Retour arrière : $SESSION/restaurer.sh"
        REPORT+=('Cache Tealdeer mis à jour.')
    else
        info 'Cache Tealdeer conservé ; les exemples peuvent être indisponibles tant que le cache est absent.'
        REPORT+=('Mise à jour du cache Tealdeer passée.')
    fi
fi
step 6 'Choisir le shell de connexion'
if contains zsh "${SELECTED[@]}"; then
    ZSH_PATH=$(type -P zsh) || fatal 'Exécutable Zsh introuvable.'
    if [[ "$OLD_SHELL" == "$ZSH_PATH" || ( "${OLD_SHELL##*/}" == zsh && "$OLD_SHELL" -ef "$ZSH_PATH" ) ]]; then
        ok "Zsh est déjà le shell de connexion : $OLD_SHELL"
        REPORT+=("Shell de connexion conservé : $OLD_SHELL")
    else
        info "Shell actuel : $OLD_SHELL · Remplacement proposé : $ZSH_PATH"
        printf '  Commande     chsh -s %q\n' "$ZSH_PATH" >&2
        info 'Le changement s’applique aux prochaines connexions. Le terminal déjà ouvert continue avec son shell.'
        if confirm 'Remplacer le shell de connexion actuel par Zsh avec chsh ?'; then
            command -v chsh >/dev/null 2>&1 || fatal "chsh absent. Voir $SESSION/restaurer.sh"
            grep -Fx -- "$ZSH_PATH" "$SHELLS_FILE" >/dev/null || fatal "Zsh non déclaré dans $SHELLS_FILE ; shell conservé."
            CURRENT_ENTRY=$(getent passwd "$USER_NAME") || fatal 'Impossible de relire le compte avant chsh.'
            [[ "${CURRENT_ENTRY##*:}" == "$OLD_SHELL" ]] || fatal 'Shell modifié depuis le début ; changement annulé.'
            python3 -B "$DEPLOY_ENGINE" mark-shell "$SESSION" --user "$USER_NAME" --old "$OLD_SHELL" --new "$ZSH_PATH"
            REPORT+=("Changement de shell demandé : $OLD_SHELL → $ZSH_PATH")
            chsh -s "$ZSH_PATH" || fatal "Échec de chsh ; configuration conservée. Voir $SESSION/restaurer.sh"
            NEW_ENTRY=$(getent passwd "$USER_NAME") || fatal 'Impossible de vérifier le shell après chsh.'
            [[ "${NEW_ENTRY##*:}" == "$ZSH_PATH" ]] || fatal "Changement de shell non confirmé. Voir $SESSION/restaurer.sh"
            REPORT+=("Shell de connexion changé et vérifié : $OLD_SHELL → $ZSH_PATH")
        else
            REPORT+=("Shell de connexion conservé : $OLD_SHELL")
        fi
    fi
else
    info 'Module Zsh absent de la sélection.'
    REPORT+=("Shell de connexion conservé : $OLD_SHELL")
fi
