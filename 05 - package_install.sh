#!/usr/bin/env bash
# Installation de paquets depuis les dépôts officiels utilisés par CachyOS.
# Aucun appel à l'AUR, aucun ajout de dépôt ni déploiement des Dotfiles.
set -euo pipefail
export LC_ALL=C

DRY_RUN=false
LIST_ONLY=false
SNAPSHOT=''
TRANSACTION_STARTED=false

# Intégration Wayland et gestionnaire de paquets : exemples conservés.

      # Intégration Wayland (notamment Niri)
      #qt5-wayland
      #qt6-wayland

# Utilitaires
GROUP_UTILITAIRES=(
      catfish
      flameshot
      gnome-disk-utility
      gparted
      #openrgb
      qbittorrent
      transmission-qt
      #lshw
      #fwupd
      timeshift
      7zip
      stow

)

# Polices
GROUP_POLICES=(
      ttf-jetbrains-mono-nerd
      ttf-meslo-nerd
      ttf-firacode-nerd

)

# Paquets de langue
GROUP_LANGUES=(
      firefox-i18n-fr
      thunderbird-i18n-fr

)

# Sécurité
GROUP_SECURITE=(
      #keepassxc
      bitwarden
      proton-pass
      #proton-vpn-gtk-app
      firewalld
      firewall-config

)

# Navigateur internet et email
GROUP_INTERNET=(
      firefox
      thunderbird
      #vivaldi
      #vivaldi-ffmpeg-codecs
      #brave-bin
      brave-origin-bin
      #helium-browser-bin
      #zen-browser-bin
      floorp-bin
      waterfox-bin

)

# Multimédia
GROUP_MULTIMEDIA=(
      strawberry
      #vlc
      mpv

)

# Communication
GROUP_COMMUNICATION=(
      #discord
      vesktop-bin

)

# Office et notes
GROUP_BUREAUTIQUE=(
      libreoffice-fresh
      libreoffice-fresh-fr
      obsidian

)

# Virtualisation
GROUP_VIRTUALISATION=(
      qemu-full
      swtpm
      virt-manager
      distrobox
      podman

)

# Terminal
GROUP_TERMINAUX=(
      kitty
      foot
      ghostty

)

# Utilitaires terminal
GROUP_TERMINAL=(
      btop
      fastfetch
      tealdeer
      git
      curl
      wget
      yazi
      starship

)

# Développement
GROUP_DEVELOPPEMENT=(
      micro
      code
      github-desktop
      meld
      zed
      #Helix
      #lazygit
      #lazydocker
      #neovim

      # Package manager
      #yay

)

# AI
GROUP_IA=(
      openai-codex
      claude-desktop
      claude-code
      opencode
      opencode-desktop

)

# KDE Plasma
GROUP_KDE=(
      merkuro
      dolphin-plugins
      isoimagewriter
      yakuake
      krusader
      systemdgenie
      print-manager

)

PACKAGE_GROUPS=(utilitaires polices langues securite internet multimedia communication bureautique virtualisation terminaux terminal developpement ia kde)
PACKAGES=()
append_group() {
  case "$1" in
    utilitaires) PACKAGES+=("${GROUP_UTILITAIRES[@]}") ;;
    polices) PACKAGES+=("${GROUP_POLICES[@]}") ;;
    langues) PACKAGES+=("${GROUP_LANGUES[@]}") ;;
    securite) PACKAGES+=("${GROUP_SECURITE[@]}") ;;
    internet) PACKAGES+=("${GROUP_INTERNET[@]}") ;;
    multimedia) PACKAGES+=("${GROUP_MULTIMEDIA[@]}") ;;
    communication) PACKAGES+=("${GROUP_COMMUNICATION[@]}") ;;
    bureautique) PACKAGES+=("${GROUP_BUREAUTIQUE[@]}") ;;
    virtualisation) PACKAGES+=("${GROUP_VIRTUALISATION[@]}") ;;
    terminaux) PACKAGES+=("${GROUP_TERMINAUX[@]}") ;;
    terminal) PACKAGES+=("${GROUP_TERMINAL[@]}") ;;
    developpement) PACKAGES+=("${GROUP_DEVELOPPEMENT[@]}") ;;
    ia) PACKAGES+=("${GROUP_IA[@]}") ;;
    kde) PACKAGES+=("${GROUP_KDE[@]}") ;;
    *) fatal "Groupe inconnu : $1. Utiliser --list-groups." 2 ;;
  esac
}


