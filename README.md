# CachyOS

Ce dépôt contient des scripts et des configurations pour installer et configurer un système CachyOS / Arch Linux : logiciels, paquets KDE, AUR, Flatpak, alias Fish et Zsh, et une configuration Zsh moderne.

## Structure du dépôt

- `Installation de logiciels/`
  - `install-pacman-packages.sh` : installe les paquets des dépôts officiels pacman.
  - `install-kde-packages.sh` : installe les paquets KDE/Plasma.
  - `install-aur-packages.sh` : installe `yay` si nécessaire, puis installe les paquets AUR.
  - `install-flatpak-packages.sh` : installe Flatpak, active Flathub et installe des applications Flatpak.
  - `liste des paquets/` : fichiers de configuration shell contenant les tableaux de paquets utilisés par les scripts.

- `Configuration Fish alias/`
  - `aliases.fish` : alias Fish personnalisés.
  - `install-fish-aliases.sh` : installe les alias Fish dans `~/.config/fish/conf.d/personal_aliases.fish`.

- `Configurations ZSH/`
  - `install-zsh.sh` : installe Zsh, Starship, zinit, plugins, et outils CLI modernes.
  - `Configuration alias/`
    - `aliases.zsh` : alias Zsh personnalisés.
    - `install-zsh-aliases.sh` : installe les alias Zsh et configure `~/.zshrc` pour les charger.

- `Configuration Paru/`
  - `mod_paru.sh` : active l'option `BottomUp` dans `/etc/paru.conf` (ou un autre fichier paru.conf).

- `Configuration FirewallD/`
  - `mod_firewalld.sh` : configure Firewalld pour utiliser la zone `home` par défaut.

## Utilisation générale

Chaque script peut être lancé directement depuis la racine du dépôt. Les scripts utilisent des fichiers de configuration et des options qui permettent de personnaliser l'installation et le comportement.

Avant de commencer :

- placez-vous dans le dossier racine du dépôt : `cd /chemin/vers/CachyOS`
- vérifiez que le script est exécutable : `chmod +x ./Installation\ de\ logiciels/*.sh ./Configuration\ Fish\ alias/*.sh ./Configurations\ ZSH/*.sh ./Configurations\ ZSH/Configuration\ alias/*.sh ./Configuration\ Paru/*.sh`
- exécutez les scripts avec `./Chemin/vers/script.sh` ou en citant les chemins contenant des espaces.

### Installation de logiciels

#### Paquets pacman

1. Modifier `Installation de logiciels/liste des paquets/pacman-packages.conf`.
2. Lancer :

```bash
./Installation\ de\ logiciels/install-pacman-packages.sh
```

Pour installer des paquets précis :

```bash
./Installation\ de\ logiciels/install-pacman-packages.sh firefox vlc
```

Comment utiliser le script :

1. modifiez `Installation de logiciels/liste des paquets/pacman-packages.conf` pour mettre à jour la liste par défaut,
2. ou passez des paquets en arguments pour installer uniquement ceux-ci,
3. exécutez le script depuis la racine du dépôt,
4. et utilisez `--dry-run` pour vérifier les commandes avant exécution.

Options utiles :

- `--dry-run` : affiche les commandes sans les exécuter.
- `--no-update` : ne lance pas `sudo pacman -Syu`.
- `-c, --config FILE` : charge un fichier de configuration personnalisé.

Remarques :

- si aucun paquet n’est précisé, le script utilise la liste `PACMAN_PACKAGES` du fichier de configuration,
- le script nécessite `pacman` et `sudo`.

#### Paquets KDE/Plasma

1. Modifier `Installation de logiciels/liste des paquets/kde-packages.conf`.
2. Lancer :

```bash
./Installation\ de\ logiciels/install-kde-packages.sh
```

Pour installer des paquets KDE directement :

```bash
./Installation\ de\ logiciels/install-kde-packages.sh konsole dolphin kate
```

Options : `--dry-run`, `--no-update`, `-c, --config FILE`.

#### Paquets AUR

1. Modifier `Installation de logiciels/liste des paquets/aur-packages.conf`.
2. Lancer :

```bash
./Installation\ de\ logiciels/install-aur-packages.sh
```

Ce script :

- vérifie que `pacman` et `sudo` sont disponibles,
- refuse d’exécuter en root pour éviter les erreurs `makepkg`,
- installe `git` et `base-devel` si nécessaire,
- installe `yay` depuis l’AUR si nécessaire,
- installe ensuite les paquets listés.

Comment l’utiliser :

1. modifiez `Installation de logiciels/liste des paquets/aur-packages.conf` si vous voulez définir une liste par défaut,
2. exécutez le script depuis la racine du dépôt,
3. passez des noms de paquets en arguments pour installer seulement ceux-ci,
4. ajoutez `--dry-run` pour simuler l’installation.

Pour installer un paquet AUR spécifique :

```bash
./Installation\ de\ logiciels/install-aur-packages.sh visual-studio-code-bin
```

Options : `--dry-run`, `-c, --config FILE`.

#### Applications Flatpak

1. Modifier `Installation de logiciels/liste des paquets/flatpak-packages.conf`.
2. Lancer :

```bash
./Installation\ de\ logiciels/install-flatpak-packages.sh
```

Ce script :

- installe `flatpak` si nécessaire,
- active le dépôt `flathub`,
- installe les applications Flatpak listées.

Comment l’utiliser :

