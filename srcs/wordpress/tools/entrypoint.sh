#!/bin/sh

set -e

if [ "$1" = "php-fpm83" ]; then
	if [ -z "$WORDPRESS_PORT" ]; then
		echo "Error: Missing WORDPRESS_PORT environment variable." >&2
		exit 1
	fi

	echo "[INFO] Writing PHP-FPM pool config (listening on port $WORDPRESS_PORT)..."

	cat <<EOF > /etc/php83/php-fpm.d/www.conf
	[www]
	user = nobody
	group = nobody
	listen = 0.0.0.0:${WORDPRESS_PORT}
	listen.owner = nobody
	listen.group = nobody
	pm = dynamic
	pm.max_children = 10
	pm.start_servers = 2
	pm.min_spare_servers = 1
	pm.max_spare_servers = 4
	clear_env = no
EOF

fi

exec "$@"