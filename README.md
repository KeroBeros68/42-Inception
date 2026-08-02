*This project has been created as part of the 42 curriculum by kebertra.*

# 🐳 Inception

## 📖 Description

**Inception** is a System Administration project from the 42 curriculum. Its goal is to
build, from scratch and inside a personal virtual machine, a small but realistic web
infrastructure entirely orchestrated with Docker Compose — without relying on any
pre-built image from Docker Hub (base OS images excluded).

The mandatory part sets up a classic three-tier stack:

- 🔒 **NGINX** — the single entry point of the infrastructure, exposing HTTPS (TLS 1.2/1.3
  only) on port 443.
- 📝 **WordPress + php-fpm** — the CMS and its PHP processor, with no web server bundled
  inside the container.
- 🗄️ **MariaDB** — the database engine backing WordPress, with no web server bundled
  inside the container either.

Each service runs in its own container, built from its own hand-written Dockerfile
(`FROM alpine:3.23`, the penultimate stable Alpine release, as allowed by the subject),
communicates over a dedicated Docker network, and stores its persistent data in named
volumes mounted under `/home/kebertra/data` on the host.

On top of the mandatory part, this implementation includes every bonus service listed
in the subject, plus one service picked freely and justified at defense:

- ⚡ **Redis** — object cache for WordPress.
- 📂 **Pure-FTPd** — FTP access to the WordPress files volume.
- 🌐 **A static site** — a PHP-free showcase site, served by NGINX on a second hostname
  (SNI) on the same port 443.
- 🛠️ **Adminer** — a lightweight web UI to inspect/administer the MariaDB database.
- 📊 **Netdata** *(free choice)* — real-time monitoring of the host's and every
  container's CPU, memory, network and disk usage, served on a third hostname via SNI.

## 🏗️ Architecture

```
                                   WWW
                                    │
                          443 (TLS 1.2/1.3, SNI)
                                    │
┌───────────────────────── inception-front ───────────────────────────┐
│                                                                       │
│              ┌────────┐                                              │
│   ┌─────────►│ nginx  │◄───────────────┬─────────────────┬──────────┼──► FTP (21 + passive range)
│   │          └───┬────┘                │                 │          │        ┌───────────┐
│   │              │ :9000 (FastCGI)     │ :8080 (FastCGI) │ :19999   │        │ pure-ftpd │
│   │              ▼                     ▼                 ▼          │        └─────┬─────┘
│   │       ┌──────────────┐      ┌───────────┐    ┌───────────┐      │              │
│   │       │  wordpress   │      │  adminer  │     │  netdata  │      │              │
│   │       │  (php-fpm)   │      └─────┬─────┘     └───────────┘      │              │
│   │       └──────┬───────┘            │                              │              │
│   │              │ :3306              │ :3306                       │              │
│   └───────┐      ▼                    ▼                              │              │
│  ┌────────┴──┐ ┌────────┐                        inception-back      │              │
│  │static-site│ │mariadb │◄── internal only, no host port exposed ────┘              │
│  └───────────┘ └───┬────┘                                                           │
│                    │ :6379                                                          │
│              ┌─────▼─────┐                                                          │
│              │   redis   │                                                          │
│              └───────────┘                                                          │
└───────────────────────────────────────────────────────────────────────────────────┘
        │                    │                    │
   (named volume)      (named volume)        (named volume)
        │                    │                    │
/home/kebertra/data/wp  /home/kebertra/data/db  /home/kebertra/data/redis
```

- `inception-front` is a regular bridge network: it carries the traffic that must reach
  NGINX (and, for FTP, the host directly).
- `inception-back` is an **internal** bridge network (`internal: true`): MariaDB and
  Redis are only reachable from containers attached to it, never from the host or the
  outside world.
- NGINX is the only container publishing a host port for web traffic (`443`); Pure-FTPd
  additionally publishes its control port and passive port range, as FTP inherently
  needs a host-facing port. No other service is reachable directly from outside Docker.

## 🚀 Instructions

### ✅ Prerequisites

- A virtual machine (this project targets Debian) with Docker Engine and the Docker
  Compose plugin installed.
- The domain names used below resolving to the VM's local IP address (e.g. via
  `/etc/hosts` on the machine you browse from):
  `kebertra.42.fr`, and whichever hostnames you set as `STATIC_DOMAIN_NAME` /
  `NETDATA_DOMAIN_NAME`.

### ⚙️ Setup

```sh
git clone <this-repository>
cd inception

cp srcs/.env.example srcs/.env
$EDITOR srcs/.env          # fill in every variable, see comments in the file
```

