# Alias personnels pour zsh.
# Modifiez ce fichier, puis relancez install-zsh-aliases.sh.

# =============================================================================
# ALIAS MISE À JOUR GLOBALE
# =============================================================================

# Mise à jour Globales
alias masterupdate='sudo pacman -Syu && yay -Syu && flatpak update' # Met à jour tout le système (pacman, AUR et Flatpak)
alias updatepacman='sudo pacman -Syu'    # Met a jour le systeme
alias updateyay='yay -Syu'            # Met a jour depots officiels et AUR
alias updateflatpak='flatpak update'   # Met a jour les applications Flatpak

# =============================================================================
# ALIAS PACMAN, YAY ET FLATPAK
# =============================================================================

# Pacman
alias pacupdate='sudo pacman -Syu'    # Met a jour le systeme
alias pacinstall='sudo pacman -S'     # Installe un paquet
alias paclocalin='sudo pacman -U'  # Installe un paquet local
alias pacremoveall='sudo pacman -Rns'   # Supprime un paquet et ses dependances inutiles
alias pacremove='sudo pacman -R'      # Supprime un paquet
alias pacssearch='pacman -Ss'         # Recherche un paquet distant
alias pacsinfo='pacman -Si'         # Affiche les infos d'un paquet distant
#alias pacqs='pacman -Qs'         # Recherche un paquet installe
#alias pacqi='pacman -Qi'         # Affiche les infos d'un paquet installe
#alias pacql='pacman -Ql'         # Liste les fichiers d'un paquet
#alias pacqo='pacman -Qo'         # Trouve le paquet proprietaire d'un fichier
#alias pacorphans='pacman -Qtd'  # Liste les paquets orphelins
#alias pacclean='sudo pacman -Sc' # Nettoie le cache des anciens paquets
#alias paccleanall='sudo pacman -Scc' # Nettoie tout le cache pacman
#alias pacfiles='pacman -F'       # Recherche dans la base des fichiers
#alias pacmirrors='sudo pacman-mirrors --fasttrack' # Optimise les miroirs

# Yay
alias yayup='yay -Syu'            # Met a jour depots officiels et AUR
alias yayinstall='yay -S'             # Installe un paquet
alias yayremoveall='yay -Rns'           # Supprime un paquet et ses dependances inutiles
alias yayssearch='yay -Ss'            # Recherche un paquet
alias yayclean='yay -Sc'         # Nettoie le cache
#alias yaysi='yay -Si'            # Affiche les infos d'un paquet distant
#alias yayqs='yay -Qs'            # Recherche un paquet installe
#alias yayqi='yay -Qi'            # Affiche les infos d'un paquet installe
#alias yayorphans='yay -Qtdq'     # Liste les paquets orphelins
#alias yaycleanall='yay -Scc'     # Nettoie tout le cache yay

# Paru
alias paruup='paru -Syu'            # Met a jour depots officiels et AUR
alias paruinstall='paru -S'             # Installe un paquet
alias paruremoveall='paru -Rns'           # Supprime un paquet et ses dependances inutiles
alias parussearch='paru -Ss'            # Recherche un paquet
alias paruclean='paru -Sc'         # Nettoie le cache

# Flatpak
alias flatinstall='flatpak install'      # Installe une application
alias flatremove='flatpak uninstall'   # Desinstalle une application
alias flatsearch='flatpak search'       # Recherche une application
alias flatupdate='flatpak update'       # Met a jour les applications
alias flatlist='flatpak list'         # Liste les applications installees
alias flatinfo='flatpak info'      # Affiche les infos d'une application
alias flatrmdata='flatpak uninstall --delete-data' # Desinstalle avec donnees
#alias flatrun='flatpak run'        # Lance une application
#alias flatremotes='flatpak remotes' # Liste les depots Flatpak
#alias flatrepair='flatpak repair'  # Repare l'installation Flatpak
#alias flatclean='flatpak uninstall --unused' # Supprime les runtimes inutilises

# Nettoyage et maintenance
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)' # Supprime les paquets orphelins
alias cleanpkg='sudo pacman -Sc' # Nettoie le cache des anciens paquets
alias cleanall='sudo pacman -Scc' # Nettoie tout le cache pacman
alias pacdiff='sudo pacdiff' # Affiche les fichiers de configuration modifiés par les mises à jour


# =============================================================================
# ALIAS SYSTÈME ET MONITORING
# =============================================================================

# Mémoire et processus
alias freemem="free -mt"
alias mem='free -h'
alias meminfo='cat /proc/meminfo'
alias ps='ps aux'
alias top='btop'
alias cpuinfo='cat /proc/cpuinfo'
alias df='df -h'
alias du='du -h'
alias dus='du -sh'

# Système
alias hw="hwinfo --short"
alias ff="fastfetch"
alias audio="pactl info | grep 'Server Name'"
alias kernel="ls /usr/lib/modules"
alias uptime='uptime -p'
alias cpu='lscpu'


# Réseau
alias ping='ping -c 5'
alias ports='netstat -tuln'
alias myip='curl -s ifconfig.me'
alias speedtest='speedtest-cli'


