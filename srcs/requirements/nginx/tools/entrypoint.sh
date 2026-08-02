#!/bin/sh

set -e

if [ "$1" = "nginx" ]; then

    if [ -z "$DOMAIN_NAME" ] || [ -z "$NGINX_PORT" ] || [ -z "$WORDPRESS_PORT" ] || [ -z "$ADMINER_PORT" ] || \
       [ -z "$STATIC_DOMAIN_NAME" ] || [ -z "$STATIC_SITE_PORT" ] || [ -z "$NETDATA_DOMAIN_NAME" ] || [ -z "$NETDATA_PORT" ]; then
        echo "[ERROR]: Missing DOMAIN_NAME, NGINX_PORT, WORDPRESS_PORT, ADMINER_PORT, STATIC_DOMAIN_NAME, STATIC_SITE_PORT, NETDATA_DOMAIN_NAME and/or NETDATA_PORT environment variable(s)." >&2
        exit 1
    fi

    echo "Configuring NGINX for: $DOMAIN_NAME, $STATIC_DOMAIN_NAME, $NETDATA_DOMAIN_NAME"

    sed -i "s/__DOMAIN_NAME__/$DOMAIN_NAME/g" /etc/nginx/nginx.conf
    sed -i "s/__NGINX_PORT__/$NGINX_PORT/g" /etc/nginx/nginx.conf
    sed -i "s/__WORDPRESS_PORT__/$WORDPRESS_PORT/g" /etc/nginx/nginx.conf
    sed -i "s/__ADMINER_PORT__/$ADMINER_PORT/g" /etc/nginx/nginx.conf
    sed -i "s/__STATIC_DOMAIN_NAME__/$STATIC_DOMAIN_NAME/g" /etc/nginx/nginx.conf
    sed -i "s/__STATIC_SITE_PORT__/$STATIC_SITE_PORT/g" /etc/nginx/nginx.conf
    sed -i "s/__NETDATA_DOMAIN_NAME__/$NETDATA_DOMAIN_NAME/g" /etc/nginx/nginx.conf
    sed -i "s/__NETDATA_PORT__/$NETDATA_PORT/g" /etc/nginx/nginx.conf

	CERTS_DIR="/etc/nginx/ssl"

	mkdir -p "$CERTS_DIR"

    for DOMAIN in "$DOMAIN_NAME" "$STATIC_DOMAIN_NAME" "$NETDATA_DOMAIN_NAME"; do
        if [ ! -f "$CERTS_DIR/$DOMAIN.crt" ]; then
            echo "Generating self-signed SSL certificate for $DOMAIN..."

            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "$CERTS_DIR/$DOMAIN.key" \
                -out "$CERTS_DIR/$DOMAIN.crt" \
                -subj "/C=FR/ST=GrandEst/L=Mulhouse/O=42/OU=Inception/CN=$DOMAIN"

            echo "[OK] SSL certificate generated successfully for $DOMAIN."
        fi
    done

fi

exec "$@"