# Présentation du plan et du bilan dans le terminal.
CYAN='' BOLD='' GREEN='' YELLOW='' BLUE='' VIOLET='' RED='' RESET='' ERROR_RESET=''
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
  if [[ -t 1 ]]; then
    CYAN='\033[1;36m' BOLD='\033[1m' GREEN='\033[1;32m' YELLOW='\033[1;33m'
    BLUE='\033[1;94m' VIOLET='\033[1;95m' RESET='\033[0m'
  fi
  if [[ -t 2 ]]; then RED='\033[1;31m' ERROR_RESET='\033[0m'; fi
fi
info() { printf '  %s\n' "$*"; }
status_line() { printf '  %b[%s]%b %s\n' "$1" "$2" "$RESET" "$3"; }
ok() { status_line "$GREEN" 'OK' "$*"; }
warn() { status_line "$YELLOW" 'Attention' "$*"; }
error() { printf '  %b[Échec]%b %s\n' "$RED" "$ERROR_RESET" "$*" >&2; }
fatal() { error "$1"; exit "${2:-1}"; }
step() { printf '\n%b── %s/%s  %s%b\n' "$CYAN" "$1" "$STEPS" "$2" "$RESET"; }

show_help() {
  cat <<'EOF'
Usage : bash "05 - package_install.sh" [--list | --dry-run] [--groups LISTE]

  --help, -h   Afficher cette aide, sans privilèges ni contrôle système.
  --list-groups Afficher les groupes disponibles, sans contrôle système.
  --groups LISTE Sélectionner des groupes séparés par des virgules (défaut : tous).
  --list       Afficher la liste exacte des paquets sélectionnés.
  --dry-run    Vérifier les dépôts et afficher les cibles, sans écriture,
               téléchargement, sudo, mise à jour ni nettoyage.

Sans option : contrôle, aperçu, confirmation puis une transaction Pacman
avec mise à jour complète du système. Lancer depuis un terminal interactif.
Sudo est utilisé uniquement pour Pacman si nécessaire. Pacman conserve ses
propres confirmations (conflits, remplacements et transaction finale).

Sources autorisées : cachyos, variantes stables v3/v4/znver4 et les dépôts
Arch stables core/extra/multilib normalement utilisés par CachyOS.
Tout dépôt tiers ou de test activé bloque l'exécution, dépendances comprises.
Aucun dépôt n'est ajouté ou désactivé automatiquement.

Les contrôles utilisent les bases locales existantes. Une base absente ou
un paquet introuvable bloque le script ; aucune synchronisation isolée -Sy.
La transaction réelle -Syu actualise les bases et confirme les versions finales.

L'inventaire avant/après est conservé dans un dossier privé sous /var/tmp.
Ce n'est pas une sauvegarde système : pas de restauration automatique,
pas de suppression de paquets ni de nettoyage du cache.
EOF
}

