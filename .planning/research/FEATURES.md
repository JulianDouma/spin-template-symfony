# Feature Research

**Domain:** Docker-based PHP framework template (Spin template for Symfony 7 LTS + FrankenPHP)
**Researched:** 2026-03-18
**Confidence:** HIGH — based on direct inspection of the Laravel basic template source, serversideup/php documentation, and FrankenPHP documentation.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `meta.yml` metadata file | Spin CLI requires it to list and identify templates | LOW | Title, description, authors, repository, issues fields — exactly mirrors `spin-template-laravel-basic/meta.yml` |
| `install.sh` with `new()` and `init()` functions | Spin CLI dispatches via `$SPIN_ACTION`; missing = template is uncallable | MEDIUM | Must export `SPIN_PROJECT_DIRECTORY`, handle both `new` (create from scratch) and `init` (retrofit existing project) paths |
| Interactive PHP version selection | Users have different runtime needs; all other Spin templates offer this | LOW | FrankenPHP requires PHP 8.3+, so valid choices are 8.3, 8.4, 8.5 — fewer options than fpm-nginx |
| Interactive OS selection (debian/alpine) | Mirrors Laravel template; users choose image size tradeoff | LOW | FrankenPHP docs recommend Debian for JIT performance; Alpine has stack size issues with Symfony — flag this in prompt |
| `template/` directory with all Docker files | Spin copies this directory into the user's project | LOW | All Dockerfile and compose files live here |
| Multi-stage `Dockerfile` (base, development, ci, deploy) | Industry standard; dev/prod parity requires separate stages | MEDIUM | base → development (UID/GID mapping, drop to www-data); base → ci (runs as root); base → deploy (COPY app, set www-data) |
| `docker-compose.yml` base service definition | Compose overlay pattern requires a base file | LOW | Minimal: define `traefik` and `php` services with `depends_on`; no ports here |
| `docker-compose.dev.yml` development overlay | Local dev needs volume mounts, Traefik ports, Mailpit | MEDIUM | Volume-mount source for live editing; USER_ID/GROUP_ID build args for file permission parity; Traefik with self-signed SSL on localhost |
| `docker-compose.prod.yml` production overlay | Docker Swarm deployment is the Spin production model | MEDIUM | Swarm deploy config, rollback policy, restart policy, named volumes for persistent data, Let's Encrypt via Traefik ACME |
| Traefik v3 as reverse proxy | SSL termination and routing for both dev and prod | MEDIUM | Dev: self-signed PEM certs via `traefik-certs.yml`; prod: Let's Encrypt ACME with `httpChallenge`; both configs stored in `.infrastructure/conf/traefik/` |
| Self-signed SSL certificates for local dev | HTTPS parity with production; browser-trusted dev cert | LOW | Pre-generated PEM pair in `.infrastructure/conf/traefik/dev/certificates/`; Traefik loads via file provider |
| Let's Encrypt SSL for production | Automatic HTTPS in prod; non-negotiable for real deployments | LOW | Configured in prod `traefik.yml` via `letsencryptresolver`; requires `SERVER_CONTACT` email collected during `install.sh` |
| `.infrastructure/` directory structure | Traefik configs, SSL certs, and volume data mount points | LOW | `conf/traefik/dev/`, `conf/traefik/prod/`, `conf/ci/`, `volume_data/` with `.gitignore` for generated data |
| Symfony 7 LTS skeleton install via Composer | Template's entire purpose is bootstrapping Symfony | MEDIUM | `composer create-project symfony/skeleton` run via Docker CLI image during `new()`; installs into project directory |
| `SERVER_CONTACT` email prompt | Required for Let's Encrypt ACME in production Traefik config | LOW | Collected during `install.sh` via `prompt_and_update_file` utility; written into prod `traefik.yml` |
| Node.js service in dev compose | Symfony AssetMapper or Webpack Encore builds require Node | LOW | `node:22` image, volume-mounts project root, same network as PHP — matches Laravel template pattern |
| Mailpit service in dev compose | Email testing during development; Symfony Mailer is standard | LOW | `axllent/mailpit` image; ports 8025 (web UI) and 1025 (SMTP); Symfony dev already preconfigures Mailpit SMTP |
| Production health check configuration | Traefik load balancer needs a health endpoint to route traffic | LOW | Traefik label `loadbalancer.healthcheck.path` pointing to a simple Symfony endpoint; Symfony does not have a built-in `/up` route like Laravel — must configure one |
| OPcache enabled in production | Standard PHP performance requirement; missing = slow production | LOW | `PHP_OPCACHE_ENABLE: "1"` environment variable on the php service in prod compose |
| Named volumes for persistent data in production | Stateless containers need external volume for logs, cache, sessions | LOW | Symfony-specific volume paths differ from Laravel: `var/log/`, `var/cache/`, `var/sessions/` (if filesystem sessions used) |
| Destructive-action warning in `init()` | Safety gate when retrofitting existing project; present in Laravel template | LOW | Check for existing Dockerfile/compose files, prompt before deleting |
| Cloudflare trusted IP ranges in prod Traefik config | Correct real-IP forwarding when behind Cloudflare CDN | LOW | Pre-populated YAML anchor in prod `traefik.yml`; mirrors Laravel template exactly |

