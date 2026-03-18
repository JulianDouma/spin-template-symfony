# Phase 3: Install Scripts - Research

**Researched:** 2026-03-18
**Domain:** Spin template scripting — install.sh, post-install.sh, meta.yml
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Prompt order:** variation → version → OS → email (same as Laravel template for consistent Spin UX)
- **FrankenPHP as default variation** (Laravel defaults to fpm-nginx — we diverge here intentionally)
- **Alpine + FrankenPHP warning** shown when that combination is selected (musl stack-size issues with worker mode)
- **PHP versions:** 8.3, 8.4, 8.5 (FrankenPHP requires 8.3+)
- **Use Spin utility functions:** `prompt_and_update_file` for email, `show_header` adapted for Symfony branding
- `new()` and `init()` functions dispatched via `$SPIN_ACTION` (same pattern as Laravel)
- **Symfony skeleton installed via Docker:** `docker run serversideup/php:*-cli composer create-project symfony/skeleton` — no host Composer required
- **Install `serversideup/spin` as Composer dev dependency** (like Laravel template)
- **No PHP extensions prompt** — users edit the Dockerfile manually (simpler than Laravel)
- **No database/feature/JS package manager selection prompts** (no database, no frontend tooling)
- **Git repository initialized** if not already present
- **Patch server contact email** into Traefik prod config
- **Dockerfile patching strategy:** Patch ARG defaults, NOT the full FROM line — keeps ARG interpolation pattern intact
  - `ARG PHP_VERSION="8.3"` → `ARG PHP_VERSION="<user-selected>"`
  - `ARG PHP_VARIATION="frankenphp"` → `ARG PHP_VARIATION="<user-selected>"`
  - `ARG PHP_OS_SUFFIX=""` → `ARG PHP_OS_SUFFIX="-alpine"` or `""` (debian = empty string)
- **Traefik prod config:** patch `changeme@example.com` → `$SERVER_CONTACT`
- **Template identity:** name=`symfony`, title="Symfony Basic Template", author=Julian Douma (@JulianDouma), repo URL to be decided
- `show_header()` says: "Let's get Symfony launched!"
- `assemble_php_docker_image()` also patches `PHP_OS_SUFFIX` ARG (unlike Laravel which patches the full FROM line)

### Claude's Discretion

