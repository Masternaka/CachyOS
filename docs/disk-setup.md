# Configurer les quatre disques secondaires

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

Le script `10 - disk_setup.sh` est propre à cet ordinateur CachyOS. Il
identifie les partitions ext4 par UUID, même si les noms `/dev/sdX`
changent. Les volumes sont ciblés dans cet ordre.

| Label ext4 | UUID | Point de montage |
| --- | --- | --- |
| Backup Medias | `58cdcfb4-b7c7-45aa-9d27-97d3567e77ba` | `/mnt/Backup Medias` |
| Disque Samsung | `7c61158b-ac8c-42e6-90ed-1f659acf4335` | `/mnt/Disque Samsung` |
| Medias | `cab0291d-9a2a-4110-a02f-6783238dcda3` | `/mnt/Medias` |
| SSD | `d594fd69-fb7d-485a-aab4-272da6bee7e0` | `/mnt/SSD` |

## Ouvrir le menu

```bash
bash "10 - disk_setup.sh"
```

Le menu indique les labels, les volumes montés et l’UID du compte `gabriel`.
Si un volume est encore monté, ferme les fichiers ouverts et démonte le volume
depuis le gestionnaire de fichiers. Appuie sur Entrée pour actualiser ou sur
`q` pour quitter. Si tu veux seulement voir l’inventaire, lance
`bash "10 - disk_setup.sh" --dry-run`. Un lancement sans terminal affiche aussi
seulement l’inventaire.

## Appliquer

Quand les quatre volumes sont démontés et tes données importantes
sauvegardées, réponds `o` à la proposition de poursuivre avec `sudo`. Le script
relit les identifiants sur les partitions et vérifie le format ext4, l’absence
de montage et l’accès en écriture. Il s’arrête si un UUID manque ou si
plusieurs partitions correspondent. Une fois les contrôles passés, tape
`APPLIQUER` pour effectuer les changements. Toute autre réponse annule.
Le script vérifie de nouveau les cibles avant le premier montage et refuse
qu’une seconde exécution modifie les volumes en même temps.

Pour chaque partition, le script monte brièvement le volume dans un dossier
privé. Il consigne les propriétaires d’origine, attribue à `gabriel` la racine
du volume et tout son contenu, puis vérifie le propriétaire. Il change aussi
le propriétaire des liens symboliques eux-mêmes sans suivre leurs cibles.
Les groupes sont conservés. Le changement de propriétaire peut retirer
certains bits spéciaux ou certaines capacités de fichiers. Une fois le volume
démonté, le script corrige le label s’il diffère, puis le relit.

Le script vérifie le fichier `/etc/fstab` préparé et l’installe après avoir
traité les quatre volumes. Il refuse de remplacer une entrée en conflit ou
d’utiliser un dossier de montage non vide. Une entrée identique est réutilisée.
Au prochain démarrage, le système monte les volumes dans les dossiers ci-dessus.
L’option `nofail` laisse le démarrage se poursuivre si l’un d’eux est absent.

## Relevé et retour arrière

Le script affiche un dossier privé `/var/tmp/cachyos-disques.*`. Le fichier
`journal.tsv` indique les volumes traités. Après un échec, une entrée
« Propriété en cours » peut correspondre à un changement partiel.

- `fstab.avant` conserve le fichier d’origine si des entrées de montage ont
  été ajoutées. Pour désactiver le montage automatique, compare la sauvegarde
  à `/etc/fstab` et retire les entrées ajoutées en conservant les autres
  modifications faites depuis.
- `<uuid>.label` conserve le label d’origine. Après avoir confirmé l’UUID et
  démonté la partition, ce label peut être rétabli avec `sudo e2label PÉRIPHÉRIQUE "ANCIEN_LABEL"`.
- `<uuid>.proprietaires` contient, pour chaque entrée concernée, cinq champs
  délimités par des octets NUL : UID, GID, mode, inode et chemin relatif
  (vide pour la racine). Pour rétablir un propriétaire, remonte le bon
  volume, vérifie le chemin et l’inode, puis utilise
  `sudo chown -h -- +UID CHEMIN` sur l’entrée concernée.

Le relevé documente les métadonnées visées. La restauration des données et
des capacités de fichiers dépend de la sauvegarde du volume.
