---
phase: 03-install-scripts
plan: 02
subsystem: infra
tags: [bash, spin, post-install, dockerfile, composer, git, line_in_file]

# Dependency graph
requires:
  - phase: 03-install-scripts-plan-01
    provides: "install.sh that exports SPIN_PHP_VERSION, SPIN_PHP_VARIATION, PHP_OS_SUFFIX, SERVER_CONTACT"
  - phase: 01-container-runtime
    provides: "template/Dockerfile with ARG PHP_VERSION, ARG PHP_VARIATION, ARG PHP_OS_SUFFIX"
provides:
  - "post-install.sh that patches Dockerfile ARG defaults to user selections"
  - "serversideup/spin Composer dev dependency installation (both new and init action paths)"
  - "Traefik prod config and .spin.yml email patching with --ignore-missing"
  - "Git repository initialization if not already present"
affects: [04-production-environment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "line_in_file --action replace for Dockerfile ARG patching (prefix match, full-line replacement)"
    - "line_in_file --action exact --ignore-missing for files that may not exist yet (Phase 4 deliverables)"
    - "SPIN_INSTALL_DEPENDENCIES guard wrapping all docker pull/run/compose calls"
    - "SPIN_ACTION branch: docker compose run for init, docker run for new"

key-files:
  created:
    - "post-install.sh"
  modified: []

key-decisions:
  - "Default SPIN_PHP_VARIATION in post-install.sh is frankenphp (not fpm-nginx, matching install.sh)"
  - "Prod Traefik config email patching uses --ignore-missing since traefik.yml is a Phase 4 deliverable"
  - "ARG patching uses --action replace (line prefix match) not --action exact (substring match) — correct for ARG lines"
  - "Git init is unconditional (no SPIN_INSTALL_DEPENDENCIES guard) — always runs if .git directory absent"

patterns-established:
  - "Pattern: post-install.sh variables section captures Spin injected vars with safe fallback defaults for standalone testing"
  - "Pattern: Dockerfile ARG defaults patched via line_in_file --action replace using ARG NAME= as prefix search"

requirements-completed: [SPIN-07, SPIN-08, RT-03]

# Metrics
duration: 1min
completed: 2026-03-18
---

# Phase 3 Plan 02: post-install.sh Summary

**post-install.sh using line_in_file to patch Dockerfile ARG defaults, install serversideup/spin via Docker (init=compose run, new=docker run), patch email placeholders with --ignore-missing, and git init**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-18T21:30:55Z
- **Completed:** 2026-03-18T21:31:49Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `post-install.sh` with valid bash syntax (bash -n passes)
- Implemented all 3 Dockerfile ARG patches using `line_in_file --action replace` (PHP_VERSION, PHP_VARIATION, PHP_OS_SUFFIX)
- Implemented `serversideup/spin --dev` Composer install with separate code paths for `init` (docker compose run) vs `new` (docker run)
- Implemented email placeholder patching for Traefik prod config and .spin.yml using `--ignore-missing`
- Implemented git repository initialization guard

## Task Commits

Each task was committed atomically:

1. **Task 1: Create post-install.sh with Dockerfile patching, Composer deps, and git init** - `3fd3769` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `post-install.sh` - Spin post-install hook: patches Dockerfile ARGs, installs Composer deps, patches email, initializes git

## Decisions Made

- Default `SPIN_PHP_VARIATION` fallback is `frankenphp` (consistent with install.sh default, unlike Laravel which uses `fpm-nginx`)
- `git init` does not require `SPIN_INSTALL_DEPENDENCIES=true` — it runs unconditionally when `.git` is absent
- `--ignore-missing` applied to both Traefik prod config (Phase 4 deliverable) and `.spin.yml` (fetched by spin, placeholder may not be present)
- No `SPIN_USER_TODOS` export — Symfony template has no todo system

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `post-install.sh` is complete and ready for integration testing with install.sh (Phase 3 Plan 01)
- Phase 4 must add `changeme@example.com` placeholder to `template/.infrastructure/conf/traefik/prod/traefik.yml` for email patching to take effect at install time
- Full `spin new symfony` integration test can validate end-to-end flow once both install.sh and post-install.sh are finalized

---
*Phase: 03-install-scripts*
*Completed: 2026-03-18*
