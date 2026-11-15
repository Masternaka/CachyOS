# CachyOS

Ce dépôt prépare la personnalisation de mon ordinateur personnel sous CachyOS,
avec Niri. Modifier le dépôt n'applique rien sur l'ordinateur : les installations
et les changements système restent des actions distinctes à autoriser.

## Repères

Les numéros identifient les scripts ; ils ne constituent pas un ordre obligatoire
d'exécution. Examiner leurs prérequis et leurs simulations avant de les appliquer.

| Script | Fonction | Lancement réel |
| --- | --- | --- |
| [01 · Services systemd](docs/systemd-services.md) | Bluetooth, serveur SSH, TRIM et nettoyage périodique du cache Pacman | Avec `sudo`, sans confirmation intégrée |
| [02 · Pare-feu](docs/firewalld.md) | Détection UFW/firewalld, désactivation au choix, interface graphique ou règles firewalld | Avec `sudo` et confirmation |
| [03 · Réglages Pacman](docs/pacman-settings.md) | Téléchargements parallèles | Avec `sudo`, saisie interactive ou options explicites |
| [04 · Zsh et outils du terminal](docs/zsh.md) | Outils, configurations, GNU Stow et changement de shell facultatif | Compte normal, `sudo` si des paquets natifs manquent |
| [05 · Paquets natifs](docs/package-install.md) | 62 paquets des dépôts officiels utilisés par CachyOS | Sans `sudo` conseillé, élévation pour Pacman après confirmation |
| [06 · Applications Flatpak](docs/flatpak-install.md) | Prérequis natifs et sélection parmi 13 applications Flathub personnelles | Compte normal, `sudo` si des prérequis natifs manquent |
| [07 · QEMU et Virt-Manager](docs/qemu.md) | KVM, libvirt, UEFI, TPM, stockage et réseau virtuel | Compte normal, confirmations avant les actions `sudo` |
| [08 · master-archrepo](docs/master-archrepo.md) | Dépôt Pacman tiers pour SambaPilot et DotfilePilot | Avec `sudo` et une empreinte vérifiée, sans simulation ni confirmation intégrée |
| [09 · Purge d’applications](docs/purge-applications.md) | Inventaire Pacman et Flatpak, sélection interactive et configurations ciblées | Simulation par défaut, `sudo` pour retirer les paquets natifs |
| [10 · Disques secondaires](docs/disk-setup.md) | Labels ext4 et propriété des quatre volumes de données | Simulation par défaut, `sudo` et confirmation pour appliquer |

Les [guides détaillés](docs/README.md) et le [catalogue Dotfiles](Dotfiles/README.md)
décrivent les fichiers, les sauvegardes et les limites de validation.

Les services exigent notamment `bluez`, `util-linux` et `pacman-contrib` déjà
présents. Le script 06 propose d’installer Flatpak et les prérequis manquants.
GNU Stow est proposé par l'installateur Zsh, même en mode copie.

Depuis la racine du dépôt, utiliser `bash "nom du script.sh" --help` dans
Fish ou Zsh. Commencer par `--dry-run` quand le guide le propose. Les
simulations et applications réelles ont chacune leurs prérequis.
Les statuts s’affichent avec leur libellé. **Vert** indique un succès vérifié
ou un service `active`. **Bleu** indique un état déjà conforme, un résultat
inchangé ou un démarrage `enabled`. **Cyan** signale le plan et la simulation,
**jaune** un état inactif ou un avertissement, **rouge** un échec et **violet**
une sauvegarde ou un inventaire. Les scripts omettent leurs couleurs sur
les sorties redirigées ou avec `NO_COLOR=1`.

## Installation des logiciels

`05 - package_install.sh` propose 62 paquets, avec une sélection facultative par
groupes. Il vérifie la sélection dans les dépôts officiels activés sur CachyOS,
affiche les cibles `dépôt/paquet`, puis demande confirmation
avant une transaction Pacman avec mise à jour complète. Aucun recours à l'AUR,
aucun nettoyage automatique du cache et aucun déploiement des Dotfiles.

