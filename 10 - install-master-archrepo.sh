#!/usr/bin/env bash
set -euo pipefail
umask 077

repo=master-archrepo
base=https://masternaka.github.io/master-archrepo
server="$base/x86_64"
config=/etc/pacman.conf

fail() {
    printf 'Erreur : %s\n' "$*" >&2
    exit 1
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    cat <<'HELP'
Usage : sudo bash scripts/install-master-archrepo.sh EMPREINTE_VERIFIEE

Ajoute le dépôt public master-archrepo à pacman sur CachyOS x86_64.
Fournir l’empreinte primaire OpenPGP complète obtenue auprès de la
personne qui a créé la clé du dépôt. Les applications s’installent ensuite
avec pacman.
HELP
    exit 0
fi

[[ $# -eq 1 ]] || fail 'Indiquez l’empreinte complète ou utilisez --help.'
fingerprint="${1^^}"
[[ "$fingerprint" =~ ^([A-F0-9]{40}|[A-F0-9]{64})$ ]] \
    || fail 'L’empreinte doit contenir 40 ou 64 caractères hexadécimaux, sans espaces.'
[[ "$(uname -sm)" == 'Linux x86_64' ]] || fail 'Ce script est prévu pour Linux x86_64.'
[[ "$EUID" == 0 ]] || fail 'Exécutez ce script avec sudo.'
for command in curl gpg gpgv pacman-conf pacman-key awk grep mktemp cp cmp mv rm; do
    command -v "$command" >/dev/null || fail "Commande requise absente : $command."
done
[[ -f "$config" && ! -L "$config" ]] || fail "Configuration absente ou lien symbolique : $config."

work="$(mktemp -d /etc/.master-archrepo.XXXXXXXX)"
trap 'rm -rf -- "$work"' EXIT
cp -a -- "$config" "$work/original"
printf '[%s]\nSigLevel = Required TrustedOnly\nServer = %s\n' "$repo" "$server" >"$work/repo.conf"

# pacman-conf résout aussi les sections déclarées par Include.
repos="$(pacman-conf --config "$config" --repo-list)" || fail "Impossible de lire $config."
candidate="$work/candidate"
cp -a -- "$work/original" "$candidate"
if grep -Fxq -- "$repo" <<<"$repos"; then
    actual_server="$(pacman-conf --config "$config" --repo "$repo" Server)"
    actual_policy="$(pacman-conf --config "$config" --repo "$repo" SigLevel)"
    expected_policy="$(pacman-conf --config "$work/repo.conf" --repo "$repo" SigLevel)"
    [[ "$actual_server" == "$server" && "$actual_policy" == "$expected_policy" ]] \
        || fail "Une section [$repo] différente existe déjà. Examinez-la avant de relancer."
else
    { printf '\n'; cat "$work/repo.conf"; } >>"$candidate"
    actual_server="$(pacman-conf --config "$candidate" --repo "$repo" Server)"
    [[ "$actual_server" == "$server" ]] || fail 'La configuration proposée est invalide.'
fi

download() {
    curl --disable --fail --silent --show-error --location \
        --proto '=https' --proto-redir '=https' --max-time 60 \
        --output "$2" "$1" || fail "Fichier indisponible sur GitHub Pages : $1"
}

download "$base/$repo.asc" "$work/key.asc"
download "$server/$repo.db" "$work/$repo.db"
download "$server/$repo.db.sig" "$work/$repo.db.sig"

key_details="$(gpg --homedir "$work" --batch --no-autostart --with-colons --show-keys "$work/key.asc")" \
    || fail 'Clé publique illisible.'
reported="$(awk -F: '
    $1 == "fpr" && previous == "pub" { print $10 }
    { previous = $1 }
' <<<"$key_details")"
[[ "$reported" == "$fingerprint" ]] || fail 'La clé publique ne correspond pas à l’empreinte attendue.'
gpg --homedir "$work" --batch --no-autostart --output "$work/keyring.gpg" --dearmor "$work/key.asc"
gpgv --homedir "$work" --keyring "$work/keyring.gpg" "$work/$repo.db.sig" "$work/$repo.db" \
    || fail 'Signature de la base pacman invalide.'

cmp -s -- "$config" "$work/original" || fail "$config a changé. Relancez le script."
pacman-key --add "$work/key.asc"
pacman-key --lsign-key "$fingerprint"
if ! cmp -s -- "$candidate" "$work/original"; then
    backup="$(mktemp "${config}.before-master-archrepo.XXXXXXXX")"
    cp -a -- "$work/original" "$backup"
    cmp -s -- "$config" "$work/original" || fail "$config a changé. Relancez le script."
    mv -T -- "$candidate" "$config"
    printf 'Sauvegarde de la configuration : %s\n' "$backup"
fi

printf '%s\n' 'Dépôt master-archrepo configuré.' \
    'Pour installer les deux applications :' \
    '  sudo pacman -Syu master-archrepo/sambapilot master-archrepo/dotfilepilot'