### Differentiators (Competitive Advantage)

Features that set this template apart from a generic "Symfony + Docker" starter. Not expected by users arriving from zero, but clearly valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| FrankenPHP as default (not fpm-nginx) | Worker mode delivers ~3x throughput vs PHP-FPM + Nginx (8ms vs 45ms p50 latency per benchmarks); HTTP/2 and HTTP/3 out of the box | MEDIUM | Uses `serversideup/php:*-frankenphp` images; SSL_MODE env var controls HTTP/HTTPS on ports 8080/8443; worker mode is automatic in Symfony 7.4+ (no extra package needed) |
| FrankenPHP worker mode pre-configured | Symfony 7.4+ has native worker mode support with zero extra config; earlier 7.x required `runtime/frankenphp-symfony`; template targets 7 LTS so the right approach depends on exact minor version | MEDIUM | For Symfony <7.4: `FRANKENPHP_CONFIG=worker ./public/index.php` and `APP_RUNTIME=Runtime\FrankenPhpSymfony\Runtime`; for 7.4+: automatic via Runtime component detection |
| `serversideup/php` images instead of official `dunglas/frankenphp` | Pre-configured security hardening (unprivileged www-data), PHP tuning defaults, UID/GID mapping tooling (`docker-php-serversideup-set-id`), consistent with the broader Spin ecosystem | LOW | Image tag pattern: `serversideup/php:{version}-frankenphp` or `serversideup/php:{version}-frankenphp-alpine` |
| Docker Swarm production model | Real zero-downtime deploys with `start-first` rolling update, automatic rollback on failure, replica management — not just `docker compose up` in prod | MEDIUM | `deploy.update_config.order: start-first` and `failure_action: rollback` in prod compose matches Laravel basic pattern |
| Spin ecosystem integration | Users get `spin up`, `spin deploy`, `spin new symfony` — the full Spin DX rather than raw Docker knowledge | LOW | `SPIN_IMAGE_DOCKERFILE`, `SPIN_APP_DOMAIN`, `SPIN_MD5_HASH_TRAEFIK_YML` env vars expected by Spin CLI |
| Symfony-specific health check endpoint | Traefik requires a health route; Symfony has no built-in `/up` (unlike Laravel); template should include a minimal health controller or route | MEDIUM | Options: simple controller returning 200, or `kiora/health-check-bundle`; template should ship a minimal working route so Traefik health check works immediately |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem like good additions but would violate the "basic" template scope or create maintenance burden.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Database service (Postgres/MySQL/MariaDB) | Every real Symfony app needs a database | Forces a specific DB choice on users; doubles maintenance surface; "basic" template scope excludes it per PROJECT.md | Users add their own DB service after init; a future `spin-template-symfony-pro` can include DB options |
| Redis / cache service | Symfony cache, sessions, and queues often use Redis | Same rationale as database — opinionated infrastructure choice | Users add Redis to their compose as needed |
| Symfony Messenger / queue worker service | Async processing is common in Symfony apps | Needs separate worker container config, supervisor, retry logic — well beyond "basic" scope | Document as a post-install step; future pro template |
| GitHub Actions CI/CD workflows | Automates testing and deployment | Out of scope for basic template per PROJECT.md; different CI systems for different teams | Users copy from Spin docs or pro template |
| Webpack Encore or AssetMapper config | Frontend asset bundling is expected | Every project chooses differently; Node service is included for user-driven builds | Node service in dev compose is sufficient; users configure their own bundler |
| Xdebug pre-enabled | Developers want debugging | Performance overhead in dev containers; Xdebug version must match PHP version exactly; creates noise for users who don't need it | Document environment variable override (`XDEBUG_MODE=debug`) using serversideup/php image's built-in Xdebug support |
| Mercure hub for real-time | FrankenPHP/Caddy ships Mercure natively; looks compelling | Adds significant complexity to Caddyfile/compose; most Symfony apps don't use Mercure | Leave Mercure for a Symfony "full" or pro template |
| Alpine as default OS | Smaller image size | FrankenPHP docs warn Alpine needs increased stack size for Symfony; JIT doesn't work on Alpine musl; Debian is the safe default | Offer Alpine as opt-in choice in `install.sh` prompt with a warning note |