```bash
bash "05 - package_install.sh" --list
bash "05 - package_install.sh" --groups virtualisation,terminal --list
bash "05 - package_install.sh" --dry-run
```

La simulation ne crée aucun fichier et n'utilise pas sudo. Les dépôts tiers ou
de test activés et les paquets introuvables sont bloquants. Voir le
[guide du catalogue et du contrôle de provenance](docs/package-install.md)
pour les sources consultées, les confirmations, les inventaires et leurs limites.

Un paquet déjà installé et à jour est conservé grâce à `--needed`. Une version
plus récente est mise à jour. `-Syu` concerne l'ensemble du système, y compris
les paquets qui ne figurent pas dans cette liste. Distrobox et Podman sont inclus
pour préparer notamment BoxBuddy.

## Applications Flatpak

`06 - flatpak_install.sh` se lance depuis le compte utilisateur. Il propose
d’installer les prérequis natifs manquants avec Pacman. Il prépare ensuite
13 applications Flathub et leurs runtimes avec `flatpak --user`.

```bash
bash "06 - flatpak_install.sh" --list
bash "06 - flatpak_install.sh" --dry-run
bash "06 - flatpak_install.sh" --dry-run --only 2,3
```

Dans le menu, saisir les numéros séparés par des virgules ou appuyer sur Entrée
pour sélectionner tout le catalogue. Un seul accord lance le lot sélectionné.
Le [guide Flatpak](docs/flatpak-install.md) détaille les prérequis, la portée
de l’accord et les inventaires.

## QEMU et Virt-Manager

```bash
bash "07 - install_qemu.sh" --dry-run
```

Le [guide QEMU](docs/qemu.md) décrit le réseau NAT, le stockage, les contrôles KVM
et les options d’accès local à `qemu:///system`.

## Installation et configuration des outils du terminal

`04 - install_zsh.sh` utilise [Dotfiles](Dotfiles/README.md) comme source des
configurations et propose seize modules : Zsh, Starship, Yazi, btop, Tealdeer, Bat, FZF, Zoxide,
Eza, Ripgrep, fd, Delta, Lazygit, Kitty, Foot et duf. Les deux terminaux sont configurés
avec **JetBrainsMono Nerd Font**. `duf` ne nécessite aucun fichier à déployer.

Depuis Fish, ouvrir le menu et prévisualiser ses choix avec Bash :

```bash
bash "04 - install_zsh.sh" --interactive --dry-run
bash "04 - install_zsh.sh" --dry-run --mode stow --only zsh,starship,kitty,foot
bash "04 - install_zsh.sh" --dry-run --only starship --palette macchiato
bash "04 - install_zsh.sh" --check-scripts
```

