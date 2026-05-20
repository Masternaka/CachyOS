#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
UPDATE_SYSTEM=true
CHANGE_SHELL=true
INSTALL_ALIASES=true
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC_FILE="${HOME}/.zshrc"
STARSHIP_CONFIG="${HOME}/.config/starship.toml"
OMZ_HOME="${HOME}/.oh-my-zsh"
ALIASES_SOURCE="${SCRIPT_DIR}/Configuration alias/aliases.zsh"
ALIASES_TARGET="${HOME}/.config/zsh/personal_aliases.zsh"


PACMAN_PACKAGES=(
  zsh
  ttf-jetbrains-mono-nerd
  starship
  zoxide
  fzf
  fd
  eza
  ripgrep
  bat
  git
  pacman-contrib
  reflector
  btop
  fastfetch
  expac
)

OMZ_PLUGINS=(
  git
  sudo
  colored-man-pages
)

OMZ_CUSTOM_PLUGINS=(
  zsh-users/zsh-completions
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
)


log_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
log_error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; }

fatal() {
  log_error "$1"
  exit 1
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Installe et configure zsh avec JetBrainsMono Nerd Font, Starship
Catppuccin Powerline, Oh My Zsh et une selection de plugins.

Options:
  --dry-run           Affiche les commandes sans les executer
  --no-update         Ne lance pas pacman -Syu avant l'installation
  --no-chsh           Ne change pas le shell par defaut vers zsh
  --no-aliases        N'installe pas le fichier d'alias personnel
  --zshrc FILE        Fichier .zshrc a modifier (defaut: ${ZSHRC_FILE})
  --starship FILE     Fichier starship.toml a ecrire (defaut: ${STARSHIP_CONFIG})
  --aliases FILE      Fichier d'alias a installer (defaut: ${ALIASES_SOURCE})
  --aliases-target FILE
                      Destination du fichier d'alias (defaut: ${ALIASES_TARGET})
  -h, --help          Affiche cette aide
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      --no-update)
        UPDATE_SYSTEM=false
        ;;
      --no-chsh)
        CHANGE_SHELL=false
        ;;
      --no-aliases)
        INSTALL_ALIASES=false
        ;;
      --zshrc)
        shift
        [[ $# -gt 0 ]] || fatal "Option --zshrc: fichier manquant"
        ZSHRC_FILE="$1"
        ;;
      --starship)
        shift
        [[ $# -gt 0 ]] || fatal "Option --starship: fichier manquant"
        STARSHIP_CONFIG="$1"
        ;;
      --aliases)
        shift
        [[ $# -gt 0 ]] || fatal "Option --aliases: fichier manquant"
        ALIASES_SOURCE="$1"
        ;;
      --aliases-target)
        shift
        [[ $# -gt 0 ]] || fatal "Option --aliases-target: fichier manquant"
        ALIASES_TARGET="$1"
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

check_prereqs() {
  if ! command -v pacman >/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      log_warn "pacman est introuvable; verification ignoree en dry-run"
    else
      fatal "pacman est introuvable"
    fi
  fi

  if ! command -v sudo >/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      log_warn "sudo est introuvable; verification ignoree en dry-run"
    else
      fatal "sudo est introuvable"
    fi
  fi

  if [[ "$DRY_RUN" == false ]]; then
    sudo -v || fatal "Impossible d'obtenir les droits sudo"
  fi
}

install_packages() {
  if [[ "$UPDATE_SYSTEM" == true ]]; then
    log_info "Mise a jour du systeme"
    run sudo pacman -Syu --noconfirm
  fi

  log_info "Installation des paquets zsh, Starship et outils CLI"
  run sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

install_oh_my_zsh() {
  if [[ -d "$OMZ_HOME" ]]; then
    log_info "Oh My Zsh est deja installe : $OMZ_HOME"
  else
    log_info "Installation de Oh My Zsh"
    run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_HOME"
  fi

  local plugin_url plugin_name
  for plugin_url in "${OMZ_CUSTOM_PLUGINS[@]}"; do
    plugin_name="${plugin_url##*/}"
    if [[ ! -d "$OMZ_HOME/custom/plugins/$plugin_name" ]]; then
      log_info "Installation du plugin custom Oh My Zsh : $plugin_name"
      run git clone --depth=1 "https://github.com/${plugin_url}.git" "$OMZ_HOME/custom/plugins/$plugin_name"
    fi
  done
}

configure_starship() {
  local starship_dir

  starship_dir="$(dirname -- "$STARSHIP_CONFIG")"
  log_info "Configuration de Starship avec le preset Catppuccin Powerline"
  run mkdir -p "$starship_dir"

  if [[ "$DRY_RUN" == true ]]; then
    printf '[DRY-RUN] starship preset catppuccin-powerline -o %q\n' "$STARSHIP_CONFIG"
    return
  fi

  starship preset catppuccin-powerline -o "$STARSHIP_CONFIG" \
    || fatal "Impossible d'appliquer le preset Starship catppuccin-powerline"
}

build_zsh_block() {
  local p plugins_list=""
  for p in "${OMZ_PLUGINS[@]}"; do
    plugins_list+=" $p"
  done
  for p in "${OMZ_CUSTOM_PLUGINS[@]}"; do
    plugins_list+=" ${p##*/}"
  done

  cat <<EOF
# >>> CachyOS zsh configuration >>>
export ZSH="${OMZ_HOME}"

# Le theme est laisse vide car nous utilisons Starship
ZSH_THEME=""

plugins=(${plugins_list})

fpath+=( \${ZSH}/custom/plugins/zsh-completions/src )

if [[ -f "\${ZSH}/oh-my-zsh.sh" ]]; then
  source "\${ZSH}/oh-my-zsh.sh"
else
  print -P "%F{yellow}[WARN]%f Oh My Zsh est introuvable : \${ZSH}"
fi

HISTFILE="\${ZDOTDIR:-\${HOME}}/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

# Options additionnelles de Zsh
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_silent
setopt correct
setopt interactive_comments
setopt no_beep

bindkey -e
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward

export BAT_THEME="Catppuccin Mocha"
export EZA_COLORS="uu=36:gu=37:da=34"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="\${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

if command -v zoxide >/dev/null && ! command -v z >/dev/null; then
  eval "\$(zoxide init zsh)"
fi

if command -v fzf >/dev/null; then
  [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
  [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
fi

eval "\$(starship init zsh)"
# <<< CachyOS zsh configuration <<<
EOF
}

configure_zshrc() {
  local zshrc_dir
  local backup_file
  local temp_file

  zshrc_dir="$(dirname -- "$ZSHRC_FILE")"
  log_info "Configuration de zsh dans: $ZSHRC_FILE"
  run mkdir -p "$zshrc_dir"

  if [[ "$DRY_RUN" == true ]]; then
    printf '[DRY-RUN] update managed block in %q\n' "$ZSHRC_FILE"
    return
  fi

  touch "$ZSHRC_FILE"

  if grep -q '# >>> CachyOS zsh configuration >>>' "$ZSHRC_FILE"; then
    backup_file="${ZSHRC_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$ZSHRC_FILE" "$backup_file"
    log_warn "Bloc zsh existant detecte; sauvegarde vers: $backup_file"

    temp_file="$(mktemp)"
    sed '/# >>> CachyOS zsh configuration >>>/,/# <<< CachyOS zsh configuration <<</d' "$ZSHRC_FILE" > "$temp_file"
    {
      cat "$temp_file"
      printf '\n'
      build_zsh_block
    } > "$ZSHRC_FILE"
    rm -f "$temp_file"
  else
    {
      printf '\n'
      build_zsh_block
    } >> "$ZSHRC_FILE"
  fi
}

install_aliases() {
  local alias_installer

  [[ "$INSTALL_ALIASES" == true ]] || return 0

  alias_installer="${SCRIPT_DIR}/Configuration alias/install-zsh-aliases.sh"
  [[ -f "$alias_installer" ]] || fatal "Script d'installation des alias introuvable: $alias_installer"
  [[ -f "$ALIASES_SOURCE" ]] || fatal "Fichier d'alias introuvable: $ALIASES_SOURCE"

  log_info "Installation des alias personnels"

  if [[ "$DRY_RUN" == true ]]; then
    run bash "$alias_installer" --dry-run --config "$ALIASES_SOURCE" --target "$ALIASES_TARGET" --zshrc "$ZSHRC_FILE"
  else
    bash "$alias_installer" --config "$ALIASES_SOURCE" --target "$ALIASES_TARGET" --zshrc "$ZSHRC_FILE"
  fi
}

change_default_shell() {
  local zsh_path

  [[ "$CHANGE_SHELL" == true ]] || return 0

  zsh_path="$(command -v zsh || true)"
  [[ -n "$zsh_path" ]] || fatal "zsh est introuvable apres installation"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log_info "zsh est deja le shell par defaut"
    return
  fi

  log_info "Changement du shell par defaut vers: $zsh_path"

  if ! grep -qxF "$zsh_path" /etc/shells; then
    run sudo sh -c 'printf "%s\n" "$1" >> /etc/shells' sh "$zsh_path"
  fi

  run chsh -s "$zsh_path"
}

main() {
  parse_args "$@"
  check_prereqs
  install_packages
  install_oh_my_zsh
  configure_starship
  configure_zshrc
  install_aliases
  change_default_shell

  log_info "Installation terminee. Ouvrez une nouvelle session zsh pour charger la configuration."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
