# Configuration Kitty Terminal

Cette configuration vise le poste CachyOS avec Niri. Le fichier versionné sélectionne Catppuccin Macchiato et JetBrainsMono Nerd Font. Le dépôt ne déploie aucun fichier par sa simple présence ; les commandes ci-dessous restent à examiner avant application.

## 📁 Structure des fichiers

```
kitty/
├── kitty.conf              # Configuration principale
├── themes/
│   ├── gruvbox.conf        # Variante disponible
│   ├── catppuccin-macchiato.conf # Thème actif
│   ├── dracula.conf
│   ├── nord.conf
│   └── ...
└── README.md               # Ce fichier
```

## 🎨 Thème

### Catppuccin Macchiato

Le thème est chargé par `include ~/.config/kitty/themes/catppuccin-macchiato.conf`.
Les variantes Gruvbox, Dracula et Nord restent fournies pour une sélection manuelle.
L'opacité active est `0.85`. Le curseur est explicitement surchargé par
`cursor_color #928374` dans `kitty.conf`.

## ⚙️ Configuration détaillée

### Fenêtre et affichage
- **Dimensions initiales** : 1050 × 600 dans le fichier ; taille effective en mosaïque déterminée par Niri
- **Espacement** : 10px de padding
- **Décorations** : Non masquées par le fichier (`hide_window_decorations no`)
- **Transparence** : 0.85 (85% d'opacité)
- **Mémorisation** : Taille et position non mémorisées
- **Retour à la ligne** : Activé (`wrap_lines yes`)
- **Liens hypertexte** : Cibles affichées (`show_hyperlink_targets yes`)
- **Ouverture d'URL** : Utilise l'application par défaut

### Police
- **Famille** : JetBrainsMono Nerd Font
- **Taille** : 12.0 points dans la source ; le mode copie préserve la taille existante
- **Ligatures** : Activées pour une meilleure typographie
- **Variations** : Auto pour gras/italique/bold-italic

### Curseur
- **Forme** : Bloc (`block`)
- **Couleur** : `#928374` (gris Gruvbox)
- **Clignotement** : Intervalle de 0.5s, arrêt après 1s
- **Trail** : Traînée activée (niveau 1)

### Onglets
- **Position** : En haut (`tab_bar_edge top`)
- **Style** : Powerline avec style incliné (`slanted`)
- **Template** : Affiche le titre et le nombre de fenêtres si > 1

### Comportement
- **Historique** : 2 000 lignes de scrollback
- **Indicateur scrollback** : Opacité 0 (invisible)
- **Défilement molette** : Minimum 1 ligne
- **Copie** : Automatique sur sélection (`copy_on_select yes`)
- **Copie propre** : Supprime les espaces en fin de ligne lors de la copie
- **Navigation** : Focus suit la souris (`focus_follows_mouse yes`)
- **Notifications** : Visuelles seulement (pas de son)
- **Cloche** : Désactivée sur les onglets (`bell_on_tab no`)
- **Contrôle distant** : Activé (`allow_remote_control yes`)
- **Fermeture** : Pas de confirmation (`confirm_os_window_close 0`)

## ⌨️ Raccourcis clavier

Les lignes `map` de `kitty.conf` sont actuellement commentées. Les exemples
ci-dessous décrivent les actions envisagées, pas des raccourcis activés par ce
fichier. Les raccourcis effectifs dépendent des valeurs par défaut de Kitty et
des autres réglages chargés. Vérifier les conflits avec Niri avant d'en activer.

### Gestion des onglets
- `Ctrl+Tab` : Onglet suivant
- `Ctrl+Shift+Tab` : Onglet précédent
- `Ctrl+Shift+T` : Nouvel onglet
- `Ctrl+Shift+W` : Fermer l'onglet

### Split de fenêtre
- `Ctrl+Shift+D` : Split horizontal
- `Ctrl+Shift+E` : Split vertical
- `Ctrl+Shift+Flèches` : Navigation entre splits

### Navigation et scroll
- `Ctrl+Shift+Haut/Bas` : Ligne par ligne
- `Ctrl+Shift+Page Haut/Bas` : Page par page
- `Ctrl+Shift+Home/End` : Début/Fin du buffer

### Copier-coller
- `Ctrl+Shift+C` : Copier
- `Ctrl+Shift+V` : Coller

### Taille de police
- `Ctrl+Shift+Plus` : Augmenter la police (+2.0pt)
- `Ctrl+Shift+Moins` : Diminuer la police (-2.0pt)
- `Ctrl+Shift+0` : Réinitialiser la taille
- `Ctrl+Shift+KP_Add` : Augmenter (pavé numérique)
- `Ctrl+Shift+KP_Subtract` : Diminuer (pavé numérique)

### Autres
- `Ctrl+Shift+F11` : Plein écran
- `Ctrl+Shift+F2` : Éditer la configuration

## Linux et Niri

Les anciennes options `macos_*` restent comme exemples commentés à la fin du
fichier ; elles ne sont pas activées. Niri gère la disposition des fenêtres.
Le fichier `quick-access-terminal.conf` prépare des préférences pour un terminal
d'accès rapide, mais aucun lancement ni raccourci Niri n'est ajouté automatiquement.
Le comportement réel reste à valider sous CachyOS.

## 🚀 Performance

### Structure de la configuration

Le fichier `kitty.conf` est organisé en sections numérotées et commentées :

1. **Thème** : Inclusion du thème Catppuccin Macchiato
2. **Shell** : Aucun shell imposé ; exemples Zsh/Fish commentés
3. **Apparence - Fenêtre** : Dimensions, décorations, transparence, espacement
4. **Apparence - Police & Curseur** : Police, ligatures, curseur avec clignotement
5. **Apparence - Onglets** : Style Powerline avec template personnalisé
6. **Comportement - Scrollback & Copie** : Historique, copie automatique
7. **Comportement - Interface** : Souris, affichage, audio, contrôle distant
8. **Raccourcis - Onglets** : Navigation entre onglets
9. **Raccourcis - Fenêtres & Splits** : Splits et navigation
10. **Raccourcis - Scrolling & Zoom** : Défilement et zoom de police
11. **Raccourcis - Éditeur & Presse-papiers** : Copier-coller et édition config
12. **Anciennes options macOS** : Exemples commentés

## 🛠️ Personnalisation

### Changer de thème
1. Commentez la ligne actuelle dans `kitty.conf` :
   ```conf
   # include ~/.config/kitty/themes/catppuccin-macchiato.conf
   ```
2. Ajoutez le nouveau thème :
   ```conf
   include ~/.config/kitty/themes/votre-theme.conf
   ```

### Ajuster la transparence
Modifiez dans la section "3. APPARENCE - FENÊTRE" :
```conf
background_opacity 0.95  # Plus opaque
background_opacity 0.8   # Plus transparent
background_opacity 0.85  # Actuel
```

### Modifier le curseur
Dans la section "4. APPARENCE - POLICE & CURSEUR" :
```conf
cursor_shape block        # block, beam, underline
cursor_blink_interval 0.5  # Intervalle de clignotement (secondes)
cursor_stop_blinking_after 1  # Arrêt après X secondes
cursor_trail 1           # Traînée (0-10)
```

### Personnaliser les onglets
Dans la section "5. APPARENCE - ONGLETS" :
```conf
tab_bar_style powerline  # powerline, fade, separator, hidden
tab_powerline_style slanted  # slanted, angled, round
tab_title_template {title}  # Template personnalisé
```

### Ajouter des raccourcis
Utilisez le format :
```conf
map vos+raccourcis votre_commande
```

## Installation et déploiement sur CachyOS

`08 - package_install.sh` propose Kitty et la police depuis les dépôts natifs,
sans déployer les fichiers. `04 - install_zsh.sh` sait installer ces dépendances
et déployer le module `kitty`, après confirmations :

```bash
bash "04 - install_zsh.sh" --dry-run --only kitty
bash "04 - install_zsh.sh" --dry-run --mode stow --only kitty
```

Ces commandes se lancent depuis la racine du dépôt, sans sudo. Le mode copie
préserve la taille et les autres réglages d'un `kitty.conf` existant lors du
changement de police. Le mode Stow lie les fichiers versionnés après sauvegarde
et confirmation. Les thèmes et fichiers complémentaires font partie du paquet.

Pour Stow manuel, avec les logiciels déjà présents, examiner :

```bash
stow --dir="$PWD/Dotfiles" --target="$HOME" --no-folding --simulate --verbose \
  --stow kitty
```

Sauvegarder les conflits puis, après autorisation, retirer `--simulate` pour
appliquer. Ne pas utiliser `--adopt`. Stow manuel lie aussi ce README et ne crée
aucune sauvegarde automatique. Fermer et rouvrir Kitty pour vérifier le rendu
une fois les configurations déployées.

## 🔧 Dépannage

### Problèmes courants
- **Police non trouvée** : Installez JetBrainsMono Nerd Font
- **Thème ne s'applique pas** : Vérifiez le chemin du fichier de thème
- **Raccourcis** : Les exemples `map` sont commentés ; vérifier les raccourcis actifs et ceux de Niri

### Logs et debug
Activer le mode debug :
```bash
kitty --debug-config
```

## 📚 Ressources

- [Documentation Kitty](https://sw.kovidgoyal.net/kitty/)
- [Thèmes Kitty](https://github.com/kovidgoyal/kitty-themes)
- [Gruvbox Theme](https://github.com/morhetz/gruvbox)
- [Référence de configuration](https://sw.kovidgoyal.net/kitty/conf.html)

## 📝 Notes

- Configuration organisée en sections numérotées pour faciliter la maintenance
- Tous les paramètres sont commentés en français
- Configuration destinée à CachyOS/Niri ; exemples macOS inactifs
- Support complet des Nerd Fonts pour les icônes
- Intégration shell activée pour une meilleure expérience

---

**Dernière mise à jour** : 2026-11-12

*Rendu natif et prise en charge des options à vérifier avec la version Kitty installée.*