Starship propose **Catppuccin Powerline** en Mocha, Macchiato, Frappé et Latte
dans le menu et avec `--palette`. Mocha est la variante par défaut.
[Preset Starship](https://starship.rs/presets/catppuccin-powerline)

Le mode `copy` par défaut installe des copies et préserve les autres réglages
Kitty/Foot lors du changement de police. Le mode `stow` crée des liens vers les
configurations versionnées après sauvegarde des conflits. Lancer sans `sudo`.
GNU Stow est également proposé à l'installation en mode copie pour un usage futur,
avec la confirmation habituelle ; aucun lien n'est créé dans ce mode.

Après autorisation d'une exécution réelle, retirer `--dry-run`. Les paquets et
la mise à jour système, fzf-tab éventuel, le déploiement, le cache Tealdeer et
le changement facultatif du shell demandent des accords distincts. Le shell
de connexion détecté est conservé par défaut. Le rapport final affiche les
actions effectuées et le script de restauration lorsqu’il est disponible.

Les alias restent dans un fichier séparé chargé par `.zshrc`. Les réglages locaux
`~/.zshrc.local.pre` et `~/.zshrc.local` sont conservés. Voir le [guide complet](docs/zsh.md)
pour la sélection des modules, les fichiers concernés, les limites des tests et le
retour arrière. Aucun logiciel ni lien n'est installé par la présence de ces fichiers.

Le dossier Dotfiles contient aussi Ghostty pour Linux/Niri et Fastfetch, soit
17 paquets Stow. Ces deux configurations supplémentaires ne sont pas des modules
de `04 - install_zsh.sh` ; leur déploiement Stow reste séparé. Installer les
logiciels avec `05 - package_install.sh` ne déploie pas leurs configurations.

## Services systemd

Bluetooth, serveur SSH, TRIM et nettoyage du cache Pacman. La simulation
affiche les actions par unité. L’application démarre et active les unités
sans demander de confirmation dans le script.

```bash
bash "01 - systemd_services.sh" --dry-run
```

Le [guide systemd](docs/systemd-services.md) détaille les paquets requis,
les contrôles après application et le fichier de retour arrière.

## Pare-feu

Le menu de `02 - firewalld_settings.sh` affiche l’état d’UFW et de firewalld.
Il permet de désactiver l’un des deux ou de conserver les deux états, puis
d’installer Gufw ou Firewall Config. Le rapport final indique les actions et le
chemin de la sauvegarde lorsqu’elle a été créée.

```bash
bash "02 - firewalld_settings.sh" --interactive --dry-run
```

Avec `--services`, le script règle les règles et la zone d’un firewalld **déjà
installé et actif**. Un UFW actif, activé au démarrage ou dans un état
non pris en charge bloque ce mode.

```bash
bash "02 - firewalld_settings.sh" --dry-run --services ssh,samba
# SSH seul, autre zone :
bash "02 - firewalld_settings.sh" --dry-run --zone home --services ssh
```

Les choix de `--services` sont `ssh`, `samba`, `ssh,samba` et `none`.
`none` n'ajoute aucun service ; les règles existantes sont conservées. Le script
ajoute les règles manquantes dans les configurations active et permanente sans
rechargement global, puis définit la zone par défaut. Les serveurs SSH et Samba
ne sont ni installés ni démarrés. Les affectations explicites des interfaces et
connexions ne sont pas changées. Les ouvertures portent sur toute la zone choisie.

Après autorisation sur la cible, appliquer avec `sudo bash` et sans `--dry-run`.
Une confirmation précède la sauvegarde privée sous `/var/tmp/cachyos-firewall.*`.
Un changement détecté pendant l'attente bloque l'application. Les échecs et
interruptions interceptables déclenchent une tentative de retour arrière ciblé.
Le script affiche aussi `sudo bash CHEMIN/restaurer.sh`, à examiner et utiliser
avant toute autre modification volontaire. Il rétablit l'ancienne zone et retire
uniquement les autorisations que cette session devait ajouter. Une copie de
`/etc/firewalld` et les inventaires restent disponibles, sans restauration globale
automatique qui écraserait d'autres règles. Une coupure ou SIGKILL n'est pas intercepté.
Voir le [guide pare-feu](docs/firewalld.md) pour les limites et la migration UFW.

## Téléchargements parallèles de Pacman

Choisir une valeur de 0 à 20 ou demander une estimation CPU/RAM.
La simulation laisse la configuration proposée sur la sortie standard.

```bash
bash "03 - pacman_settings.sh" --dry-run --value 5
bash "03 - pacman_settings.sh" --dry-run --auto
```

Le [guide Pacman](docs/pacman-settings.md) explique la valeur `0`, le
contrôle par `pacman-conf`, la sauvegarde et la restauration.

## Dépôt master-archrepo

`08 - install-master-archrepo.sh` configure le dépôt de SambaPilot et DotfilePilot.
L’aide est consultable sans privilège. L’ajout réel modifie la confiance Pacman
et nécessite l’empreinte OpenPGP vérifiée auprès du propriétaire de la clé.

```bash
bash "08 - install-master-archrepo.sh" --help
```

Le [guide master-archrepo](docs/master-archrepo.md) couvre l’ajout, la
vérification et le retour arrière. Avec ce dépôt activé, le script `05`
refuse la transaction, car il exige des dépôts officiels uniquement.

## Raccourcis et commandes par outil

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
| Yazi | `y` ouvre Yazi et reporte le dernier dossier dans Zsh à la sortie. Dans Yazi, `g` puis `h` ouvre le dossier personnel, `g` puis `c` ouvre `~/.config` et `g` puis `/` ouvre la racine. Par défaut, `Entrée` ouvre le fichier, `O` choisit l’application, `q` quitte et `F1` ou `~` ouvre l’aide. [Éditeur Yazi et erreur 127](docs/zsh.md#ouvrir-un-fichier-texte-dans-yazi) · [Guide Yazi](https://yazi-rs.github.io/docs/quick-start/#keybindings) |
| Eza | `ll` liste les détails, `la` inclut les fichiers cachés, `lt` affiche l’arbre et `l` liste un nom par ligne. |
| Bat | `ccat FICHIER` affiche un fichier colorisé sans pagination. `bat FICHIER` utilise la pagination selon la sortie. |
| Ripgrep | `rg -n 'motif' .` cherche dans le contenu avec les numéros de ligne. `rg --files` liste les fichiers examinables. |
| fd | `fd 'motif'` cherche par nom. `fd -t d 'motif'` limite la recherche aux dossiers. |
| Git | `gs` affiche l’état court, `gd` les différences de travail, `gds` les différences indexées, `gl` le graphe des commits et `gb` les branches locales avec leur suivi. |
| Delta | `gd` et `gds` utilisent Delta lorsque le pager Git est configuré et que la sortie est un terminal. Dans le pager `less`, `q` revient au shell. |
| Lazygit | `lg` lance l’interface. Par défaut, `?` liste les touches contextuelles et `q` quitte. [Raccourcis Lazygit](https://github.com/jesseduffield/lazygit/blob/master/docs/keybindings/Keybindings_en.md) |
| Micro | `micro FICHIER` ouvre l’éditeur. Les touches de base sont `Ctrl+S` pour enregistrer, `Ctrl+Q` pour quitter et `Ctrl+E` pour ouvrir la barre de commandes. [Raccourcis Micro](https://github.com/zyedidia/micro/blob/master/runtime/help/defaultkeys.md) |
| VS Code | Par défaut sous Linux, `Ctrl+P` ouvre un fichier par son nom et `Ctrl+Maj+P` ouvre la palette de commandes. [Raccourcis VS Code](https://code.visualstudio.com/docs/reference/default-keybindings) |

Les alias `ls`, `cat`, `cp`, `mv` et `rm` facultatifs suivent le choix
`--replace-commands` du script 04. [Liste des alias Zsh](Dotfiles/zsh/.config/cachyos-zsh/aliases.zsh)

### Terminaux

| Outil | Raccourcis |
| --- | --- |
| Ghostty | Le dépôt définit `F11` pour le plein écran, `Ctrl+Maj+T` pour un onglet et `Ctrl+Maj+W` pour fermer le panneau actif. `Ctrl+Tab` et `Ctrl+Maj+Tab` changent d’onglet, `Ctrl+Maj+←/→` les déplacent et `Ctrl+Maj+I` les renomme. |
| Ghostty, panneaux | `Ctrl+Maj+D` divise à droite, `Ctrl+Maj+Alt+D` vers le bas, `Ctrl+Maj+H/J/K/L` sélectionne gauche/bas/haut/droite et `Ctrl+Maj+Alt+Flèches` redimensionne. `Ctrl+Maj+Entrée` bascule le zoom, `Ctrl+Maj+E` égalise les panneaux. |
| Ghostty, historique | `Ctrl+Maj+↑/↓` rejoint les invites avec l’intégration du shell, `Ctrl+Maj+F` recherche le texte sélectionné et `Ctrl+Maj+S` ouvre l’historique du panneau dans un fichier. `Ctrl+Maj+R` réinitialise le terminal. [Configuration Ghostty](Dotfiles/ghostty/.config/ghostty/config) · [Actions Ghostty](https://ghostty.org/docs/config/keybind/reference) |
| Kitty | Par défaut, `Ctrl+Maj+C/V` copie ou colle, `Ctrl+Maj+T` ouvre un onglet, `Ctrl+Tab` va au suivant et `Ctrl+Maj+Tab` au précédent. `Ctrl+Maj+Entrée` ouvre un panneau, `Ctrl+Maj+F3` liste les actions et `Ctrl+Maj+F5` recharge la configuration. [Guide Kitty](Dotfiles/kitty/.config/kitty/README.md#raccourcis-clavier) |
| Foot | Par défaut, `Ctrl+Maj+C/V` copie ou colle, `Ctrl+Maj+R` recherche dans l’historique, `Ctrl+Maj+N` ouvre un terminal et `Ctrl+0` réinitialise la police. [Manuel Foot](https://man.archlinux.org/man/foot.ini.5.en) |

### Invite, aide et système

| Outil | Raccourcis et commandes utiles |
| --- | --- |
| Starship | L’invite se met à jour avec le dossier et l’état Git. `starship explain` explique les modules visibles. |
| Tealdeer | `tldr COMMANDE` affiche des exemples, par exemple `tldr tar`. `tldr --update` télécharge la mise à jour du cache. |
| btop | `bt` lance le moniteur. Par défaut, `F1` ouvre l’aide, `F2` les options et `q` quitte. [Touches btop](https://github.com/aristocratos/btop/blob/v1.4.7/src/btop_input.cpp) |
| Fastfetch | `fastfetch` affiche le résumé du système. [Guide Fastfetch](Dotfiles/fastfetch/.config/fastfetch/README.md) |
| duf | `duf` affiche l’espace des disques et montages. `dfh` reste le raccourci Zsh pour `df -h`. |
| Pacman | `pkgsearch MOTIF` cherche un paquet, `pkginfo PAQUET` décrit la version installée, `pkgfiles PAQUET` liste ses fichiers et `orphans` liste les dépendances orphelines. `update` lance une mise à jour complète. |
| systemd et journalctl | `services` liste les services en cours, `logs` ouvre le journal et `j` le suit en direct. `Ctrl+C` interrompt le suivi. |
| Réseau | `ipa` affiche les adresses, `ipr` les routes, `ports` les sockets en écoute et `dns` l’état de la résolution DNS lorsque `resolvectl` est disponible. |
| Pare-feu | `gufw` ouvre l’interface UFW et `firewall-config` l’interface firewalld. Le [guide pare-feu](docs/firewalld.md) explique quand utiliser chaque interface. |
| Flatpak | `flatpak list --user --app` liste les applications du compte. `flatpak run IDENTIFIANT` lance une application. [Catalogue des identifiants](docs/flatpak-install.md) |
| GNU Stow | `stow --simulate --verbose` avec la cible et les paquets souhaités affiche le plan de liens. [Exemples Stow](Dotfiles/README.md) |

## Diagnostic et validation du dépôt

```bash
# Lecture seule, sans sudo, installation ni téléchargement :
python3 -B scripts/diagnostic.py
# Syntaxes et cohérence documentaire seulement :
python3 -B scripts/verifier_depot.py --statique
# Avec tests dans des dossiers temporaires isolés :
python3 -B scripts/verifier_depot.py
```

Le diagnostic signale les outils absents, l'état des unités et les configurations
à examiner. Il ne résout aucun conflit automatiquement. Lance la vérification
du dépôt sur ton ordinateur avant d’envoyer les changements sur GitHub. Le
[guide de validation](docs/validation.md) décrit les contrôles et leurs limites.
