# Activer les services et timers systemd

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

Le script `01 - systemd_services.sh` active durablement et démarre
`bluetooth.service`, `sshd.service`, `fstrim.timer` et `paccache.timer`. Il nécessite
CachyOS/Arch, un gestionnaire systemd accessible et les paquets `bluez`, `openssh`,
`util-linux` et `pacman-contrib`. Il n'installe aucun paquet. `bluez-utils` n'est
pas requis. Le serveur SSH écoute selon sa configuration et les règles du
pare-feu restent inchangées.

## Prévisualiser et appliquer

Depuis la racine du dépôt, examiner d’abord les actions, puis lancer l’application
sur CachyOS lorsqu’elle est souhaitée. La seconde commande applique directement le
plan. Prévoir un accès local si SSH est ton seul accès à la machine.

```bash
bash "01 - systemd_services.sh" --help
bash "01 - systemd_services.sh" --dry-run
sudo bash "01 - systemd_services.sh"
```

## Lire le bilan

Les unités déjà actives et activées durablement sont conservées. Les unités
activées mais arrêtées sont démarrées. Les unités masquées ou dans un état non
pris en charge nécessitent une intervention manuelle. Une erreur sur une unité
n'empêche pas le traitement des autres ; toute erreur entraîne un code de sortie
`1`. Une option inconnue ou des arguments supplémentaires entraînent le code `2`.

Les timers peuvent déclencher leurs tâches dès leur démarrage, selon leur
configuration locale. Le script ne modifie ni leur calendrier ni leurs options.

Pour relire les états et les prochaines échéances après l’application.

```bash
systemctl show -p Id -p ActiveState -p UnitFileState bluetooth.service sshd.service fstrim.timer paccache.timer
systemctl list-timers --all fstrim.timer paccache.timer
```

Une unité `active` avec `UnitFileState=enabled` remplit l’objectif du script.
Le test d’accès SSH depuis un autre poste dépend aussi du pare-feu et des
paramètres d’authentification.

## Revenir en arrière

Avant les changements, le script crée un fichier de retour arrière privé dans
`/var/tmp` et affiche son chemin. Examiner ce fichier, puis l'exécuter avec
`sudo bash CHEMIN_AFFICHE` pour restaurer l'activation initiale et l'état
démarré/arrêté des unités traitées. L'utiliser avant d'autres changements
volontaires sur ces unités. Il ne restaure pas les paquets supprimés du cache,
les effets du TRIM ou un ancien état `failed`. Aucun retour arrière automatique
n'est exécuté après une erreur.

## Validation locale

```bash
bash -n "01 - systemd_services.sh"
python3 -B -m unittest discover -s tests -p test_systemd_services.py -v
```

Les tests utilisent des commandes simulées dans un dossier temporaire. Sur un
hôte non root, les branches d'application sont testées sur une copie temporaire
qui contourne uniquement la garde root ; cette garde est testée séparément sur
le script original. Ces tests ne remplacent pas une validation sous CachyOS.
