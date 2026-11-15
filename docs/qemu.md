# Installer QEMU/KVM et Virt-Manager

`07 - install_qemu.sh` prépare la virtualisation sur CachyOS x86_64 avec
systemd. Lancer depuis le compte qui utilisera Virt-Manager. Les commandes
système utilisent `sudo` après confirmation.

```bash
bash "07 - install_qemu.sh" --dry-run
bash "07 - install_qemu.sh" --dry-run --no-network
```

La simulation vérifie les paquets locaux, les unités systemd et la présence
de `/dev/kvm`. Elle ne lance pas libvirt. Si les extensions de virtualisation
du processeur ne sont pas visibles, vérifier leur activation dans l’UEFI ou
sur l’hyperviseur hôte.

## Appliquer la configuration

```bash
bash "07 - install_qemu.sh"
```

1. **Paquets.** Pacman propose QEMU, libvirt, Virt-Manager, OVMF (UEFI) et
   `swtpm` (TPM virtuel). Lorsque le réseau NAT est demandé, les dépendances
   hôte comprennent aussi dnsmasq et les outils de filtrage. L’installation
   des paquets manquants implique une mise à jour système complète.
2. **Libvirt.** Une confirmation distincte précède la sauvegarde privée et
   l’activation des unités locales. La configuration neuve utilise
   `libvirtd.service`. Une installation modulaire déjà utilisée est conservée.
   Le démarrage de libvirt peut lancer les VM déjà configurées en démarrage
   automatique. Le module KVM du processeur est chargé si le périphérique est
   absent et si les extensions CPU sont visibles.
3. **Stockage et réseau.** Le script prépare le pool `default` sous
   `/var/lib/libvirt/images` s’il est absent. Il active le réseau NAT
   `default` ou le crée s’il est absent, avec `virbr0` sur
   `192.168.122.0/24`. Une définition personnalisée non NAT est conservée.
   Utiliser `--no-network` pour passer cette étape, par exemple si ce
   sous-réseau est déjà utilisé sur le LAN ou par un VPN.
4. **Accès local.** Le script peut autoriser, après un accord séparé, la
   gestion complète de libvirt sans mot de passe pour ton compte dans une
   session graphique locale active. Ce droit permet d’administrer les VM,
   leurs périphériques, leurs réseaux et leurs disques. En déclinant, on
   conserve la politique d’authentification existante.

[Paquet QEMU](https://packages.cachyos.org/package/extra/x86_64/qemu-full) ·
[Services libvirt](https://libvirt.org/daemons.html) ·
[Authentification libvirt](https://libvirt.org/auth.html)

## Vérifier

Depuis la session graphique, lancer Virt-Manager comme utilisateur normal.

```bash
virt-manager --connect qemu:///system
```

Le script vérifie les unités locales, affiche le pool et le réseau et teste
les capacités KVM exposées par libvirt. Pour valider de bout en bout, créer
une VM dans Virt-Manager, sélectionner une image ISO de ton choix et vérifier
le démarrage, le disque et la connectivité de l’invité.

## Revenir en arrière

La sauvegarde est indiquée dans `/var/tmp/cachyos-qemu.*`. Elle peut contenir
la copie privée de `/etc/libvirt`, les états des unités et les inventaires
Pacman. Examiner ces relevés avant de rétablir l’activation des unités.
Retirer la règle `49-cachyos-libvirt.rules` si elle a été créée et que l’accès
facultatif doit être révoqué. Pour revenir sur un réseau ou un pool créé
par cette session, vérifier d’abord qu’aucune VM ni aucun disque n’en dépend.
Une sauvegarde de la configuration ne restaure ni les images des VM ni les
paquets mis à jour. [Référence virsh](https://libvirt.org/manpages/virsh.html)
