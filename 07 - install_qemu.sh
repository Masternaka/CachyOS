#!/usr/bin/env bash
# Poste CachyOS x86_64 : QEMU/KVM, libvirt local et Virt-Manager.
set -Eeuo pipefail
export LC_ALL=C

DRY_RUN=false
NETWORK=true
SNAPSHOT=''
URI=qemu:///system
PACKAGES=(qemu-full libvirt virt-manager edk2-ovmf swtpm)

CYAN='' GREEN='' YELLOW='' RED='' RESET='' ERROR_RESET=''
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    if [[ -t 1 ]]; then CYAN='\033[1;36m' GREEN='\033[32m' YELLOW='\033[33m' RESET='\033[0m'; fi
    if [[ -t 2 ]]; then RED='\033[1;31m' ERROR_RESET='\033[0m'; fi
fi
step() { printf '\n%b── %s/%s  %s%b\n' "$CYAN" "$1" "$STEPS" "$2" "$RESET"; }
info() { printf '  %s\n' "$*"; }
ok() { printf '  %bOK%b  %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '  %bAttention%b  %s\n' "$YELLOW" "$RESET" "$*"; }
fatal() { printf '  %bErreur%b  %s\n' "$RED" "$ERROR_RESET" "$*" >&2; exit 1; }
confirm() {
    local answer
    printf '%s [o/N] ' "$1"
    IFS= read -r answer || return 1
    case "$answer" in o|O|oui|Oui|OUI) return 0 ;; *) return 1 ;; esac
}
show_command() { printf ' '; printf ' %q' "$@"; printf '\n'; }
virsh_system() { sudo virsh --connect "$URI" "$@"; }

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --no-network) NETWORK=false ;;
        --help|-h)
            cat <<'HELP'
Usage : bash "07 - install_qemu.sh" [--dry-run] [--no-network]

Prépare QEMU/KVM, libvirt, Virt-Manager, le micrologiciel UEFI et le TPM virtuel.
Lancer depuis le compte utilisateur normal sur CachyOS x86_64.
  --dry-run     Examiner les paquets et le plan, sans sudo ni écriture.
  --no-network  Passer la préparation du réseau NAT libvirt default.

Accords séparés pour Pacman, la configuration libvirt et une éventuelle
autorisation Polkit sans mot de passe pour la session locale.
HELP
            exit 0 ;;
        *) fatal "Option inconnue : $arg. Utiliser --help." ;;
    esac
done

on_exit() {
    local status=$1
    if (( status != 0 )) && [[ -n "$SNAPSHOT" ]]; then
        warn "Opération incomplète. Inventaire privé : $SNAPSHOT"
    fi
}
trap 'on_exit "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
STEPS=5
printf '%bCachyOS · QEMU/KVM et Virt-Manager%b\n' "$CYAN" "$RESET"
if $DRY_RUN; then STEPS=3; info 'Mode : simulation'; fi
step 1 'Vérifier la machine et les prérequis'
[[ "$(uname -sm)" == 'Linux x86_64' ]] || fatal 'Linux x86_64 requis.'
[[ $EUID -ne 0 ]] || fatal 'Lancer sans sudo depuis le compte utilisateur concerné.'
for tool in pacman pacman-conf awk systemctl id grep; do
    command -v "$tool" >/dev/null 2>&1 || fatal "Commande requise absente : $tool."
done
systemctl show -p Version --value >/dev/null || fatal 'Le gestionnaire systemd est inaccessible.'
ACCOUNT=$(id -un)
[[ "$ACCOUNT" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*\$?$ ]] || fatal 'Nom de compte non pris en charge.'
KVM_MODULE=''
if [[ -c /dev/kvm ]]; then
    ok '/dev/kvm est disponible.'
elif grep -Eq '^flags[[:space:]]*:.*[[:space:]]vmx([[:space:]]|$)' /proc/cpuinfo; then
    KVM_MODULE=kvm_intel
elif grep -Eq '^flags[[:space:]]*:.*[[:space:]]svm([[:space:]]|$)' /proc/cpuinfo; then
    KVM_MODULE=kvm_amd
else
    warn 'Les extensions KVM ne sont pas visibles. Vérifier la virtualisation dans l’UEFI ou sur l’hyperviseur hôte.'
fi

if $NETWORK; then PACKAGES+=(dnsmasq nftables); fi

