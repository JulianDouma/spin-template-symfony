---
phase: 03-install-scripts
plan: 01
subsystem: infra
tags: [bash, spin, meta.yml, install.sh, frankenphp, symfony, docker]

# Dependency graph
requires:
  - phase: 01-container-runtime
    provides: Dockerfile with ARG PHP_VERSION/PHP_VARIATION/PHP_OS_SUFFIX defaults to patch
  - phase: 02-development-environment
    provides: docker-compose.dev.yml confirming all variations use port 8080 + http in dev
provides:
  - meta.yml registering template for `spin new symfony` discovery
  - install.sh with interactive prompts (variation, version, OS, email) and dispatch
  - Exported variables SPIN_PROJECT_DIRECTORY, SPIN_PHP_VERSION, SPIN_PHP_VARIATION,
    SPIN_PHP_DOCKER_BASE_IMAGE, SPIN_PHP_DOCKER_INSTALLER_IMAGE, PHP_OS_SUFFIX, SERVER_CONTACT
  - new() and init() functions dispatched via $SPIN_ACTION
affects: [03-02-post-install, 04-prod-compose]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - install.sh sourced by Spin CLI — all exports flow into post-install.sh environment
    - FrankenPHP-first variation ordering (diverges from Laravel fpm-nginx default)
    - Alpine+FrankenPHP warning for musl thread stack-size crashes in worker mode
    - PHP_OS_SUFFIX exported as empty string (debian) or "-alpine" (alpine) for Dockerfile ARG patching

key-files:
  created:
    - meta.yml
    - install.sh
  modified: []

key-decisions:
  - "FrankenPHP is default variation (not fpm-nginx like Laravel) — matches CONTEXT.md decision"
  - "PHP_OS_SUFFIX computed and exported in assemble_php_docker_image() for post-install.sh ARG patching"
  - "new() mounts $(pwd) not $SPIN_PROJECT_DIRECTORY — avoids Docker creating dir as root before composer"
  - "spin_project_files includes var/ (Symfony cache/log dir) but not node_modules/yarn.lock/package-lock.json"
  - "database mention removed from destructive warning — Symfony template has no database"

patterns-established:
  - "Pattern: prompt order variation -> version -> OS -> email (matches Spin UX convention)"
  - "Pattern: export PHP_OS_SUFFIX as '' for debian, '-alpine' for alpine — maps to Dockerfile ARG"
  - "Pattern: FrankenPHP warning emitted after OS selection, before returning from prompt_php_os()"

requirements-completed: [SPIN-01, SPIN-02, SPIN-03, SPIN-04, SPIN-05, SPIN-06, SPIN-09]

# Metrics
duration: 3min
completed: 2026-03-18
---

# Phase 3 Plan 01: Install Scripts Summary

**meta.yml template registration and install.sh with FrankenPHP-first interactive prompts, PHP_OS_SUFFIX export, and symfony/skeleton:^7.4 new() dispatch**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-18T21:31:23Z
- **Completed:** 2026-03-18T21:34:10Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- meta.yml registers the template for `spin new symfony` discovery with title, author, description, repository, and issues URL
- install.sh implements all interactive prompts (variation with FrankenPHP default, PHP version 8.3-8.5, OS with Alpine+FrankenPHP warning, server contact email)
- install.sh exports all 7 required variables for post-install.sh: SPIN_PROJECT_DIRECTORY, SPIN_PHP_VERSION, SPIN_PHP_VARIATION, SPIN_PHP_DOCKER_BASE_IMAGE, SPIN_PHP_DOCKER_INSTALLER_IMAGE, PHP_OS_SUFFIX, SERVER_CONTACT
- new() and init() functions dispatched via $SPIN_ACTION with correct composer create-project $(pwd) mount

## Task Commits

Each task was committed atomically:

1. **Task 1: Create meta.yml template registration** - `3fd3769` (feat)
2. **Task 2: Create install.sh with prompts and dispatch** - `4858f5a` (feat)
3. **Fix: Remove database mention from destructive warning** - `972c878` (fix)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `meta.yml` - Template registration for spin new symfony discovery
- `install.sh` - Interactive prompts, assemble_php_docker_image, new()/init() dispatch

## Decisions Made

- FrankenPHP is the default variation (explicit divergence from Laravel's fpm-nginx default)
- PHP_OS_SUFFIX exported as empty string for debian, "-alpine" for alpine — maps directly to the Dockerfile ARG PHP_OS_SUFFIX line that post-install.sh patches
- new() mounts $(pwd) rather than $SPIN_PROJECT_DIRECTORY to avoid Docker creating the target directory as root before composer create-project runs
- spin_project_files includes var/ (Symfony cache/log directory) but excludes node_modules, yarn.lock, package-lock.json (no frontend tooling in template)
- Removed "database" mention from destructive action warning — Symfony template has no database

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed "database" mention from destructive warning**
- **Found during:** Task 2 (install.sh creation) — caught during overall verification
- **Issue:** `display_destructive_action_warning()` said "backups of your files and database" but the plan spec explicitly states "No mention of node or database" for Symfony template
- **Fix:** Changed to "backups of your files" only
- **Files modified:** install.sh
- **Verification:** `grep -qi "database" install.sh` returns nothing
- **Committed in:** `972c878` (fix commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Minor text correction, no scope creep.

## Issues Encountered

None — plan executed cleanly with one small text correction caught during verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- meta.yml and install.sh are complete and passing all verification checks
- post-install.sh (Plan 02) can now consume all 7 exported variables: SPIN_PHP_VERSION, SPIN_PHP_VARIATION, PHP_OS_SUFFIX, SPIN_PHP_DOCKER_BASE_IMAGE, SPIN_PHP_DOCKER_INSTALLER_IMAGE, SPIN_PROJECT_DIRECTORY, SERVER_CONTACT
- Dockerfile ARG patching targets confirmed: ARG PHP_VERSION="8.3", ARG PHP_VARIATION="frankenphp", ARG PHP_OS_SUFFIX=""

---
*Phase: 03-install-scripts*
*Completed: 2026-03-18*