1. modifiez `Installation de logiciels/liste des paquets/flatpak-packages.conf` pour définir la liste de Flathub,
2. exécutez le script depuis la racine du dépôt,
3. passez des app-ids en arguments pour installer seulement celles-ci,
4. ajoutez `--dry-run` pour vérifier les commandes avant exécution.

Pour installer une application précise :

```bash
./Installation\ de\ logiciels/install-flatpak-packages.sh org.mozilla.firefox
```

Options : `--dry-run`, `-c, --config FILE`.

### Configuration des alias Fish

1. Modifier `Configuration Fish alias/aliases.fish`.
2. Lancer :

```bash
./Configuration\ Fish\ alias/install-fish-aliases.sh
```

Le fichier est copié dans :

```bash
~/.config/fish/conf.d/personal_aliases.fish
```

Options :

- `-c, --config FILE` : source d’alias personnalisée,
- `-t, --target FILE` : destination du fichier installé,
- `--dry-run` : simulateur.

Le script valide la syntaxe si `fish` est installé.

### Configuration des alias Zsh

1. Modifier `Configurations ZSH/Configuration alias/aliases.zsh`.
2. Lancer :

```bash
./Configurations\ ZSH/Configuration\ alias/install-zsh-aliases.sh
```

Le fichier est copié dans :

```bash
~/.config/zsh/personal_aliases.zsh
```

Le script ajoute un bloc géré dans `~/.zshrc` pour charger automatiquement ce fichier.

Options :

- `-c, --config FILE`
- `-t, --target FILE`
- `--zshrc FILE`
- `--dry-run`

### Installation et configuration Zsh

Lancer :

```bash
./Configurations\ ZSH/install-zsh.sh
```

Ce script installe et configure :

- `zsh`, `starship`, `zoxide`, `fzf`, `fd`, `eza`, `ripgrep`, `bat`, `git`, et autres utilitaires,
- `zinit` pour la gestion des plugins,
- un preset `Catppuccin Powerline` pour Starship,
- un bloc de configuration Zsh géré dans `~/.zshrc`.

Options :

- `--dry-run`
- `--no-update`
- `--no-chsh`
- `--zshrc FILE`
- `--starship FILE`

## Configuration Paru

1. Lancer :

```bash
./Configuration\ Paru/mod_paru.sh
```

Ce script :

- modifie le fichier `/etc/paru.conf` par défaut (ou un autre fichier via `-t, --target`),
- active l’option `BottomUp`,
- effectue une sauvegarde de la configuration avant la modification.

Comment l’utiliser :

1. placez-vous dans la racine du dépôt,
2. exécutez `./Configuration\ Paru/mod_paru.sh`,
3. si vous ne voulez pas modifier le fichier directement, ajoutez `--dry-run` pour simuler l’action,
4. utilisez `-t /chemin/vers/paru.conf` pour modifier un fichier de configuration différent.

Options :

- `-t, --target FILE` : fichier `paru.conf` à modifier,
- `--dry-run` : affiche les actions sans exécuter.

## Configuration FirewallD

1. Lancer :

```bash
./Configuration\ FirewallD/mod_firewalld.sh
```

Ce script :

- configure Firewalld pour utiliser la zone par défaut `home`,
- vérifie que `firewalld` ou `firewall-offline-cmd` est disponible,
- applique la configuration en ligne si Firewalld est actif,
- applique la configuration hors ligne si le service n'est pas actif.

Comment l’utiliser :

1. placez-vous dans la racine du dépôt,
2. exécutez `./Configuration\ FirewallD/mod_firewalld.sh`,
3. utilisez `--dry-run` pour afficher les commandes sans modification,
4. utilisez `-z zone` ou `--zone zone` pour définir une autre zone par défaut.

Options :

- `-z, --zone ZONE` : zone Firewalld à définir par défaut (défaut : `home`),
- `--dry-run` : affiche les actions sans exécuter.

## Notes importantes

- Les scripts sont conçus pour CachyOS / Arch Linux.
- Ils utilisent `sudo` et `pacman`.
- Le script AUR ne doit pas être exécuté en tant que root.
- Les scripts sauvegardent les fichiers existants avant de modifier `~/.zshrc` ou les alias si un bloc géré est déjà présent.

## Personnalisation

- Modifiez les listes de paquets dans `Installation de logiciels/liste des paquets/`.
- Modifiez les alias dans `Configuration Fish alias/aliases.fish` et `Configurations ZSH/Configuration alias/aliases.zsh`.
- Utilisez les options de chaque script pour ajuster les chemins et le comportement.

## Exemples de commandes

```bash
./Installation\ de\ logiciels/install-pacman-packages.sh --dry-run
./Installation\ de\ logiciels/install-kde-packages.sh --dry-run
./Installation\ de\ logiciels/install-aur-packages.sh --dry-run
./Installation\ de\ logiciels/install-flatpak-packages.sh --dry-run
./Configuration\ Fish\ alias/install-fish-aliases.sh --dry-run
./Configurations\ ZSH/Configuration\ alias/install-zsh-aliases.sh --dry-run
./Configurations\ ZSH/install-zsh.sh --dry-run
```

## Objectif du dépôt

Ce dépôt sert de collection de scripts pour :

- installer des logiciels et paquets sur CachyOS / Arch Linux,
- gérer les paquets KDE, AUR et Flatpak,
- déployer des alias Fish et Zsh personnalisés,
- configurer un environnement Zsh moderne avec Starship et zinit.
