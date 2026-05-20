# Guide de validation - Script d'installation de Dotfiles

Le script de déploiement de vos dotfiles via GNU Stow a été créé avec succès et configuré pour votre système.

L'ensemble des fichiers modifiés ou créés est listé ci-dessous :
- [install-dotfiles.sh](file:///Users/gchapdelaine/Desktop/Github/CachyOS/Installation%20dotfiles/install-dotfiles.sh) (Nouveau script de déploiement)
- [task.md](file:///Users/gchapdelaine/.gemini/antigravity/brain/cafa2ccc-ff17-44ac-b5db-5d55b0271284/task.md) (Suivi du projet)

---

## 🚀 Comment tester le script en toute sécurité (Simulation / Dry-Run)

Afin de vous assurer que le script réagit parfaitement sans modifier aucun de vos fichiers actuels, vous pouvez lancer une simulation complète.

### Étape 1 : Rendre le script exécutable
Ouvrez votre terminal dans le dossier du dépôt `CachyOS` et lancez la commande suivante :
```bash
chmod +x "Installation dotfiles/install-dotfiles.sh"
```

### Étape 2 : Lancer le test en mode simulation (`--dry-run`)
Pour simuler le déploiement en utilisant votre dépôt local situé sur votre Bureau (`Desktop/Github/dotfiles`), exécutez :
```bash
./Installation\ dotfiles/install-dotfiles.sh --dry-run
```

Si vous souhaitez forcer un chemin de dotfiles spécifique ou tester le clonage temporaire depuis votre dépôt GitHub distant, vous pouvez faire :
```bash
# Pour simuler avec le dossier local spécifique
./Installation\ dotfiles/install-dotfiles.sh -d ~/Desktop/Github/dotfiles --dry-run

# Pour simuler à partir de GitHub (sans utiliser le dossier local du Bureau)
./Installation\ dotfiles/install-dotfiles.sh -r https://github.com/Masternaka/dotfiles --dry-run
```

---

## 🛠️ Ce que fait la simulation (Dry-Run) pas à pas :

1. **Vérification de Stow** : Elle vérifie si GNU Stow est présent sur votre machine. Si Stow est manquant, elle affiche la commande d'installation qui serait exécutée sur votre OS.
2. **Détection du dépôt** : Elle repère automatiquement votre dépôt de dotfiles dans `~/Desktop/Github/dotfiles` et simule une mise à jour (`git pull`).
3. **Menu interactif** : Elle vous présente une magnifique grille avec l'ensemble des 30 paquets de configurations détectés (`kitty`, `ghostty`, `zed`, `starship`, etc.) et vous invite à sélectionner les paquets à simuler.
4. **Analyse des collisions** : Pour chaque paquet choisi, elle scanne récursivement les fichiers existants dans votre répertoire personnel `~` et vous affiche précisément ce qui serait sauvegardé dans `~/.dotfiles_backup/YYYYMMDD_HHMMSS/`.
5. **Rapport final** : Elle résume l'analyse sans effectuer la moindre modification physique sur votre disque dur.

Une fois que vous aurez validé que la simulation se comporte exactement comme vous le souhaitez, vous pourrez lancer l'installation réelle en retirant simplement le flag `--dry-run` :
```bash
./Installation\ dotfiles/install-dotfiles.sh
```
