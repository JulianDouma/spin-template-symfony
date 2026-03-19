---
phase: 04-production-and-ship
plan: 01
subsystem: infra
tags: [docker-swarm, traefik, frankenphp, letsencrypt, acme, spin]

# Dependency graph
requires:
  - phase: 02-development-environment
    provides: base docker-compose.yml and dev overlay patterns
  - phase: 03-install-scripts
    provides: post-install.sh that patches changeme@example.com and FrankenPHP labels
provides:
  - Production Docker Swarm compose overlay with rolling updates and rollback
  - Traefik prod config with Let's Encrypt HTTP-01 ACME and Cloudflare IP trust
  - .spin.yml server configuration scaffold with email placeholder
affects: [post-install.sh patching, spin-deploy, production setup docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Swarm deploy.labels (not top-level labels) for Traefik service discovery in Swarm mode"
    - "SPIN_MD5_HASH_TRAEFIK_YML config name ensures Traefik config updates are detected"
    - "YAML anchors for Cloudflare IP trust lists (DRY across web/websecure entrypoints)"
    - "changeme@example.com placeholder contract for post-install.sh line_in_file patching"

key-files:
  created:
    - template/docker-compose.prod.yml
    - template/.infrastructure/conf/traefik/prod/traefik.yml
    - template/.spin.yml
  modified:
    - template/.infrastructure/conf/traefik/prod/.gitignore (deleted - replaced by traefik.yml)

key-decisions:
  - "FrankenPHP defaults in prod compose: port=8443, scheme=https, SSL_MODE=full — post-install.sh patches to port=8080 scheme=http for fpm-* variants"
  - "Router and service name is 'symfony' (not 'my-php-app' from Laravel template)"
  - "providers.swarm (not providers.docker) required for Docker Swarm mode service discovery"
  - "Traefik ports use long-form mode: host syntax for Swarm ingress (not short-form)"

patterns-established:
  - "Prod compose overlay: extend base services, add Swarm deploy blocks, use deploy.labels for Traefik"
  - "Health check path /healthcheck matches HEALTHCHECK_PATH env var in same compose file"

requirements-completed: [PROD-01, PROD-02, PROD-03, PROD-04, PROD-05, PROD-06, PROD-07, TRAF-03, TRAF-04, SPIN-10]

# Metrics
duration: 2min
completed: 2026-03-19
---

# Phase 4 Plan 01: Production Infrastructure Summary

**Docker Swarm compose overlay with FrankenPHP HTTPS defaults, Traefik Let's Encrypt ACME over HTTP-01, and .spin.yml scaffold — all wired to post-install.sh placeholder contract**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-19T19:39:55Z
- **Completed:** 2026-03-19T19:41:55Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 deleted/replaced)

## Accomplishments

- Production Docker Swarm overlay with rolling-update deploy blocks, FrankenPHP-default Traefik labels (`port=8443`, `scheme=https`), health check at `/healthcheck`, named volumes `certificates` and `symfony_var`, and ACME-aware configs section
- Traefik prod config with `providers.swarm`, `insecureSkipVerify: true` for FrankenPHP internal TLS, HTTP-to-HTTPS redirect, all 22 Cloudflare IP ranges for forwarded header trust, and Let's Encrypt HTTP-01 resolver
- `.spin.yml` scaffold with `server_contact: changeme@example.com` placeholder, ready for post-install.sh patching to actual admin email at install time

## Task Commits

Each task was committed atomically:

1. **Task 1: Create docker-compose.prod.yml with Swarm deployment config** - `bbd19e4` (feat)
2. **Task 2: Create prod Traefik config and .spin.yml scaffold** - `6881452` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `template/docker-compose.prod.yml` - Production Swarm overlay extending base compose; Traefik host-mode ports, PHP with FrankenPHP defaults and rolling-update deploy block
- `template/.infrastructure/conf/traefik/prod/traefik.yml` - Traefik Swarm provider config with ACME, Cloudflare IP trust, HTTP-to-HTTPS redirect
- `template/.spin.yml` - Spin server config scaffold with email/users/servers/environments sections
- `template/.infrastructure/conf/traefik/prod/.gitignore` - Deleted (stub replaced by traefik.yml)

## Decisions Made

- FrankenPHP defaults in prod compose use `port=8443` and `scheme=https` with `SSL_MODE=full` — post-install.sh patches these to `port=8080` and `scheme=http` for fpm-nginx and fpm-apache variants
- Router/service name is `symfony` throughout (diverges from Laravel template's `my-php-app`)
- `providers.swarm` (not `providers.docker`) is required for Docker Swarm mode
- Traefik ports use long-form `mode: host` syntax, not short-form `"80:80"`, for proper Swarm ingress routing

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The `changeme@example.com` placeholder is patched at install time by post-install.sh.

## Next Phase Readiness

- All three production infrastructure files are in place
- post-install.sh email patching contract satisfied (`changeme@example.com` in both traefik.yml and .spin.yml)
- FrankenPHP label patching contract satisfied (port=8443, scheme=https in deploy.labels, ready for fpm-* override)
- Phase 04 Plan 02 can proceed (final integration, README, release)

---
*Phase: 04-production-and-ship*
*Completed: 2026-03-19*
