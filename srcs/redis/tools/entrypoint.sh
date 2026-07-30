#!/bin/sh

set -e

if [ "$1" = "redis-server" ]; then

	REDIS_PASSWORD=$(cat /run/secrets/redis_password)

    if [ -z "$REDIS_PORT" ] || [ -z "$REDIS_PASSWORD" ]; then
        echo "[ERROR]: Missing REDIS_PORT or REDIS_PASSWORD environment variable(s)." >&2
        exit 1
    fi

    echo "Configuring Redis..."

    sed -i "s/__REDIS_PORT__/$REDIS_PORT/g" /usr/local/etc/redis/redis.conf
	sed -i "s/__REDIS_PASSWORD__/$REDIS_PASSWORD/g" /usr/local/etc/redis/redis.conf

fi

exec "$@"