# Documentation CachyOS

Les scripts et configurations de ce dépôt préparent le poste personnel CachyOS
avec Niri. La préparation du dépôt n'autorise pas une installation ou un
déploiement sur la machine : chaque application réelle reste à examiner et à
autoriser. Les commandes des guides sont des exemples à exécuter volontairement.

## Guides

| Document | Contenu |
| --- | --- |
| [README du dépôt](../README.md) | Index des scripts, exemples et raccourcis par outil |
| [01 · Services systemd](systemd-services.md) | Bluetooth, SSH, timers et fichier de retour arrière |
| [02 · Pare-feu](firewalld.md) | Détection, interfaces graphiques, désactivation et règles firewalld |
| [03 · Réglages Pacman](pacman-settings.md) | Téléchargements parallèles, contrôle et restauration |
| [Paquets natifs](package-install.md) | 62 paquets, provenance, mises à jour et inventaires |
| [Applications Flatpak](flatpak-install.md) | 13 applications personnelles, Flathub, confirmations et nettoyage facultatif |
| [Zsh et outils du terminal](zsh.md) | 16 modules, plugins sans gestionnaire, alias, polices, copies/Stow et restauration |
| [07 · QEMU et Virt-Manager](qemu.md) | Paquets, accès libvirt, KVM, réseau NAT et stockage |
| [08 · master-archrepo](master-archrepo.md) | Empreinte OpenPGP, dépôt Pacman tiers et effets sur le script 05 |
| [09 · Purge d’applications](purge-applications.md) | Sélection des cibles, simulation, sauvegarde et réinstallation |
| [10 · Disques secondaires](disk-setup.md) | Identifier les volumes par UUID, appliquer leurs labels et leur propriétaire, et les monter au démarrage |
| [Catalogue Dotfiles](../Dotfiles/README.md) | 17 paquets Stow, dont Ghostty et Fastfetch séparés |
| [Configuration Kitty](../Dotfiles/kitty/.config/kitty/README.md) | Réglages actuels, thèmes, police et déploiement sur CachyOS/Niri |
| [Configuration Fastfetch](../Dotfiles/fastfetch/.config/fastfetch/README.md) | Affichage système, personnalisation et déploiement manuel |

## Choisir les étapes

La numérotation n'est pas un orchestrateur. Les scripts restent indépendants :

- `05 - package_install.sh` installe les logiciels natifs, dont Distrobox et Podman,
  et met à jour tout le système. Il ne déploie pas les configurations.
- `06 - flatpak_install.sh` propose les paquets hôte nécessaires, puis installe
  les applications et runtimes via `flatpak --user`.
- `07 - install_qemu.sh` prépare libvirt, le stockage et le réseau virtuel.
- `04 - install_zsh.sh` prépare les outils du terminal et leurs configurations.
  Il propose GNU Stow même si le mode copie est choisi. Ghostty et Fastfetch se
  déploient séparément, après examen du plan Stow.
- Les services, le pare-feu et les téléchargements parallèles ont chacun leurs
  prérequis. Ouvrir leurs guides avant application.
- `08 - install-master-archrepo.sh` ajoute un dépôt tiers. Tant que ce dépôt est
  actif, le contrôle de provenance du script 05 bloque la transaction.

Les inventaires des installations Pacman et Flatpak ne remplacent pas une
sauvegarde système ou des données personnelles. La restauration des fichiers
proposée par l'installateur Zsh n'annule pas les installations de logiciels.

## Validation et limites

Les références des scripts et les listes attendues des tests ont été actualisées.
Le catalogue actuel comprend 62 paquets natifs, 13 applications Flatpak, 17 paquets
Stow et 16 modules de l'installateur Zsh. La sélection native par groupes ne change
pas la liste par défaut. Les noms attendus et les références documentaires sont
contrôlés automatiquement.

- [Diagnostic et validation](validation.md) : lecture seule, tests isolés et CI.
- [Anciens modèles Zsh](../config/zsh/README.md) : archives conservées, sources actives.

Les tests simulés ne valident pas le comportement natif de Pacman, firewalld,
Flatpak, Niri ou des applications. Un outil absent produit un contrôle ignoré ;
aucun outil n'est téléchargé automatiquement. L'exécution du workflow GitHub reste
à confirmer après une publication autorisée. Aucun changement système n'a été
appliqué dans le cadre de ces corrections.
