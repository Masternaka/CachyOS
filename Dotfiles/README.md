# Dotfiles CachyOS pour GNU Stow

Ce dossier prépare une installation future par liens symboliques. Aucun paquet
n'est installé et aucun lien n'est créé dans le dossier personnel par sa simple
présence dans le dépôt. Les 17 sous-dossiers ci-dessous sont des paquets Stow
autonomes. Le script `04 - install_zsh.sh` sait déployer les 15 modules de Zsh à
Foot par copies ou avec Stow, après un plan et des confirmations : voir le
[guide](../docs/zsh.md). Ghostty et Fastfetch se déploient séparément.
Le seizième module de l'installateur, `duf`, installe seulement l'outil : aucun
fichier de configuration ni paquet Stow n'est nécessaire.
Son contenu reproduit les chemins relatifs au dossier personnel cible.

```text
Dotfiles/
├── zsh/       .zshrc et .config/cachyos-zsh/aliases.zsh
├── starship/  .config/starship.toml
├── yazi/      .config/yazi/{yazi,keymap,theme}.toml
├── btop/      .config/btop/btop.conf
├── tealdeer/  .config/tealdeer/config.toml
├── bat/       .config/bat/config
├── fzf/       .config/fzf/config.zsh
├── zoxide/    .config/zoxide/config.zsh
├── eza/       .config/eza/config.zsh
├── ripgrep/   .config/ripgrep/config
├── fd/        .config/fd/ignore
├── delta/     .config/git/config
├── lazygit/   .config/lazygit/config.yml
├── kitty/     .config/kitty/kitty.conf, thèmes, accès rapide et README.md
├── foot/      .config/foot/foot.ini
├── ghostty/   .config/ghostty/config
└── fastfetch/ .config/fastfetch/config.jsonc et README.md
```

## Ce qui est préparé

| Paquet Stow | Réglages et activation |
|---|---|
| `zsh` | Suggestions, complétions, historique ↑/↓, alias séparés, FZF, Zoxide, Yazi `y` et Starship lorsque les outils sont présents. Aucun gestionnaire de plugins. |
| `starship` | Invite Catppuccin Powerline (Mocha) avec dossier, Git, horloge et durée des commandes. La même source est utilisée en copie ou avec Stow. |
| `yazi` | Tri naturel, dossiers en premier, trois panneaux, touches `g h`, `g c` et `g /`, couleurs Mocha intégrées sans flavor externe. |
| `btop` | CPU/RAM/réseau/processus, Celsius, rafraîchissement de 1,5 s et arrière-plan du terminal. Thème intégré Default, sans téléchargement. |
| `tealdeer` | Exemples lisibles et pager ; mise à jour automatique du cache désactivée. `tldr --update` reste une action séparée à autoriser. |
| `bat` | Numéros, changements et en-tête ; thème ANSI intégré et pagination automatique. `ccat` force la lecture sans pager. |
| `fzf` | Fenêtre à 60 %, présentation inversée, bord arrondi et couleurs Mocha. Le paquet Zsh charge ce fichier avant FZF. |
| `zoxide` | Affichage du dossier choisi par `z`, sans déplacer ni gérer sa base de données. Chargé par le paquet Zsh. |
| `eza` | Couleurs ANSI des dossiers, exécutables et liens ; alias `ll`, `la`, `lt` dans le paquet Zsh. |
| `ripgrep` | Recherche sensible à la casse uniquement si la requête contient une majuscule, exclusion de `.git`. Le paquet Zsh configure `RIPGREP_CONFIG_PATH`. |
| `fd` | Exclusions globales `.DS_Store` et `__pycache__`. Utiliser `fd --no-ignore` pour les contourner. |
| `delta` | Pager Git avec numéros et navigation. Nécessite `git-delta` installé. Aucune identité, URL distante ou authentification n'est fournie. |
| `lazygit` | Couleurs Mocha et icônes Nerd Font 3 ; fetch et contrôles de mise à jour automatiques désactivés. |
| `kitty` | JetBrainsMono Nerd Font avec variantes automatiques ; source à 12 points et thème Catppuccin Macchiato, taille existante préservée par le mode copie. [Guide Kitty](kitty/.config/kitty/README.md). |
| `foot` | JetBrainsMono Nerd Font, 11 points pour une configuration neuve ; taille existante préservée par le mode copie. |
| `ghostty` | Configuration Linux/Niri : thèmes Catppuccin, JetBrainsMono Nerd Font 14 points, transparence et raccourcis Ctrl+Maj. Déploiement Stow séparé. |
| `fastfetch` | Informations système, environnement, matériel et audio, sections colorées et icônes Nerd Font. Déploiement Stow séparé ; [guide du paquet](fastfetch/.config/fastfetch/README.md). |

Les fichiers `fzf/config.zsh`, `zoxide/config.zsh` et `eza/config.zsh` sont des
fragments d'environnement chargés par **notre paquet Zsh** ; ces outils ne les
lisent pas directement. Sans ce paquet Zsh, leur chargement doit être ajouté à
votre configuration personnelle. Les variables déjà définies sont respectées.