SELECTED_PACKAGE_GROUPS=''
while (( $# > 0 )); do
  case "$1" in
    --help|-h) show_help; exit 0 ;;
    --list) LIST_ONLY=true; shift ;;
    --list-groups) printf '%s\n' "${PACKAGE_GROUPS[@]}"; exit 0 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --groups)
      [[ -z "$SELECTED_PACKAGE_GROUPS" && $# -ge 2 && -n "$2" && "$2" != -* ]] || fatal 'Valeur --groups manquante ou répétée.' 2
      SELECTED_PACKAGE_GROUPS="$2"; shift 2 ;;
    *) fatal "Option inconnue : $1. Utiliser --help." 2 ;;
  esac
done
if [[ -n "$SELECTED_PACKAGE_GROUPS" ]]; then
  [[ "$SELECTED_PACKAGE_GROUPS" != ,* && "$SELECTED_PACKAGE_GROUPS" != *, && "$SELECTED_PACKAGE_GROUPS" != *,,* ]] || fatal 'Liste de groupes mal formée.' 2
  IFS=, read -r -a REQUESTED_PACKAGE_GROUPS <<< "$SELECTED_PACKAGE_GROUPS"
else
  REQUESTED_PACKAGE_GROUPS=("${PACKAGE_GROUPS[@]}")
fi
SEEN_PACKAGE_GROUPS=' '
for group in "${REQUESTED_PACKAGE_GROUPS[@]}"; do
  [[ "$SEEN_PACKAGE_GROUPS" != *" $group "* ]] || fatal "Groupe dupliqué : $group" 2
  append_group "$group"
  SEEN_PACKAGE_GROUPS+="$group "
done
if $LIST_ONLY; then printf '%s\n' "${PACKAGES[@]}"; exit 0; fi

on_exit() {
  local status=$1
  if (( status != 0 )); then
    printf 'Opération interrompue ou en échec (code %s).\n' "$status" >&2
    if [[ -n "$SNAPSHOT" ]]; then
      printf 'Inventaire conservé : %s\n' "$SNAPSHOT" >&2
    fi
    if $TRANSACTION_STARTED; then
      printf 'Pacman a pu effectuer des changements. Examiner son journal ; aucun retour arrière automatique.\n' >&2
    fi
  fi
}
trap 'on_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

STEPS=4
printf '%bCachyOS · Paquets natifs%b\n' "$BOLD" "$RESET"
if $DRY_RUN; then
  STEPS=3
  status_line "$CYAN" 'Simulation' 'Aucun sudo nécessaire.'
else
  status_line "$BOLD" 'Privilèges' 'Lancer depuis le compte utilisateur. Le script utilise sudo pour la transaction Pacman après confirmation.'
fi
step 1 'Vérifier les prérequis'
[[ $(uname -s) == Linux ]] || fatal 'Ce script nécessite CachyOS Linux.'
[[ -r /etc/os-release ]] || fatal '/etc/os-release est introuvable.'
OS_ID=$(awk -F= '$1 == "ID" {gsub(/["\047]/, "", $2); print $2}' /etc/os-release)
[[ "$OS_ID" == cachyos ]] || fatal 'Ce script est réservé à CachyOS.'
for tool in pacman pacman-conf awk; do
  command -v "$tool" >/dev/null 2>&1 || fatal "Commande requise absente : $tool."
done

allowed_repository() {
  case "$1" in
    core|extra|multilib|cachyos|cachyos-v3|cachyos-v4|cachyos-znver4|\
    cachyos-core-v3|cachyos-extra-v3|cachyos-core-v4|cachyos-extra-v4|\
    cachyos-core-znver4|cachyos-extra-znver4) return 0 ;;
    *) return 1 ;;
  esac
}

check_repositories() {
  local repository configured has_cachyos=false
  configured=$(pacman-conf --repo-list) || fatal 'Lecture des dépôts impossible.'
  [[ -n "$configured" ]] || fatal 'Aucun dépôt configuré.'
  while IFS= read -r repository; do
    allowed_repository "$repository" || fatal "Dépôt non autorisé activé : $repository. Aucun changement effectué."
    case "$repository" in cachyos|cachyos-*) has_cachyos=true ;; esac
  done <<< "$configured"
  $has_cachyos || fatal 'Aucun dépôt CachyOS stable activé.'
  CONFIGURED_REPOS=$configured
  CONFIG_EFFECTIVE=$(pacman-conf) || fatal 'Lecture de la configuration effective impossible.'
}

