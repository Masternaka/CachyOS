# Installation des logiciels

Le script `08 - package_install.sh` propose 62 paquets par défaut et installe la
sélection dans une seule transaction `pacman -Syu --needed dépôt/paquet…`, après
confirmation.
Il remplace l'ancien client `tldr` par `tealdeer`, déjà configuré par le script Zsh.
Les autres choix actifs et les exemples commentés sont conservés.
Distrobox et Podman sont maintenant actifs dans la liste pour préparer BoxBuddy.

## Examiner puis exécuter

```bash
bash "08 - package_install.sh" --help
bash "08 - package_install.sh" --list
# Sur la machine CachyOS : contrôle en lecture seule.
bash "08 - package_install.sh" --dry-run
# Seulement lorsque l'installation est souhaitée :
bash "08 - package_install.sh"
```

L'aide et la liste fonctionnent sans Linux ni privilèges. La simulation nécessite
CachyOS, Pacman, pacman-conf et leurs bases existantes. Elle ne crée aucun fichier,
ne synchronise pas les bases, ne télécharge rien et n'appelle pas sudo.
Une base manquante ou un paquet introuvable est bloquant : le script n'effectue
jamais de synchronisation isolée `-Sy` pour contourner ce refus.

L'exécution réelle exige un terminal interactif et une réponse affirmative après
l'aperçu des cibles et des effets. Pacman conserve ses propres confirmations pour
les dépendances, conflits, remplacements et versions finales. Il peut notamment
proposer un remplacement du client tldr existant selon les paquets installés.
Aucune option `--yes` ou `--noconfirm` n'est prévue.

## Paquets déjà installés et intégration Flatpak

Avec `--needed`, un paquet déjà à jour n'est pas réinstallé. Une version plus
récente est installée pendant la mise à jour complète. `-Syu` met également à
jour les paquets du système qui ne font pas partie des cibles sélectionnées.

`distrobox` et `podman` sont installés sur l'hôte par cette liste. Le
[script Flatpak](flatpak-install.md) vérifie ensuite leur présence pour BoxBuddy,
sans les réinstaller. Le paquet `flatpak` lui-même ne fait pas partie de cette
liste : il doit déjà être disponible avant d'utiliser ce second script.

## Choisir les groupes

Sans `--groups`, la sélection complète existante est conservée. Les groupes se
combinent avec `--list` et `--dry-run`, sans appel système pour la liste :

```bash
bash "08 - package_install.sh" --list-groups
bash "08 - package_install.sh" --groups virtualisation,terminal --list
bash "08 - package_install.sh" --groups virtualisation,terminal --dry-run
```

Après autorisation de l'installation sur la cible, retirer `--dry-run`. Même avec
un seul groupe, la transaction `-Syu` met à jour tout le système. Aucun groupe ne
configure les services ou les applications. La sélection de `langues` ne force
pas le groupe `internet` ; Pacman décide des dépendances réelles.

### Catalogue actuel

| Groupe | Paquets |
| --- | --- |
| `utilitaires` | `catfish`, `flameshot`, `gnome-disk-utility`, `gparted`, `qbittorrent`, `transmission-qt`, `lshw`, `fwupd`, `timeshift`, `7zip`, `stow` |
| `polices` | `ttf-jetbrains-mono-nerd`, `ttf-meslo-nerd`, `ttf-firacode-nerd` |
| `langues` | `firefox-i18n-fr`, `thunderbird-i18n-fr` |
| `securite` | `bitwarden`, `proton-pass`, `firewalld`, `firewall-config` |
| `internet` | `firefox`, `thunderbird`, `brave-origin-bin` |
| `multimedia` | `strawberry`, `mpv` |
| `communication` | `vesktop-bin` |
| `bureautique` | `libreoffice-fresh`, `libreoffice-fresh-fr`, `obsidian` |
| `virtualisation` | `qemu-full`, `swtpm`, `virt-manager`, `distrobox`, `podman` |
| `terminaux` | `kitty`, `foot`, `ghostty` |
| `terminal` | `btop`, `fastfetch`, `tealdeer`, `git`, `curl`, `wget`, `yazi`, `starship` |
| `developpement` | `micro`, `code`, `github-desktop`, `meld`, `zed` |
| `ia` | `openai-codex`, `claude-desktop`, `claude-code`, `opencode`, `opencode-desktop` |
| `kde` | `merkuro`, `dolphin-plugins`, `isoimagewriter`, `yakuake`, `krusader`, `systemdgenie`, `print-manager` |

## Provenance et contrôle sur la cible

