#!/bin/bash

# -------------------------------------------------------------------
# Projet : Serveur DayZ Dedicated Linux
#
# Script : update.sh
# Version : 0.4.0
#
# Mutualisation du workshop
#
# Mise à jour :
#   - serveur DayZ
#   - mods Workshop
#   - mods serveur Workshop
#   - liens symboliques des mods
#   - copie des clés .bikey
#
# Codes de sortie :
#
#   0  = mise à jour terminée avec succès
#   78 = état ne permettant pas de démarrer le serveur
#
# Le code 78 correspond à EX_CONFIG (sysexits).
# Il est utilisé ici lorsqu'une erreur empêche de garantir que
# l'environnement du serveur est cohérent avant son démarrage.
#
# -------------------------------------------------------------------

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

SCRIPT_VERSION="0.4.0"

SERVER="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
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
# LOG
#
# Toutes les sorties stdout/stderr sont récupérables par journalctl
# lorsque le script est lancé par systemd.
# -------------------------------------------------------------------

log()
{
    echo "[$SERVER_NAME] $*"
}

error()
{
    echo "[$SERVER_NAME] ERREUR : $*" >&2
}

# -------------------------------------------------------------------
# ERREUR FATALE
#
# Toute erreur empêchant de garantir un état cohérent du serveur
# provoque l'arrêt du script avec le code 78 (EX_CONFIG).
#
# systemd pourra utiliser ce code pour empêcher un redémarrage
# automatique après un échec de update.sh.
# -------------------------------------------------------------------

fatal()
{
    error "$*"
    exit 78
}

# -------------------------------------------------------------------
# VERIFICATIONS
# -------------------------------------------------------------------

if [[ ! -d "$SERVER" ]]
then
    fatal "répertoire serveur absent : $SERVER"
fi

if [[ ! -f "$MODS_FILE" ]]
then
    fatal "fichier de configuration des mods absent : $MODS_FILE"
fi

if [[ ! -f "$SERVERMODS_FILE" ]]
then
    fatal "fichier de configuration des mods serveur absent : $SERVERMODS_FILE"
fi

if [[ ! -x "$STEAMCMD" ]]
then
    fatal "SteamCMD absent ou non exécutable : $STEAMCMD"
fi

if [[ ! -d "$WORKSHOP_DIR" ]]
then
    fatal "répertoire Workshop mutualisé absent : $WORKSHOP_DIR"
fi

mkdir -p "$SERVER/keys"

# -------------------------------------------------------------------
# LECTURE DE mods.conf
#
# Format :
#
#   1559212036 | @CF
#   1828439124 | @DayZExpansion
#   #2906642967
#
#   Workshop ID | Nom du mod
#
#   Le nom du mod doit commencer par @
# -------------------------------------------------------------------

MOD_IDS=()
MOD_NAMES=()

