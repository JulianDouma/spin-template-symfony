# Stack Research

**Domain:** Docker template for Symfony 7 LTS with FrankenPHP runtime
**Researched:** 2026-03-18
**Confidence:** HIGH (all core claims verified against official docs and Docker Hub)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| serversideup/php (FrankenPHP) | `8.4-frankenphp` or `8.4-frankenphp-alpine` | PHP runtime Docker base image | Official images for this template category; runs as unprivileged `www-data` by default (unlike `dunglas/frankenphp` which runs as root); built-in health checks, SSL_MODE, and env-var-driven configuration that matches Spin's patterns |
| Symfony skeleton | `7.4.*` | Framework bootstrap via `composer create-project` | Symfony 7.4 is the current LTS (released Nov 2025, supported until Nov 2028 bugs / Nov 2029 security); requires PHP >=8.2; minimal deps — framework-bundle, dotenv, runtime, yaml, console |
| Traefik | `v3.6` | Reverse proxy for dev (self-signed SSL) and prod (Let's Encrypt) | Same version the reference `spin-template-laravel-basic` uses; v3 is the current stable series; v3.6.10 is latest patch as of March 2026 |
| Mailpit | `latest` (axllent/mailpit) | Local SMTP/email testing in dev | Same choice as the Laravel basic template; zero-config, web UI on port 8025 |
| Docker Compose | v2 syntax | Orchestration overlays (base / dev / prod) | Required by Spin's template conventions; base + dev + prod overlay pattern mirrors the reference template exactly |

### PHP Version Support Matrix

FrankenPHP requires PHP 8.3 or higher (confirmed in the Laravel basic `install.sh`). The install.sh for this template must offer only these PHP versions:

| PHP Version | serversideup/php Tag Pattern | Status |
|-------------|------------------------------|--------|
| 8.5 | `8.5-frankenphp`, `8.5-frankenphp-alpine` | Latest stable — default recommendation |
| 8.4 | `8.4-frankenphp`, `8.4-frankenphp-alpine` | Active support — safe choice |
| 8.3 | `8.3-frankenphp`, `8.3-frankenphp-alpine` | Active security support — minimum for FrankenPHP |

PHP 8.2 and below: not available in the FrankenPHP variant. Do not offer them.

### OS Variants

| OS | Tag Suffix | Debian Base | Notes |
|----|-----------|-------------|-------|
| Debian Bookworm (default) | _(no suffix — omit for debian)_ | Debian 12 | Larger image; broader package compatibility; recommended default |
| Alpine | `-alpine` | Alpine 3.21/3.22/3.23 | Smaller image; serversideup docs note performance issues have been reported with alpine FrankenPHP — prefer debian unless image size is critical |

Tag assembly logic (mirrors the reference `install.sh`):
- Debian: `serversideup/php:${PHP_VERSION}-frankenphp`
- Alpine: `serversideup/php:${PHP_VERSION}-frankenphp-alpine`

### Symfony Composer Packages

| Package | Install command | Purpose | Notes |
|---------|----------------|---------|-------|
| symfony/skeleton | `composer create-project symfony/skeleton:"7.4.*"` | Minimal application scaffold | Installs framework-bundle, console, dotenv, runtime, yaml — everything Spin needs to run |
| symfony/webapp (pack) | `composer require webapp` | Full web app extras | Adds twig, form, security, orm-pack, mailer, debug-pack; offer as optional prompt in install.sh |
| runtime/frankenphp-symfony | `composer require runtime/frankenphp-symfony` | FrankenPHP worker mode runtime | v1.0.0 released Dec 2025; still a separate package in Symfony 7.4 (built-in native support arrives in Symfony 8.0+); required for `APP_RUNTIME=Runtime\\FrankenPhpSymfony\\Runtime` env var |

### Docker Image: Installer vs Runtime

The reference template uses two separate images — an installer image and a runtime base image:

| Role | Tag | Used In |
|------|-----|---------|
| Installer (composer create-project) | `serversideup/php:${PHP_VERSION}-cli` | `install.sh` — runs composer in a throw-away container |
| Runtime base | `serversideup/php:${PHP_VERSION}-frankenphp[-alpine]` | `Dockerfile` FROM — all build stages |

Debian CLI installer tag omits the OS suffix (same convention as the Laravel template). Alpine CLI installer uses `-alpine` suffix.

### Supporting Infrastructure

| Component | Image / Version | Purpose |
|-----------|----------------|---------|
| Traefik (dev) | `traefik:v3.6` | Self-signed SSL termination; HTTP on 80, HTTPS on 443 |
| Traefik (prod) | `traefik:v3.6` (Swarm mode) | Let's Encrypt ACME; Docker Swarm configs |
| Mailpit | `axllent/mailpit:latest` | Dev SMTP trap; web UI port 8025 |

### Key Environment Variables (FrankenPHP-specific)

These differ from the fpm-nginx variation and must be configured in the Dockerfile / Compose files:

| Variable | Default | Usage in Template |
|----------|---------|-------------------|
| `SSL_MODE` | `off` | Set to `full` in prod Compose for Traefik passthrough HTTPS |
| `HEALTHCHECK_PATH` | `/healthcheck` | Set to a custom Symfony route (e.g. `/healthz`) in prod |
| `FRANKENPHP_CONFIG` | _(unset)_ | Optional: set to `worker ./public/index.php` to enable worker mode |
| `APP_RUNTIME` | _(unset)_ | Set to `Runtime\FrankenPhpSymfony\Runtime` to activate FrankenPHP Symfony runtime |
| `PHP_OPCACHE_ENABLE` | `0` | Set to `1` in prod Compose |
| `CADDY_SERVER_ROOT` | `/var/www/html/public` | Correct for Symfony — no change needed |
| `SERVER_NAME` | _(unset)_ | Set to domain in prod |

Traefik port for FrankenPHP: HTTP backend is `8080`, HTTPS backend is `8443` (differs from fpm-nginx which uses `8080` only). The prod Compose `loadbalancer.server.port` must be `8443` with `scheme=https`.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `serversideup/php:*-frankenphp` | `dunglas/frankenphp` (official image) | When you need official FrankenPHP images without serversideup conventions; not suitable here because Spin templates are built around serversideup image env-var API |
| `serversideup/php:*-frankenphp` | `serversideup/php:*-fpm-nginx` | When targeting PHP 8.2 or lower, or when FrankenPHP worker mode is not needed; this template is FrankenPHP-primary, but the Dockerfile could be adapted |
| `symfony/skeleton:"7.4.*"` | `symfony/skeleton:"6.4.*"` | When PHP 8.1 support is required; Symfony 6.4 LTS supported until Nov 2027 — a valid choice for older environments, but out of scope for this template |
| Debian base (default) | Alpine | When minimal image footprint is the top priority; serversideup docs warn of reported performance issues in Alpine FrankenPHP — test thoroughly before shipping as default |
| `traefik:v3.6` | `nginx-proxy` or Caddy standalone | When Swarm/Compose label-based routing is not needed; Traefik is the Spin ecosystem standard |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `symfony/website-skeleton` | Abandoned package; no longer maintained | `composer create-project symfony/skeleton:"7.4.*"` then `composer require webapp` |
| `dunglas/frankenphp` Docker image | Runs as root; no serversideup env-var API (SSL_MODE, HEALTHCHECK_PATH, etc.) | `serversideup/php:*-frankenphp` |
| PHP 8.2 or below with FrankenPHP variation | Not available as a serversideup FrankenPHP tag; PHP 8.2 is not a supported FrankenPHP base | PHP 8.3+ |
| `runtime/frankenphp-symfony` v0.x | Outdated; v1.0.0 released December 2025 is the current stable | `runtime/frankenphp-symfony:^1.0` |
| `traefik:latest` unpinned | Unexpected breaking changes on image pull; the reference template pins to `v3.6` | `traefik:v3.6` |
| `AUTORUN_ENABLED: "true"` (Laravel automation) | This is a Laravel-specific serversideup feature; it runs migrations automatically — no Symfony equivalent | Remove this env var; Symfony uses console commands explicitly |

---

## Stack Patterns by Variant

**If user selects Debian (default):**
- Installer image: `serversideup/php:${PHP_VERSION}-cli`
- Runtime image: `serversideup/php:${PHP_VERSION}-frankenphp`
- No OS suffix in either tag

**If user selects Alpine:**
- Installer image: `serversideup/php:${PHP_VERSION}-cli-alpine`
- Runtime image: `serversideup/php:${PHP_VERSION}-frankenphp-alpine`
- Add a warning in `install.sh` that alpine FrankenPHP has reported performance issues

**If user wants worker mode (post-install customization, not install.sh default):**
- Add `runtime/frankenphp-symfony` to composer deps
- Set `APP_RUNTIME=Runtime\FrankenPhpSymfony\Runtime` in `.env`
- Set `FRANKENPHP_CONFIG=worker ./public/index.php` in Compose environment
- Document in README; do not enable by default (adds complexity, needs Symfony kernel reset handling)

**If user selects webapp pack (optional install.sh prompt):**
- Run `composer require webapp` after skeleton install
- This adds: twig-bundle, orm-pack, form, security-bundle, validator, mailer, debug-pack
- Does not change the Docker configuration

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `serversideup/php:8.3-frankenphp` | Symfony 7.4 (requires PHP >=8.2) | Works; PHP 8.3 is minimum for FrankenPHP variation |
| `serversideup/php:8.4-frankenphp` | Symfony 7.4 (requires PHP >=8.2) | Recommended default — active PHP support, matches Packagist symfony/skeleton v7.4.99 which says `>=8.4` |
| `serversideup/php:8.5-frankenphp` | Symfony 7.4 | Latest PHP — use if project wants to stay on bleeding edge |
| `runtime/frankenphp-symfony:^1.0` | `symfony/runtime:^7.0` | Symfony 7.x compatible; included transitively via symfony/skeleton |
| `traefik:v3.6` | Docker Compose v2, Docker Swarm | Current stable; no known breaking issues with serversideup images |
| `symfony/skeleton:"7.4.*"` | `composer/composer:^2` | Requires symfony/flex ^2 (auto-installed) |

---

## Dockerfile Stage Pattern (mirrors Laravel basic)

```dockerfile
FROM serversideup/php:${PHP_VERSION}-frankenphp AS base

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

Key difference from the Laravel basic template: use `frankenphp` instead of `fpm-nginx-alpine`, and remove the SQLite volume `mkdir` (no database in this template).

---

## Sources

- Docker Hub API `serversideup/php` tags (verified 2026-03-18) — PHP 8.3/8.4/8.5 FrankenPHP tags confirmed HIGH confidence
- [serversideup/docker-php releases (GitHub)](https://github.com/serversideup/docker-php/releases) — latest release v4.3.3, FrankenPHP v1.11.3 — HIGH confidence
- [serversideup FrankenPHP image docs](https://serversideup.net/open-source/docker-php/docs/image-variations/frankenphp) — ports, env vars, SSL_MODE — HIGH confidence
- [serversideup choosing an image docs](https://serversideup.net/open-source/docker-php/docs/getting-started/choosing-an-image) — Debian vs Alpine tradeoff — HIGH confidence
- [Symfony releases page](https://symfony.com/releases) — Symfony 7.4 is current LTS, released Nov 2025, supported until Nov 2029 — HIGH confidence
- [Symfony 7.4 setup docs](https://symfony.com/doc/7.4/setup.html) — installation commands, PHP >=8.2 requirement — HIGH confidence
- [symfony/skeleton on Packagist](https://packagist.org/packages/symfony/skeleton) — v7.4.99 latest, deps list — HIGH confidence
- [runtime/frankenphp-symfony on Packagist](https://packagist.org/packages/runtime/frankenphp-symfony) — v1.0.0 released Dec 2025 — HIGH confidence
- [Traefik GitHub releases](https://github.com/traefik/traefik/releases) — v3.6.10 latest stable — MEDIUM confidence (via WebSearch)
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/` — reference template structure and conventions — HIGH confidence (local files)

---
*Stack research for: Spin Template Symfony (Docker template for Symfony 7 LTS with FrankenPHP)*
*Researched: 2026-03-18*
