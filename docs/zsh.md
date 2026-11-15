# Installer et configurer les outils du terminal sous CachyOS

`04 - install_zsh.sh` utilise les fichiers de [Dotfiles](../Dotfiles/README.md)
pour installer les outils sélectionnés, déployer leurs configurations, préparer
Zsh et sélectionner **JetBrainsMono Nerd Font dans Kitty et Foot**.

Lancer le script comme utilisateur normal, jamais avec `sudo`. Le dépôt peut être
préparé sur une autre machine : sa modification ne lance aucune installation.
L'exécution réelle sur votre ordinateur doit rester une action autorisée.

## Plan, sélection et modes

Depuis la racine du dépôt, utilisez la même commande dans Fish, Bash ou Zsh :

```bash
bash "04 - install_zsh.sh" --interactive --dry-run
```

Le menu propose le mode de déploiement, les modules, la palette Starship et les alias Zsh.
Il s’ouvre aussi en lançant le script via Bash sans argument dans un terminal.
`q` quitte le menu avant toute application. `--dry-run` seul affiche directement
le plan de la sélection par défaut.

```bash
bash "04 - install_zsh.sh" --check-scripts
```

Ce contrôle lit les scripts Bash à la racine du dépôt. En vert, le fichier
est exécutable et passe `bash -n`. En rouge, il manque la permission
d’exécution directe ou la syntaxe Bash est invalide. Un script lisible et
syntaxiquement valide peut être lancé avec `bash "nom du script.sh"`.
Le contrôle apparaît aussi dans le plan normal et ne change aucun droit.
Les configurations du plan sont indiquées comme conformes, à créer, à lier ou
à remplacer.

La simulation lit les fichiers, les informations du compte et les bases locales de
Pacman. Elle ne crée aucun lien, fichier, journal, sauvegarde ou cache et ne
contacte pas GitHub. Les fichiers à créer ou remplacer et leur état initial sont
annoncés. Les options inconnues et les modules mal formés sont refusés.

Les seize modules sont sélectionnés par défaut :

```text
zsh,starship,yazi,btop,tealdeer,bat,fzf,zoxide,eza,ripgrep,fd,delta,lazygit,kitty,foot,duf
```

