#!/bin/bash

# Define the internal backup root (standardized for the container)
BKP_ROOT="/backups"

if [ -z "$1" ]; then
    echo "=================================================================="
    echo "📂 AVAILABLE BACKUPS"
    echo "=================================================================="
    if [ -d "$BKP_ROOT" ]; then
        # Lists backups as: IP_ADDRESS/bkp_YYYY-MM-DD_HH-MM-SS.7z
        find "$BKP_ROOT" -name "*.7z" | sed "s|$BKP_ROOT/||" | sort
    else
        echo "❌ Error: Backup directory $BKP_ROOT not found."
    fi
    echo "=================================================================="
    echo "Usage: extract-mt-backup <IP_FOLDER/FILENAME.7z>"
    exit 0
fi

ARCHIVE_PATH="$1"
# Ensure we are looking in the /backups mount
[[ "$ARCHIVE_PATH" != /backups/* ]] && ARCHIVE_PATH="$BKP_ROOT/$ARCHIVE_PATH"

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "❌ Error: Archive '$ARCHIVE_PATH' not found."
    exit 1
fi

# Load password from environment (provided by Ansible/Compose)
ZIP_PASS="${BACKUP_PASSWORD}"

if [ -z "$ZIP_PASS" ]; then
    read -s -p "Enter 7-Zip Archive Password: " ZIP_PASS
    echo ""
fi

DEST_DIR="${ARCHIVE_PATH%.7z}_extracted"
mkdir -p "$DEST_DIR"

echo "📦 Extracting to '$DEST_DIR'..."
7z x -p"${ZIP_PASS}" -y "$ARCHIVE_PATH" -o"$DEST_DIR" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Extraction successful!"
    ls -lh "$DEST_DIR"
else
    echo "❌ ERROR: Extraction failed."
    rmdir "$DEST_DIR" 2>/dev/null
fi