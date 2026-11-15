# Désinstaller des applications et retirer leurs configurations

`09 - purge_applications.sh` reçoit les paquets et configurations à retirer
par arguments. Lance-le depuis le compte CachyOS concerné. La simulation est
le mode par défaut et affiche les cibles sans sudo ni écriture.

## Préparer la liste

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

Fermer les applications visées. Après examen, relancer avec `--apply` à la
place de `--dry-run` et taper `PURGER` lorsque le plan est correct.

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
