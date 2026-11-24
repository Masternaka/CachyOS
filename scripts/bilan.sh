#!/usr/bin/env bash
# Affichage commun, sans fichier créé ni commande système exécutée.
# Les scripts appellent bilan_print APRES leur nettoyage/retour arrière existant.
# Les tableaux conservent seulement les événements confirmés dans le processus
# principal ; aucun bilan n'est imprimé depuis une substitution de commande.

# Le flux ordinaire varie selon le script ; les erreurs vont toujours sur stderr.
# Les libellés restent lisibles sans couleur (redirection, NO_COLOR, TERM=dumb).
bilan_couleurs() {
    GREEN='' YELLOW='' CYAN='' BLUE='' VIOLET='' BOLD='' RESET=''
    STATE_RED='' RED='' ERROR_RESET=''
    [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]] || return 0
    if [[ -t ${1:-1} ]]; then
        GREEN='\033[1;32m' YELLOW='\033[1;33m' CYAN='\033[1;36m'
        BLUE='\033[1;94m' VIOLET='\033[1;95m' BOLD='\033[1m' RESET='\033[0m'
        STATE_RED='\033[1;31m'
    fi
    if [[ -t 2 ]]; then RED='\033[1;31m' ERROR_RESET='\033[0m'; fi
}

bilan_init() {
    BILAN_TITRE=$1
    shift
    BILAN_ACTIF=true
    BILAN_IMPRIME=false
    BILAN_COMMENCE=false
    BILAN_CONFORME=false
    BILAN_ANNULE=false
    BILAN_SIMULATION=false
    BILAN_RETOUR_ARRIERE=false
    BILAN_ACTIONS=()
    BILAN_IGNORES=()
    BILAN_ERREURS=()
    BILAN_NOTES=()
    BILAN_TOTAUX=''
    local argument
    for argument in "$@"; do
        case "$argument" in
            --help|-h|--list) BILAN_ACTIF=false ;;
            --dry-run) BILAN_SIMULATION=true ;;
        esac
    done
    trap 'bilan_print "$?"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

# Marquer avant une action pouvant modifier la cible, puis confirmer seulement
# après les vérifications propres au script. Une sauvegarde seule n'est pas une
# preuve que l'opération demandée a réussi.
bilan_debut() { BILAN_COMMENCE=true; }
# Les appelants signalent la conformité après avoir vérifié l'état demandé.
bilan_conforme() { BILAN_CONFORME=true; }
bilan_action() { BILAN_ACTIONS+=("$*"); }
bilan_ignore() { BILAN_IGNORES+=("$*"); }
bilan_erreur() { BILAN_ERREURS+=("$*"); }
bilan_note() { BILAN_NOTES+=("$*"); }
bilan_annule() { BILAN_ANNULE=true; bilan_ignore "$*"; }

bilan_liste() {
    local titre=$1 element affiche=0 limite=8
    shift
    (( $# > 0 )) || return 0
    printf '  %s : %s\n' "$titre" "$#" >&2
    # Les erreurs restent toutes visibles ; les longues listes d'actions ont
    # déjà leurs détails dans les étapes précédentes du terminal.
    if [[ "$titre" == 'Erreurs / avertissements' ]]; then limite=$#; fi
    for element in "$@"; do
        if (( affiche >= limite )); then
            printf '    … %s autres éléments ; voir les détails ci-dessus.\n' "$(( $# - affiche ))" >&2
            break
        fi
        printf '    - %s\n' "$element" >&2
        affiche=$((affiche + 1))
    done
}

bilan_chemins() {
    # Les variables sont celles des scripts appelants. Ne pas confondre un
    # instantané de travail temporaire avec une sauvegarde conservée.
    case "$BILAN_TITRE" in
        03*)
            if [[ -n ${BACKUP_FILE:-} && -f "$BACKUP_FILE" ]]; then
                printf '  Sauvegarde   : %s\n' "$BACKUP_FILE" >&2
                printf '  Retour arrière : sudo bash "%s" --restore "%s"\n' "$0" "$BACKUP_FILE" >&2
            fi
            ;;
        08*)
            if [[ -n ${backup:-} ]]; then printf '  Sauvegarde   : %s\n' "$backup" >&2; fi
            ;;
        *)
            local dossier=''
            case "$BILAN_TITRE" in
                02*|04*) dossier=${SESSION:-} ;;
                05*|06*|07*|09*|10*) dossier=${SNAPSHOT:-} ;;
                11*) dossier=${RUN_DIR:-} ;;
            esac
            if [[ -n "$dossier" ]]; then printf '  Suivi / sauvegardes : %s\n' "$dossier" >&2; fi
            ;;
    esac
    if [[ -n ${UNDO_FILE:-} ]]; then
        printf '  Retour arrière : examiner puis lancer sudo bash "%s"\n' "$UNDO_FILE" >&2
    fi
    if [[ -n ${UNDO:-} ]]; then
        printf '  Retour arrière : examiner puis lancer sudo bash "%s"\n' "$UNDO" >&2
    elif [[ "$BILAN_TITRE" == 02* && -n ${SESSION:-} && -f "$SESSION/restaurer.sh" ]]; then
        printf '  Retour arrière : examiner puis lancer sudo bash "%s/restaurer.sh"\n' "$SESSION" >&2
    elif [[ "$BILAN_TITRE" == 04* && -n ${SESSION:-} ]]; then
        printf '  Retour arrière : examiner puis lancer bash "%s/restaurer.sh"\n' "$SESSION" >&2
    fi
}