Les complétions, suggestions, coloration et recherche d'historique Zsh restent
fournies par les paquets installés. Leur code n'est pas copié dans ce dépôt.
La configuration cherche fzf-tab dans des emplacements locaux usuels ou dans la
copie `fzf-tab-v1.3.0` préparée par l'installateur. Pour un autre emplacement,
définir `CACHYOS_ZSH_FZF_TAB_SOURCE` dans `~/.zshrc.local.pre`. Aucune extension
n'est téléchargée ou mise à jour à l'ouverture du terminal.

## Préparer le déploiement

Ces configurations visent **CachyOS avec Zsh, les chemins XDG habituels et Yazi
26.9**. Les outils concernés et GNU Stow doivent déjà être installés avant une
application réelle. Ne pas lancer les commandes avec `sudo`.

Stow déploie des fichiers, pas des logiciels, et ne change pas le shell du compte.
Les fichiers `.config` de cette arborescence visent `~/.config`. Si votre
`XDG_CONFIG_HOME` ou votre `ZDOTDIR` est différent, adapter le plan avant de créer
les liens ; Stow ne réécrit pas ces chemins en fonction des variables.

1. Examiner les fichiers et sélectionner seulement les paquets voulus.
2. Inventorier les fichiers et liens déjà présents, ainsi que les éventuels
   `.stowrc` dans votre environnement. Prévoir une sauvegarde avant toute
   modification réelle.
3. Depuis la racine du dépôt, examiner le plan suivant :

```bash
stow --dir="$PWD/Dotfiles" --target="$HOME" --no-folding --simulate --verbose \
  --stow zsh starship yazi btop tealdeer bat fzf zoxide eza ripgrep fd delta lazygit kitty foot
```

Le choix explicite de `--target` est indispensable : sans lui, Stow prend par
défaut le parent de `Dotfiles`, qui serait ici le dépôt. `--no-folding` garde de
vrais dossiers dans la cible et crée les liens fichier par fichier.

Un fichier ordinaire existant au même emplacement est un conflit à résoudre
après examen et sauvegarde. **Ne pas utiliser `--adopt` pour contourner le conflit** :
cette option peut remplacer les fichiers de ce dépôt par ceux de la cible.
Ne pas supprimer ou déplacer automatiquement une configuration personnelle.

Après votre autorisation explicite de l'application, et seulement après avoir
résolu les conflits et sauvegardé les fichiers concernés, la commande est la même
sans `--simulate` :

```bash
stow --dir="$PWD/Dotfiles" --target="$HOME" --no-folding --verbose \
  --stow zsh starship yazi btop tealdeer bat fzf zoxide eza ripgrep fd delta lazygit kitty foot
```

Un choix réduit est possible, par exemple `--stow yazi btop tealdeer`. Ne pas lancer
`stow *` : les documents à la racine de ce dossier ne sont pas des paquets.

### Ghostty et Fastfetch

Le script de paquets peut installer ces logiciels mais ne déploie pas leurs
configurations. Ils ne sont pas acceptés par `--only` dans l'installateur Zsh.
Depuis la racine du dépôt, leur plan Stow séparé est :

```bash
stow --dir="$PWD/Dotfiles" --target="$HOME" --no-folding --simulate --verbose \
  --stow ghostty fastfetch
```

Après examen, sauvegarde des éventuels conflits et autorisation, retirer
`--simulate` pour appliquer ce plan. Comme pour les autres paquets Stow manuels,
aucune sauvegarde ou restauration automatique n'est créée. Le paquet Fastfetch
lie également son README dans `~/.config/fastfetch/README.md`.

Ghostty vise Linux/Wayland avec Niri, sans réglages macOS. Niri contrôle le
placement et la taille des fenêtres en mosaïque ; les dimensions du fichier sont
indicatives. L'exemple de règle Niri pour le flou reste commenté : aucun fichier
Niri n'est modifié. Vérifier son adaptation à la version installée avant une
application séparée. Les raccourcis utilisent F11 et Ctrl+Maj, en laissant Super
disponible pour Niri. Les préférences locales facultatives peuvent être placées
dans `~/.config/ghostty-local.conf`, chargé par la configuration versionnée.

Fastfetch affiche les informations disponibles dans la session ; certains
modules peuvent ne pas produire de valeur sous Niri. Il n'est pas ajouté
automatiquement au démarrage du shell.

## Personnalisation et coexistence

Après déploiement, les liens pointent vers ce dépôt : modifier un fichier lié
modifie sa source versionnée. Certains logiciels peuvent réécrire leur
configuration ou remplacer le lien ; vérifier l'état des liens après les réglages
faits dans leurs interfaces. Ne pas lancer de logiciel pendant une opération Stow.

Le paquet Zsh charge `~/.zshrc.local.pre` avant les réglages, puis les fichiers
Stow, et `~/.zshrc.local` avant Starship et les derniers plugins. Ces deux fichiers
personnels ne sont ni fournis ni remplacés par Stow. Ils permettent de conserver
vos ajustements locaux. Exemples à envisager dans le fichier précoce :

