# =============================================================================
# Alias pratiques Zsh — modèle versionné pour CachyOS
# Installé dans ${XDG_CONFIG_HOME:-$HOME/.config}/cachyos-zsh/aliases.zsh.
# Chargé par ~/.zshrc avant ~/.zshrc.local, qui peut surcharger ces raccourcis.
# Définir un alias ne lance aucune commande ; pas de téléchargement au chargement.
# =============================================================================

# ────────────────────────────────────────────────────────────────────────────
# 01 · Historique et shell
# ────────────────────────────────────────────────────────────────────────────
# Affiche l'historique des commandes.
alias h='history'

# Affiche la pile des dossiers avec leurs numéros.
alias d='dirs -v'

# Affiche le chemin du dossier courant.
alias p='pwd'

# Efface l'affichage du terminal.
if (( $+commands[clear] )); then
    alias c='clear'
fi

# ────────────────────────────────────────────────────────────────────────────
# 02 · Affichage des fichiers
# ────────────────────────────────────────────────────────────────────────────
if (( $+commands[eza] )); then
    # Liste les fichiers en détail, avec tailles lisibles, icônes et état Git.
    alias ll='eza -lh --icons --git'

    # Comme ll, en incluant les fichiers cachés.
    alias la='eza -lah --icons --git'

    # Affiche les fichiers et dossiers sous forme d’arbre avec icônes.
    alias lt='eza --tree --icons'

    # Liste une entrée par ligne avec son icône.
    alias l='eza -1 --icons'
fi

if (( $+commands[bat] )); then
    # Affiche un fichier avec coloration, sans pagination.
    alias ccat='bat --paging=never'
fi

# ────────────────────────────────────────────────────────────────────────────
# 03 · Navigation et espace disque
# ────────────────────────────────────────────────────────────────────────────
# Remonte au dossier parent.
alias ..='cd ..'

# Remonte de deux niveaux dans les dossiers.
alias ...='cd ../..'

# Remonte de trois niveaux dans les dossiers.
alias ....='cd ../../..'

# Crée un dossier et ses parents manquants en affichant les créations.
alias md='mkdir -pv'              # crée les parents, verbose

# Supprime un dossier uniquement s’il est vide.
alias rd='rmdir'

# Affiche la taille totale de chaque chemin fourni, dans une unité lisible.
alias dus='du -sh'

# Affiche l’espace utilisé et disponible des systèmes de fichiers.
alias dfh='df -h'

# ────────────────────────────────────────────────────────────────────────────
# 04 · Git
# ────────────────────────────────────────────────────────────────────────────
if (( $+commands[git] )); then
    # Abrège git ; ajouter la sous-commande souhaitée.
    alias g='git'

    # Affiche un état Git compact et les informations de branche.
    alias gs='git status -sb'

    # Ajoute les chemins indiqués à la préparation du prochain commit.
    alias ga='git add'

    # Prépare tous les ajouts, modifications et suppressions du dépôt.
    alias gaa='git add --all'

    # Crée un commit avec le message fourni entre guillemets.
    alias gc='git commit -m'

    # Modifie le dernier commit avec les changements préparés, sans changer son message.
    alias gca='git commit --amend --no-edit'

    # Envoie les commits vers le dépôt distant selon la configuration Git.
    alias gp='git push'

    # Récupère puis intègre les changements distants selon la configuration Git.
    alias gpl='git pull'

    # Récupère les changements distants et retire les références de suivi devenues
    # obsolètes.
    alias gf='git fetch --prune'

    # Affiche les modifications des fichiers suivis qui ne sont pas encore préparées.
    alias gd='git diff'

    # Affiche les modifications préparées pour le prochain commit.
    alias gds='git diff --staged'

    # Affiche un graphe compact des commits de toutes les branches.
    alias gl='git log --oneline --graph --decorate --all'

    # Change de branche ou restaure des fichiers selon les arguments fournis.
    alias gco='git checkout'

    # Liste les branches locales avec leur dernier commit et leur suivi distant.
    alias gb='git branch -vv'

    # Supprime la branche locale indiquée si Git la considère comme fusionnée.
    alias gbd='git branch -d'

    # Rejoue les commits sur la base indiquée ; réécrit leur historique.
    alias grb='git rebase'

    # Met de côté les modifications suivies pour libérer le travail en cours.
    alias gst='git stash'

    # Réapplique les modifications mises de côté et retire cette entrée si l’application
    # réussit.
    alias gstp='git stash pop'
fi