bilan_print() {
    local code=$1 resultat
    (( BASH_SUBSHELL == 0 )) || return 0
    $BILAN_IMPRIME && return 0
    BILAN_IMPRIME=true
    # Une erreur d'arguments reste visible, même si --list avait été demandé.
    if ! $BILAN_ACTIF && (( code == 0 )); then return 0; fi

    # Les scripts 09 et 11 simulent par défaut ; le 10 peut devenir un aperçu
    # lorsqu'il est lancé sans terminal. Lire le mode réellement retenu.
    case "$BILAN_TITRE" in
        09*) [[ ${APPLY:-false} == true ]] || BILAN_SIMULATION=true ;;
        10*) [[ ${MODE:-} != preview ]] || BILAN_SIMULATION=true ;;
        11*) [[ ${MODE:---dry-run} != --dry-run ]] || BILAN_SIMULATION=true ;;
    esac
    if $BILAN_ANNULE && [[ "$code" != 129 && "$code" != 130 && "$code" != 143 ]]; then
        resultat='Annulé'
        if $BILAN_COMMENCE; then resultat='Annulé après le début des opérations'; fi
    elif (( code != 0 )); then
        if (( ${#BILAN_ACTIONS[@]} > 0 )) && ! $BILAN_SIMULATION && ! $BILAN_RETOUR_ARRIERE; then
            resultat='Partiellement réussi'
        else
            resultat='Échoué'
        fi
        case "$code" in 129|130|143) resultat='Interrompu' ;; esac
    elif $BILAN_SIMULATION; then
        resultat='Simulation terminée'
    elif (( ${#BILAN_ERREURS[@]} > 0 )); then
        resultat='Terminé avec avertissements'
    elif $BILAN_CONFORME && ! $BILAN_COMMENCE && (( ${#BILAN_ACTIONS[@]} == 0 )); then
        resultat='Déjà conforme'
    else
        resultat='Réussi'
    fi

    printf '\n── Bilan de l’opération ──────────────────────────────\n' >&2
    printf '  Script       : %s\n  Résultat     : %s\n  Code de sortie : %s\n' "$BILAN_TITRE" "$resultat" "$code" >&2
    if [[ -n "$BILAN_TOTAUX" ]]; then printf '  Totaux       : %s\n' "$BILAN_TOTAUX" >&2; fi
    if (( code != 0 )) && [[ -n ${BILAN_ETAPE:-} ]]; then
        printf '  Dernière étape : %s\n' "$BILAN_ETAPE" >&2
    fi
    if $BILAN_SIMULATION; then
        printf '  Mode         : simulation ; aucune application effectuée.\n' >&2
    fi
    if $BILAN_RETOUR_ARRIERE; then
        bilan_liste 'Actions terminées avant le retour arrière' ${BILAN_ACTIONS[@]+"${BILAN_ACTIONS[@]}"}
    else
        bilan_liste 'Actions confirmées' ${BILAN_ACTIONS[@]+"${BILAN_ACTIONS[@]}"}
    fi
    if (( ${#BILAN_ACTIONS[@]} == 0 )); then
        printf '  Actions confirmées : aucune modification confirmée.\n' >&2
    fi
    bilan_liste 'Inchangés / ignorés' ${BILAN_IGNORES[@]+"${BILAN_IGNORES[@]}"}
    bilan_liste 'Erreurs / avertissements' ${BILAN_ERREURS[@]+"${BILAN_ERREURS[@]}"}
    if (( code != 0 )); then
        if $BILAN_COMMENCE; then
            printf '  À vérifier   : des changements peuvent subsister ; examiner les détails ci-dessus avant de relancer.\n' >&2
        else
            printf '  À vérifier   : lire le premier diagnostic ci-dessus avant de relancer.\n' >&2
        fi
    fi
    bilan_liste 'Détails de la session' ${REPORT[@]+"${REPORT[@]}"}
    bilan_liste 'Vérifications restantes / remarques' ${BILAN_NOTES[@]+"${BILAN_NOTES[@]}"}
    bilan_chemins
    return 0
}
