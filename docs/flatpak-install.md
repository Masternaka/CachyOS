# Applications Flatpak personnelles

Le script `09 - flatpak_install.sh` installe les 13 applications sélectionnées
depuis Flathub, dans leur branche `stable` et pour l'architecture de l'hôte.
Il se lance **sans sudo**, dans la session du compte concerné. Toutes les
commandes portant sur une installation utilisent explicitement `--user`.

```bash
bash "09 - flatpak_install.sh" --help
bash "09 - flatpak_install.sh" --list
bash "09 - flatpak_install.sh" --dry-run
```

L'aide et la liste ne nécessitent pas Flatpak. La simulation exige Linux,
Flatpak, Distrobox et Podman déjà disponibles. Ces deux derniers sont les
prérequis hôte de BoxBuddy, déjà prévus dans le script de paquets ; le script
Flatpak ne les installe pas et ne modifie pas leur configuration.
Les deux paquets sont actifs dans `08 - package_install.sh` (62 paquets au total).
Le paquet `flatpak` n'y figure pas : vérifier sa présence avant cette étape.

Les [paquets natifs](package-install.md) proviennent des dépôts Pacman ; les
applications de ce guide proviennent du dépôt personnel Flathub. Aucun des deux
scripts ne déploie les configurations [Dotfiles](../Dotfiles/README.md).

## Simulation et confirmations

La simulation consulte uniquement l'architecture, les dépôts personnels et les
applications personnelles installées. Elle affiche les installations et les
vérifications de mise à jour prévues. Elle ne crée aucun inventaire, ne télécharge
rien, n'ajoute pas Flathub et ne nettoie rien. Elle n'annonce aucun faux succès.

La disponibilité distante et les versions nouvelles ne sont pas vérifiées dans
ce mode. L'option Flatpak `--cached` préfère les informations locales, sans
garantir l'absence de requête réseau : elle n'est donc pas employée comme une
simulation réseau. Voir la [référence officielle Flatpak](https://docs.flatpak.org/en/latest/flatpak-command-reference.html).

Pour une exécution souhaitée sur la machine Linux :

```bash
bash "09 - flatpak_install.sh"
# Variante : proposer aussi le nettoyage à la fin.
bash "09 - flatpak_install.sh" --cleanup
```

Un terminal interactif est obligatoire. Après l'aperçu des applications et des
effets, une confirmation autorise la création de l'inventaire, l'accès réseau,
les écritures de cache, l'ajout éventuel du dépôt et les transactions proposées.
L'état local est relu après cette attente ; un changement de dépôts ou
d'applications invalide l'aperçu. Les confirmations natives Flatpak sont conservées,
sans `-y`, sans `--noninteractive` et sans tentative répétée automatiquement.

## Dépôt et applications déjà installées

Le dépôt personnel nommé `flathub` doit utiliser une URL HTTPS reconnue :
`https://dl.flathub.org/repo/` ou `https://flathub.org/repo/` (avec ou sans barre
finale). Une autre URL, un dépôt désactivé, OCI ou sans vérification GPG est
refusé ; sa configuration n'est jamais réparée automatiquement. Le contrôle
ne constitue pas un audit des clés locales ou des autres dépôts.

Si le dépôt personnel manque, son ajout via
`https://flathub.org/repo/flathub.flatpakrepo` a lieu seulement après confirmation.
Les 13 références distantes exactes sont alors contrôlées avant la première
installation. Une référence absente ou une erreur réseau bloque cette étape :
le dépôt et le cache peuvent déjà avoir été créés, mais aucune application
sélectionnée n'a encore été installée.

Pour les applications personnelles sélectionnées :

- Absente : installation de la référence stable exacte depuis Flathub.
- Présente depuis Flathub : recherche de mise à jour de cette seule référence.
- Déjà à jour : comptée comme inchangée, en comparant les commits complets.
- Présente depuis une autre origine : refus, sans migration automatique.

Une application uniquement installée au niveau système n'est pas une installation
personnelle : une copie personnelle sera proposée. Les autres branches et les
applications système sont conservées. Les runtimes et extensions requis peuvent
être installés ou mis à jour par Flatpak ; aucun `flatpak update` global n'est lancé.
Les origines, commits et présences sont contrôlés après chaque transaction.

## Nettoyage et bilan

Aucun nettoyage par défaut. Avec `--cleanup`, si aucune installation ou mise à
jour n'a échoué, une seconde confirmation propose
`flatpak uninstall --user --unused`. Le dialogue natif affiche les éléments
concernés et permet de refuser. Une erreur ou annulation signalée par Flatpak
est conservée comme telle, sans être présentée comme une absence de runtimes.

Le bilan distingue les applications nouvelles, mises à jour, inchangées et les
erreurs. Toute installation, mise à jour, vérification ou suppression en échec
entraîne un code non nul. Une erreur individuelle de transaction n'empêche pas
les suivantes ; `Ctrl+C` interrompt le script. Un échec de lecture d'inventaire
est bloquant. Aucun succès global n'est annoncé après une erreur détectée.

## Inventaires et retour arrière

Après accord, un dossier privé de mode `0700` est créé sous
`/var/tmp/cachyos-flatpak.XXXXXXXX`. Il conserve les dépôts avant/après, les
références (applications, runtimes et extensions), origines et commits abrégés,
la sélection et les nouvelles applications vérifiées. En cas d'échec précoce,
seuls les fichiers déjà produits sont disponibles. Ce dossier contient un guide
de diagnostic et de retrait manuel des nouvelles références.

Il ne sauvegarde ni `~/.var/app`, ni les permissions personnalisées, ni les clés
de dépôts, ni les anciens runtimes. Prévoir une sauvegarde des données importantes
avant des mises à jour. Aucun script de restauration automatique n'est généré.
Retirer une nouvelle application avec `flatpak uninstall --user REFERENCE`
demande un examen préalable ; ne pas ajouter `--delete-data` pour préserver les
données. Cette opération n'annule pas une mise à jour d'application existante.

## Validation

```bash
bash -n "09 - flatpak_install.sh"
python3 -B -m unittest discover -s tests -p test_flatpak_install.py -v
```

Les tests simulent Linux, Flatpak et les outils hôte, avec pseudo-terminal pour
les confirmations et inventaires dans une fixture privée. Ils reproduisent
notamment la colonne `ref` native, qui omet le préfixe `app/`. Aucun téléchargement,
installation réelle, accès à une configuration personnelle ou essai natif sous
CachyOS n'a été effectué pour préparer ces changements.
