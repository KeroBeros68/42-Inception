#!/bin/sh

set -e

if [ "$1" = "netdata" ]; then

    if [ -z "$NETDATA_PORT" ]; then
        echo "[ERROR]: Missing NETDATA_PORT environment variable." >&2
        exit 1
    fi

    sed -i "s/__NETDATA_PORT__/$NETDATA_PORT/g" /etc/netdata/netdata.conf

    export NETDATA_HOST_PREFIX=/host
fi

exec "$@"