Every credential lives outside `.env`, in the `secrets/` directory, as plain text
files ignored by Git. Create them interactively (existing, non-empty files are left
untouched):

```sh
make secrets   # prompts for each value, hidden input, writes secrets/*.txt
```

Equivalently, they can be created by hand:

```sh
echo "a-strong-password"  > secrets/db_root_password.txt
echo "a-strong-password"  > secrets/db_password.txt
echo "a-strong-password"  > secrets/wp_admin_password.txt
echo "a-strong-password"  > secrets/wp_password.txt
echo "a-strong-password"  > secrets/redis_password.txt
echo "a-strong-password"  > secrets/ftp_password.txt
```

### ▶️ Build & run

```sh
make          # equivalent to `make run` — creates the host data directories,
              # then `docker compose up --build -d` (requires secrets/*.txt to already exist)
```

Available targets:

| Target | Effect |
|--------|--------|
| `make` / `make run` | Builds every image and starts the whole stack, detached |
| `make down` | Stops the containers without removing images/volumes |
| `make re` | `down` then `run` |
| `make clean` | Stops the stack and removes this project's containers, images and volumes |
| `make fclean` | `clean`, plus a full `docker system prune -af` (affects Docker beyond this project) |
| `make db` | Opens a MariaDB shell against the `wordpress` database (root user) |
| `make secrets` | Interactively creates `secrets/*.txt`, skipping any that already exist |
| `make help` | Lists all available commands |

Once the containers report healthy (`docker compose -f srcs/docker-compose.yml ps`),
the site is reachable at `https://kebertra.42.fr`, with:

- 📝 `https://kebertra.42.fr/wp-admin` for the WordPress admin dashboard.
- 🛠️ `https://kebertra.42.fr/adminer/` for Adminer.
- 🌐 `https://<STATIC_DOMAIN_NAME>` for the static showcase site.
- 📊 `https://<NETDATA_DOMAIN_NAME>` for the Netdata monitoring dashboard.
- 📂 `ftp://kebertra.42.fr:<FTP_PORT>` for FTP access to the WordPress files, using
  `FTP_USER` and the password from `secrets/ftp_password.txt`.

All three HTTPS hostnames are served by the *same* NGINX container on the *same* port
443, distinguished purely via SNI (`server_name` + one certificate per hostname) —
consistent with the subject's requirement of a single network entry point.

