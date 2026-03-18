# Architecture Research

**Domain:** Docker template for Symfony 7 LTS with FrankenPHP (Spin template)
**Researched:** 2026-03-18
**Confidence:** HIGH — all findings verified against live source code of the reference template and official serversideup documentation

## Standard Architecture

### System Overview

```
spin new symfony
       |
       v
┌─────────────────────────────────────────────────────────────────┐
│                    Spin Template Repository                       │
│                                                                   │
│  meta.yml          install.sh         template/                  │
│  (metadata)        (interactive       ├── Dockerfile             │
│                     setup)            ├── docker-compose.yml     │
│                                       ├── docker-compose.dev.yml │
│                                       ├── docker-compose.prod.yml│
│                                       └── .infrastructure/       │
│                    post-install.sh        ├── conf/traefik/      │
│                    (framework             │   ├── dev/            │
│                     install)             │   └── prod/           │
│                                          └── volume_data/        │
└─────────────────────────────────────────────────────────────────┘
       |
       v (files copied to user's project)
┌─────────────────────────────────────────────────────────────────┐
│                   User's Project (Runtime)                        │
├──────────────────────────────┬──────────────────────────────────┤
│         Dev Environment      │       Prod Environment            │
│                              │                                   │
│  Traefik (reverse proxy)     │  Traefik (Docker Swarm mode)      │
│    - Self-signed SSL certs   │    - Let's Encrypt ACME           │
│    - Docker provider         │    - Swarm provider               │
│    - Port 80/443             │    - Port 80/443 (host mode)      │
│         |                    │          |                        │
│  php container               │  php service (Swarm replica)      │
│    (frankenphp image)        │    (frankenphp image)             │
│    - Volume mount (live)     │    - Named volumes                │
│    - Port 8080/8443          │    - Port 8080/8443               │
│    - USER_ID/GROUP_ID match  │    - SSL_MODE: full               │
│         |                    │    - AUTORUN_ENABLED              │
│  node container              │         |                         │
│    (asset compilation)       │  Named volumes                    │
│         |                    │    - storage_private              │
│  mailpit (dev email)         │    - storage_public               │
│    - Port 8025               │    - storage_sessions             │
│                              │    - storage_logs                 │
└──────────────────────────────┴──────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `meta.yml` | Declares template identity (title, author, repo URL) for Spin CLI discovery | YAML file, no logic |
| `install.sh` | Interactive prompts: PHP version, OS (debian/alpine); assembles image tag; dispatches `new()` or `init()` | Bash with `SPIN_ACTION` dispatch pattern |
| `post-install.sh` | Installs Symfony skeleton via Composer inside Docker container; patches Dockerfile FROM line with chosen image; configures Traefik server contact email | Bash, calls `docker run` with installer image |
| `Dockerfile` | Multi-stage build: `base`, `development`, `ci`, `deploy`; `deploy` stage copies application code and sets ownership | Multi-stage Dockerfile using `serversideup/php:*-frankenphp` base |
| `docker-compose.yml` | Base service definitions — service names, images, core environment; no ports; no network | Docker Compose base; always merged |
| `docker-compose.dev.yml` | Adds Traefik (self-signed SSL), volume mounts for live editing, node service, Mailpit, `development` network, UID/GID build args | Docker Compose override for `spin up` |
| `docker-compose.prod.yml` | Adds Swarm deploy config (replicas, update/rollback policy, restart policy), named volumes, Traefik labels with Let's Encrypt, `web-public` network, Docker configs for Traefik YAML | Docker Compose override for `spin deploy` |
| `.infrastructure/conf/traefik/dev/` | Dev-mode Traefik config: Docker provider, file provider for certs, self-signed TLS cert files | `traefik.yml`, `traefik-certs.yml`, `certificates/*.pem` |
| `.infrastructure/conf/traefik/prod/` | Prod Traefik config: Swarm provider, Let's Encrypt ACME resolver, HTTP→HTTPS redirect, Cloudflare trusted IPs | `traefik.yml` |
| `.infrastructure/volume_data/` | Persisted runtime data: Symfony var/ equivalent, any writable directories | `.gitignore` to exclude actual data, directory structure committed |
| `serversideup/php:*-frankenphp` | PHP runtime + Caddy web server in one process; handles HTTP/2, HTTP/3, optional worker mode; runs as `www-data` on ports 8080/8443 | Official Docker image, not built by this template |

## Recommended Project Structure

```
spin-template-symfony/
├── meta.yml                          # Template identity for Spin CLI
├── install.sh                        # Interactive setup (PHP version, OS, email)
├── post-install.sh                   # Framework install + file patching
└── template/                         # Files copied to user's project
    ├── Dockerfile                    # Multi-stage: base, development, ci, deploy
    ├── docker-compose.yml            # Base: php service, image reference
    ├── docker-compose.dev.yml        # Dev: Traefik, volumes, node, mailpit
    ├── docker-compose.prod.yml       # Prod: Swarm, Let's Encrypt, named volumes
    └── .infrastructure/
        ├── conf/
        │   └── traefik/
        │       ├── dev/
        │       │   ├── traefik.yml           # Docker provider, file provider
        │       │   ├── traefik-certs.yml     # TLS store pointing to local certs
        │       │   └── certificates/
        │       │       ├── local-dev.pem     # Self-signed cert (committed)
        │       │       └── local-dev-key.pem # Self-signed key (committed)
        │       └── prod/
        │           └── traefik.yml           # Swarm provider, ACME, Cloudflare IPs
        └── volume_data/
            └── .gitignore                    # Exclude runtime data, keep dir structure
```

### Structure Rationale

- **`meta.yml` at root:** Spin CLI reads this file first to discover template metadata before running install scripts.
- **`install.sh` at root:** Spin CLI convention — the entry point for `spin new` and `spin init`. Must export `SPIN_PROJECT_DIRECTORY`.
- **`post-install.sh` at root:** Runs after template files are copied, performs the framework installation (Composer create-project) and token substitution (FROM line, email placeholders).
- **`template/` as the copy source:** Everything inside `template/` is what Spin copies into the user's project directory. The template author sees one level of nesting; the user sees none.
- **`.infrastructure/` within template:** Keeps infrastructure config co-located with the project (not a separate repo). The `conf/` vs `volume_data/` split separates committed config from runtime data.

## Architectural Patterns

### Pattern 1: Multi-Stage Dockerfile (base → development → ci → deploy)

**What:** A single Dockerfile with four named targets. `base` installs shared dependencies. `development` adds UID/GID remapping so bind-mounted files are writable by the host user. `ci` runs as root for pipeline flexibility. `deploy` copies application code and locks down permissions.

**When to use:** Always — this is the established Spin template pattern. The Laravel basic template uses this exact structure.

**Trade-offs:** Slightly more Dockerfile complexity but eliminates separate dev vs prod Dockerfiles. The `deploy` stage is what gets pushed to a registry for production.

**Example:**
```dockerfile
FROM serversideup/php:8.4-frankenphp AS base

FROM base AS development
ARG USER_ID
ARG GROUP_ID
USER root
RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID && \
    docker-php-serversideup-set-file-permissions --owner $USER_ID:$GROUP_ID
USER www-data

FROM base AS ci
USER root

FROM base AS deploy
COPY --chown=www-data:www-data . /var/www/html
USER www-data
```

### Pattern 2: Docker Compose Environment Overlays

**What:** Three Compose files always merged in order: base (`docker-compose.yml`) + environment overlay (`docker-compose.dev.yml` or `docker-compose.prod.yml`). Base defines service names and image references only. Overlays add environment-specific configuration.

**When to use:** Always — this is how Spin orchestrates dev vs prod without duplicating service definitions.

**Trade-offs:** Requires understanding of Docker Compose merge semantics. Keys override; arrays like `labels` append in some Compose versions. Keeping the base minimal reduces merge surprises.

**Example structure:**
```
# docker-compose.yml (base)
services:
  php:
    image: ${SPIN_IMAGE_DOCKERFILE:-ghcr.io/org/app:latest}

# docker-compose.dev.yml (overlay)
services:
  php:
    build:
      target: development
      args:
        USER_ID: ${SPIN_USER_ID}
        GROUP_ID: ${SPIN_GROUP_ID}
    volumes:
      - .:/var/www/html/
```

### Pattern 3: Traefik as Reverse Proxy with Labels

**What:** Traefik reads Docker/Swarm service labels to discover routing rules. The PHP container announces itself to Traefik via `traefik.enable=true` and routing labels. No static Traefik route config needed for the application.

**When to use:** Always in this template. Dev uses Docker provider; prod uses Swarm provider.

**Trade-offs:** Dev and prod Traefik configs differ structurally (Docker provider vs Swarm provider). FrankenPHP's built-in HTTPS/ACME is bypassed in favor of Traefik handling SSL — this is the correct architecture when using a reverse proxy.

**Key port mapping:**
```
# Dev: PHP container labels
traefik.http.services.symfony.loadbalancer.server.port=8080  # HTTP to FrankenPHP
traefik.http.services.symfony.loadbalancer.server.scheme=http

# Prod: SSL_MODE=full means FrankenPHP handles HTTPS internally
traefik.http.services.symfony.loadbalancer.server.port=8443  # HTTPS to FrankenPHP
traefik.http.services.symfony.loadbalancer.server.scheme=https
```

### Pattern 4: FrankenPHP Symfony Worker Mode

**What:** FrankenPHP can keep the Symfony kernel bootstrapped in memory across requests (worker mode), dramatically reducing per-request overhead. Requires `runtime/frankenphp-symfony` Composer package. Configured via `FRANKENPHP_CONFIG` environment variable.

**When to use:** Optional in development (adds complexity during debugging), recommended for production.

**Trade-offs:** Worker mode means the Symfony kernel stays in memory — stateful bugs (e.g., not resetting service state) become visible. Not all Symfony bundles are worker-mode safe. Disabled by default so developers must opt in explicitly.

**Configuration:**
```bash
# Environment variable to enable worker mode
FRANKENPHP_CONFIG="worker ./public/index.php"
APP_RUNTIME=Runtime\\FrankenPhpSymfony\\Runtime

# Or via composer.json (preferred for consistency)
# "extra": { "runtime": { "class": "Runtime\\FrankenPhpSymfony\\Runtime" } }
```

## Data Flow

### Request Flow (Development)

```
Browser
  |
  | HTTP/HTTPS :80/:443
  v
Traefik container
  | (reads Docker labels, routes by Host header)
  | HTTP :8080 (dev uses HTTP to FrankenPHP)
  v
php container (serversideup/php:*-frankenphp)
  | (FrankenPHP/Caddy receives request)
  | (bootstraps Symfony kernel OR reuses worker)
  v
Symfony 7 application
  | (public/index.php → HttpKernel)
  v
Response back through same chain
```

### Request Flow (Production / Docker Swarm)

```
Internet
  |
  | TCP :80/:443 (host mode)
  v
Traefik service (Swarm manager node)
  | (reads Swarm labels, Let's Encrypt terminates TLS)
  | HTTPS :8443 (SSL_MODE=full → Traefik speaks HTTPS to FrankenPHP)
  v
php service replica(s)
  | (FrankenPHP worker mode if configured)
  v
Symfony 7 application
  |
  v (writes)
Named volumes: storage_private, storage_public, storage_sessions, storage_logs
```

### install.sh Execution Flow

```
spin new symfony [project-name]
  |
  v
install.sh starts
  | 1. prompt_php_version()   → sets SPIN_PHP_VERSION
  | 2. prompt_php_os()        → sets SPIN_PHP_OS (debian/alpine)
  | 3. assemble_php_docker_image() → builds SPIN_PHP_DOCKER_BASE_IMAGE tag
  | 4. prompt SERVER_CONTACT email
  v
new() called (SPIN_ACTION=new)
  | - docker pull installer image
  | - docker run composer create-project symfony/skeleton [name]
  | - calls init --force
  v
Template files copied to project directory
  v
post-install.sh runs
  | - line_in_file replaces FROM serversideup/... with chosen image tag
  | - patches changeme@example.com in traefik/prod/traefik.yml
  | - patches changeme@example.com in .spin.yml
  | - git init
  v
User has working project
```

### Key Data Flows

1. **Image tag assembly:** `SPIN_PHP_VERSION` + `SPIN_PHP_OS` → `SPIN_PHP_DOCKER_BASE_IMAGE` string (e.g., `serversideup/php:8.4-frankenphp-alpine`) → written into Dockerfile `FROM` line by `post-install.sh`.
2. **UID/GID passthrough:** `SPIN_USER_ID` and `SPIN_GROUP_ID` (set by Spin CLI from host OS) → Dockerfile `ARG` → `docker-php-serversideup-set-id` remaps `www-data` to match host user → bind-mounted files are writable without `sudo`.
3. **Traefik discovery:** FrankenPHP container declares routing labels → Traefik Docker/Swarm provider reads socket → routes added dynamically, no restart needed.
4. **SSL flow (dev):** Self-signed `local-dev.pem` mounted into Traefik → `traefik-certs.yml` registers as default TLS cert → browser hits HTTPS via Traefik → Traefik forwards HTTP to FrankenPHP on port 8080.
5. **SSL flow (prod):** Traefik uses ACME httpChallenge → obtains Let's Encrypt cert → stores in `certificates` named volume → forwards HTTPS to FrankenPHP on port 8443 with `SSL_MODE=full`.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single developer | Default template as-is — single Swarm replica, SQLite acceptable |
| Small team / staging | Add `replicas: 2+` in prod compose, use PostgreSQL/MySQL service (user adds themselves) |
| High traffic | Enable FrankenPHP worker mode, tune `FRANKENPHP_CONFIG` worker count, add external DB, Redis for sessions |

### Scaling Priorities

1. **First bottleneck:** PHP bootstrap overhead on each request — solved by enabling FrankenPHP worker mode (`FRANKENPHP_CONFIG=worker ./public/index.php`).
2. **Second bottleneck:** Named volume I/O for sessions/logs on Swarm — move sessions to Redis, centralize logging to stdout/external service.

## Anti-Patterns

### Anti-Pattern 1: Using `SSL_MODE=full` in Development

**What people do:** Copy prod compose config to dev, or set `SSL_MODE=full` in dev.

**Why it's wrong:** FrankenPHP's internal Caddy SSL in `full` mode tries to use ACME or self-signed certs at the Caddy level. Traefik is already handling SSL termination in dev. Double-SSL causes connection errors and debugging pain.

**Do this instead:** Dev overlay keeps `SSL_MODE` unset (defaults to HTTP on 8080). Traefik handles the self-signed cert. The PHP container label uses `server.port=8080` and `server.scheme=http`.

### Anti-Pattern 2: Committing Runtime Data in `.infrastructure/volume_data/`

**What people do:** Accidentally `git add .infrastructure/` without checking the `.gitignore`, committing SQLite databases, log files, or uploaded assets.

**Why it's wrong:** Sensitive data in version control. Large binary files bloat repo history. Production secrets may leak.

**Do this instead:** Commit only the directory structure with a `.gitignore` that excludes all files except itself. The Laravel basic template does exactly this — `volume_data/.gitignore` contains exclusion rules.

### Anti-Pattern 3: Skipping the Symfony Runtime Package for Worker Mode

**What people do:** Set `FRANKENPHP_CONFIG="worker ./public/index.php"` without installing `runtime/frankenphp-symfony`.

**Why it's wrong:** Without the Symfony-specific FrankenPHP runtime bridge, worker mode may work initially but will not properly reset Symfony's kernel state between requests, leading to data leaking between requests (wrong user context, stale service instances).

**Do this instead:** `composer require runtime/frankenphp-symfony` and declare the runtime class in `composer.json`. This installs the runtime component that correctly handles kernel reset in worker mode.

### Anti-Pattern 4: Alpine OS with FrankenPHP

**What people do:** Choose Alpine for FrankenPHP to get smaller image sizes.

**Why it's wrong:** serversideup's own documentation warns of "known performance issues with FrankenPHP on Alpine." The FrankenPHP project documentation also notes Alpine may require stack size increases (`FRANKENPHP_CONFIG` environment variable workarounds).

**Do this instead:** Default to Debian for FrankenPHP. Alpine is appropriate for fpm-nginx and fpm-apache variations where the performance issues don't exist.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Traefik v3 | Reverse proxy via Docker/Swarm label discovery | Dev: Docker provider on Unix socket; Prod: Swarm provider on Unix socket (manager node only) |
| Let's Encrypt | ACME httpChallenge via Traefik's `certificatesResolvers` | Requires domain accessible on port 80; email contact configured by `install.sh` |
| Mailpit | Docker container on port 8025, dev-only | Dev email catcher; Symfony mailer DSN points to `mailpit:1025` |
| serversideup/php | Base Docker image providing FrankenPHP runtime | Image tag assembled from user's PHP version + OS choice during `install.sh` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Traefik ↔ php | HTTP on port 8080 (dev) / HTTPS on port 8443 (prod) | FrankenPHP listens on non-privileged ports; Traefik bridges external 80/443 |
| php ↔ Symfony app | In-process (FrankenPHP IS the app server) | No FastCGI socket or separate web server process — Caddy and PHP run in the same binary |
| install.sh ↔ post-install.sh | Environment variables (`SPIN_PHP_VERSION`, `SPIN_PHP_OS`, `SPIN_PHP_DOCKER_BASE_IMAGE`, `SERVER_CONTACT`, `SPIN_PROJECT_DIRECTORY`) | Spin CLI orchestrates execution order; variables must be exported |
| docker-compose.yml ↔ overlays | Docker Compose merge semantics (base keys overridden, new keys added) | Spin CLI merges files; template must not put ports in base to avoid prod conflicts |

## Build Order Implications

The component dependencies create a natural build sequence for the roadmap:

1. **`meta.yml`** — No dependencies. Start here; it unblocks Spin CLI discovery immediately.
2. **`install.sh`** — Depends only on knowing the FrankenPHP image naming scheme and PHP version ranges. Build this second; it gates everything else.
3. **`Dockerfile`** — Depends on knowing the `serversideup/php:*-frankenphp` base image tag format. Validated by running `docker build --target development`.
4. **`docker-compose.yml` + `docker-compose.dev.yml`** — Depends on Dockerfile stages being defined. Dev compose validates the full dev experience (Traefik, volumes, Mailpit).
5. **`.infrastructure/conf/traefik/`** — Depends on understanding port mapping (8080 dev / 8443 prod). Dev config depends on self-signed certs existing in the directory.
6. **`docker-compose.prod.yml`** — Depends on all of the above plus Swarm label knowledge. Validate with `docker stack deploy` smoke test.
7. **`post-install.sh`** — Depends on all template files existing. Validates the full `spin new symfony` flow end-to-end.

## Sources

- [serversideup/php FrankenPHP variation docs](https://serversideup.net/open-source/docker-php/docs/image-variations/frankenphp) — HIGH confidence
- [serversideup/php SSL configuration docs](https://serversideup.net/open-source/docker-php/docs/deployment-and-production/configuring-ssl) — HIGH confidence
- [serversideup/php choosing an image](https://serversideup.net/open-source/docker-php/docs/getting-started/choosing-an-image) — HIGH confidence
- [FrankenPHP worker mode docs](https://frankenphp.dev/docs/worker/) — HIGH confidence
- [FrankenPHP Symfony integration (fusonic.net)](https://www.fusonic.net/en/blog/frankenphp-symfony) — MEDIUM confidence (blog, but corroborated by official docs)
- [FrankenPHP production deployment](https://frankenphp.dev/docs/production/) — HIGH confidence
- Direct source inspection: `spin-template-laravel-basic` install.sh, post-install.sh, template/ files — HIGH confidence (primary source)
- Direct source inspection: `spin-template-skeleton` meta.yml, install.sh, template/ files — HIGH confidence (primary source)

---
*Architecture research for: Spin Template for Symfony 7 LTS with FrankenPHP*
*Researched: 2026-03-18*
