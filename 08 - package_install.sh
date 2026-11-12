#!/usr/bin/env bash
# Installation de paquets depuis les dépôts officiels utilisés par CachyOS.
# Aucun appel à l'AUR, aucun ajout de dépôt ni déploiement des Dotfiles.
set -euo pipefail
export LC_ALL=C

DRY_RUN=false
LIST_ONLY=false
SNAPSHOT=''
TRANSACTION_STARTED=false

PACKAGES=(

      # Intégration Wayland (notamment Niri)
      #qt5-wayland
      qt6-wayland

      # Utilitaires
      catfish
      flameshot
      gnome-disk-utility
      gparted
      openrgb
      qbittorrent
      transmission-qt
      lshw
      fwupd
      #timeshift
      7zip
      #stow

      # Polices
      ttf-jetbrains-mono-nerd
      ttf-meslo-nerd
      ttf-firacode-nerd

      # Paquets de langue
      firefox-i18n-fr
      thunderbird-i18n-fr

      # Sécurité
      #keepassxc
      bitwarden

      # Navigateur internet et email
      firefox
      thunderbird
      #vivaldi
      #vivaldi-ffmpeg-codecs
      brave-bin
      #brave-origin-bin
      #helium-browser-bin
      #zen-browser-bin

      # Multimédia
      strawberry
      #vlc
      mpv

      # Communication
      #discord
      vesktop-bin

      # Office et notes
      libreoffice-fresh
      libreoffice-fresh-fr
      obsidian

      # Virtualisation
      qemu-full
      swtpm
      virt-manager
      distrobox
      podman

      # Terminal
      kitty
      foot
      ghostty

      # Utilitaires terminal
      #btop
      fastfetch
      tealdeer # Même client que dans 04 - install_zsh.sh
      git
      curl
      wget
      #yazi

      # Développement
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

      # AI
      openai-codex
      claude-desktop
      claude-code

  )

info() { printf '%s\n' "$*"; }
fatal() { printf 'Erreur : %s\n' "$1" >&2; exit "${2:-1}"; }

show_help() {
  cat <<'EOF'
Usage : bash "08 - package_install.sh" [--help | --list | --dry-run]

  --help, -h   Afficher cette aide, sans privilèges ni contrôle système.
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

for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help; exit 0 ;;
    --list) LIST_ONLY=true ;;
    --dry-run) DRY_RUN=true ;;
    *) fatal "Option inconnue : $arg. Utiliser --help." 2 ;;
  esac
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
      printf '  INTROUVABLE : %s\n' "$package" >&2
      missing=$((missing + 1))
      continue
    fi
    allowed_repository "${target%%/*}" || fatal "Source non autorisée : $target."
    TARGETS+=("$target")
    printf '  %s\n' "$target"
  done
  (( missing == 0 )) || fatal "$missing paquet(s) introuvable(s). Aucune installation ; aucun recours à l'AUR."
}

resolve_packages
info ''
info "${#PACKAGES[@]} paquets demandés. Les dépendances et mises à jour seront détaillées par Pacman."
info 'Action : mise à jour complète du système et installation des paquets manquants.'
info 'Inventaire privé avant/après ; aucun nettoyage du cache.'
info 'Les Dotfiles, services, permissions utilisateur et réglages Niri ne sont pas configurés par ce script.'
info 'Les scripts et hooks propres aux paquets peuvent modifier le système pendant la transaction.'
printf 'Commande :'
printf ' %q' pacman -Syu --needed "${TARGETS[@]}"
printf '\n'
if $DRY_RUN; then
  info 'Simulation terminée : aucun fichier écrit et aucune installation effectuée.'
  info 'Disponibilité constatée dans les bases locales ; versions finales vérifiées par la transaction réelle.'
  exit 0
fi

[[ -t 0 && -t 1 ]] || fatal 'Exécution réelle refusée sans terminal interactif. Utiliser --dry-run pour examiner.'
SUDO=()
if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || fatal 'sudo est nécessaire pour la transaction Pacman.'
  SUDO=(sudo)
fi
for tool in mktemp chmod; do
  command -v "$tool" >/dev/null 2>&1 || fatal "Commande requise absente : $tool."
done
info 'Une mise à jour ne peut pas être annulée avec une simple liste de paquets.'
info 'Pour un retour système complet, prévoir une sauvegarde ou un instantané avant de continuer.'
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
info "Inventaire avant transaction : $SNAPSHOT"
TRANSACTION_STARTED=true
# Une transaction groupée, cibles attachées au dépôt, confirmations natives.
# Aucune synchronisation -Sy séparée susceptible de laisser une mise à jour partielle.
status=0
if [[ $EUID -eq 0 ]]; then
  pacman -Syu --needed "${TARGETS[@]}" || status=$?
else
  "${SUDO[@]}" pacman -Syu --needed "${TARGETS[@]}" || status=$?
fi
pacman -Q > "$SNAPSHOT/paquets-apres.txt" || fatal 'Lecture de l’état final impossible ; vérifier le journal Pacman.'
(( status == 0 )) || fatal 'La transaction Pacman a échoué ou a été annulée. Aucun succès annoncé.' "$status"

missing=0
new_count=0
for package in "${PACKAGES[@]}"; do
  if ! pacman -Q "$package" >/dev/null 2>&1; then
    printf 'Paquet demandé absent après la transaction : %s\n' "$package" >&2
    missing=$((missing + 1))
  elif ! awk -v pkg="$package" '$1 == pkg {found=1} END {exit !found}' "$SNAPSHOT/paquets-avant.txt"; then
    new_count=$((new_count + 1))
  fi
done
(( missing == 0 )) || fatal "$missing paquet(s) demandé(s) absent(s) après la transaction."
info "Transaction terminée : ${#PACKAGES[@]} paquets demandés présents, dont $new_count nouvellement installés."
info "Inventaires et versions avant/après : $SNAPSHOT"
info 'Les autres changements du système sont consignés par Pacman. Cache conservé.'

