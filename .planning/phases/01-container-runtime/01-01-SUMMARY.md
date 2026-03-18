---
phase: 01-container-runtime
plan: 01
subsystem: infra
tags: [docker, dockerfile, serversideup-php, symfony, frankenphp, fpm-nginx, fpm-apache]

# Dependency graph
requires: []
provides:
  - Multi-stage Dockerfile (base, development, ci, deploy) using serversideup/php images
  - ARG-driven PHP version/variation/OS switching via PHP_VERSION, PHP_VARIATION, PHP_OS_SUFFIX
  - Symfony production build sequence in deploy stage (composer install, dump-autoload, dump-env, asset-map)
  - POSIX-compliant entrypoint cache warmup hook at container start
  - .dockerignore excluding vendor/, var/, tests/, node_modules/, and planning files
affects:
  - 02-compose (uses Dockerfile stages; compose env vars control document root and ports)
  - 03-install-scripts (install.sh patches PHP_VERSION/PHP_VARIATION/PHP_OS_SUFFIX ARGs)
  - 04-production (deploy stage is the production image)

# Tech tracking
tech-stack:
  added:
    - serversideup/php (base image; frankenphp default; fpm-nginx and fpm-apache supported)
    - install-php-extensions (mlocati; pre-installed in serversideup/php; commented-out block only)
  patterns:
    - Multi-stage Dockerfile with ARG-driven FROM for variation switching
    - Layer-cached composer install (lockfiles first, then COPY . .) to prevent code changes busting dependency layer
    - Entrypoint hook pattern (/etc/entrypoint.d/) for deferred startup actions requiring live services
    - POSIX sh shebang for Alpine compatibility in all startup scripts

key-files:
  created:
    - template/Dockerfile
    - template/.dockerignore
    - template/.infrastructure/entrypoint.d/10-cache-warmup.sh
  modified: []

key-decisions:
  - "PHP_OS_SUFFIX ARG (not PHP_OS) used for Alpine — Docker FROM only supports literal ARG interpolation, not shell conditionals; PHP_OS_SUFFIX defaults to empty string (Debian) and is set to -alpine by install.sh"
  - "cache:warmup runs at container start via /etc/entrypoint.d/ hook, not at docker build time — avoids failures when Redis/database unavailable during build"
  - "No Caddyfile, nginx.conf, or apache.conf shipped — serversideup/php env vars (CADDY_SERVER_ROOT, NGINX_WEBROOT, APACHE_DOCUMENT_ROOT) handle document root in compose"
  - "Xdebug excluded from all stages with explanatory comment — FrankenPHP worker mode incompatible with HTTP request debugging; fpm users can uncomment"

patterns-established:
  - "Pattern: ARG-before-FROM for multi-variation images — PHP_VERSION, PHP_VARIATION, PHP_OS_SUFFIX declared before first FROM"
  - "Pattern: COPY lockfiles first for layer caching — composer.json/composer.lock copied before COPY . . in deploy stage"
  - "Pattern: entrypoint.d hook with bin/console guard — cache warmup checks for Symfony before executing"

requirements-completed: [DOCK-01, DOCK-02, DOCK-03, DOCK-04, DOCK-05, RT-01, RT-02]

# Metrics
duration: 2min
completed: 2026-03-18
---

# Phase 1 Plan 1: Container Runtime — Dockerfile and Entrypoint Hook Summary

**Multi-stage Dockerfile for serversideup/php with ARG-driven variation switching and POSIX-sh entrypoint cache warmup hook**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-18T20:00:43Z
- **Completed:** 2026-03-18T20:02:52Z
- **Tasks:** 2
- **Files modified:** 3 created

## Accomplishments

- Four-stage Dockerfile (base, development, ci, deploy) using serversideup/php images with PHP_VERSION/PHP_VARIATION/PHP_OS_SUFFIX build args
- Symfony production build sequence in deploy stage: layer-cached composer install, dump-autoload --classmap-authoritative, dump-env prod, asset-map:compile (conditional)
- POSIX-compliant /bin/sh entrypoint cache warmup script with bin/console guard for Alpine and dev-container compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Dockerfile and .dockerignore** - `b416e26` (feat)
2. **Task 2: Create entrypoint cache warmup script** - `94ef5cd` (feat)

## Files Created/Modified

- `template/Dockerfile` - Multi-stage Dockerfile with base/development/ci/deploy stages; ARG-driven FROM for PHP variation switching; Symfony deploy sequence; commented extension block
- `template/.dockerignore` - Excludes vendor/, var/, tests/, node_modules/, .planning/, and other non-production files from build context
- `template/.infrastructure/entrypoint.d/10-cache-warmup.sh` - POSIX sh warmup script; runs cache:warmup --env=prod at container start if bin/console exists

## Decisions Made

- Used `PHP_OS_SUFFIX` (not `PHP_OS`) as the build arg for Alpine support. Docker's FROM line cannot evaluate shell conditionals — only literal ARG substitution is supported. An empty suffix means Debian (the default), and `-alpine` selects Alpine. The install.sh script (Phase 3) sets this based on user choice.
- Cache warmup deferred to container start time via entrypoint hook rather than `RUN` in deploy stage. During `docker build`, services like Redis and databases are unavailable; the entrypoint.d approach runs when services are reachable.
- No Caddyfile, nginx.conf, or apache.conf shipped in the template. serversideup/php images expose env vars (`CADDY_SERVER_ROOT`, `NGINX_WEBROOT`, `APACHE_DOCUMENT_ROOT`) that handle document root. These will be set in the compose files (Phase 2).

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Dockerfile is the foundational build artifact all later phases consume
- Phase 2 (compose) can now reference `--target development`, `--target ci`, and `--target deploy` stages
- Phase 3 (install scripts) has a clear patch point: the PHP_VERSION, PHP_VARIATION, PHP_OS_SUFFIX ARG defaults at the top of the Dockerfile
- No blockers for Phase 2 — compose files only need to reference the correct stage targets and set the serversideup/php env vars

---
*Phase: 01-container-runtime*
*Completed: 2026-03-18*