resolve_packages() {
  local listing package target missing=0
  check_repositories
  # -Sl consulte les bases locales : aucun téléchargement ni rafraîchissement.
  listing=$(pacman -Sl) || fatal 'Bases locales indisponibles. Vérifier les dépôts sur la machine cible.'
  TARGETS=()
  info 'Paquets sélectionnés et dépôts (priorité de la configuration Pacman) :'
  for package in "${PACKAGES[@]}"; do
    # Lire toute la sortie évite un SIGPIPE avec pipefail sur de grosses bases.
    target=$(printf '%s\n' "$listing" | awk -v pkg="$package" '$2 == pkg && !found {print $1 "/" $2; found=1}')
    if [[ -z "$target" ]]; then
      error "Paquet introuvable : $package"
      missing=$((missing + 1))
      continue
    fi
    allowed_repository "${target%%/*}" || fatal "Source non autorisée : $target."
    TARGETS+=("$target")
    status_line "$CYAN" 'Sélectionné' "$target"
  done
  (( missing == 0 )) || fatal "$missing paquet(s) introuvable(s). Aucune installation ; aucun recours à l'AUR."
}

step 2 'Examiner les paquets et leurs dépôts'
resolve_packages
info "${#PACKAGES[@]} paquets demandés. Les dépendances et mises à jour seront détaillées par Pacman."
warn 'La transaction met à jour tout le système et installe les paquets manquants.'
info 'Inventaire privé avant/après ; aucun nettoyage du cache.'
info 'Les Dotfiles, services, permissions utilisateur et réglages Niri ne sont pas configurés par ce script.'
info 'Les scripts et hooks propres aux paquets peuvent modifier le système pendant la transaction.'
printf 'Commande :'
printf ' %q' pacman -Syu --needed "${TARGETS[@]}"
printf '\n'
if $DRY_RUN; then
  step 3 'Bilan de la simulation'
  status_line "$CYAN" 'Simulation' 'Simulation terminée : aucun fichier écrit et aucune installation effectuée.'
  info 'Disponibilité constatée dans les bases locales ; versions finales vérifiées par la transaction réelle.'
  exit 0
fi

step 3 'Confirmer et lancer la transaction Pacman'
[[ -t 0 && -t 1 ]] || fatal 'Exécution réelle refusée sans terminal interactif. Utiliser --dry-run pour examiner.'
SUDO=()
if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || fatal 'sudo est nécessaire pour la transaction Pacman.'
  SUDO=(sudo)
fi
for tool in mktemp chmod; do
  command -v "$tool" >/dev/null 2>&1 || fatal "Commande requise absente : $tool."
done
warn 'Prévoir une sauvegarde ou un instantané pour un retour système complet.'
printf 'Autoriser la création de l’inventaire et la transaction décrite ? [o/N] '
IFS= read -r answer || fatal 'Confirmation non reçue.'
case "$answer" in
  o|O|oui|Oui|y|Y|yes) ;;
  *) info 'Installation annulée ; aucun fichier écrit.'; exit 0 ;;
esac

# Revalider après l'attente de confirmation, avant toute écriture.
PREVIEW_REPOS=$CONFIGURED_REPOS
PREVIEW_CONFIG=$CONFIG_EFFECTIVE
PREVIEW_TARGETS=$(printf '%s\n' "${TARGETS[@]}")
resolve_packages
[[ "$PREVIEW_REPOS" == "$CONFIGURED_REPOS" && "$PREVIEW_CONFIG" == "$CONFIG_EFFECTIVE" && "$PREVIEW_TARGETS" == "$(printf '%s\n' "${TARGETS[@]}")" ]] ||
  fatal 'Les dépôts ou les cibles ont changé. Relancer pour examiner le nouvel aperçu.'

umask 077
SNAPSHOT=$(mktemp -d /var/tmp/cachyos-packages.XXXXXXXX) || fatal 'Création du dossier d’inventaire impossible.'
chmod 700 "$SNAPSHOT"
pacman -Q > "$SNAPSHOT/paquets-avant.txt"
pacman -Qqe > "$SNAPSHOT/explicites-avant.txt"
# Une sélection sans paquet étranger peut renvoyer 1. Distinguer ce résultat
# d'une erreur de lecture accompagnée d'un diagnostic.
query_status=0
pacman -Qqm > "$SNAPSHOT/etrangers-avant.txt" 2> "$SNAPSHOT/diagnostic-etrangers.txt" || query_status=$?
if (( query_status != 0 )); then
  (( query_status == 1 )) && [[ ! -s "$SNAPSHOT/etrangers-avant.txt" && ! -s "$SNAPSHOT/diagnostic-etrangers.txt" ]] ||
    fatal 'Lecture des paquets étrangers impossible.'