Certificates are self-signed (generated on first boot by NGINX's entrypoint), which is
sufficient for a local, non-publicly-exposed environment; browsers will show a trust
warning that can safely be bypassed in this context.

## 🧩 Project description

### 🐳 Docker usage and project sources

Every container is built from its own Dockerfile under
`srcs/requirements/<service>/dockerfile` (and `srcs/requirements/bonus/<service>/dockerfile`
for the bonus services), all based on `alpine:3.23` — the only image pulled from a
registry, as explicitly permitted by the subject. No other image is pulled ready-made:
NGINX, php-fpm, MariaDB, Redis, Pure-FTPd, Adminer and Netdata are all installed and
configured by hand inside their respective Dockerfile.

Each Dockerfile:

- Installs only the packages that specific service needs (minimal attack surface, small
  image size).
- Copies in its static configuration (e.g. `nginx.conf`, `redis.conf`) and its
  `entrypoint.sh`.
- Declares a `HEALTHCHECK` so Docker Compose can express real startup dependencies
  (`depends_on: condition: service_healthy`) instead of guessing with fixed delays.
- Uses `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]` + `CMD [...]`, where the entrypoint
  script performs first-boot configuration (writing config files from environment
  variables, generating TLS certificates, initializing the database, installing
  WordPress via WP-CLI, etc.) and finishes with `exec "$@"`, so the container's actual
  PID 1 ends up being the real service daemon (`nginx`, `mariadbd`, `php-fpm83`, ...)
  running in the foreground — never a shell loop, `tail -f`, or `sleep infinity`.

`docker-compose.yml` (at `srcs/docker-compose.yml`) ties every service together:
two networks (`inception-front`, `inception-back`), three application named volumes
plus one healthcheck-driven boot order, Docker secrets mounted read-only in
`/run/secrets/*`, `restart: unless-stopped` on every service, and JSON-file logging
capped in size to avoid unbounded log growth on a long-running VM.

### 💡 Main design choices

- **Two networks instead of one.** Splitting `inception-front` (reaches NGINX/FTP) from
  an `internal: true` `inception-back` (MariaDB, Redis) means the database and cache are
  architecturally unreachable from outside Docker, not just "not exposed by convention".
- **TLS terminated at NGINX only.** All internal traffic (NGINX → php-fpm, php-fpm →
  MariaDB/Redis) stays in plaintext *inside* an isolated Docker network the host doesn't
  route to; only the single external-facing hop is encrypted, matching the subject's
  "NGINX is the only entry point" requirement.
- **One hostname, one port, multiple sites via SNI.** Rather than opening extra host
  ports for the static site and Netdata, they're reverse-proxied by NGINX on distinct
  `server_name` blocks sharing port 443 — keeping the "single entry point" promise
  literal instead of just spiritual.
- **Idempotent entrypoints.** Every entrypoint checks for a marker of prior
  initialization (`.initialized` file for MariaDB, presence of `wp-config.php` for
  WordPress, presence of a `.crt` file for NGINX) before doing first-boot work, so
  `make down && make run` restarts cleanly without re-running installation logic or
  failing on "already exists" errors.
- **WP-CLI instead of the browser install wizard.** WordPress is installed headlessly by
  script (`wp core install`, `wp user create`), which is what makes a from-scratch
  `make` bring the whole site up with zero manual clicking, and is also how the second,
  non-admin WordPress user and the Redis object-cache plugin get provisioned
  automatically.

### 🖥️ Virtual Machines vs Docker

| | Virtual Machine | Docker |
|---|---|---|
| Isolation unit | Full OS (own kernel), virtualized hardware | Process, isolated via kernel namespaces/cgroups, sharing the host kernel |
| Boot time / overhead | Seconds to minutes; a full OS to boot and keep running | Milliseconds to seconds; no OS boot, just process startup |
| Resource footprint | Each VM reserves its own RAM/CPU/disk allocation | Containers share the host kernel and only consume what the running process needs |
| Use in this project | The whole infrastructure runs *inside one VM*, per the subject's requirement | *Inside* that VM, each service is one container — composition, not virtualization |

The two are complementary here, not competing: the VM provides one hard isolation
boundary against the host machine (and is what the subject mandates), while Docker
provides fast, cheap, reproducible isolation *between the services themselves* — giving
each of the seven services its own filesystem, process tree and network namespace
without paying a full-OS cost seven times over.

### 🔐 Secrets vs Environment Variables

`srcs/.env` holds everything that configures behavior but isn't sensitive: hostnames,
ports, database/user *names*, and host paths for the volumes. It's read directly by
`docker-compose.yml`'s variable substitution and by the Makefile, and is excluded from
Git via `.gitignore` — but nothing in it would cause serious harm if leaked, only
inconvenience.

Actual credentials (`db_root_password.txt`, `db_password.txt`, `wp_admin_password.txt`,
`wp_password.txt`, `redis_password.txt`, `ftp_password.txt`) live under `secrets/` and
are wired in through Docker's native `secrets:` mechanism instead of environment
variables. Concretely this means:

- Each secret is mounted read-only as a *file* at `/run/secrets/<name>` inside the
  container that needs it, never as a process environment variable.
- Environment variables are visible to any process that can read `/proc/<pid>/environ`
  in the container, show up in `docker inspect`, and can leak into crash reports or
  child-process environments. A file under `/run/secrets` mounted via a `tmpfs`-backed
  bind avoids all of that: it's read once by the entrypoint script (`cat
  /run/secrets/db_password`) and never persisted to the image or the container layer,
  so it can't end up baked into an image built or committed by mistake.

That's also why the `*_PASSWORD_FILE` convention appears in `docker-compose.yml`
(e.g. `MARIADB_PASSWORD_FILE=/run/secrets/db_password`) instead of `*_PASSWORD`: the
container only ever receives a *path* to the credential, and reads it explicitly at
startup.

### 🌐 Docker Network vs Host Network

The subject explicitly forbids `network: host` and `--link`. This project defines two
custom bridge networks (`inception-front`, `inception-back`) instead of using the host's
network namespace:

- With `network: host`, a container shares the host's network stack directly: no
  isolation, every container-exposed port is automatically a host port, and containers
  can only be told apart by the port they bind to — collisions are one typo away, and
  MariaDB/Redis would be reachable from anywhere the host itself is reachable.
- With dedicated bridge networks, each container gets its own network namespace and a
  private IP on that bridge. Only what's explicitly published via `ports:` in
  `docker-compose.yml` (443 and the FTP range) is reachable from the host; service
  discovery between containers happens by *service name* (`wordpress:9000`,
  `mariadb:3306`) via Docker's embedded DNS, not by hardcoded IPs. Making
  `inception-back` `internal: true` goes one step further: containers on it get no
  route to the outside world at all, so even a compromised WordPress container
  couldn't use MariaDB's network path to reach out.

### 💾 Docker Volumes vs Bind Mounts

The subject requires **named volumes**, explicitly forbidding bind mounts, for the two
persistent stores (database + WordPress files) — this project also adds a third one for
Redis's append-only file. Concretely:

- A **bind mount** maps a host path straight into the container as-is: the container
  sees (and can alter permissions/ownership of) an arbitrary host directory, and the
  mapping is defined by *whoever runs `docker run`/`docker compose up`*, not by the
  image or a stable Docker-managed name.
- A **named volume** is a storage area Docker manages under its own identity
  (`wordpress_data`, `mariadb_data`, `redis_data`), independent of the container's
  lifecycle: `docker compose down` removes the containers but leaves the volumes (and
  the data in them) intact until explicitly removed with `-v` / `make clean`.

Here, each named volume additionally uses the `local` driver with `driver_opts` of
`type: none, o: bind, device: ${..._DATA_PATH}` — meaning the volume's actual backing
storage *is* a bind mount to a fixed host path under `/home/kebertra/data/...`, as the
subject requires, but it stays wrapped in a Docker-managed named volume. This keeps the
required host-visible path for grading while still going through `docker volume`
tooling (naming, inspection, safe removal) rather than a raw, ad-hoc bind mount declared
directly on the service.

## 📚 Resources

### 🔗 Documentation & references

- 🐳 [Docker documentation](https://docs.docker.com/)
- 🐳 [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- 🔐 [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) and
  [Compose `secrets` top-level element](https://docs.docker.com/compose/compose-file/09-secrets/)
- 📄 [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- 🏔️ [Alpine Linux packages](https://pkgs.alpinelinux.org/packages)
- 🔒 [NGINX documentation](https://nginx.org/en/docs/)
- 🔒 [NGINX SNI-based multi-site TLS](https://nginx.org/en/docs/http/configuring_https_servers.html)
- 🗄️ [MariaDB Knowledge Base](https://mariadb.com/kb/en/documentation/)
- 📝 [WordPress Developer Resources](https://developer.wordpress.org/)
- 📝 [WP-CLI command reference](https://developer.wordpress.org/cli/commands/)
- ⚡ [Redis documentation](https://redis.io/docs/latest/) and the
  [Redis Object Cache plugin](https://wordpress.org/plugins/redis-cache/)
- 📂 [Pure-FTPd documentation](https://www.pureftpd.org/project/pure-ftpd/doc/)
- 🛠️ [Adminer](https://www.adminer.org/)
- 📊 [Netdata documentation](https://learn.netdata.cloud/)
- ✍️ [Stéphane Robert's blog](https://blog.stephane-robert.info/) — DevOps/Docker/Linux
  write-ups used as a secondary, practitioner-oriented reference alongside the official
  docs above.
- 🧠 [My Obsidian vault](https://github.com/KeroBeros68/Obsidian-vault) — personal
  knowledge base built from these same sources, used to cross-check the Docker, NGINX,
  MariaDB, Redis and FTP concepts applied in this project.
- 📘 42 "Inception" subject, version 5.3 (provided with the project)

### 🤖 AI usage

AI (an LLM-based coding assistant) was used during this project strictly as a support
tool, in line with the subject's AI guidelines — not to generate the infrastructure
unsupervised:

- ✍️ **Documentation writing.** This README, as well as the internal project-management
  documents (cahier des charges), were drafted and formatted with AI assistance based
  on the actual subject requirements and the already-written source code, then reviewed
  for accuracy against both.
- 💡 **Conceptual explanations.** Used to understand underlying concepts before
  implementing them by hand — e.g. how PID 1 signal handling works in containers, why
  `tail -f`-style entrypoints are discouraged, how TLS session caching works, how
  Docker secrets differ from environment variables at the kernel/filesystem level.
- 🐛 **Debugging and configuration review.** Used to help diagnose startup failures
  (container dependency ordering, php-fpm/FastCGI misconfiguration, MariaDB
  initialization races) and to review `docker-compose.yml` and the Dockerfiles for
  mistakes, without having AI author the working configuration from scratch.

Every piece of AI-assisted output was read, understood and validated against the
official subject and the project's own behavior before being kept, per the "only use
AI-generated content you fully understand and can take responsibility for" rule stated
in the subject.

## 🙏 Special thanks

- **Gdosch**, fellow 42 student, for advice throughout the project and for sharing an
  example of the expected result, which helped calibrate what a complete, defense-ready
  submission looks like.