```zsh
# Désactivé par défaut : remplacer certaines commandes usuelles par les alias.
# export CACHYOS_ZSH_REPLACE_COMMANDS=true
# Chemin personnalisé vers un fzf-tab déjà installé :
# export CACHYOS_ZSH_FZF_TAB_SOURCE="$HOME/outils/fzf-tab/fzf-tab.plugin.zsh"
```

`STARSHIP_CONFIG`, `FZF_DEFAULT_OPTS`, `EZA_COLORS` et `RIPGREP_CONFIG_PATH` déjà
choisis restent prioritaires. Les paquets Kitty et Foot sélectionnent
JetBrainsMono Nerd Font. Le script propose le paquet de police et vérifie sa
présence avec Fontconfig, sans ouvrir ou fermer de fenêtre. Rouvrir les terminaux
pour lire les nouveaux fichiers ; leur rendu reste à vérifier sur la machine cible.
Les aperçus PDF, vidéo, etc. de Yazi dépendent de ses outils facultatifs installés.

Le paquet `delta` fournit `~/.config/git/config`, pas `~/.gitconfig`. Git peut lire
les deux ; avec les commandes Stow manuelles, vos réglages dans `~/.gitconfig`
peuvent surcharger ce pager. Le script automatisé annonce aussi, si nécessaire,
un complément ciblé du `.gitconfig` ordinaire existant pour le pager et
`diffFilter`, avec sauvegarde intégrale et identité conservée. Ce complément est
copié même en mode Stow ; un `.gitconfig` symbolique est refusé. Le module `lazygit` reste
utilisable sans Delta et ne le lance pas automatiquement.

**Source commune, deux modes :** `04 - install_zsh.sh` utilise maintenant ce dossier.
Son mode `copy` copie les fichiers et adapte seulement les polices des configurations
Kitty/Foot existantes. Son mode `stow` crée des liens fichier par fichier et résout
les conflits après sauvegarde et confirmation, sans `--adopt`. Les sources du dépôt
ne sont jamais écrasées. Un lien vers une autre origine reste refusé.

Le script crée aussi `~/.config/cachyos-zsh/install-settings.zsh` pour ses options
et le chemin fzf-tab de cette machine. Ce fichier est copié, sauvegardé et restauré
même en mode Stow ; il n'appartient pas aux sources portables de ce dossier.
Le `.zshrc` le charge avant `~/.zshrc.local.pre`, qui reste prioritaire. Les anciens
modèles `config/zsh` sont conservés, mais ne sont plus utilisés par l'installateur.

Les commandes Stow manuelles de ce guide n'installent aucun logiciel et ne créent
pas de journal de restauration. Pour une session automatisée avec sauvegardes et
retour arrière, utiliser le script et le [guide associé](../docs/zsh.md).

## Retirer les liens

Examiner d'abord la suppression prévue, en choisissant les paquets concernés :

```bash
stow --dir="$PWD/Dotfiles" --target="$HOME" --no-folding --simulate --verbose \
  --delete yazi btop tealdeer
```

Après autorisation, retirer `--simulate` pour délier ces fichiers. Cette opération
ne désinstalle pas les outils, ne restaure pas les anciennes configurations et ne
supprime pas les sources dans le dépôt. Conserver les sauvegardes pour restaurer
ensuite les fichiers antérieurs. Les répertoires restés vides peuvent subsister.

## Vérifications

```bash
python3 -B -m unittest discover -s tests -p 'test_dotfiles.py' -v
```

Les tests vérifient les chemins, les syntaxes TOML/YAML/Zsh, le fichier Git et le
chargement des fragments dans un HOME temporaire. Les liens du test de chargement
sont créés directement pour tester la configuration ; ce n'est pas un test de
GNU Stow. Un test distinct appelle le vrai Stow dans un dossier temporaire lorsqu'il
est déjà disponible, sinon il est explicitement ignoré. Aucun outil manquant n'est
installé pour les vérifications. Un parseur manquant produit aussi un test ignoré.

Sur l'hôte de préparation, Stow et les applications de personnalisation concernées
ne sont pas disponibles ; Zsh et Git sont utilisés pour les contrôles décrits.
Le catalogue attendu est maintenant vérifié par les noms explicites des 17 paquets.
Ghostty et Fastfetch nécessitent aussi une validation native distincte. Voir le
[guide de validation](../docs/validation.md) pour les outils absents et les limites.
Le rendu et le comportement natif sous CachyOS restent à valider.
Aucun déploiement dans le dossier personnel n'a été effectué.

Références : [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html),
[configuration Yazi](https://yazi-rs.github.io/docs/configuration/yazi/),
[Tealdeer](https://github.com/tealdeer-rs/tealdeer/blob/main/docs/src/config.md),
[Lazygit](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md),
[Delta](https://dandavison.github.io/delta/configuration.html).
