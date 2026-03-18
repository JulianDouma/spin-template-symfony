# Requirements: Spin Template Symfony

**Defined:** 2026-03-18
**Core Value:** Developers can run `spin new symfony` and get a working Symfony 7 LTS application with FrankenPHP, Traefik, and production-ready Docker configuration in under a minute.

## v1 Requirements

### Dockerfile

- [ ] **DOCK-01**: Multi-stage Dockerfile with `base`, `development`, `ci`, and `deploy` targets using `serversideup/php:*-frankenphp` images
- [ ] **DOCK-02**: Dockerfile accepts `PHP_VERSION` and `PHP_OS` build args to support configurable PHP version (8.3-8.5) and OS (debian/alpine)
- [ ] **DOCK-03**: Development stage sets `USER_ID` and `GROUP_ID` args for host permission matching
- [ ] **DOCK-04**: Deploy stage copies application code, sets correct ownership to `www-data`
- [ ] **DOCK-05**: CI stage runs as root for pipeline compatibility

### Caddyfile

- [ ] **CADDY-01**: Caddyfile sets document root to `/var/www/html/public` (Symfony's public directory)
- [ ] **CADDY-02**: FrankenPHP listens on internal ports 8080 (HTTP) and 8443 (HTTPS), not 80/443
- [ ] **CADDY-03**: Caddyfile includes a `/healthz` endpoint that returns 200 OK for Traefik health monitoring

### Compose Base

- [ ] **COMP-01**: `docker-compose.yml` defines the `php` service with Symfony-appropriate configuration
- [ ] **COMP-02**: Base compose file is minimal and designed to be extended by dev/prod overlays

### Compose Development

- [ ] **DEV-01**: `docker-compose.dev.yml` includes Traefik reverse proxy on ports 80/443
- [ ] **DEV-02**: Dev compose mounts entire project directory into container for live editing
- [ ] **DEV-03**: Dev compose uses a named volume overlay for `var/` to prevent cache/log performance issues with bind mounts
- [ ] **DEV-04**: Dev compose builds from Dockerfile with `development` target
- [ ] **DEV-05**: Dev compose includes Mailpit service on port 8025 for email testing
- [ ] **DEV-06**: Dev compose defines a `development` network for service communication

### Compose Production

- [ ] **PROD-01**: `docker-compose.prod.yml` uses Docker Swarm mode with deployment constraints
- [ ] **PROD-02**: Prod compose uses pre-built image (not Dockerfile build) for deployment
- [ ] **PROD-03**: Prod compose includes named volumes for `var/log`, `var/cache`, and Let's Encrypt certificates
- [ ] **PROD-04**: Prod compose sets `APP_ENV=prod`, `PHP_OPCACHE_ENABLE=1`
- [ ] **PROD-05**: Prod compose configures Traefik health check using `/healthz` endpoint
- [ ] **PROD-06**: Prod compose enables HTTPS via Let's Encrypt with HTTP→HTTPS redirect
- [ ] **PROD-07**: Prod compose uses `SSL_MODE=full` for FrankenPHP HTTPS passthrough (`loadbalancer.server.port=8443`, `scheme=https`)

### Traefik Configuration

- [ ] **TRAF-01**: Dev Traefik config uses Docker provider with file provider for SSL certificates
- [ ] **TRAF-02**: Dev Traefik includes self-signed SSL certificates for local HTTPS
- [ ] **TRAF-03**: Prod Traefik config uses Swarm provider with ACME HTTP-01 challenge for Let's Encrypt
- [ ] **TRAF-04**: Prod Traefik includes Cloudflare trusted IPs for proper client IP detection
- [ ] **TRAF-05**: `.infrastructure/` directory structure mirrors Laravel basic template (conf/traefik/dev/, conf/traefik/prod/, volume_data/)

### Spin Template Structure

- [ ] **SPIN-01**: `meta.yml` registers template with title, authors, description, and repository URL
- [ ] **SPIN-02**: `install.sh` implements `new()` and `init()` functions dispatched via `$SPIN_ACTION`
- [ ] **SPIN-03**: `install.sh` prompts user for PHP version (8.3, 8.4, 8.5), with FrankenPHP as default runtime
- [ ] **SPIN-04**: `install.sh` prompts user for OS choice (debian default, alpine with performance warning)
- [ ] **SPIN-05**: `install.sh` prompts for server contact email (for Let's Encrypt)
- [ ] **SPIN-06**: `post-install.sh` installs Symfony 7 LTS skeleton via `composer create-project symfony/skeleton`
- [ ] **SPIN-07**: `post-install.sh` installs Composer dependencies via Docker container
- [ ] **SPIN-08**: All template files reside in `template/` directory

### Documentation

- [ ] **DOC-01**: README.md with installation instructions, required configuration changes, and running commands
- [ ] **DOC-02**: `.env.example` with Symfony-appropriate environment variables (APP_ENV, APP_SECRET, APP_URL)

## v2 Requirements

### Worker Mode

- **WORK-01**: Optional FrankenPHP worker mode configuration via `runtime/frankenphp-symfony` package
- **WORK-02**: Documentation for enabling/disabling worker mode

### Additional Services

- **SVC-01**: Optional PostgreSQL service in compose
- **SVC-02**: Optional MySQL/MariaDB service in compose
- **SVC-03**: Optional Redis service for caching/sessions

### CI/CD

- **CI-01**: GitHub Actions workflow for building and deploying

## Out of Scope

| Feature | Reason |
|---------|--------|
| Database services | Users add their own based on project needs |
| Redis/cache services | Same rationale as database |
| Webpack Encore / AssetMapper | Users choose their own frontend tooling |
| Pro template features | Belongs in a separate spin-template-symfony-pro |
| Symfony Flex recipes | Users customize post-install |
| Node service in dev compose | Not included in basic scope; users add if needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCK-01 | — | Pending |
| DOCK-02 | — | Pending |
| DOCK-03 | — | Pending |
| DOCK-04 | — | Pending |
| DOCK-05 | — | Pending |
| CADDY-01 | — | Pending |
| CADDY-02 | — | Pending |
| CADDY-03 | — | Pending |
| COMP-01 | — | Pending |
| COMP-02 | — | Pending |
| DEV-01 | — | Pending |
| DEV-02 | — | Pending |
| DEV-03 | — | Pending |
| DEV-04 | — | Pending |
| DEV-05 | — | Pending |
| DEV-06 | — | Pending |
| PROD-01 | — | Pending |
| PROD-02 | — | Pending |
| PROD-03 | — | Pending |
| PROD-04 | — | Pending |
| PROD-05 | — | Pending |
| PROD-06 | — | Pending |
| PROD-07 | — | Pending |
| TRAF-01 | — | Pending |
| TRAF-02 | — | Pending |
| TRAF-03 | — | Pending |
| TRAF-04 | — | Pending |
| TRAF-05 | — | Pending |
| SPIN-01 | — | Pending |
| SPIN-02 | — | Pending |
| SPIN-03 | — | Pending |
| SPIN-04 | — | Pending |
| SPIN-05 | — | Pending |
| SPIN-06 | — | Pending |
| SPIN-07 | — | Pending |
| SPIN-08 | — | Pending |
| DOC-01 | — | Pending |
| DOC-02 | — | Pending |

**Coverage:**
- v1 requirements: 38 total
- Mapped to phases: 0
- Unmapped: 38 ⚠️

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after initial definition*