while IFS='|' read -r MOD_ID MOD_NAME
do
    # Retirer les espaces en début/fin
    MOD_ID="\${MOD_ID#"\${MOD_ID%%[![:space:]]*}"}"
    MOD_ID="\${MOD_ID%"\${MOD_ID##*[![:space:]]}"}"

    MOD_NAME="\${MOD_NAME#"\${MOD_NAME%%[![:space:]]*}"}"
    MOD_NAME="\${MOD_NAME%"\${MOD_NAME##*[![:space:]]}"}"

    # Ligne vide
    [[ -z "$MOD_ID" ]] && continue

    # Commentaire
    [[ "$MOD_ID" =~ ^# ]] && continue

    # Vérification Workshop ID
    if ! [[ "$MOD_ID" =~ ^[0-9]+$ ]]
    then
        fatal "Workshop ID invalide : $MOD_ID"
    fi

    # Vérification du nom du mod
    if [[ -z "$MOD_NAME" ]]
    then
        fatal "Nom de mod absent pour le Workshop ID : $MOD_ID"
    fi

    # Le nom doit commencer par @
    if [[ "$MOD_NAME" != @* ]]
    then
        fatal "Nom de mod invalide : $MOD_NAME ; le nom doit commencer par @"
    fi

    MOD_IDS+=("$MOD_ID")
    MOD_NAMES+=("$MOD_NAME")

done < "$MODS_FILE"

log "Version du script : $SCRIPT_VERSION"
log "Mods configurés : \${#MOD_IDS[@]}"

# -------------------------------------------------------------------
# LECTURE DE servermods.conf
#
# Format :
#
#   3820528827 | @Nasdara_VehicleFuelFix
#
#   Workshop ID | Nom du mod
# -------------------------------------------------------------------

SERVERMOD_IDS=()
SERVERMOD_NAMES=()

while IFS='|' read -r MOD_ID MOD_NAME
do
    # Retirer les espaces en début/fin
    MOD_ID="\${MOD_ID#"\${MOD_ID%%[![:space:]]*}"}"
    MOD_ID="\${MOD_ID%"\${MOD_ID##*[![:space:]]}"}"

    MOD_NAME="\${MOD_NAME#"\${MOD_NAME%%[![:space:]]*}"}"
    MOD_NAME="\${MOD_NAME%"\${MOD_NAME##*[![:space:]]}"}"

    # Ligne vide
    [[ -z "$MOD_ID" ]] && continue

    # Commentaire
    [[ "$MOD_ID" =~ ^# ]] && continue

    # Vérification Workshop ID
    if ! [[ "$MOD_ID" =~ ^[0-9]+$ ]]
    then
        fatal "Workshop ID invalide : $MOD_ID"
    fi

    # Vérification du nom du mod
    if [[ -z "$MOD_NAME" ]]
    then
        fatal "Nom de mod absent pour le Workshop ID : $MOD_ID"
    fi

    # Le nom doit commencer par @
    if [[ "$MOD_NAME" != @* ]]
    then
        fatal "Nom de mod invalide : $MOD_NAME ; le nom doit commencer par @"
    fi

    SERVERMOD_IDS+=("$MOD_ID")
    SERVERMOD_NAMES+=("$MOD_NAME")

done < "$SERVERMODS_FILE"

log "Mods serveur configurés : \${#SERVERMOD_IDS[@]}"

# -------------------------------------------------------------------
# VERIFICATION DES DOUBLONS
#
# Un même Workshop ID ne peut pas être déclaré dans :
#
#   - mods.conf
#   - servermods.conf
#
# Chaque mod doit appartenir à une seule catégorie.
# -------------------------------------------------------------------

for SERVERMOD_INDEX in "\${!SERVERMOD_IDS[@]}"
do
    SERVERMOD_ID="\${SERVERMOD_IDS[$SERVERMOD_INDEX]}"

    for MOD_INDEX in "\${!MOD_IDS[@]}"
    do
        MOD_ID="\${MOD_IDS[$MOD_INDEX]}"

        if [[ "$SERVERMOD_ID" == "$MOD_ID" ]]
        then
            fatal "Workshop ID $MOD_ID présent dans $MODS_FILE et $SERVERMODS_FILE."
        fi
    done
done

log "Vérification des doublons entre $MODS_FILE et $SERVERMODS_FILE : OK"

# -------------------------------------------------------------------
# MISE À JOUR DU SERVEUR DAYZ
#
# Session SteamCMD n°1
# -------------------------------------------------------------------

log "Mise à jour / validation du serveur DayZ..."

if ! "$STEAMCMD" \
    +force_install_dir "$SERVER/" \
    +login "$STEAM_USER" \
    +app_update "$DAYZ_APP_ID" \
    +quit
then
    fatal "échec de la mise à jour du serveur DayZ."
fi

log "Serveur DayZ : mise à jour terminée."

# -------------------------------------------------------------------
# MISE À JOUR DES MODS
#
# Session SteamCMD n°2
#
# Tous les mods ( mods.conf et servermods.conf ) sont téléchargés dans UNE SEULE session SteamCMD.
# -------------------------------------------------------------------

ALL_MOD_IDS=("\${MOD_IDS[@]}" "\${SERVERMOD_IDS[@]}")
ALL_MOD_NAMES=("\${MOD_NAMES[@]}" "\${SERVERMOD_NAMES[@]}")

if [[ "\${#ALL_MOD_IDS[@]}" -gt 0 ]]
then
    log "Mise à jour des \${#ALL_MOD_IDS[@]} mods Workshop..."

    STEAM_MOD_ARGS=(
        +force_install_dir "$WORKSHOP_DIR/"
        +login "$STEAM_USER"
    )

    for MOD_ID in "\${ALL_MOD_IDS[@]}"
    do
        log "Workshop : préparation du mod $MOD_ID"

        STEAM_MOD_ARGS+=(
            +workshop_download_item "$WORKSHOP_APP_ID" "$MOD_ID"
        )
    done

    STEAM_MOD_ARGS+=(+quit)

    if ! "$STEAMCMD" "\${STEAM_MOD_ARGS[@]}"
    then
        fatal "échec de la mise à jour des mods Workshop."
    fi

    log "Mise à jour des mods terminée."

else
    log "Aucun mod actif dans $MODS_FILE ou $SERVERMODS_FILE."
fi

# -------------------------------------------------------------------
# PREPARATION DES LIENS MODS
#
# Les mods sont exposés dans le serveur avec leur nom @ :
#
#   /home/dayz/servers/dayz-server/@CF
#
# Chaque lien pointe vers le Workshop mutualisé :
#
#   /home/dayz/servers/workshop_shared/
#       steamapps/workshop/content/221100/1559212036
#
# Le Workshop ID reste utilisé pour accéder au contenu réel.
#
# -------------------------------------------------------------------

log "Préparation des liens symboliques des mods..."

for INDEX in "\${!ALL_MOD_IDS[@]}"
do
    MOD_ID="\${ALL_MOD_IDS[$INDEX]}"
    MOD_NAME="\${ALL_MOD_NAMES[$INDEX]}"

    MOD_PATH="$WORKSHOP_DIR/steamapps/workshop/content/$WORKSHOP_APP_ID/$MOD_ID"

    LINK_PATH="$SERVER/$MOD_NAME"

    if [[ ! -d "$MOD_PATH" ]]
    then
        fatal "mod absent après téléchargement : $MOD_ID"
    fi

    # Un lien existant vers la bonne cible est conservé.
    # Un lien pointant vers une ancienne cible est remplacé.

    if [[ -L "$LINK_PATH" ]]
    then
        CURRENT_TARGET="$(readlink -f "$LINK_PATH")"
        EXPECTED_TARGET="$(readlink -f "$MOD_PATH")"

        if [[ "$CURRENT_TARGET" == "$EXPECTED_TARGET" ]]
        then
            log "Lien déjà correct : $MOD_ID"
            continue
        fi

        log "Lien incorrect détecté : $LINK_PATH"
        log "Ancienne cible : $CURRENT_TARGET"
        log "Nouvelle cible : $EXPECTED_TARGET"

        rm "$LINK_PATH"
    fi

    # Un objet réel portant déjà le nom du mod est dangereux.

    if [[ -e "$LINK_PATH" ]]
    then
        fatal "un fichier/répertoire existe déjà : $LINK_PATH"
    fi

    ln -s "$MOD_PATH" "$LINK_PATH"

    log "Lien créé : $MOD_ID"
done

# -------------------------------------------------------------------
# COPIE DES CLES .BIKEY
#
# Recherche insensible à la casse :
#
#   keys
#   Keys
#   KEYS
#   key
#   Key
#   KEY
#   etc.
#
# et :
#
#   *.bikey
#   *.BIKEY
#   *.Bikey
#   etc.
#
# Les clés sont COPIÉES dans le dossier serveur.
# Aucun lien symbolique n'est créé.
# -------------------------------------------------------------------

log "Recherche des clés .bikey..."

for MOD_ID in "\${ALL_MOD_IDS[@]}"
do
    MOD_PATH="$WORKSHOP_DIR/steamapps/workshop/content/$WORKSHOP_APP_ID/$MOD_ID"

    # Recherche d'un dossier Keys/keys/Key/key quelle que soit sa casse.

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
        log "Aucune clé : $MOD_ID"
        continue
    fi

    log "Clés trouvées dans : $MOD_ID/$(basename "$KEY_DIR")"

    while IFS= read -r -d '' KEY
    do
        KEY_NAME="$(basename "$KEY")"

        # Recherche d'une clé existante avec comparaison
        # insensible à la casse sur son nom.

        EXISTING_KEY="$(
            find "$SERVER/keys" \
                -maxdepth 1 \
                -type f \
                -iname "$KEY_NAME" \
                -print \
                -quit
        )"

        # -----------------------------------------------------------
        # Aucune clé de même nom
        # -----------------------------------------------------------

        if [[ -z "$EXISTING_KEY" ]]
        then
            cp "$KEY" "$SERVER/keys/$KEY_NAME"

            log "Clé copiée : $KEY_NAME"

            continue
        fi

        # -----------------------------------------------------------
        # Même nom, même contenu
        # -----------------------------------------------------------

        if cmp -s "$KEY" "$EXISTING_KEY"
        then
            log "Clé déjà présente : $(basename "$EXISTING_KEY")"

            continue
        fi

        # -----------------------------------------------------------
        # Même nom, contenu différent
        # -----------------------------------------------------------

        fatal "conflit de clé : $KEY_NAME ; source : $KEY ; existante : $EXISTING_KEY ; les deux fichiers portent le même nom mais leur contenu diffère."

    done < <(
        find "$KEY_DIR" \
            -maxdepth 1 \
            -type f \
            -iname "*.bikey" \
            -print0
    )
done

# -------------------------------------------------------------------
# GENERATION DES LISTES DE MODS
# -------------------------------------------------------------------

MOD_LIST="$(IFS=';'; echo "\${MOD_NAMES[*]}")"
SERVERMOD_LIST="$(IFS=';'; echo "\${SERVERMOD_NAMES[*]}")"

printf '%s\n' "$MOD_LIST" > "$MOD_LIST_FILE"
printf '%s\n' "$SERVERMOD_LIST" > "$SERVERMOD_LIST_FILE"

log "Liste des mods sauvegardée dans : $MOD_LIST_FILE"
log "Liste des mods serveur sauvegardée dans : $SERVERMOD_LIST_FILE"

log "Mods actifs : $MOD_LIST"
log "Mods serveur actifs : $SERVERMOD_LIST"

exit 0
