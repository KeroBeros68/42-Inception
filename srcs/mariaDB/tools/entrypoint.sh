#!/bin/sh

set -e

if [ "$1" = "mariadb" ]; then
	print("ok")
fi

exec "$@"