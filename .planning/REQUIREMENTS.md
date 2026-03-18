# Requirements: Spin Template Symfony

**Defined:** 2026-03-18
**Core Value:** Developers can run `spin new symfony` and get a working Symfony 7 LTS application with Traefik and production-ready Docker configuration in under a minute, with their choice of PHP runtime (FrankenPHP default, fpm-nginx, fpm-apache).

## v1 Requirements

### Dockerfile

- [ ] **DOCK-01**: Multi-stage Dockerfile with `base`, `development`, `ci`, and `deploy` targets using `serversideup/php` images
- [ ] **DOCK-02**: Dockerfile accepts `PHP_VERSION`, `PHP_VARIATION`, and `PHP_OS` build args to support configurable PHP version (8.3-8.5), runtime variation (frankenphp, fpm-nginx, fpm-apache), and OS (debian/alpine)
- [ ] **DOCK-03**: Development stage sets `USER_ID` and `GROUP_ID` args for host permission matching
- [ ] **DOCK-04**: Deploy stage copies application code, sets correct ownership to `www-data`
- [ ] **DOCK-05**: CI stage runs as root for pipeline compatibility

### Runtime Configuration

- [ ] **RT-01**: Template ships a Caddyfile for FrankenPHP variation with document root `/var/www/html/public` and internal ports 8080/8443
- [ ] **RT-02**: Health check endpoint available for all variations — Caddyfile `/healthz` for FrankenPHP, appropriate config for fpm-nginx/fpm-apache
- [ ] **RT-03**: `install.sh` patches Dockerfile, compose files, and Traefik labels based on selected runtime variation (port, scheme, health path)

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
- [ ] **PROD-05**: Prod compose configures Traefik health check using the appropriate health endpoint for the selected runtime
- [ ] **PROD-06**: Prod compose enables HTTPS via Let's Encrypt with HTTP→HTTPS redirect
- [ ] **PROD-07**: Prod compose Traefik labels adapt to selected runtime — FrankenPHP uses `loadbalancer.server.port=8443` with `scheme=https` and `SSL_MODE=full`; fpm-nginx/fpm-apache use `loadbalancer.server.port=8080` with `scheme=http`

### Traefik Configuration

- [ ] **TRAF-01**: Dev Traefik config uses Docker provider with file provider for SSL certificates
- [ ] **TRAF-02**: Dev Traefik includes self-signed SSL certificates for local HTTPS
- [ ] **TRAF-03**: Prod Traefik config uses Swarm provider with ACME HTTP-01 challenge for Let's Encrypt
- [ ] **TRAF-04**: Prod Traefik includes Cloudflare trusted IPs for proper client IP detection
- [ ] **TRAF-05**: `.infrastructure/` directory structure mirrors Laravel basic template (conf/traefik/dev/, conf/traefik/prod/, volume_data/)

### Spin Template Structure

- [ ] **SPIN-01**: `meta.yml` registers template with title, authors, description, and repository URL
- [ ] **SPIN-02**: `install.sh` implements `new()` and `init()` functions dispatched via `$SPIN_ACTION`
- [ ] **SPIN-03**: `install.sh` prompts user for PHP version (8.3, 8.4, 8.5)
- [ ] **SPIN-04**: `install.sh` prompts user for PHP variation (frankenphp default, fpm-nginx, fpm-apache)
- [ ] **SPIN-05**: `install.sh` prompts user for OS choice (debian default, alpine with performance warning for FrankenPHP)
- [ ] **SPIN-06**: `install.sh` prompts for server contact email (for Let's Encrypt)
- [ ] **SPIN-07**: `post-install.sh` installs Symfony 7 LTS skeleton via `composer create-project symfony/skeleton`
- [ ] **SPIN-08**: `post-install.sh` installs Composer dependencies via Docker container
- [ ] **SPIN-09**: All template files reside in `template/` directory

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
| DOCK-01 | Phase 1 | Pending |
| DOCK-02 | Phase 1 | Pending |
| DOCK-03 | Phase 1 | Pending |
| DOCK-04 | Phase 1 | Pending |
| DOCK-05 | Phase 1 | Pending |
| RT-01 | Phase 1 | Pending |
| RT-02 | Phase 1 | Pending |
| COMP-01 | Phase 2 | Pending |
| COMP-02 | Phase 2 | Pending |
| DEV-01 | Phase 2 | Pending |
| DEV-02 | Phase 2 | Pending |
| DEV-03 | Phase 2 | Pending |
| DEV-04 | Phase 2 | Pending |
| DEV-05 | Phase 2 | Pending |
| DEV-06 | Phase 2 | Pending |
| TRAF-01 | Phase 2 | Pending |
| TRAF-02 | Phase 2 | Pending |
| TRAF-05 | Phase 2 | Pending |
| SPIN-01 | Phase 3 | Pending |
| SPIN-02 | Phase 3 | Pending |
| SPIN-03 | Phase 3 | Pending |
| SPIN-04 | Phase 3 | Pending |
| SPIN-05 | Phase 3 | Pending |
| SPIN-06 | Phase 3 | Pending |
| SPIN-07 | Phase 3 | Pending |
| SPIN-08 | Phase 3 | Pending |
| SPIN-09 | Phase 3 | Pending |
| RT-03 | Phase 3 | Pending |
| PROD-01 | Phase 4 | Pending |
| PROD-02 | Phase 4 | Pending |
| PROD-03 | Phase 4 | Pending |
| PROD-04 | Phase 4 | Pending |
| PROD-05 | Phase 4 | Pending |
| PROD-06 | Phase 4 | Pending |
| PROD-07 | Phase 4 | Pending |
| TRAF-03 | Phase 4 | Pending |
| TRAF-04 | Phase 4 | Pending |
| DOC-01 | Phase 4 | Pending |
| DOC-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 39 total
- Mapped to phases: 39
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after runtime flexibility adjustment; traceability fully mapped*
