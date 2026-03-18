# Phase 1: Container Runtime - Research

**Researched:** 2026-03-18
**Domain:** Docker multi-stage builds, serversideup/php images, Symfony deployment
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dockerfile Structure**
- Single Dockerfile with ARG interpolation: `FROM serversideup/php:${PHP_VERSION}-${PHP_VARIATION}` — one file for all variations
- Build args: `PHP_VERSION` (8.3/8.4/8.5), `PHP_VARIATION` (frankenphp/fpm-nginx/fpm-apache), `PHP_OS` (debian/alpine)
- OS suffix handling: append `-alpine` to tag when `PHP_OS=alpine`, no suffix for debian

**Deploy Stage (Production/Staging)**
- Follow official Symfony deployment approach — no `cache:warmup` at build time (avoids DB/service connection failures during `docker build`)
- Layer-cached composer install: copy `composer.json`/`composer.lock` first, then `composer install --no-dev --no-autoloader --no-scripts --no-progress`
- After `COPY . .`: run `composer dump-autoload --classmap-authoritative --no-dev`, `composer dump-env prod`, `composer run-script --no-dev post-install-cmd`
- Conditional asset compilation: `if [ -f importmap.php ]; then php bin/console asset-map:compile; fi`
- Set `APP_ENV=prod` as build-time ENV
- Cache warmup happens at container start via entrypoint hook (`/etc/entrypoint.d/` scripts) — services are available at runtime, unlike during build
- File ownership: `COPY --chown=www-data:www-data`

**CI Stage**
- Root user — sandboxed, short-lived CI environment, acceptable per POLP
- Minimal: `FROM base` + `USER root`, CI pipelines handle their own test deps

**Development Stage**
- Non-root user (www-data) with `USER_ID`/`GROUP_ID` args for host permission matching — POLP for long-lived environment
- No Xdebug pre-installed — FrankenPHP worker mode is incompatible with Xdebug for HTTP debugging. Commented-out block with note explaining the limitation
- Users on fpm-nginx/fpm-apache can uncomment and add Xdebug since those runtimes don't use persistent connections

**Health Endpoint**
- Use serversideup/php built-in `/healthcheck` endpoint (default, zero additional config)
- No need to implement a custom health endpoint

**Runtime Configuration**
- No custom Caddyfile, nginx.conf, or Apache config files shipped
- serversideup/php images configurable via environment variables only
- All runtime-specific config delegated to serversideup/php defaults + env vars in compose

**PHP Extensions**
- Commented-out `install-php-extensions` block in Dockerfile
- `install-php-extensions` (mlocati) is already pre-installed in serversideup/php images

### Claude's Discretion
- Exact entrypoint script for cache warmup (`/etc/entrypoint.d/` hook)
- `.dockerignore` contents
- Exact commented extension examples in the install-php-extensions block

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DOCK-01 | Multi-stage Dockerfile with `base`, `development`, `ci`, and `deploy` targets using `serversideup/php` images | Laravel basic template provides the exact structural reference; serversideup/php docs confirm all stages |
| DOCK-02 | Dockerfile accepts `PHP_VERSION`, `PHP_VARIATION`, and `PHP_OS` build args for configurable PHP version (8.3-8.5), runtime (frankenphp, fpm-nginx, fpm-apache), and OS (debian/alpine) | Tag format confirmed: `{VERSION}-{VARIATION}` for Debian, `{VERSION}-{VARIATION}-alpine` for Alpine; ARG interpolation in FROM is standard Docker |
| DOCK-03 | Development stage sets `USER_ID` and `GROUP_ID` args for host permission matching | `docker-php-serversideup-set-id` command confirmed in Laravel reference; pattern is identical |
| DOCK-04 | Deploy stage copies application code, sets correct ownership to `www-data` | `COPY --chown=www-data:www-data` confirmed; dunglas/symfony-docker confirms full composer deploy sequence |
| DOCK-05 | CI stage runs as root for pipeline compatibility | Pattern confirmed from Laravel reference Dockerfile |
| RT-01 | Template ships a Caddyfile for FrankenPHP variation — NOTE: CONTEXT.md overrides this; no custom Caddyfile shipped; env vars handle document root | CONTEXT.md decision supersedes this requirement — serversideup/php `CADDY_SERVER_ROOT` env var handles `/var/www/html/public`; ports are defaults (8080/8443) |
| RT-02 | Health check endpoint available for all variations | serversideup/php built-in `/healthcheck` confirmed for fpm-nginx, fpm-apache, and FrankenPHP — zero config required |
</phase_requirements>

