#!/bin/bash

# -------------------------------------------------------------------
# Projet : Serveur DayZ Dedicated Linux
#
# Script :
#   start.sh
#
# Version :
#   0.3.0
#
# Auteur administration :
#   Fred LeBorgne
#
# Assistance conception et analyse :
#   ChatGPT (OpenAI)
#
# Description :
#   Démarrage du serveur DayZ Dedicated Linux.
#
#   Les listes de mods sont générées exclusivement par update.sh :
#
#       $SERVER/mod_list.conf
#       $SERVER/servermod_list.conf
#
#   Comportement :
#
#   - Un fichier absent :
#       ERREUR - démarrage refusé
#
#   - Les deux fichiers présents mais vides :
#       démarrage VANILLA
#
#   - Au moins une liste non vide :
#       démarrage avec les catégories de mods configurées
#
# -------------------------------------------------------------------

set -uo pipefail

SCRIPT_VERSION="0.3.0"

SERVER="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

MOD_LIST_FILE="$SERVER/mod_list.conf"
SERVERMOD_LIST_FILE="$SERVER/servermod_list.conf"


# -------------------------------------------------------------------
# INFORMATIONS
# -------------------------------------------------------------------

echo "Version du script : $SCRIPT_VERSION"
echo "Serveur : $SERVER"


# -------------------------------------------------------------------
# VERIFICATION DU SERVEUR
# -------------------------------------------------------------------

if [[ ! -d "$SERVER" ]]
then
    echo "ERREUR : répertoire serveur absent : $SERVER" >&2
    exit 1
fi


# -------------------------------------------------------------------
# VERIFICATION DES LISTES DE MODS
# -------------------------------------------------------------------

if [[ ! -f "$MOD_LIST_FILE" ]]
then
    echo "ERREUR : mod_list.conf absent." >&2
    echo "ERREUR : le serveur ne sera pas démarré." >&2
    echo "ERREUR : exécuter update.sh avant start.sh." >&2
    exit 1
fi


if [[ ! -f "$SERVERMOD_LIST_FILE" ]]
then
    echo "ERREUR : servermod_list.conf absent." >&2
    echo "ERREUR : le serveur ne sera pas démarré." >&2
    echo "ERREUR : exécuter update.sh avant start.sh." >&2
    exit 1
fi


# -------------------------------------------------------------------
# LECTURE DES LISTES DE MODS
# -------------------------------------------------------------------

MOD_LIST=$(cat "$MOD_LIST_FILE")
SERVERMOD_LIST=$(cat "$SERVERMOD_LIST_FILE")


# -------------------------------------------------------------------
# INFORMATIONS MODS CLASSIQUES
# -------------------------------------------------------------------

if [[ -z "${MOD_LIST//[[:space:]]/}" ]]
then
    echo "INFO : aucun mod classique configuré."
else
    echo "Mods classiques chargés :"
    echo "$MOD_LIST"
fi


# -------------------------------------------------------------------
# INFORMATIONS MODS SERVEUR
# -------------------------------------------------------------------

if [[ -z "${SERVERMOD_LIST//[[:space:]]/}" ]]
then
    echo "INFO : aucun mod exclusivement serveur configuré."
else
    echo "Mods exclusivement serveur chargés :"
    echo "$SERVERMOD_LIST"
fi


# -------------------------------------------------------------------
# LANCEMENT DAYZ
# -------------------------------------------------------------------

cd "$SERVER" || exit 1


if [[ -n "${MOD_LIST//[[:space:]]/}" || -n "${SERVERMOD_LIST//[[:space:]]/}" ]]
then

    echo "INFO : lancement de DayZ avec les mods."

    DAYZ_ARGS=(
        -config=serverDZ.cfg
        -port=2301
    )

    if [[ -n "${MOD_LIST//[[:space:]]/}" ]]
    then
        DAYZ_ARGS+=("-mod=$MOD_LIST")
    fi

    if [[ -n "${SERVERMOD_LIST//[[:space:]]/}" ]]
    then
        DAYZ_ARGS+=("-servermod=$SERVERMOD_LIST")
    fi

    DAYZ_ARGS+=(
        -BEpath=battleye
        -profiles=profiles
        -dologs
        -adminlog
        -netlog
        -freezecheck
    )

    exec ./DayZServer "${DAYZ_ARGS[@]}"

else

    echo "INFO : lancement de DayZ en mode VANILLA."

    exec ./DayZServer \
        -config=serverDZ.cfg \
        -port=2301 \
        -BEpath=battleye \
        -profiles=profiles \
        -dologs \
        -adminlog \
        -netlog \
        -freezecheck

fi
