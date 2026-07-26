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

	if [ ! -f /var/www/html/wp-load.php ]; then

		echo "Wordpress not found... Installation.."
		wp core download --allow-root

		until mysqladmin ping -h"$MARIADB_HOST" -P"$MARIADB_PORT" \
			-u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" --silent; do
			echo "[INFO] Waiting for MariaDB..."
			sleep 2
		done

		if [ ! -f /var/www/html/wp-config.php ]; then
			wp config create \
				--dbname="$MARIADB_DATABASE" \
				--dbuser="$MARIADB_USER" \
				--dbpass="$(cat /run/secrets/db_password)" \
				--dbhost="$MARIADB_HOST:$MARIADB_PORT" \
				--allow-root
		fi

		if ! wp core is-installed --allow-root; then
			wp core install \
				--url="https://$DOMAIN_NAME" \
				--title="Inception" \
				--admin_user="$(cat /run/secrets/wp_admin_password | cut -d: -f1 2>/dev/null || echo admin)" \
				--admin_password="$(cat /run/secrets/wp_admin_password)" \
				--admin_email="admin@$DOMAIN_NAME" \
				--allow-root
		fi
	fi
fi

exec "$@"