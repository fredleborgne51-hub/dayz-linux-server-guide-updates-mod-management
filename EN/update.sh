#!/bin/bash

# -------------------------------------------------------------------
# Project: DayZ Dedicated Linux Server
#
# Script: update.sh
# Version: 0.4.0
#
# Shared Workshop
#
# Updates:
#   - DayZ server
#   - Workshop mods
#   - Server-side Workshop mods
#   - Mod symbolic links
#   - .bikey key files
#
# Exit codes:
#
#   0  = update completed successfully
#   78 = state preventing the server from starting
#
# Exit code 78 corresponds to EX_CONFIG (sysexits).
# It is used when an error prevents the script from guaranteeing
# that the server environment is consistent before startup.
#
# -------------------------------------------------------------------

set -euo pipefail


# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

SCRIPT_VERSION="0.4.0"

SERVER="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVER_NAME="$(basename "$SERVER")"

MODS_FILE="$SERVER/mods.conf"
MOD_LIST=""
MOD_LIST_FILE="$SERVER/mod_list.conf"

SERVERMODS_FILE="$SERVER/servermods.conf"
SERVERMOD_LIST=""
SERVERMOD_LIST_FILE="$SERVER/servermod_list.conf"

STEAMCMD="$(dirname "$SERVER")/steamcmd/steamcmd.sh"

WORKSHOP_DIR="$(dirname "$SERVER")/workshop_shared"

STEAM_USER="fredleborgne"

WORKSHOP_APP_ID="221100"

DAYZ_APP_ID="223350"


# -------------------------------------------------------------------
# LOGGING
#
# All stdout/stderr output can be retrieved with journalctl
# when the script is run by systemd.
# -------------------------------------------------------------------

log()
{
    echo "[$SERVER_NAME] $*"
}


error()
{
    echo "[$SERVER_NAME] ERROR: $*" >&2
}


# -------------------------------------------------------------------
# FATAL ERROR
#
# Any error preventing the script from guaranteeing a consistent
# server state causes the script to exit with code 78 (EX_CONFIG).
#
# systemd can use this code to prevent an automatic restart
# following an update.sh failure.
# -------------------------------------------------------------------

fatal()
{
    error "$*"
    exit 78
}


# -------------------------------------------------------------------
# CHECKS
# -------------------------------------------------------------------

if [[ ! -d "$SERVER" ]]
then
    fatal "server directory not found: $SERVER"
fi

if [[ ! -f "$MODS_FILE" ]]
then
    fatal "mod configuration file not found: $MODS_FILE"
fi

if [[ ! -f "$SERVERMODS_FILE" ]]
then
    fatal "server-side mod configuration file not found: $SERVERMODS_FILE"
fi

if [[ ! -x "$STEAMCMD" ]]
then
    fatal "SteamCMD not found or not executable: $STEAMCMD"
fi

if [[ ! -d "$WORKSHOP_DIR" ]]
then
    fatal "shared Workshop directory not found: $WORKSHOP_DIR"
fi

mkdir -p "$SERVER/keys"


# -------------------------------------------------------------------
# READ mods.conf
#
# Format:
#
#   1559212036 | @CF
#   1828439124 | @DayZExpansion
#   #2906642967
#
#   Workshop ID | Mod name
#
#   The mod name must start with @
# -------------------------------------------------------------------

MOD_IDS=()
MOD_NAMES=()


