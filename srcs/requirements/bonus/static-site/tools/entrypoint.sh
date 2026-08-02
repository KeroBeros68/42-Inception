#!/bin/sh

set -e

if [ "$1" = "nginx" ]; then

    if [ -z "$STATIC_SITE_PORT" ]; then
        echo "[ERROR]: Missing STATIC_SITE_PORT environment variable." >&2
        exit 1
    fi

    sed -i "s/__STATIC_SITE_PORT__/$STATIC_SITE_PORT/g" /etc/nginx/nginx.conf
fi

exec "$@"