- Exact `show_header()` ASCII art / branding for Symfony
- Helper function structure (can mirror Laravel's `delete_matching_pattern`, `project_files_exist`, etc.)
- `spin_project_files` array contents (Symfony-specific files to track)
- Exact `assemble_php_docker_image()` implementation (translate OS choice to suffix)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SPIN-01 | `meta.yml` registers template with title, authors, description, and repository URL | meta.yml format confirmed from Laravel reference |
| SPIN-02 | `install.sh` implements `new()` and `init()` functions dispatched via `$SPIN_ACTION` | Dispatch pattern confirmed from spin `action_init.sh` and Laravel reference |
| SPIN-03 | `install.sh` prompts user for PHP version (8.3, 8.4, 8.5) | `prompt_php_version()` pattern confirmed; FrankenPHP filters to 8.3+ |
| SPIN-04 | `install.sh` prompts user for PHP variation (frankenphp default, fpm-nginx, fpm-apache) | `prompt_php_variation()` pattern confirmed; default must be flipped to frankenphp |
| SPIN-05 | `install.sh` prompts user for OS choice (debian default, alpine with performance warning) | `prompt_php_os()` pattern confirmed; warning message needed for alpine+frankenphp combo |
| SPIN-06 | `install.sh` prompts for server contact email (for Let's Encrypt) | `prompt_and_update_file` with `--output-only --validate email` confirmed |
| SPIN-07 | `post-install.sh` installs Symfony 7.4 LTS skeleton via `composer create-project symfony/skeleton:"^7.4"` | Docker run pattern confirmed; version constraint verified: `^7.4` |
| SPIN-08 | `post-install.sh` installs Composer dependencies via Docker container | Same `docker run` pattern as Laravel; `serversideup/spin --dev` confirmed |
| SPIN-09 | All template files reside in `template/` directory | Already satisfied by Phase 1+2 outputs |
| RT-03 | `install.sh` patches Dockerfile, compose files, and Traefik labels based on selected runtime variation | Confirmed: only Dockerfile ARG patching needed — compose uses env vars; prod compose labels handled in Phase 4 |
</phase_requirements>

---

## Summary

Phase 3 implements `install.sh`, `post-install.sh`, and `meta.yml` — the three files that make `spin new symfony` work interactively. The implementation follows the Laravel basic template pattern closely, with deliberate divergences: FrankenPHP is the default variation (not fpm-nginx), the PHP extension prompt is omitted, and Dockerfile patching targets ARG lines (not the full FROM line) because the Symfony Dockerfile uses ARG interpolation.

The Spin CLI executes `install.sh` by sourcing it (not fork/exec), which means all exported variables from `install.sh` are available in `post-install.sh`. Spin's built-in utilities — `line_in_file` and `prompt_and_update_file` — are defined in `~/.spin/lib/functions.sh` and are fully available in the sourced environment. The `action_init()` in spin copies template files, generates `.gitignore`/`.dockerignore` entries, and fetches `.spin.yml` automatically — `post-install.sh` only needs to handle Symfony-specific setup.

RT-03 ("patches compose files based on runtime variation") is narrower than it sounds: the dev compose already uses static port 8080 + http for all variations (Phase 2 decision). The install scripts only need to patch the Dockerfile ARG defaults. Prod compose variation-specific label patching (port 8443 for FrankenPHP, 8080 for fpm-*) is deferred to Phase 4 when the prod compose file is created.

**Primary recommendation:** Mirror the Laravel install.sh structure exactly but swap the default variation to `frankenphp`, remove all database/feature/extension prompts, and switch Dockerfile patching from `FROM serversideup` line replacement to `ARG PHP_VERSION` / `ARG PHP_VARIATION` / `ARG PHP_OS_SUFFIX` line replacement.

---

## Standard Stack

### Core — Spin-Provided Utilities (sourced, no installation needed)

| Utility | Source | Purpose | Notes |
|---------|--------|---------|-------|
| `line_in_file` | `~/.spin/lib/functions.sh:717` | File patching — ensure, replace, after, exact, delete, search modes | Supports multiple `--file` flags, `--ignore-missing`, `--action` |
| `prompt_and_update_file` | `~/.spin/lib/functions.sh:966` | Interactive prompt with optional file update | `--output-only` returns value to stdout; `--validate email` validates format |

### Supporting — External

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `symfony/skeleton` | `^7.4` (7.4 LTS) | Minimal Symfony project skeleton | Installed via `composer create-project` inside Docker |
| `serversideup/spin` | latest | Spin Composer package | Installed as `--dev` dependency after skeleton install |

### Symfony Skeleton Version Constraint

Symfony 7.4 is the current LTS (released November 2025), supported until November 2028 for bugs, November 2029 for security. The correct constraint is `"^7.4"`. Version `v7.4.99` (meta-version) is on Packagist.

```bash
composer create-project symfony/skeleton:"^7.4" my-project
```

Source: Packagist symfony/skeleton, Symfony releases page (verified 2026-03-18)

---

## Spin CLI Internals — Critical Knowledge

### How `spin new` and `spin init` Work

1. `spin new symfony my-app` → sets `SPIN_ACTION=new`, calls `action_init()`
2. `spin init symfony` → sets `SPIN_ACTION=init`, calls `action_init()`
3. `action_init()` (in `~/.spin/lib/actions/init.sh`):
   - Downloads/clones template repo to `SPIN_TEMPLATE_TEMPORARY_SRC_DIR` (a tmp dir)
   - **Sources** `install.sh` (not exec) — all exports remain in environment
   - Writes `.gitignore` entries: `.vault-password`, `.spin.yml`
   - Writes `.dockerignore` entries: `.vault-password`, `.github`, `.git`, `Dockerfile`, `docker-*.yml`, etc.
   - **Copies `template/` directory** to `$SPIN_PROJECT_DIRECTORY`
   - Fetches `.spin.yml` from ansible-collection-spin
   - **Sources** `post-install.sh` — receives all exports from install.sh

### Variables Spin Injects

| Variable | Set By | Value |
|----------|--------|-------|
| `SPIN_ACTION` | spin CLI | `"new"` or `"init"` |
| `SPIN_USER_ID` | spin CLI (default: `$(id -u)`) | Host user UID |
| `SPIN_GROUP_ID` | spin CLI (default: `$(id -g)`) | Host user GID |
| `SPIN_INSTALL_DEPENDENCIES` | spin CLI (default: `true`) | `"true"` or `"false"` — use `--no-install` flag to disable |
| `SPIN_TEMPLATE_TEMPORARY_SRC_DIR` | spin CLI | Absolute path to cloned template repo |
| `SPIN_PROJECT_DIRECTORY` | **install.sh MUST set and export this** | Absolute path to project directory |

**Critical:** `install.sh` is responsible for computing and exporting `SPIN_PROJECT_DIRECTORY`. If it's missing, `action_init()` exits with an error.

### Variables install.sh Must Export for post-install.sh

| Variable | Purpose |
|----------|---------|
| `SPIN_PROJECT_DIRECTORY` | Absolute path to where project is/will be |
| `SPIN_PHP_VERSION` | Selected PHP version string (e.g., `"8.5"`) |
| `SPIN_PHP_VARIATION` | Selected variation (e.g., `"frankenphp"`) |
| `SPIN_PHP_DOCKER_BASE_IMAGE` | Full image tag for base image |
| `SPIN_PHP_DOCKER_INSTALLER_IMAGE` | Full image tag for installer (CLI) image |
| `SERVER_CONTACT` | Email for Let's Encrypt (captured via `prompt_and_update_file --output-only`) |

**post-install.sh also has access to:** `SPIN_USER_ID`, `SPIN_GROUP_ID`, `SPIN_INSTALL_DEPENDENCIES`, `SPIN_TEMPLATE_TEMPORARY_SRC_DIR`

---

## Architecture Patterns

### File Layout

```
spin-template-symfony/
├── install.sh              # Prompts + new()/init() dispatch
├── post-install.sh         # Symfony install + Dockerfile patching + git init
├── meta.yml                # Template registration
└── template/               # Copied by spin to SPIN_PROJECT_DIRECTORY
    ├── Dockerfile
    ├── docker-compose.yml
    ├── docker-compose.dev.yml
    └── .infrastructure/
```

### Pattern 1: install.sh Structure

```bash
#!/bin/env bash
set -e

# 1. Capture args
symfony_framework_args=("$@")

# 2. Default image vars
SPIN_PHP_VERSION="${SPIN_PHP_VERSION:-8.5}"
SPIN_PHP_DOCKER_INSTALLER_IMAGE="${SPIN_PHP_DOCKER_INSTALLER_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-cli}"
SPIN_PHP_DOCKER_BASE_IMAGE="${SPIN_PHP_DOCKER_BASE_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-frankenphp}"

# 3. spin_project_files array (for init() cleanup)
declare -a spin_project_files=(...)

# 4. Compute SPIN_PROJECT_DIRECTORY (MUST be exported)
if [ "$SPIN_ACTION" == "new" ]; then
  symfony_project_directory=${symfony_framework_args[0]:-symfony}
  SPIN_PROJECT_DIRECTORY="$(pwd)/$symfony_project_directory"
elif [ "$SPIN_ACTION" == "init" ]; then
  SPIN_PROJECT_DIRECTORY="$(pwd)"
fi
export SPIN_PROJECT_DIRECTORY

# 5. Helper functions: delete_matching_pattern, project_files_exist, show_header,
#    prompt_php_variation, prompt_php_version, prompt_php_os, assemble_php_docker_image,
#    set_colors

# 6. new() and init() functions

# 7. Main: call prompts, then dispatch
set_colors
prompt_php_variation
prompt_php_version
prompt_php_os
assemble_php_docker_image

SERVER_CONTACT=$(prompt_and_update_file \
    --title "🤖 Server Contact" \
    --details "Set an email contact for Let's Encrypt SSL renewals and system alerts." \
    --prompt "Please enter your email" \
    --output-only \
    --validate "email")
export SERVER_CONTACT

if type "$SPIN_ACTION" &>/dev/null; then
  $SPIN_ACTION
else
  echo "The function '$SPIN_ACTION' does not exist."
  exit 1
fi
```

Source: Laravel install.sh reference read directly, cross-referenced with `action_init.sh`

### Pattern 2: Variation Default — FrankenPHP (Symfony divergence from Laravel)

```bash
prompt_php_variation() {
    local variations=("frankenphp" "fpm-nginx" "fpm-apache")
    # ...
    [[ -z "$SPIN_PHP_VARIATION" ]] && SPIN_PHP_VARIATION="frankenphp"  # Symfony default
```

### Pattern 3: Alpine + FrankenPHP Warning

```bash
prompt_php_os() {
    # After selection, before returning:
    if [[ "$SPIN_PHP_VARIATION" == "frankenphp" && "$SPIN_PHP_OS" == "alpine" ]]; then
        echo ""
        echo "${BOLD}${YELLOW}⚠️  Performance Warning:${RESET}"
        echo "Alpine Linux uses musl libc which has a smaller default thread stack size."
        echo "This can cause crashes in FrankenPHP worker mode."
        echo "Consider using Debian for FrankenPHP in production."
        echo ""
        sleep 2
    fi
```

### Pattern 4: assemble_php_docker_image() — Symfony Extension

The Symfony version must also patch `ARG PHP_OS_SUFFIX` in the Dockerfile (Laravel patches the whole FROM line — Symfony uses ARG interpolation instead):

```bash
assemble_php_docker_image() {
    if [[ "$SPIN_PHP_OS" == "debian" ]]; then
        PHP_OS_SUFFIX=""
        export SPIN_PHP_DOCKER_INSTALLER_IMAGE="serversideup/php:${SPIN_PHP_VERSION}-cli"
        export SPIN_PHP_DOCKER_BASE_IMAGE="serversideup/php:${SPIN_PHP_VERSION}-${SPIN_PHP_VARIATION}"
    else
        PHP_OS_SUFFIX="-alpine"
        export SPIN_PHP_DOCKER_INSTALLER_IMAGE="serversideup/php:${SPIN_PHP_VERSION}-cli-${SPIN_PHP_OS}"
        export SPIN_PHP_DOCKER_BASE_IMAGE="serversideup/php:${SPIN_PHP_VERSION}-${SPIN_PHP_VARIATION}-${SPIN_PHP_OS}"
    fi
    export PHP_OS_SUFFIX  # Used by post-install.sh to patch ARG PHP_OS_SUFFIX

    echo ""
    echo "${BOLD}${BLUE}📦 Docker Base Image:${RESET} $SPIN_PHP_DOCKER_BASE_IMAGE"
    echo ""
    sleep 1
}
```

### Pattern 5: post-install.sh Structure

```bash
#!/bin/bash

# 1. Capture Spin variables (with defaults for standalone testing)
SPIN_ACTION=${SPIN_ACTION:-"install"}
SPIN_PHP_VERSION="${SPIN_PHP_VERSION:-8.5}"
SPIN_PHP_VARIATION="${SPIN_PHP_VARIATION:-frankenphp}"
# ...

# 2. Local path vars
project_dir=${SPIN_PROJECT_DIRECTORY:-"$(pwd)/template"}
template_src_dir=${SPIN_TEMPLATE_TEMPORARY_SRC_DIR:-"$(pwd)"}
php_dockerfile="Dockerfile"

# 3. Functions: initialize_git_repository, etc.

# 4. Main:
#    a. Patch Dockerfile ARG lines
#    b. Install Symfony skeleton (new only)
#    c. Install Composer deps (serversideup/spin --dev)
#    d. Patch Traefik prod config email
#    e. Git init if needed
```

### Pattern 6: Dockerfile ARG Patching (Symfony-specific — NOT Laravel's FROM-line patch)

The Laravel template replaces the whole `FROM serversideup...` line. The Symfony template instead patches individual ARG lines to preserve the `${PHP_VERSION}-${PHP_VARIATION}${PHP_OS_SUFFIX}` interpolation:

```bash
# In post-install.sh — patch ARG defaults in Dockerfile
line_in_file --action replace \
    --file "$project_dir/$php_dockerfile" \
    'ARG PHP_VERSION=' \
    "ARG PHP_VERSION=\"${SPIN_PHP_VERSION}\""

line_in_file --action replace \
    --file "$project_dir/$php_dockerfile" \
    'ARG PHP_VARIATION=' \
    "ARG PHP_VARIATION=\"${SPIN_PHP_VARIATION}\""

line_in_file --action replace \
    --file "$project_dir/$php_dockerfile" \
    'ARG PHP_OS_SUFFIX=' \
    "ARG PHP_OS_SUFFIX=\"${PHP_OS_SUFFIX}\""
```

**Why `replace` and not `exact`:** `replace` matches lines that START WITH the search term (grep `^${search}`) and replaces the whole line. This is correct for ARG lines since the search term is the beginning of the line. `exact` does a literal substring match anywhere in the file.

### Pattern 7: Symfony Skeleton Installation (new() only)

```bash
new() {
    docker pull "$SPIN_PHP_DOCKER_INSTALLER_IMAGE"

    docker run --rm \
        -v "$(pwd):/var/www/html" \
        --user "${SPIN_USER_ID}:${SPIN_GROUP_ID}" \
        -e COMPOSER_CACHE_DIR=/dev/null \
        -e "SHOW_WELCOME_MESSAGE=false" \
        "$SPIN_PHP_DOCKER_INSTALLER_IMAGE" \
        composer --no-cache create-project \
            symfony/skeleton:"^7.4" \
            "${symfony_framework_args[@]}"

    init --force
}
```

**Note:** The project directory (`symfony_framework_args[0]`) is passed directly to `composer create-project` as the target directory. Composer creates it inside the mounted `/var/www/html`, which maps to `$(pwd)` on the host.

### Pattern 8: Traefik Email Patching

```bash
# prod traefik.yml will contain: changeme@example.com
# post-install.sh patches it with --ignore-missing since prod traefik.yml is Phase 4
line_in_file --action exact \
    --ignore-missing \
    --file "$project_dir/.infrastructure/conf/traefik/prod/traefik.yml" \
    "changeme@example.com" \
    "$SERVER_CONTACT"
```

**IMPORTANT:** The prod Traefik config is NOT yet in the template — it's a Phase 4 deliverable. The prod traefik directory currently only contains a `.gitignore` stub. Two approaches:
1. Phase 3 uses `--ignore-missing` (graceful no-op) — Phase 4 adds the file and patching happens at install time
2. Phase 4 pre-populates the placeholder and Phase 3 handles it

Given that `post-install.sh` runs AFTER `copy_template_files`, if the prod `traefik.yml` is added in Phase 4, Phase 3 should use `--ignore-missing`. When Phase 4 adds the file to `template/`, the email patching will work automatically at install time. Also patch `.spin.yml` which spin downloads — same pattern as Laravel template.

### Pattern 9: serversideup/spin Installation

For `new` action — use docker run with `$project_dir` mount (compose stack not yet up):

```bash
if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]; then
    docker pull "$SPIN_PHP_DOCKER_INSTALLER_IMAGE"

    if [[ "$SPIN_ACTION" == "init" ]]; then
        docker compose run --rm --no-deps --build \
            -e COMPOSER_CACHE_DIR=/dev/null \
            -e "SHOW_WELCOME_MESSAGE=false" \
            php \
            composer require serversideup/spin --dev
    else
        # new action — run standalone container
        docker run --rm \
            -v "$project_dir:/var/www/html" \
            --user "${SPIN_USER_ID}:${SPIN_GROUP_ID}" \
            -e COMPOSER_CACHE_DIR=/dev/null \
            -e "SHOW_WELCOME_MESSAGE=false" \
            "$SPIN_PHP_DOCKER_INSTALLER_IMAGE" \
            composer require serversideup/spin --dev
    fi
fi
```

### Pattern 10: meta.yml Format

```yaml
---
title: Symfony Basic Template
authors:
  - Julian Douma (@JulianDouma)
description: The Symfony Spin template when you run `spin new symfony` from CLI.
repository: https://github.com/JulianDouma/spin-template-symfony
issues: https://github.com/JulianDouma/spin-template-symfony/issues
```

Source: Laravel `meta.yml` read directly — confirmed format matches skeleton `meta.yml`

---

## `line_in_file` Full API Reference

Source: Read directly from `~/.spin/lib/functions.sh:717` (HIGH confidence)

```
line_in_file [--action ACTION] [--file FILE]... [--ignore-missing] ARG...
```

| Flag | Type | Description |
|------|------|-------------|
| `--file FILE` | Repeatable | File(s) to operate on. Created if missing. |
| `--action ACTION` | Optional | One of: `ensure`, `replace`, `after`, `exact`, `delete`, `search`. Default: `ensure` |
| `--ignore-missing` | Flag | On `exact` action: silently skip if search text not found (instead of error) |

| Action | Args | Behavior |
|--------|------|---------|
| `ensure` | 1+ strings | Appends each string to file IF it does not already exist (full-line grep -F match) |
| `replace` | search, replacement | Finds lines starting with `search` (grep `^search`), replaces whole line. If not found and replacement not already present, appends replacement. |
| `after` | search, insert | Inserts `insert` after line containing `search` (grep -F). If search not found, appends both. |
| `exact` | search, replacement | Replaces ALL occurrences of exact literal `search` with `replacement` (sed). Errors if not found, unless `--ignore-missing`. |
| `delete` | text | Deletes all lines containing `text`. Warns if not found. |
| `search` | text | Returns exit code 0 if `text` found, 1 if not. No file modification. |

**Key behavioral detail for `replace`:** The search term is matched as a line PREFIX using `grep -q -- "^${args[0]}"`. For ARG patching, search with `'ARG PHP_VERSION='` (the start of the line). The entire matched line is replaced.

**Key behavioral detail for `exact`:** Uses sed with full literal escaping of both search and replacement. Use this for `changeme@example.com` → email replacements where you want substring match.

---

## `prompt_and_update_file` Full API Reference

Source: Read directly from `~/.spin/lib/functions.sh:966` (HIGH confidence)

```
prompt_and_update_file --title TITLE [options...]
```

| Flag | Required | Description |
|------|----------|-------------|
| `--title TITLE` | YES | Bold blue heading displayed to user |
| `--details TEXT` | No | Additional description shown below title |
| `--prompt TEXT` | No | Prompt text (default: "Enter your response") |
| `--file FILE` | Yes (unless `--output-only`) | File to update. Repeatable. |
| `--search-default VALUE` | Yes (unless `--output-only`) | Placeholder text to find+replace in file; also shown as default value in prompt |
| `--success-msg TEXT` | No | Message shown on success (prefix "✅ " is added) |
| `--output-only` | No | Do NOT update any file; instead echo value to stdout. Used with `$()` capture. |
| `--validate TYPE` | No | Currently only `email` supported. Loops until valid input. |
| `--clear-screen` | No | `clear` before displaying prompt |

**All output except the captured value goes to stderr** — safe to capture with `VAR=$(prompt_and_update_file --output-only ...)`.

**When `--output-only` is used**, `--file` and `--search-default` are NOT required.

---

## RT-03: Runtime Variation Patching — What Actually Needs Patching

RT-03 states: "install.sh patches Dockerfile, compose files, and Traefik labels based on selected runtime variation."

**Actual scope after Phase 2 analysis:**

| What | Needs patching? | Reason |
|------|----------------|--------|
| Dockerfile ARG defaults | YES | `ARG PHP_VERSION`, `ARG PHP_VARIATION`, `ARG PHP_OS_SUFFIX` — hardcoded defaults need user selection |
| `docker-compose.yml` | NO | Base compose is minimal (only `image: traefik:v3.6`, `depends_on`), no variation-specific content |
| `docker-compose.dev.yml` | NO | Phase 2 decision: all variations use port 8080 + http in dev |
| Dev Traefik labels | NO | Same for all variations in dev |
| Prod compose labels | Out of scope Phase 3 | Prod compose file created in Phase 4; Phase 4 will handle FrankenPHP (port 8443, scheme=https) vs fpm-* (port 8080, scheme=http) |
| Traefik prod config email | YES | `changeme@example.com` → `$SERVER_CONTACT` (with `--ignore-missing` since file is Phase 4) |

**RT-03 is fully satisfied by ARG patching in post-install.sh.** No compose file patching is needed at install time.

---

## spin_project_files Array — Symfony-Appropriate Contents

For `init()` to clean up before re-initializing, include Symfony-specific artifacts:

```bash
declare -a spin_project_files=(
    "vendor"
    "composer.lock"
    ".infrastructure"
    "docker-compose*"
    "Dockerfile*"
    "var"
)
```

**Excluded vs Laravel:** `node_modules`, `yarn.lock`, `package-lock.json` — Symfony template has no frontend tooling. `var/` is Symfony's cache/log directory, worth cleaning on re-init.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File line replacement | Custom sed wrapper | `line_in_file` | Already handles escaping, macOS/Linux sed -i compat, multiple files, multiple modes |
| Interactive prompt with validation | Custom read loop | `prompt_and_update_file` | Already handles email validation, stderr/stdout split, default value display |
| OS/platform detection for sed | Custom | `sed_inplace` (used inside `line_in_file`) | Spin handles macOS BSD sed vs GNU sed -i differences internally |
| Symfony skeleton install | Custom PHP install logic | `composer create-project symfony/skeleton:"^7.4"` in Docker | Single command, no host PHP required |

**Key insight:** All file manipulation should go through `line_in_file`. Every custom sed call is a portability risk (macOS BSD sed vs GNU sed `-i` differences).

---

## Common Pitfalls

### Pitfall 1: Wrong line_in_file Action for ARG Patching

**What goes wrong:** Using `--action exact` to patch `ARG PHP_VERSION="8.3"` fails if version string differs, or patches unintended occurrences.

**Why it happens:** Confusing `exact` (literal substring match anywhere) with `replace` (line prefix match + full line replacement).

**How to avoid:** Use `--action replace` with the ARG prefix as the search term:
```bash
line_in_file --action replace --file "$dockerfile" 'ARG PHP_VERSION=' "ARG PHP_VERSION=\"${SPIN_PHP_VERSION}\""
```
The `replace` action finds any line starting with `ARG PHP_VERSION=` and replaces the entire line.

**Warning signs:** If the search string contains quotes, test both `replace` and `exact` manually to verify correct behavior.

### Pitfall 2: new() Must Run in pwd, not project_dir

**What goes wrong:** Mounting `$project_dir` to Docker before it exists (Docker creates it as root-owned).

**Why it happens:** `composer create-project` creates the target directory itself. Mounting `$(pwd)` and letting Composer create the subdirectory avoids permission issues.

**How to avoid:** Mount `$(pwd)` (parent), pass project name as argument to `composer create-project`.

```bash
# CORRECT
docker run --rm -v "$(pwd):/var/www/html" ... composer create-project symfony/skeleton:"^7.4" my-app

# WRONG — docker creates my-app dir as root before composer runs
docker run --rm -v "$(pwd)/my-app:/var/www/html" ... composer create-project symfony/skeleton:"^7.4" .
```

### Pitfall 3: Forgetting --ignore-missing for Prod Traefik Config

**What goes wrong:** `line_in_file --action exact` errors if `changeme@example.com` not found (file doesn't exist yet in Phase 3).

**Why it happens:** Prod traefik.yml is a Phase 4 deliverable. The file doesn't exist in the template during Phase 3.

**How to avoid:** Always use `--ignore-missing` for the prod traefik email patch in post-install.sh.

### Pitfall 4: init() Must Not Run Symfony Skeleton Install

**What goes wrong:** `init` action is called on an EXISTING Symfony project. Running `composer create-project` would overwrite it.

**Why it happens:** `new()` calls `init --force` after the skeleton install. `init()` standalone should only copy/update Spin infrastructure files.

**How to avoid:** Skeleton install only in `new()`. The `init()` function handles file cleanup (spin_project_files) and destructive action warning.

### Pitfall 5: PHP_OS_SUFFIX Must Be Exported for post-install.sh

**What goes wrong:** `post-install.sh` can't patch `ARG PHP_OS_SUFFIX` if `PHP_OS_SUFFIX` is not exported from `install.sh`.

**Why it happens:** `assemble_php_docker_image()` is called in `install.sh`, which must export `PHP_OS_SUFFIX`. If only set locally, it won't be visible in the sourced `post-install.sh`.

**How to avoid:** `export PHP_OS_SUFFIX` inside `assemble_php_docker_image()`.

### Pitfall 6: install.sh Sourced in Parent Shell

**What goes wrong:** `exit 1` in install.sh terminates the user's shell session.

**Why it happens:** Spin sources install.sh (`source "$SPIN_TEMPLATE_TEMPORARY_SRC_DIR/install.sh"`), not execs it.

**How to avoid:** This is actually the same as the Laravel template — both use `exit 1` for errors. It's acceptable since spin is always run as a sub-command, not from a user's interactive shell. No change needed.

---

## Code Examples

### Verified: Exact prompt_and_update_file Call for Email

```bash
# Source: ~/.spin/lib/functions.sh:966, cross-referenced with Laravel install.sh
SERVER_CONTACT=$(prompt_and_update_file \
    --title "🤖 Server Contact" \
    --details "Set an email contact who should be notified for Let's Encrypt SSL renewals and other system alerts." \
    --prompt "Please enter your email" \
    --output-only \
    --validate "email")

export SERVER_CONTACT
```

### Verified: Git Init Pattern

```bash
# Source: Laravel post-install.sh:109-118
initialize_git_repository() {
    local current_dir=""
    current_dir=$(pwd)

    cd "$project_dir" || exit
    echo "Initializing Git repository..."
    git init

    cd "$current_dir" || exit
}

# Called after all other setup:
if [[ ! -d "$project_dir/.git" ]]; then
    initialize_git_repository
fi
```

### Verified: SPIN_INSTALL_DEPENDENCIES Guard

```bash
# Source: Laravel post-install.sh — guards all docker install calls
if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]; then
    # ... docker pull, docker run, etc.
fi
```

### Verified: Dockerfile ARG Lines to Patch (from Phase 1 output)

```dockerfile
# Current defaults in template/Dockerfile:
ARG PHP_VERSION="8.3"
ARG PHP_VARIATION="frankenphp"
ARG PHP_OS_SUFFIX=""
```

These three lines are the only patching targets in post-install.sh.

### Verified: SPIN_ACTION Dispatch

```bash
# Source: Laravel install.sh:370-376, action_init.sh shows SPIN_ACTION is already set
if type "$SPIN_ACTION" &>/dev/null; then
  $SPIN_ACTION
else
  echo "The function '$SPIN_ACTION' does not exist."
  exit 1
fi
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Laravel patches `FROM serversideup...` line | Symfony patches `ARG PHP_VERSION/VARIATION/OS_SUFFIX` lines | Keeps ARG interpolation in FROM; only 3 `replace` calls |
| All variations use same dev port | Prod compose has variation-specific ports (Phase 4) | Install scripts simpler; no per-variation compose patching needed |
| `symfony/skeleton` `^6.4` (old LTS) | `symfony/skeleton:"^7.4"` (current LTS, Nov 2025+) | 7.4 requires PHP 8.2+; pairs well with FrankenPHP 8.3+ requirement |

---

## Open Questions

1. **meta.yml repository URL**
   - What we know: Author is Julian Douma (@JulianDouma)
   - What's unclear: Final GitHub repo URL (personal fork vs org?)
   - Recommendation: Use `https://github.com/JulianDouma/spin-template-symfony` as placeholder; update when repo is public

2. **PHP_OS_SUFFIX variable name convention**
   - What we know: The Dockerfile uses `PHP_OS_SUFFIX`. The variable computed in `assemble_php_docker_image()` should match.
   - What's unclear: Whether to export as `PHP_OS_SUFFIX` or `SPIN_PHP_OS_SUFFIX`
   - Recommendation: Use `PHP_OS_SUFFIX` (no `SPIN_` prefix) since it directly maps to the Dockerfile ARG name and the CONTEXT.md refers to it as `PHP_OS_SUFFIX`

3. **prod traefik.yml timing with Phase 3 patching**
   - What we know: prod traefik.yml doesn't exist yet (Phase 4); `--ignore-missing` handles gracefully
   - What's unclear: Whether Phase 4 should add `changeme@example.com` placeholder explicitly for the patch to work at install time
   - Recommendation: Phase 3 uses `--ignore-missing`. Phase 4 MUST add the placeholder so the patch works end-to-end. Document this dependency clearly in Phase 4 plan.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bash (no formal test framework detected) |
| Config file | None — manual testing via spin CLI |
| Quick run command | `SPIN_ACTION=new bash -n install.sh` (syntax check) |
| Full suite command | `spin new symfony test-app` (integration test) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SPIN-01 | meta.yml validates with spin CLI | manual | `spin new symfony --dry-run` or yaml lint | ❌ Wave 0 |
| SPIN-02 | new()/init() dispatched correctly | manual-only | `SPIN_ACTION=new bash install.sh symfony-test` | ❌ Wave 0 |
| SPIN-03 | PHP version prompt shows 8.3/8.4/8.5 | manual-only | Interactive test | N/A |
| SPIN-04 | Variation prompt defaults to frankenphp | manual-only | Interactive test | N/A |
| SPIN-05 | Alpine+FrankenPHP warning displayed | manual-only | Interactive test | N/A |
| SPIN-06 | Email prompt validates format | manual-only | Interactive test | N/A |
| SPIN-07 | symfony/skeleton:"^7.4" installed | manual | Check composer.json after `spin new symfony` | ❌ Wave 0 |
| SPIN-08 | serversideup/spin in composer.json --dev | manual | Check composer.json after install | ❌ Wave 0 |
| SPIN-09 | template/ directory contains all files | unit | `ls template/` assertion | ✅ (files exist) |
| RT-03 | Dockerfile ARGs patched correctly | unit | `grep "ARG PHP_VERSION" Dockerfile` after install | ❌ Wave 0 |

### Sampling Rate

- **Per task:** `bash -n install.sh && bash -n post-install.sh` (syntax check)
- **Per wave merge:** Full `spin new symfony test-app` integration run
- **Phase gate:** Verify all three ARG lines patched, serversideup/spin in composer.json, git repo initialized

### Wave 0 Gaps

- [ ] `install.sh` — does not exist yet
- [ ] `post-install.sh` — does not exist yet
- [ ] `meta.yml` — does not exist yet
- [ ] Bash syntax check command: `bash -n install.sh && bash -n post-install.sh`
- [ ] Integration test: `spin new symfony test-app --no-install` (skips docker pulls for faster CI)

---

## Sources

### Primary (HIGH confidence)

- `~/.spin/lib/functions.sh:717` — `line_in_file` full implementation (read directly)
- `~/.spin/lib/functions.sh:966` — `prompt_and_update_file` full implementation (read directly)
- `~/.spin/lib/actions/init.sh` — `action_init()` showing how install.sh and post-install.sh are sourced, variable injection sequence (read directly)
- `~/.spin/lib/actions/new.sh` — `action_new()` showing SPIN_ACTION="new" set before calling action_init (read directly)
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/install.sh` — canonical reference (read fully)
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/post-install.sh` — canonical reference (read fully)
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/meta.yml` — format reference (read directly)
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/Dockerfile` — patching targets (read directly)
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/docker-compose.dev.yml` — confirmed all variations use port 8080 + http in dev (read directly)

### Secondary (MEDIUM confidence)

- Packagist symfony/skeleton page — confirmed `^7.4` constraint for current LTS (fetched 2026-03-18)
- Symfony releases page via WebSearch — confirmed 7.4 is the current LTS (released Nov 2025) (verified 2026-03-18)

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all utilities read from live spin source; version constraint verified against Packagist
- Architecture: HIGH — sourced directly from canonical Laravel reference template and spin CLI internals
- `line_in_file` / `prompt_and_update_file` API: HIGH — read from actual spin lib source, not documentation
- Pitfalls: HIGH — derived from direct code analysis of spin internals and template source
- RT-03 scope: HIGH — derived from Phase 2 outputs (actual docker-compose.dev.yml reviewed) and STATE.md decisions

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (spin is stable; Symfony 7.4 LTS support long-term)
