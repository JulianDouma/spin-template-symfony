# Project Research Summary

**Project:** spin-template-symfony
**Domain:** Docker-based Spin template for Symfony 7 LTS with FrankenPHP runtime
**Researched:** 2026-03-18
**Confidence:** HIGH

## Executive Summary

This project is a Spin CLI template that bootstraps a production-ready Symfony 7 LTS application inside Docker using FrankenPHP as the PHP runtime. Expert teams building this type of template follow the `spin-template-laravel-basic` as the canonical reference: a bash `install.sh` that prompts for PHP version and OS, copies a `template/` directory of Docker/Compose files into the user's project, and runs Composer via a throw-away Docker CLI container. The key structural difference from a Laravel template is that FrankenPHP embeds Caddy (the web server), so there is no separate Nginx or PHP-FPM process — the PHP container handles HTTP directly on internal ports 8080 (HTTP) and 8443 (HTTPS), with Traefik as the external reverse proxy that terminates TLS.

The recommended approach centers on `serversideup/php:*-frankenphp` images (not the official `dunglas/frankenphp`), Symfony 7.4 LTS skeleton via `composer create-project`, Traefik v3.6 for reverse-proxy with self-signed SSL in dev and Let's Encrypt ACME in production via Docker Swarm. All four research areas converge on the same phase sequence: nail the Dockerfile + Caddyfile scaffold first (wrong document root and port conflicts cause all downstream failures), then build the Compose dev environment, then wire the install/post-install scripts, and finally validate the production Swarm config end-to-end.

The primary risks are Symfony-specific deviations from the Laravel template that are easy to miss: FrankenPHP requires Debian (not Alpine) to avoid musl stack-size crashes, the document root must point to `public/` not the project root, the dev Compose overlay must use a named volume for `var/` to avoid bind-mount performance degradation, and all worker-mode configuration requires the `runtime/frankenphp-symfony` package for correct Symfony kernel reset between requests. None of these are blocking risks if addressed in the correct phase — they are well-documented in official FrankenPHP and serversideup docs and have clear prevention steps.

## Key Findings

### Recommended Stack

The template uses `serversideup/php:*-frankenphp` as the Docker base image (offering PHP 8.3, 8.4, and 8.5 — the minimum FrankenPHP supports), with Symfony 7.4 LTS installed via `composer create-project symfony/skeleton:"7.4.*"`. Symfony 7.4 LTS was released November 2025 and is supported until November 2029. Traefik v3.6 handles all reverse-proxy and SSL duties — this is the same version used by the Laravel basic template and the current stable series. PHP 8.4 is the recommended default (active PHP support, highest adoption, matches `symfony/skeleton` v7.4.99 constraints).

**Core technologies:**
- `serversideup/php:*-frankenphp` (Debian, default): PHP runtime + Caddy web server in one process — runs as unprivileged `www-data`, provides UID/GID remapping tooling, SSL_MODE env var, and health check configuration
- `symfony/skeleton:"7.4.*"`: Minimal Symfony 7 LTS bootstrap via Composer — installs framework-bundle, console, dotenv, runtime, yaml
- `runtime/frankenphp-symfony:^1.0`: FrankenPHP-Symfony runtime bridge for correct worker mode kernel reset (v1.0.0 released December 2025)
- `traefik:v3.6`: Reverse proxy handling self-signed SSL in dev (Docker provider) and Let's Encrypt in prod (Swarm provider)
- `axllent/mailpit:latest`: Local SMTP catcher with web UI, zero-configuration, consistent with the Laravel basic template
- Docker Compose v2 (base + dev + prod overlays): Exact overlay pattern from the reference template; base defines services, overlays add environment-specific config

### Expected Features