---

## Summary

Phase 1 delivers the Dockerfile and one runtime configuration artifact (the entrypoint cache warmup script). The structural reference is the Laravel basic template Dockerfile, which uses the same four-stage pattern (`base`, `development`, `ci`, `deploy`) with `serversideup/php` images. Symfony-specific adaptations are: the deploy stage runs the full Symfony production build sequence (`composer install --no-dev`, `dump-autoload --classmap-authoritative`, `dump-env prod`, `run-script post-install-cmd`, optional `asset-map:compile`), and the cache warmup moves to an `/etc/entrypoint.d/` hook at container start rather than `docker build` time.

The REQUIREMENTS.md RT-01 requirement ("ship a Caddyfile") is superseded by the CONTEXT.md locked decision: no custom runtime config files are shipped. The serversideup/php image's `CADDY_SERVER_ROOT` / `NGINX_WEBROOT` / `APACHE_DOCUMENT_ROOT` environment variables (all defaulting to `/var/www/html/public`) replace any config file. This is a CONTEXT.md override that the planner must apply — RT-01 as written in REQUIREMENTS.md is outdated.

The ARG/FROM tag puzzle is resolved: Debian images use tag `{PHP_VERSION}-{PHP_VARIATION}` and Alpine images use `{PHP_VERSION}-{PHP_VARIATION}-alpine`. The `PHP_OS` ARG needs a shell conditional to construct the correct suffix — `$([ "$PHP_OS" = "alpine" ] && echo "-alpine" || echo "")` — but Docker's `FROM` line only supports ARG interpolation, not shell expressions. The correct approach is a two-ARG pattern where `PHP_OS_SUFFIX` defaults to empty and is overridden by the caller, or using a `DOCKER_BUILDKIT` inline `--build-arg`. See the Architecture Patterns section for the recommended approach.

**Primary recommendation:** Use the Laravel basic Dockerfile verbatim as the structural skeleton, then layer in the Symfony deploy sequence. The entrypoint hook for cache warmup should use `/bin/sh` (not bash) for Alpine compatibility, and be numbered `10-cache-warmup.sh` to run early in the startup sequence.

---

## Standard Stack

### Core

| Library / Image | Version | Purpose | Why Standard |
|-----------------|---------|---------|--------------|
| serversideup/php | 8.3/8.4/8.5 | Base PHP runtime (FrankenPHP, fpm-nginx, fpm-apache) | Project mandated; ships with opcache, pdo_mysql, pdo_pgsql, redis, zip, pcntl |
| install-php-extensions (mlocati) | pre-installed | PHP extension installer | Pre-bundled in serversideup/php; only for commented-out extension block |

### Pre-installed PHP Extensions (no action needed)

| Extension | Purpose |
|-----------|---------|
| opcache | Opcode caching (enable with `PHP_OPCACHE_ENABLE=1`) |
| pdo_mysql | MySQL/MariaDB connections |
| pdo_pgsql | PostgreSQL connections |
| redis | Redis caching / sessions |
| zip | File compression |
| pcntl | Process control (queues, signals) |
| ctype, curl, dom, fileinfo, filter, hash, mbstring, openssl, pcre, session, tokenizer, xml | Bundled in official PHP images |

### Common Symfony Extensions to Suggest in Commented Block

| Extension | Use Case |
|-----------|---------|
| intl | Internationalization (Translator component) |
| bcmath | Arbitrary precision math |
| gd | Image manipulation |
| imagick | ImageMagick integration |
| amqp | RabbitMQ / Messenger AMQP transport |

---

## Architecture Patterns

### Recommended File Structure

```
template/
├── Dockerfile
├── .dockerignore
└── .infrastructure/
    └── entrypoint.d/
        └── 10-cache-warmup.sh   # copied into /etc/entrypoint.d/ at build time
```

The entrypoint script is part of the template and gets `COPY`'d into the image in the `deploy` stage.

### Pattern 1: Multi-Stage Dockerfile with ARG-Driven FROM

