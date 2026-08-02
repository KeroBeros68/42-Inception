# 🛠️ Developer Documentation — Inception

This document is for whoever maintains or extends this codebase — adding a service,
changing a Dockerfile, debugging a build, or reviewing the project for the 42 defense.
For what the deployed stack looks like and how to run it, see
[README.md](README.md#-architecture). For day-to-day usage once it's running, see
[USER_DOC.md](USER_DOC.md).

## 📂 Repository layout

```
.
├── Makefile                      # entry point: build/run/clean the stack
├── secrets/                      # *.txt credential files, git-ignored, touched (empty) by `make run`
├── project_management/           # cahier des charges, subject.txt (not part of the delivered app)
└── srcs/
    ├── .env                      # real config, git-ignored
    ├── .env.example              # documented template, committed
    ├── docker-compose.yml        # the whole orchestration
    └── requirements/
        ├── nginx/
        ├── wordpress/
        ├── mariadb/
        └── bonus/
            ├── redis/
            ├── pure-ftpd/
            ├── adminer/
            ├── static-site/
            └── netdata/
```

Each service directory under `requirements/` follows the same shape:

```
<service>/
├── dockerfile
├── .dockerignore          # excludes .git*, .env*, *.md from the build context
├── conf/                  # static config file(s), copied in at build time
└── tools/
    └── entrypoint.sh       # runtime configuration, executed at container start
```

## 🧱 Base image & build philosophy

Every image is `FROM alpine:3.23` — the only image pulled from a registry, per the
subject's rule (`penultimate stable version of Alpine or Debian`, base images excluded
from the "no ready-made image" restriction). Everything on top (NGINX, php-fpm,
MariaDB, Redis, Pure-FTPd, Netdata, Adminer's PHP file) is installed and configured by
hand — no `wordpress:*`, `nginx:*`, `mariadb:*`, etc. image is ever pulled.

Two deliberate consequences of choosing Alpine over Debian:

- Package manager is `apk`, C library is `musl` — service names differ from
  Debian/Ubuntu tutorials (e.g. `php83`, `php83-fpm`, not `php8.3-fpm`); watch for this
  when consulting Debian-oriented documentation.
- Images stay small, which keeps `make fclean && make` build times reasonable during
  iteration.

Each Dockerfile pins the image tag to `alpine:3.23` explicitly (never `latest`, which
the subject forbids), and none tags its own image `latest` either — see the `image:`
key per service in `docker-compose.yml` (`<service>:inception_1`).

## 🚦 Entrypoint pattern (read this before touching any `entrypoint.sh`)

Every service follows the same contract:

```sh
#!/bin/sh
set -e

if [ "$1" = "<the real daemon command>" ]; then
    # 1. validate required env vars are set, fail loudly otherwise
    # 2. template config files (sed __PLACEHOLDER__ -> $ENV_VAR)
    # 3. first-boot-only setup, guarded by an idempotency check
fi

exec "$@"
```

- `exec "$@"` is what makes the daemon (`nginx`, `mariadbd`, `php-fpm83`, `redis-server`,
  `/usr/sbin/pure-ftpd`, `netdata`) become the container's actual **PID 1**, in the
  foreground, so it receives signals directly (clean `SIGTERM` on `docker stop`,
  correct `restart: unless-stopped` behavior). Never replace this with a background
  daemon + a `tail -f`/`sleep infinity`/`while true` wrapper — the subject explicitly
  forbids that pattern and it breaks signal handling.
- The `if [ "$1" = "..." ]` guard means the setup logic only runs when the container is
  started with its normal `CMD`; it's skipped if someone overrides the command (e.g.
  `docker run ... sh`) for debugging.
- **Idempotency guards** — every entrypoint that does first-boot work checks a marker
  before doing it again, so `make down && make run` (which reuses the named volumes) is
  safe to run repeatedly without erroring or re-running install logic:

  | Service | Idempotency marker |
  |---|---|
  | `mariadb` | `/var/lib/mysql/.initialized` |
  | `wordpress` | presence of `/var/www/html/wp-config.php` (core install), `wp-load.php` (core download), the Redis plugin's `object-cache.php` |
  | `nginx` | presence of `/etc/nginx/ssl/<domain>.crt` per hostname |
  | `pure-ftpd` | presence of `/etc/pure-ftpd/passwd/pureftpd.pdb` |

