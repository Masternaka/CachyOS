# =============================================================================
# ~/.zshrc — CachyOS, extensions locales sans gestionnaire de plugins
# Paquet Stow autonome. Personnalisation : ~/.zshrc.local.pre et ~/.zshrc.local.
# Aucun téléchargement ni mise à jour n'est lancé à l'ouverture du terminal.
# =============================================================================

# --- Surcharges et réglages des paquets Stow ----------------------------------
# Valeurs par défaut de l'installateur ; le fichier local précoce reste prioritaire.
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/cachyos-zsh/install-settings.zsh" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/cachyos-zsh/install-settings.zsh"
fi
# Le fichier précoce permet de choisir FZF, les alias, Starship et le chemin fzf-tab.
if [[ -r "$HOME/.zshrc.local.pre" ]]; then source "$HOME/.zshrc.local.pre"; fi
for _cachyos_tool in fzf zoxide eza; do
    _cachyos_settings="${XDG_CONFIG_HOME:-$HOME/.config}/$_cachyos_tool/config.zsh"
    if [[ -r "$_cachyos_settings" ]]; then source "$_cachyos_settings"; fi
done
unset _cachyos_tool _cachyos_settings
if [[ -z ${RIPGREP_CONFIG_PATH+x} && -r "${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/config" ]]; then
    export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/config"
fi

# --- Completions -------------------------------------------------------------
# zsh-completions est fourni par Pacman dans ce répertoire.
if [[ -d /usr/share/zsh/site-functions ]]; then
    typeset -U fpath
    fpath=(/usr/share/zsh/site-functions $fpath)
fi
autoload -Uz compinit
compinit -d "${ZDOTDIR:-$HOME}/.zcompdump"

# --- Options zsh -------------------------------------------------------------
setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="${HOME}/.zsh_history"

# --- Intégrations natives FZF et Zoxide --------------------------------------
if (( $+commands[fzf] )); then
    eval "$(fzf --zsh)"
fi

# --- Complétions Tab avec FZF, après compinit et avant les autres widgets ------
# Recherche locale uniquement : aucun téléchargement ni gestionnaire de plugins.
typeset -g _cachyos_fzf_tab_source=${CACHYOS_ZSH_FZF_TAB_SOURCE:-}
if [[ -z "$_cachyos_fzf_tab_source" ]]; then
    for _cachyos_candidate in \
        /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh \
        /usr/share/fzf-tab/fzf-tab.plugin.zsh \
        /usr/share/zsh/site-functions/fzf-tab.plugin.zsh \
        "${XDG_DATA_HOME:-$HOME/.local/share}/cachyos-zsh/fzf-tab-v1.3.0/fzf-tab.plugin.zsh"; do
        if [[ -r "$_cachyos_candidate" ]]; then
            _cachyos_fzf_tab_source="$_cachyos_candidate"
            break
        fi
    done
    unset _cachyos_candidate
fi
if (( $+commands[fzf] )) && [[ -r "$_cachyos_fzf_tab_source" ]]; then
    source "$_cachyos_fzf_tab_source"
    zstyle ':completion:*' menu no
    zstyle ':completion:*:descriptions' format '[%d]'
    if (( $+commands[eza] )); then
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always -- "$realpath"'
    fi
fi
unset _cachyos_fzf_tab_source

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi

# --- Alias pratiques dans un fichier séparé -----------------------------------
typeset -g CACHYOS_ZSH_REPLACE_COMMANDS=${CACHYOS_ZSH_REPLACE_COMMANDS:-false}
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/cachyos-zsh/aliases.zsh" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/cachyos-zsh/aliases.zsh"
fi

# --- Yazi : quitter le navigateur dans le dossier sélectionné -----------------
# Utiliser `y` pour changer aussi le dossier du shell ; `yazi` reste inchangé.
if (( $+commands[yazi] )); then
    function y() {
        local temporary cwd result
        temporary=$(command mktemp "${TMPDIR:-/tmp}/cachyos-yazi.XXXXXXXX") || return
        if command yazi "$@" --cwd-file="$temporary"; then result=0; else result=$?; fi
        if (( result == 0 )); then
            cwd=$(command cat -- "$temporary")
            if [[ -n "$cwd" && -d "$cwd" && "$cwd" != "$PWD" ]]; then
                builtin cd -- "$cwd" || result=$?
            fi
        fi
        command rm -f -- "$temporary" || return
        return "$result"
    }
fi

# --- Suggestions locales -----------------------------------------------------
if [[ -r "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# --- Personnalisation conservée en dehors du fichier généré ------------------
if [[ -r "$HOME/.zshrc.local" ]]; then source "$HOME/.zshrc.local"; fi

# --- Starship ----------------------------------------------------------------
if (( $+commands[starship] )); then
    # Respecter STARSHIP_CONFIG choisi dans l'environnement ou le fichier local.
    if [[ ${CACHYOS_ZSH_USE_THEME:-true} == true ]] && [[ -z ${STARSHIP_CONFIG:-} && -r "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ]]; then
        export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
    fi
    eval "$(starship init zsh)"
fi

# --- Coloration syntaxique ---------------------------------------------------
# Exception documentée par history-substring-search : le charger APRÈS cette
# coloration pour que sa propre mise en évidence de l'historique fonctionne.
if [[ -r "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# --- Historique : rechercher un fragment avec les flèches haut/bas ------------
if [[ -r "/usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "/usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
    HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
    zmodload -i zsh/terminfo
    for _cachyos_keymap in emacs viins vicmd; do
        bindkey -M "$_cachyos_keymap" '^[[A' history-substring-search-up
        bindkey -M "$_cachyos_keymap" '^[[B' history-substring-search-down
        bindkey -M "$_cachyos_keymap" '^[OA' history-substring-search-up
        bindkey -M "$_cachyos_keymap" '^[OB' history-substring-search-down
        if [[ -n ${terminfo[kcuu1]:-} ]]; then
            bindkey -M "$_cachyos_keymap" "$terminfo[kcuu1]" history-substring-search-up
        fi
        if [[ -n ${terminfo[kcud1]:-} ]]; then
            bindkey -M "$_cachyos_keymap" "$terminfo[kcud1]" history-substring-search-down
        fi
    done
    unset _cachyos_keymap
fi
