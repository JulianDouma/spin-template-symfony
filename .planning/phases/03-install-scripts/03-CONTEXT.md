# Phase 3: Install Scripts - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Interactive `install.sh`, `post-install.sh`, and `meta.yml` that automate project setup via `spin new symfony`. Covers PHP version/variation/OS prompts, Symfony skeleton installation, Dockerfile ARG patching, Composer dependency installation, and template registration. Does NOT include production compose, README, or .env.example — those are Phase 4.

</domain>

<decisions>
## Implementation Decisions

### install.sh Prompts
- Prompt order: variation → version → OS → email (same as Laravel template for consistent Spin UX)
- FrankenPHP as default variation (Laravel defaults to fpm-nginx — we diverge here intentionally)
- Show Alpine performance warning when FrankenPHP + Alpine is selected (musl stack-size issues with worker mode)
- PHP versions: 8.3, 8.4, 8.5 (FrankenPHP requires 8.3+)
- Use Spin utility functions: `prompt_and_update_file` for email, `show_header` adapted for Symfony branding
- `new()` and `init()` functions dispatched via `$SPIN_ACTION` (same pattern as Laravel)

### post-install.sh Behavior
- Symfony skeleton installed via Docker: `docker run serversideup/php:*-cli composer create-project symfony/skeleton` — no host Composer required
- Install `serversideup/spin` as Composer dev dependency (like Laravel template)
- No PHP extensions prompt — users edit the Dockerfile manually (simpler than Laravel's interactive extension selection)
- No database/feature/JS package manager selection prompts (we have no database, no frontend tooling)
- Git repository initialized if not already present
- Patch server contact email into Traefik prod config

### Dockerfile Patching Strategy
- Patch ARG defaults in Dockerfile, NOT the full FROM line — keeps ARG interpolation pattern intact
- `line_in_file` replaces: `ARG PHP_VERSION="8.3"` → `ARG PHP_VERSION="8.5"` (user's selection)
- `line_in_file` replaces: `ARG PHP_VARIATION="frankenphp"` → `ARG PHP_VARIATION="fpm-nginx"` (user's selection)
- For OS suffix: `assemble_php_docker_image()` translates user's OS choice (debian/alpine) into `PHP_OS_SUFFIX` value ("" or "-alpine") and patches `ARG PHP_OS_SUFFIX=""` accordingly
- Traefik prod config: patch `changeme@example.com` → `$SERVER_CONTACT`

### meta.yml Identity
- Template name: `symfony` (invoked via `spin new symfony my-app`)
- Title: "Symfony Basic Template"
- Author: Julian Douma (@JulianDouma)
- Repository: https://github.com/JulianDouma/spin-template-symfony (or appropriate URL)
- Description: "The Symfony Spin template when you run `spin new symfony` from CLI."

### Claude's Discretion
- Exact `show_header()` ASCII art / branding for Symfony
- Helper function structure (can mirror Laravel's `delete_matching_pattern`, `project_files_exist`, etc.)
- `spin_project_files` array contents (Symfony-specific files to track)
- Exact `assemble_php_docker_image()` implementation (translate OS choice to suffix)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spin Template Reference
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/install.sh` — Laravel install.sh with prompt functions, `new()`/`init()` dispatch, `assemble_php_docker_image()`
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/post-install.sh` — Laravel post-install with Dockerfile patching, Composer install, extensions, git init
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/meta.yml` — Laravel meta.yml format

### Phase 1-2 Outputs
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/Dockerfile` — The Dockerfile whose ARG defaults get patched
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/.infrastructure/conf/traefik/dev/` — Traefik config that's already in place

### Spin Utilities
- `prompt_and_update_file` — Spin-provided utility for interactive prompts with validation
- `line_in_file` — Spin-provided utility for file patching (replace, after, exact modes)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `template/Dockerfile` — Has ARG lines that need patching: `ARG PHP_VERSION="8.3"`, `ARG PHP_VARIATION="frankenphp"`, `ARG PHP_OS_SUFFIX=""`
- `template/.infrastructure/conf/traefik/prod/` — Currently has `.gitignore` stub; will get `traefik.yml` in Phase 4 with `changeme@example.com` placeholder

### Established Patterns
- Spin CLI sets `$SPIN_ACTION` ("new" or "init"), `$SPIN_USER_ID`, `$SPIN_GROUP_ID`, `$SPIN_INSTALL_DEPENDENCIES`
- `prompt_and_update_file` and `line_in_file` are Spin-provided (not custom)
- Laravel template structure: install.sh handles prompts + dispatch, post-install.sh handles framework install + file patching

### Integration Points
- `install.sh` must export: `SPIN_PHP_VERSION`, `SPIN_PHP_VARIATION`, `SPIN_PHP_DOCKER_BASE_IMAGE`, `SPIN_PHP_DOCKER_INSTALLER_IMAGE`, `SERVER_CONTACT`
- `post-install.sh` receives these exports and patches files accordingly
- `meta.yml` registers the template with Spin CLI for `spin new symfony`

</code_context>

<specifics>
## Specific Ideas

- The `show_header()` should say "Let's get Symfony launched!" (adapted from Laravel's "Let's get Laravel launched!")
- `assemble_php_docker_image()` must handle the debian/alpine suffix correctly: debian = no suffix in tag, alpine = `-alpine` suffix — same logic as Laravel but additionally patches `PHP_OS_SUFFIX` ARG

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-install-scripts*
*Context gathered: 2026-03-18*
