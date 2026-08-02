# 📗 User & Administrator Documentation — Inception

This document is for anyone **using** the deployed Inception stack day to day — as a
site visitor, a WordPress content editor/administrator, or the person operating FTP,
Adminer and Netdata. It assumes the infrastructure is already built and running; for
build/deploy instructions and architecture, see [README.md](README.md). For internals
aimed at whoever maintains the Dockerfiles/configs, see [DEV_DOC.md](DEV_DOC.md).

## 🌍 Accessing the site

| What | URL |
|---|---|
| WordPress site | `https://kebertra.42.fr` |
| WordPress admin dashboard | `https://kebertra.42.fr/wp-admin` |
| Adminer (database UI) | `https://kebertra.42.fr/adminer/` |
| Static showcase site | `https://<STATIC_DOMAIN_NAME>` (set in `srcs/.env`) |
| Netdata (monitoring dashboard) | `https://<NETDATA_DOMAIN_NAME>` (set in `srcs/.env`) |
| FTP | `ftp://kebertra.42.fr:<FTP_PORT>` |

All hostnames must resolve to the VM's local IP address (e.g. an entry in your
`/etc/hosts` file) before they'll load in a browser.

> ⚠️ **Certificate warning is expected.** TLS certificates are self-signed (generated
> locally, not issued by a public authority), so your browser will show a "not
> private"/"untrusted certificate" warning on first visit. This is normal for this
> local, pedagogical environment — proceed past the warning to reach the site.

## 👤 WordPress accounts & roles

Two accounts exist by default, created at first boot:

| Variable | Role | Notes |
|---|---|---|
| `WP_ADMIN_USER` | Administrator | Full control of the site. Username never contains `admin`/`administrator` (required by the subject). |
| `WP_USER` | Author | Can write and publish their own posts, upload media, but cannot manage plugins/users/settings. |

Passwords are the ones stored in `secrets/wp_admin_password.txt` and
`secrets/wp_password.txt` at deploy time — ask whoever ran `make` for them, or read the
files directly on the VM if you have access.

## ✍️ Managing content

Once logged in at `/wp-admin`:

- **Posts / Pages** → *Add New* to write content; the block editor (Gutenberg) is
  WordPress's default.
- **Media Library** → drag-and-drop uploads (images, documents). Upload size is capped
  at 64 MB by the NGINX configuration (`client_max_body_size`); larger files will be
  rejected with an error before reaching WordPress.
- **Plugins** → the *Redis Object Cache* plugin is installed and activated
  automatically; leave it enabled unless you're deliberately testing without a cache.
  Only the Administrator role can install/activate further plugins.
- **Users** → Administrator can create additional accounts (*Users → Add New*); avoid
  reusing "admin"-style usernames if you add another administrator, to stay consistent
  with the project's security requirement.

## ⚡ Redis object cache

The site's page/object cache is backed by the `redis` container. As a user you don't
need to do anything for it to work — it's transparent. To check it's actually active:

- In `/wp-admin`, go to **Settings → Redis** (added by the Redis Object Cache plugin):
  status should read *Connected*.
- Practically: reloading a page you've already visited should feel faster than the
  first load, since WordPress serves it from Redis instead of re-querying MariaDB and
  re-rendering PHP.

