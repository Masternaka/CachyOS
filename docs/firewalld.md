# Configurer le pare-feu

## Menu interactif

```bash
bash "02 - firewalld_settings.sh" --interactive --dry-run
```

Le menu s’ouvre aussi sans argument depuis un terminal. Il affiche l’état des
unités systemd et interroge les règles UFW avec `ufw status`, qui peut nécessiter
les droits root. Chaque choix propose de passer l’étape. Gufw correspond à UFW
et Firewall Config à firewalld. Pacman vérifie la présence du paquet dans les
dépôts configurés et présente sa transaction avant installation.
[Gufw](https://packages.cachyos.org/package/extra/any/gufw) ·
[Firewall Config](https://packages.cachyos.org/package/extra/any/firewall-config)

Après autorisation sur la cible, ouvrir le menu avec `sudo bash` depuis un accès
local. L’arrêt peut couper une connexion ou laisser la machine sans l’un de ces
deux pare-feu actifs. Le menu présente les commandes et demande confirmation.
Si une interface et une désactivation sont sélectionnées, l’installation passe
en premier. Le choix de l’interface est indépendant du choix de désactivation.

Le rapport final indique les commandes exécutées, les vérifications et le
dossier de sauvegarde. Avant l’arrêt, le script copie la configuration et
conserve un relevé dans `/var/tmp/cachyos-firewall.*`. Le fichier `restaurer.sh`
est à examiner depuis un accès local avant une autre modification. Il permet
de rétablir l’état du service et la configuration d’activation d’UFW. Les
règles temporaires firewalld peuvent demander une restauration manuelle.
L’interface graphique installée reste installée lors de ce retour arrière.

L’arrêt de firewalld est vérifié via systemd. Avec `CleanupOnExit=no`, ses
règles peuvent rester chargées après l’arrêt. Une autre unité peut aussi
redémarrer firewalld à la demande. Le menu permet de conserver l’autre
pare-feu dans son état actuel. [Configuration firewalld](https://firewalld.org/documentation/man-pages/firewalld.conf.html) ·
[Gestion du service](https://firewalld.org/documentation/howto/enable-and-disable-firewalld)

## Régler la zone et les services de firewalld

```bash
bash "02 - firewalld_settings.sh" --dry-run --services ssh
bash "02 - firewalld_settings.sh" --dry-run --zone home --services ssh,samba
bash "02 - firewalld_settings.sh" --dry-run --services none
```

Une sélection explicite est obligatoire ; `none` conserve les autorisations
existantes sans en ajouter. Les services non sélectionnés ne sont pas supprimés.
Le script lit les états systemd et firewalld ; une lecture impossible bloque le
plan. Les configurations active et permanente sont interrogées séparément.
Aucun fichier, installation ou élévation dans la simulation. Selon les permissions
locales, certaines lectures peuvent être refusées ; le script n'élève pas ses droits.

Les ouvertures concernent toute la zone choisie. La zone par défaut ne remplace
pas les affectations explicites des interfaces ou des profils NetworkManager.
Depuis un accès local, examiner les zones actives avant d'autoriser l'application.
Une connexion distante peut être interrompue pendant un changement de zone.

## Application et retour arrière

Après autorisation sur la cible, utiliser `sudo bash` avec les mêmes options et
sans `--dry-run`. Le script demande confirmation puis relit le plan ; tout écart
sur les états surveillés provoque un refus avant modification.

Le dossier privé `/var/tmp/cachyos-firewall.*` conserve :

- une copie de référence de `/etc/firewalld` lorsqu'il existe ;
- les inventaires des zones actives et permanentes ;
- `restaurer.sh`, qui rétablit l'ancienne zone par défaut et retire seulement les
  services absents au moment du plan dans chaque configuration.

Le script n'effectue aucun `reload` global. En cas d'échec ou de signal intercepté,
il tente ce retour arrière. Un retour incomplet est signalé et le dossier est
conservé. Après une coupure ou SIGKILL, examiner le dossier depuis un accès local.
Pour un retour volontaire, examiner puis lancer `sudo bash CHEMIN/restaurer.sh`
**avant d'autres changements volontaires**. Il ne détecte pas les intentions
ultérieures de l'utilisateur ; ne pas le réutiliser après une nouvelle configuration.
La copie globale n'est pas réappliquée automatiquement.

## Migration depuis UFW : procédure distincte

Le menu peut désactiver UFW. La reprise des règles et le démarrage du pare-feu
de remplacement relèvent d’une migration distincte. Un service UFW actif, activé
au démarrage ou dans un état non pris en charge bloque le mode `--services` sur
firewalld.

Avant une migration réelle, préparer séparément :

1. Un accès local et un inventaire des interfaces, des zones, des règles UFW et
   des accès SSH/Samba nécessaires ; vérifier les unités et leurs éventuels conflits.
2. Une sauvegarde des configurations UFW et firewalld, des états des services et
   un plan de restauration d'UFW indépendant du réseau.
3. L'installation préalable des paquets nécessaires, sans retirer UFW.
4. Un plan exact de bascule et de validation adapté à cette machine, avec
   autorisation explicite avant son exécution. La préparation des règles hors ligne
   et l'ordre d'arrêt/démarrage doivent être décidés avec les états réels.
5. La validation de firewalld et des accès depuis les réseaux concernés, puis
   seulement une éventuelle désinstallation d'UFW séparément autorisée.

Aucune migration native ni connexion réelle n'a été testée ici.

Références : [état de firewalld](https://firewalld.org/documentation/howto/get-firewalld-state.html),
[configurations active et permanente](https://firewalld.org/documentation/configuration/runtime-versus-permanent.html),
[commandes et codes de retour](https://firewalld.org/documentation/man-pages/firewall-cmd.html).