read_package_plan() {
    local installed listing pkg target provider_status=0 required=("${PACKAGES[@]}")
    if $NETWORK; then
        # Conserver un fournisseur iptables déjà en place.
        pacman -T iptables >/dev/null || provider_status=$?
        case "$provider_status" in
            0) ;;
            127) required+=(iptables-nft) ;;
            *) fatal 'Impossible de vérifier le fournisseur iptables.' ;;
        esac
    fi
    PLANNED_PACKAGES=("${required[@]}")
    installed=$(pacman -Qq) || fatal 'Lecture des paquets installés impossible.'
    REPOS=$(pacman-conf --repo-list) || fatal 'Lecture des dépôts Pacman impossible.'
    TARGETS=()
    for pkg in "${required[@]}"; do
        if [[ $'\n'"$installed"$'\n' == *$'\n'"$pkg"$'\n'* ]]; then continue; fi
        if [[ -z ${listing+x} ]]; then listing=$(pacman -Sl) || fatal 'Bases Pacman locales indisponibles.'; fi
        target=$(awk -v pkg="$pkg" '$2 == pkg && !found {print $1 "/" $2; found=1}' <<< "$listing")
        case "${target%%/*}" in
            core|extra|multilib|cachyos|cachyos-v3|cachyos-v4|cachyos-znver4|\
            cachyos-core-v3|cachyos-extra-v3|cachyos-core-v4|cachyos-extra-v4|\
            cachyos-core-znver4|cachyos-extra-znver4) TARGETS+=("$target") ;;
            *) fatal "Paquet $pkg introuvable dans les dépôts officiels configurés ou masqué par un dépôt tiers." ;;
        esac
    done
}

unit_configured() {
    local state
    state=$(systemctl show "$1" -p ActiveState -p UnitFileState) || fatal "État de l’unité inaccessible : $1."
    [[ $'\n'"$state"$'\n' == *$'\nActiveState=active\n'* ||
       $'\n'"$state"$'\n' == *$'\nUnitFileState=enabled\n'* ||
       $'\n'"$state"$'\n' == *$'\nUnitFileState=enabled-runtime\n'* ]]
}

select_units() {
    UNITS=(libvirtd.service)
    local unit
    for unit in virtqemud.socket virtqemud.service virtnetworkd.socket virtnetworkd.service virtstoraged.socket virtstoraged.service; do
        if unit_configured "$unit"; then
            UNITS=(virtqemud.socket virtnetworkd.socket virtstoraged.socket)
            if unit_configured libvirtd.socket || unit_configured libvirtd.service; then
                fatal 'Libvirt monolithique et modulaire sont déjà activés. Examiner les unités avant application.'
            fi
            break
        fi
    done
}

step 2 'Examiner les paquets, le réseau et l’accès local'
read_package_plan
select_units
info "Paquets : ${PLANNED_PACKAGES[*]}"
info "Unités locales prévues : ${UNITS[*]}"
info "Compte graphique : $ACCOUNT · Connexion : $URI"
if $NETWORK; then
    warn 'Le réseau NAT default peut créer virbr0 (192.168.122.0/24), un service DHCP/DNS et des règles de filtrage libvirt.'
