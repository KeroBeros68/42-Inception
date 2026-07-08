#!/bin/sh

set -e

if [ "$1" = "nginx" ]; then

    if [ -z "$DOMAIN_NAME" ] || [ -z "$NGINX_PORT" ] || [ -z "$WORDPRESS_PORT" ]; then
        echo "Error: Missing DOMAIN_NAME, NGINX_PORT and/or WP_PORT environment variable(s)." >&2
        exit 1
    fi

    echo "[INFO] Configuring NGINX for domain: $DOMAIN_NAME"
    sed -i "s/__DOMAIN_NAME__/$DOMAIN_NAME/g" /etc/nginx/nginx.conf
    sed -i "s/__NGINX_PORT__/$NGINX_PORT/g" /etc/nginx/nginx.conf
    sed -i "s/__WP_PORT__/$WORDPRESS_PORT/g" /etc/nginx/nginx.conf

fi

exec "$@"