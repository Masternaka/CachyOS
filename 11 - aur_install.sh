#!/usr/bin/env bash
# Installation AUR volontaire, depuis un compte normal sur CachyOS.
# Ne jamais sourcer un PKGBUILD : c'est du code qui peut modifier le compte.
set -euo pipefail

# Bilan commun ; conserver le dossier scripts/ à côté de ce fichier.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/scripts/bilan.sh"
bilan_init "11 · Paquets AUR" "$@"
export LC_ALL=C

PACKAGES=(
  t3code-bin
  herdr-bin
  orca-ide-bin
  gitkraken
)
MODE=--dry-run
RUN_DIR=''

fatal() { bilan_erreur "$*"; printf 'Erreur : %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'HELP'
Usage : bash "11 - aur_install.sh" [--dry-run | --install | --list | --help]

Sans option / --dry-run : contrôles locaux en lecture seule et aperçu.
  Aucun réseau, fichier créé, téléchargement, sudo ou installation.
--list : afficher les quatre paquets, même hors de CachyOS.
--install : demander confirmation avant le réseau et les écritures, puis
  afficher les informations AUR et installer chaque paquet après accord.

Prérequis déjà installés : Paru, Pacman, pacman-conf, base-devel, Git,
makepkg et sudo. Le script ne les installe pas.
Préparer séparément une mise à jour complète et une sauvegarde système.
Voir docs/aur-install.md pour la revue et le retour arrière.
HELP
}

confirm() {
  local expected=$1 answer
  printf '\nPour continuer, saisir exactement « %s » : ' "$expected"
  IFS= read -r answer || { bilan_annule 'Confirmation non reçue.'; fatal 'Lecture interrompue ; arrêt.'; }
  [[ "$answer" == "$expected" ]] || { bilan_annule 'Confirmation refusée.'; fatal 'Confirmation refusée ; arrêt.'; }
}

check_target() {
  local tool repos repo names package database
  [[ "$(uname -s)" == Linux ]] || fatal 'Ce contrôle nécessite la machine CachyOS cible.'
  [[ -r /etc/os-release ]] || fatal '/etc/os-release absent.'
  # Lecture de texte seulement : ne pas exécuter /etc/os-release.
  grep -Eq '^ID=(cachyos|"cachyos")$' /etc/os-release || fatal 'CachyOS non détecté.'
  (( EUID != 0 )) || fatal 'Ne pas utiliser sudo pour lancer ce script.'
  for tool in paru pacman pacman-conf git makepkg sudo awk grep mktemp; do
    command -v "$tool" >/dev/null 2>&1 || fatal "Prérequis manquant : $tool (installation séparée nécessaire)."
  done
  pacman -Q base-devel git >/dev/null || fatal 'base-devel et git doivent être déjà installés.'
  database=$(pacman-conf DBPath) || fatal 'Lecture de DBPath impossible.'
  [[ -n "$database" && -d "$database" ]] || fatal 'Base Pacman absente.'
  [[ ! -e "${database%/}/db.lck" ]] || fatal 'Pacman est occupé ; ne pas supprimer son verrou.'
  repos=$(pacman-conf --repo-list) || fatal 'Lecture des dépôts impossible.'
  [[ -n "$repos" ]] || fatal 'Aucun dépôt configuré.'
  printf '\nDépôts configurés :\n%s\n' "$repos"
  # Une dépendance peut provenir de tout dépôt activé. Refuser les tiers/tests.
  while IFS= read -r repo; do
    case "$repo" in
      core|extra|multilib|cachyos|cachyos-v3|cachyos-v4|cachyos-extra-v3|cachyos-extra-v4|cachyos-core-v3|cachyos-core-v4) ;;
      *) fatal "Dépôt non autorisé pour ce script : $repo. Examiner sa provenance séparément." ;;
    esac
  done <<< "$repos"
  # -Sl consulte uniquement les bases locales ; pas de -Sy isolé.
  names=$(pacman -Sl) || fatal 'Lecture des bases synchronisées impossible.'
  [[ -n "$names" ]] || fatal 'Bases synchronisées vides : mettre le système à jour séparément.'
  names=$(awk '{print $2}' <<< "$names")
  for package in "${PACKAGES[@]}"; do
    if grep -Fxq "$package" <<< "$names"; then
      fatal "$package existe dans un dépôt configuré : privilégier celui-ci et revoir la sélection AUR."
    fi
  done
  printf '\nAucun des quatre noms trouvé dans les bases locales.\n'
  printf 'Ces bases peuvent être anciennes ; vérifier aussi https://packages.cachyos.org/\n'
}

# Une configuration Paru neutre évite SkipReview, les outils substitués,
# les MFlags de contournement et les dépôts PKGBUILD personnels.
# PARU_CONF est une variable documentée de Paru ; --config vise Pacman.
run_paru() { PARU_CONF=/dev/null paru "$@"; }

finish() {
  local result=$?
  trap - EXIT
  if [[ -n "$RUN_DIR" ]]; then
    if ! pacman -Q > "$RUN_DIR/paquets-apres.txt"; then
      bilan_erreur 'Inventaire final incomplet.'
      printf 'Attention : inventaire final incomplet.\n' >&2
      result=1
    fi
    printf '\nDossier de suivi conservé : %s\n' "$RUN_DIR"
    printf 'Une interruption ne désinstalle pas les paquets déjà installés.\n'
    printf 'Ce dossier temporaire ne remplace pas une sauvegarde système.\n'
  fi
  bilan_print "$result"
  exit "$result"
}

