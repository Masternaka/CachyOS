# Utiliser les scripts

[Accueil](../README.md) · [Choisir un script](../README.md#choisir-un-script) ·
[Diagnostic et validation](validation.md)

Toutes les commandes partent de la racine du dépôt, depuis le compte concerné
sur CachyOS. Dans Fish, Bash ou Zsh, conserver `bash` et les guillemets autour
du nom du fichier. Les exemples d'application ci-dessous changent réellement
la machine : les utiliser seulement une fois le plan examiné et l'action voulue.
Conserver le dossier `scripts/` avec les scripts numérotés : ils utilisent
maintenant son module commun `bilan.sh` pour leur affichage final.

## Comprendre les modes

| Mode | Usage |
| --- | --- |
| `--help` | Afficher l'aide du script ; aucun lancement réel. |
| `--list` | Consulter un catalogue, uniquement sur les scripts 05, 06, 09 et 11. Sur le script 09, c'est l'état local des applications. |
| `--dry-run` | Lire l'état disponible et présenter le plan, sur tous les scripts sauf le 08. N'installe pas les outils manquants. |
| Application | Dépend du script : retrait de `--dry-run`, `--apply` ou `--install`. Voir chaque exemple ci-dessous. |

Un aperçu ne réserve pas l'état du système et ne garantit pas la réussite de
l'application. Certains contrôles nécessitent déjà Pacman, systemd ou d'autres
outils. Ne pas remplacer un refus par l'ajout de `sudo` ou d'une option forcée.
Les aides et listes des scripts 05, 06 et 11 peuvent se consulter hors CachyOS.

## Lire le bilan final

Les onze scripts affichent un même bloc **Bilan de l’opération** à la fin d'une
opération ou d'une simulation. Il reprend le résultat, le code de sortie, les
actions confirmées, les éléments inchangés ou ignorés, les erreurs et les chemins
de suivi disponibles. Les vérifications restant à faire sont indiquées lorsque
le script peut les identifier.

```text
── Bilan de l’opération ──────────────────────────────
  Script       : 11 · Paquets AUR
  Résultat     : Partiellement réussi
  Code de sortie : 1
  Actions confirmées : 2
    - paquet A : présence finale vérifiée.
    - paquet B : présence finale vérifiée.
  Erreurs / avertissements : 1
    - Échec ou refus pour le paquet C ; arrêt du lot.
  À vérifier   : des changements peuvent subsister ; examiner les détails ci-dessus avant de relancer.
  Suivi / sauvegardes : /chemin/du/dossier
```

Les résultats distinguent **réussi**, **partiellement réussi**, **annulé**,
**échoué**, **interrompu**, **simulation terminée** et, si nécessaire,
**terminé avec avertissements**. Une annulation peut survenir après certaines
actions ; celles-ci restent mentionnées. Une action dont seule la tentative
est connue n'est pas comptée comme réussie. « Aucune modification confirmée »
ne signifie donc pas qu'aucun changement n'a pu avoir lieu après un échec.

Les longues listes affichent leur total et leurs huit premiers éléments ; les
autres détails sont dans les étapes précédentes du terminal. Les erreurs ne
sont pas abrégées. Après le retour arrière automatique du mode règles du
pare-feu, les actions exécutées auparavant sont identifiées comme telles,
sans être présentées comme des changements encore appliqués.

Le bilan s'affiche après le nettoyage ou la tentative de retour arrière prévue
par chaque script. Il ne crée aucun rapport supplémentaire sur disque et ne
change pas les codes de sortie existants. Les sauvegardes et inventaires propres
aux scripts sont conservés comme auparavant. Leurs chemins ne sont affichés que
lorsqu'ils sont connus ; un inventaire ne remplace pas une sauvegarde complète.

Le bilan utilise la sortie d'erreur (`stderr`) pour préserver les listes et les
aperçus de configuration sur la sortie standard. Les aides et les listes seules
ne reçoivent pas de bilan supplémentaire lorsqu'elles réussissent. Le mode `--silent` du script
03 conserve son comportement silencieux en cas de succès. Une erreur précoce
affiche les informations disponibles ; `SIGKILL`, une coupure de courant ou une
impossibilité d'écrire dans le terminal ne permettent pas de garantir un bilan.

## 01 · Services systemd

Préparer les paquets `bluez`, `openssh`, `util-linux` et `pacman-contrib`.
Le script n'installe pas ces prérequis.

```bash
# Aperçu sans sudo.
bash "01 - systemd_services.sh" --dry-run
```

Application volontaire :

```bash
sudo bash "01 - systemd_services.sh"
```

**Cette commande ne redemande pas confirmation.** Elle démarre et active
Bluetooth, SSH et les timers TRIM/nettoyage du cache. SSH peut exposer un accès
réseau selon sa configuration et le pare-feu. Les timers peuvent agir dès leur
activation. Le chemin du fichier de retour arrière est affiché.
[Détails et contrôles après application](systemd-services.md).

## 02 · Pare-feu

Depuis un accès local, choisir entre le menu UFW/firewalld et les règles d'un
firewalld déjà installé et actif :

```bash
bash "02 - firewalld_settings.sh" --interactive --dry-run
bash "02 - firewalld_settings.sh" --dry-run --zone home --services ssh,samba
```

Pour appliquer **un seul de ces plans**, reprendre la commande choisie sans
`--dry-run` et avec `sudo bash`. Une confirmation précède les modifications.
L'arrêt d'un pare-feu peut laisser la machine sans protection ; les ouvertures
SSH/Samba concernent toute la zone. Le script ne démarre pas ces serveurs.
Conserver le dossier de sauvegarde et examiner `restaurer.sh` avant usage.
[Guide pare-feu et migration depuis UFW](firewalld.md).

## 03 · Téléchargements parallèles Pacman

```bash
bash "03 - pacman_settings.sh" --dry-run --value 5
# Autre choix : estimation à partir du CPU et de la RAM.
bash "03 - pacman_settings.sh" --dry-run --auto
```

Application de la valeur examinée :

```bash
sudo bash "03 - pacman_settings.sh" --value 5
```

La valeur explicite est appliquée sans seconde confirmation. Le script modifie
`/etc/pacman.conf`, conserve une sauvegarde et affiche son chemin. Les valeurs
vont de 0 à 20 ; `0` désactive la directive locale et exige une valeur effective
de 1. [Valeurs, contrôles et restauration](pacman-settings.md).

## 04 · Zsh et outils du terminal

Lancer depuis le compte utilisateur normal. Choisir les modules, le mode copie
ou Stow, les alias et la palette Starship dans le menu :

```bash
bash "04 - install_zsh.sh" --interactive --dry-run
# Exemple de sélection précise :
bash "04 - install_zsh.sh" --dry-run --mode stow --only zsh,starship,kitty,foot
```

Pour appliquer, relancer le menu ou la sélection voulue sans `--dry-run`.
Des accords distincts couvrent les paquets et la mise à jour système, fzf-tab
éventuel, le déploiement sauvegardé, le cache Tealdeer et le changement facultatif
du shell. Garder Fish comme shell reste possible. Ghostty et Fastfetch ne sont
pas des modules de cet installateur. [Options et restauration](zsh.md).

## 05 · Paquets natifs

```bash
bash "05 - package_install.sh" --list-groups
bash "05 - package_install.sh" --list
bash "05 - package_install.sh" --groups virtualisation,terminal --dry-run
```

Après examen, appliquer cette sélection depuis le compte normal :

```bash
bash "05 - package_install.sh" --groups virtualisation,terminal
```

Omettre `--groups` sélectionne les 41 paquets. **Même avec un seul groupe,
Pacman met à jour l'ensemble du système** après confirmation. Les dépôts tiers
et de test sont refusés. Une base locale absente ou ancienne peut empêcher
l'aperçu ; préparer séparément la mise à jour, sans `pacman -Sy` isolé.
Les inventaires avant/après ne constituent pas une sauvegarde complète.
[Catalogue exact des 14 groupes et limites](package-install.md).

## 06 · Applications Flatpak

Dans la session du compte concerné, de préférence sous Niri :

```bash
bash "06 - flatpak_install.sh" --list
bash "06 - flatpak_install.sh" --dry-run --only 2,3
```

Pour ouvrir le menu d'installation, lancer sans `--dry-run` et sans `sudo` :

```bash
bash "06 - flatpak_install.sh"
```

Saisir les numéros séparés par des virgules ; Entrée sélectionne tout et `q`
annule. `--only` accepte aussi des identifiants exacts. Un accord couvre le plan,
y compris l'ajout éventuel de Flathub et les dépendances. Les commandes suivantes
utilisent des réponses automatiques ; les prérequis natifs manquants impliquent
une mise à jour complète avec Pacman. Relire le plan avant de confirmer.
[Catalogue, portée de l'accord et retour arrière](flatpak-install.md).

## 07 · QEMU et Virt-Manager

```bash
bash "07 - install_qemu.sh" --dry-run
# Si le réseau NAT ne doit pas être préparé :
bash "07 - install_qemu.sh" --dry-run --no-network
```

Lancer la commande choisie sans `--dry-run`, toujours depuis le compte normal,
pour appliquer après confirmations. Le script peut installer des paquets,
démarrer libvirt, préparer le stockage et le réseau NAT `192.168.122.0/24`.
Vérifier l'absence de conflit avec le LAN ou un VPN. Une permission locale
facultative permet d'administrer libvirt sans mot de passe ; elle demande un
accord séparé. [Prérequis KVM, sauvegardes et vérification d'une VM](qemu.md).

## 08 · Dépôt master-archrepo

Ce script n'a pas de simulation. Commencer par son aide et son guide :

```bash
bash "08 - install-master-archrepo.sh" --help
```

Pour ajouter volontairement le dépôt, obtenir l'empreinte primaire complète par
un canal de confiance distinct, puis remplacer le texte d'exemple :

```bash
sudo bash "08 - install-master-archrepo.sh" EMPREINTE_VERIFIEE
```

**Cette commande agit sans confirmation intégrée.** Elle télécharge la clé et
la base signée, modifie le trousseau Pacman et peut remplacer `pacman.conf`.
L'installation des applications reste séparée. Les scripts 05 et 11 refusent
l'exécution tant que ce dépôt tiers est activé.
[Vérifier l'empreinte et comprendre le retrait](master-archrepo.md).

## 09 · Désinstaller des applications

```bash
bash "09 - purge_applications.sh" --list
# Menu de sélection en simulation, sans suppression :
bash "09 - purge_applications.sh"
# Exemple ciblé :
bash "09 - purge_applications.sh" --dry-run --pacman haruna --config haruna
```

Pour appliquer, reprendre les cibles avec `--apply` à la place de `--dry-run`,
ou lancer `--apply` seul pour refaire la sélection. Le script exige la saisie
de `PURGER`, sauvegarde les éléments prévus puis désinstalle les applications
et met de côté les configurations ciblées. Fermer les applications avant cela.
Les données et caches restent hors de cette purge.
[Sélection Pacman/Flatpak, sauvegardes et réinstallation](purge-applications.md).

## 10 · Quatre disques secondaires

**Ce script contient les UUID des disques personnels et vise le compte
`gabriel`.** Vérifier ces valeurs dans le guide et le fichier avant usage.

```bash
bash "10 - disk_setup.sh" --dry-run
```

Pour poursuivre volontairement, lancer sans option depuis le compte normal.
Le menu propose l'élévation avec sudo, puis exige `APPLIQUER` après les contrôles.
Les volumes doivent être démontés et les données sauvegardées. Le script change
la propriété de tout leur contenu, leurs labels et le montage dans `/etc/fstab`.
Le relevé des métadonnées ne remplace pas une sauvegarde des volumes.
[UUID, effets et retour arrière](disk-setup.md).

## 11 · Quatre paquets AUR

```bash
bash "11 - aur_install.sh" --list
bash "11 - aur_install.sh" --dry-run
```

Paru et ses prérequis doivent déjà être installés. Préparer séparément la mise
à jour complète et une sauvegarde restaurable, puis, si l'installation est voulue :

```bash
bash "11 - aur_install.sh" --install
```

Le script demande confirmation avant les téléchargements, vérifie les quatre
noms auprès de l'AUR, puis demande d'examiner chaque paquet avec la revue Paru.
Lire aussi les recettes des dépendances. Une installation interrompue peut
laisser des paquets présents ; une revue ne garantit pas leur sécurité.
[Contrôles AUR, suivi et retour arrière](aur-install.md).