## Feature Dependencies

```
[meta.yml]
    └──required-by──> [Spin CLI template registration]

[install.sh with new()/init()]
    └──requires──> [prompt_php_version()]
    └──requires──> [prompt_php_os()]
    └──requires──> [assemble_php_docker_image()]
    └──requires──> [SERVER_CONTACT prompt]
    └──calls──> [Composer create-project symfony/skeleton]  (new() only)
    └──copies──> [template/ directory contents]

[template/Dockerfile]
    └──requires──> [PHP version + OS selection from install.sh]
    └──uses──> [serversideup/php:{version}-frankenphp[-alpine] base image]

[docker-compose.yml]
    └──requires──> [Dockerfile] (build target reference)

[docker-compose.dev.yml]
    └──requires──> [docker-compose.yml] (overlay pattern)
    └──requires──> [.infrastructure/conf/traefik/dev/traefik.yml]
    └──requires──> [.infrastructure/conf/traefik/dev/traefik-certs.yml]
    └──requires──> [.infrastructure/conf/traefik/dev/certificates/] (pre-generated PEM files)

[docker-compose.prod.yml]
    └──requires──> [docker-compose.yml] (overlay pattern)
    └──requires──> [.infrastructure/conf/traefik/prod/traefik.yml]
    └──requires──> [SERVER_CONTACT] ──written-into──> [prod traefik.yml ACME email]

[FrankenPHP worker mode]
    └──requires──> [Symfony 7 LTS skeleton] (app must exist first)
    └──for <7.4──> [runtime/frankenphp-symfony composer package]
    └──for 7.4+──> [automatic via Runtime component, no extra package]
    └──configured-via──> [FRANKENPHP_CONFIG env var OR Caddyfile worker directive]

[Health check endpoint]
    └──required-by──> [docker-compose.prod.yml Traefik health check label]
    └──requires──> [Symfony skeleton] (route/controller must exist in app)
    └──unlike-laravel──> [no built-in /up route; must be created or bundled]

[Mailpit service]
    └──enhances──> [Symfony Mailer dev workflow]
    └──independent-of──> [PHP service] (standalone SMTP catcher)

[Node.js service]
    └──enhances──> [Asset compilation in dev]
    └──independent-of──> [PHP service]

[Named volumes in prod]
    └──requires──> [docker-compose.prod.yml]
    └──Symfony-paths-differ-from-Laravel──> [var/log/, var/cache/ instead of storage/]
```

### Dependency Notes

