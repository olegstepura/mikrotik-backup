#!/bin/bash
set -e

# Allow users to pass custom commands (e.g., docker-compose run --rm mikrotik-backup /app/backup.sh)
# This is a Docker best practice and allows for easy isolated testing.
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# Run immediately on startup if requested
if [ "${RUN_ON_STARTUP:-false}" = "true" ]; then
    echo "=> RUN_ON_STARTUP=true detected. Executing backup immediately..."
    /app/backup.sh
    echo "=> Immediate run completed."
fi

# Schedule or Run-Once logic
if [ -n "$CRON_SCHEDULE" ]; then
    echo "=> CRON_SCHEDULE detected: '$CRON_SCHEDULE'"
    
    if [ -n "$SENTRY_DSN" ]; then
        echo "=> SENTRY_DSN detected: Job failures will be reported to Sentry"
    fi

    echo "=> Starting in daemon mode using Supercronic..."
    
    # Generate the crontab dynamically in the runtime directory
    echo "$CRON_SCHEDULE /app/backup.sh" > /run/crontab
    
    # Use 'exec' to replace the entrypoint process with Supercronic for proper signal handling.
    exec supercronic /run/crontab

# Legacy Run-Once Mode (No Cron)
else
    # Prevent running twice if RUN_ON_STARTUP was already executed
    if [ "${RUN_ON_STARTUP:-false}" != "true" ]; then
        echo "=> No CRON_SCHEDULE detected. Running backup once and exiting..."
        exec /app/backup.sh
    else
        echo "=> Exiting gracefully."
        exit 0
    fi
fi