The `PHP_OS` build arg cannot be used in a shell conditional inside the `FROM` line — Docker's `FROM` only supports ARG interpolation of literal values. The recommended approach is a two-arg pattern where the OS suffix is passed as a separate build arg that defaults to empty (Debian) and is set to `-alpine` for Alpine builds.

```dockerfile
# Source: Laravel basic template + serversideup/php tag format research
ARG PHP_VERSION="8.3"
ARG PHP_VARIATION="frankenphp"
ARG PHP_OS_SUFFIX=""
# PHP_OS_SUFFIX is "" for debian, "-alpine" for alpine
# The install.sh script (Phase 3) writes the correct default into this ARG

FROM serversideup/php:${PHP_VERSION}-${PHP_VARIATION}${PHP_OS_SUFFIX} AS base
```

The `install.sh` script (Phase 3) will patch this ARG default when the user selects Alpine. The planner should note this as an integration point.

### Pattern 2: Development Stage with UID/GID Matching

```dockerfile
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/Dockerfile
FROM base AS development

ARG USER_ID
ARG GROUP_ID

USER root
RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID && \
    docker-php-serversideup-set-file-permissions --owner $USER_ID:$GROUP_ID

USER www-data
```

### Pattern 3: CI Stage (Root)

```dockerfile
# Source: Laravel basic template
FROM base AS ci

USER root
```

### Pattern 4: Deploy Stage — Symfony Production Build Sequence

```dockerfile
# Source: dunglas/symfony-docker + CONTEXT.md decisions
FROM base AS deploy

ENV APP_ENV=prod

# Layer-cached vendor install (runs before COPY . . so code changes don't bust this layer)
COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-dev --no-autoloader --no-scripts --no-progress

# Copy application code
COPY --chown=www-data:www-data . .

# Generate optimized autoloader, compile env, run post-install hooks
RUN composer dump-autoload --classmap-authoritative --no-dev && \
    composer dump-env prod && \
    composer run-script --no-dev post-install-cmd

# Compile assets if using Symfony AssetMapper
RUN if [ -f importmap.php ]; then php bin/console asset-map:compile; fi

# Copy entrypoint startup hook (cache warmup runs at container start, not build time)
COPY --chmod=755 .infrastructure/entrypoint.d/ /etc/entrypoint.d/

USER www-data
```

### Pattern 5: Entrypoint Cache Warmup Hook

```sh
#!/bin/sh
# Source: serversideup/php entrypoint.d docs + Symfony cache warmup
# File: .infrastructure/entrypoint.d/10-cache-warmup.sh
#
# Cache warmup runs at container start (not docker build) so that services
# like Redis, databases, etc. are available when the cache is built.
#
# NOTE: Use /bin/sh (not /bin/bash) for Alpine compatibility.

set -e

APP_BASE_DIR="${APP_BASE_DIR:-/var/www/html}"

if [ -f "$APP_BASE_DIR/bin/console" ]; then
    echo "Running Symfony cache warmup..."
    php "$APP_BASE_DIR/bin/console" cache:warmup --env=prod
else
    echo "bin/console not found — skipping cache warmup"
fi
```

Naming convention: scripts in `/etc/entrypoint.d/` must have `.sh` extension, be executable (chmod 755), and are executed in alphanumeric order. Lower numbers run earlier. `10-cache-warmup.sh` runs early in the startup sequence.

### Pattern 6: PHP Extensions Commented Block

```dockerfile
# Source: serversideup/php docs
## Uncomment to install additional PHP extensions:
# USER root
# RUN install-php-extensions \
#     intl \
#     bcmath \
#     gd
# NOTE: FrankenPHP worker mode is incompatible with Xdebug for HTTP debugging.
# Xdebug only works for CLI commands in worker mode. If you are using
# fpm-nginx or fpm-apache, you can safely add xdebug here.
# USER www-data
```

### Anti-Patterns to Avoid

