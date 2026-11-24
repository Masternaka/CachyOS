# =============================================================================
# Alias pratiques Zsh — paquet Stow CachyOS
# Installé dans ${XDG_CONFIG_HOME:-$HOME/.config}/cachyos-zsh/aliases.zsh.
# Chargé par ~/.zshrc avant ~/.zshrc.local, qui peut surcharger ces raccourcis.
# Définir un alias ne lance aucune commande ; pas de téléchargement au chargement.
# =============================================================================

# --- Raccourcis du shell ------------------------------------------------------
alias h='history'
alias d='dirs -v'
alias p='pwd'
if (( $+commands[clear] )); then alias c='clear'; fi

# --- Aliases : Fichiers (eza + bat) ------------------------------------------
if (( $+commands[eza] )); then
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons --git'
    alias lt='eza --tree --level=2 --icons'
    alias l='eza -1 --icons'
fi
if (( $+commands[bat] )); then
    alias ccat='bat --paging=never'
fi

# --- Aliases : Navigation ----------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias md='mkdir -pv'              # crée les parents, verbose
alias rd='rmdir'
alias dus='du -sh'
alias dfh='df -h'

# --- Aliases : Git -----------------------------------------------------------
if (( $+commands[git] )); then
    alias g='git'
    alias gs='git status -sb'
    alias ga='git add'
    alias gaa='git add --all'
    alias gc='git commit -m'
    alias gca='git commit --amend --no-edit'
    alias gp='git push'
    alias gpl='git pull'
    alias gf='git fetch --prune'
    alias gd='git diff'
    alias gds='git diff --staged'
    alias gl='git log --oneline --graph --decorate --all'
    alias gco='git checkout'
    alias gb='git branch -vv'
    alias gbd='git branch -d'
    alias grb='git rebase'
    alias gst='git stash'
    alias gstp='git stash pop'
fi

# --- Aliases : Système (Arch) ------------------------------------------------
if (( $+commands[pacman] )); then
    alias update='sudo pacman -Syu'  # action explicite, confirmation Pacman conservée
    alias pkginstall='sudo pacman -S'
    alias pkgremove='sudo pacman -Rns'
    alias pkgsearch='pacman -Ss'
    alias pkginfo='pacman -Qi'
    alias pkgfiles='pacman -Ql'
    alias orphans='pacman -Qtdq'     # inventaire seulement, aucune suppression
fi
if (( $+commands[systemctl] )); then
    alias reboot='sudo systemctl reboot'
    alias poweroff='sudo systemctl poweroff'
    alias suspend='sudo systemctl suspend'
    alias services='systemctl list-units --type=service --state=running'
fi
if (( $+commands[journalctl] )); then
    alias logs='journalctl -xe'
    alias j='journalctl -f'          # suivi des logs en direct
fi
if (( $+commands[lazygit] )); then alias lg='lazygit'; fi
if (( $+commands[btop] )); then alias bt='btop'; fi

# --- Aliases : Réseau --------------------------------------------------------
if (( $+commands[ip] )); then
    alias ipa='ip -c addr'
    alias ipr='ip -c route'
fi
if (( $+commands[ss] )); then alias ports='ss -tulnp'; fi
if (( $+commands[resolvectl] )); then alias dns='resolvectl status'; fi
# Aucun alias ne télécharge un programme pour l'exécuter.
# Installer un outil de mesure réseau séparément si nécessaire.

# --- Remplacement facultatif des commandes usuelles --------------------------
# Choix effectué à l'installation ; surcharge possible dans l'environnement.
# Sans option ni variable explicite, les commandes usuelles sont conservées.
if [[ ${CACHYOS_ZSH_REPLACE_COMMANDS:-false} == true ]]; then
    if (( $+commands[eza] )); then alias ls='eza --group-directories-first --icons=auto'; fi
    if (( $+commands[bat] )); then
        alias cat='bat --paging=never'
        alias less='bat'
    fi
    alias mkdir='mkdir -pv'
    alias cp='cp -iv'              # interactif + verbose
    alias mv='mv -iv'
    alias rm='rm -Iv'              # confirmation si >3 fichiers ou récursif
    alias du='du -sh'
    alias df='df -h'
    if (( $+commands[ip] )); then alias ip='ip -c'; fi
    if (( $+commands[ping] )); then alias ping='ping -c 5'; fi
fi

