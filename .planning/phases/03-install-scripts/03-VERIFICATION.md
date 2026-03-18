---
phase: 03-install-scripts
verified: 2026-03-18T21:46:00Z
status: human_needed
score: 4/4 automated must-haves verified
human_verification:
  - test: "Run `spin new symfony test-app` end-to-end"
    expected: "Prompts appear for variation, version, OS, and email. After completion, `test-app/` exists with symfony/skeleton installed, vendor/, symfony.lock, and a git repository present."
    why_human: "Requires Spin CLI, Docker daemon, and interactive terminal. Exercises the full install.sh + post-install.sh chain with real Docker pulls and composer create-project."
  - test: "Select fpm-nginx during `spin new symfony` and verify Dockerfile ARG"
    expected: "`ARG PHP_VARIATION=\"fpm-nginx\"` appears in the generated project's Dockerfile (not frankenphp). PHP_OS_SUFFIX is empty string for debian or -alpine for alpine."
    why_human: "Verifies that post-install.sh's line_in_file --action replace actually patches the ARG lines correctly when a non-default variation is chosen."
  - test: "Run `spin init` on an existing project directory"
    expected: "init() runs (shows destructive warning, prompts y/N), does NOT run composer create-project. Only cleans spin_project_files and skips skeleton install."
    why_human: "Verifies SPIN_ACTION dispatch correctly routes to init() and that the SPIN_ACTION != 'new' guard inside init() prevents double-execution."
  - test: "Select Alpine + FrankenPHP during OS prompt"
    expected: "Warning about musl libc thread stack size appears immediately after Alpine selection (before the email prompt). PHP_OS_SUFFIX exported as '-alpine'."
    why_human: "Verifies the post-selection warning block fires for the frankenphp+alpine combination specifically and not for other combos."
---

# Phase 3: Install Scripts Verification Report

**Phase Goal:** Running `spin new symfony` interactively configures and bootstraps a Symfony 7 LTS project from the template, including PHP version, runtime variation, and OS selection
**Verified:** 2026-03-18T21:46:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | `meta.yml` registers the template so `spin new symfony` discovers it | VERIFIED | `meta.yml` at repo root, `title: Symfony Basic Template`, `description` mentions `spin new symfony`, correct author and repository URLs |
| 2  | `install.sh` prompts for PHP variation with frankenphp as default | VERIFIED | `prompt_php_variation()` sets default `[[ -z "$SPIN_PHP_VARIATION" ]] && SPIN_PHP_VARIATION="frankenphp"`, variations array is `("frankenphp" "fpm-nginx" "fpm-apache")` — FrankenPHP first |
| 3  | `install.sh` prompts for PHP version (8.3, 8.4, 8.5) filtered by variation | VERIFIED | `prompt_php_version()` uses `php_versions=("8.5" "8.4" "8.3")` with FrankenPHP filter note displayed. No 8.2/8.1/8.0 options. |
| 4  | `install.sh` prompts for OS (debian default, alpine with FrankenPHP warning) | VERIFIED | `prompt_php_os()` defaults debian, and Alpine+FrankenPHP warning block fires with 2s sleep after selection |
| 5  | `install.sh` prompts for server contact email with validation | VERIFIED | `SERVER_CONTACT=$(prompt_and_update_file --validate "email")` in main execution block |
| 6  | `install.sh` exports SPIN_PROJECT_DIRECTORY, SPIN_PHP_VERSION, SPIN_PHP_VARIATION, SPIN_PHP_DOCKER_BASE_IMAGE, SPIN_PHP_DOCKER_INSTALLER_IMAGE, PHP_OS_SUFFIX, SERVER_CONTACT | VERIFIED | All 7 exports confirmed: SPIN_PROJECT_DIRECTORY (line 44), SPIN_PHP_VERSION (line 229), SPIN_PHP_VARIATION (line 177), SPIN_PHP_DOCKER_BASE_IMAGE (lines 303/307), SPIN_PHP_DOCKER_INSTALLER_IMAGE (lines 302/306), PHP_OS_SUFFIX (line 309), SERVER_CONTACT (line 382) |
| 7  | `new()` creates project directory via Docker and calls `init --force` | VERIFIED | `new()` runs `docker run ... composer create-project symfony/skeleton:"^7.4"` mounting `$(pwd)`, then calls `init --force` |
| 8  | `init()` warns about destructive action and cleans spin_project_files | VERIFIED | `init()` checks `SPIN_ACTION != "new"`, calls `display_destructive_action_warning()` when files exist, then loops `delete_matching_pattern` for each item in `spin_project_files` |
| 9  | `post-install.sh` patches Dockerfile ARG defaults to match user selection | VERIFIED | Three `line_in_file --action replace` calls for `ARG PHP_VERSION=`, `ARG PHP_VARIATION=`, `ARG PHP_OS_SUFFIX=` targeting `$project_dir/Dockerfile` |
| 10 | `post-install.sh` installs serversideup/spin as Composer dev dependency | VERIFIED | `composer require serversideup/spin --dev` in both the `init` path (docker compose run) and `new` path (docker run), guarded by `SPIN_INSTALL_DEPENDENCIES == "true"` |
| 11 | `post-install.sh` respects SPIN_INSTALL_DEPENDENCIES flag | VERIFIED | All docker pull/run/compose calls wrapped in `if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]` |
| 12 | `post-install.sh` initializes git repository if not already present | VERIFIED | `if [[ ! -d "$project_dir/.git" ]]; then initialize_git_repository; fi` at end of main |
| 13 | All template files reside in `template/` directory | VERIFIED | `template/` contains Dockerfile, docker-compose.yml, docker-compose.dev.yml, .dockerignore, .infrastructure/ tree |

