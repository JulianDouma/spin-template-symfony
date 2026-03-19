---
phase: 04-production-and-ship
plan: 02
subsystem: infra
tags: [symfony, post-install, env, readme, traefik, frankenphp, spin, letsencrypt]

# Dependency graph
requires:
  - phase: 04-production-and-ship
    plan: 01
    provides: docker-compose.prod.yml with FrankenPHP default labels and .spin.yml scaffold
  - phase: 03-install-scripts
    provides: post-install.sh with line_in_file patching and SPIN_PHP_VARIATION variable
provides:
  - Prod compose label patching for fpm-nginx/fpm-apache runtimes in post-install.sh
  - Unconditional APP_SECRET generation via openssl rand -hex 16 in post-install.sh
  - template/.env.example with Symfony defaults and APP_SECRET placeholder
  - README.md with full install-to-deploy workflow documentation
affects: [spin-new, spin-init, spin-deploy, developer-onboarding]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "APP_SECRET generated unconditionally in post-install.sh (outside SPIN_INSTALL_DEPENDENCIES guard)"
    - "Prod label patching uses SPIN_PHP_VARIATION != frankenphp conditional — only patches fpm-* variants"
    - ".env.example ships APP_SECRET= empty; post-install.sh generates and patches real value at install time"

key-files:
  created:
    - template/.env.example
    - README.md
  modified:
    - post-install.sh

key-decisions:
  - "APP_SECRET generation is unconditional and outside SPIN_INSTALL_DEPENDENCIES block — ensures spin init users also get a patched secret"
  - "Prod label patching guards with [[ -f $project_dir/.env ]] — safe for init action where .env may not exist"
  - "README does not include Laravel-specific content (AUTORUN, artisan, SQLite volume) — Symfony-only"

patterns-established:
  - "post-install.sh extension pattern: add unconditional blocks after Dockerfile ARG patching, before SPIN_INSTALL_DEPENDENCIES"
  - ".env.example as placeholder contract: ship empty values that post-install.sh fills at install time"

requirements-completed: [DOC-01, DOC-02]

# Metrics
duration: 2min
completed: 2026-03-19
---

# Phase 4 Plan 02: Completion and Documentation Summary

**post-install.sh extended with prod Traefik label patching and unconditional APP_SECRET generation; .env.example and README complete the Symfony template for first-time use**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-19T19:44:55Z
- **Completed:** 2026-03-19T19:47:23Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- Extended `post-install.sh` with two new unconditional blocks: prod Traefik label patching (port=8080/scheme=http for fpm-nginx/fpm-apache) and APP_SECRET generation (`openssl rand -hex 16` patched into `.env` if present)
- Created `template/.env.example` with Symfony defaults: `APP_ENV=prod`, empty `APP_SECRET=` placeholder, `APP_URL=https://localhost`, commented DATABASE_URL examples for PostgreSQL/MySQL/SQLite, commented `MAILER_DSN=smtp://mailpit:1025`
- Created `README.md` covering full install-to-deploy workflow: `spin new symfony`, required changes (env.production, Let's Encrypt email), Symfony commands (bin/console, composer), Mailpit add-on section, advanced configuration (runtime switching, image name, Traefik MD5 hash)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend post-install.sh with prod label patching and APP_SECRET generation** - `e04bad8` (feat)
2. **Task 2: Create .env.example and README.md** - `eb112b7` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `post-install.sh` - Added prod compose label patching for fpm-* variants and unconditional APP_SECRET generation
- `template/.env.example` - Symfony environment variable template with APP_SECRET placeholder
- `README.md` - Full project documentation from install to deploy with Mailpit add-on section

## Decisions Made

- APP_SECRET generation is placed outside the `SPIN_INSTALL_DEPENDENCIES` conditional block so it runs for both `spin new` and `spin init` flows
- APP_SECRET block is guarded with `[[ -f "$project_dir/.env" ]]` to handle `spin init` on existing projects without Composer install
- README mirrors the Laravel basic template structure but excludes Laravel-specific sections (AUTORUN, artisan, SQLite volume) entirely

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The template is ready for `spin new symfony` and `spin deploy`.

## Next Phase Readiness

- All deliverables complete — this is the final plan in phase 04 and the final phase overall
- Template is fully shippable: install scripts, dev environment, prod infrastructure, documentation all in place
- `spin new symfony` will: install dependencies, patch Dockerfile ARGs, patch prod Traefik labels (for fpm-*), generate APP_SECRET, patch email placeholders, initialize git
- README enables a developer to go from zero to deployed following only the README

---
*Phase: 04-production-and-ship*
*Completed: 2026-03-19*
