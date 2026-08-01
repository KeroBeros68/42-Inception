#!/bin/sh

set -e

if [ "$1" = "/usr/sbin/pure-ftpd" ]; then

    if [ -z "$FTP_USER" ] || [ -z "$FTP_PORT" ] || [ -z "$FTP_PASSIVE_MIN_PORT" ] || [ -z "$FTP_PASSIVE_MAX_PORT" ]; then
        echo "[ERROR]: Missing FTP_USER, FTP_PORT, FTP_PASSIVE_MIN_PORT and/or FTP_PASSIVE_MAX_PORT environment variable(s)." >&2
        exit 1
    fi

    FTP_PASSWORD=$(cat /run/secrets/ftp_password)

    if [ -z "$FTP_PASSWORD" ]; then
        echo "[ERROR]: Missing FTP_PASSWORD secret." >&2
        exit 1
    fi

    PASSWD_FILE=/etc/pure-ftpd/passwd/pureftpd.passwd
    PDB_FILE=/etc/pure-ftpd/passwd/pureftpd.pdb

    mkdir -p /etc/pure-ftpd/passwd

    if [ ! -f "$PDB_FILE" ]; then
        echo "Creating FTP user $FTP_USER..."

        printf '%s\n%s\n' "$FTP_PASSWORD" "$FTP_PASSWORD" | \
            pure-pw useradd "$FTP_USER" -f "$PASSWD_FILE" -u nobody -g nobody -d /var/www/html

        pure-pw mkdb "$PDB_FILE" -f "$PASSWD_FILE"

        echo "[OK] FTP user created successfully."
    fi

    set -- /usr/sbin/pure-ftpd \
        -l "puredb:$PDB_FILE" \
        -S "$FTP_PORT" \
        -p "$FTP_PASSIVE_MIN_PORT:$FTP_PASSIVE_MAX_PORT" \
        -A -E -R -C 10

    if [ -n "$DOMAIN_NAME" ]; then
        set -- "$@" -P "$DOMAIN_NAME"
    fi
fi

exec "$@"
