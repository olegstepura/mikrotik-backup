#!/bin/bash

# Check if an archive was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_archive.7z>"
    exit 1
fi

ARCHIVE_FILE="$1"

if [ ! -f "$ARCHIVE_FILE" ]; then
    echo "❌ Error: File '$ARCHIVE_FILE' not found."
    exit 1
fi

# Try to load password from .env if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    # Export vars from .env, ignoring comments
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs) 2>/dev/null
fi

ZIP_PASS="${BACKUP_PASSWORD}"

# Prompt for password if not found in .env
if [ -z "$ZIP_PASS" ]; then
    read -s -p "Enter 7-Zip Archive Password: " ZIP_PASS
    echo ""
fi

# Create a clean destination folder based on the archive name
DEST_DIR="${ARCHIVE_FILE%.7z}_extracted"
mkdir -p "$DEST_DIR"

echo "📦 Extracting '$ARCHIVE_FILE' to '$DEST_DIR'..."

# Extract the archive
7z x -p"${ZIP_PASS}" -y "$ARCHIVE_FILE" -o"$DEST_DIR" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Extraction successful!"
    echo "------------------------------------------------------------------"
    ls -lh "$DEST_DIR"
    echo "------------------------------------------------------------------"
    echo "💡 REMINDER: To restore the binary .backup file via WinBox/Terminal,"
    echo "you will need the password stored inside the '_router_pass.txt' file."
else
    echo "❌ ERROR: Extraction failed. Incorrect password or corrupted archive."
    rmdir "$DEST_DIR" 2>/dev/null
fi