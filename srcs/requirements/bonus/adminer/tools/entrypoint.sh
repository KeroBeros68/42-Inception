#!/bin/sh

set -e

if [ "$1" = "php-fpm83" ]; then

    if [ -z "$ADMINER_PORT" ]; then
        echo "[ERROR]: Missing ADMINER_PORT environment variable." >&2
        exit 1
    fi

    echo "[INFO] Writing PHP-FPM pool config (listening on port $ADMINER_PORT)..."

    cat <<EOF > /etc/php83/php-fpm.d/www.conf
[www]
user = nobody
group = nobody
listen = 0.0.0.0:${ADMINER_PORT}
listen.owner = nobody
listen.group = nobody
pm = dynamic
pm.max_children = 5
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 2
clear_env = no
EOF

fi

exec "$@"
