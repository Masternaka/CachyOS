# Installation des logiciels

Le script `08 - package_install.sh` prépare 47 paquets et les installe dans une
seule transaction `pacman -Syu --needed dépôt/paquet…`, après confirmation.
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
jour les paquets du système qui ne font pas partie des 47 cibles explicites.

`distrobox` et `podman` sont installés sur l'hôte par cette liste. Le
[script Flatpak](flatpak-install.md) vérifie ensuite leur présence pour BoxBuddy,
sans les réinstaller. Le paquet `flatpak` lui-même ne fait pas partie de cette
liste : il doit déjà être disponible avant d'utiliser ce second script.

## Provenance des paquets

CachyOS utilise à la fois ses dépôts optimisés et les dépôts Arch stables.
Le [wiki officiel](https://wiki.cachyos.org/features/optimized_repos/) indique de
conserver `cachyos`, `core`, `extra` et `multilib` avec les variantes optimisées.
Le script n'exige donc pas que chaque paquet porte littéralement le dépôt
`cachyos` : il accepte les sources officielles normalement utilisées par CachyOS.

Avant toute écriture, le script :

1. Lit les dépôts activés avec `pacman-conf --repo-list`, qui résout les inclusions.
2. Refuse tout dépôt hors de la liste stable autorisée, même pour les dépendances.
3. Exige au moins un dépôt CachyOS et cherche chaque nom exact dans `pacman -Sl`.
4. Respecte l'ordre des dépôts configurés et affiche chaque cible `dépôt/paquet`.
5. Revalide les dépôts, la configuration effective et les cibles après confirmation.
6. Passe les cibles qualifiées à Pacman dans une transaction complète avec mise à jour.

Liste autorisée : `core`, `extra`, `multilib`, `cachyos`, `cachyos-v3`,
`cachyos-v4`, `cachyos-znver4`, `cachyos-core-v3`, `cachyos-extra-v3`,
`cachyos-core-v4`, `cachyos-extra-v4`, `cachyos-core-znver4`,
`cachyos-extra-znver4`. Un nouveau nom officiel devra être vérifié et ajouté
explicitement. Les dépôts de test, Chaotic-AUR et les dépôts personnels bloquent
le script ; il ne modifie pas automatiquement leur configuration.

Aucun appel à Yay, Paru, npm, curl, Git ou à l'AUR n'est utilisé pour installer.
Les miroirs, clés et règles de signature restent ceux de Pacman ; le contrôle
ne constitue pas un audit de leur configuration ni de la provenance historique
des paquets déjà présents. Les scripts et hooks des paquets peuvent modifier
le système pendant l'installation.

## Vérification documentaire du 12 novembre 2026

Les 47 noms ont été recherchés : 44 ont une fiche consultable dans le catalogue
CachyOS (ou son alias `dashboard.cachyos.org`). Pour Catfish, Transmission Qt et
Bitwarden, les pages du catalogue n'étaient pas accessibles avec l'outil de
consultation ; les fiches officielles Arch confirment leur présence dans `extra`.
Ces trois cas sont identifiés dans le tableau. Ce contrôle documentaire ne
remplace pas celui des bases réellement activées sur la machine cible.

Les versions du catalogue peuvent être anciennes ; aucune version ni architecture
optimisée n'est imposée dans le script. Le tableau donne une source constatée,
pas obligatoirement celle que la priorité locale retiendra.

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
La présence des 47 paquets est contrôlée après succès de Pacman. Le compteur final
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

Le test de taille de liste attend encore 45 paquets et son résumé attendu indique
44 nouveaux paquets : ces assertions précèdent l'activation de Distrobox et Podman.
Elles doivent être actualisées avant d'annoncer que la suite passe avec la liste
actuelle. La présente mise à jour documentaire ne modifie pas les tests.