(( $# <= 1 )) || fatal 'Une seule option est acceptée ; voir --help.'
if (( $# == 1 )); then MODE=$1; fi
case "$MODE" in
  --help|-h) usage; exit 0 ;;
  --list) printf '%s\n' "${PACKAGES[@]}"; exit 0 ;;
  --dry-run|--install) ;;
  *) fatal "Option inconnue : $MODE ; voir --help." ;;
esac

printf 'Paquets AUR prévus :\n'
printf '  %s\n' "${PACKAGES[@]}"
check_target
cat <<'PLAN'

L'installation contactera l'AUR et les serveurs des sources, téléchargera les
recettes et les logiciels, puis pourra installer des dépendances et des paquets
avec sudo via Paru/Pacman. Les recettes s'exécutent avec les droits du compte ;
les scripts d'installation et les hooks Pacman peuvent s'exécuter comme root.
Les paquets -bin contiennent des binaires précompilés à évaluer eux aussi.

Avant de continuer : vérifier le catalogue CachyOS, terminer une mise à jour
complète du système et disposer d'une sauvegarde ou d'un instantané restaurable.
Aucune mise à jour système ni sauvegarde complète n'est effectuée ici.

Pour chaque paquet ET ses dépendances AUR, examiner :
  - mainteneur, dates, signalement obsolète, commentaires et historique AUR ;
  - PKGBUILD, fichiers .install, patchs et autres fichiers de la recette ;
  - domaines des sources et correspondance avec le site de l'éditeur ;
  - sommes de contrôle, entrées SKIP et signatures PGP si disponibles ;
  - commandes exécutées et modifications hors des répertoires de construction.
Une somme correcte n'établit pas la fiabilité du logiciel ou du mainteneur.
Ne pas accepter une clé inconnue ou un conflit sans comprendre sa provenance.
Refuser dans Paru ou interrompre avec Ctrl+C en cas de doute.
PLAN

if [[ "$MODE" == --dry-run ]]; then
  printf '\nAperçu terminé. Aucun accès AUR ni contrôle des recettes effectué.\n'
  printf 'Installation volontaire : bash "11 - aur_install.sh" --install\n'
  exit 0
fi

[[ -t 0 && -t 1 ]] || fatal 'Un terminal interactif est obligatoire.'
confirm 'DEPOTS VERIFIES, SYSTEME A JOUR ET SAUVEGARDE PRETE'
# Nouvelle lecture après l'attente et avant la première écriture.
check_target
umask 077
RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cachyos-aur.XXXXXXXX") || fatal 'Création du dossier de suivi impossible.'
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'Dossier de suivi : %s\n' "$RUN_DIR"
pacman -Q > "$RUN_DIR/paquets-avant.txt"
pacman -Qqe > "$RUN_DIR/explicites-avant.txt"
pacman-conf > "$RUN_DIR/pacman-conf-avant.txt"
printf '%s\n' "${PACKAGES[@]}" > "$RUN_DIR/cibles.txt"

# Résoudre tous les noms avant de commencer la première installation.
# Les informations ne sont pas une analyse de sécurité et peuvent évoluer.
for package in "${PACKAGES[@]}"; do
  printf '\nInformations AUR : %s\n' "$package"
  if ! run_paru -Si --aur "$package" > "$RUN_DIR/$package-info.txt"; then
    fatal "Informations AUR indisponibles pour $package ; aucune installation commencée."
  fi
  cat "$RUN_DIR/$package-info.txt"
done

for package in "${PACKAGES[@]}"; do
  printf '\nPage à examiner : https://aur.archlinux.org/packages/%s\n' "$package"
  printf 'Paru présentera ensuite les recettes et la transaction avec ses confirmations.\n'
  confirm "EXAMINER $package"
  check_target
  # Dossier neuf : éviter une ancienne recette modifiée ou déjà approuvée.
  # --review impose la revue ; --confirm garde les questions de Pacman.
  # Aucun --skipchecksums, --skippgpcheck, --noconfirm ou --overwrite.
  before_state=$(pacman -Q "$package" 2>/dev/null) || before_state=''
  bilan_debut
  if ! run_paru -S --aur --needed --review --confirm --noremovemake \
      --clonedir "$RUN_DIR/build-$package" "$package"; then
    fatal "Échec ou refus pour $package ; arrêt du lot, sans retour arrière automatique."
  fi
  after_state=$(pacman -Q "$package") || fatal "$package absent après le retour de Paru."
  printf '%s\n' "$after_state"
  if [[ "$before_state" == "$after_state" ]]; then
    bilan_ignore "$package : version déjà présente ($after_state)."
  else
    bilan_action "$package : présence finale vérifiée ($after_state)."
  fi
done
bilan_note 'La présence des paquets ne garantit pas leur sécurité ; le dossier de suivi est temporaire.'
printf '\nLes quatre paquets sont présents. Cela ne valide pas leur sécurité.\n'
