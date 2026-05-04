# Alias personnels pour zsh.
# Modifiez ce fichier, puis relancez install-zsh-aliases.sh.

# Navigation
alias ..='cd ..'                 # Remonte d'un dossier
alias ...='cd ../..'             # Remonte de deux dossiers
alias ....='cd ../../..'         # Remonte de trois dossiers
alias -- -='cd -'                # Retourne au dossier precedent

# Shell
alias c='clear'                  # Nettoie le terminal
alias cls='clear'                # Nettoie le terminal
alias mkdir='mkdir -p'           # Cree les dossiers parents si besoin
alias cp='cp -i'                 # Demande confirmation avant d'ecraser
alias mv='mv -i'                 # Demande confirmation avant d'ecraser
alias rm='rm -i'                 # Demande confirmation avant de supprimer
alias df='df -h'                 # Affiche l'espace disque lisible
alias du='du -h'                 # Affiche la taille des dossiers lisible
alias free='free -h'             # Affiche la memoire lisible

# Fichiers et recherche
if command -v eza >/dev/null; then
  alias ls='eza --icons=auto --group-directories-first'              # Liste avec eza
  alias l='eza --icons=auto --group-directories-first'               # Liste courte avec eza
  alias la='eza -a --icons=auto --group-directories-first'           # Liste avec fichiers caches
  alias ll='eza -lah --icons=auto --git --group-directories-first'   # Liste detaillee avec infos git
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first' # Arbre limite a 2 niveaux
  alias tree='eza --tree --icons=auto --group-directories-first'     # Affiche une arborescence
else
  alias l='ls -CF'                 # Liste courte classique
  alias la='ls -A'                 # Liste avec fichiers caches
  alias ll='ls -lah'               # Liste detaillee classique
fi

if command -v bat >/dev/null; then
  alias cat='bat --paging=never'   # Affiche un fichier avec coloration
  alias catp='bat'                 # Affiche un fichier avec pagination
fi

if command -v fd >/dev/null; then
  alias find='fd'                  # Recherche de fichiers plus simple
fi

if command -v rg >/dev/null; then
  alias grep='rg'                  # Recherche de texte plus rapide
fi

# Git
if command -v git >/dev/null; then
  alias g='git'                    # Raccourci git
  alias ga='git add'               # Ajoute des fichiers
  alias gaa='git add --all'        # Ajoute tous les changements
  alias gb='git branch'            # Liste les branches locales
  alias gba='git branch --all'     # Liste toutes les branches
  alias gbd='git branch --delete'  # Supprime une branche locale
  alias gc='git commit'            # Cree un commit
  alias gcm='git commit -m'        # Cree un commit avec message
  alias gca='git commit --amend'   # Modifie le dernier commit
  alias gd='git diff'              # Affiche les changements non indexes
  alias gds='git diff --staged'    # Affiche les changements indexes
  alias gf='git fetch'             # Recupere les changements distants
  alias gfa='git fetch --all --prune' # Recupere tout et nettoie les branches supprimees
  alias gl='git log --oneline --graph --decorate' # Historique compact
  alias gla='git log --oneline --graph --decorate --all' # Historique compact toutes branches
  alias gp='git push'              # Envoie les commits
  alias gpf='git push --force-with-lease' # Force push plus prudent
  alias gpl='git pull'             # Recupere et fusionne
  alias gpr='git pull --rebase'    # Recupere avec rebase
  alias gr='git restore'           # Restaure des fichiers
  alias grs='git restore --staged' # Retire des fichiers de l'index
  alias gst='git status --short --branch' # Statut compact
  alias gsw='git switch'           # Change de branche
  alias gswc='git switch -c'       # Cree et change de branche
  alias gt='git tag'               # Gere les tags
fi

