# Activer les services et timers systemd

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

Le script `01 - systemd_services.sh` prépare l’activation de
`bluetooth.service`, `fstrim.timer` et `paccache.timer`. Il propose aussi d’inclure
`sshd.service`. Entrée conserve l’état actuel de SSH. Il nécessite CachyOS/Arch,
un gestionnaire systemd accessible et les paquets `bluez`, `util-linux` et
`pacman-contrib`. `openssh` est requis uniquement si SSH est sélectionné.
Le serveur SSH écoute selon sa configuration et les règles du pare-feu en place.

## Prévisualiser et appliquer

Depuis la racine du dépôt, utiliser `--dry-run` pour examiner le plan.
Dans un terminal, la simulation propose aussi d’inclure SSH. Pour appliquer,
relancer avec `sudo`, refaire le choix SSH et confirmer les actions affichées.
Entrée à la confirmation annule le plan. Avant chaque action, le script
vérifie que l’état de l’unité correspond toujours à celui du plan.

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