**Score:** 13/13 truths verified (automated); 4 items require human testing for end-to-end confirmation

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `meta.yml` | Template registration with title, authors, description, repository | VERIFIED | 7 lines, all required fields present, `title: Symfony Basic Template` confirmed |
| `install.sh` | Interactive prompts and new/init dispatch, min_lines: 200 | VERIFIED | 395 lines, passes `bash -n`, all exports present |
| `post-install.sh` | Dockerfile patching, Composer deps, git init, min_lines: 80 | VERIFIED | 98 lines, passes `bash -n`, all line_in_file calls present |
| `template/Dockerfile` | ARG lines patchable by post-install.sh | VERIFIED | Lines 4/5/10 contain `ARG PHP_VERSION="8.3"`, `ARG PHP_VARIATION="frankenphp"`, `ARG PHP_OS_SUFFIX=""` — exact prefix matches used by post-install.sh |
| `template/` directory | All template files at this path | VERIFIED | Dockerfile, docker-compose.yml, docker-compose.dev.yml, .infrastructure/ tree |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `install.sh` | `post-install.sh` | exported shell variables | VERIFIED | `export SPIN_PHP_VERSION`, `export SPIN_PHP_VARIATION`, `export PHP_OS_SUFFIX`, `export SERVER_CONTACT` all present in install.sh |
| `install.sh` | spin CLI `action_init.sh` | SPIN_ACTION dispatch | VERIFIED | `if type "$SPIN_ACTION" &>/dev/null; then $SPIN_ACTION; fi` at line 388 — exact pattern required by Spin CLI |
| `post-install.sh` | `template/Dockerfile` | `line_in_file --action replace` | VERIFIED | Three replace calls use `'ARG PHP_VERSION='`, `'ARG PHP_VARIATION='`, `'ARG PHP_OS_SUFFIX='` as prefix patterns — match the exact lines in template/Dockerfile |
| `post-install.sh` | `template/.infrastructure/conf/traefik/prod/traefik.yml` | `line_in_file --action exact --ignore-missing` | VERIFIED (deferred) | `--ignore-missing` correctly applied; file is a Phase 4 deliverable — patching will activate when Phase 4 adds the file with `changeme@example.com` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SPIN-01 | 03-01-PLAN.md | `meta.yml` registers template with title, authors, description, repository URL | SATISFIED | `meta.yml` exists at repo root with all required fields |
| SPIN-02 | 03-01-PLAN.md | `install.sh` implements `new()` and `init()` functions dispatched via `$SPIN_ACTION` | SATISFIED | Both functions implemented, dispatch pattern at line 388 |
| SPIN-03 | 03-01-PLAN.md | `install.sh` prompts user for PHP version (8.3, 8.4, 8.5) | SATISFIED | `prompt_php_version()` with versions 8.5, 8.4, 8.3 — no older versions |
| SPIN-04 | 03-01-PLAN.md | `install.sh` prompts user for PHP variation (frankenphp default, fpm-nginx, fpm-apache) | SATISFIED | `prompt_php_variation()` with frankenphp first and as default |
| SPIN-05 | 03-01-PLAN.md | `install.sh` prompts user for OS choice (debian default, alpine with performance warning for FrankenPHP) | SATISFIED | `prompt_php_os()` with debian default and FrankenPHP+Alpine warning block |
| SPIN-06 | 03-01-PLAN.md | `install.sh` prompts for server contact email (for Let's Encrypt) | SATISFIED | `prompt_and_update_file --validate "email"` in main execution |
| SPIN-07 | 03-02-PLAN.md | `post-install.sh` installs Symfony 7 LTS skeleton via `composer create-project symfony/skeleton` | SATISFIED | `new()` in install.sh runs `composer create-project symfony/skeleton:"^7.4"` via Docker |
| SPIN-08 | 03-02-PLAN.md | `post-install.sh` installs Composer dependencies via Docker container | SATISFIED | All composer commands run inside Docker (docker run for new, docker compose run for init) — no host Composer required |
| SPIN-09 | 03-01-PLAN.md | All template files reside in `template/` directory | SATISFIED | `template/` contains Dockerfile, compose files, .infrastructure/ tree |
| RT-03 | 03-02-PLAN.md | `install.sh` patches Dockerfile, compose files, and Traefik labels based on selected runtime variation | PARTIAL — scoped by design | Dockerfile ARG patching is implemented (PHP_VERSION, PHP_VARIATION, PHP_OS_SUFFIX). Compose file and Traefik label patching intentionally deferred to Phase 4 — research explicitly justified this: all dev variations use port 8080+http, prod compose (where variation-specific labels differ) is a Phase 4 deliverable. REQUIREMENTS.md marks this as "Complete" but the requirement text overstates Phase 3 scope. |

**RT-03 Scope Note:** The REQUIREMENTS.md requirement text says "patches Dockerfile, compose files, and Traefik labels based on selected runtime variation (port, scheme, health path)." Phase 3 implements Dockerfile ARG patching. Compose file and Traefik label patching is not implemented in Phase 3 because:
1. The dev compose uses the same port (8080) and scheme (http) for all three variations by Phase 2 design decision — no per-variation patching is needed in dev.
2. Production compose (where FrankenPHP uses port 8443/https vs 8080/http for fpm-*) is a Phase 4 deliverable.
3. The Phase 3 RESEARCH.md explicitly documents: "RT-03 ('patches compose files based on runtime variation') is narrower than it sounds...prod compose variation-specific label patching...is deferred to Phase 4."

This is a justified and documented scope reduction, not an implementation gap. However, RT-03 in REQUIREMENTS.md should be updated to reflect that compose/label patching is split between Phase 3 (Dockerfile) and Phase 4 (prod compose labels).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `post-install.sh` | 89 | Comment containing "placeholder" | Info | In a comment only (`# fetched by spin, may not contain placeholder`). Not an implementation stub. No impact. |

No TODO/FIXME/HACK patterns found. No empty return stubs. No console.log-only implementations. No Laravel-specific contamination (node_modules, yarn, sqlite, mysql, redis, etc.) in either script.

### Human Verification Required

#### 1. Full `spin new symfony` End-to-End

**Test:** Run `spin new symfony test-app` in a temporary directory, complete all interactive prompts (select a non-default variation such as fpm-nginx, PHP 8.4, debian, and a valid email).
**Expected:** All four prompts appear in order (variation, version, OS, email). After completion: `test-app/` directory exists with the Symfony skeleton installed (`vendor/`, `symfony.lock`, `composer.json` present), a `.git` repository initialized, and `serversideup/spin` listed in `composer.json` dev dependencies.
**Why human:** Requires Spin CLI and Docker daemon. The full chain — Spin sourcing install.sh, user prompts, Docker composer create-project, Spin copying template files, Spin sourcing post-install.sh — cannot be verified by static file analysis.

#### 2. Dockerfile ARG Patching Verification

**Test:** After running `spin new symfony test-app` with fpm-nginx + PHP 8.4 + alpine selected, inspect `test-app/Dockerfile`.
**Expected:** Lines read `ARG PHP_VERSION="8.4"`, `ARG PHP_VARIATION="fpm-nginx"`, `ARG PHP_OS_SUFFIX="-alpine"`. The `FROM` line resolves to `serversideup/php:8.4-fpm-nginx-alpine AS base`.
**Why human:** `post-install.sh` uses `line_in_file` (a Spin utility not available standalone) — cannot dry-run the patching without Spin's sourced environment.

#### 3. `spin init` Does Not Re-Run Skeleton Install

**Test:** In an existing Symfony project directory, run `spin init`.
**Expected:** `init()` runs (shows the destructive warning, prompts y/N), then cleans spin_project_files. It does NOT run `composer create-project`. After proceeding, Spin copies fresh template files and `post-install.sh` re-installs Composer deps.
**Why human:** Requires Spin CLI to dispatch `SPIN_ACTION=init`, which cannot be simulated by static analysis.

#### 4. Alpine + FrankenPHP Warning

**Test:** During `spin new symfony`, select frankenphp, then select alpine for OS.
**Expected:** Immediately after the OS selection confirmation, a yellow WARNING block appears about musl libc thread stack size with a 2-second pause before continuing to the email prompt.
**Why human:** Requires interactive terminal to observe the timed warning output.

### Gaps Summary

No structural gaps found. All must-have truths are verified, all artifacts are substantive and wired correctly, and all key links connect properly. The one nuance is RT-03's partial scope — compose and Traefik label patching for production is intentionally deferred to Phase 4 and is documented in the research. This does not block the Phase 3 goal.

The phase goal — "Running `spin new symfony` interactively configures and bootstraps a Symfony 7 LTS project from the template" — is achievable from the code as written. Human verification is needed to confirm the end-to-end runtime behavior.

---

_Verified: 2026-03-18T21:46:00Z_
_Verifier: Claude (gsd-verifier)_
