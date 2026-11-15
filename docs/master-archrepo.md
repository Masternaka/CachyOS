# Ajouter le dépôt master-archrepo

`08 - install-master-archrepo.sh` configure le dépôt Pacman public qui
distribue SambaPilot et DotfilePilot. Il s’utilise sur CachyOS Linux x86_64
avec `sudo`. Il requiert notamment `curl`, `gpg`, `gpgv`, `pacman-conf` et
`pacman-key`.

## Examiner puis ajouter

Depuis la racine du dépôt, afficher l’aide.

```bash
bash "08 - install-master-archrepo.sh" --help
```

Obtenir l’empreinte primaire OpenPGP complète auprès du propriétaire de la clé
par un canal de confiance distinct du téléchargement. Elle contient 40 ou
64 caractères hexadécimaux sans espaces. Une fois l’ajout voulu et l’empreinte
vérifiée, remplacer `EMPREINTE_VERIFIEE` dans cette commande.

```bash
sudo bash "08 - install-master-archrepo.sh" EMPREINTE_VERIFIEE
```

La commande lance directement l’opération, sans simulation ni confirmation
intégrée avant l’import de la clé.

## Ce que le script vérifie et modifie

1. Il lit `/etc/pacman.conf` avec `pacman-conf`, y compris les dépôts déclarés
   par `Include`. Une section `[master-archrepo]` incompatible bloque l’ajout.
2. Il télécharge par HTTPS la clé publique, la base du dépôt et sa signature.
   Il compare l’empreinte complète et vérifie la signature de la base avec
   cette clé.
3. Il importe la clé et la signe localement dans le trousseau Pacman. Il
   ajoute la section `[master-archrepo]` avec `SigLevel = Required TrustedOnly`
   et sauvegarde la configuration d’origine si le fichier est remplacé.
   Une section déjà conforme peut rester telle quelle.

Après l’ajout, consulter la configuration effective avec
`pacman-conf --repo master-archrepo Server` et
`pacman-conf --repo master-archrepo SigLevel`.

L’installation des applications est une opération séparée qui inclut une
mise à jour système.

```bash
sudo pacman -Syu master-archrepo/sambapilot master-archrepo/dotfilepilot
```

Le [script 05](package-install.md) autorise seulement les dépôts officiels
CachyOS et Arch. Avec `master-archrepo` activé, il s’arrête à son contrôle
de provenance.

## Sauvegarde et retour arrière

Si la configuration a été remplacée, le script affiche un fichier de sauvegarde
`/etc/pacman.conf.before-master-archrepo.*`. Pour retirer le dépôt, comparer
d’abord ce fichier à la configuration actuelle. Restaurer le fichier intégral
uniquement si ses autres réglages doivent aussi revenir à cet état. En présence
de modifications ultérieures, retirer uniquement la section ajoutée.

La restauration de `pacman.conf` laisse la clé et sa signature locale dans
le trousseau Pacman. Examiner l’empreinte et ses usages avant de décider d’un
retrait séparé. Un échec après l’import peut laisser la clé ajoutée même si le
dépôt est absent de la configuration. Les applications déjà installées restent
installées. [Manuel pacman-key](https://man.archlinux.org/man/pacman-key.8)
