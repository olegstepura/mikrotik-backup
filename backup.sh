#!/bin/bash

# Paths
SSH_DIR="/ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"
PUB_KEY_FILE="${KEY_FILE}.pub"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
BACKUP_ROOT="/backups"

# Config from ENV
R_USER="${BACKUP_USER:-backup}"
ZIP_PASS="${BACKUP_PASSWORD}"
IPS=($MIKROTIK_IPS)

# Retention
KEEP_LAST_N=${KEEP_LAST_N:-7}
KEEP_MONTHS=${KEEP_MONTHS:-6}

# 1. SSH Key Check / Generation
if [ ! -f "$KEY_FILE" ]; then
    echo "=================================================================="
    echo "🔑 INITIAL SETUP: SSH KEY GENERATION"
    echo "=================================================================="
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -q
    PUB_KEY=$(cat "$PUB_KEY_FILE")
    
    echo "✅ New SSH key generated!"
    echo ""
    echo "⚠️  IMPORTANT: Copy and paste these commands LINE BY LINE into your MikroTik terminal."
    echo "When you run the second command, the router will prompt you to type a password."
    echo "------------------------------------------------------------------"
    echo "/user group add name=backup-group policy=ssh,read,write,ftp,sensitive,test,password,policy;"
    echo "/user add name=$R_USER group=backup-group comment=\"Backup Bot\";"
    echo "/user ssh-keys add user=$R_USER key=\"$PUB_KEY\";"
    echo "------------------------------------------------------------------"
    echo ""
    echo "=================================================================="
    exit 0
fi

DATE=$(date +%Y-%m-%d_%H-%M-%S)
SSH_OPTS=(-q -o LogLevel=ERROR -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KNOWN_HOSTS" -i "$KEY_FILE")

# 2. Process IP Array
for R_HOST in "${IPS[@]}"; do
    echo "=================================================================="
    echo "🚀 Backing up: $R_HOST"
    
    DEST_DIR="${BACKUP_ROOT}/${R_HOST}"
    mkdir -p "$DEST_DIR"
    BKP_NAME="bkp_${R_HOST}_${DATE}"

    # Generate a temporary 16-char random password to secure the file on the router
    TEMP_MT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "$TEMP_MT_PASS" > "${DEST_DIR}/${BKP_NAME}_router_pass.txt"

    # Generate the binary backup securely on the router (Silenced output)
    ssh "${SSH_OPTS[@]}" "${R_USER}@${R_HOST}" \
        "/system backup save name=${BKP_NAME} password=${TEMP_MT_PASS}" >/dev/null 2>&1
    
    # Try RouterOS v7 export. Capture the output to check for v6 syntax errors.
    EXPORT_OUT=$(ssh "${SSH_OPTS[@]}" "${R_USER}@${R_HOST}" "/export show-sensitive file=${BKP_NAME}" 2>&1)
    
    # If the router complains about the syntax, it is likely v6. Run the v6 export fallback.
    if echo "$EXPORT_OUT" | grep -qi -E "expected end of command|bad command|syntax error"; then
        ssh "${SSH_OPTS[@]}" "${R_USER}@${R_HOST}" "/export file=${BKP_NAME}" >/dev/null 2>&1
    fi
    
    sleep 5

    # Pull the files
    scp "${SSH_OPTS[@]}" "${R_USER}@${R_HOST}:${BKP_NAME}.*" "$DEST_DIR/"

    # Check if download succeeded before packing
    if [[ -f "${DEST_DIR}/${BKP_NAME}.backup" || -f "${DEST_DIR}/${BKP_NAME}.rsc" ]]; then
        # Pack everything (including the text file containing the router-level backup password)
        7z a -p"${ZIP_PASS}" -mhe=on "${DEST_DIR}/${BKP_NAME}.7z" "${DEST_DIR}/${BKP_NAME}.backup" "${DEST_DIR}/${BKP_NAME}.rsc" "${DEST_DIR}/${BKP_NAME}_router_pass.txt" > /dev/null

        # Cleanup Router & Local Temp
        rm -f "${DEST_DIR}/${BKP_NAME}.backup" "${DEST_DIR}/${BKP_NAME}.rsc" "${DEST_DIR}/${BKP_NAME}_router_pass.txt"
        ssh "${SSH_OPTS[@]}" "${R_USER}@${R_HOST}" "/file remove [find name~\"${BKP_NAME}\"]" >/dev/null 2>&1

        # GFS Retention
        cd "$DEST_DIR" || continue
        FILES=$(ls -1t *.7z 2>/dev/null)
        if [ -n "$FILES" ]; then
            COUNT=0; MONTHS_KEPT=0; declare -A KEPT_MONTHS_MAP
            for FILE in $FILES; do
                ((COUNT++))
                if [ "$COUNT" -le "$KEEP_LAST_N" ]; then continue; fi
                YYYY_MM=$(echo "$FILE" | grep -oE '[0-9]{4}-[0-9]{2}' | head -1)
                if [[ -z "${KEPT_MONTHS_MAP[$YYYY_MM]}" && "$MONTHS_KEPT" -lt "$KEEP_MONTHS" ]]; then
                    KEPT_MONTHS_MAP[$YYYY_MM]=1; ((MONTHS_KEPT++)); continue
                fi
                rm "$FILE"
            done
            unset KEPT_MONTHS_MAP
        fi
        echo "✅ Done: $R_HOST"
    else
        echo "❌ ERROR: Failed to generate or download files for $R_HOST."
        # Cleanup the stranded text file
        rm -f "${DEST_DIR}/${BKP_NAME}_router_pass.txt"
    fi
done