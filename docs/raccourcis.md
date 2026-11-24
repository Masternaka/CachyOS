# Raccourcis et commandes par outil

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

Les alias et fonctions de ce dépôt se chargent dans une session **Zsh** avec
les dotfiles installés. Les touches marquées **par défaut** viennent de l’outil
et peuvent être surchargées par les préférences locales. `g` puis `h` signifie
deux touches successives. Dans `Ctrl+Maj+T`, les touches s’enfoncent ensemble.

### Shell, fichiers et Git

| Outil | Raccourcis et commandes utiles |
| --- | --- |
| Zsh | Saisir un début ou un fragment de commande, puis `↑` ou `↓` pour parcourir les correspondances de l’historique. `h` affiche l’historique, `d` la pile de dossiers, `p` le dossier courant et `c` efface l’écran. `..`, `...` et `....` remontent d’un à trois niveaux. |
| FZF | Par défaut après chargement de l’intégration, `Ctrl+R` rappelle une commande, `Ctrl+T` insère un chemin et `Alt+C` choisit un dossier. [Raccourcis FZF](https://github.com/junegunn/fzf#key-bindings-for-command-line) |
| fzf-tab | Après une commande ou un début de chemin, `Tab` ouvre les complétions dans FZF lorsque le plugin est chargé. La complétion de `cd` utilise un aperçu eza si l’outil est installé. |
| Zoxide | `z projet` rejoint un dossier déjà visité, `zi projet` choisit un résultat dans FZF, `z -` revient au dossier précédent. [Commandes Zoxide](https://github.com/ajeetdsouza/zoxide#getting-started) |
| Yazi | `y` ouvre Yazi et reporte le dernier dossier dans Zsh à la sortie. Dans Yazi, `g` puis `h` ouvre le dossier personnel, `g` puis `c` ouvre `~/.config` et `g` puis `/` ouvre la racine. Par défaut, `Entrée` ouvre le fichier, `O` choisit l’application, `q` quitte et `F1` ou `~` ouvre l’aide. [Éditeur Yazi et erreur 127](zsh.md#ouvrir-un-fichier-texte-dans-yazi) · [Guide Yazi](https://yazi-rs.github.io/docs/quick-start/#keybindings) |
| Eza | `ll` liste les détails, `la` inclut les fichiers cachés, `lt` affiche l’arbre sur deux niveaux et `l` liste un nom par ligne. |
| Bat | `ccat FICHIER` affiche un fichier colorisé sans pagination. `bat FICHIER` utilise la pagination selon la sortie. |
| Ripgrep | `rg -n 'motif' .` cherche dans le contenu avec les numéros de ligne. `rg --files` liste les fichiers examinables. |
| fd | `fd 'motif'` cherche par nom. `fd -t d 'motif'` limite la recherche aux dossiers. |
| Git | `gs` affiche l’état court, `gd` les différences de travail, `gds` les différences indexées, `gl` le graphe des commits et `gb` les branches locales avec leur suivi. |
| Delta | `gd` et `gds` utilisent Delta lorsque le pager Git est configuré et que la sortie est un terminal. Dans le pager `less`, `q` revient au shell. |
| Lazygit | `lg` lance l’interface. Par défaut, `?` liste les touches contextuelles et `q` quitte. [Raccourcis Lazygit](https://github.com/jesseduffield/lazygit/blob/master/docs/keybindings/Keybindings_en.md) |
| Micro | `micro FICHIER` ouvre l’éditeur. Les touches de base sont `Ctrl+S` pour enregistrer, `Ctrl+Q` pour quitter et `Ctrl+E` pour ouvrir la barre de commandes. [Raccourcis Micro](https://github.com/zyedidia/micro/blob/master/runtime/help/defaultkeys.md) |
| VS Code | Par défaut sous Linux, `Ctrl+P` ouvre un fichier par son nom et `Ctrl+Maj+P` ouvre la palette de commandes. [Raccourcis VS Code](https://code.visualstudio.com/docs/reference/default-keybindings) |

Le menu du script 04 permet d’activer les alias facultatifs qui remplacent
`ls`, `cat`, `cp`, `mv` et `rm`. [Liste des alias Zsh](../Dotfiles/zsh/.config/cachyos-zsh/aliases.zsh)

### Terminaux

| Outil | Raccourcis |
| --- | --- |
| Ghostty | Le dépôt définit `F11` pour le plein écran, `Ctrl+Maj+T` pour un onglet et `Ctrl+Maj+W` pour fermer le panneau actif. `Ctrl+Tab` et `Ctrl+Maj+Tab` changent d’onglet, `Ctrl+Maj+←/→` les déplacent et `Ctrl+Maj+I` les renomme. |
| Ghostty, panneaux | `Ctrl+Maj+D` divise à droite, `Ctrl+Maj+Alt+D` vers le bas, `Ctrl+Maj+H/J/K/L` sélectionne gauche/bas/haut/droite et `Ctrl+Maj+Alt+Flèches` redimensionne. `Ctrl+Maj+Entrée` bascule le zoom, `Ctrl+Maj+E` égalise les panneaux. |
| Ghostty, historique | `Ctrl+Maj+↑/↓` rejoint les invites avec l’intégration du shell, `Ctrl+Maj+F` recherche le texte sélectionné et `Ctrl+Maj+S` ouvre l’historique du panneau dans un fichier. `Ctrl+Maj+R` réinitialise le terminal. [Configuration Ghostty](../Dotfiles/ghostty/.config/ghostty/config) · [Actions Ghostty](https://ghostty.org/docs/config/keybind/reference) |
| Kitty | Par défaut, `Ctrl+Maj+C/V` copie ou colle, `Ctrl+Maj+T` ouvre un onglet, `Ctrl+Tab` va au suivant et `Ctrl+Maj+Tab` au précédent. `Ctrl+Maj+Entrée` ouvre un panneau, `Ctrl+Maj+F3` liste les actions et `Ctrl+Maj+F5` recharge la configuration. [Guide Kitty](kitty.md#raccourcis-clavier) |
| Foot | Par défaut, `Ctrl+Maj+C/V` copie ou colle, `Ctrl+Maj+R` recherche dans l’historique, `Ctrl+Maj+N` ouvre un terminal et `Ctrl+0` réinitialise la police. [Manuel Foot](https://man.archlinux.org/man/foot.ini.5.en) |

### Invite, aide et système

| Outil | Raccourcis et commandes utiles |
| --- | --- |
| Starship | L’invite se met à jour avec le dossier et l’état Git. `starship explain` explique les modules visibles. |
| Tealdeer | `tldr COMMANDE` affiche des exemples, par exemple `tldr tar`. `tldr --update` télécharge la mise à jour du cache. |
| btop | `bt` lance le moniteur. Par défaut, `F1` ouvre l’aide, `F2` les options et `q` quitte. [Touches btop](https://github.com/aristocratos/btop/blob/v1.4.7/src/btop_input.cpp) |
| Fastfetch | `fastfetch` affiche le résumé du système. [Guide Fastfetch](fastfetch.md) |
| duf | `duf` affiche l’espace des disques et montages. `dfh` reste le raccourci Zsh pour `df -h`. |
| Pacman | `pkgsearch MOTIF` cherche un paquet, `pkginfo PAQUET` décrit la version installée, `pkgfiles PAQUET` liste ses fichiers et `orphans` liste les dépendances orphelines. `update` lance une mise à jour complète. |
| systemd et journalctl | `services` liste les services en cours, `logs` ouvre le journal et `j` le suit en direct. `Ctrl+C` interrompt le suivi. |
| Réseau | `ipa` affiche les adresses, `ipr` les routes, `ports` les sockets en écoute et `dns` l’état de la résolution DNS lorsque `resolvectl` est disponible. |
| Pare-feu | `gufw` ouvre l’interface UFW et `firewall-config` l’interface firewalld. Le [guide pare-feu](firewalld.md) explique quand utiliser chaque interface. |
| Flatpak | `flatpak list --user --app` liste les applications du compte. `flatpak run IDENTIFIANT` lance une application. [Catalogue des identifiants](flatpak-install.md) |
| GNU Stow | `stow --simulate --verbose` avec la cible et les paquets souhaités affiche le plan de liens. [Exemples Stow](dotfiles.md) |