# ────────────────────────────────────────────────────────────────────────────
# 05 · Paquets et système
# ────────────────────────────────────────────────────────────────────────────
if (( $+commands[pacman] )); then
    # Met à jour les bases et tous les paquets du système avec les confirmations Pacman.
    alias update='sudo pacman -Syu'  # action explicite, confirmation Pacman conservée

    # Installe les paquets indiqués depuis les bases de dépôts locales existantes.
    alias pkginstall='sudo pacman -S'

    # Retire les paquets indiqués et leurs dépendances devenues inutiles, sans créer de
    # .pacsave.
    alias pkgremove='sudo pacman -Rns'

    # Recherche un paquet par nom ou description dans les bases des dépôts.
    alias pkgsearch='pacman -Ss'

    # Affiche les informations du paquet installé indiqué.
    alias pkginfo='pacman -Qi'

    # Liste les fichiers appartenant au paquet installé indiqué.
    alias pkgfiles='pacman -Ql'

    # Liste les noms des dépendances installées devenues orphelines, sans les supprimer.
    alias orphans='pacman -Qtdq'     # inventaire seulement, aucune suppression
fi

if (( $+commands[systemctl] )); then
    # Redémarre l’ordinateur.
    alias reboot='sudo systemctl reboot'

    # Éteint l’ordinateur.
    alias poweroff='sudo systemctl poweroff'

    # Met l’ordinateur en veille.
    alias suspend='sudo systemctl suspend'

    # Liste les services systemd en cours d’exécution.
    alias services='systemctl list-units --type=service --state=running'
fi

if (( $+commands[journalctl] )); then
    # Ouvre les entrées récentes du journal avec leurs explications disponibles.
    alias logs='journalctl -xe'

    # Suit les nouvelles entrées du journal en direct ; Ctrl+C arrête le suivi.
    alias j='journalctl -f'          # suivi des logs en direct
fi

# Ouvre l’interface Git interactive Lazygit.
if (( $+commands[lazygit] )); then
    alias lg='lazygit'
fi

# Ouvre le moniteur de ressources btop.
if (( $+commands[btop] )); then
    alias bt='btop'
fi

# ────────────────────────────────────────────────────────────────────────────
# 06 · Réseau
# ────────────────────────────────────────────────────────────────────────────
if (( $+commands[ip] )); then
    # Affiche les interfaces et leurs adresses réseau avec des couleurs.
    alias ipa='ip -c addr'

    # Affiche les routes réseau avec des couleurs.
    alias ipr='ip -c route'
fi

# Liste les sockets TCP/UDP en écoute et les processus visibles avec les droits actuels.
if (( $+commands[ss] )); then
    alias ports='ss -tulnp'
fi

# Affiche les paramètres et l’état de la résolution DNS.
if (( $+commands[resolvectl] )); then
    alias dns='resolvectl status'
fi

# Aucun alias ne télécharge un programme pour l'exécuter.
# Installer un outil de mesure réseau séparément si nécessaire.

# ────────────────────────────────────────────────────────────────────────────
# 07 · Remplacements facultatifs des commandes usuelles
# ────────────────────────────────────────────────────────────────────────────
# Choix effectué à l'installation ; surcharge possible dans l'environnement.
# Sans option ni variable explicite, les commandes usuelles sont conservées.
if [[ ${CACHYOS_ZSH_REPLACE_COMMANDS:-false} == true ]]; then
    # Remplace la liste habituelle des fichiers par eza avec des icônes.
    if (( $+commands[eza] )); then
        alias ls='eza --icons'
    fi

    if (( $+commands[bat] )); then
        # Affiche les fichiers avec bat, colorisés et sans pagination.
        alias cat='bat --paging=never'

        # Affiche les fichiers avec bat, qui choisit la pagination selon la sortie.
        alias less='bat'
    fi

    # Crée aussi les dossiers parents manquants et affiche les créations.
    alias mkdir='mkdir -pv'

    # Copie en affichant les opérations et demande confirmation avant écrasement.
    alias cp='cp -iv'              # interactif + verbose

    # Déplace en affichant les opérations et demande confirmation avant écrasement.
    alias mv='mv -iv'

    # Supprime en affichant les opérations et demande un accord global au-delà de trois
    # fichiers ou en mode récursif.
    alias rm='rm -Iv'              # confirmation si >3 fichiers ou récursif

    # Affiche seulement la taille totale de chaque chemin fourni, dans une unité
    # lisible.
    alias du='du -sh'

    # Affiche l’espace des systèmes de fichiers dans des unités lisibles.
    alias df='df -h'

    # Active les couleurs pour les commandes réseau ip.
    if (( $+commands[ip] )); then
        alias ip='ip -c'
    fi

    # Limite chaque commande ping à cinq requêtes.
    if (( $+commands[ping] )); then
        alias ping='ping -c 5'
    fi
fi