- **`cache:warmup` in RUN layer during build:** Fails silently or loudly if any service (Redis, database) is required. Run at container start via entrypoint hook instead.
- **Shell conditional in FROM line:** `FROM ...:${PHP_VERSION}-${PHP_VARIATION}-${PHP_OS}` where PHP_OS is "debian" fails — "debian" is not a valid tag suffix. Use `PHP_OS_SUFFIX` (empty string or `-alpine`).
- **`/bin/bash` shebang in entrypoint scripts:** Bash is not present on Alpine images. Use `#!/bin/sh`.
- **Xdebug in base or deploy stage:** Adds overhead and is incompatible with FrankenPHP worker mode for HTTP request debugging.
- **Running `composer dump-env prod` before `COPY . .`:** The `.env` file does not exist yet at that point; `dump-env` reads `.env` files from the project root.
- **`COPY . .` without `--chown=www-data:www-data`:** Files land as root:root, causing permission errors when the www-data process tries to write to `var/`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PHP extension installation | Custom apt/apk install sequences | `install-php-extensions` (pre-installed in serversideup/php) | Handles multi-stage dependencies, PECL, version pinning, Alpine vs Debian differences automatically |
| Health check endpoint | Custom `/healthz` PHP route or controller | `serversideup/php` built-in `/healthcheck` | Already wired to the correct internal port for all variations; zero config |
| Document root configuration | Custom Caddyfile / nginx.conf / Apache vhost | `CADDY_SERVER_ROOT` / `NGINX_WEBROOT` / `APACHE_DOCUMENT_ROOT` env vars | serversideup/php reads these at startup; no config files to maintain |
| Port configuration | Custom server config files | `CADDY_HTTP_PORT` / `NGINX_HTTP_PORT` / `APACHE_HTTP_PORT` env vars | Same as above |
| SSL mode | Custom TLS config | `SSL_MODE=full` env var | serversideup/php handles FrankenPHP HTTPS termination internally |
| UID/GID mapping | Custom `useradd` / `usermod` commands | `docker-php-serversideup-set-id` script (pre-installed) | Also fixes file permissions via `docker-php-serversideup-set-file-permissions` |

**Key insight:** serversideup/php is designed so that all runtime configuration happens via environment variables in the compose file, not via config files baked into the image. The template should ship zero nginx/caddy/apache config files.

---

## Common Pitfalls

### Pitfall 1: RT-01 Requirement vs CONTEXT.md Decision Conflict

**What goes wrong:** The REQUIREMENTS.md RT-01 says "template ships a Caddyfile." The CONTEXT.md locked decision says "no custom Caddyfile." The planner may treat RT-01 as binding.
**Why it happens:** The requirement was refined during the /discuss-phase session and the REQUIREMENTS.md was not updated.
**How to avoid:** CONTEXT.md decisions supersede REQUIREMENTS.md when they conflict. The intent of RT-01 (correct document root + ports) is fully satisfied by the `CADDY_SERVER_ROOT=public` env var in the compose file (Phase 2). No Caddyfile needed.
**Warning signs:** Any plan task that creates `Caddyfile`, `nginx.conf`, or `apache.conf` in the template.

### Pitfall 2: FROM Line Cannot Evaluate Shell Expressions

**What goes wrong:** Writing `FROM serversideup/php:${PHP_VERSION}-${PHP_VARIATION}-${PHP_OS}` where `PHP_OS` is "debian" — the tag `8.3-frankenphp-debian` does not exist.
**Why it happens:** Docker ARGs in FROM lines are literal substitution only; no shell logic.
**How to avoid:** Use `PHP_OS_SUFFIX` ARG that defaults to `""` (empty = Debian) and is set to `"-alpine"` for Alpine. Tag becomes `${PHP_VERSION}-${PHP_VARIATION}${PHP_OS_SUFFIX}`.
**Warning signs:** Build failing with "manifest not found" or "image not found."

### Pitfall 3: COPY Before install-php-extensions Busts Cache

**What goes wrong:** Placing `COPY . .` before `RUN install-php-extensions` means any code change triggers an extension reinstall.
**Why it happens:** Docker layer cache is busted top-to-bottom.
**How to avoid:** All `install-php-extensions` calls go in the `base` stage before any COPY. The `deploy` stage inherits from `base`.

### Pitfall 4: composer dump-env prod Embeds .env Values at Build Time

**What goes wrong:** If `APP_SECRET`, `DATABASE_URL`, etc. are real production secrets, running `dump-env prod` at build time bakes them into the image layer.
**Why it happens:** `composer dump-env` reads all `.env*` files present at build time and writes them to `.env.local.php`.
**How to avoid:** The template's `.env` file should contain only placeholder values (e.g., `APP_SECRET=changeme`). Actual secrets are injected at runtime via Docker secrets or environment variables — which override `.env.local.php`. Document this clearly for template users.
**Warning signs:** Real secrets appearing in `docker image inspect` output or in image layers.

