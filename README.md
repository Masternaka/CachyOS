# CachyOS

Ce dépôt prépare la personnalisation de mon ordinateur personnel sous CachyOS,
avec Niri. Modifier le dépôt n'applique rien sur l'ordinateur : les installations
et les changements système restent des actions distinctes à autoriser.

## Repères

Les numéros identifient les scripts ; ils ne constituent pas un ordre obligatoire
d'exécution. Examiner leurs prérequis et leurs simulations avant de les appliquer.

| Script | Fonction | Lancement réel |
| --- | --- | --- |
| `01 - systemd_services.sh` | Bluetooth, serveur SSH, TRIM et nettoyage périodique du cache Pacman | Avec `sudo`, sans confirmation intégrée |
| `02 - firewalld_settings.sh` | Détection UFW/firewalld, désactivation au choix, interface graphique ou réglage des règles firewalld | Simulation ou application avec `sudo` et confirmation |
| `03 - pacman_settings.sh` | Téléchargements parallèles de Pacman | Avec `sudo`, saisie interactive ou options explicites |
| `04 - install_zsh.sh` | Outils du terminal, configurations et GNU Stow | Sans `sudo`, confirmations par étape |
| `08 - package_install.sh` | 62 paquets des dépôts officiels utilisés par CachyOS | Sans `sudo` conseillé ; élévation pour Pacman après confirmation |
| `09 - flatpak_install.sh` | 13 applications Flathub personnelles | Sans `sudo`, confirmation obligatoire |

Les [guides détaillés](docs/README.md) et le [catalogue Dotfiles](Dotfiles/README.md)
décrivent les fichiers, les sauvegardes et les limites de validation.

Les services exigent notamment `bluez`, `util-linux` et `pacman-contrib` déjà
présents. Le script Flatpak exige `flatpak`, `distrobox` et `podman`. Distrobox
et Podman font partie des 62 paquets ; Flatpak n'est pas installé par cette liste.
GNU Stow est proposé par l'installateur Zsh, même en mode copie.

## Installation des logiciels

`08 - package_install.sh` propose 62 paquets, avec une sélection facultative par
groupes. Il vérifie la sélection dans les dépôts officiels activés sur CachyOS,
affiche les cibles `dépôt/paquet`, puis demande confirmation
avant une transaction Pacman avec mise à jour complète. Aucun recours à l'AUR,
aucun nettoyage automatique du cache et aucun déploiement des Dotfiles.