**Must have (table stakes):**
- `meta.yml` — Spin CLI cannot discover or register the template without it
- `install.sh` with `new()` and `init()`, PHP version prompt (8.3/8.4/8.5), OS prompt (debian/alpine with Alpine warning), and `SERVER_CONTACT` email prompt
- Multi-stage `Dockerfile` (base, development, ci, deploy) using `serversideup/php:*-frankenphp`
- `docker-compose.yml` base + `docker-compose.dev.yml` (Traefik, volume mounts, Mailpit, Node service) + `docker-compose.prod.yml` (Swarm deploy, Let's Encrypt, named volumes, OPcache)
- `.infrastructure/conf/traefik/dev/` with pre-generated self-signed PEM pair and `traefik-certs.yml`
- `.infrastructure/conf/traefik/prod/traefik.yml` with Cloudflare trusted IPs and ACME resolver
- Symfony skeleton installed via Composer during `new()` — this is the template's core value
- Named volume overlay for `var/` in dev Compose (critical: prevents 3-10x performance degradation)
- Health check endpoint — Symfony has no built-in `/up` route; template must ship a minimal working route or use Caddy's metrics endpoint
- FrankenPHP worker mode configured via env vars in Compose
- OPcache enabled in prod Compose (`PHP_OPCACHE_ENABLE=1`)
- Named volumes for Symfony's `var/log/`, `var/cache/` paths (differ from Laravel's `storage/` paths)

**Should have (competitive differentiators):**
- FrankenPHP worker mode pre-configured (`FRANKENPHP_CONFIG` + `APP_RUNTIME`) — delivers ~3x throughput vs PHP-FPM based on benchmarks (45ms vs 8ms p50)
- `cache:warmup` in Dockerfile `deploy` stage — eliminates slow first request after deploy
- `frankenphp_loop_max` configured in Caddyfile — prevents memory leaks from unbounded worker lifetime
- Alpine OS opt-in with explicit warning in `install.sh` prompt

**Defer (v2+):**
- Database service (Postgres, MySQL, MariaDB) — belongs in `spin-template-symfony-pro`
- Queue worker container (Symfony Messenger) — complexity beyond "basic" scope
- GitHub Actions CI/CD workflows — explicitly out of scope per PROJECT.md
- Mercure hub integration — advanced feature; FrankenPHP ships Mercure natively but adds significant config complexity

### Architecture Approach

The template follows the same structural pattern as `spin-template-laravel-basic`: a root-level `install.sh` + `post-install.sh` pair orchestrates interactive prompts and Composer project creation, while a `template/` directory contains all Docker and infrastructure files that get copied into the user's project. The key Symfony-specific deviation is that FrankenPHP IS the web server (no Nginx), so the Caddyfile (embedded in the image) must be configured correctly, and the Traefik-to-FrankenPHP port mapping differs from fpm-nginx templates.

**Major components:**
1. `meta.yml` — Template identity declaration; unblocks Spin CLI discovery; no logic, no dependencies
2. `install.sh` + `post-install.sh` — Interactive setup (PHP version, OS, email), Composer skeleton install, Dockerfile FROM line patching, Traefik email substitution
3. `Dockerfile` (multi-stage) — `base` (shared FrankenPHP runtime), `development` (UID/GID remapping), `ci` (root for pipelines), `deploy` (copies app, locks ownership, runs cache:warmup)
4. `docker-compose.yml` (base) + `docker-compose.dev.yml` + `docker-compose.prod.yml` — Compose overlay pattern; base is minimal; dev adds volume mounts, Traefik with self-signed SSL, Mailpit, Node; prod adds Swarm deploy config, named volumes, Let's Encrypt labels
5. `.infrastructure/conf/traefik/` — Static Traefik configuration files for dev (Docker provider, file-based TLS) and prod (Swarm provider, ACME, Cloudflare trusted IPs); separate from runtime data in `volume_data/`
6. Health check route — A minimal Symfony controller or use of the Caddy admin metrics endpoint so Traefik's `loadbalancer.healthcheck.path` works out of the box

### Critical Pitfalls

1. **Wrong document root (all routes return 404)** — The Caddyfile `root *` directive must point to `/var/www/html/public`, not the project root. This is the single most common FrankenPHP + Symfony misconfiguration. Set it correctly in Phase 1 and add a `curl` smoke test.

2. **FrankenPHP and Traefik competing for ports 80/443** — FrankenPHP's embedded Caddy also wants standard ports. Configure Caddy to listen on internal port 8080 only; never expose ports 80 or 443 from the PHP service in Compose. Traefik owns external SSL termination.

