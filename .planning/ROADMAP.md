# Roadmap: Spin Template Symfony

## Overview

Build a production-ready Spin CLI template that bootstraps Symfony 7 LTS with developer's choice of PHP runtime (FrankenPHP default, fpm-nginx, fpm-apache) and Traefik in under a minute. The work proceeds in dependency order: first the container image must build and serve correctly for the chosen runtime variation, then the development environment, then the interactive install scripts that automate the whole flow (including runtime selection), and finally the production Swarm configuration with documentation. Each phase produces something that can be independently verified before the next begins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Container Runtime** - Multi-stage Dockerfile and runtime config files that build and serve Symfony correctly across supported PHP variations (completed 2026-03-18)
- [x] **Phase 2: Development Environment** - Compose base + dev overlay with Traefik, self-signed SSL, and live-editing volumes (completed 2026-03-18)
- [x] **Phase 3: Install Scripts** - Interactive `install.sh`, `post-install.sh`, and `meta.yml` that automate setup including runtime selection (completed 2026-03-18)
- [ ] **Phase 4: Production and Ship** - Prod Swarm config, Traefik ACME, named volumes, per-runtime labels, and README

## Phase Details

### Phase 1: Container Runtime
**Goal**: The container builds and serves a Symfony application correctly across all supported PHP variations, with all Dockerfile stages and runtime configuration files in place
**Depends on**: Nothing (first phase)
**Requirements**: DOCK-01, DOCK-02, DOCK-03, DOCK-04, DOCK-05, RT-01, RT-02
**Success Criteria** (what must be TRUE):
  1. `docker build --target development --build-arg PHP_VARIATION=frankenphp .` succeeds without errors using a `serversideup/php` base image
  2. `docker build --target deploy .` produces an image where the app is owned by `www-data` and `cache:warmup` has run
  3. A running FrankenPHP container serves HTTP on port 8080 with the document root resolving from `/var/www/html/public` (no 404 on `/`)
  4. `curl http://localhost/healthz` (or the variation-appropriate health path) returns 200 OK from the shipped runtime config
  5. Changing `PHP_VERSION`, `PHP_VARIATION`, or `PHP_OS` build args produces a different base image tag without Dockerfile edits
**Plans:** 1/1 plans complete

Plans:
- [x] 01-01-PLAN.md — Dockerfile, .dockerignore, and entrypoint cache warmup script

### Phase 2: Development Environment
**Goal**: Developers can run `spin up` and get a working local Symfony environment with HTTPS via Traefik, live code editing, and optimized cache performance
**Depends on**: Phase 1
**Requirements**: COMP-01, COMP-02, DEV-01, DEV-02, DEV-03, DEV-04, DEV-05, DEV-06, TRAF-01, TRAF-02, TRAF-05
**Success Criteria** (what must be TRUE):
  1. `docker compose -f docker-compose.yml -f docker-compose.dev.yml up` starts all services without errors
  2. The Symfony app is reachable at `https://localhost` (or a local domain) with a valid self-signed certificate via Traefik
  3. Editing a PHP file on the host is immediately reflected in the running container without restarting
  4. `var/` directory uses a named volume (not a bind mount), preventing cache performance degradation
  5. Mailpit web UI is accessible at `http://localhost:8025`
**Plans:** 1 plan

Plans:
- [x] 02-01-PLAN.md — Traefik config, SSL certificates, .infrastructure stubs, and Docker Compose files

### Phase 3: Install Scripts
**Goal**: Running `spin new symfony` interactively configures and bootstraps a Symfony 7 LTS project from the template, including PHP version, runtime variation, and OS selection
**Depends on**: Phase 2
**Requirements**: SPIN-01, SPIN-02, SPIN-03, SPIN-04, SPIN-05, SPIN-06, SPIN-07, SPIN-08, SPIN-09, RT-03
**Success Criteria** (what must be TRUE):
  1. `spin new symfony` prompts separately for PHP version (8.3/8.4/8.5), PHP variation (frankenphp/fpm-nginx/fpm-apache), OS (debian/alpine with Alpine warning), and server contact email — all choices are reflected in the generated files
  2. After `spin new symfony` completes, `symfony/skeleton` is installed in the project directory via Composer running inside Docker (no host Composer required)
  3. The generated `Dockerfile FROM` line and runtime config files match the PHP version, variation, and OS selected during prompting
  4. `spin init` (on an existing project) runs the `init()` function without triggering skeleton install
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — meta.yml template registration and install.sh with interactive prompts
- [x] 03-02-PLAN.md — post-install.sh with Dockerfile patching, Composer deps, and git init

### Phase 4: Production and Ship
**Goal**: The template supports Docker Swarm production deployment with Let's Encrypt SSL and per-runtime Traefik labels, and is documented well enough for a developer to go from zero to live
**Depends on**: Phase 3
**Requirements**: PROD-01, PROD-02, PROD-03, PROD-04, PROD-05, PROD-06, PROD-07, TRAF-03, TRAF-04, SPIN-10, DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. `docker stack deploy` with the prod compose file starts the Symfony service in Swarm mode with OPcache enabled and `APP_ENV=prod`
  2. Traefik requests a Let's Encrypt certificate via HTTP-01 challenge using the `SERVER_CONTACT` email collected at install time
  3. HTTP requests to the production domain redirect to HTTPS; FrankenPHP variation uses `loadbalancer.server.port=8443` with `scheme=https` and `SSL_MODE=full`; fpm-nginx and fpm-apache variations use `loadbalancer.server.port=8080` with `scheme=http`
  4. `var/log` and `var/cache` persist across container restarts via named volumes
  5. README documents installation steps, required `.env` changes, and how to run the app — a developer can follow it without reading source files
**Plans**: 2 plans

Plans:
- [ ] 04-01-PLAN.md — Prod compose with Swarm deploy, Traefik prod config with ACME, and .spin.yml scaffold
- [ ] 04-02-PLAN.md — post-install.sh prod patching, .env.example, and README documentation

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Container Runtime | 1/1 | Complete | 2026-03-18 |
| 2. Development Environment | 1/1 | Complete | 2026-03-18 |
| 3. Install Scripts | 2/2 | Complete   | 2026-03-18 |
| 4. Production and Ship | 0/2 | In progress | - |