alias dsk='df -h'
alias dsku='du -sh *'

alias ip4="ip -4 addr | grep 'inet '"
alias pubip='curl -s https://ifconfig.me'

# =============================================================================
# ALIAS CONFIGURATION ET ÉDITION
# =============================================================================

# Éditeurs de configuration système
alias editpacman="sudo $EDITOR /etc/pacman.conf"
alias editmakepkg="sudo $EDITOR /etc/makepkg.conf"
alias editmirrorlist="sudo $EDITOR /etc/pacman.d/mirrorlist"
alias editfstab="sudo $EDITOR /etc/fstab"
alias editnsswitch="sudo $EDITOR /etc/nsswitch.conf"
alias editsamba="sudo $EDITOR /etc/samba/smb.conf"
alias edithosts="sudo $EDITOR /etc/hosts"
alias edithostname="sudo $EDITOR /etc/hostname"
alias editenvironment="sudo $EDITOR /etc/environment"

# Configuration shell
alias editb="$EDITOR ~/.bashrc"
alias editz="$EDITOR ~/.zshrc"
alias editf="$EDITOR ~/.config/fish/config.fish"

# Configuration applications
alias editfastfetch="$EDITOR ~/.config/fastfetch/config.jsonc"
alias editalacritty="$EDITOR ~/.config/alacritty/alacritty.toml"
alias editkitty="$EDITOR ~/.config/kitty/kitty.conf"
#alias editnvim="$EDITOR ~/.config/nvim/init.lua"


# =============================================================================
# ALIAS GESTION DES SERVICES ET SYSTÈME
# =============================================================================

# Systemd
alias jctl="journalctl -p 3 -xb"
alias sysfailed="systemctl list-units --failed"
alias sysstatus="systemctl status"
alias sysrestart="sudo systemctl restart"
alias sysstop="sudo systemctl stop"
alias sysstart="sudo systemctl start"
alias sysenable="sudo systemctl enable"
alias sysdisable="sudo systemctl disable"

# Mirrors et optimisation
alias mirrors="sudo reflector --latest 30 --number 10 --sort score --save /etc/pacman.d/mirrorlist"
alias mirrors-fast="sudo reflector --latest 20 --number 5 --sort rate --save /etc/pacman.d/mirrorlist"

# =============================================================================
# ALIAS UTILITAIRES ET RACCOURCIS
# =============================================================================

# Historique des paquets
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias riplong="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -3000 | nl"

# Logs
alias lpacman="bat /var/log/pacman.log"
alias lsystem="journalctl -f"

# Permissions et sécurité
alias chx='chmod +x'
alias fix-own='sudo chown $USER:$USER'

# Sessions et environnements
alias xd="ls /usr/share/xsessions"
alias xdw="ls /usr/share/wayland-sessions"

# Arrêt et redémarrage
alias ssn="sudo shutdown now"
alias sr="reboot"
alias reboot="sudo reboot"
alias shutdown="sudo shutdown"


# =============================================================================
# ALIAS GESTION DES POLICES ET FONTS
# =============================================================================

# Fonts
alias update-font='sudo fc-cache -fv'
alias list-fonts='fc-list'

# =============================================================================
# ALIAS SYSTÈME ET NAVIGATION
# =============================================================================

# Navigation
alias ..='cd ..'                 # Remonte d'un dossier
alias ...='cd ../..'             # Remonte de deux dossiers
alias ....='cd ../../..'         # Remonte de trois dossiers
alias -- -='cd -'                # Retourne au dossier precedent


# Fichiers et recherche (LS, Eza)
  alias ls='eza --icons=auto --group-directories-first'              # Liste avec eza
  alias ll='eza -lah --icons=auto --git --group-directories-first'   # Liste detaillee avec infos git
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first' # Arbre limite a 2 niveaux
  alias tree='eza --tree --icons=auto --group-directories-first'     # Affiche une arborescence

# Recherche et filtrage
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ripgrep='rg --sort path --color=auto'

alias cat='bat --paging=never'   # Affiche un fichier avec coloration
alias catp='bat'                 # Affiche un fichier avec pagination

alias find='fd'                  # Recherche de fichiers plus simple



# =============================================================================
# ALIAS GIT
# =============================================================================

# Git
alias gstat='git status'         # Statut du dépôt
alias gp='git push'              # Envoie les commits
alias gpl='git pull'             # Recupere et fusionne
alias gadd='git add'               # Ajoute des fichiers
alias gaddall='git add --all'        # Ajoute tous les changements
alias gcom='git commit -m'        # Cree un commit avec message
alias gdif='git diff'              # Affiche les changements non indexes
alias gf='git fetch'             # Recupere les changements distants
alias gfa='git fetch --all --prune' # Recupere tout et nettoie les branches supprimees
alias gl='git log --oneline --graph --decorate' # Historique compact
alias gla='git log --oneline --graph --decorate --all' # Historique compact toutes branches

# Zoxide
alias zi='z -i'                  # Choisit un dossier avec zoxide interactif

# FZF
  # Choisit un dossier avec fzf, puis entre dedans.
  cdfzf() {
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