# Pacman
if command -v pacman >/dev/null; then
  alias pac='pacman'               # Raccourci pacman
  alias pacu='sudo pacman -Syu'    # Met a jour le systeme
  alias pacin='sudo pacman -S'     # Installe un paquet
  alias paclocal='sudo pacman -U'  # Installe un paquet local
  alias pacrm='sudo pacman -Rns'   # Supprime un paquet et ses dependances inutiles
  alias pacr='sudo pacman -R'      # Supprime un paquet
  alias pacss='pacman -Ss'         # Recherche un paquet distant
  alias pacsi='pacman -Si'         # Affiche les infos d'un paquet distant
  alias pacqs='pacman -Qs'         # Recherche un paquet installe
  alias pacqi='pacman -Qi'         # Affiche les infos d'un paquet installe
  alias pacql='pacman -Ql'         # Liste les fichiers d'un paquet
  alias pacqo='pacman -Qo'         # Trouve le paquet proprietaire d'un fichier
  alias pacorphans='pacman -Qtdq'  # Liste les paquets orphelins
  alias pacclean='sudo pacman -Sc' # Nettoie le cache des anciens paquets
  alias paccleanall='sudo pacman -Scc' # Nettoie tout le cache pacman
  alias pacfiles='pacman -F'       # Recherche dans la base des fichiers
  alias pacmirrors='sudo pacman-mirrors --fasttrack' # Optimise les miroirs
fi

# Yay
if command -v yay >/dev/null; then
  alias yayu='yay -Syu'            # Met a jour depots officiels et AUR
  alias yayin='yay -S'             # Installe un paquet
  alias yayrm='yay -Rns'           # Supprime un paquet et ses dependances inutiles
  alias yayss='yay -Ss'            # Recherche un paquet
  alias yaysi='yay -Si'            # Affiche les infos d'un paquet distant
  alias yayqs='yay -Qs'            # Recherche un paquet installe
  alias yayqi='yay -Qi'            # Affiche les infos d'un paquet installe
  alias yayorphans='yay -Qtdq'     # Liste les paquets orphelins
  alias yayclean='yay -Sc'         # Nettoie le cache
  alias yaycleanall='yay -Scc'     # Nettoie tout le cache yay
fi

# Flatpak
if command -v flatpak >/dev/null; then
  alias fp='flatpak'               # Raccourci flatpak
  alias fpi='flatpak install'      # Installe une application
  alias fprm='flatpak uninstall'   # Desinstalle une application
  alias fprmdata='flatpak uninstall --delete-data' # Desinstalle avec donnees
  alias fps='flatpak search'       # Recherche une application
  alias fpl='flatpak list'         # Liste les applications installees
  alias fpu='flatpak update'       # Met a jour les applications
  alias fprun='flatpak run'        # Lance une application
  alias fpinfo='flatpak info'      # Affiche les infos d'une application
  alias fpremotes='flatpak remotes' # Liste les depots Flatpak
  alias fprepair='flatpak repair'  # Repare l'installation Flatpak
  alias fpclean='flatpak uninstall --unused' # Supprime les runtimes inutilises
fi

# Zoxide
if command -v zoxide >/dev/null; then
  alias zi='z -i'                  # Choisit un dossier avec zoxide interactif
fi

# FZF
if command -v fzf >/dev/null && command -v fd >/dev/null; then
  # Choisit un dossier avec fzf, puis entre dedans.
  cdf() {
    local dir
    dir="$(fd --type d --hidden --follow --exclude .git | fzf --preview 'eza -lah --icons=auto --group-directories-first {} 2>/dev/null || ls -lah {}')" || return
    [[ -n "$dir" ]] && cd "$dir"
  }

  # Choisit un fichier avec fzf, puis l'ouvre avec EDITOR.
  fzf-open() {
    local file
    file="$(fd --type f --hidden --follow --exclude .git | fzf --preview 'bat --style=numbers --color=always --line-range=:200 {} 2>/dev/null || sed -n "1,200p" {}')" || return
    [[ -n "$file" ]] && "${EDITOR:-nano}" "$file"
  }
fi