Le script vérifie les bases locales et les dépôts configurés avant toute
installation. Aucun recours automatique à l'AUR ni téléchargement externe.
Consulter le [catalogue CachyOS](https://packages.cachyos.org/) pour la disponibilité
courante. Les 62 noms actifs sont conservés tels que choisis dans le dépôt ; cette
mise à jour ne prétend pas avoir revérifié individuellement leur disponibilité.
Une entrée absente reste bloquante, sans substitution silencieuse.

### Relevé historique du 12 novembre 2026

Le tableau suivant conserve les liens du précédent relevé documentaire. Il porte
sur l'ancienne sélection de 47 paquets et ne décrit pas le catalogue actuel :
notamment `brave-bin` a été remplacé par `brave-origin-bin` dans la sélection.
Les dépôts indiqués sont ceux de ce relevé, pas une garantie de provenance actuelle.

<details>
<summary>Anciennes références de provenance</summary>

| Paquet | Dépôt constaté | Fiche consultée |
| --- | --- | --- |
| `qt6-wayland` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/qt6-wayland) |
| `catfish` | `extra` | [Arch officiel — catalogue CachyOS inaccessible](https://archlinux.org/packages/extra/any/catfish/) |
| `flameshot` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/flameshot) |
| `gnome-disk-utility` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/gnome-disk-utility) |
| `gparted` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/gparted) |
| `openrgb` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/openrgb) |
| `qbittorrent` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/qbittorrent) |
| `transmission-qt` | `extra` | [Arch officiel — catalogue CachyOS inaccessible](https://archlinux.org/packages/extra/x86_64/transmission-qt/) |
| `lshw` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/lshw) |
| `fwupd` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/fwupd) |
| `7zip` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/7zip) |
| `ttf-jetbrains-mono-nerd` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/ttf-jetbrains-mono-nerd) |
| `ttf-meslo-nerd` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/ttf-meslo-nerd) |
| `ttf-firacode-nerd` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/ttf-firacode-nerd) |
| `firefox-i18n-fr` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/firefox-i18n-fr) |
| `thunderbird-i18n-fr` | `cachyos-extra-v3` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos-extra-v3/x86_64_v3/thunderbird-i18n-fr) |
| `bitwarden` | `extra` | [Arch officiel — catalogue CachyOS inaccessible](https://archlinux.org/packages/extra/x86_64/bitwarden/) |
| `firefox` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/firefox) |
| `thunderbird` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/thunderbird) |
| `brave-bin` | `cachyos` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos/x86_64/brave-bin) |
| `strawberry` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/strawberry) |
| `mpv` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/mpv) |
| `vesktop-bin` | `cachyos` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos/x86_64/vesktop-bin) |
| `libreoffice-fresh` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/libreoffice-fresh) |
| `libreoffice-fresh-fr` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/libreoffice-fresh-fr) |
| `obsidian` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/obsidian) |
| `qemu-full` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/qemu-full) |
| `swtpm` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/swtpm) |
| `virt-manager` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/virt-manager) |
| `distrobox` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/any/distrobox) |
| `podman` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/podman) |
| `kitty` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/kitty) |
| `foot` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/foot) |
| `ghostty` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/ghostty) |
| `fastfetch` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/fastfetch) |
| `tealdeer` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/tealdeer) |
| `git` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/git) |
| `curl` | `core` | [Catalogue CachyOS](https://packages.cachyos.org/package/core/x86_64/curl) |
| `wget` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/wget) |
| `micro` | `cachyos-extra-v4` | [Catalogue CachyOS](https://dashboard.cachyos.org/package/cachyos-extra-v4/x86_64_v4/micro) |
| `code` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/code) |
| `github-desktop` | `cachyos` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos/x86_64/github-desktop) |
| `meld` | `extra` | [Catalogue CachyOS](https://dashboard.cachyos.org/package/extra/any/meld) |
| `zed` | `extra` | [Catalogue CachyOS](https://packages.cachyos.org/package/extra/x86_64/zed) |
| `openai-codex` | `cachyos-extra-v3` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos-extra-v3/x86_64_v3/openai-codex) |
| `claude-desktop` | `cachyos` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos/x86_64/claude-desktop) |
| `claude-code` | `cachyos` | [Catalogue CachyOS](https://packages.cachyos.org/package/cachyos/x86_64/claude-code) |

</details>

## Inventaires et limites du retour arrière

Après accord, un dossier privé de mode `0700` est créé sous
`/var/tmp/cachyos-packages.XXXXXXXX`. Il contient les noms et versions avant/après,
les paquets explicites, les paquets étrangers, les cibles et la configuration
Pacman effective. Si lancé entièrement avec sudo, ce dossier appartient à root.
Il peut contenir des URL de miroirs privées : ne pas le publier sans examen.

L'inventaire n'est pas une sauvegarde des fichiers ni un instantané système.
Il n'annule ni une mise à jour, ni les effets des hooks. Prévoir une sauvegarde
ou un instantané si un retour système complet est nécessaire. Aucun faux script
de récupération, nettoyage du cache, désinstallation ou rétrogradation
automatique n'est généré. Les archives existantes restent disponibles.

Le script ne déploie pas les Dotfiles, ne change pas le shell et ne configure
ni Niri, ni la virtualisation, ni les services. Ces intégrations restent du
ressort de leurs scripts dédiés. Les applications peuvent nécessiter des étapes
supplémentaires avant leur utilisation.

Toute transaction en erreur conserve un code non nul et les inventaires disponibles.
La présence de tous les paquets sélectionnés est contrôlée après succès de Pacman. Le compteur final
concerne les paquets demandés nouvellement installés, hors dépendances ; les autres
changements sont détaillés dans les inventaires et le journal Pacman.

## Validation

```bash
bash -n "08 - package_install.sh"
python3 -B -m unittest discover -s tests -p test_package_install.py -v
```

Les tests utilisent de faux Pacman, sudo et des inventaires dans une fixture
privée. Ils couvrent notamment les confirmations par pseudo-terminal, les refus
de dépôts tiers, les paquets absents, la simulation sans écriture et les échecs.
Ils ne téléchargent ni n'installent rien. Aucune transaction native sous CachyOS
n'a été exécutée dans le cadre de la préparation de ces changements.

Les tests attendent les noms explicites de la sélection actuelle. Ils vérifient
également les groupes, leur union, les erreurs de sélection et la limitation des
cibles de transaction. Une liste attendue doit être revue lors d'un ajout volontaire.
