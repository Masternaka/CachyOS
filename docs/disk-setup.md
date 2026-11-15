# Configurer les quatre disques secondaires

Le script `10 - disk_setup.sh` est propre à cet ordinateur CachyOS. Il
identifie les partitions ext4 par UUID, même si les noms `/dev/sdX`
changent. Les volumes sont ciblés dans cet ordre.

| Label ext4 | UUID |
| --- | --- |
| Backup Medias | `58cdcfb4-b7c7-45aa-9d27-97d3567e77ba` |
| Disque Samsung | `7c61158b-ac8c-42e6-90ed-1f659acf4335` |
| Medias | `cab0291d-9a2a-4110-a02f-6783238dcda3` |
| SSD | `d594fd69-fb7d-485a-aab4-272da6bee7e0` |

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

Tu peux remonter les volumes depuis le gestionnaire de fichiers après le bilan.
Le script conserve les systèmes de fichiers existants et ne modifie pas
`/etc/fstab`.

## Relevé et retour arrière

Le script affiche un dossier privé `/var/tmp/cachyos-disques.*`. Le fichier
`journal.tsv` indique les volumes traités. Après un échec, une entrée
« Propriété en cours » peut correspondre à un changement partiel.

- `<uuid>.label` conserve le label d’origine. Après avoir confirmé l’UUID et
  démonté la partition, ce label peut être rétabli avec `sudo e2label PÉRIPHÉRIQUE "ANCIEN_LABEL"`.
- `<uuid>.proprietaires` contient, pour chaque entrée concernée, cinq champs
  délimités par des octets NUL : UID, GID, mode, inode et chemin relatif
  (vide pour la racine). Pour rétablir un propriétaire, remonte le bon
  volume, vérifie le chemin et l’inode, puis utilise
  `sudo chown -h -- +UID CHEMIN` sur l’entrée concernée.

Le relevé documente les métadonnées visées. La restauration des données et
des capacités de fichiers dépend de la sauvegarde du volume.
