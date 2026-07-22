#!/bin/sh

set -e

if [ "$1" = 'mariadbd' ]; then

    if [ -z "$MARIADB_PORT" ]; then
        echo "[ERROR]: Missing MARIADB_PORT environment variable." >&2
        exit 1
    fi

    if [ ! -f "/var/lib/mysql/.initialized" ]; then
        
        MARIADB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
        MARIADB_PASSWORD=$(cat /run/secrets/db_password)

        if [ -z "$MARIADB_DATABASE" ] || [ -z "$MARIADB_ROOT_PASSWORD" ] || [ -z "$MARIADB_USER" ] || [ -z "$MARIADB_PASSWORD" ]; then
            echo "[ERROR]: Missing database environment." >&2
            exit 1
        fi

        echo "Initializing MariaDB..."

        chown -R mysql:mysql /var/lib/mysql

        mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

        mariadbd --user=mysql --datadir=/var/lib/mysql --bootstrap <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MARIADB_DATABASE};
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

        touch /var/lib/mysql/.initialized

        echo "[OK] MariaDB initialized successfully."
    fi

    set -- "$@" --user=mysql --bind-address=0.0.0.0 --port="$MARIADB_PORT"
fi

exec "$@"