If status shows *Not connected*, see [Troubleshooting](#-troubleshooting).

## 📂 FTP access

FTP gives direct access to the WordPress files volume (themes, plugins, uploads,
`wp-config.php`) without going through the WordPress admin UI — useful for bulk file
operations or manually dropping in a theme/plugin.

- **Host:** `kebertra.42.fr` (or the VM's IP)
- **Port:** value of `FTP_PORT` in `srcs/.env`
- **Username:** value of `FTP_USER` in `srcs/.env`
- **Password:** content of `secrets/ftp_password.txt`
- **Mode:** passive (the client must support passive mode; the passive port range is
  `FTP_PASSIVE_MIN_PORT`–`FTP_PASSIVE_MAX_PORT` from `srcs/.env`)

The FTP user is **chrooted** to the WordPress files directory: you'll only ever see and
edit what's inside `/var/www/html` (i.e. the same volume WordPress itself writes to) —
there's no way to browse outside it or reach other containers' data.

> ⚠️ Editing core WordPress files over FTP (rather than through plugins/themes) is easy
> to get wrong — a typo in `wp-config.php` or a core file can take the whole site down.
> Prefer the WordPress admin UI for anything it can already do.

## 🛠️ Database administration via Adminer

Adminer gives a web UI over the MariaDB database backing WordPress — useful to inspect
tables, run one-off queries, or fix data issues that aren't reachable from the WordPress
UI.

Login screen fields:

| Field | Value |
|---|---|
| System | MySQL |
| Server | `mariadb` |
| Username | `MARIADB_USER` (from `srcs/.env`) — or `root` for full access |
| Password | `secrets/db_password.txt` (application user) or `secrets/db_root_password.txt` (root) |
| Database | `MARIADB_DATABASE` (from `srcs/.env`) |

> ⚠️ **Handle with care.** Adminer lets you edit and delete rows directly, with no
> WordPress-level validation or undo. Prefer read-only inspection unless you know
> exactly which table/column you're changing — a wrong edit to `wp_options` or
> `wp_users` can break the site or lock out the admin account.

A quick read-only alternative from the command line, without opening Adminer, is:

```sh
make db   # runs a SELECT on wp_comments as root, see the Makefile for the exact query
```

## 📊 Monitoring via Netdata

The Netdata dashboard shows real-time metrics for the host and every container: CPU,
memory, network throughput, disk I/O. No login is required — it's meant for a quick
visual health check, not for making changes.

What's worth watching day to day:

- **Per-container CPU/RAM** — spot a runaway process (e.g. a stuck WordPress cron, a
  MariaDB query eating memory) before it affects the site.
- **Network** — unusually high traffic on `nginx` or `pure-ftpd` can indicate heavy
  legitimate use, or worth a closer look if unexpected.
- **Disk** — the `mariadb_data` and `wordpress_data` volumes growing unexpectedly fast
  is usually media uploads or database bloat, both fixable from WordPress/Adminer.

## 🔁 Restarting / recovering a service

All containers run with `restart: unless-stopped` — if one crashes, Docker restarts it
automatically without any action needed. If something still looks wrong (e.g. the site
serves a database-connection error):

```sh
docker compose -f srcs/docker-compose.yml ps          # check container status/health
docker compose -f srcs/docker-compose.yml logs <service>   # e.g. wordpress, mariadb, nginx
```

To manually restart the whole stack (from the project root, where the `Makefile` is):

```sh
make down
make run
```

This does **not** delete any data — WordPress files, the database and the Redis cache
all live in named volumes that survive `make down`/`make run` cycles. Only `make clean`
/ `make fclean` remove them.

## 💾 Backups

The data that matters lives on the host, under the paths configured in `srcs/.env`
(`MARIADB_DATA_PATH`, `WORDPRESS_DATA_PATH`, `REDIS_DATA_PATH`, all inside
`/home/kebertra/data` by default). To back up:

```sh
# Stop the stack first so the database isn't mid-write during the copy.
make down

tar czf inception-backup-$(date +%F).tar.gz \
    /home/kebertra/data/wp /home/kebertra/data/db

make run
```

To restore, stop the stack, replace the contents of those same host directories with
the backup, then `make run` again — the containers will pick up the existing data
instead of reinitializing from scratch (both the MariaDB and WordPress entrypoints skip
first-boot setup when their data/marker files already exist).

## 🧯 Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Browser shows a certificate warning | Expected — the certificate is self-signed. Proceed past the warning. |
| Site doesn't load at all | Check the domain resolves to the VM's IP (`/etc/hosts`), then `docker compose ps` to confirm `nginx` and `wordpress` are healthy. |
| "Error establishing a database connection" | `mariadb` container likely still starting, crashed, or unhealthy — check `docker compose logs mariadb`. |
| Locked out of `/wp-admin` (forgotten password) | Use `make db` or Adminer to inspect `wp_users`, or reset via WP-CLI: `docker exec -it inception_wordpress wp user update <user> --user_pass=<new_pass> --allow-root`. |
| Redis shows *Not connected* in wp-admin | Check `docker compose logs redis`; confirm `REDIS_HOST`/`REDIS_PORT` in `srcs/.env` match the `redis` service, and that `secrets/redis_password.txt` isn't empty. |
| FTP connection refused / times out | Confirm `FTP_PORT` and the passive range are open/forwarded if connecting from outside the VM's network, and that you're using passive mode. |
| Adminer shows a connection error | Double-check "Server" is `mariadb` (the Docker service name, not `localhost`) and the database/user/password match `srcs/.env` and the `secrets/` files. |
| Netdata dashboard is empty/incomplete for containers | It needs read access to `/var/run/docker.sock`, `/proc` and `/sys` (already mounted in `docker-compose.yml`) — confirm the `netdata` container itself is healthy. |

## 🔒 Security reminders for administrators

- Never share the contents of `secrets/*.txt` outside the team; they're intentionally
  excluded from Git.
- If a password is suspected compromised, update the corresponding file under
  `secrets/` and `make re` — this restarts the stack, but note that some services (e.g.
  MariaDB user passwords) require the change to also be applied *inside* the database,
  not just in the secret file, since the entrypoint only sets it on first initialization.
- Keep the WordPress administrator username free of "admin"/"administrator" if it is
  ever recreated — this is a hard requirement of the 42 subject, not just a suggestion.
- Prefer the Author account (`WP_USER`) for day-to-day content writing; reserve the
  Administrator account for actual admin tasks (plugins, users, settings).