fi
if [[ -n "$KVM_MODULE" ]]; then info "Chargement prévu du module $KVM_MODULE si /dev/kvm est toujours absent."; fi
info 'Stockage : préparer le pool default dans /var/lib/libvirt/images si absent.'
if (( ${#TARGETS[@]} > 0 )); then
    warn 'L’installation des paquets manquants entraîne une mise à jour système complète.'
    info "Dépôts actifs : ${REPOS//$'\n'/, }"
    show_command sudo pacman -Syu --needed -- "${TARGETS[@]}"
fi
if $DRY_RUN; then
    step 3 'Bilan de la simulation'
    info 'L’état des réseaux et pools sera lu après accord pour la configuration libvirt.'
    ok 'Simulation terminée. Aucune modification appliquée.'
    exit 0
fi

step 3 'Confirmer et installer les paquets manquants'
[[ -t 0 && -t 1 ]] || fatal 'Utiliser un terminal interactif pour appliquer.'
command -v sudo >/dev/null || fatal 'sudo est requis pour l’application.'
create_snapshot() {
    SNAPSHOT=$(sudo mktemp -d /var/tmp/cachyos-qemu.XXXXXXXX) || fatal 'Sauvegarde privée impossible.'
    info "Sauvegarde privée : $SNAPSHOT"
}
if (( ${#TARGETS[@]} > 0 )); then
    confirm 'Autoriser les paquets annoncés et la mise à jour système ?' || { info 'Installation annulée.'; exit 0; }
    approved=$(printf '%s\n' "$REPOS" "${TARGETS[@]}")
    read_package_plan
    [[ "$approved" == "$(printf '%s\n' "$REPOS" "${TARGETS[@]}")" ]] || fatal 'Le plan Pacman a changé. Relancer.'
    create_snapshot
    pacman -Q | sudo tee "$SNAPSHOT/paquets-avant.txt" >/dev/null
    sudo pacman -Syu --needed -- "${TARGETS[@]}" || fatal 'Transaction Pacman échouée. Consulter /var/log/pacman.log.'
    pacman -Q | sudo tee "$SNAPSHOT/paquets-apres.txt" >/dev/null
    read_package_plan
    (( ${#TARGETS[@]} == 0 )) || fatal 'Des paquets requis sont encore manquants.'
fi
ok 'Paquets QEMU, libvirt et Virt-Manager présents.'
for tool in virsh virt-manager; do
    command -v "$tool" >/dev/null || fatal "Commande attendue absente : $tool."
done

step 4 'Confirmer et préparer libvirt'
select_units
info "Activer au démarrage et démarrer si nécessaire : ${UNITS[*]}"
info 'Le stockage et le réseau existants seront lus avant toute modification les concernant.'
warn 'Le démarrage de libvirt peut lancer les ressources et VM déjà configurées pour le démarrage automatique.'
if ! confirm 'Autoriser la sauvegarde et la configuration libvirt annoncées ?'; then
    info 'Configuration annulée. Les paquets installés restent présents.'
    if [[ -n "$SNAPSHOT" ]]; then info "Inventaire : $SNAPSHOT"; fi
    exit 0
fi
approved_units="${UNITS[*]}"
select_units
[[ "${UNITS[*]}" == "$approved_units" ]] || fatal 'Les unités sélectionnées ont changé. Relancer.'
if [[ -z "$SNAPSHOT" ]]; then create_snapshot; fi
sudo cp -a -- /etc/libvirt "$SNAPSHOT/libvirt"
systemctl show "${UNITS[@]}" -p Id -p ActiveState -p UnitFileState |
    sudo tee "$SNAPSHOT/unites-avant.txt" >/dev/null
if [[ -n "$KVM_MODULE" && ! -c /dev/kvm ]]; then
    sudo modprobe "$KVM_MODULE" || warn 'Chargement KVM impossible. Vérifier l’UEFI et le noyau en cours.'
fi
sudo systemctl enable --now "${UNITS[@]}"
virsh_system list --all | sudo tee "$SNAPSHOT/mes-vm.txt" >/dev/null

pool_names=$(virsh_system pool-list --all --name) || fatal 'Lecture des pools impossible.'
if ! grep -Fxq default <<< "$pool_names"; then
    [[ -d /var/lib/libvirt/images && ! -L /var/lib/libvirt/images ]] || fatal 'Répertoire de stockage par défaut indisponible.'
    virsh_system pool-define-as default dir --target /var/lib/libvirt/images
    info 'Pool default défini.'
fi
pool_xml=$(virsh_system pool-dumpxml default) || fatal 'Lecture de la définition du pool impossible.'
pool_info=$(virsh_system pool-info default) || fatal 'Lecture de l’état du pool impossible.'
printf '%s\n' "$pool_info" | sudo tee "$SNAPSHOT/pool-default-avant.txt" >/dev/null
POOL_MANAGED=false
if grep -Eq "<pool[[:space:]][^>]*type=['\"]dir['\"]" <<< "$pool_xml" &&
   grep -Fq '<path>/var/lib/libvirt/images</path>' <<< "$pool_xml" &&
   grep -Eq '^Persistent:[[:space:]]+yes$' <<< "$pool_info"; then
    if grep -Eq '^State:[[:space:]]+inactive$' <<< "$pool_info"; then virsh_system pool-start default; fi
    if ! grep -Eq '^Autostart:[[:space:]]+yes$' <<< "$pool_info"; then virsh_system pool-autostart default; fi
    POOL_MANAGED=true
else
    info 'Pool default personnalisé ou transitoire : configuration conservée.'
fi

NET_MANAGED=false
if $NETWORK; then
    net_names=$(virsh_system net-list --all --name) || fatal 'Lecture des réseaux impossible.'
    if ! grep -Fxq default <<< "$net_names"; then
        sudo tee "$SNAPSHOT/nat-default.xml" >/dev/null <<'XML'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp><range start='192.168.122.2' end='192.168.122.254'/></dhcp>
  </ip>
</network>
XML
        virsh_system net-define "$SNAPSHOT/nat-default.xml"
        info 'Réseau NAT default défini.'
    fi
    net_xml=$(virsh_system net-dumpxml default) || fatal 'Lecture de la définition réseau impossible.'
    net_info=$(virsh_system net-info default) || fatal 'Lecture de l’état réseau impossible.'
    if grep -Eq "<forward[[:space:]][^>]*mode=['\"]nat['\"]" <<< "$net_xml" &&
       grep -Eq '^Persistent:[[:space:]]+yes$' <<< "$net_info"; then
        printf '%s\n' "$net_info" | sudo tee "$SNAPSHOT/reseau-default-avant.txt" >/dev/null
        if ! grep -Eq '^Active:[[:space:]]+yes$' <<< "$net_info"; then virsh_system net-start default; fi
        if ! grep -Eq '^Autostart:[[:space:]]+yes$' <<< "$net_info"; then virsh_system net-autostart default; fi
        NET_MANAGED=true
    else
        warn 'Réseau default personnalisé ou transitoire : configuration conservée.'
    fi
fi

RULE=/etc/polkit-1/rules.d/49-cachyos-libvirt.rules
warn "L’accès Polkit facultatif donne à $ACCOUNT le contrôle complet de libvirt depuis une session locale active."
if confirm "Autoriser cet accès sans mot de passe via $RULE ?"; then
    rule_payload=$(printf '%s\n' 'polkit.addRule(function (action, subject) {' \
        '    if (action.id === "org.libvirt.unix.manage" && subject.local && subject.active &&' \
        "        subject.user === \"$ACCOUNT\") {" \
        '        return polkit.Result.YES;' '    }' '});')
    printf '%s\n' "$rule_payload" | sudo tee "$SNAPSHOT/polkit-propose.rules" >/dev/null
    if sudo test -e "$RULE" || sudo test -L "$RULE"; then
        sudo test -f "$RULE" && ! sudo test -L "$RULE" &&
            sudo cmp -s "$SNAPSHOT/polkit-propose.rules" "$RULE" || fatal "Fichier Polkit différent : $RULE."
    else
        sudo install -m 0644 -- "$SNAPSHOT/polkit-propose.rules" "$RULE"
    fi
    ok "Accès local enregistré dans $RULE."
else
    info 'Les règles Polkit de la machine déterminent l’authentification dans Virt-Manager.'
fi

step 5 'Vérifier et afficher le bilan'
for unit in "${UNITS[@]}"; do
    systemctl is-active --quiet "$unit" || fatal "Unité non active : $unit."
    systemctl is-enabled --quiet "$unit" || fatal "Unité non activée au démarrage : $unit."
done
pool_info=$(virsh_system pool-info default)
printf '%s\n' "$pool_info"
if $POOL_MANAGED; then
    grep -Eq '^State:[[:space:]]+running$' <<< "$pool_info" &&
        grep -Eq '^Autostart:[[:space:]]+yes$' <<< "$pool_info" ||
        fatal 'Le pool standard n’est pas actif ou son démarrage automatique n’est pas confirmé.'
fi
if $NETWORK; then
    net_info=$(virsh_system net-info default)
    printf '%s\n' "$net_info"
    if $NET_MANAGED; then
        grep -Eq '^Active:[[:space:]]+yes$' <<< "$net_info" &&
            grep -Eq '^Autostart:[[:space:]]+yes$' <<< "$net_info" ||
            fatal 'Le réseau NAT n’est pas actif ou son démarrage automatique n’est pas confirmé.'
    fi
fi
if [[ -c /dev/kvm ]] && virsh_system domcapabilities --virttype kvm >/dev/null; then
    ok 'Capacités KVM confirmées par libvirt.'
else
    warn 'Capacités KVM non confirmées. Une VM de test reste à démarrer après diagnostic.'
fi
info "Sauvegarde : $SNAPSHOT"
show_command virt-manager --connect "$URI"
