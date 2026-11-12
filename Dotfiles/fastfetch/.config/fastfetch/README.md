# Fastfetch Configuration

Configuration personnalisée pour Fastfetch avec affichage organisé par sections et icônes Nerd Font.

## 📁 Structure

```
fastfetch/
└── .config/
    └── fastfetch/
        ├── config.jsonc    # Configuration principale
        └── README.md       # Documentation
```

## 🎯 Vue d'ensemble

Cette configuration affiche les informations système de manière organisée avec :
- **Icônes Nerd Font** pour une présentation visuelle
- **Sections colorées** pour une meilleure lisibilité
- **Séparateurs personnalisés** pour une structure claire
- **Modules organisés** par catégories logiques

## 📊 Modules affichés

### 🖥️ Section Système (Jaune)
- **OS** - Système d'exploitation avec icône de distribution
- **Kernel** - Version du noyau
- **Packages** - Nombre de paquets installés
- **Shell** - Shell utilisé

### 🎨 Section Environnement Desktop (Bleu)
- **DE/WM** - Environnement de bureau ou gestionnaire de fenêtres
- **Login Manager** - Gestionnaire de connexion
- **Theme** - Thème du gestionnaire de fenêtres
- **Icons** - Pack d'icônes
- **Terminal** - Émulateur de terminal
- **Wallpaper** - Fond d'écran actuel

### 💻 Section Matériel (Vert)
- **PC** - Informations sur l'hôte
- **CPU** - Processeur
- **GPU** - Carte graphique
- **Disk** - Espace disque
- **Memory** - Mémoire RAM
- **Swap** - Mémoire swap
- **Display** - Résolution d'écran
- **Uptime** - Temps de fonctionnement

### 🔊 Section Audio (Cyan)
- **Sound** - Informations audio
- **Player** - Lecteur multimédia actif
- **Media** - Média en cours de lecture

### 🌈 Section Couleurs
- **Colors** - Palette de couleurs du terminal

## ⚙️ Configuration

### Format du fichier
Le fichier utilise le format **JSONC** (JSON avec commentaires) pour une meilleure lisibilité.

### Schéma de validation
La configuration suit le schéma officiel de Fastfetch :
```json
"$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json"
```

### Personnalisations principales

#### Logo
```jsonc
"logo": {
  "padding": {
    "top": 2,
  },
}
```
- Padding supérieur de 2 lignes pour le logo ASCII

#### Séparateur
```jsonc
"display": {
  "separator": " -> ",
}
```
- Séparateur personnalisé entre les clés et les valeurs

#### Modules avec icônes
Chaque module utilise des icônes Nerd Font pour une meilleure présentation :
- `├` et `└` pour la structure arborescente
- Icônes spécifiques pour chaque type d'information
- Couleurs par section (yellow, blue, green, cyan)

## Installation sur CachyOS et déploiement Stow

Le paquet natif `fastfetch` est sélectionné dans `08 - package_install.sh`.
Il passe par les dépôts officiels activés et les confirmations de ce script ;
aucun recours à l'AUR n'est nécessaire dans ce parcours. L'installation du
logiciel ne déploie pas ce fichier de configuration.

Le paquet Stow `fastfetch` est indépendant des 15 modules gérés par
`04 - install_zsh.sh` : `--only fastfetch` n'est pas pris en charge.
Depuis la racine du dépôt, avec GNU Stow déjà installé, examiner le plan :

```bash
stow --dir="$PWD/Dotfiles" --target="$HOME" --no-folding --simulate --verbose \
  --stow fastfetch
```

Examiner et sauvegarder les éventuels fichiers en conflit avant toute application.
Après autorisation, retirer `--simulate` pour créer les liens ; ne pas utiliser
`--adopt`. Ce paquet lie aussi le présent README dans `~/.config/fastfetch/`.
Les liens manuels ne créent aucune sauvegarde ni journal de restauration.

Sur la machine cible, une fois le logiciel disponible, cette commande permet
un essai explicite depuis la racine du dépôt sans déployer les fichiers :

```bash
fastfetch --config "$PWD/Dotfiles/fastfetch/.config/fastfetch/config.jsonc"
```

Après déploiement dans les chemins XDG standards, `fastfetch` peut lire
`~/.config/fastfetch/config.jsonc`. Adapter le plan si `XDG_CONFIG_HOME` est
personnalisé. Aucun lancement automatique n'est ajouté à `.zshrc`.

