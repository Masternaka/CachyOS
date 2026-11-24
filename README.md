# CachyOS · Scripts et configurations personnels

Ce dépôt regroupe les scripts et les configurations de mon ordinateur CachyOS
avec Niri. Il peut être consulté ou préparé depuis une autre machine. Chaque
script se choisit selon le besoin : les numéros ne sont pas un ordre obligatoire.

**Commencer ici :** [utiliser les scripts](docs/utilisation.md) ·
[choisir un script](#choisir-un-script) · [configurations](#configurations-et-raccourcis) ·
[diagnostic et dépannage](#diagnostic-et-dépannage)

## Avant de commencer

1. Ouvrir un terminal dans le dossier du dépôt qui contient ce README.
2. Lire le guide du script et vérifier ses prérequis sur la machine CachyOS cible.
3. Ajouter `--dry-run` pour voir le plan. Les menus s’ouvrent directement dans
   le terminal. Utiliser `--help` pour consulter les options du script choisi.
4. Examiner les changements, les sauvegardes et le retour arrière avant de lancer
   volontairement l'application réelle.

Les noms de fichiers contiennent des espaces : conserver les guillemets et
utiliser `bash`, même depuis Fish ou Zsh. Il n'est pas nécessaire de rendre les
scripts exécutables pour les lancer ainsi.

```bash
# Ouvrir le menu Flatpak et examiner le plan.
bash "06 - flatpak_install.sh" --dry-run
```

La plupart des aperçus nécessitent les outils et l'état réel de CachyOS.
Un résultat incomplet ou un outil absent demande un examen ; il n'autorise pas
une installation automatique. Sur une autre machine, commencer par les guides.

**Ne pas lancer tous les scripts à la suite ni ajouter `sudo` partout.**
Le script 08 applique directement son action lorsqu'il est lancé avec les droits
et l’empreinte requis. Les commandes exactes et les confirmations
propres aux onze scripts sont dans le [guide d'utilisation](docs/utilisation.md).

## Choisir un script

Chaque lien ouvre le guide détaillé : prérequis, effets, utilisation et retour
arrière. Les commandes de ces guides sont des exemples à exécuter volontairement.

| Nº | Besoin et guide | Comportement à connaître |
| --- | --- | --- |
| 01 | [Activer Bluetooth, SSH et les timers](docs/systemd-services.md) | `--dry-run` pour examiner. SSH facultatif et confirmation du plan avant application. |
| 02 | [Choisir le pare-feu ou ses règles](docs/firewalld.md) | Aperçu puis application avec `sudo` et confirmation ; peut modifier l'accès réseau. |
| 03 | [Régler les téléchargements Pacman](docs/pacman-settings.md) | Aperçu de `ParallelDownloads` ; valeur explicite appliquée avec `sudo`, sans seconde confirmation. |
| 04 | [Installer et configurer le terminal](docs/zsh.md) | 16 modules ; compte normal, mode copie ou Stow et accords distincts. |
| 05 | [Installer les paquets natifs](docs/package-install.md) | Essentiels, groupes au choix ou catalogue complet. Confirmation avant la mise à jour complète. |
| 06 | [Installer les applications Flatpak](docs/flatpak-install.md) | 13 applications ; compte normal, un accord pour le plan sélectionné. |
| 07 | [Préparer QEMU et Virt-Manager](docs/qemu.md) | Compte normal ; confirmations pour paquets, libvirt et accès facultatif ; NAT désactivable. |
| 08 | [Ajouter master-archrepo](docs/master-archrepo.md) | Empreinte vérifiée obligatoire ; avec `sudo`, sans simulation ni confirmation intégrée. |
| 09 | [Désinstaller des applications](docs/purge-applications.md) | Simulation par défaut ; `--apply` puis saisie de `PURGER` pour agir. |
| 10 | [Configurer les quatre disques personnels](docs/disk-setup.md) | UUID et compte propres à ce poste ; aperçu, élévation puis saisie d'`APPLIQUER`. |
| 11 | [Installer les quatre paquets AUR](docs/aur-install.md) | Aperçu par défaut ; `--install`, revue Paru et confirmations par paquet. |

### Installation des logiciels : quel parcours choisir ?

- **Dépôts CachyOS et Arch :** script 05, pour les essentiels, des groupes
  choisis ou tout le catalogue. Il installe les logiciels sans déployer leurs configurations.
- **Flathub personnel :** script 06, dans le compte concerné et de préférence
  depuis la session Niri pour détecter ses portails.
- **AUR :** script 11, pour `t3code-bin`, `herdr-bin`, `orca-ide-bin` et `gitkraken`,
  après contrôle des dépôts et examen des recettes et de leurs dépendances.
- **SambaPilot et DotfilePilot via master-archrepo :** script 08, démarche
  séparée qui ajoute un dépôt tiers et modifie la confiance Pacman.

Les scripts **05 et 11 refusent les dépôts tiers**, dont master-archrepo,
ainsi que les dépôts de test. Les autres scripts ont leurs propres contrôles :
ne pas leur attribuer automatiquement la même politique de provenance.
Les scripts 04, 06 et 07 peuvent aussi proposer une mise à jour complète du
système pour installer leurs prérequis manquants.

## Configurations et raccourcis

La documentation détaillée est réunie dans `docs/`. Les sources de configuration
restent dans `Dotfiles/` ; les anciens modèles de `config/zsh/` sont conservés
comme archives et ne sont plus utilisés par l'installateur.

| Guide | Ce qu'il permet de retrouver |
| --- | --- |
| [Catalogue des configurations et Stow](docs/dotfiles.md) | Les 17 paquets Stow, leurs chemins, les simulations, les conflits et le retrait des liens. |
| [Outils du terminal et Zsh](docs/zsh.md) | Les 16 modules, palettes Starship, alias, fichiers personnels et restauration. |
| [Kitty](docs/kitty.md) | Thèmes, police, raccourcis et déploiement. |
| [Fastfetch](docs/fastfetch.md) | Modules affichés, personnalisation et déploiement manuel. |
| [Raccourcis et commandes](docs/raccourcis.md) | Aide-mémoire du shell, de Git, des terminaux et des outils système. |

Le script 04 configure ses modules par copies ou liens Stow après confirmation.
Ghostty et Fastfetch se déploient séparément. Stow crée des liens, pas des
installations de logiciels. Les commandes manuelles Stow ne sauvegardent pas les
conflits : consulter le guide avant de les appliquer.

## Diagnostic et dépannage

Depuis la racine du dépôt, ces deux commandes consultent l'état disponible et
vérifient les sources sans installer d'outil ni appliquer de configuration :

```bash
python3 -B scripts/diagnostic.py
python3 -B scripts/verifier_depot.py --statique
```

Le diagnostic décrit **la machine sur laquelle il est exécuté**. Sur macOS, il
ne peut pas décrire l'état de l'ordinateur CachyOS. Le contrôle statique vérifie
les syntaxes et la cohérence documentaire. Les tests avec écritures isolées font
l'objet d'une commande distincte dans le [guide de validation](docs/validation.md).

En cas de refus ou d'échec, lire le premier diagnostic, conserver le chemin de
la sauvegarde ou de l’inventaire et examiner l'état obtenu avant de relancer. Une
installation interrompue peut laisser des paquets ou des dépendances présents.
Un inventaire ne remplace pas une sauvegarde système ou des données.

Les onze scripts affichent un **bilan commun dans le terminal** : résultat,
actions confirmées, éléments inchangés ou ignorés, erreurs et chemins de suivi.
Aucun fichier de rapport final n’est créé. Les sauvegardes et inventaires utiles
au retour arrière sont conservés. Le bilan apparaît aussi après une annulation
ou un échec interceptable. Voir
[comment lire le bilan](docs/utilisation.md#lire-le-bilan-final). Conserver le
dossier `scripts/` avec les scripts numérotés, car il contient `bilan.sh`.

Les scripts qui utilisent les statuts colorés affichent aussi un libellé : vert
pour un succès, bleu pour un état déjà conforme, cyan pour un plan, jaune pour
un avertissement, rouge pour un échec et violet pour une sauvegarde. Les libellés
restent lisibles sans couleur ; `NO_COLOR=1` désactive les couleurs concernées.

## Références

[Wiki CachyOS](https://wiki.cachyos.org/) ·
[Catalogue des paquets CachyOS](https://packages.cachyos.org/) ·
[Documentation Noctalia](https://docs.noctalia.dev/noctalia/) ·
[Wiki Niri](https://github.com/niri-wm/niri/wiki)

Les vérifications syntaxiques et les tests simulés ne prouvent pas le
fonctionnement réel des installations, du réseau, des disques ou du rendu sous
CachyOS. Les résultats et leurs limites sont consignés dans le
[guide de validation](docs/validation.md).