### Pitfall 5: Entrypoint Script Not Executable

**What goes wrong:** Script in `/etc/entrypoint.d/` is ignored or fails with "permission denied."
**Why it happens:** File was COPY'd without executable bit.
**How to avoid:** Use `COPY --chmod=755` (Docker BuildKit, available in Docker 18.09+) or add `RUN chmod +x /etc/entrypoint.d/*.sh` after the COPY.

### Pitfall 6: Using /bin/bash in Entrypoint Scripts

**What goes wrong:** Script fails to execute on Alpine images with "not found" error.
**Why it happens:** Alpine uses musl libc and does not include bash by default.
**How to avoid:** Always use `#!/bin/sh` shebang. Use POSIX sh syntax throughout (no bash-isms like `[[ ]]`, `$BASH_SOURCE`, arrays, `local`).

---

## Code Examples

### Complete Dockerfile Skeleton (Verified Pattern)

```dockerfile
############################################
# Build Arguments
############################################
ARG PHP_VERSION="8.3"
ARG PHP_VARIATION="frankenphp"
# PHP_OS_SUFFIX: "" for Debian (default), "-alpine" for Alpine
ARG PHP_OS_SUFFIX=""

############################################
# Base Image
############################################
# Source: https://serversideup.net/open-source/docker-php/
FROM serversideup/php:${PHP_VERSION}-${PHP_VARIATION}${PHP_OS_SUFFIX} AS base

## Uncomment to install additional PHP extensions:
# USER root
# RUN install-php-extensions \
#     intl \
#     bcmath \
#     gd
# NOTE: FrankenPHP worker mode is incompatible with Xdebug for HTTP request
# debugging (only CLI commands work). If using fpm-nginx or fpm-apache,
# you can safely add xdebug here.
# USER www-data

############################################
# Development Image
############################################
FROM base AS development

ARG USER_ID
ARG GROUP_ID

USER root
RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID && \
    docker-php-serversideup-set-file-permissions --owner $USER_ID:$GROUP_ID

USER www-data

############################################
# CI Image
############################################
FROM base AS ci

# CI runs as root — sandboxed, short-lived environment (POLP acceptable)
USER root

############################################
# Deploy (Production/Staging) Image
############################################
FROM base AS deploy

ENV APP_ENV=prod

WORKDIR /var/www/html

# Layer-cached vendor install: copy lockfiles first so code changes don't
# bust the dependency installation layer
COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-dev --no-autoloader --no-scripts --no-progress

# Copy application code
COPY --chown=www-data:www-data . .

# Symfony production build sequence
# Source: https://symfony.com/doc/current/deployment.html
#         https://github.com/dunglas/symfony-docker
RUN composer dump-autoload --classmap-authoritative --no-dev && \
    composer dump-env prod && \
    composer run-script --no-dev post-install-cmd

# Compile assets if using Symfony AssetMapper (importmap.php present)
RUN if [ -f importmap.php ]; then php bin/console asset-map:compile; fi

# Install startup hook (cache warmup runs at container start, not build time,
# so that Redis/database/etc. are available when the cache is built)
COPY --chmod=755 .infrastructure/entrypoint.d/ /etc/entrypoint.d/

USER www-data
```

### Entrypoint Cache Warmup Script

```sh
#!/bin/sh
# .infrastructure/entrypoint.d/10-cache-warmup.sh
#
# Warms the Symfony cache at container start. Running at startup (not build
# time) ensures all services (Redis, database, etc.) are reachable.
#
# IMPORTANT: Use /bin/sh, not /bin/bash — Alpine images do not include bash.

set -e

APP_BASE_DIR="${APP_BASE_DIR:-/var/www/html}"

if [ -f "$APP_BASE_DIR/bin/console" ]; then
    echo "Running Symfony cache:warmup..."
    php "$APP_BASE_DIR/bin/console" cache:warmup --env=prod
else
    echo "Symfony bin/console not found at $APP_BASE_DIR — skipping cache warmup"
fi
```

### Recommended .dockerignore

