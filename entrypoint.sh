#!/bin/bash
set -e

# If the user provides a CRON_SCHEDULE environment variable, run as a daemon
if [ -n "$CRON_SCHEDULE" ]; then
    echo "=> CRON_SCHEDULE detected: '$CRON_SCHEDULE'"
    echo "=> Starting in daemon mode using Supercronic..."
    
    # Generate the crontab dynamically in the runtime directory
    echo "$CRON_SCHEDULE /app/backup.sh" > /run/crontab
    
    # Use 'exec' to replace the entrypoint process with Supercronic for proper signal handling
    exec supercronic /run/crontab

# Otherwise, preserve the original behavior: run once and exit
else
    echo "=> No CRON_SCHEDULE detected. Running backup once and exiting..."
    exec /app/backup.sh
fi