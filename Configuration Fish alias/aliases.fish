# Alias personnels pour fish.
# Modifiez ce fichier, puis relancez install-fish-aliases.sh.

# Alias existants
alias ll='ls -lah' # Liste détaillée des fichiers avec permissions, tailles, dates
alias update='sudo pacman -Syu' # Met à jour le système et les paquets
alias cls='clear' # Efface l'écran du terminal

# Alias pour utilisation quotidienne
alias la='ls -A' # Liste tous les fichiers y compris les cachés (sauf . et ..)
alias l='ls -CF' # Liste les fichiers avec indicateurs de type
alias ..='cd ..' # Remonte d'un niveau dans l'arborescence
alias ...='cd ../..' # Remonte de deux niveaux
alias ....='cd ../../..' # Remonte de trois niveaux
alias grep='grep --color=auto' # Recherche avec coloration syntaxique
alias egrep='egrep --color=auto' # Recherche étendue avec coloration
alias fgrep='fgrep --color=auto' # Recherche de chaînes fixes avec coloration
alias cp='cp -i' # Copie avec confirmation en cas d'écrasement
alias mv='mv -i' # Déplacement avec confirmation
alias rm='rm -i' # Suppression avec confirmation
alias df='df -h' # Espace disque avec unités lisibles
alias free='free -h' # Mémoire RAM avec unités lisibles
alias du='du -h' # Taille des dossiers avec unités lisibles
alias mkdir='mkdir -p' # Crée les dossiers parents si nécessaire

# Alias pour gestion des paquets (Pacman)
alias upgrade='sudo pacman -Syu' # Met à jour tous les paquets
alias install='sudo pacman -S' # Installe un ou plusieurs paquets
alias remove='sudo pacman -Rns' # Supprime un paquet et ses dépendances inutiles
alias search='pacman -Ss' # Recherche un paquet dans les dépôts
alias info='pacman -Si' # Affiche les informations d'un paquet
alias list-installed='pacman -Q' # Liste tous les paquets installés
alias list-explicit='pacman -Qe' # Liste les paquets installés explicitement
alias list-foreign='pacman -Qm' # Liste les paquets étrangers (AUR, etc.)

# Alias pour maintenance système
alias clean-cache='sudo paccache -r' # Nettoie le cache des paquets
alias remove-orphans='sudo pacman -Qdtq | sudo pacman -Rns -' # Supprime les paquets orphelins
alias check-updates='checkupdates' # Vérifie les mises à jour disponibles
alias check-aur-updates='checkupdates-aur' # Vérifie les mises à jour AUR
alias systemctl='sudo systemctl' # Gestionnaire de services systemd avec sudo
alias journal='sudo journalctl' # Affiche les logs système
alias reboot='sudo reboot' # Redémarre le système
alias shutdown='sudo shutdown now' # Éteint immédiatement le système

# Alias pour réseau
alias ping='ping -c 4' # Test de connectivité avec 4 paquets
alias myip='curl -s ifconfig.me' # Affiche l'adresse IP publique

# Alias pour processus
alias ps='ps aux' # Liste tous les processus en cours
alias top='htop' # Moniteur de processus interactif (nécessite htop)
alias kill='sudo kill' # Tue un processus par PID
alias killall='sudo killall' # Tue tous les processus d'un nom

# Alias pour édition
alias vi='vim' # Lance vim
alias nano='nano -w' # Lance nano sans retour à la ligne automatique

# Alias pour archives
alias tar-extract='tar -xvf' # Extrait une archive tar
alias tar-compress='tar -cvf' # Crée une archive tar
alias zip-extract='unzip' # Extrait une archive zip
alias zip-compress='zip -r' # Crée une archive zip récursive

# Alias spécifiques à CachyOS
alias cachy-mirrors='sudo cachyos-rate-mirrors' # Met à jour les miroirs CachyOS
alias cachy-keyrings='sudo pacman -Syu archlinux-keyring cachyos-keyring' # Met à jour les clés de signature
alias cachy-kernels='pacman -Ss "^linux-cachyos"' # Recherche les noyaux CachyOS
alias mirrors='sudo reflector --latest 30 --protocol https --sort score --save /etc/pacman.d/mirrorlist' # Met à jour la liste des miroirs
alias journal-clean='sudo journalctl --vacuum-time=14d' # Nettoie les logs de plus de 14 jours
alias grub-update='sudo grub-mkconfig -o /boot/grub/grub.cfg' # Met à jour la configuration GRUB

# Alias pour systemd
alias sysstatus='systemctl status' # Affiche le statut d'un service
alias sysrestart='sudo systemctl restart' # Redémarre un service
alias sysstop='sudo systemctl stop' # Arrête un service
alias sysstart='sudo systemctl start' # Démarre un service
alias sysenable='sudo systemctl enable' # Active un service au démarrage
alias sysdisable='sudo systemctl disable' # Désactive un service au démarrage

# Alias pour réseau
alias ports='ss -tulpen' # Liste les ports ouverts
alias pubip='curl -fsS https://ifconfig.me' # Affiche l'adresse IP publique (version silencieuse)
