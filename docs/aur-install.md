# Installation des quatre paquets AUR

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

`11 - aur_install.sh` conserve `t3code-bin`, `herdr-bin`, `orca-ide-bin` et
`gitkraken`. Il utilise Paru depuis un compte normal, jamais en lançant le script
avec `sudo`. Il n'installe pas Paru ni ses prérequis manquants.

```bash
# Liste consultable depuis toute machine :
bash "11 - aur_install.sh" --list
# Sur CachyOS : bases locales seulement, sans réseau ni écriture.
bash "11 - aur_install.sh" --dry-run
# Uniquement pour déclencher volontairement l'installation :
bash "11 - aur_install.sh" --install
```

Sans option, le script fait seulement le contrôle local et affiche le plan.
L'aide est disponible avec `--help`. Aucun argument permettant une installation
sans confirmation n'est accepté.

## Contrôles et confirmations

Le script vérifie CachyOS, le compte non root, les outils déjà présents,
`base-devel`, Git, les dépôts configurés et le verrou Pacman. Il refuse les dépôts
tiers et de test ; sa liste de dépôts autorisés est volontairement restrictive.
Un nouveau nom légitime devra être examiné avant adaptation du script.
Il bloque si l'un des quatre noms est déjà disponible dans une base de dépôt
locale, afin de privilégier cette source. Les dépendances restent résolues par
Paru et peuvent provenir des dépôts autorisés ou de l'AUR.

Les bases locales peuvent être anciennes. Avant l'installation, consulter le
[catalogue CachyOS](https://packages.cachyos.org/), terminer séparément une mise à
jour complète et préparer une sauvegarde ou un instantané restaurable.
Le script demande une attestation explicite de ces préparatifs ; il ne peut pas
vérifier qu'une sauvegarde est exploitable ni que le système est à jour.
Il ne lance ni mise à jour complète ni synchronisation isolée `pacman -Sy`.

Après cette confirmation, il crée un dossier privé temporaire, conserve les
inventaires des versions et des paquets explicites et lit les informations des
quatre paquets avec `paru -Si --aur`. Si un nom est introuvable ou si l'AUR est
inaccessible, il s'arrête avant toute installation. Il demande ensuite un accord
pour examiner chaque paquet, lance Paru et vérifie sa présence avec `pacman -Q`.
`--needed` évite la réinstallation d'une version déjà à jour ; une nouvelle
version peut être installée.

La [documentation Paru](https://github.com/Morganamilo/paru/blob/master/man/paru.8)
décrit `--review` et `PARU_CONF`. Le script utilise `PARU_CONF=/dev/null` seulement
pour ses appels : aucune configuration personnelle n'est modifiée. Cela neutralise
notamment `SkipReview`, les options de construction et les commandes personnalisées
de Paru. La configuration Pacman et celle de makepkg restent utilisées et doivent
être dignes de confiance. Un dossier de construction neuf est utilisé pour chaque
cible afin de présenter les recettes sans réutiliser une ancienne approbation.

## Examiner les recettes

Pour chacune des quatre pages AUR, regarder le mainteneur, les dates, les
signalements, les commentaires récents et l'historique. Ces informations sont
présentées pour examen humain ; le script ne certifie pas leur fiabilité et ne
bloque pas automatiquement un paquet orphelin ou signalé obsolète.

Dans la revue de Paru, lire le `PKGBUILD`, les scripts `.install`, les patchs et
les autres fichiers associés, y compris ceux des dépendances AUR. Vérifier les
domaines des sources auprès de l'éditeur, les sommes de contrôle et signatures,
les entrées `SKIP`, et les commandes exécutées. Ne pas sourcer un `PKGBUILD` pour
l'examiner : cela exécuterait déjà son code. Un paquet `-bin` fournit des binaires
précompilés ; la revue de la recette ne permet pas d'auditer leur contenu.

`--review` active la revue, mais ne prouve pas que les fichiers ont été lus ou
compris. Les questions de Paru et Pacman restent interactives. Refuser une
transaction douteuse ou interrompre avec Ctrl+C. Ne pas contourner un échec de
somme de contrôle ou de signature. Une clé PGP proposée doit être authentifiée
séparément avant de l'importer. Le script n'ajoute aucun contournement des
contrôles de makepkg.

Une recette peut exécuter du code avec les droits du compte pendant sa
construction ; les scripts d'installation et hooks Pacman peuvent agir comme
root. Les confirmations ne constituent pas une isolation et aucune vérification
automatique ne garantit qu'un paquet AUR est sûr.

## Suivi et retour arrière

Le chemin `cachyos-aur.XXXXXXXX` est affiché avant le téléchargement et à la fin.
Il contient les inventaires avant/après, la configuration Pacman effective, les
informations AUR et les répertoires de construction. Il peut prendre de la place.
Le script ne nettoie pas ces fichiers ni les dépendances de construction.
Ce dossier temporaire peut être purgé au redémarrage : en conserver une copie
ailleurs si un suivi durable est nécessaire. Ce n'est pas une sauvegarde des
données, de la base Pacman ou des anciennes archives de paquets.

En cas d'échec, les installations précédentes et certaines dépendances peuvent
rester présentes. Comparer les inventaires avant toute suppression. Pour retirer
un paquet nouvellement ajouté, examiner une commande ciblée telle que
`sudo pacman -R t3code-bin` et sa transaction avant de confirmer. Ne pas retirer
automatiquement toutes les nouvelles dépendances ni un paquet qui existait déjà.
Les fichiers personnels et les effets des hooks ne sont pas annulés par cette
désinstallation. Une mise à niveau nécessite les anciennes archives compatibles
ou la restauration de l'instantané préparé séparément.

## Limites de validation

Le script est préparé depuis macOS : aucune installation, construction ou
validation réelle sous CachyOS n'a été effectuée. Les pages AUR ont refusé la
consultation automatisée et le catalogue CachyOS charge ses résultats
dynamiquement ; la disponibilité actuelle des quatre noms et leurs recettes
ne sont donc pas certifiées ici. Les contrôles sur la cible restent nécessaires.
