# Alias personnels pour fish.
# Modifiez ce fichier, puis relancez install-fish-aliases.sh.

# Alias existants
alias ll='ls -lah'
alias update='sudo pacman -Syu'
alias cls='clear'

# Alias pour utilisation quotidienne
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias df='df -h'
alias free='free -h'
alias du='du -h'
alias mkdir='mkdir -p'

# Alias pour gestion des paquets (Pacman)
alias upgrade='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias search='pacman -Ss'
alias info='pacman -Si'
alias list-installed='pacman -Q'
alias list-explicit='pacman -Qe'
alias list-foreign='pacman -Qm'

# Alias pour maintenance système
alias clean-cache='sudo paccache -r'
alias remove-orphans='sudo pacman -Qdtq | sudo pacman -Rns -'
alias check-updates='checkupdates'
alias check-aur-updates='checkupdates-aur'
alias systemctl='sudo systemctl'
alias journal='sudo journalctl'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'

# Alias pour réseau
alias ping='ping -c 4'
alias myip='curl -s ifconfig.me'

# Alias pour processus
alias ps='ps aux'
alias top='htop'
alias kill='sudo kill'
alias killall='sudo killall'

# Alias pour édition
alias vi='vim'
alias nano='nano -w'

# Alias pour archives
alias tar-extract='tar -xvf'
alias tar-compress='tar -cvf'
alias zip-extract='unzip'
alias zip-compress='zip -r'

# Alias spécifiques à CachyOS
alias cachy-mirrors='sudo cachyos-rate-mirrors'
alias cachy-keyrings='sudo pacman -Syu archlinux-keyring cachyos-keyring'
alias cachy-kernels='pacman -Ss "^linux-cachyos"'
alias mirrors='sudo reflector --latest 30 --protocol https --sort score --save /etc/pacman.d/mirrorlist'
alias journal-clean='sudo journalctl --vacuum-time=14d'
alias grub-update='sudo grub-mkconfig -o /boot/grub/grub.cfg'

# Alias pour systemd
alias sysstatus='systemctl status'
alias sysrestart='sudo systemctl restart'
alias sysstop='sudo systemctl stop'
alias sysstart='sudo systemctl start'
alias sysenable='sudo systemctl enable'
alias sysdisable='sudo systemctl disable'

# Alias pour réseau
alias ports='ss -tulpen'
alias pubip='curl -fsS https://ifconfig.me'