- **Health check requires Symfony skeleton:** Traefik's health check label in prod compose references a route that only exists after Symfony is installed. The template must either ship a minimal health controller or document that users must configure one.
- **FrankenPHP worker mode behavior changes at Symfony 7.4:** The Symfony 7 LTS line currently sits at 7.2.x; 7.4 (where worker mode becomes automatic) is not yet released as of research date. Template must handle the `runtime/frankenphp-symfony` package installation for current 7.x until 7.4 ships.
- **Alpine conflicts with FrankenPHP + Symfony JIT:** Alpine uses musl libc which disables JIT; FrankenPHP also requires a larger stack size on Alpine for Symfony. Debian is the safe default; Alpine is a valid but lower-performance opt-in.
- **UID/GID mapping depends on development stage:** The `docker-php-serversideup-set-id` call only happens in the `development` Dockerfile stage; the `deploy` stage runs as www-data with fixed ownership from `COPY --chown`.
- **Prod volume paths are Symfony-specific:** Laravel uses `storage/app/private`, `storage/logs`, etc. Symfony uses `var/log/`, `var/cache/`. The prod compose named volumes must reflect Symfony's directory layout.

## MVP Definition

### Launch With (v1)

Minimum viable product — what `spin new symfony` must deliver to be usable.

- [ ] `meta.yml` — without it, Spin CLI cannot register or discover the template
- [ ] `install.sh` with `new()` and `init()`, PHP version prompt (8.3/8.4/8.5), OS prompt (debian/alpine with warning), `SERVER_CONTACT` prompt — the interactive setup experience is the product
- [ ] `template/Dockerfile` with base, development, ci, deploy stages using `serversideup/php:*-frankenphp` images — image must build successfully
- [ ] `template/docker-compose.yml` base with traefik + php services
- [ ] `template/docker-compose.dev.yml` with Traefik ports, self-signed SSL, volume mounts, Mailpit, Node service
- [ ] `template/docker-compose.prod.yml` with Swarm deploy, Let's Encrypt, named volumes, health check label, OPcache
- [ ] `.infrastructure/conf/traefik/dev/` with `traefik.yml`, `traefik-certs.yml`, and pre-generated PEM certificate pair
- [ ] `.infrastructure/conf/traefik/prod/traefik.yml` with Cloudflare trusted IPs and ACME resolver
- [ ] `.infrastructure/volume_data/.gitignore` to prevent committing runtime data
- [ ] Symfony 7 LTS skeleton installed via `composer create-project symfony/skeleton` during `new()`
- [ ] Health check route (minimal controller at `/up` or similar) so Traefik prod health check works out of the box
- [ ] FrankenPHP worker mode configured (via env vars in compose for current Symfony 7.x, or documented as automatic for 7.4+)

### Add After Validation (v1.x)

Features to add once the core template is working and user feedback arrives.