```bash
bash "08 - package_install.sh" --list
bash "08 - package_install.sh" --groups virtualisation,terminal --list
bash "08 - package_install.sh" --dry-run
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

`09 - flatpak_install.sh` se lance sans sudo et utilise explicitement `--user`.
Il prépare 13 applications Flathub, vérifie leur disponibilité après accord,
installe celles qui manquent et recherche les mises à jour de celles déjà présentes.

```bash
bash "09 - flatpak_install.sh" --list
bash "09 - flatpak_install.sh" --dry-run
```

La simulation consulte seulement l'état local. Aucun changement avant
confirmation ; aucun nettoyage automatique. Distrobox et Podman sont contrôlés
comme prérequis de BoxBuddy, sans installation supplémentaire. Voir le
[guide Flatpak](docs/flatpak-install.md) pour les confirmations, la portée
personnelle, les inventaires et le nettoyage facultatif.

## Installation et configuration des outils du terminal

`04 - install_zsh.sh` utilise [Dotfiles](Dotfiles/README.md) comme source des
configurations et propose seize modules : Zsh, Starship, Yazi, btop, Tealdeer, Bat, FZF, Zoxide,
Eza, Ripgrep, fd, Delta, Lazygit, Kitty, Foot et duf. Les deux terminaux sont configurés
avec **JetBrainsMono Nerd Font**. `duf` ne nécessite aucun fichier à déployer.

Depuis Fish, ouvrir le menu et prévisualiser ses choix avec Bash :

```bash
bash "04 - install_zsh.sh" --interactive --dry-run
bash "04 - install_zsh.sh" --dry-run --mode stow --only zsh,starship,kitty,foot
```

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
logiciels avec `08 - package_install.sh` ne déploie pas leurs configurations.

## Services systemd

Le script `01 - systemd_services.sh` active durablement et démarre
`bluetooth.service`, `sshd.service`, `fstrim.timer` et `paccache.timer`. Il nécessite
CachyOS/Arch, un gestionnaire systemd accessible et les paquets `bluez`, `openssh`,
`util-linux` et `pacman-contrib`. Il n'installe aucun paquet. `bluez-utils` n'est
pas requis. Le serveur SSH écoute selon sa configuration et les règles du
pare-feu restent inchangées.

Examiner les actions sans modification, puis appliquer :

```bash
bash "01 - systemd_services.sh" --dry-run
sudo bash "01 - systemd_services.sh"
```

Les unités déjà actives et activées durablement sont conservées. Les unités
activées mais arrêtées sont démarrées. Les unités masquées ou dans un état non
pris en charge nécessitent une intervention manuelle. Une erreur sur une unité
n'empêche pas le traitement des autres ; toute erreur entraîne un code de sortie
`1`. Une option inconnue ou des arguments supplémentaires entraînent le code `2`.

Les timers peuvent déclencher leurs tâches dès leur démarrage, selon leur
configuration locale. Le script ne modifie ni leur calendrier ni leurs options.

Avant les changements, le script crée un fichier de retour arrière privé dans
`/var/tmp` et affiche son chemin. Examiner ce fichier, puis l'exécuter avec
`sudo bash CHEMIN_AFFICHE` pour restaurer l'activation initiale et l'état
démarré/arrêté des unités traitées. L'utiliser avant d'autres changements
volontaires sur ces unités. Il ne restaure pas les paquets supprimés du cache,
les effets du TRIM ou un ancien état `failed`. Aucun retour arrière automatique
n'est exécuté après une erreur.

Validation locale :

```bash
bash -n "01 - systemd_services.sh"
python3 -B -m unittest discover -s tests -p test_systemd_services.py -v
```

Les tests utilisent des commandes simulées dans un dossier temporaire. Sur un
hôte non root, les branches d'application sont testées sur une copie temporaire
qui contourne uniquement la garde root ; cette garde est testée séparément sur
le script original. Ces tests ne remplacent pas une validation sous CachyOS.

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

`03 - pacman_settings.sh` règle `ParallelDownloads` dans la section `[options]`
de `/etc/pacman.conf`. Il conserve les commentaires et les exemples. Les lignes
actives en double sont commentées. Les valeurs sont décimales, de 0 à 20 :
`0` commente la directive locale et exige une valeur effective de `1`.

Examiner la configuration proposée sans écriture :

```bash
bash "03 - pacman_settings.sh" --dry-run --value 5
bash "03 - pacman_settings.sh" --dry-run --auto
```

`--auto` fournit une estimation selon le CPU et la RAM totale, sans mesure du
réseau ni des miroirs. Les modes `--auto`, `--value` et `--restore` sont exclusifs.
Sans mode explicite, le script demande une valeur sur un terminal et refuse une
entrée non interactive. `--silent` conserve les erreurs visibles.

Après autorisation de l'application sur la machine cible, la commande est
`sudo bash "03 - pacman_settings.sh" --value 5`. Le script vérifie ses dépendances
existantes, dont `pacman-conf` et `flock`, sans installer ni télécharger d'outil.
Il valide la configuration candidate et sa valeur effective avant remplacement,
puis vérifie de nouveau le fichier appliqué. Un conflit avec une directive
`Include` provoque un refus si la valeur effective ne correspond pas à la demande.
Les fichiers inclus ne sont jamais modifiés.

Chaque changement crée une sauvegarde unique dans `/etc/pacman.conf.backups`.
Le script affiche le chemin précis pour revenir en arrière :

```bash
sudo bash "03 - pacman_settings.sh" --restore /chemin/de/la/sauvegarde
```

`--restore` seul choisit la dernière sauvegarde créée par le script, enregistrée
dans un index `.latest` remplacé atomiquement sous le verrou. Pour les anciennes
sauvegardes sans index, la date est utilisée ; des dates indiscernables imposent
un chemin explicite. Toute restauration est
validée et précédée d'une sauvegarde de la configuration courante, même si celle-ci
est invalide. La restauration remplace tout `pacman.conf`, sans restaurer les
fichiers inclus. Les droits, le propriétaire et le groupe sont conservés ; la date
des sauvegardes reflète leur création, et l'index évite les ambiguïtés à la seconde.

Le remplacement utilise un fichier temporaire dans le même répertoire. Les échecs
après remplacement et les interruptions interceptables déclenchent le retour à
l'instantané précédent. Une coupure de courant ou `SIGKILL` ne peut pas être
intercepté ; les sauvegardes restent disponibles. Le verrou protège les exécutions
de ce script, et une comparaison détecte les changements externes avant application.
Éviter les autres modifications de configuration pendant son exécution.

Le journal reste configurable avec `ARCH_CUSTOM_LOGFILE`. Un échec de journalisation
est signalé sans annuler une configuration validée. En mode simulation, aucun
journal, verrou, fichier temporaire ou sauvegarde n'est créé. L'aperçu ne valide pas
la configuration candidate : cette vérification est faite lors de l'application.

Les tests de `tests/test_pacman_settings.py` utilisent un faux `pacman-conf` et des
fichiers temporaires. Ils couvrent les erreurs, les sauvegardes, la restauration et
les interruptions ; ils ne prouvent pas le fonctionnement du vrai Pacman sous
CachyOS. Aucun changement système réel n'a été effectué pendant leur développement.

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
à examiner. Il ne résout aucun conflit automatiquement. Les contrôles automatiques
et leurs limites sont décrits dans le [guide de validation](docs/validation.md).