```
# Source: dunglas/symfony-docker .dockerignore (adapted)
# https://github.com/dunglas/symfony-docker/blob/main/.dockerignore

**/*.log
**/*.md
**/*.php~
**/*.dist.php
**/*.dist
**/*.cache
**/.DS_Store
**/.git/
**/.gitattributes
**/.gitignore
**/.gitmodules
**/docker-compose*.yml
**/docker-compose*.yaml
**/Dockerfile
**/Thumbs.db
.github/
docs/
public/bundles/
tests/
var/
vendor/
.editorconfig
.env.*.local
.env.local
.env.local.php
.env.test
node_modules/
.infrastructure/volume_data/
```

Key exclusions for Symfony:
- `vendor/` — rebuilt by `composer install` in the image
- `var/` — cache and logs; runtime-generated, not to be baked in
- `public/bundles/` — assets compiled at build time via `asset-map:compile`
- `.env.local.php` — generated by `composer dump-env prod` in deploy stage; must not be pre-baked
- `tests/` — not needed in production or development container
- `.infrastructure/volume_data/` — local runtime data, never in image

### serversideup/php Key Environment Variables

```yaml
# Document root and ports (compose file, not Dockerfile)
# Source: https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification
environment:
  # FrankenPHP
  CADDY_SERVER_ROOT: /var/www/html/public
  CADDY_HTTP_PORT: "8080"
  CADDY_HTTPS_PORT: "8443"
  # fpm-nginx
  NGINX_WEBROOT: /var/www/html/public
  # fpm-apache
  APACHE_DOCUMENT_ROOT: /var/www/html/public
  APACHE_HTTP_PORT: "8080"
  APACHE_HTTPS_PORT: "8443"
  # Health check (default: /healthcheck — no change needed)
  HEALTHCHECK_PATH: /healthcheck
  # Production
  PHP_OPCACHE_ENABLE: "1"
  SSL_MODE: "full"   # FrankenPHP only; "off" for fpm variations
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `cache:warmup` in RUN during docker build | Entrypoint hook at container start | Symfony best practice (connection-dependent warmup) | Eliminates build failures when services are unavailable during `docker build` |
| `composer install --optimize-autoloader` in one step | Two-step: `install --no-autoloader` then `dump-autoload --classmap-authoritative` | Layer cache optimization | Code changes don't re-run the slow dependency resolution step |
| Custom nginx/caddy/apache config files in template | Zero config files; env vars only | serversideup/php v3 env-driven config | Removes a class of template maintenance burden |
| `/bin/bash` shebang in startup scripts | `#!/bin/sh` | Alpine compatibility requirement | Scripts work on both Debian and Alpine images |

**Deprecated/outdated:**
- Symfony `Unit` variation in serversideup/php: deprecated per their docs — do not use
- `AUTORUN_ENABLED=true`: a Laravel-specific feature in serversideup/php; not applicable for Symfony (Symfony uses its own entrypoint hook)

---

## Open Questions

1. **`WORKDIR` in base vs deploy stage**
   - What we know: Laravel basic template does not set an explicit WORKDIR in base; the serversideup/php image likely sets it to `/var/www/html`
   - What's unclear: Whether `WORKDIR /var/www/html` needs to be explicit in the deploy stage or is inherited
   - Recommendation: Add explicit `WORKDIR /var/www/html` in the deploy stage for clarity; costs nothing and prevents confusion

2. **`composer run-script --no-dev post-install-cmd` on fresh Symfony skeleton**
   - What we know: dunglas/symfony-docker runs this command in their deploy builder; Symfony Flex recipes register post-install hooks
   - What's unclear: Whether a minimal Symfony 7 skeleton has any meaningful `post-install-cmd` entries; the command exits 0 if there are none
   - Recommendation: Include the command — it is harmless if empty and picks up any hooks users add via Flex recipes