- [ ] Symfony-specific `AUTORUN` equivalent — serversideup images have Laravel automations but not Symfony; a post-start script to run `bin/console cache:warmup` or migrations could be added once users validate the pattern
- [ ] PHP extension selection prompt (mirrors Laravel basic's `post-install.sh` extension step) — add when users report needing bcmath, gd, intl etc. as common Symfony extensions

### Future Consideration (v2+)

Features to defer until basic template is validated and a "pro" variant is planned.

- [ ] Database service options (Postgres, MySQL, MariaDB, SQLite) — belongs in `spin-template-symfony-pro`
- [ ] Queue worker service configuration — complexity exceeds "basic" scope
- [ ] GitHub Actions CI/CD — per PROJECT.md out-of-scope decision
- [ ] Mercure hub integration — advanced real-time feature beyond basic template
- [ ] Xdebug pre-configuration — document env var approach instead

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| meta.yml + install.sh scaffolding | HIGH | LOW | P1 |
| Dockerfile multi-stage build | HIGH | MEDIUM | P1 |
| docker-compose.yml base | HIGH | LOW | P1 |
| docker-compose.dev.yml with Traefik + Mailpit | HIGH | MEDIUM | P1 |
| docker-compose.prod.yml with Swarm + Let's Encrypt | HIGH | MEDIUM | P1 |
| Traefik dev config + pre-generated SSL certs | HIGH | LOW | P1 |
| Traefik prod config + ACME | HIGH | LOW | P1 |
| .infrastructure/ directory structure | HIGH | LOW | P1 |
| Symfony skeleton install via Composer | HIGH | MEDIUM | P1 |
| Health check endpoint for Traefik | HIGH | MEDIUM | P1 |
| FrankenPHP worker mode config | MEDIUM | MEDIUM | P1 |
| Node.js dev service | MEDIUM | LOW | P1 |
| Named volumes (Symfony paths) in prod | HIGH | LOW | P1 |
| OPcache in prod compose | HIGH | LOW | P1 |
| PHP extension prompt in install.sh | MEDIUM | MEDIUM | P2 |
| Symfony cache warmup autorun | MEDIUM | MEDIUM | P2 |
| Database service | HIGH | HIGH | P3 (pro template) |
| GitHub Actions CI/CD | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration or separate template

## Competitor Feature Analysis

| Feature | dunglas/symfony-docker (official) | Generic PHP+Nginx Docker setups | This Template (Spin Symfony Basic) |
|---------|-----------------------------------|----------------------------------|-------------------------------------|
| FrankenPHP runtime | Yes (default, uses `dunglas/frankenphp` image) | No (fpm-nginx) | Yes (uses `serversideup/php` images) |
| Interactive setup wizard | No (manual edit required) | No | Yes (`install.sh` prompts) |
| Dev/prod compose overlay | Yes | Sometimes | Yes (mirrors Laravel basic pattern) |
| Traefik reverse proxy | No (Caddy built-in) | Varies | Yes (consistent with Spin ecosystem) |
| Let's Encrypt in prod | Yes (Caddy native) | Rarely | Yes (via Traefik ACME) |
| Docker Swarm prod model | No (plain compose) | No | Yes |
| Self-signed dev SSL | Yes (Caddy auto) | Rarely | Yes (pre-generated PEM via Traefik) |
| Mailpit for dev email | Yes (via Flex recipe) | Rarely | Yes |
| Node.js dev service | No | No | Yes |
| Database included | Yes (Postgres via Flex) | Varies | No (deliberate — keep it basic) |
| Mercure hub | Yes (via Flex) | No | No (anti-feature for basic scope) |
| serversideup image benefits | No | No | Yes (UID/GID tooling, security hardening, PHP defaults) |
| Spin CLI integration | No | No | Yes (meta.yml, SPIN_* env vars) |

## Sources

- Direct inspection: `serversideup/spin-template-laravel-basic` — Dockerfile, docker-compose.yml, docker-compose.dev.yml, docker-compose.prod.yml, install.sh, meta.yml, .infrastructure/ directory
- [serversideup/php FrankenPHP image documentation](https://serversideup.net/open-source/docker-php/docs/image-variations/frankenphp)
- [serversideup/php image selection guide](https://serversideup.net/open-source/docker-php/docs/getting-started/choosing-an-image)
- [serversideup/php Laravel automations](https://serversideup.net/open-source/docker-php/docs/framework-guides/laravel/automations)
- [FrankenPHP worker mode documentation](https://frankenphp.dev/docs/worker/)
- [FrankenPHP Docker images documentation](https://frankenphp.dev/docs/docker/)
- [dunglas/symfony-docker reference implementation](https://github.com/dunglas/symfony-docker)
- [Symfony 7.4 native FrankenPHP worker mode announcement](https://x.com/alexdaubois/status/1936016578866212894)
- [FrankenPHP Symfony benchmark: 45ms to 8ms](https://dev.to/mattleads/from-45ms-to-8ms-benchmarking-symfony-74-on-frankenphp-ekk)
- [Mailpit Docker image](https://hub.docker.com/r/axllent/mailpit)
- [Symfony using Docker docs](https://symfony.com/doc/current/setup/docker.html)
- [Symfony health check approaches](https://medium.com/@laurentmn/stop-routing-traffic-to-broken-containers-health-checks-for-symfony-docker-a0e2fe6b00fb)

---
*Feature research for: Docker-based Spin template (Symfony 7 LTS + FrankenPHP)*
*Researched: 2026-03-18*