Le module `duf` propose le paquet du même nom, disponible dans le
[dépôt Extra d'Arch](https://archlinux.org/packages/extra/x86_64/duf/), après
vérification dans les dépôts configurés. La commande `duf` affiche l'espace total,
utilisé et disponible des systèmes de fichiers. Elle ne demande aucun fichier de
configuration ni paquet Stow ; `df` et ses alias existants sont conservés.

Le dossier Dotfiles contient 17 paquets Stow au total. Les configurations
supplémentaires `ghostty` et `fastfetch` ne sont pas des modules de cet
installateur et ne peuvent pas être passées à `--only`. Leur déploiement séparé
est décrit dans le [catalogue Dotfiles](../Dotfiles/README.md#ghostty-et-fastfetch).

Pour préparer seulement certains modules :

```bash
bash "04 - install_zsh.sh" --dry-run --only zsh,starship,yazi,kitty,foot
```

Deux modes sont disponibles :

GNU Stow fait partie des dépendances communes : s'il manque, son installation
est proposée avec confirmation même en mode copie, afin de préparer un usage
ultérieur. Cela ne crée aucun lien tant que le mode Stow n'est pas choisi.

- `--mode copy`, par défaut : copies autonomes des configurations. Pour Kitty et
  Foot déjà configurés, seules les directives de police sont remplacées ; les
  autres options et commentaires restent présents. La taille existante est
  conservée (y compris `pixelsize` pour Foot). Un fichier absent reçoit la
  configuration versionnée, avec Foot à 11 points.
- `--mode stow` : liens fichier par fichier vers le dépôt, avec le vrai GNU Stow
  et `--no-folding`. Les fichiers ordinaires en conflit sont sauvegardés puis
  retirés après confirmation, avant simulation et application Stow. Il n'y a
  jamais de `--adopt`. Les configurations Kitty/Foot deviennent alors les fichiers
  canoniques du dépôt ; les anciennes préférences restent dans les sauvegardes.

Exemple de préparation pour Stow :

```bash
bash "04 - install_zsh.sh" --dry-run --mode stow --only zsh,starship,kitty,foot
```

Après autorisation de l'application sur la machine cible, relancer la commande
choisie sans `--dry-run`. Le script redemande un accord pour chaque catégorie
d'action. Il n'existe pas d'option qui accepte tout sans interaction.

Le script lit le shell de connexion dans le compte utilisateur et affiche la
disponibilité de Fish et Zsh. Si le module Zsh est sélectionné, il propose de
garder le shell actuel ou de le remplacer par Zsh après le déploiement. Garder
le shell actuel est le choix par défaut. Un changement confirmé est vérifié et
consigné pour la restauration. Fish reste installé dans les deux cas.
[Changement de shell sous CachyOS](https://wiki.cachyos.org/fr/configuration/post_install_setup/)

Le rapport final récapitule les modules, les installations et vérifications
effectuées, les actions facultatives et le chemin du retour arrière lorsqu’une
session de sauvegarde est disponible.

Autres options :

- `--no-theme` : ne pas déployer le module Starship et conserver la sélection du
  thème existant ; ses autres outils peuvent toujours être configurés.
- `--palette mocha|macchiato|frappe|latte` : sélectionner la variante du thème
  Catppuccin Powerline. Mocha est le choix par défaut. Le menu propose aussi de
  conserver le thème actuel. Les variantes autres que Mocha produisent un
  `starship.toml` propre au compte, sauvegardé comme une copie même si les autres
  modules sont déployés en liens Stow. [Preset Starship](https://starship.rs/presets/catppuccin-powerline)
- `--replace-commands` : activer les alias remplaçant les commandes usuelles
  (`ls`, `cat`, `less`, `cp`, `mv`, `rm`, etc.). Sans cette option, les raccourcis
  distincts comme `ll`, `ccat` et `dfh` sont utilisés.

Pour prévisualiser uniquement Starship en Macchiato.

```bash
bash "04 - install_zsh.sh" --dry-run --only starship --palette macchiato
```
- `--extras` : option conservée pour compatibilité ; fd, Delta et Lazygit sont
  maintenant compris dans la sélection par défaut. `--only` permet de les exclure.

## Confirmations et téléchargements

Les étapes sont séparées et annoncées :

1. **Paquets manquants.** Le script explique puis propose
   `sudo pacman -Syu --needed ...` pour les dépendances des modules sélectionnés.
   Cela inclut une mise à jour complète du système. Il attend votre réponse et
   conserve aussi la confirmation native Pacman ; pas de `--noconfirm`.
2. **fzf-tab**, si Zsh est sélectionné et qu'aucun paquet ne le fournit : un
   téléchargement distinct de la version officielle fixe est proposé. Aucun
   gestionnaire AUR ou gestionnaire de plugins n'est lancé.
3. **Déploiement des fichiers.** Le plan final est revalidé, puis une confirmation
   est demandée avant sauvegarde et application. Un changement de source ou de
   cible entre le plan approuvé et l'application provoque un refus.
4. **Cache Tealdeer**, si sélectionné : le script propose `tldr --update`, qui
   télécharge ou actualise les exemples. Un refus conserve le cache existant ;
   les exemples peuvent manquer si le cache n'existe pas. Un échec est signalé
   sans annoncer une réussite générale ni retirer les configurations validées.
5. **Shell par défaut**, si Zsh est sélectionné : changement facultatif avec
   `chsh`, après vérification du shell enregistré et de `/etc/shells`.

Seules les réponses `o`, `O`, `oui` et `OUI` acceptent une action. Les réponses
vides et la fin d'entrée valent refus. Refuser les paquets, le téléchargement
requis ou le déploiement arrête la préparation. Refuser le cache ou le changement
de shell laisse les configurations appliquées et passe la suite de ces options.

Les installations et mises à jour système, les téléchargements et le cache ne
sont pas annulés par la restauration des configurations. Ils sont annoncés comme
tels avant leur confirmation.

## Intégrations et personnalisation

Les extensions locales de Zsh sont installées par les paquets, puis chargées
sans téléchargement à l'ouverture du terminal : complétions, suggestions,
coloration et recherche d'historique ↑/↓. fzf-tab est chargé après `compinit`
et FZF. La recherche par fragment est chargée après la coloration conformément
à ses instructions d'intégration.

FZF, Zoxide, Eza et Ripgrep lisent leurs fragments ou variables d'environnement
à travers le `.zshrc` commun. Starship utilise le thème Catppuccin
Powerline via `~/.config/starship.toml`.
Le dossier, Git et l’horloge apparaissent sur la première ligne. La durée
s’affiche à partir de deux secondes et la flèche indique le résultat sur la
ligne suivante. Les séparateurs et les icônes utilisent la Nerd Font du terminal.

### Ouvrir un fichier texte dans Yazi

Dans Yazi, `Entrée` ouvre le fichier sélectionné et `O` affiche les choix
d’ouverture. Le script 04 inclut Micro lorsque le module Yazi est sélectionné
et propose son installation après confirmation s’il manque. Pour un fichier
texte, la configuration essaie l’exécutable indiqué par `EDITOR`, puis
`micro`, `nano`, `nvim`, `vim` ou `vi` dans cet ordre. Le code `127` du lanceur d’origine signale généralement que
l’éditeur demandé est introuvable, souvent `vi` lorsque `EDITOR` est vide.
[FAQ Yazi](https://yazi-rs.github.io/docs/faq/#why-cant-i-edit-text-files)

Pour choisir Micro pour une session de Yazi s’il est installé.

```bash
type -a micro
env EDITOR=micro yazi
```

Les alias sont dans [Dotfiles/zsh/.config/cachyos-zsh/aliases.zsh](../Dotfiles/zsh/.config/cachyos-zsh/aliases.zsh),
chargés avec `source` : navigation, fichiers, Git, système, réseau, `bt` pour btop
et `lg` pour Lazygit. La fonction Yazi `y` reste dans `.zshrc` et reprend dans le
shell le dossier choisi après une sortie réussie.

Le fichier personnel `~/.zshrc.local.pre` est chargé avant les intégrations ;
`~/.zshrc.local` est chargé ensuite pour surcharger les alias et les réglages.
Ces fichiers ne sont jamais fournis ou remplacés par le script. Les préférences
explicites comme `STARSHIP_CONFIG`, `FZF_DEFAULT_OPTS` ou `EZA_COLORS` sont respectées.

Le script écrit aussi `~/.config/cachyos-zsh/install-settings.zsh`, avec les valeurs
par défaut de ses options et le chemin local retenu pour fzf-tab. Ce fichier est
copié même en mode Stow, car il dépend de cette installation ; il est sauvegardé
et restauré comme les autres. Les anciennes versions de `config/zsh/` sont
conservées dans le dépôt, mais ne sont plus les sources de cet installateur.

Pour fzf-tab, le script préfère un paquet installé parmi `fzf-tab`, `zsh-fzf-tab`
et `fzf-tab-git`, puis les dépôts configurés. À défaut, il propose le dépôt
[Aloxaf/fzf-tab](https://github.com/Aloxaf/fzf-tab) version `v1.3.0`, commit
`d7e0234614dbe5369fdd760907d12c0e05a4dccc`. Le commit, l'état local et la syntaxe
du point d'entrée sont contrôlés. Une copie existante conforme est réutilisée,
sans `git pull` ; une copie modifiée est refusée sans écrasement.

Les configurations Yazi, btop, Tealdeer, Bat, Delta et Lazygit sont déployées
uniquement si leurs modules sont sélectionnés. Delta devient le pager Git via
`~/.config/git/config`, sans toucher à l'identité ou aux identifiants. Si un
`~/.gitconfig` ordinaire existe, le plan annonce aussi son complément ciblé pour
le pager et `diffFilter`, après sauvegarde intégrale. Un `.gitconfig` symbolique
est refusé sans modification. Le pager effectif est relu avec Git après
déploiement ; une priorité externe qui l'empêche est signalée. Les dépendances
facultatives des aperçus avancés Yazi ne sont pas installées automatiquement.

## JetBrainsMono Nerd Font : Kitty et Foot

Les modules `kitty` et `foot` proposent leurs paquets ainsi que `fontconfig` et
`ttf-jetbrains-mono-nerd`. Le nom configuré est **JetBrainsMono Nerd Font** : la
version avec les glyphes Nerd Font, pas seulement la police JetBrains Mono nue.

Le script configure la famille et les variantes dans les fichiers des terminaux,
puis interroge `fc-match` pour vérifier qu'une famille JetBrainsMono Nerd Font
est trouvée. Un résultat de remplacement est signalé comme un échec de vérification.
La présence de la famille ne prouve pas le rendu de tous les glyphes sur écran.

Aucune fenêtre de terminal n'est lancée ni fermée automatiquement. Rouvrir Kitty
et Foot pour lire les nouveaux réglages ; une session existante n'est pas
transformée en session Zsh. Si le shell a été changé, se reconnecter au besoin.

## Sauvegardes, liens et restauration

Le moteur [scripts/zsh_deploy.py](../scripts/zsh_deploy.py) crée une session privée
unique sous `${XDG_STATE_HOME:-$HOME/.local/state}/cachyos-zsh/backups/`.
Elle contient les originaux, le journal, une copie du moteur de restauration et
`restaurer.sh`. Son chemin est affiché avant les remplacements. Le dossier du dépôt
peut donc évoluer sans supprimer le moteur nécessaire à une ancienne restauration.

Un verrou empêche deux applications simultanées. Les copies utilisent un fichier
temporaire dans le même dossier puis un remplacement atomique. En cas d'échec ou
d'interruption interceptable pendant le déploiement, les fichiers déjà traités
sont restaurés lorsque leur état permet une récupération sûre. En Stow, le moteur
retire les liens créés par cette opération puis restaure les fichiers précédents.
Les sources du dépôt ne sont jamais adoptées, supprimées ou écrasées.

Pour restaurer volontairement, examiner le journal et le script affiché, puis,
après accord sur l'action :

```bash
bash /chemin/de/la/session/restaurer.sh
# ou :
bash "04 - install_zsh.sh" --restore /chemin/de/la/session
```

Une nouvelle confirmation est demandée. Les fichiers copiés modifiés après le
déploiement sont refusés avant toute restauration : ils ne sont pas écrasés.
Les liens attendus sont retirés sans effacer leurs sources. Un changement de shell
avait été tenté ? L'ancien shell est également restauré, après vérification qu'un
autre changement de shell n'est pas intervenu depuis.

Les dossiers vides peuvent rester présents. Une coupure de courant ou `SIGKILL`
nécessite d'examiner la session et de lancer une récupération manuelle ; aucun
programme ne peut intercepter ces arrêts. Les paquets, caches et copies de fzf-tab
ne sont pas désinstallés par ce retour arrière.

## Chemins et limites

En mode copie, les chemins absolus `XDG_CONFIG_HOME`, `XDG_STATE_HOME`,
`XDG_DATA_HOME` et `ZDOTDIR` sont pris en compte. Les cibles de déploiement et les
sauvegardes doivent rester dans le dossier personnel validé. Les parents
symboliques et les liens vers une autre origine sont refusés. Les liens Stow
pointant exactement sur les sources sélectionnées de ce dépôt sont reconnus et
peuvent être conservés ou convertis en copie après examen du plan.

En mode Stow, cette arborescence exige `~/.config` et `~/.zshrc` standards.
Les règles Stow implicites comme `~/.stowrc` sont refusées avant application pour
éviter qu'elles introduisent `--adopt`, une autre cible ou des exclusions cachées.
Le script ne les modifie pas.

Python 3 et les outils de base doivent être disponibles pour préparer le plan.
La validation TOML utilise `tomllib` (Python 3.11+) ou un `tomli` déjà fourni avec
pip ; aucun parseur n'est téléchargé automatiquement. La présence des commandes,
les syntaxes Zsh/TOML, les fichiers copiés ou liés et la famille de police sont
contrôlés. Cela ne constitue pas un lancement graphique de chaque logiciel.

## Vérifications de développement

```bash
bash -n "04 - install_zsh.sh"
python3 -B -m unittest discover -s tests -p 'test_install_zsh.py' -v
python3 -B -m unittest discover -s tests -p 'test_dotfiles.py' -v
```

Les tests utilisent un HOME temporaire et les vrais accès aux fichiers. Pacman,
Git distant, Fontconfig, `chsh`, Tealdeer et Stow y sont simulés ; Zsh et le moteur
Python sont réels. Un test distinct utilise le vrai Stow s'il est déjà disponible,
sinon il est explicitement ignoré. Aucun téléchargement, installation, changement
de shell réel ou déploiement dans le dossier personnel n'est effectué pendant ces
tests. Le rendu Kitty/Foot, les vrais paquets et les accès réseau sous CachyOS
restent à valider sur la machine cible avec autorisation.

Le test de structure vérifie les noms explicites des 17 paquets Stow, y compris
Ghostty et Fastfetch. Le module `duf` n'est pas un paquet Stow ; il est testé
séparément en sélection seule ou mixte. Voir le [guide de validation](validation.md).

Références : [Kitty](https://sw.kovidgoyal.net/kitty/conf/#fonts),
[Foot](https://man.archlinux.org/man/foot.ini.5.en),
[police dans les dépôts CachyOS](https://packages.cachyos.org/package/extra/any/ttf-jetbrains-mono-nerd).