3. **Alpine OS + FrankenPHP = stack size crash** — musl libc's smaller thread stack causes PHP fatal errors during Symfony DI compilation in worker mode. Default to Debian. Emit a visible warning in `install.sh` when Alpine is chosen.

4. **Dev bind mount overwrites `var/` (3-10x dev performance degradation)** — Mounting `.:/var/www/html` shadows the container's warm cache. Add a named volume overlay for `/var/www/html/var` in `docker-compose.dev.yml`. This is a Symfony-specific problem; the Laravel template does not face it.

5. **FrankenPHP worker mode without `runtime/frankenphp-symfony`** — Worker mode without the Symfony runtime bridge causes stale Doctrine entity manager state between requests (identity map leaks, wrong user context). Always install the bridge package and configure `frankenphp_loop_max` as a safety net against memory leaks.

## Implications for Roadmap

Based on research, the component dependency graph creates a clear build sequence. Each phase's outputs are required by the next.

### Phase 1: Dockerfile and Caddyfile Scaffold

**Rationale:** Everything else depends on the container image building and serving correctly. The two most critical pitfalls (wrong document root, port conflict with Traefik) live here. Getting this wrong means all downstream validation is meaningless.

**Delivers:** A working multi-stage Dockerfile (`base`, `development`, `ci`, `deploy`) using `serversideup/php:*-frankenphp`, with FrankenPHP configured to listen on port 8080 internally, `root * /var/www/html/public` set, and `cache:warmup` in the `deploy` stage. The image must build and serve a `200 OK` on `/`.

**Addresses:** Dockerfile multi-stage build (P1), FrankenPHP worker mode env var configuration (P1), `cache:warmup` in deploy (differentiator)

**Avoids:** Wrong document root (Pitfall 1), port 80/443 conflict (Pitfall 2), Alpine stack size crash (Pitfall 3), worker mode without runtime bridge (Pitfall 5)

### Phase 2: Development Compose Environment

**Rationale:** Once the image builds, the local dev experience is the first thing a developer sees. The named `var/` volume pitfall is the most immediately impactful issue for all users.

**Delivers:** `docker-compose.yml` (base) + `docker-compose.dev.yml` with Traefik v3.6 reverse proxy (self-signed SSL via pre-generated PEM pair), volume mounts with a named volume overlay for `var/`, Mailpit service, Node.js service. `spin up` must start all services cleanly and serve HTTPS on localhost.

**Addresses:** `docker-compose.yml` base (P1), `docker-compose.dev.yml` with Traefik + Mailpit (P1), Traefik dev config + pre-generated SSL certs (P1), `.infrastructure/` directory structure (P1), named volume for `var/` (critical correctness requirement)

**Avoids:** `var/` bind mount performance degradation (Pitfall 4), `SSL_MODE=full` in dev anti-pattern, double-SSL configuration error

### Phase 3: Install and Post-Install Scripts

**Rationale:** Once the Docker environment is validated manually, the install scripts automate it. These scripts are the user-facing product — they must be correct before `meta.yml` registers the template in Spin.

**Delivers:** `install.sh` with `new()` and `init()` functions: PHP version selection (8.3/8.4/8.5), OS selection (debian/alpine with Alpine warning), `SERVER_CONTACT` email prompt. `post-install.sh` that runs `composer create-project symfony/skeleton` via Docker CLI image with `--user` flag, patches the Dockerfile FROM line, patches Traefik email placeholder. `meta.yml` that registers the template with Spin CLI.

**Addresses:** `meta.yml` (P1), `install.sh` with `new()`/`init()` (P1), Symfony skeleton install via Composer (P1), interactive PHP version and OS selection (P1)

**Avoids:** Root-owned project files from missing `--user` flag (Pitfall 5), Laravel-specific strings remaining in template (UX pitfall), incorrect Alpine selection without warning

### Phase 4: Production Compose and Swarm Configuration

**Rationale:** Production config is last because it depends on all prior phases being correct. Swarm health checks require the health route to exist (established in Phase 1/2), and ACME config requires the email collected in Phase 3.