fi
printf '%s\n' "$CONFIG_EFFECTIVE" > "$SNAPSHOT/pacman-conf-avant.txt"
printf '%s\n' "${TARGETS[@]}" > "$SNAPSHOT/cibles.txt"
cat > "$SNAPSHOT/LIRE-MOI.txt" <<'EOF'
Inventaire de la transaction CachyOS, pas une sauvegarde système.
paquets-avant.txt : noms et versions avant la transaction.
explicites-avant.txt : paquets installés explicitement avant la transaction.
etrangers-avant.txt : paquets absents des bases synchronisées au moment du relevé.
cibles.txt : cibles explicites dépôt/paquet demandées.
paquets-apres.txt : état après la tentative, si la lecture a réussi.
pacman-conf-avant.txt : configuration effective lors du relevé.

Pour diagnostiquer : comparer les inventaires et consulter /var/log/pacman.log
(ou le LogFile personnalisé dans pacman-conf-avant.txt).
Aucune commande automatique de suppression ou de rétrogradation n'est générée.
Un retour à une ancienne version doit tenir compte des dépendances et nécessite
des archives compatibles ou un instantané système existant.
Les fichiers personnels, configurations et services ne sont pas sauvegardés ici.
EOF
status_line "$VIOLET" 'Inventaire' "$SNAPSHOT"
TRANSACTION_STARTED=true
# Une transaction groupée, cibles attachées au dépôt, confirmations natives.
# Aucune synchronisation -Sy séparée susceptible de laisser une mise à jour partielle.
status=0
if [[ $EUID -eq 0 ]]; then
  pacman -Syu --needed "${TARGETS[@]}" || status=$?
else
  "${SUDO[@]}" pacman -Syu --needed "${TARGETS[@]}" || status=$?
fi
step 4 'Vérifier la transaction et afficher le bilan'
pacman -Q > "$SNAPSHOT/paquets-apres.txt" || fatal 'Lecture de l’état final impossible ; vérifier le journal Pacman.'
(( status == 0 )) || fatal 'La transaction Pacman a échoué ou a été annulée. Aucun succès annoncé.' "$status"

missing=0
new_count=0
for package in "${PACKAGES[@]}"; do
  if ! pacman -Q "$package" >/dev/null 2>&1; then
    error "Paquet demandé absent après la transaction : $package"
    missing=$((missing + 1))
    continue
  fi
  before_version=$(awk -v pkg="$package" '$1 == pkg {print $2; exit}' "$SNAPSHOT/paquets-avant.txt")
  after_version=$(awk -v pkg="$package" '$1 == pkg {print $2; exit}' "$SNAPSHOT/paquets-apres.txt")
  if [[ -z "$before_version" ]]; then new_count=$((new_count + 1)); fi
  if [[ -z "$after_version" ]]; then
    warn "$package présent, version absente de l’inventaire final."
  elif [[ -z "$before_version" ]]; then
    status_line "$GREEN" 'Installé' "$package · $after_version"
  elif [[ "$before_version" != "$after_version" ]]; then
    status_line "$GREEN" 'Version changée' "$package · $before_version → $after_version"
  else
    status_line "$BLUE" 'Inchangé' "$package · $after_version"
  fi
done
(( missing == 0 )) || fatal "$missing paquet(s) demandé(s) absent(s) après la transaction."
ok "Transaction terminée : ${#PACKAGES[@]} paquets demandés présents, dont $new_count nouvellement installés."
status_line "$VIOLET" 'Inventaires' "$SNAPSHOT"
info 'Les autres changements du système sont consignés par Pacman. Cache conservé.'