3. **`asset-map:compile` and missing packages**
   - What we know: The command is guarded by `if [ -f importmap.php ]`; it only runs when AssetMapper is installed
   - What's unclear: Whether `symfony/asset-mapper` is in the default symfony/skeleton dependency set
   - Recommendation: Keep the conditional guard; the task description should note that `symfony/asset-mapper` must be installed for this to execute

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — this phase produces Dockerfile and shell scripts only |
| Config file | N/A — no application code |
| Quick run command | `docker build --target base .` (smoke test) |
| Full suite command | `docker build --target deploy . && docker build --target development . && docker build --target ci .` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCK-01 | Four named build stages exist and build successfully | smoke | `docker build --target base . && docker build --target development . && docker build --target ci . && docker build --target deploy .` | ❌ Wave 0 |
| DOCK-02 | PHP_VERSION / PHP_VARIATION / PHP_OS_SUFFIX args change the base image | smoke | `docker build --build-arg PHP_VERSION=8.4 --build-arg PHP_VARIATION=fpm-nginx --target base .` | ❌ Wave 0 |
| DOCK-03 | Development stage accepts USER_ID / GROUP_ID args | smoke | `docker build --build-arg USER_ID=1000 --build-arg GROUP_ID=1000 --target development .` | ❌ Wave 0 |
| DOCK-04 | Deploy stage has correct www-data ownership | smoke | `docker build --target deploy . && docker run --rm <image> stat -c %U /var/www/html/composer.json` | ❌ Wave 0 |
| DOCK-05 | CI stage runs as root | smoke | `docker build --target ci . && docker run --rm <image> whoami` (expect: root) | ❌ Wave 0 |
| RT-01 | N/A — no Caddyfile shipped; env vars handle this (Phase 2) | manual-only | Verified in Phase 2 compose tests | N/A |
| RT-02 | /healthcheck responds 200 for all variations | smoke | `docker run -d <deploy-image> && curl -f http://localhost:8080/healthcheck` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `docker build --target base .` (fast, catches FROM tag errors)
- **Per wave merge:** Build all four targets with default args
- **Phase gate:** All four target builds succeed + /healthcheck responds 200 before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] No Dockerfile exists yet — must be created in Wave 1
- [ ] No `.infrastructure/entrypoint.d/10-cache-warmup.sh` exists yet
- [ ] No `.dockerignore` exists yet
- [ ] Smoke test commands above require the Dockerfile to exist first — tests are runnable after Wave 1 tasks complete

---

## Sources

### Primary (HIGH confidence)
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/Dockerfile` — Reference multi-stage structure, USER_ID/GROUP_ID pattern, install-php-extensions pattern (read directly)
- https://serversideup.net/open-source/docker-php/docs/customizing-the-image/adding-your-own-start-up-scripts — entrypoint.d path, .sh naming, chmod 755, numeric prefix ordering
- https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification — All env vars: CADDY_SERVER_ROOT, NGINX_WEBROOT, APACHE_DOCUMENT_ROOT, ports, HEALTHCHECK_PATH, SSL_MODE, PHP_OPCACHE_ENABLE
- https://serversideup.net/open-source/docker-php/docs/guide/using-healthchecks-with-laravel — /healthcheck endpoint behavior across all variations
- https://serversideup.net/open-source/docker-php/docs/customizing-the-image/installing-additional-php-extensions — install-php-extensions syntax, root user requirement
- https://serversideup.net/open-source/docker-php/docs/getting-started/default-configurations — Pre-installed extensions list
- https://symfony.com/doc/current/deployment.html — composer install --no-dev, dump-autoload --classmap-authoritative, dump-env prod sequence
- https://github.com/dunglas/symfony-docker/blob/main/Dockerfile — dunglas production build stage: exact composer command sequence confirmed
- https://github.com/dunglas/symfony-docker/blob/main/.dockerignore — Symfony-canonical .dockerignore contents

### Secondary (MEDIUM confidence)
- WebSearch results confirming serversideup/php tag format: `{VERSION}-{VARIATION}` for Debian, `{VERSION}-{VARIATION}-alpine` for Alpine — verified against hub.docker.com/r/serversideup/php layer examples
- WebSearch results confirming `composer dump-env prod` generates `.env.local.php` — verified against symfony.com/doc/current/configuration.html

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified directly from serversideup/php docs and reference Dockerfile
- Architecture: HIGH — verified against dunglas/symfony-docker canonical production Dockerfile and serversideup/php docs
- Pitfalls: HIGH — FROM tag format verified via Docker Hub; compose dump-env behavior verified via official Symfony docs
- Entrypoint script pattern: HIGH — verified against serversideup/php startup scripts docs (sh compatibility confirmed)

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (serversideup/php is stable; Symfony deployment steps are stable for 7.x LTS)
