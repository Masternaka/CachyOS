#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=false
UPDATE_SYSTEM=true
CHANGE_SHELL=true
ZSHRC_FILE="${HOME}/.zshrc"
STARSHIP_CONFIG="${HOME}/.config/starship.toml"
ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git}"

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
)

ZINIT_PLUGINS=(
  zsh-users/zsh-completions
  zsh-users/zsh-autosuggestions
  fdellwing/zsh-bat
  unixorn/fzf-zsh-plugin
  z-shell/zsh-zoxide
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
Catppuccin Powerline, zinit et une selection de plugins.

Options:
  --dry-run           Affiche les commandes sans les executer
  --no-update         Ne lance pas pacman -Syu avant l'installation
  --no-chsh           Ne change pas le shell par defaut vers zsh
  --zshrc FILE        Fichier .zshrc a modifier (defaut: ${ZSHRC_FILE})
  --starship FILE     Fichier starship.toml a ecrire (defaut: ${STARSHIP_CONFIG})
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
  command -v pacman >/dev/null || fatal "pacman est introuvable"
  command -v sudo >/dev/null || fatal "sudo est introuvable"

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

install_zinit() {
  if [[ -d "$ZINIT_HOME/.git" ]]; then
    log_info "zinit est deja installe: $ZINIT_HOME"
    return
  fi

  log_info "Installation de zinit"
  run mkdir -p "$(dirname -- "$ZINIT_HOME")"
  run git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
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
  local plugin

  cat <<EOF
# >>> CachyOS zsh configuration >>>
export ZINIT_HOME="${ZINIT_HOME}"

HISTFILE="\${ZDOTDIR:-\${HOME}}/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt inc_append_history
setopt share_history

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

if [[ -f "\${ZINIT_HOME}/zinit.zsh" ]]; then
  source "\${ZINIT_HOME}/zinit.zsh"
  autoload -Uz _zinit
  (( \${+_comps} )) && _comps[zinit]=_zinit

EOF

  for plugin in "${ZINIT_PLUGINS[@]}"; do
    printf '  zinit light %s\n' "$plugin"
  done

  cat <<'EOF'
else
  print -P "%F{yellow}[WARN]%f zinit est introuvable: ${ZINIT_HOME}/zinit.zsh"
fi

autoload -Uz compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:warnings' format 'Aucune completion pour %d'
zmodload zsh/complist

mkdir -p "${XDG_CACHE_HOME:-${HOME}/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/zcompdump-${ZSH_VERSION}"

if command -v zoxide >/dev/null && ! command -v z >/dev/null; then
  eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null; then
  [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
  [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
fi

eval "$(starship init zsh)"
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

change_default_shell() {
  local zsh_path

  [[ "$CHANGE_SHELL" == true ]] || return

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
  install_zinit
  configure_starship
  configure_zshrc
  change_default_shell

  log_info "Installation terminee. Ouvrez une nouvelle session zsh pour charger la configuration."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