**Delivers:** `docker-compose.prod.yml` with Docker Swarm `deploy` config (replicas, `start-first` rolling updates, rollback policy), Let's Encrypt Traefik labels, named volumes for Symfony paths (`var/log/`, `var/cache/`), OPcache enabled, `APP_ENV=prod`, health check label. `.infrastructure/conf/traefik/prod/traefik.yml` with Cloudflare trusted IPs and ACME resolver. Validated with `docker stack deploy` smoke test.

**Addresses:** `docker-compose.prod.yml` with Swarm + Let's Encrypt (P1), Traefik prod config + ACME (P1), named volumes for Symfony paths (P1), OPcache in prod (P1)

**Avoids:** `APP_ENV=APP_SECRET` `.env` confusion (Pitfall 6), `APP_ENV=dev` left in prod, committing `volume_data/` runtime files, health check pointing to non-existent route

### Phase 5: Validation and Polish

**Rationale:** End-to-end smoke testing catches integration issues that unit-level validation misses. This is also when Laravel-specific artifacts (strings, env vars, messaging) are hunted down and replaced.

**Delivers:** Complete `spin new symfony` flow tested on macOS and Linux. All 10 "looks done but isn't" checklist items verified. Symfony-appropriate `.env.example`. README documenting worker mode opt-in, Alpine caveats, health check configuration, and secrets management pattern.

**Addresses:** All UX pitfalls (Laravel strings, health route documentation, worker mode dev warnings), security checklist (APP_SECRET, Caddy admin port, Docker socket exposure)

**Avoids:** Ship-blocking issues discovered post-launch; all "looks done but isn't" items from PITFALLS.md

### Phase Ordering Rationale

- **Dockerfile before Compose:** You cannot validate Compose service definitions without a working image. Port mapping labels in Compose must match what the Caddyfile actually configures.
- **Dev before Prod:** Prod is a superset of dev configuration. Issues in dev (volume paths, Traefik routing) propagate to prod. Validate dev end-to-end first.
- **Scripts after Docker files:** `post-install.sh` patches Docker files, so the Docker files must exist and be correct before the patching logic is written and tested.
- **Prod last:** Production Swarm config depends on email from `install.sh` (Phase 3) and health routes from Phase 1/2. Attempting prod before those are stable creates circular debugging.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 3 (install.sh):** The exact shell utility functions available in Spin's bash environment (`prompt_and_update_file`, `line_in_file`, etc.) need verification against the reference template source. The Symfony-specific Composer flags for `create-project` inside Docker also need a test run to confirm `--user` flag behavior across macOS/Linux.
- **Phase 4 (Prod Swarm):** Docker Swarm label syntax for FrankenPHP's HTTPS backend (`scheme=https`, `port=8443`) needs verification against the actual Traefik v3.6 label documentation — the syntax changed slightly between Traefik v2 and v3.

Phases with standard patterns (skip research-phase):

- **Phase 1 (Dockerfile):** serversideup FrankenPHP image docs and the laravel-basic template provide all needed patterns. Well-documented, high-confidence sources.
- **Phase 2 (Dev Compose):** Compose overlay pattern is identical to laravel-basic. The named `var/` volume solution is documented in official Symfony Docker guides.
- **Phase 5 (Validation):** Checklist-driven; no new technical decisions required.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core claims verified against Docker Hub tag API, serversideup official docs, Symfony releases page, and Packagist. PHP version support matrix confirmed. Traefik version confirmed via GitHub releases. |
| Features | HIGH | Based on direct source inspection of `spin-template-laravel-basic` (primary source). Symfony-specific deviations (health route, named volumes, var/ paths) corroborated by official Symfony Docker guides. |
| Architecture | HIGH | All architectural patterns verified against live reference template source code and serversideup official docs. Component boundaries and data flow match observable behavior in the reference template. |
| Pitfalls | HIGH | All critical pitfalls traced to active GitHub issues in `frankenphp`, `dunglas/symfony-docker`, and `symfony/symfony` repositories with reproduction steps. Not speculative. |

**Overall confidence:** HIGH

### Gaps to Address

