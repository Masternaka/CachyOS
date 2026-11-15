# Diagnostic et validation

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

## Résultat local du 13 novembre 2026

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
