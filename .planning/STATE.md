---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: complete
stopped_at: Completed 04-02-PLAN.md
last_updated: "2026-03-19T19:47:23Z"
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 6
  completed_plans: 6
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Developers can run `spin new symfony` and get a working Symfony 7 LTS application with their choice of PHP runtime (FrankenPHP default, fpm-nginx, fpm-apache), Traefik, and production-ready Docker configuration in under a minute.
**Current focus:** Phase 04 — production-and-ship — COMPLETE

## Current Position

Phase: 04 (production-and-ship) — COMPLETE
Plan: 2 of 2 (all plans done)

## Performance Metrics

**Velocity:**

- Total plans completed: 3
- Average duration: ~7 min
- Total execution time: ~0.4 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-container-runtime | 1 | ~15 min | 15 min |
| 02-development-environment | 1 | 6 min | 6 min |

**Recent Trend:**

- Last 5 plans: 6 min (02-01)
- Trend: improving

*Updated after each plan completion*
| Phase 01-container-runtime P01 | ~15min | 2 tasks | 3 files |
| Phase 02-development-environment P01 | 6min | 2 tasks | 8 files |
| Phase 03-install-scripts P02 | 1min | 1 task | 1 file |
| Phase 03-install-scripts P01 | 3min | 2 tasks | 2 files |
| Phase 04-production-and-ship P01 | 2min | 2 tasks | 4 files |
| Phase 04-production-and-ship P02 | 2min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- FrankenPHP is the default runtime but not locked in — Dockerfile accepts `PHP_VARIATION` build arg (frankenphp, fpm-nginx, fpm-apache); install.sh prompts user to select
- FrankenPHP variation: Caddyfile must set `root * /var/www/html/public` and listen on 8080 internally only; Traefik labels use `port=8443` with `scheme=https` and `SSL_MODE=full`
- fpm-nginx/fpm-apache variations: Traefik labels use `port=8080` with `scheme=http`; install.sh patches compose and labels accordingly (RT-03)
- No database included — template stays minimal, users add their own
- Follow Laravel basic template patterns — use as reference for Dockerfile stages, Compose overlays, and .infrastructure/ structure
- Default OS: Debian — Alpine causes musl stack-size crashes with FrankenPHP worker mode; emit warning if Alpine selected
- [Phase 01-container-runtime]: PHP_OS_SUFFIX ARG (not PHP_OS) for Alpine — Docker FROM cannot evaluate shell conditionals; empty string = Debian, -alpine = Alpine; patched by install.sh
- [Phase 01-container-runtime]: cache:warmup at container start via /etc/entrypoint.d/ hook — not at docker build time, avoids failures when Redis/database unavailable
- [Phase 01-container-runtime]: No Caddyfile/nginx.conf/apache.conf shipped — serversideup/php env vars (CADDY_SERVER_ROOT, NGINX_WEBROOT, APACHE_DOCUMENT_ROOT) set in compose files (Phase 2)
- [Phase 02-development-environment]: Dev compose labels use entrypoints=web (HTTP) not websecure — Traefik handles HTTPS at edge, PHP speaks HTTP on 8080
- [Phase 02-development-environment]: All three PHP variations use identical dev compose labels (port 8080, scheme http) — variation differences only matter for prod (Phase 4)
- [Phase 02-development-environment]: symfony_var named volume overlaid on var/ only — vendor/ stays in bind mount for IDE autocompletion
- [Phase 02-development-environment]: No mailpit or node services — minimal, unopinionated; README to document these as optional add-ons
- [Phase 03-install-scripts P02]: ARG patching uses --action replace (line prefix match) not --action exact — replace is correct for ARG lines
- [Phase 03-install-scripts P02]: Traefik prod config and .spin.yml email patching uses --ignore-missing — prod traefik.yml is Phase 4 deliverable, must add changeme@example.com placeholder then
- [Phase 03-install-scripts P02]: git init runs unconditionally (no SPIN_INSTALL_DEPENDENCIES guard) whenever .git absent
- [Phase 03-install-scripts P02]: Default SPIN_PHP_VARIATION fallback in post-install.sh is frankenphp (consistent with install.sh)
- [Phase 03-install-scripts P01]: FrankenPHP is default variation in install.sh (not fpm-nginx like Laravel) — divergence intentional per CONTEXT.md
- [Phase 03-install-scripts P01]: PHP_OS_SUFFIX exported as empty string (debian) or "-alpine" (alpine) from assemble_php_docker_image() for post-install.sh ARG patching
- [Phase 03-install-scripts P01]: new() mounts $(pwd) not $SPIN_PROJECT_DIRECTORY — avoids Docker creating dir as root before composer create-project runs
- [Phase 04-production-and-ship P01]: FrankenPHP defaults in prod compose use port=8443 and scheme=https — post-install.sh patches to port=8080 scheme=http for fpm-* variants
- [Phase 04-production-and-ship P01]: providers.swarm (not providers.docker) required for Docker Swarm mode service discovery in Traefik
- [Phase 04-production-and-ship P01]: Router/service name is 'symfony' (not 'my-php-app' from Laravel template)
- [Phase 04-production-and-ship P02]: APP_SECRET generation is unconditional and outside SPIN_INSTALL_DEPENDENCIES block — ensures spin init users also get a patched secret
- [Phase 04-production-and-ship P02]: .env.example ships APP_SECRET= empty; post-install.sh generates and patches real value at install time

### Pending Todos

None yet.

### Blockers/Concerns

None

## Session Continuity

Last session: 2026-03-19T19:47:23Z
Stopped at: Completed 04-02-PLAN.md
Resume file: none — all plans complete
