#!/usr/bin/env bash

set -euo pipefail

# --- Variables de couleur ---
C_RESET='\e[0m'
C_RED='\e[0;31m'
C_GREEN='\e[0;32m'
C_YELLOW='\e[0;33m'
C_BLUE='\e[0;34m'
C_BOLD='\e[1m'
C_CYAN='\e[0;36m'

# --- Variables de contrôle ---
PERFORM_TEST=false
VERBOSE=false

# --- Fonctions utilitaires ---

print_message() {
    local type="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%H:%M:%S')

    case "$type" in
        "INFO")    echo -e "${C_BLUE}[$timestamp] [INFO]${C_RESET} ${message}" ;;
        "SUCCESS") echo -e "${C_GREEN}[$timestamp] [SUCCESS]${C_RESET} ${message}" ;;
        "WARN")    echo -e "${C_YELLOW}[$timestamp] [WARN]${C_RESET} ${message}" ;;
        "ERROR")   echo -e "${C_RED}[$timestamp] [ERROR]${C_RESET} ${message}" >&2 ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "${C_CYAN}[$timestamp] [DEBUG]${C_RESET} ${message}"
            fi
            ;;
        *) echo "[$timestamp] ${message}" ;;
    esac
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_message "ERROR" "Ce script doit être exécuté avec les privilèges root (sudo)."
        exit 1
    fi
}

format_bytes() {
    local bytes="$1"
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || echo "${bytes} bytes"
    else
        echo "${bytes} bytes"
    fi
}

# --- Résumé complet de la configuration ZRAM ---

show_zram_summary() {
    echo -e "\n${C_BOLD}${C_CYAN}═══ Résumé de la configuration ZRAM ═══${C_RESET}\n"

    if ! lsmod 2>/dev/null | grep -q zram; then
        print_message "WARN" "Module zram non chargé"
        return 1
    fi
    print_message "SUCCESS" "Module zram chargé"

    local found_devices=false
    for dev in /sys/block/zram*; do
        if [[ ! -d "$dev" ]]; then
            continue
        fi
        found_devices=true

        local zram_dev
        zram_dev=$(basename "$dev")

        echo -e "\n${C_BOLD}── ${zram_dev} ──${C_RESET}"

        if [[ -f "${dev}/comp_algorithm" ]]; then
            echo -e "  Algorithme de compression : ${C_GREEN}$(cat "${dev}/comp_algorithm")${C_RESET}"
        fi

        if [[ -f "${dev}/disksize" ]]; then
            local disksize
            disksize=$(cat "${dev}/disksize")
            echo -e "  Taille du disque         : ${C_GREEN}$(format_bytes "$disksize")${C_RESET}"
        fi

        if [[ -f "${dev}/max_comp_streams" ]]; then
            echo -e "  Flux de compression max  : $(cat "${dev}/max_comp_streams")"
        fi

        if [[ -f "${dev}/mem_used_total" ]]; then
            local mem_used
            mem_used=$(cat "${dev}/mem_used_total")
            echo -e "  Mémoire utilisée (total) : $(format_bytes "$mem_used")"
        fi

        if [[ -f "${dev}/mem_limit" ]]; then
            local mem_limit
            mem_limit=$(cat "${dev}/mem_limit")
            echo -e "  Limite mémoire           : $(format_bytes "$mem_limit")"
        fi

        if [[ -f "${dev}/compr_data_size" ]] && [[ -f "${dev}/orig_data_size" ]]; then
            local compr orig
            compr=$(cat "${dev}/compr_data_size")
            orig=$(cat "${dev}/orig_data_size")
            if [[ "$orig" -gt 0 ]]; then
                local ratio
                ratio=$(awk "BEGIN {printf \"%.2f\", ${compr}/${orig}}" 2>/dev/null || echo "N/A")
                local saved=$((orig - compr))
                echo -e "  Données originales       : $(format_bytes "$orig")"
                echo -e "  Données compressées      : $(format_bytes "$compr")"
                echo -e "  Ratio de compression     : ${C_GREEN}${ratio}${C_RESET}"
                echo -e "  Mémoire économisée       : ${C_GREEN}$(format_bytes "$saved")${C_RESET}"
            fi
        fi
    done

    if ! $found_devices; then
        print_message "WARN" "Aucun périphérique zram détecté dans /sys/block/"
        return 1
    fi

    if command -v zramctl &>/dev/null; then
        echo -e "\n${C_BOLD}── zramctl ──${C_RESET}"
        zramctl
    else
        echo -e "\n${C_BOLD}── zramctl ──${C_RESET}"
        print_message "WARN" "zramctl non disponible"
    fi

    echo -e "\n${C_BOLD}── Swap ──${C_RESET}"
    if command -v swapon &>/dev/null; then
        swapon --show 2>/dev/null || echo "  Aucun swap actif"
    fi

    local config_file="/etc/systemd/zram-generator.conf.d/99-zram.conf"
    local alt_config="/etc/systemd/zram-generator.conf"
    echo -e "\n${C_BOLD}── Fichier de configuration ──${C_RESET}"
    if [[ -f "$config_file" ]]; then
        print_message "INFO" "Configuration trouvée : $config_file"
        cat "$config_file"
    elif [[ -f "$alt_config" ]]; then
        print_message "INFO" "Configuration trouvée : $alt_config"
        cat "$alt_config"
    else
        print_message "INFO" "Aucun fichier de configuration zram-generator trouvé"
        print_message "INFO" "ZRAM est probablement configuré via le noyau ou udev"
    fi

    echo -e "\n${C_BOLD}── Service systemd ──${C_RESET}"
    if systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -qi zram; then
        systemctl status systemd-zram-setup@zram0.service 2>/dev/null --no-pager --lines=0 || true
        print_message "INFO" "Utilisez 'systemctl status systemd-zram-setup@zram0.service' pour plus de détails"
    else
        print_message "INFO" "Aucun service systemd zram trouvé (normal sur CachyOS)"
    fi

    echo
}

