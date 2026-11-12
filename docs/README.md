# Documentation CachyOS

Les scripts et configurations de ce dépôt préparent le poste personnel CachyOS
avec Niri. La préparation du dépôt n'autorise pas une installation ou un
déploiement sur la machine : chaque application réelle reste à examiner et à
autoriser. Les commandes des guides sont des exemples à exécuter volontairement.

## Guides

| Document | Contenu |
| --- | --- |
| [README du dépôt](../README.md) | Scripts actuels, privilèges, prérequis, services, pare-feu et Pacman |
| [Paquets natifs](package-install.md) | 47 paquets, provenance, mises à jour et inventaires |
| [Applications Flatpak](flatpak-install.md) | 13 applications personnelles, Flathub, confirmations et nettoyage facultatif |
| [Zsh et outils du terminal](zsh.md) | 15 modules, plugins sans gestionnaire, alias, polices, copies/Stow et restauration |
| [Catalogue Dotfiles](../Dotfiles/README.md) | 17 paquets Stow, dont Ghostty et Fastfetch séparés |
| [Configuration Kitty](../Dotfiles/kitty/.config/kitty/README.md) | Réglages actuels, thèmes, police et déploiement sur CachyOS/Niri |
| [Configuration Fastfetch](../Dotfiles/fastfetch/.config/fastfetch/README.md) | Affichage système, personnalisation et déploiement manuel |

## Choisir les étapes

La numérotation n'est pas un orchestrateur. Les scripts restent indépendants :

- `08 - package_install.sh` installe les logiciels natifs, dont Distrobox et Podman,
  et met à jour tout le système. Il ne déploie pas les configurations.
- `09 - flatpak_install.sh` exige Flatpak déjà présent et vérifie Distrobox/Podman
  pour BoxBuddy. Il gère uniquement l'installation personnelle via `--user`.
- `04 - install_zsh.sh` prépare les outils du terminal et leurs configurations.
  Il propose GNU Stow même si le mode copie est choisi. Ghostty et Fastfetch se
  déploient séparément, après examen du plan Stow.
- Les services, le pare-feu et les téléchargements parallèles restent des réglages
  système distincts. Consulter leurs sections dans le README avant application.

Les inventaires des installations Pacman et Flatpak ne remplacent pas une
sauvegarde système ou des données personnelles. La restauration des fichiers
proposée par l'installateur Zsh n'annule pas les installations de logiciels.

## Validation et écarts connus

La mise à jour documentaire du 12 novembre 2026 a vérifié les noms de scripts,
les liens locaux et la cohérence des listes avec les fichiers du dépôt. Elle
n'a exécuté aucune installation, aucune configuration système et aucun Stow
dans le dossier personnel. Les validations natives CachyOS/Niri restent à faire.

Les tests simulés précédemment réussis ne constituent pas un résultat de la
suite entière pour l'état actuel. Des écarts ont été identifiés à la lecture :

| Contrôle | Écart à actualiser |
| --- | --- |
| `tests/test_firewalld_settings.py` | Référence encore l'ancien `03 - firewalld_settings.sh` ; le fichier actuel est `02 - firewalld_settings.sh`. |
| `tests/test_pacman_settings.py` | Référence encore l'ancien `04 - pacman_settings.sh` ; le fichier actuel est `03 - pacman_settings.sh`. |
| `tests/test_package_install.py` | Attend 45 paquets et 44 nouvelles installations dans sa fixture, avant l'activation de Distrobox et Podman ; la liste actuelle en contient 47. |
| `tests/test_dotfiles.py` | Attend 15 paquets Stow ; le dossier en contient 17 avec Ghostty et Fastfetch. |

L'aide intégrée de `03 - pacman_settings.sh` utilise également son ancien numéro.
Les commandes de cette documentation utilisent le nom actuel. Ces écarts de
code et de tests ne sont pas modifiés dans le cadre de la mise à jour documentaire.

Les commandes de validation figurent dans chaque guide. Avant de lancer la
suite complète, actualiser les références et assertions ci-dessus. Aucun outil
manquant ne doit être installé automatiquement pour effectuer les contrôles.
