# Phase 4: Production and Ship - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Production Docker Compose with Swarm deployment, Traefik ACME SSL, per-runtime label patching. Plus `.spin.yml` starter, `.env.example`, and README documentation. This is the final phase — after this, the template is shippable.

</domain>

<decisions>
## Implementation Decisions

### Prod Compose + Swarm
- Ship FrankenPHP labels by default (`loadbalancer.server.port=8443`, `scheme=https`, `SSL_MODE=full`)
- `post-install.sh` patches labels to `port=8080`/`scheme=http` when user selects fpm-nginx or fpm-apache (install-time patching — consistent with Spin ecosystem pattern)
- Docker Swarm mode with deployment constraints, rolling updates, failure rollback
- Named volumes: `symfony_var` for `var/` (logs + cache combined), `certificates` for Let's Encrypt ACME data
- Pre-built image (not Dockerfile build) — uses `${SPIN_IMAGE_NAME}` variable
- Environment: `APP_ENV=prod`, `PHP_OPCACHE_ENABLE=1`
- Health check using serversideup built-in `/healthcheck`
- `HEALTHCHECK_PATH=/healthcheck` in Traefik labels

### .spin.yml
- Minimal scaffold with `server_contact: changeme@example.com` placeholder (patched by post-install.sh)
- One example server, one environment (production)
- Enough structure to get started without being overwhelming
- Reference: https://serversideup.net/open-source/spin/docs/server-configuration/spin-yml-usage

### Traefik Prod Config
- Mirror the Laravel template's approach: Swarm provider, ACME HTTP-01 challenge resolver, Cloudflare trusted IPs
- `changeme@example.com` placeholder for ACME email (patched by post-install.sh)
- HTTP→HTTPS redirect via entrypoint configuration
- File lives at `template/.infrastructure/conf/traefik/prod/traefik.yml` (replacing the current `.gitignore` stub)

### README
- Mirror the Laravel README structure: installation, required changes, running commands, advanced config
- Include a short Mailpit add-on section (3-4 lines: compose service definition + `MAILER_DSN` env var)
- Document all Spin commands (`spin up`, `spin deploy`, `spin run`, `spin exec`)
- Document the per-runtime label differences and how to switch runtimes after install

### .env.example
- Include Symfony defaults + Spin-specific variables: `APP_ENV`, `APP_SECRET`, `APP_URL`, `DATABASE_URL` placeholder, `MAILER_DSN` placeholder
- `APP_SECRET` generated at install time by `post-install.sh` (random hex string — one less manual step)
- `APP_URL=https://localhost` as default
- Commented-out `DATABASE_URL` with examples for PostgreSQL, MySQL, SQLite

### post-install.sh Updates (Phase 3 file, patched here)
- Add prod label patching logic: if `SPIN_PHP_VARIATION != "frankenphp"`, patch `loadbalancer.server.port` and `scheme` labels in `docker-compose.prod.yml`
- Add `APP_SECRET` generation: `openssl rand -hex 16` or `php -r "echo bin2hex(random_bytes(16));"` and patch into `.env`
- Patch `changeme@example.com` in `.spin.yml` with `SERVER_CONTACT` (already has `--ignore-missing`)

### Claude's Discretion
- Exact Swarm deploy config (replicas, update_config, rollback_config)
- README formatting and section ordering
- `.spin.yml` exact field structure beyond server_contact
- Cloudflare IP ranges in Traefik prod config (copy from Laravel template)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spin Template Reference
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml` — Laravel prod compose with Swarm config, Traefik labels, named volumes
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/.infrastructure/conf/traefik/prod/traefik.yml` — Laravel prod Traefik config with ACME + Cloudflare IPs
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/README.md` — Laravel README structure

### Spin Configuration
- https://serversideup.net/open-source/spin/docs/server-configuration/spin-yml-usage — Official .spin.yml docs

### Phase 1-3 Outputs
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/Dockerfile` — Deploy target this compose references
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/docker-compose.yml` — Base compose this overlay extends
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/docker-compose.dev.yml` — Dev compose for pattern reference
- `/Users/juliandouma/Developer/oss/spin-template-symfony/post-install.sh` — Needs updates for prod label patching + APP_SECRET generation
- `/Users/juliandouma/Developer/oss/spin-template-symfony/install.sh` — Exports SPIN_PHP_VARIATION used by prod label patching

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `template/.infrastructure/conf/traefik/prod/.gitignore` — Will be replaced by actual `traefik.yml`
- `post-install.sh` — Already has `line_in_file` patching for Dockerfile ARGs and email; needs extension for prod compose labels + APP_SECRET
- `template/docker-compose.dev.yml` — Pattern reference for compose structure, Traefik labels, network naming

### Established Patterns
- `line_in_file --action replace` for patching known lines
- `line_in_file --action exact --ignore-missing` for email patching across multiple files
- serversideup/php env vars for runtime config
- FrankenPHP: port 8443/scheme https; fpm-*: port 8080/scheme http

### Integration Points
- `docker-compose.prod.yml` extends `docker-compose.yml` (base) — same as dev overlay pattern
- `post-install.sh` patches prod compose labels based on `$SPIN_PHP_VARIATION`
- `.spin.yml` gets `SERVER_CONTACT` email patched by `post-install.sh`
- Traefik prod `traefik.yml` gets email patched by `post-install.sh`

</code_context>

<specifics>
## Specific Ideas

- APP_SECRET auto-generation is a nice DX improvement over the Laravel template (which requires manual APP_KEY generation)
- README should include a Mailpit add-on section since we decided not to ship it as a service
- The prod label patching in post-install.sh should handle both the port AND scheme in a single conditional block

</specifics>

<deferred>
## Deferred Ideas

- Configurable local domain / mkcert (from Phase 2 discussion)
- Node service for frontend assets
- Worker mode documentation for FrankenPHP

</deferred>

---

*Phase: 04-production-and-ship*
*Context gathered: 2026-03-19*