La configuration vise le poste CachyOS/Niri. Les informations d'environnement,
de fond d'écran et d'audio dépendent de ce que la session expose ; leur affichage
n'a pas été validé sur le poste réel. Les icônes nécessitent une police Nerd Font
sélectionnée dans le terminal, par exemple JetBrainsMono Nerd Font.

Pour retirer les liens, examiner le plan ci-dessus en remplaçant `--stow` par
`--delete`, puis l'appliquer seulement après accord. Cela ne désinstalle pas
Fastfetch et ne restaure pas les fichiers antérieurs ; conserver les sauvegardes.

## 🎨 Personnalisation

### Modifier les couleurs
Chaque section utilise une couleur différente. Pour changer une couleur :
```jsonc
{
  "type": "os",
  "key": "OS",
  "keyColor": "red",  // yellow, blue, green, cyan, red, magenta, etc.
}
```

### Ajouter ou retirer des modules
Ajoutez ou supprimez des entrées dans le tableau `modules` :
```jsonc
"modules": [
  "title",
  "separator",
  {
    "type": "votre_module",
    "key": "Votre Clé",
    "keyColor": "couleur",
  },
  // ...
]
```

### Modifier le séparateur
Changez le séparateur dans la section `display` :
```jsonc
"display": {
  "separator": " : ",  // Votre séparateur personnalisé
}
```

### Personnaliser les icônes
Les icônes proviennent de Nerd Fonts. Vous pouvez :
- Consulter [nerdfonts.com](https://www.nerdfonts.com/cheat-sheet) pour trouver d'autres icônes
- Remplacer les codes Unicode dans les clés `key`
- Utiliser des emojis ou du texte simple si vous n'avez pas Nerd Fonts

## 🔧 Modules disponibles

Fastfetch supporte de nombreux modules. Voici quelques exemples :

### Système
- `title` - Titre avec logo ASCII
- `separator` - Ligne de séparation
- `break` - Saut de ligne
- `os` - Système d'exploitation
- `kernel` - Version du noyau
- `uptime` - Temps de fonctionnement
- `packages` - Paquets installés
- `shell` - Shell utilisé

### Matériel
- `host` - Nom de l'hôte
- `cpu` - Processeur
- `gpu` - Carte graphique
- `memory` - Mémoire RAM
- `swap` - Mémoire swap
- `disk` - Espace disque
- `display` - Résolution d'écran

### Logiciel
- `wm` - Gestionnaire de fenêtres
- `de` - Environnement de bureau
- `wmtheme` - Thème du WM
- `icons` - Pack d'icônes
- `terminal` - Terminal
- `player` - Lecteur multimédia
- `media` - Média en cours

### Autres
- `colors` - Palette de couleurs
- `wallpaper` - Fond d'écran
- `sound` - Informations audio

## 📝 Notes

- **Format JSONC** : Le fichier utilise `.jsonc` pour permettre les commentaires
- **Nerd Fonts requis** : Pour afficher correctement les icônes, installez une police Nerd Font
- **Logo ASCII** : Le logo peut être personnalisé ou désactivé selon vos préférences
- **Performance** : Fastfetch est optimisé pour être rapide et léger

## 🐛 Dépannage

### Les icônes ne s'affichent pas correctement
- Installez une police Nerd Font (JetBrainsMono, FiraCode, etc.)
- Configurez votre terminal pour utiliser cette police
- Redémarrez votre terminal

### La configuration ne se charge pas
- Vérifiez le chemin du fichier de configuration
- Utilisez `--config` avec le chemin complet
- Vérifiez la syntaxe JSONC (les commentaires doivent être valides)

### Certains modules ne s'affichent pas
- Certains modules nécessitent des outils système spécifiques
- Vérifiez que les commandes système sont disponibles
- Consultez la documentation Fastfetch pour les prérequis

### Erreur de schéma JSON
- Vérifiez que le schéma est accessible en ligne
- Assurez-vous que la syntaxe JSONC est valide
- Utilisez un éditeur avec validation JSON

## 🔗 Ressources

- [Documentation officielle Fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [Schéma JSON de configuration](https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json)
- [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet)
- [Liste complète des modules](https://github.com/fastfetch-cli/fastfetch/wiki/Modules)

---

**Dernière mise à jour** : 2026-11-12