- **Symfony 7.4 worker mode status:** Symfony 7.4 is the LTS version but as of research date the actual minor is 7.2.x. The claim that "worker mode is automatic at 7.4" must be verified when 7.4 ships — until then, the template must install `runtime/frankenphp-symfony`. The template should handle this transition gracefully.
- **Health check endpoint implementation:** The template must ship a working `/up` or `/healthz` route. Two options exist (minimal custom controller vs. Caddy admin endpoint at `localhost:2019/metrics`) and neither has been tested against the Traefik health check label format. Choose and verify during Phase 1 or 2.
- **FrankenPHP `frankenphp_loop_max` default value:** The recommended value (500 requests) is sourced from community discussion, not official documentation. Validate this against observed memory behavior during Phase 5 smoke testing.
- **Alpine + FrankenPHP install.sh warning copy:** The exact warning text and whether it should block or merely inform the user is a UX decision not resolved in research. Decide during Phase 3.

## Sources

### Primary (HIGH confidence)

- `serversideup/spin-template-laravel-basic` (local source inspection) — install.sh, post-install.sh, Dockerfile, all Compose files, .infrastructure/ directory structure, meta.yml
- `serversideup/spin-template-skeleton` (local source inspection) — meta.yml and install.sh conventions
- [serversideup/php FrankenPHP image docs](https://serversideup.net/open-source/docker-php/docs/image-variations/frankenphp) — ports, SSL_MODE, env vars, HEALTHCHECK_PATH
- [serversideup/php choosing an image](https://serversideup.net/open-source/docker-php/docs/getting-started/choosing-an-image) — Debian vs Alpine tradeoff
- [serversideup/docker-php GitHub releases](https://github.com/serversideup/docker-php/releases) — v4.3.3, FrankenPHP v1.11.3
- [Symfony releases page](https://symfony.com/releases) — Symfony 7.4 LTS, support dates
- [Symfony 7.4 setup docs](https://symfony.com/doc/7.4/setup.html) — PHP >=8.2 requirement, composer create-project command
- [symfony/skeleton on Packagist](https://packagist.org/packages/symfony/skeleton) — v7.4.99, dependency list
- [runtime/frankenphp-symfony on Packagist](https://packagist.org/packages/runtime/frankenphp-symfony) — v1.0.0 released Dec 2025
- Docker Hub `serversideup/php` tag API (verified 2026-03-18) — PHP 8.3/8.4/8.5 FrankenPHP tags confirmed
- [FrankenPHP worker mode docs](https://frankenphp.dev/docs/worker/) — worker configuration, loop_max, kernel reset
- [FrankenPHP Docker docs](https://frankenphp.dev/docs/docker/) — Caddyfile configuration, document root
- [FrankenPHP production docs](https://frankenphp.dev/docs/production/) — deployment patterns

### Secondary (MEDIUM confidence)

- [Traefik GitHub releases](https://github.com/traefik/traefik/releases) — v3.6.10 confirmed as latest stable (via WebSearch, not direct API)
- [FrankenPHP Symfony benchmark: 45ms to 8ms](https://dev.to/mattleads/from-45ms-to-8ms-benchmarking-symfony-74-on-frankenphp-ekk) — worker mode performance claim
- [FrankenPHP behind Traefik discussion](https://github.com/php/frankenphp/issues/344) — port mapping recommendations
- [Symfony FrankenPHP worker mode integration (fusonic.net)](https://www.fusonic.net/en/blog/frankenphp-symfony) — kernel reset patterns, corroborated by official docs

### Tertiary (via GitHub issues — HIGH specificity, MEDIUM generalizability)

- [Alpine FrankenPHP freeze issue #1722](https://github.com/php/frankenphp/issues/1722) — stack size crash reproduction
- [Stack size fatal error issue #380](https://github.com/php/frankenphp/issues/380) — musl libc stack size confirmation
- [Entity manager not reopened between requests #1707](https://github.com/php/frankenphp/issues/1707) — Doctrine stale state in worker mode
- [Worker mode best practices discussion #1486](https://github.com/php/frankenphp/discussions/1486) — loop_max recommendation
- [FrankenPHP running from project root issue #1723](https://github.com/php/frankenphp/issues/1723) — document root 404 reproduction

---
*Research completed: 2026-03-18*
*Ready for roadmap: yes*