- **Config templating** uses `sed -i "s/__VAR__/$VAR/g"` on placeholder tokens baked
  into the committed config file (`nginx.conf`, `redis.conf`, `netdata.conf`) — not
  environment variable substitution at the NGINX/Redis config-parser level, since
  neither of those support that natively. If you add a new configurable value, add the
  `__TOKEN__` in the conf file *and* the corresponding `sed` line in that service's
  `entrypoint.sh`, and fail fast if the env var is unset.

## 🔗 Service-by-service notes

### nginx

- Single `nginx.conf`, three HTTPS `server {}` blocks sharing port 443 via **SNI**
  (WordPress/main domain, static site, Netdata — differentiated by `server_name` +
  distinct cert/key pair each), plus one plain HTTP block on port 80 that 301-redirects
  everything to HTTPS.
- Self-signed certs are generated once per hostname on first boot
  (`openssl req -x509 ...`), stored in `/etc/nginx/ssl/`, and re-used on restart thanks
  to the idempotency check above.
- `depends_on: condition: service_healthy` on `wordpress`, `adminer`, `static-site` and
  `netdata` — NGINX won't start proxying before its upstreams report healthy, avoiding a
  boot-order race.
- Adding a new proxied hostname = add a `server {}` block with its own `server_name`
  and cert paths, add its domain to the plain-HTTP redirect block's `server_name` list,
  add the new domain/port to `.env` + `docker-compose.yml`'s `environment:` and
  `depends_on:` for `nginx`, and template it in `entrypoint.sh`.

### wordpress

