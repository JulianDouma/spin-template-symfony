# Phase 1: Container Runtime - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Multi-stage Dockerfile and runtime configuration that builds and serves a Symfony 7 LTS application correctly across all supported PHP variations (frankenphp, fpm-nginx, fpm-apache). Covers all Dockerfile stages (base, development, ci, deploy) and health endpoint setup. Does NOT include compose files, Traefik config, or install scripts — those are later phases.

</domain>

<decisions>
## Implementation Decisions

### Dockerfile Structure
- Single Dockerfile with ARG interpolation: `FROM serversideup/php:${PHP_VERSION}-${PHP_VARIATION}` — one file for all variations
- Build args: `PHP_VERSION` (8.3/8.4/8.5), `PHP_VARIATION` (frankenphp/fpm-nginx/fpm-apache), `PHP_OS_SUFFIX` (empty string for debian, `-alpine` for alpine)
- Note: Docker `FROM` cannot evaluate shell conditionals, so the Dockerfile uses `PHP_OS_SUFFIX` (not `PHP_OS`) directly in the tag interpolation. The `install.sh` (Phase 3) is responsible for translating the user's OS choice into the correct suffix value (e.g., user picks "alpine" → install.sh sets `PHP_OS_SUFFIX=-alpine`)

### Deploy Stage (Production/Staging)
- Follow official Symfony deployment approach — no `cache:warmup` at build time (avoids DB/service connection failures during `docker build`)
- Layer-cached composer install: copy `composer.json`/`composer.lock` first, then `composer install --no-dev --no-autoloader --no-scripts --no-progress`
- After `COPY . .`: run `composer dump-autoload --classmap-authoritative --no-dev`, `composer dump-env prod`, `composer run-script --no-dev post-install-cmd`
- Conditional asset compilation: `if [ -f importmap.php ]; then php bin/console asset-map:compile; fi`
- Set `APP_ENV=prod` as build-time ENV
- Cache warmup happens at container start via entrypoint hook (serversideup/php supports `/etc/entrypoint.d/` scripts) — services are available at runtime, unlike during build
- File ownership: `COPY --chown=www-data:www-data`

### CI Stage
- Root user — sandboxed, short-lived CI environment, acceptable per POLP
- Minimal: `FROM base` + `USER root`, CI pipelines handle their own test deps

### Development Stage
- Non-root user (www-data) with `USER_ID`/`GROUP_ID` args for host permission matching — POLP for long-lived environment
- No Xdebug pre-installed — FrankenPHP worker mode is incompatible with Xdebug for HTTP debugging (only works for CLI commands). Commented-out block with note explaining the limitation
- Users on fpm-nginx/fpm-apache can uncomment and add Xdebug since those runtimes don't use persistent connections

### Health Endpoint
- Both Traefik health checks (via labels in compose) and Docker HEALTHCHECK (via compose healthcheck key) — full coverage for Swarm rolling deploys
- Use serversideup/php built-in `/healthcheck` endpoint (default, zero additional config)
- Each runtime variation uses its native health strategy (already handled by serversideup/php)
- No need to implement a custom health endpoint — serversideup/php provides this out of the box

### Runtime Configuration
- No custom Caddyfile, nginx.conf, or Apache config files shipped
- serversideup/php images are fully configurable via environment variables:
  - `CADDY_SERVER_ROOT` / `NGINX_WEBROOT` / `APACHE_DOCUMENT_ROOT` = `/var/www/html/public`
  - `CADDY_HTTP_PORT` / `APACHE_HTTP_PORT` = `8080`
  - `CADDY_HTTPS_PORT` / `APACHE_HTTPS_PORT` = `8443`
  - `SSL_MODE`, `PHP_OPCACHE_ENABLE`, `HEALTHCHECK_PATH`, etc.
- All runtime-specific config delegated to serversideup/php defaults + env vars in compose

### PHP Extensions
- Commented-out `install-php-extensions` block in Dockerfile (pattern from Laravel template)
- `install-php-extensions` (mlocati) is already pre-installed in serversideup/php images
- serversideup/php ships with: pdo_mysql, pdo_pgsql, redis, zip, opcache, pcntl, plus standard PHP extensions
- Users uncomment and add what they need (common Symfony additions: intl, bcmath, gd, imagick, amqp)

### Claude's Discretion
- Exact entrypoint script for cache warmup (`/etc/entrypoint.d/` hook)
- `.dockerignore` contents
- Exact commented extension examples in the install-php-extensions block

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spin Template Structure
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/Dockerfile` — Reference Dockerfile with multi-stage pattern (base, development, ci, deploy)
- `/Users/juliandouma/Developer/oss/spin/spin-template-skeleton/template/` — Skeleton template structure

### Symfony Deployment
- Official Symfony deployment docs: https://symfony.com/doc/current/deployment.html
- dunglas/symfony-docker Dockerfile pattern (composer install --no-dev, dump-autoload, dump-env prod)

### serversideup/php Images
- Environment variable specification: https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification
- Health checks: https://serversideup.net/open-source/docker-php/docs/guide/using-healthchecks-with-laravel
- Installing extensions: https://serversideup.net/open-source/docker-php/docs/customizing-the-image/installing-additional-php-extensions
- Adding startup scripts: https://serversideup.net/open-source/docker-php/docs/customizing-the-image/adding-your-own-start-up-scripts

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No existing code (greenfield project)

### Established Patterns
- Laravel basic template Dockerfile is the structural reference — same multi-stage pattern, adapted for Symfony
- serversideup/php env var naming conventions must be followed

### Integration Points
- Dockerfile is consumed by docker-compose.dev.yml (Phase 2) and docker-compose.prod.yml (Phase 4)
- Entrypoint hook for cache warmup is consumed at container start in all environments
- install.sh (Phase 3) patches the `FROM` line based on user's PHP version/variation/OS selection

</code_context>

<specifics>
## Specific Ideas

- POLP (Principle of Least Privilege): root only in sandboxed CI, www-data everywhere else
- Xdebug/FrankenPHP worker-mode incompatibility should be documented in a comment — developers on persistent-connection runtimes can only debug CLI operations
- The template should lean heavily on serversideup/php's built-in capabilities rather than reimplementing config

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-container-runtime*
*Context gathered: 2026-03-18*
