# Spin Template: Symfony

## What This Is

An official-style Spin template that bootstraps a production-ready Symfony 7 (LTS) application using the FrankenPHP runtime. It follows the conventions established by `serversideup/spin-template-laravel-basic` — multi-stage Dockerfile, environment-specific Docker Compose overlays (dev/prod), Traefik reverse proxy with SSL, and an interactive `install.sh` — but adapted for the Symfony ecosystem.

## Core Value

Developers can run `spin new symfony` and get a working Symfony 7 LTS application with FrankenPHP, Traefik, and production-ready Docker configuration in under a minute.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Template bootstraps from `spin-template-skeleton` structure (meta.yml, install.sh, template/ directory)
- [ ] Interactive `install.sh` lets users choose PHP version (8.3, 8.4, 8.5 if supported), OS (debian/alpine)
- [ ] FrankenPHP is the default and primary runtime (using `serversideup/php:*-frankenphp` images)
- [ ] Multi-stage Dockerfile with base, development, ci, and deploy targets
- [ ] `docker-compose.yml` base config with PHP/Symfony service
- [ ] `docker-compose.dev.yml` with Traefik reverse proxy, volume mounts for live editing, Mailpit
- [ ] `docker-compose.prod.yml` with Swarm deployment, Let's Encrypt SSL, health checks, named volumes
- [ ] Traefik configuration for dev (self-signed SSL) and prod (Let's Encrypt ACME)
- [ ] `.infrastructure/` directory with Traefik configs, SSL certificates, and volume data structure
- [ ] Symfony 7 LTS skeleton installed during `post-install.sh` via Composer
- [ ] No database service included — users add their own
- [ ] Template follows all Spin template conventions (meta.yml, install.sh with `new()`/`init()` functions, template/ directory)

### Out of Scope

- Database services — users add their own based on project needs
- Redis/cache services — same rationale
- CI/CD GitHub Actions — keep it basic like the Laravel basic template
- Symfony Flex recipes beyond the skeleton — users customize post-install
- Webpack Encore / AssetMapper configuration — users choose their own frontend tooling
- Pro template features (those belong in a separate spin-template-symfony-pro)

## Context

- **Reference template:** `serversideup/spin-template-laravel-basic` at `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic`
- **Skeleton template:** `serversideup/spin-template-skeleton` at `/Users/juliandouma/Developer/oss/spin/spin-template-skeleton`
- **Spin CLI:** Available at `/Users/juliandouma/.spin/bin/spin`
- **serversideup/php images:** Official Docker images that provide PHP variations (fpm-nginx, frankenphp, fpm-apache) with built-in features like Laravel/Symfony automations
- **Symfony 7 LTS:** Long-term support version of Symfony, the target framework
- **FrankenPHP:** Modern PHP application server built on Caddy, supports worker mode, HTTP/2, HTTP/3 — the primary runtime for this template
- The template structure requires: `meta.yml` (metadata), `install.sh` (interactive setup), `template/` directory (actual template files)
- The `install.sh` uses `$SPIN_ACTION` variable to dispatch between `new()` and `init()` functions

## Constraints

- **Runtime:** FrankenPHP as primary runtime (via serversideup/php images)
- **Framework:** Symfony 7 LTS only
- **Template conventions:** Must follow Spin template structure exactly (meta.yml, install.sh, template/)
- **Image base:** Must use `serversideup/php` Docker images
- **Parity:** Should mirror the Laravel basic template's infrastructure patterns (Traefik config, SSL certs, Dockerfile stages, compose overlay structure)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| FrankenPHP as default runtime | User specified; modern, performant, supports worker mode | — Pending |
| No database included | User specified; keeps template minimal, users add their own | — Pending |
| Follow Laravel basic (not pro) pattern | User specified; basic template scope | — Pending |
| Configurable PHP version via install.sh | User wants flexibility; support 8.3-8.5 | — Pending |
| Symfony 7 LTS | Long-term support ensures stability | — Pending |

---
*Last updated: 2026-03-18 after initialization*
