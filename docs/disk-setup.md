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

## Examiner le plan

```bash
bash "10 - disk_setup.sh"
```

La simulation indique les labels et l’état de montage sans écrire sur les
disques. Elle annonce l’UID du compte `gabriel`. Le script s’arrête si un
UUID manque, apparaît plusieurs fois ou identifie un autre type de partition.

## Appliquer

Ferme les applications qui utilisent les volumes et démonte les quatre
volumes depuis le gestionnaire de fichiers. Vérifie que les données importantes
sont sauvegardées. Lance ensuite la commande ci-dessous et saisis `APPLIQUER`
après avoir vérifié les cibles.

```bash
sudo bash "10 - disk_setup.sh" --apply
```

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
