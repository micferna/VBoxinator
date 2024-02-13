#!/bin/bash

# Chemin vers le script PowerShell
PS_SCRIPT_PATH="C:\\script\\VBoxinator\\VBoxManager.ps1"

function color_text() {
    case $1 in
        green) echo -e "\e[32m$2\e[0m";;
        yellow) echo -e "\e[33m$2\e[0m";;
        cyan) echo -e "\e[36m$2\e[0m";;
        purple) echo -e "\e[35m$2\e[0m";;
        *) echo "$2";; # Texte sans couleur si l'option est inconnue
    esac
}

# Fonction pour afficher l'aide
function show_help() {
    color_text green "Usage: $0 action [options]"
    color_text yellow "Actions:"
    
    # Tableau des commandes
    local commands=(
        "list      Liste toutes les machines virtuelles."
        "clone     Clone une machine virtuelle avec un nouveau nom. [VM_SOURCE NOM_DU_CLONE [OPTIONS]]"
        "delete    Supprime une ou plusieurs machines virtuelles.   [vmNameOrUUID]"
        "start     Démarre une ou plusieurs machines virtuelles.    [vmNameOrUUID]"
        "stop      Arrête une ou plusieurs machines virtuelles.     [vmNameOrUUID]"
        "reboot    Redémarre une ou plusieurs machines virtuelles.  [vmNameOrUUID]"
        "resize    Redimensionne le disque d'une machine virtuelle. [vmNameOrUUID diskSizeMB [OPTIONS]]"
    )

    # Afficher les commandes et descriptions
    for cmd in "${commands[@]}"; do
        color_text cyan "  ${cmd}"
    done

    echo ""
    color_text purple "[OPTIONS]"
    color_text yellow "  -diskSizeMB 50480 -cpuCores 4 -ramSize 4096"
    echo ""
    exit 0 # Assurez-vous de quitter après avoir affiché l'aide
}

# Vérifie si au moins un argument a été fourni
if [ $# -eq 0 ] || [ "$1" == "help" ]; then
    show_help
    exit 0
fi

action=$1; shift # Supprime l'action pour ne garder que les options

# Initialise les paramètres pour le script PowerShell avec l'action
params="-action $action"

# Vérifie le type d'action
if [ "$action" = "clone" ]; then
    # Le premier argument après 'clone' est la VM source
    vmSource=$1; shift
    # Le reste des arguments jusqu'à une option sont les noms des clones
    cloneNames=()
    while [ $# -gt 0 ] && [[ "$1" != -* ]]; do
        cloneNames+=("$1")
        shift
    done
    # Ajoute la VM source et les noms des clones aux paramètres
    params+=" -vmNameOrUUID $vmSource -cloneNames ${cloneNames[*]}"
fi

# Ajoute les autres arguments (options) aux paramètres
for arg in "$@"; do
    params+=" $arg"
done

# Exécution du script PowerShell via WSL seulement si une action est spécifiée
if [ -n "$action" ]; then
    output=$(powershell.exe -ExecutionPolicy Bypass -File "$PS_SCRIPT_PATH" $params 2>&1)
    echo -e "\e[35m$output\e[0m"
else
    show_help
fi