- Installed **headlessly** via [WP-CLI](https://developer.wordpress.org/cli/commands/)
  (`wp core download`, `wp config create`, `wp core install`, `wp user create`) — no
  browser install wizard involved, which is what lets `make` bring up a fully
  configured site with zero manual steps.
- Waits on MariaDB with a polling loop (`until mariadb-admin ping ...; do sleep 2;
  done`) before touching the database — this is a *readiness* wait, not a substitute for
  `depends_on: condition: service_healthy` (which is also set); both together avoid
  relying on either alone.
- Redis integration: installs/activates the `redis-cache` plugin via WP-CLI, sets
  `WP_REDIS_HOST`/`PORT`/`PASSWORD` in `wp-config.php`, then `wp redis enable`. Checked
  idempotently via `wp redis status | grep -qi connected`.
- Runs php-fpm listening on `0.0.0.0:$WORDPRESS_PORT` (not a Unix socket) since NGINX
  reaches it over the Docker network by service name (`fastcgi_pass
  wordpress:__WORDPRESS_PORT__`), not a shared filesystem.

### mariadb

- First boot: `mariadb-install-db`, then a `mariadbd --bootstrap` heredoc that sets the
  root password, creates the `wordpress` database, and creates the application user —
  all before the daemon is handed control normally, avoiding a window where the DB is
  up but unsecured.
- Runs with `--skip-networking=0 --bind-address=0.0.0.0` so it's reachable from
  `wordpress`/`adminer` over `inception-back`; that network is `internal: true` in
  Compose, so this never becomes reachable from the host or outside Docker.

### redis, pure-ftpd, adminer, static-site, netdata (bonus)

- **redis** — `maxmemory 2gb` / `allkeys-lru` eviction, `appendonly yes` for durability
  across restarts, password and port templated into `redis.conf` at boot.
- **pure-ftpd** — a single virtual user (`pure-pw useradd`) chrooted to
  `/var/www/html` (the same `wordpress_data` volume), started with `-A` (chroot
  everyone), `-E` (no anonymous), `-R` (no `chmod`), `-C 10` (max connections per IP).
  Passive mode requires `-P <container IP>` so clients get a routable address back —
  handled via `hostname -i` in the entrypoint.
- **adminer** — a single downloaded PHP file (`adminer-<version>-mysql.php`) served by
  its own php-fpm pool, reverse-proxied by NGINX at `/adminer/`. No database
  connection details are baked in; they're entered by hand at Adminer's login screen
  (see [USER_DOC.md](USER_DOC.md#-database-administration-via-adminer)).
- **static-site** — plain NGINX serving static files from `html/`, no PHP installed at
  all (the subject explicitly excludes PHP for this bonus). Its own minimal
  `nginx.conf` is unrelated to the main NGINX container's config.
- **netdata** — mounts `/var/run/docker.sock`, `/proc` and `/sys` read-only from the
  host (with `NETDATA_HOST_PREFIX=/host`) so it reports real host/container metrics
  instead of only its own near-empty container's stats.

## 🌐 Networking & volumes reference

| Network | Type | Purpose |
|---|---|---|
| `inception-front` | bridge | nginx, wordpress, adminer, static-site, netdata, pure-ftpd — anything that either faces NGINX or needs a host-published port |
| `inception-back` | bridge, `internal: true` | wordpress ↔ mariadb, wordpress ↔ redis, adminer ↔ mariadb — no route to the outside world |

| Volume | Backing host path (from `.env`) | Used by |
|---|---|---|
| `wordpress_data` | `WORDPRESS_DATA_PATH` | wordpress, nginx (read), pure-ftpd |
| `mariadb_data` | `MARIADB_DATA_PATH` | mariadb |
| `redis_data` | `REDIS_DATA_PATH` | redis |

All three are `driver: local` with `driver_opts: {type: none, o: bind, device:
<path>}` — a named volume whose storage happens to be a bind mount to a fixed host
path, satisfying the subject's "must be under `/home/<login>/data`, no bind mounts"
requirement while staying Docker-managed (see README's
[Docker Volumes vs Bind Mounts](README.md#-docker-volumes-vs-bind-mounts) for the
reasoning).

## 🔑 Environment variables & secrets reference

`srcs/.env.example` is the source of truth for every variable — copy it to `srcs/.env`
and fill it in; each entry has an inline comment. Do not add a new *credential* to
`.env`: anything sensitive belongs in `secrets/` and is wired through
`docker-compose.yml`'s `secrets:` block + a `*_FILE` environment variable, following
the existing pattern (e.g. `MARIADB_PASSWORD_FILE=/run/secrets/db_password`). See
README's [Secrets vs Environment Variables](README.md#-secrets-vs-environment-variables)
for why.

To add a new secret:

1. Add its filename to `SECRET_FILES` in the `Makefile`, so `make secrets` creates it
   too (created interactively before `make run`, per [README.md](README.md#-setup) —
   `make run` itself no longer creates secret files).
2. Declare it under `secrets:` at the top of `docker-compose.yml`.
3. List it under the consuming service's `secrets:` key, and pass its path as a
   `SOMETHING_FILE` environment variable.
4. Read it in that service's `entrypoint.sh` with `cat /run/secrets/<name>` — never log
   its value.

## 🧪 Debugging & common dev workflows

```sh
# Rebuild a single service after editing its Dockerfile/entrypoint:
docker compose -f srcs/docker-compose.yml up -d --build <service>

# Tail logs for one service:
docker compose -f srcs/docker-compose.yml logs -f <service>

# Shell into a running container:
docker exec -it inception_<service> sh

# Check why a HEALTHCHECK is failing:
docker inspect --format='{{json .State.Health}}' inception_<service> | python3 -m json.tool

# Full reset (containers + images + volumes for this project only):
make clean

# Full reset + prune everything Docker-wide on the host (careful — affects other projects too):
make fclean
```

Startup order is expressed entirely through `depends_on: condition: service_healthy`
in `docker-compose.yml`, backed by each Dockerfile's `HEALTHCHECK`. If a service seems
to start before its dependency is really ready, check that service's `HEALTHCHECK`
command actually reflects readiness (e.g. WordPress's checks that the FastCGI port is
listening, not that WP-CLI's install step has finished) before adding a workaround
elsewhere.

## ✅ Conventions to follow when extending the project

- One Dockerfile per service, `FROM alpine:3.23`, never `latest` on the produced image.
- `ENTRYPOINT` + `CMD`, ending in `exec "$@"` — the daemon must be PID 1, foreground,
  no loop-based patches.
- Fail fast and loud (`echo "[ERROR]: ..." >&2; exit 1`) on missing required env vars,
  rather than starting in a half-configured state.
- Idempotent first-boot logic, guarded by a marker file — restarts must not fail or
  redo expensive/destructive work.
- No secret ever hardcoded in a Dockerfile, config file, or committed to Git — always
  `secrets/` + `/run/secrets/*`.
- `HEALTHCHECK` on every service, used as the real signal for `depends_on`.
- `.dockerignore` per service (`.git*`, `.env*`, `*.md`) to keep build contexts small
  and avoid ever baking `.env`/secrets into an image layer by accident.
