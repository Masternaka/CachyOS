# Diagnostic et validation

[Accueil](../README.md) · [Utiliser les scripts](utilisation.md) · [Tous les guides](../README.md#choisir-un-script)

## Diagnostic de la machine consultée

```bash
python3 -B scripts/diagnostic.py
# Examiner un dossier donné en ignorant les chemins XDG personnels :
python3 -B scripts/diagnostic.py --home /chemin/du/dossier
```

Le diagnostic consulte les outils disponibles, les dépôts Pacman, les paquets
natifs et les propriétés de cinq unités systemd lorsque l'hôte Linux le permet.
Il compare les cibles des configurations aux sources du dépôt : fichier différent,
lien externe, cible spéciale et parent redirigé sont signalés. Les fichiers absents
ne sont pas considérés comme des conflits. Aucun contenu personnel n'est imprimé.

Il ne lance aucun script d'application, sudo, installation, téléchargement, service
ou application graphique. Les commandes consultées ont un délai maximal de dix
secondes chacune. Hors Linux, les contrôles Pacman/systemd sont ignorés. Le code
`1` indique des outils absents, des conflits à examiner ou un diagnostic incomplet ;
il n'autorise aucune correction automatique. Ce relevé est un préalable, pas un plan
exhaustif d'installation ni une validation de la sécurité réseau.

## Vérification du dépôt

Depuis la racine du dépôt, lancer la vérification sur ton ordinateur avant
d’envoyer les changements sur GitHub.

```bash
# Lecture seule : syntaxes Bash/Python/Zsh et cohérence des documents.
python3 -B scripts/verifier_depot.py --statique
# Avec les tests autorisés dans des dossiers temporaires isolés.
python3 -B scripts/verifier_depot.py
```

Le mode statique ne crée ni cache Python ni fixture. Il vérifie les listes
documentées, les chemins locaux des liens Markdown et les références des tests.
Le mode complet utilise les outils déjà disponibles. Zsh, Stow et les parseurs
facultatifs absents produisent des contrôles ignorés, sans installation automatique.
Les tests système remplacent les commandes par des faux outils et redirigent les
écritures dans leurs fixtures. Les configurations personnelles ne servent pas de
fixtures. Les anciens modèles de `config/zsh/` restent des archives avec marqueurs,
exclus de la validation des sources Zsh actives.

## Vérification documentaire du 17 novembre 2026

La documentation utilise désormais un seul `README.md` à la racine. Les guides
Stow, Kitty, Fastfetch et les raccourcis sont regroupés dans `docs/`, avec un
guide d'utilisation des onze scripts. Les anciens modèles Zsh restent conservés
dans `config/zsh/` ; leur rôle est décrit dans le
[catalogue des configurations](dotfiles.md#anciens-modèles-zsh).

`python3 -B scripts/verifier_depot.py --statique` réussit : syntaxes
Bash/Python/Zsh et cinq tests de cohérence documentaire. Le catalogue documenté
correspond aux 59 paquets actifs, répartis en 14 groupes. Les liens locaux et
23 liens vers des sections Markdown ont également été examinés.

Cette passe n'exécute pas les tests avec fixtures et ne valide ni installation
ni configuration sur CachyOS. Aucune application système n'a été lancée.

## Bilans communs du 17 novembre 2026

Les onze scripts utilisent `scripts/bilan.sh`. Ce module affiche le bilan sur
la sortie d'erreur, sans créer de rapport supplémentaire. Les nettoyages et
retours arrière des scripts sont exécutés avant le bilan final. L'aide et les
listes réussies conservent leurs sorties sans ajout. Le vérificateur contrôle
désormais aussi la syntaxe des modules Bash de `scripts/`.

Les **16 tests de `tests/test_bilan.py` réussissent**. Ils couvrent le succès,
l'échec précoce, les actions partielles, l'annulation avant/après des actions,
le signal TERM, les modes de simulation, le mode silencieux, le retour arrière,
les listes longues et l'absence de doublon ou de pollution de la sortie standard.
Ils vérifient aussi le bilan d'une erreur d'arguments sur les onze scripts.
Les fixtures existantes copient le module commun dans leur dépôt temporaire.
Les tests du pare-feu, de Pacman et de systemd vérifient également le bilan lors
d'échecs simulés, notamment après restauration.

La suite complète examine **161 tests : 151 réussissent, 9 échouent et 1 est
ignoré**. Les neuf échecs sont reproduits sans les nouveaux bilans, dans des
copies des scripts de référence avec la sélection de paquets présente avant
cette modification :

- Sept scénarios Flatpak sont bloqués par l'expansion d'un tableau `HOST_TARGETS`
  vide avec `set -u` sous le Bash 3.2 de macOS. Cela ne permet pas de conclure
  sur leur comportement avec Bash sous CachyOS.
- Deux tests de paquets natifs attendent un ancien catalogue ou un ancien nombre
  de nouvelles installations, incompatibles avec la sélection actuelle de
  59 paquets. Cette sélection personnelle n'a pas été changée pour satisfaire
  les tests.
- Le test utilisant le vrai GNU Stow est ignoré car l'outil est absent.

Ces écarts préexistants restent à traiter séparément ; la suite complète n'est
donc pas annoncée comme entièrement réussie. Les contrôles statiques passent.
Aucun outil n'a été installé, aucun service réel n'a été modifié et aucune
installation de paquets ou configuration personnelle n'a été appliquée. Les
tests et la comparaison avec les versions de référence utilisent uniquement
des dossiers temporaires isolés. La validation réelle sous CachyOS reste à faire.

## Résultat historique du 13 novembre 2026

La commande `python3 -B scripts/verifier_depot.py` s'est terminée avec succès :
syntaxes Bash/Python/Zsh, cohérence documentaire et 141 tests examinés, dont
140 réussis et un ignoré. Le contrôle avec le vrai GNU Stow est ignoré parce
que cet outil est absent ; les déploiements simulés restent couverts.
`git diff --check` n’a signalé aucun défaut d’espacement.

Aucun logiciel n'a été installé et aucune configuration système ou personnelle
n'a été appliquée. Les écritures des tests sont restées dans des dossiers
temporaires isolés.

## Validation sur CachyOS

Les tests simulés et les syntaxes ne prouvent pas une transaction Pacman réelle,
une installation Flatpak, un déploiement avec le vrai Stow s'il est absent, ni le
rendu de Niri/Kitty/Foot/Ghostty. La restauration et les accès réseau nécessitent
une validation séparément autorisée sur la cible. Consigner ces validations avec
la date, la version de CachyOS et les résultats, sans publier de données privées.