while IFS='|' read -r MOD_ID MOD_NAME
do

    # Trim leading and trailing whitespace
    MOD_ID="${MOD_ID#"${MOD_ID%%[![:space:]]*}"}"
    MOD_ID="${MOD_ID%"${MOD_ID##*[![:space:]]}"}"

    MOD_NAME="${MOD_NAME#"${MOD_NAME%%[![:space:]]*}"}"
    MOD_NAME="${MOD_NAME%"${MOD_NAME##*[![:space:]]}"}"


    # Empty line
    [[ -z "$MOD_ID" ]] && continue


    # Comment
    [[ "$MOD_ID" =~ ^# ]] && continue


    # Validate Workshop ID
    if ! [[ "$MOD_ID" =~ ^[0-9]+$ ]]
    then
        fatal "invalid Workshop ID: $MOD_ID"
    fi


    # Validate mod name
    if [[ -z "$MOD_NAME" ]]
    then
        fatal "missing mod name for Workshop ID: $MOD_ID"
    fi


    # The name must start with @
    if [[ "$MOD_NAME" != @* ]]
    then
        fatal "invalid mod name: $MOD_NAME; the name must start with @"
    fi


    MOD_IDS+=("$MOD_ID")
    MOD_NAMES+=("$MOD_NAME")

done < "$MODS_FILE"


log "Script version: $SCRIPT_VERSION"
log "Configured mods: ${#MOD_IDS[@]}"

# -------------------------------------------------------------------
# READ servermods.conf
#
# Format:
#
#   3820528827 | @Nasdara_VehicleFuelFix
#
#   Workshop ID | Mod name
# -------------------------------------------------------------------

SERVERMOD_IDS=()
SERVERMOD_NAMES=()

while IFS='|' read -r MOD_ID MOD_NAME
do

    # Trim leading and trailing whitespace
    MOD_ID="${MOD_ID#"${MOD_ID%%[![:space:]]*}"}"
    MOD_ID="${MOD_ID%"${MOD_ID##*[![:space:]]}"}"

    MOD_NAME="${MOD_NAME#"${MOD_NAME%%[![:space:]]*}"}"
    MOD_NAME="${MOD_NAME%"${MOD_NAME##*[![:space:]]}"}"


    # Empty line
    [[ -z "$MOD_ID" ]] && continue


    # Comment
    [[ "$MOD_ID" =~ ^# ]] && continue


    # Validate Workshop ID
    if ! [[ "$MOD_ID" =~ ^[0-9]+$ ]]
    then
        fatal "invalid Workshop ID: $MOD_ID"
    fi


    # Validate mod name
    if [[ -z "$MOD_NAME" ]]
    then
        fatal "missing mod name for Workshop ID: $MOD_ID"
    fi


    # The name must start with @
    if [[ "$MOD_NAME" != @* ]]
    then
        fatal "invalid mod name: $MOD_NAME; the name must start with @"
    fi


    SERVERMOD_IDS+=("$MOD_ID")
    SERVERMOD_NAMES+=("$MOD_NAME")

done < "$SERVERMODS_FILE"


log "Configured server-side mods: ${#SERVERMOD_IDS[@]}"

# -------------------------------------------------------------------
# CHECK FOR DUPLICATES
#
# The same Workshop ID cannot be declared in both:
#
#   - mods.conf
#   - servermods.conf
#
# Each mod must belong to only one category.
# -------------------------------------------------------------------

for SERVERMOD_INDEX in "${!SERVERMOD_IDS[@]}"
do

    SERVERMOD_ID="${SERVERMOD_IDS[$SERVERMOD_INDEX]}"

    for MOD_INDEX in "${!MOD_IDS[@]}"
    do

        MOD_ID="${MOD_IDS[$MOD_INDEX]}"

        if [[ "$SERVERMOD_ID" == "$MOD_ID" ]]
        then
            fatal "Workshop ID $MOD_ID is present in both $MODS_FILE and $SERVERMODS_FILE."
        fi

    done

done

log "Duplicate check between $MODS_FILE and $SERVERMODS_FILE: OK"

# -------------------------------------------------------------------
# UPDATE THE DAYZ SERVER
#
# SteamCMD session #1
# -------------------------------------------------------------------

log "Updating / validating the DayZ server..."


if ! "$STEAMCMD" \
    +force_install_dir "$SERVER/" \
    +login "$STEAM_USER" \
    +app_update "$DAYZ_APP_ID" \
    +quit
then
    fatal "DayZ server update failed."
fi


log "DayZ server update completed."

# -------------------------------------------------------------------
# UPDATE THE MODS
#
# SteamCMD session #2
#
# All mods (from mods.conf and servermods.conf) are downloaded
# in a SINGLE SteamCMD session.
# -------------------------------------------------------------------

ALL_MOD_IDS=("${MOD_IDS[@]}" "${SERVERMOD_IDS[@]}")
ALL_MOD_NAMES=("${MOD_NAMES[@]}" "${SERVERMOD_NAMES[@]}")

if [[ "${#ALL_MOD_IDS[@]}" -gt 0 ]]
then

    log "Updating ${#ALL_MOD_IDS[@]} Workshop mods..."

    STEAM_MOD_ARGS=(
        +force_install_dir "$WORKSHOP_DIR/"
        +login "$STEAM_USER"
    )


    for MOD_ID in "${ALL_MOD_IDS[@]}"
    do
        log "Workshop: preparing mod $MOD_ID"

        STEAM_MOD_ARGS+=(
            +workshop_download_item "$WORKSHOP_APP_ID" "$MOD_ID"
        )
    done


    STEAM_MOD_ARGS+=(+quit)


    if ! "$STEAMCMD" "${STEAM_MOD_ARGS[@]}"
    then
        fatal "Workshop mod update failed."
    fi


    log "Mod updates completed."

else

    log "No active mods in $MODS_FILE or $SERVERMODS_FILE."

fi

# -------------------------------------------------------------------
# PREPARE MOD LINKS
#
# Mods are exposed in the server directory using their @ name:
#
#   /home/dayz/servers/dayz-server/@CF
#
# Each link points to the shared Workshop directory:
#
#   /home/dayz/servers/workshop_shared/
#       steamapps/workshop/content/221100/1559212036
#
# The Workshop ID is still used to access the actual mod content.
#
# -------------------------------------------------------------------

log "Preparing mod symbolic links..."


for INDEX in "${!ALL_MOD_IDS[@]}"
do

    MOD_ID="${ALL_MOD_IDS[$INDEX]}"
    MOD_NAME="${ALL_MOD_NAMES[$INDEX]}"

    MOD_PATH="$WORKSHOP_DIR/steamapps/workshop/content/$WORKSHOP_APP_ID/$MOD_ID"

    LINK_PATH="$SERVER/$MOD_NAME"


    if [[ ! -d "$MOD_PATH" ]]
    then
        fatal "mod missing after download: $MOD_ID"
    fi

    # An existing link pointing to the correct target is kept.
    # A link pointing to an outdated target is replaced.

    if [[ -L "$LINK_PATH" ]]
    then

        CURRENT_TARGET="$(readlink -f "$LINK_PATH")"
        EXPECTED_TARGET="$(readlink -f "$MOD_PATH")"


        if [[ "$CURRENT_TARGET" == "$EXPECTED_TARGET" ]]
        then
            log "Link already correct: $MOD_ID"
            continue
        fi


        log "Incorrect link detected: $LINK_PATH"
        log "Old target: $CURRENT_TARGET"
        log "New target: $EXPECTED_TARGET"

        rm "$LINK_PATH"

    fi


    # An actual file or directory already using the mod name
    # is considered a dangerous conflict.

    if [[ -e "$LINK_PATH" ]]
    then
        fatal "a file/directory already exists: $LINK_PATH"
    fi


    ln -s "$MOD_PATH" "$LINK_PATH"


    log "Link created: $MOD_ID"

done


# -------------------------------------------------------------------
# COPY .BIKEY FILES
#
# Case-insensitive search for directories:
#
#   keys
#   Keys
#   KEYS
#   key
#   Key
#   KEY
#   etc.
#
# And files:
#
#   *.bikey
#   *.BIKEY
#   *.Bikey
#   etc.
#
# Key files are COPIED to the server directory.
# No symbolic links are created.
# -------------------------------------------------------------------

log "Searching for .bikey files..."


for MOD_ID in "${ALL_MOD_IDS[@]}"
do

    MOD_PATH="$WORKSHOP_DIR/steamapps/workshop/content/$WORKSHOP_APP_ID/$MOD_ID"


    # Find a Keys/keys/Key/key directory, regardless of case.

    KEY_DIR="$(
        find "$MOD_PATH" \
            -maxdepth 2 \
            -type d \
            \( -iname "key" -o -iname "keys" \) \
            -print \
            -quit
    )"


    if [[ -z "$KEY_DIR" ]]
    then
        log "No keys found: $MOD_ID"
        continue
    fi


    log "Keys found in: $MOD_ID/$(basename "$KEY_DIR")"


    while IFS= read -r -d '' KEY
    do

        KEY_NAME="$(basename "$KEY")"


        # Look for an existing key using a case-insensitive
        # filename comparison.

        EXISTING_KEY="$(
            find "$SERVER/keys" \
                -maxdepth 1 \
                -type f \
                -iname "$KEY_NAME" \
                -print \
                -quit
        )"


        # -----------------------------------------------------------
        # No key with the same name exists
        # -----------------------------------------------------------

        if [[ -z "$EXISTING_KEY" ]]
        then

            cp "$KEY" "$SERVER/keys/$KEY_NAME"

            log "Key copied: $KEY_NAME"

            continue

        fi


        # -----------------------------------------------------------
        # Same name, same content
        # -----------------------------------------------------------

        if cmp -s "$KEY" "$EXISTING_KEY"
        then

            log "Key already present: $(basename "$EXISTING_KEY")"

            continue

        fi


        # -----------------------------------------------------------
        # Same name, different content
        # -----------------------------------------------------------

        fatal "key conflict: $KEY_NAME; source: $KEY; existing file: $EXISTING_KEY; both files have the same name but different contents."

    done < <(
        find "$KEY_DIR" \
            -maxdepth 1 \
            -type f \
            -iname "*.bikey" \
            -print0
    )

done


# -------------------------------------------------------------------
# GENERATE MOD LIST FILES
# -------------------------------------------------------------------

MOD_LIST="$(IFS=';'; echo "${MOD_NAMES[*]}")"
SERVERMOD_LIST="$(IFS=';'; echo "${SERVERMOD_NAMES[*]}")"


printf '%s\\n' "$MOD_LIST" > "$MOD_LIST_FILE"
printf '%s\\n' "$SERVERMOD_LIST" > "$SERVERMOD_LIST_FILE"


log "Mod list saved to: $MOD_LIST_FILE"
log "Server-side mod list saved to: $SERVERMOD_LIST_FILE"

log "Active mods: $MOD_LIST"
log "Active server-side mods: $SERVERMOD_LIST"

exit 0
