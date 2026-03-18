#!/bin/sh
# .infrastructure/entrypoint.d/10-cache-warmup.sh
#
# Warms the Symfony cache at container start. Running at startup (not build
# time) ensures all services (Redis, database, etc.) are reachable.
#
# IMPORTANT: Use /bin/sh, not /bin/bash — Alpine images do not include bash.

set -e

APP_BASE_DIR="${APP_BASE_DIR:-/var/www/html}"

if [ -f "$APP_BASE_DIR/bin/console" ]; then
    echo "Running Symfony cache:warmup..."
    php "$APP_BASE_DIR/bin/console" cache:warmup --env=prod
else
    echo "Symfony bin/console not found at $APP_BASE_DIR — skipping cache warmup"
fi
