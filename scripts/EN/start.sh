#!/bin/bash

# -------------------------------------------------------------------
# Project: DayZ Dedicated Linux Server
#
# Script:
#   start.sh
#
# Version:
#   0.3.0
#
# Server administrator:
#   Fred LeBorgne
#
# Design and analysis assistance:
#   ChatGPT (OpenAI)
#
# Description:
#   Starts the DayZ Dedicated Linux server.
#
#   Mod lists are generated exclusively by update.sh:
#
#       $SERVER/mod_list.conf
#       $SERVER/servermod_list.conf
#
#   Behaviour:
#
#   - If either file is missing:
#       ERROR - startup refused
#
#   - If both files exist but are empty:
#       VANILLA startup
#
#   - If at least one list is non-empty:
#       startup with the configured mod categories
#
# -------------------------------------------------------------------

set -uo pipefail

SCRIPT_VERSION="0.3.0"

SERVER="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

MOD_LIST_FILE="$SERVER/mod_list.conf"
SERVERMOD_LIST_FILE="$SERVER/servermod_list.conf"


# -------------------------------------------------------------------
# INFORMATION
# -------------------------------------------------------------------

echo "Script version: $SCRIPT_VERSION"
echo "Server: $SERVER"


# -------------------------------------------------------------------
# SERVER CHECK
# -------------------------------------------------------------------

if [[ ! -d "$SERVER" ]]
then
    echo "ERROR: server directory does not exist: $SERVER" >&2
    exit 1
fi


# -------------------------------------------------------------------
# MOD LIST CHECK
# -------------------------------------------------------------------

if [[ ! -f "$MOD_LIST_FILE" ]]
then
    echo "ERROR: mod_list.conf is missing." >&2
    echo "ERROR: the server will not be started." >&2
    echo "ERROR: run update.sh before start.sh." >&2
    exit 1
fi


if [[ ! -f "$SERVERMOD_LIST_FILE" ]]
then
    echo "ERROR: servermod_list.conf is missing." >&2
    echo "ERROR: the server will not be started." >&2
    echo "ERROR: run update.sh before start.sh." >&2
    exit 1
fi


# -------------------------------------------------------------------
# READ MOD LISTS
# -------------------------------------------------------------------

MOD_LIST=$(cat "$MOD_LIST_FILE")
SERVERMOD_LIST=$(cat "$SERVERMOD_LIST_FILE")


# -------------------------------------------------------------------
# STANDARD MOD INFORMATION
# -------------------------------------------------------------------

if [[ -z "${MOD_LIST//[[:space:]]/}" ]]
then
    echo "INFO: no standard mods configured."
else
    echo "Loaded standard mods:"
    echo "$MOD_LIST"
fi


# -------------------------------------------------------------------
# SERVER-SIDE MOD INFORMATION
# -------------------------------------------------------------------

if [[ -z "${SERVERMOD_LIST//[[:space:]]/}" ]]
then
    echo "INFO: no server-side-only mods configured."
else
    echo "Loaded server-side-only mods:"
    echo "$SERVERMOD_LIST"
fi


# -------------------------------------------------------------------
# START DAYZ
# -------------------------------------------------------------------

cd "$SERVER" || exit 1


if [[ -n "${MOD_LIST//[[:space:]]/}" || -n "${SERVERMOD_LIST//[[:space:]]/}" ]]
then

    echo "INFO: starting DayZ with mods."

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

    echo "INFO: starting DayZ in VANILLA mode."

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
