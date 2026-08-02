#!/bin/sh

set -e

if [ "$1" = "httpd" ]; then

    if [ -z "$STATIC_SITE_PORT" ]; then
        echo "[ERROR]: Missing STATIC_SITE_PORT environment variable." >&2
        exit 1
    fi

    set -- httpd -f -p "$STATIC_SITE_PORT" -h /var/www/html
fi

exec "$@"
