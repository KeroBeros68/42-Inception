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
    sed -i "s/__WORDPRESS_PORT__/$WORDPRESS_PORT/g" /etc/nginx/nginx.conf

	    CERTS_DIR="/etc/nginx/ssl"

    if [ ! -f "$CERTS_DIR/$DOMAIN_NAME.crt" ]; then
        echo "[INFO] Generating self-signed SSL certificate..."
        
        mkdir -p "$CERTS_DIR"

        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$CERTS_DIR/$DOMAIN_NAME.key" \
            -out "$CERTS_DIR/$DOMAIN_NAME.crt" \
            -subj "/C=FR/ST=GrandEst/L=Mulhouse/O=42/OU=Inception/CN=$DOMAIN_NAME"
            
        echo "[INFO] SSL certificate generated successfully."
    fi

fi

exec "$@"