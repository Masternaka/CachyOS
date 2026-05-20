#!/usr/bin/env bash

# Script d'installation de Dotfiles avec GNU Stow
# Auteur : Antigravity (Gemini)
# Description : Clone/Met à jour vos configurations depuis GitHub et les déploie proprement
#               sur votre système en utilisant GNU Stow, avec gestion sécurisée des conflits.

set -Eeuo pipefail

# --- CONFIGURATION & PARAMÈTRES PAR DÉFAUT ---
DRY_RUN=false
FORCE=false
DEFAULT_REPO="https://github.com/Masternaka/dotfiles"
DOTFILES_DIR=""
BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Chemins de détection automatique de votre dépôt de dotfiles déjà cloné
DEFAULT_LOCAL_PATHS=(
  "${HOME}/Desktop/Github/dotfiles"
  "${HOME}/Github/dotfiles"
  "${HOME}/.dotfiles"
)

# --- UTILS DE JOURNALISATION (STYLE PREMIUM) ---
log_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[32m[SUCCESS]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
log_error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; }
fatal() {
  log_error "$1"
  exit 1
}

# --- AIDE & USAGE ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Installe vos fichiers dotfiles depuis votre dépôt GitHub en utilisant GNU Stow.

Options:
  -r, --repo URL      URL ou nom du dépôt GitHub (défaut: ${DEFAULT_REPO})
  -d, --dir PATH      Chemin local du dossier dotfiles (si déjà cloné)
  -b, --backup PATH   Dossier de sauvegarde (défaut: ~/.dotfiles_backup/YYYYMMDD_HHMMSS)
  --dry-run, -n       Simule toutes les actions sans écrire sur le disque (mode simulation)
  --force, -f         Force le déploiement de tous les paquets sans demande interactive
  -h, --help          Affiche cette aide

Description:
  Ce script détecte votre dépôt dotfiles existant ou le télécharge, vérifie 
  l'installation de GNU Stow (et propose de l'installer si absent), analyse les 
  conflits de fichiers locaux, effectue des sauvegardes préventives, et applique 
  les liens symboliques proprement avec Stow.
EOF
}

# --- PARSING DES ARGUMENTS ---
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--repo)
        shift
        [[ $# -gt 0 ]] || fatal "Option --repo: valeur manquante"
        DEFAULT_REPO="$1"
        ;;
      -d|--dir)
        shift
        [[ $# -gt 0 ]] || fatal "Option --dir: chemin manquant"
        DOTFILES_DIR="$1"
        ;;
      -b|--backup)
        shift
        [[ $# -gt 0 ]] || fatal "Option --backup: chemin manquant"
        BACKUP_DIR="$1"
        ;;
      --dry-run|-n)
        DRY_RUN=true
        ;;
      --force|-f)
        FORCE=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        fatal "Option inconnue: $1"
        ;;
      *)
        fatal "Argument inattendu: $1"
        ;;
    esac
    shift
  done
}

# --- VÉRIFICATION & INSTALLATION DE GNU STOW ---
check_and_install_stow() {
  if command -v stow >/dev/null 2>&1; then
    log_success "GNU Stow est déjà installé sur le système."
    return 0
  fi

  log_warn "GNU Stow n'est pas installé sur ce système."

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[SIMULATION] GNU Stow serait installé automatiquement via le gestionnaire de paquets."
    return 0
  fi

  # Détecter le système d'exploitation et le gestionnaire de paquets
  if command -v pacman >/dev/null 2>&1; then
    log_info "Détection de CachyOS / Arch Linux. Installation de stow via pacman..."
    sudo pacman -S --noconfirm stow || fatal "Échec de l'installation de stow avec pacman."
  elif command -v brew >/dev/null 2>&1; then
    log_info "Détection de macOS. Installation de stow via Homebrew..."
    brew install stow || fatal "Échec de l'installation de stow avec Homebrew."
  elif command -v apt-get >/dev/null 2>&1; then
    log_info "Détection de Debian/Ubuntu. Installation de stow via apt..."
    sudo apt-get update && sudo apt-get install -y stow || fatal "Échec de l'installation de stow."
  elif command -v dnf >/dev/null 2>&1; then
    log_info "Détection de Fedora. Installation de stow via dnf..."
    sudo dnf install -y stow || fatal "Échec de l'installation de stow."
  else
    fatal "Aucun gestionnaire de paquets compatible n'a été détecté. Veuillez installer 'stow' manuellement."
  fi
  
  log_success "GNU Stow installé avec succès."
}

