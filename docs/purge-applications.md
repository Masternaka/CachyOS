# Désinstaller des applications et retirer leurs configurations

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

`09 - purge_applications.sh` détecte les applications de son catalogue au
démarrage. Lance-le depuis le compte CachyOS concerné. La simulation est le
mode par défaut et affiche les cibles sans sudo ni écriture.

## Choisir les applications

```bash
bash "09 - purge_applications.sh"
bash "09 - purge_applications.sh" --list
```

Sans argument, le script affiche l’état des paquets dans deux listes, Pacman
et Flatpak. Les numéros se suivent d’une liste à l’autre et le menu te laisse
faire toute la sélection en une fois.

| Saisie | Sélection |
| --- | --- |
| `1 2` ou `1,2` | Les entrées numérotées 1 et 2, si elles sont installées et admissibles |
| `haruna,org.kde.haruna` | Les deux éditions de Haruna, si elles sont installées et admissibles |
| `tout` | Toutes les entrées installées et admissibles des deux catalogues |
| `pacman` ou `flatpak` | Toutes les entrées admissibles du catalogue choisi |
| Entrée ou `q` | Annuler la sélection |

`--list` affiche seulement l’inventaire. Une application Flatpak installée
seulement au niveau système apparaît dans l’inventaire et reste hors de la
sélection. Les applications installées hors catalogue restent accessibles avec
les options `--pacman` et `--flatpak` et ne sont pas comprises dans `tout`.

Haruna figure dans les deux listes. Pour ajouter des applications au catalogue,
modifie `NATIVE_CATALOGUE` (format `paquet` ou `paquet:chemin-de-configuration`)
et `FLATPAK_CATALOGUE` (identifiants complets) au début du script. Le chemin de
configuration natif est relatif à `XDG_CONFIG_HOME` (par défaut `~/.config`).

## Fournir des cibles par arguments

```bash
bash "09 - purge_applications.sh" --help
pacman -Qq
flatpak list --user --app --columns=application
```

Pour chaque application, identifier son nom exact Pacman ou son identifiant
Flatpak. Pour un paquet natif, relever aussi le nom du fichier ou du dossier
de configuration sous `~/.config`, ou sous `XDG_CONFIG_HOME` s’il est défini.
Par exemple, `--config mon-application/reglages.toml` peut viser un fichier
précis. Les options sont répétables pour préparer plusieurs applications.

### Exemple avec Haruna

Pour le paquet natif `haruna`, cibler aussi le dossier de réglages `haruna`
sous `~/.config` ou `XDG_CONFIG_HOME`. Pour l’édition Flatpak personnelle,
utiliser l’identifiant `org.kde.haruna`.
[Paquet CachyOS](https://packages.cachyos.org/package/cachyos-extra-v4/x86_64_v4/haruna) ·
[Réglages Haruna](https://www.mail-archive.com/kde-bugs-dist%40kde.org/msg1120972.html) ·
[Flathub](https://flathub.org/apps/org.kde.haruna)

```bash
# Version native Pacman
bash "09 - purge_applications.sh" --dry-run --pacman haruna --config haruna

# Version Flatpak personnelle
bash "09 - purge_applications.sh" --dry-run --flatpak org.kde.haruna
```

Le plan sépare les fichiers `/etc` recensés par Pacman des configurations
personnelles. Pour un Flatpak personnel, il propose automatiquement le dossier
`config` dans `~/.var/app/IDENTIFIANT`. Le dossier est conservé lorsqu’une
installation système partage le même identifiant. Plusieurs versions
personnelles du même identifiant demandent un examen manuel.

## Appliquer et lire le rapport

Fermer les applications visées. Après la simulation, relancer avec `--apply`
et refaire la sélection, ou reprendre les mêmes cibles en arguments. Taper
`PURGER` lorsque le plan affiché est correct.

Le plan natif utilise `pacman -R --print` pour vérifier la transaction sans
désinstaller les paquets. L’option `-n` est utilisée à l’étape du retrait.

1. Le script crée un dossier privé `~/.cachyos-purge.*` et archive les fichiers
   existants de `/etc` déclarés par les paquets demandés. Les fichiers déclarés
   mais absents sont ignorés. Un parent symbolique arrête l’archivage.
2. Il désinstalle les applications personnelles Flatpak avec les confirmations
   natives, puis les paquets Pacman explicitement demandés avec `-Rn`.
   Pacman garde ses contrôles de dépendances. Cette option désactive
   la création de nouveaux fichiers `.pacsave` pendant la désinstallation.
3. Après vérification des retraits, il déplace les configurations personnelles
   vers `fichiers/` dans la sauvegarde. Les liens Stow sélectionnés sont
   déplacés comme liens. La source du lien reste à son emplacement.

La purge couvre les paquets explicitement choisis, leurs fichiers gérés par
le gestionnaire et les configurations décrites dans le plan. Les données,
caches et permissions Flatpak sont conservés. Les dépendances orphelines,
anciens `.pacsave` et fichiers générés hors du périmètre nécessitent un examen
séparé. [Manuel Pacman](https://man.archlinux.org/man/pacman.8.en#REMOVE_OPTIONS_(APPLY_TO_-R)) ·
[Manuel Flatpak](https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-uninstall)

## Revenir en arrière

Le rapport indique le dossier de sauvegarde. Les inventaires donnent les noms
et versions Pacman, les références Flatpak et les chemins personnels prévus.
Un échec peut laisser une désinstallation partielle. Relire le rapport et
l’état des gestionnaires avant de relancer ou de réinstaller.

- Pour une configuration personnelle, reprendre dans `fichiers/` son chemin
  relatif au dossier personnel. Vérifier qu’aucune nouvelle configuration
  n’occupe la destination.
- Pour les fichiers natifs, lire d’abord le contenu de `etc.tar.gz` avec
  `tar -tzf`. Réinstaller le paquet souhaité, puis comparer et restaurer
  seulement les fichiers nécessaires.
- La sauvegarde archive les fichiers `/etc` recensés et les configurations
  déplacées. Les logiciels, leurs anciennes versions et les configurations
  natives hors de `/etc` dépendent des gestionnaires ou d’une sauvegarde
  système existante.
