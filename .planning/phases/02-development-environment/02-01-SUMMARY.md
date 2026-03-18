---
phase: 02-development-environment
plan: 01
subsystem: infra
tags: [traefik, docker-compose, ssl, self-signed-cert, frankenphp, named-volume]

# Dependency graph
requires:
  - phase: 01-container-runtime
    provides: Dockerfile with development stage, USER_ID/GROUP_ID build args, and serversideup/php base image

provides:
  - Traefik static config (traefik.yml) with Docker + file providers, exposedByDefault: false, dashboard enabled
  - Traefik dynamic cert config (traefik-certs.yml) pointing to local-dev.pem
  - Self-signed SSL certificate with SAN (DNS:localhost, IP:127.0.0.1), rsa:4096, 10-year expiry
  - Base docker-compose.yml: traefik:v3.6 image + php service with depends_on (minimal, no version: key)
  - Dev overlay docker-compose.dev.yml: Traefik on 80/443, php build target development, bind mount + symfony_var named volume overlay, development network, Traefik labels
  - .infrastructure/conf/traefik/prod/ and .infrastructure/volume_data/ stub directories

affects:
  - 03-install-script (uses docker-compose.dev.yml as base for patching PHP_VARIATION labels)
  - 04-production (adds docker-compose.prod.yml alongside these files)

# Tech tracking
tech-stack:
  added: [traefik:v3.6, openssl rsa:4096, docker-compose-v2-overlay-pattern]
  patterns:
    - Base compose (minimal) + dev overlay (full) Compose merge pattern
    - Named volume overlay on var/ to prevent macOS I/O performance degradation
    - Traefik v3 HostRegexp label syntax (not v2 catchall style)
    - Self-signed cert committed to repo (dev-only, not secrets)

key-files:
  created:
    - template/docker-compose.yml
    - template/docker-compose.dev.yml
    - template/.infrastructure/conf/traefik/dev/traefik.yml
    - template/.infrastructure/conf/traefik/dev/traefik-certs.yml
    - template/.infrastructure/conf/traefik/dev/certificates/local-dev.pem
    - template/.infrastructure/conf/traefik/dev/certificates/local-dev-key.pem
    - template/.infrastructure/conf/traefik/prod/.gitignore
    - template/.infrastructure/volume_data/.gitignore
  modified: []

key-decisions:
  - "Dev compose labels use entrypoints=web (HTTP) not websecure — Traefik handles HTTPS at edge, PHP speaks HTTP on 8080"
  - "CADDY_SERVER_ROOT set explicitly in dev compose (belt-and-suspenders even though serversideup/php default matches)"
  - "symfony_var named volume overlaid on var/ only — vendor/ stays in bind mount for IDE autocompletion"
  - "No mailpit or node services in dev compose — minimal, unopinionated per CONTEXT.md decision"
  - "Dev compose ships with FrankenPHP-compatible defaults (port 8080, scheme http) — all variations use identical dev labels"

patterns-established:
  - "Named volume overlay: bind mount .:/var/www/html/ first, then named volume on /var/www/html/var — order matters"
  - "Traefik v3 HostRegexp syntax: HostRegexp(`localhost`) not HostRegexp(`{catchall:.*}`)"
  - "Docker socket mounted :ro on Traefik — never read-write"

requirements-completed: [COMP-01, COMP-02, DEV-01, DEV-02, DEV-03, DEV-04, DEV-05, DEV-06, TRAF-01, TRAF-02, TRAF-05]

# Metrics
duration: 6min
completed: 2026-03-18
---

# Phase 02 Plan 01: Development Environment Summary

**Traefik v3 reverse proxy with self-signed SSL (SAN), named volume overlay on var/, and minimal base + dev overlay Docker Compose files for `spin up` local Symfony development**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-18T20:48:32Z
- **Completed:** 2026-03-18T20:55:01Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Traefik static + dynamic config with Docker provider (exposedByDefault: false), file provider for SSL, and dashboard enabled in dev
- Self-signed SSL certificate generated fresh with rsa:4096, 10-year expiry, and SAN (DNS:localhost, IP:127.0.0.1) — browser-compatible with no NET::ERR_CERT_COMMON_NAME_INVALID
- Base compose minimal (6 lines), dev overlay full with named volume overlay on var/, Traefik v3 labels, development network, and no deprecated patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Traefik configuration, SSL certificates, and .infrastructure stubs** - `51ec2be` (feat)
2. **Task 2: Create base and dev Docker Compose files** - `1c5036c` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `template/docker-compose.yml` - Minimal base: traefik:v3.6 image + php service with depends_on
- `template/docker-compose.dev.yml` - Dev overlay: Traefik on 80/443, php development build, bind mount + symfony_var named volume overlay, Traefik labels, development network
- `template/.infrastructure/conf/traefik/dev/traefik.yml` - Traefik static config with Docker + file providers, exposedByDefault: false, dashboard insecure
- `template/.infrastructure/conf/traefik/dev/traefik-certs.yml` - Dynamic cert config pointing to certificates/local-dev.pem
- `template/.infrastructure/conf/traefik/dev/certificates/local-dev.pem` - Self-signed SSL certificate with SAN for localhost
- `template/.infrastructure/conf/traefik/dev/certificates/local-dev-key.pem` - SSL private key (no passphrase, containerized)
- `template/.infrastructure/conf/traefik/prod/.gitignore` - Stub for Phase 4 production Traefik config directory
- `template/.infrastructure/volume_data/.gitignore` - Stub for runtime volume data directory

## Decisions Made

- Dev compose Traefik labels use `entrypoints=web` (HTTP on port 80), not `websecure` — Traefik terminates HTTPS at its edge and proxies to PHP's HTTP port 8080. PHP container never handles TLS in dev.
- `CADDY_SERVER_ROOT: /var/www/html/public` set explicitly in dev compose even though serversideup/php default matches — explicit is safer for a template users will fork.
- All three PHP variations (frankenphp, fpm-nginx, fpm-apache) use identical dev compose labels (port 8080, scheme http) — variation differences only matter for production (Phase 4).
- No mailpit or node services per CONTEXT.md locked decision — README will document these as optional add-ons.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None. Docker Compose validates cleanly (`docker compose config --quiet`) with expected warnings for SPIN_USER_ID/SPIN_GROUP_ID env vars (set by Spin CLI at runtime, not in compose file).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 03 (install.sh): All compose files ready for patching. `docker-compose.dev.yml` ships with FrankenPHP defaults; install.sh will patch CADDY_SERVER_ROOT/NGINX_WEBROOT/APACHE_DOCUMENT_ROOT and production labels based on user-selected PHP_VARIATION.
- Phase 04 (production): Traefik dev config established; prod config stub directory exists at `.infrastructure/conf/traefik/prod/`.
- `spin up` will start a working local Symfony environment with HTTPS via Traefik and live code editing via bind mount once a Symfony app is present in the template.

## Self-Check: PASSED

All 9 files confirmed present on disk. Both commits (51ec2be, 1c5036c) confirmed in git log.

---
*Phase: 02-development-environment*
*Completed: 2026-03-18*