# --- DÉTECTION OU CLONAGE DU DÉPÔT ---
locate_dotfiles() {
  # Si un dossier a été manuellement passé en paramètre
  if [[ -n "$DOTFILES_DIR" ]]; then
    # Résoudre le chemin relatif ou absolu
    DOTFILES_DIR="$(cd "$DOTFILES_DIR" && pwd)"
    if [[ -d "$DOTFILES_DIR" ]]; then
      log_info "Dossier dotfiles spécifié manuellement : $DOTFILES_DIR"
      return 0
    else
      fatal "Le dossier dotfiles spécifié n'existe pas : $DOTFILES_DIR"
    fi
  fi

  # Rechercher dans les chemins par défaut
  for path in "${DEFAULT_LOCAL_PATHS[@]}"; do
    local resolved_path="${path/#\~/$HOME}"
    if [[ -d "$resolved_path" ]]; then
      DOTFILES_DIR="$resolved_path"
      log_success "Dossier dotfiles local détecté dans : $DOTFILES_DIR"
      
      # Mettre à jour si c'est un dépôt Git
      if [[ -d "$DOTFILES_DIR/.git" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
          log_info "[SIMULATION] git pull serait lancé dans $DOTFILES_DIR pour mettre à jour les fichiers."
        else
          printf "\nVotre dépôt local a été détecté. Voulez-vous le mettre à jour (git pull) ? [y/N] "
          read -r answer
          if [[ "$answer" =~ ^[Yy] ]]; then
            log_info "Mise à jour du dépôt en cours..."
            (cd "$DOTFILES_DIR" && git pull) || log_warn "Échec du git pull. Poursuite avec la version locale existante."
          fi
        fi
      fi
      return 0
    fi
  done

  # Si aucun dépôt local n'est détecté, procéder au clonage
  log_warn "Aucun dossier dotfiles local détecté dans vos dossiers habituels."
  local target_clone="${HOME}/.dotfiles"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[SIMULATION] Le dépôt distant $DEFAULT_REPO serait cloné dans : $target_clone"
    
    # Pour la simulation, on va cloner temporairement pour pouvoir analyser les paquets réels !
    DOTFILES_DIR="$(mktemp -d -t dotfiles-dryrun-XXXXXX)"
    log_info "Téléchargement temporaire de la structure du dépôt pour analyse..."
    git clone --depth 1 "$DEFAULT_REPO" "$DOTFILES_DIR" >/dev/null 2>&1 || {
      rm -rf "$DOTFILES_DIR"
      fatal "Impossible de récupérer le dépôt pour analyse. Vérifiez l'adresse ou votre connexion."
    }
    trap 'rm -rf "$DOTFILES_DIR"' EXIT
    return 0
  fi

  printf "\nVoulez-vous cloner le dépôt GitHub (%s) dans %s ? [Y/n] " "$DEFAULT_REPO" "$target_clone"
  read -r answer
  if [[ "$answer" =~ ^[Nn] ]]; then
    fatal "Opération annulée. Utilisez --dir pour spécifier le chemin de votre dépôt."
  fi

  log_info "Clonage du dépôt..."
  git clone "$DEFAULT_REPO" "$target_clone" || fatal "Échec du clonage du dépôt."
  DOTFILES_DIR="$target_clone"
  log_success "Dépôt cloné avec succès dans : $DOTFILES_DIR"
}

# --- CHOIX DES PAQUETS DE CONFIGURATION ---
select_packages() {
  local pkgs=()
  
  # Parcourir les dossiers du dépôt (Stow requiert des dossiers par paquet)
  while IFS= read -r -d '' dir; do
    local base
    base="$(basename "$dir")"
    # Exclure les dossiers système git et d'éventuels fichiers d'aide ou de config du dépôt
    if [[ ! "$base" =~ ^\. ]] && [[ "$base" != "README.md" ]] && [[ "$base" != "LICENSE" ]] && [[ "$base" != "ToDO.md" ]]; then
      pkgs+=("$base")
    fi
  done < <(find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    fatal "Aucun paquet de configuration détecté à la racine de $DOTFILES_DIR. Stow nécessite une structure en dossiers."
  fi

  # Mode force ou interactif
  SELECTED_PACKAGES=()
  if [[ "$FORCE" == true ]]; then
    SELECTED_PACKAGES=("${pkgs[@]}")
    log_info "Option --force activée : tous les paquets détectés seront traités."
    return 0
  fi

  log_info "Paquets de configurations détectés dans votre dépôt (${#pkgs[@]}) :"
  local col=0
  for i in "${!pkgs[@]}"; do
    printf '  %2d) \033[36m%-16s\033[0m' "$((i+1))" "${pkgs[i]}"
    col=$((col+1))
    if [[ $col -eq 4 ]]; then
      printf '\n'
      col=0
    fi
  done
  if [[ $col -ne 0 ]]; then
    printf '\n'
  fi

  printf "\nSélectionnez les paquets à installer (ex: 1 3 5), saisissez 'all' pour tout installer, ou Entrée pour quitter : "
  read -r choice

  if [[ -z "$choice" ]]; then
    log_info "Aucune sélection effectuée. Sortie."
    exit 0
  fi

  if [[ "$choice" == "all" ]]; then
    SELECTED_PACKAGES=("${pkgs[@]}")
  else
    for num in $choice; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -le "${#pkgs[@]}" ]] && [[ "$num" -gt 0 ]]; then
        SELECTED_PACKAGES+=("${pkgs[$((num-1))]}")
      else
        log_warn "Choix invalide ignoré : $num"
      fi
    done
  fi

  if [[ ${#SELECTED_PACKAGES[@]} -eq 0 ]]; then
    fatal "Aucun paquet valide n'a été sélectionné."
  fi

  log_info "Déploiement des paquets suivants : ${SELECTED_PACKAGES[*]}"
}

# --- ANALYSE ET SAUVEGARDE DES CONFLITS ---
backup_conflicts() {
  local pkg="$1"
  local pkg_dir="$DOTFILES_DIR/$pkg"
  local backup_created=false

  # Parcourir récursivement tous les fichiers et dossiers du paquet
  while IFS= read -r -d '' item; do
    [[ "$item" == "$pkg_dir" ]] && continue

    # Calculer le chemin de destination relatif à la maison de l'utilisateur
    local rel_path="${item#$pkg_dir/}"
    local target_path="${HOME}/${rel_path}"

    if [[ -e "$target_path" || -L "$target_path" ]]; then
      # Cas 1 : C'est déjà un lien symbolique
      if [[ -L "$target_path" ]]; then
        local link_target
        link_target="$(readlink "$target_path" 2>/dev/null || true)"
        
        # Si le lien pointe déjà sur notre dépôt de dotfiles, on n'a rien à faire
        if [[ "$link_target" == "$item" ]]; then
          continue
        fi

        # Si c'est un lien symbolique obsolète ou pointant ailleurs, on le supprime
        if [[ "$DRY_RUN" == true ]]; then
          log_info "  [DRY-RUN] Le lien obsolète serait supprimé : $target_path (pointait vers $link_target)"
        else
          log_warn "  Lien symbolique obsolète détecté pour $rel_path. Suppression..."
          rm "$target_path"
        fi

      # Cas 2 : C'est un vrai fichier
      elif [[ -f "$target_path" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
          log_info "  [DRY-RUN] Sauvegarde du fichier : $target_path -> $BACKUP_DIR/$rel_path"
        else
          if [[ "$backup_created" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            backup_created=true
            log_info "  Création du dossier de sauvegarde : $BACKUP_DIR"
          fi
          log_warn "  Fichier existant détecté pour $rel_path. Sauvegarde..."
          mkdir -p "$(dirname "$BACKUP_DIR/$rel_path")"
          mv "$target_path" "$BACKUP_DIR/$rel_path"
        fi

      # Cas 3 : C'est un dossier (conflit potentiel de type)
      elif [[ -d "$target_path" ]]; then
        # Si la source dans le dépôt est un fichier, on doit sauvegarder le dossier
        if [[ -f "$item" ]]; then
          if [[ "$DRY_RUN" == true ]]; then
            log_info "  [DRY-RUN] Sauvegarde du dossier (conflit de type) : $target_path -> $BACKUP_DIR/$rel_path"
          else
            if [[ "$backup_created" == false ]]; then
              mkdir -p "$BACKUP_DIR"
              backup_created=true
              log_info "  Création du dossier de sauvegarde : $BACKUP_DIR"
            fi
            log_warn "  Dossier existant en conflit avec un fichier pour $rel_path. Sauvegarde..."
            mkdir -p "$(dirname "$BACKUP_DIR/$rel_path")"
            mv "$target_path" "$BACKUP_DIR/$rel_path"
          fi
        fi
        # Si source et destination sont des dossiers, on laisse Stow faire la fusion
      fi
    fi
  done < <(find "$pkg_dir" -print0)
}

# --- PROCESSUS DE DÉPLOIEMENT ---
deploy_packages() {
  local success_count=0
  local fail_count=0

  log_info "Début du traitement des paquets de configuration..."

  for pkg in "${SELECTED_PACKAGES[@]}"; do
    printf '\n'
    log_info "Traitement du paquet : \033[36m$pkg\033[0m"

    # Étape 1 : Gérer les conflits et sauvegarder
    backup_conflicts "$pkg"

    # Étape 2 : Exécuter Stow
    if [[ "$DRY_RUN" == true ]]; then
      log_info "  [DRY-RUN] Exécution de: stow -v -R -t ~ -d $DOTFILES_DIR $pkg"
      if command -v stow >/dev/null 2>&1; then
        # Afficher la simulation native de stow
        stow -n -v -R -t "$HOME" -d "$DOTFILES_DIR" "$pkg" 2>&1 | while read -r line; do
          log_info "    (stow-sim) $line"
        done
      else
        log_info "    (stow-sim) stow créerait les liens symboliques correspondants pour le paquet $pkg."
      fi
      success_count=$((success_count + 1))
    else
      # Déploiement réel
      if stow -v -R -t "$HOME" -d "$DOTFILES_DIR" "$pkg" 2>&1; then
        log_success "  Paquet '$pkg' déployé avec succès !"
        success_count=$((success_count + 1))
      else
        log_error "  Échec du déploiement pour le paquet '$pkg'."
        fail_count=$((fail_count + 1))
      fi
    fi
  done

  # --- RAPPORT FINAL ---
  printf '\n'
  if [[ "$DRY_RUN" == true ]]; then
    log_success "--- SIMULATION TERMINÉE ---"
    log_info "Aucune modification n'a été écrite sur le disque."
    log_info "Total : $success_count paquets simulés avec succès."
  else
    log_success "--- INSTALLATION TERMINÉE ---"
    log_info "Rapport : Réussis = $success_count, Échecs = $fail_count"
    if [[ -d "$BACKUP_DIR" ]]; then
      log_info "Les anciennes configurations en conflit ont été déplacées dans : $BACKUP_DIR"
    fi
  fi
}

# --- FONCTION PRINCIPALE ---
main() {
  parse_args "$@"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_info "--- MODE SIMULATION (DRY-RUN) ACTIF ---"
  fi

  check_and_install_stow
  locate_dotfiles
  select_packages
  deploy_packages
}

main "$@"