# --- Vérification rapide du statut ZRAM ---

verify_zram() {
    print_message "INFO" "Vérification du statut ZRAM..."

    local status=0

    if lsmod 2>/dev/null | grep -q zram; then
        print_message "SUCCESS" "Module zram chargé"
    else
        print_message "ERROR" "Module zram non chargé"
        status=1
    fi

    if [[ -b "/dev/zram0" ]]; then
        print_message "SUCCESS" "Périphérique /dev/zram0 détecté"
        local dev_count
        dev_count=$(ls -1 /dev/zram* 2>/dev/null | wc -l | tr -d ' ')
        print_message "INFO" "${dev_count} périphérique(s) zram trouvé(s)"
    else
        print_message "ERROR" "Périphérique /dev/zram0 non trouvé"
        status=1
    fi

    if systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
        print_message "SUCCESS" "Service ZRAM actif"
    else
        print_message "INFO" "Service ZRAM non géré par systemd (peut être normal sur CachyOS)"
    fi

    if swapon --show 2>/dev/null | grep -q zram; then
        print_message "SUCCESS" "Swap zram actif"
    else
        print_message "WARN" "Swap zram non détecté dans swapon"
    fi

    return $status
}

# --- Test de performance ---

test_zram_performance() {
    print_message "INFO" "Test de performance ZRAM..."
    check_root

    if [[ ! -b "/dev/zram0" ]]; then
        print_message "ERROR" "Périphérique /dev/zram0 introuvable"
        return 1
    fi

    if ! lsmod 2>/dev/null | grep -q zram; then
        print_message "ERROR" "Module zram non chargé"
        return 1
    fi

    print_message "INFO" "Test d'écriture sur /dev/zram0 (50MB de données aléatoires)..."
    local write_result
    if write_result=$(dd if=/dev/urandom of=/dev/zram0 bs=1M count=50 2>&1); then
        print_message "SUCCESS" "Test d'écriture réussi"
        echo "$write_result" | grep -E "copied|MB/s|GB/s" || true
    else
        print_message "WARN" "Test d'écriture interrompu (normal si le périphérique est plein)"
    fi

    print_message "INFO" "Test de lecture depuis /dev/zram0..."
    local read_result
    if read_result=$(dd if=/dev/zram0 of=/dev/null bs=1M 2>&1); then
        print_message "SUCCESS" "Test de lecture réussi"
        echo "$read_result" | grep -E "copied|MB/s|GB/s" || true
    else
        print_message "WARN" "Test de lecture échoué"
    fi

    print_message "SUCCESS" "Tests de performance terminés"
}

# --- Aide ---

show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Affiche un résumé complet de la configuration ZRAM actuelle."
    echo
    echo "Commandes:"
    echo "  summary            (défaut) Affiche le résumé complet de ZRAM"
    echo "  verify             Vérifie le statut actuel de ZRAM"
    echo "  test               Teste les performances de ZRAM (nécessite root)"
    echo
    echo "Options:"
    echo "  --test             Équivalent à la commande 'test'"
    echo "  --verbose, -v      Active le mode verbeux"
    echo "  --help, -h         Affiche cette aide"
    echo
    echo "Exemples:"
    echo "  $0                        # Résumé complet"
    echo "  $0 --verbose              # Résumé détaillé"
    echo "  sudo $0 test --verbose    # Test de performance détaillé"
    echo
}

# --- Parsing des arguments ---

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                PERFORM_TEST=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            summary|verify|test)
                COMMAND="$1"
                shift
                ;;
            *)
                print_message "ERROR" "Argument non reconnu: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# --- Point d'entrée ---

main() {
    COMMAND="summary"
    parse_arguments "$@"

    case "$COMMAND" in
        summary)
            show_zram_summary
            ;;
        verify)
            verify_zram
            ;;
        test)
            test_zram_performance
            ;;
        *)
            print_message "ERROR" "Commande non valide: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
