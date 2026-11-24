# Régler les téléchargements parallèles de Pacman

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

`03 - pacman_settings.sh` règle `ParallelDownloads` dans la section `[options]`
de `/etc/pacman.conf`. Il conserve les commentaires et les exemples. Les lignes
actives en double sont commentées. Les valeurs sont décimales, de 0 à 20 :
`0` commente la directive locale et exige une valeur effective de `1`.

## Choisir une valeur et l’appliquer

Depuis la racine du dépôt, utiliser l’aide ou examiner la configuration proposée.

```bash
bash "03 - pacman_settings.sh" --help
bash "03 - pacman_settings.sh" --dry-run --value 5
bash "03 - pacman_settings.sh" --dry-run --auto
```

`--auto` fournit une estimation selon le CPU et la RAM totale, sans mesure du
réseau ni des miroirs. Les modes `--auto`, `--value` et `--restore` sont exclusifs.
Sans mode explicite, le script demande une valeur sur un terminal et refuse une
entrée non interactive. Les étapes et le bilan s’affichent sur la sortie
d’erreur, et l’aperçu du fichier sur la sortie standard.

Pour appliquer la valeur examinée, lancer `sudo bash "03 - pacman_settings.sh" --value 5`.
Le mode explicite applique directement la valeur. Le script vérifie ses dépendances
existantes, dont `pacman-conf` et `flock`, sans installer ni télécharger d'outil.
Il valide la configuration candidate et sa valeur effective avant remplacement,
puis vérifie de nouveau le fichier appliqué. Un conflit avec une directive
`Include` provoque un refus si la valeur effective ne correspond pas à la demande.
Les fichiers inclus ne sont jamais modifiés.

Pour relire la valeur effective après l’application.

```bash
pacman-conf --config /etc/pacman.conf ParallelDownloads
```

## Sauvegarde et restauration

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

Le résultat et le retour arrière sont affichés uniquement dans le terminal ;
aucun journal supplémentaire n’est créé par ce script. Les sauvegardes de
configuration restent conservées. En mode simulation, aucun verrou, fichier
temporaire ou sauvegarde n’est créé. L'aperçu ne valide pas
la configuration candidate : cette vérification est faite lors de l'application.

Les tests de `tests/test_pacman_settings.py` utilisent un faux `pacman-conf` et des
fichiers temporaires. Ils couvrent les erreurs, les sauvegardes, la restauration et
les interruptions ; ils ne prouvent pas le fonctionnement du vrai Pacman sous
CachyOS. Aucun changement système réel n'a été effectué pendant leur développement.
