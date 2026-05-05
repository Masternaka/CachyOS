# Alias et petites fonctions pour CachyOS / Arch.
# Modifiez ce fichier, puis relancez install-zsh-aliases.sh.

# =============================================================================
# Mises a jour et paquets
# =============================================================================

aur() {
  if command -v paru >/dev/null 2>&1; then
    paru "$@"
  elif command -v yay >/dev/null 2>&1; then
    yay "$@"
  else
    print -u2 "Aucun helper AUR trouve: installez paru ou yay."
    return 127
  fi
}

sysup() {
  sudo pacman -Syu || return
  aur -Sua
  command -v flatpak >/dev/null 2>&1 && flatpak update
}

orphans() {
  pacman -Qtdq 2>/dev/null
}

cleanorphans() {
  local -a orphan_list
  orphan_list=("${(@f)$(orphans)}")
  orphan_list=("${(@)orphan_list:#}")

  if (( ${#orphan_list[@]} == 0 )); then
    print "Aucun paquet orphelin."
    return 0
  fi

  sudo pacman -Rns "${orphan_list[@]}"
}

sysclean() {
  cleanorphans
  command -v paccache >/dev/null 2>&1 && sudo paccache -r
  command -v flatpak >/dev/null 2>&1 && flatpak uninstall --unused
  sudo journalctl --vacuum-time=14d
}

alias update='sysup'
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S --needed'
alias pacrm='sudo pacman -Rns'
alias pacsearch='pacman -Ss'
alias pacinfo='pacman -Si'
alias pacqinfo='pacman -Qi'
alias pacfiles='pacman -Ql'
alias paclist='pacman -Qe'
alias pacorphans='orphans'
alias paclog='less /var/log/pacman.log'
alias pacdiff='sudo -E pacdiff'
alias aurup='aur -Sua'
alias aurin='aur -S --needed'
alias aurrm='aur -Rns'
alias aursearch='aur -Ss'
alias aurinfo='aur -Si'
alias flatup='flatpak update'
alias flatin='flatpak install'
alias flatrm='flatpak uninstall'
alias flatclean='flatpak uninstall --unused'

# =============================================================================
# Maintenance CachyOS / systeme
# =============================================================================

alias cachy-mirrors='sudo cachyos-rate-mirrors'
alias cachy-keyrings='sudo pacman -Syu archlinux-keyring cachyos-keyring'
alias cachy-repos='pacman-conf --repo-list | grep cachyos'
alias cachy-kernels='pacman -Ss "^linux-cachyos"'
alias chwd-list='chwd --list-all'
alias chwd-installed='chwd --list-installed'
alias chwd-auto='sudo chwd -a'
alias mirrors='sudo reflector --latest 30 --protocol https --sort score --save /etc/pacman.d/mirrorlist'
alias cleanpkg='sudo paccache -r'
alias cleanpkg-uninstalled='sudo paccache -ruk0'
alias cleanup='sysclean'
alias journal-size='journalctl --disk-usage'
alias journal-clean='sudo journalctl --vacuum-time=14d'
alias mkinit='sudo mkinitcpio -P'
alias grub-update='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias kernel='uname -r'
alias kernels='ls /usr/lib/modules'
alias reboot-check='test -d /usr/lib/modules/$(uname -r) && print "Aucun redemarrage evident." || print "Redemarrage conseille: le noyau actif n a plus de modules installes."'

# =============================================================================
# Systemd, journaux et diagnostic
# =============================================================================

alias jctl='journalctl -p 3 -xb'
alias jboot='journalctl -b'
alias jerr='journalctl -b -p err'
alias jwarn='journalctl -b -p warning'
alias jfollow='journalctl -f'
alias sysfailed='systemctl list-units --failed'
alias sysstatus='systemctl status'
alias sysrestart='sudo systemctl restart'
alias sysreload='sudo systemctl reload'
alias sysstop='sudo systemctl stop'
alias sysstart='sudo systemctl start'
alias sysenable='sudo systemctl enable'
alias sysdisable='sudo systemctl disable'
alias mem='free -h'
alias cpu='lscpu'
alias df='df -h'
alias du='du -h'
alias dus='du -sh'
alias dsku='du -sh -- *'
alias ports='ss -tulpen'
alias ip4='ip -brief -4 addr'
alias ip6='ip -brief -6 addr'
alias routes='ip route'
alias pubip='curl -fsS https://ifconfig.me'
alias dns='resolvectl status'
alias gpu='lspci -k | grep -EA3 "VGA|3D|Display"'
alias sensors-watch='watch -n 2 sensors'
alias ff='fastfetch'
alias top='btop'

# =============================================================================
# Edition de configuration
# =============================================================================

alias edit='${EDITOR:-nano}'
alias sedit='sudoedit'
alias editz='${EDITOR:-nano} ~/.zshrc'
alias editaliases='${EDITOR:-nano} ~/.config/zsh/personal_aliases.zsh'
alias editpacman='sudoedit /etc/pacman.conf'
alias editmakepkg='sudoedit /etc/makepkg.conf'
alias editmirrorlist='sudoedit /etc/pacman.d/mirrorlist'
alias editcachymirrorlist='sudoedit /etc/pacman.d/cachyos-mirrorlist'
alias editfstab='sudoedit /etc/fstab'
alias edithosts='sudoedit /etc/hosts'

# =============================================================================
# Fichiers, navigation et recherche
# =============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -lah --icons=auto --git --group-directories-first'
alias la='eza -lah --icons=auto --group-directories-first'
alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
alias tree='eza --tree --icons=auto --group-directories-first'
alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'
alias cat='bat --paging=never'
alias catp='bat'
alias fdf='fd --hidden --follow --exclude .git'
alias chx='chmod +x'
alias fix-own='sudo chown -R "$USER:$USER"'

cdfzf() {
  local dir
  dir="$(fd --type d --hidden --follow --exclude .git | fzf --preview 'eza -lah --icons=auto --group-directories-first {} 2>/dev/null || ls -lah {}')" || return
  [[ -n "$dir" ]] && cd "$dir"
}

fzf-open() {
  local file
  file="$(fd --type f --hidden --follow --exclude .git | fzf --preview 'bat --style=numbers --color=always --line-range=:200 {} 2>/dev/null || sed -n "1,200p" {}')" || return
  [[ -n "$file" ]] && "${EDITOR:-nano}" "$file"
}

# =============================================================================
# Git
# =============================================================================

alias g='git'
alias gs='git status --short'
alias gstat='git status'
alias gp='git push'
alias gpl='git pull'
alias gadd='git add'
alias gaddall='git add --all'
alias gcom='git commit -m'
alias gdif='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gb='git branch'
alias gsw='git switch'

# =============================================================================
# Raccourcis divers
# =============================================================================

alias zi='z -i'
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias shutnow='sudo shutdown now'
alias reboot='sudo reboot'
alias poweroff='sudo poweroff'
alias update-font='fc-cache -fv'
