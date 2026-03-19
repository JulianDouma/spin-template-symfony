# Phase 4: Production and Ship - Research

**Researched:** 2026-03-19
**Domain:** Docker Swarm production compose, Traefik v3 ACME SSL, Spin template scaffold, Symfony env config
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Prod Compose + Swarm**
- Ship FrankenPHP labels by default (`loadbalancer.server.port=8443`, `scheme=https`, `SSL_MODE=full`)
- `post-install.sh` patches labels to `port=8080`/`scheme=http` when user selects fpm-nginx or fpm-apache (install-time patching — consistent with Spin ecosystem pattern)
- Docker Swarm mode with deployment constraints, rolling updates, failure rollback
- Named volumes: `symfony_var` for `var/` (logs + cache combined), `certificates` for Let's Encrypt ACME data
- Pre-built image (not Dockerfile build) — uses `${SPIN_IMAGE_NAME}` variable
- Environment: `APP_ENV=prod`, `PHP_OPCACHE_ENABLE=1`
- Health check using serversideup built-in `/healthcheck`
- `HEALTHCHECK_PATH=/healthcheck` in Traefik labels

**.spin.yml**
- Minimal scaffold with `server_contact: changeme@example.com` placeholder (patched by post-install.sh)
- One example server, one environment (production)
- Enough structure to get started without being overwhelming

**Traefik Prod Config**
- Mirror the Laravel template's approach: Swarm provider, ACME HTTP-01 challenge resolver, Cloudflare trusted IPs
- `changeme@example.com` placeholder for ACME email (patched by post-install.sh)
- HTTP→HTTPS redirect via entrypoint configuration
- File lives at `template/.infrastructure/conf/traefik/prod/traefik.yml` (replacing the current `.gitignore` stub)

**README**
- Mirror the Laravel README structure: installation, required changes, running commands, advanced config
- Include a short Mailpit add-on section (3-4 lines: compose service definition + `MAILER_DSN` env var)
- Document all Spin commands (`spin up`, `spin deploy`, `spin run`, `spin exec`)
- Document the per-runtime label differences and how to switch runtimes after install

**.env.example**
- Include Symfony defaults + Spin-specific variables: `APP_ENV`, `APP_SECRET`, `APP_URL`, `DATABASE_URL` placeholder, `MAILER_DSN` placeholder
- `APP_SECRET` generated at install time by `post-install.sh` (random hex string — one less manual step)
- `APP_URL=https://localhost` as default
- Commented-out `DATABASE_URL` with examples for PostgreSQL, MySQL, SQLite

**post-install.sh Updates (Phase 3 file, patched here)**
- Add prod label patching logic: if `SPIN_PHP_VARIATION != "frankenphp"`, patch `loadbalancer.server.port` and `scheme` labels in `docker-compose.prod.yml`
- Add `APP_SECRET` generation: `openssl rand -hex 16` or `php -r "echo bin2hex(random_bytes(16));"` and patch into `.env`
- Patch `changeme@example.com` in `.spin.yml` with `SERVER_CONTACT` (already has `--ignore-missing`)

### Claude's Discretion
- Exact Swarm deploy config (replicas, update_config, rollback_config)
- README formatting and section ordering
- `.spin.yml` exact field structure beyond server_contact
- Cloudflare IP ranges in Traefik prod config (copy from Laravel template)

### Deferred Ideas (OUT OF SCOPE)
- Configurable local domain / mkcert (from Phase 2 discussion)
- Node service for frontend assets
- Worker mode documentation for FrankenPHP
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PROD-01 | `docker-compose.prod.yml` uses Docker Swarm mode with deployment constraints | Laravel prod compose confirms: `deploy.placement.constraints`, `update_config`, `rollback_config`, `restart_policy` pattern |
| PROD-02 | Prod compose uses pre-built image (not Dockerfile build) for deployment | Laravel pattern: `image: ${SPIN_IMAGE_DOCKERFILE}` — adapt to `${SPIN_IMAGE_NAME}` per CONTEXT.md |
| PROD-03 | Prod compose includes named volumes for `var/` and Let's Encrypt certificates | Named volumes: `symfony_var` (for `/var/www/html/var`) + `certificates` (for `/certificates`) — mirrors Laravel's storage/certificates pattern |
| PROD-04 | Prod compose sets `APP_ENV=prod`, `PHP_OPCACHE_ENABLE=1` | Directly confirmed from Laravel prod compose environment block |
| PROD-05 | Prod compose configures Traefik health check using the appropriate health endpoint | `HEALTHCHECK_PATH=/healthcheck` env var + Traefik `healthcheck.path=/healthcheck` + `healthcheck.scheme=http` label |
| PROD-06 | Prod compose enables HTTPS via Let's Encrypt with HTTP→HTTPS redirect | `tls.certresolver=letsencryptresolver` label + Traefik traefik.yml HTTP redirect entrypoint |
| PROD-07 | Prod compose Traefik labels adapt to selected runtime — FrankenPHP vs fpm-* | FrankenPHP default: `port=8443`, `scheme=https`; fpm-*: `port=8080`, `scheme=http` — post-install.sh patches at install time |
| TRAF-03 | Prod Traefik config uses Swarm provider with ACME HTTP-01 challenge for Let's Encrypt | Confirmed from Laravel traefik.yml: `providers.swarm`, `certificatesResolvers.letsencryptresolver.acme.httpChallenge` |
| TRAF-04 | Prod Traefik includes Cloudflare trusted IPs for proper client IP detection | Full Cloudflare IP list confirmed in Laravel traefik.yml — 21 ranges to copy verbatim |
| SPIN-10 | Starter `.spin.yml` with sensible defaults and `changeme@example.com` placeholder | `.spin.yml` structure documented from official Spin docs; `server_contact` is a top-level field |
| DOC-01 | README.md with installation instructions, required configuration changes, and running commands | Laravel README structure confirmed — 6 sections, mirror directly with Symfony specifics |
| DOC-02 | `.env.example` with Symfony-appropriate environment variables | `APP_ENV`, `APP_SECRET`, `APP_URL`, `DATABASE_URL`, `MAILER_DSN` confirmed from CONTEXT.md decisions |
</phase_requirements>

---

## Summary

This phase ships four new files and extends one existing file to make the Symfony template production-deployable. The central deliverable is `docker-compose.prod.yml` which uses Docker Swarm mode with Traefik ACME SSL. The prod compose ships FrankenPHP labels by default (`port=8443`, `scheme=https`) and `post-install.sh` patches them to `port=8080`/`scheme=http` for fpm-nginx and fpm-apache at install time.

The Traefik prod config (`template/.infrastructure/conf/traefik/prod/traefik.yml`) is a near-exact copy of the Laravel template's config: Swarm provider, HTTP-01 ACME challenge, Cloudflare trusted IPs, HTTP→HTTPS redirect. The only Symfony-specific divergences are the `changeme@example.com` placeholder and the `insecureSkipVerify: true` for FrankenPHP's internal TLS backend.

Three supporting deliverables round out the phase: a minimal `.spin.yml` scaffold, a `.env.example` with Symfony defaults, and a README mirroring the Laravel template structure. The `post-install.sh` receives targeted additions (prod label patching + `APP_SECRET` generation) without restructuring the existing script.

**Primary recommendation:** Mirror the Laravel prod compose and Traefik config as closely as possible — the ecosystem patterns are already proven. The only Symfony-specific differences are volume names, the healthcheck path, the Symfony-appropriate env vars, and the FrankenPHP/fpm label divergence.

---

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| traefik | v3.6 (pinned in base compose) | Reverse proxy, ACME SSL, routing | Already used in dev; Spin ecosystem standard |
| Docker Swarm | built-in | Container orchestration for production | `spin deploy` targets Swarm; no extra tooling needed |
| Let's Encrypt (ACME HTTP-01) | — | Free SSL certificates | Standard Spin/serversideup pattern; zero cert management overhead |
| serversideup/php | (from Dockerfile) | Runtime image — deploy target | Defined in Dockerfile; prod compose references built image |

### Key Environment Variables (prod compose)
| Variable | Value | Source |
|----------|-------|--------|
| `APP_ENV` | `prod` | CONTEXT.md locked decision |
| `PHP_OPCACHE_ENABLE` | `1` | CONTEXT.md locked decision |
| `SSL_MODE` | `full` | FrankenPHP TLS passthrough to Traefik |
| `HEALTHCHECK_PATH` | `/healthcheck` | serversideup/php built-in endpoint |
| `CADDY_SERVER_ROOT` | `/var/www/html/public` | Symfony public dir (same as dev) |

---

## Architecture Patterns

### Prod Compose Structure

The prod compose is an overlay that extends `docker-compose.yml` (base). It follows the identical overlay pattern to `docker-compose.dev.yml`.

```
template/
├── docker-compose.yml              # base: traefik image pinned, php depends_on
├── docker-compose.dev.yml          # dev overlay: build, bind mounts, dev labels
├── docker-compose.prod.yml         # prod overlay: Swarm deploy, pre-built image, Traefik labels
├── .infrastructure/
│   └── conf/traefik/
│       ├── dev/traefik.yml         # already exists
│       └── prod/traefik.yml        # NEW — replaces .gitignore stub
├── .spin.yml                       # NEW — minimal Spin scaffold
├── .env.example                    # NEW — Symfony env defaults
└── ...
```

### Pattern 1: Docker Swarm Deploy Block

**What:** Every Swarm service needs a `deploy:` block with placement, update, rollback, and restart policy.

**When to use:** All services in a prod compose targeting `docker stack deploy`.

```yaml
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml
deploy:
  replicas: 1
  update_config:
    failure_action: rollback
    parallelism: 1
    delay: 5s
    order: start-first
  rollback_config:
    parallelism: 0
    order: stop-first
  restart_policy:
    condition: any
    delay: 10s
    max_attempts: 3
    window: 120s
```

Note: `order: start-first` for `update_config` means the new container starts before the old one stops — enables zero-downtime rolling updates. Traefik must be `order: stop-first` (stateful — only one can hold port 80/443 at a time).

### Pattern 2: Traefik Labels in Swarm Mode

**What:** In Swarm mode, Traefik labels MUST be under `deploy.labels`, NOT under `labels`. This is a hard Swarm requirement — top-level `labels` are not visible to the Swarm provider.

**Critical:** The dev compose uses top-level `labels:` (Docker provider reads these). The prod compose MUST use `deploy.labels:` (Swarm provider reads these).

```yaml
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml
deploy:
  ...
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.symfony.rule=Host(`${SPIN_APP_DOMAIN}`)"
    - "traefik.http.routers.symfony.entrypoints=websecure"
    - "traefik.http.routers.symfony.tls=true"
    - "traefik.http.routers.symfony.tls.certresolver=letsencryptresolver"
    # FrankenPHP defaults (patched to port=8080/scheme=http for fpm-*)
    - "traefik.http.services.symfony.loadbalancer.server.port=8443"
    - "traefik.http.services.symfony.loadbalancer.server.scheme=https"
    # Health check
    - "traefik.http.services.symfony.loadbalancer.healthcheck.path=/healthcheck"
    - "traefik.http.services.symfony.loadbalancer.healthcheck.interval=30s"
    - "traefik.http.services.symfony.loadbalancer.healthcheck.timeout=5s"
    - "traefik.http.services.symfony.loadbalancer.healthcheck.scheme=http"
```

Note: `healthcheck.scheme=http` is correct even for FrankenPHP — the healthcheck goes directly to the container on the Traefik side of the loopback, before TLS termination. Confirmed from Laravel template pattern.

### Pattern 3: Docker Swarm `configs:` Section

**What:** `docker stack deploy` cannot use host-mounted files (no bind mounts in Swarm). Traefik config is delivered via Docker Swarm configs, not a volume mount.

**Why:** The `configs:` section creates an immutable, content-addressed config object in Swarm. The MD5 hash in the config name forces a config update whenever `traefik.yml` changes — this is how `spin deploy` detects Traefik config changes.

```yaml
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml
configs:
  traefik:
    name: "traefik-${SPIN_MD5_HASH_TRAEFIK_YML}.yml"
    file: ./.infrastructure/conf/traefik/prod/traefik.yml

services:
  traefik:
    configs:
      - source: traefik
        target: /etc/traefik/traefik.yml
```

`SPIN_MD5_HASH_TRAEFIK_YML` is computed by `spin deploy` automatically. Developers must not change the variable name.

### Pattern 4: Traefik Prod Config Structure

```yaml
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/.infrastructure/conf/traefik/prod/traefik.yml

# YAML anchors for Cloudflare IP list (DRY)
x-trustedIps: &trustedIPs
  - "173.245.48.0/20"
  # ... 20 more ranges

serversTransport:
  insecureSkipVerify: true   # Required: FrankenPHP uses self-signed internal cert

providers:
  swarm:                     # NOT docker: — Swarm provider required for labels in deploy block
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https      # HTTP→HTTPS redirect
    forwardedHeaders:
      trustedIPs: *trustedIPs
    proxyProtocol:
      trustedIPs: *trustedIPs
  websecure:
    address: ":443"
    forwardedHeaders:
      trustedIPs: *trustedIPs
    proxyProtocol:
      trustedIPs: *trustedIPs

certificatesResolvers:
  letsencryptresolver:
    acme:
      email: "changeme@example.com"   # MUST be this exact string — post-install.sh patches it
      storage: "/certificates/acme.json"
      httpChallenge:
        entryPoint: web
```

### Pattern 5: FrankenPHP vs fpm-* Label Divergence

**What:** FrankenPHP serves HTTPS natively on port 8443. Traefik must talk HTTPS to it. fpm-nginx and fpm-apache serve HTTP on port 8080.

| Runtime | Port | Scheme | SSL_MODE env |
|---------|------|--------|--------------|
| frankenphp | 8443 | https | full |
| fpm-nginx | 8080 | http | (not set) |
| fpm-apache | 8080 | http | (not set) |

**post-install.sh patch logic:**

```bash
# In post-install.sh — add after Dockerfile ARG patching
if [[ "$SPIN_PHP_VARIATION" != "frankenphp" ]]; then
    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.server.port=' \
        '      - "traefik.http.services.symfony.loadbalancer.server.port=8080"'

    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.server.scheme=' \
        '      - "traefik.http.services.symfony.loadbalancer.server.scheme=http"'
fi
```

Note: The `line_in_file --action replace` uses prefix matching on the search string. The exact indentation in the replacement string matters for valid YAML.

### Pattern 6: APP_SECRET Generation in post-install.sh

**What:** Symfony requires a random `APP_SECRET` (32 hex chars = 16 bytes). Generate at install time, patch into `.env`.

```bash
# Generate APP_SECRET and write to .env
APP_SECRET=$(openssl rand -hex 16)

line_in_file --action replace \
    --file "$project_dir/.env" \
    'APP_SECRET=' \
    "APP_SECRET=${APP_SECRET}"
```

`openssl rand -hex 16` produces a 32-character hex string. This is the Symfony-standard length (16 bytes = 128 bits). The `.env.example` ships `APP_SECRET=` (empty) as the placeholder — the install patches the generated value into `.env` (copied from `.env.example` by `post-install.sh` or by the developer).

**Important:** post-install.sh currently patches `.env` only if `SPIN_INSTALL_DEPENDENCIES=true` (the Composer install block). The APP_SECRET patch must run unconditionally — Symfony cannot start without it.

### Pattern 7: .spin.yml Minimal Scaffold

```yaml
# .spin.yml — lives in template/ directory
# Source: https://serversideup.net/open-source/spin/docs/server-configuration/spin-yml-usage

server_contact: changeme@example.com   # Patched by post-install.sh
server_timezone: "Etc/UTC"
use_passwordless_sudo: true

users:
  - username: spin
    name: Spin User
    groups: ['sudo']
    authorized_keys:
      - public_key: "~/.ssh/id_ed25519.pub"

servers:
  - server_name: web-1
    environment: production
    hardware_profile: your_hardware_profile

environments:
  - name: production
```

Required fields: `users`, `servers`, `environments`, `server_contact`. The `hardware_profiles:` section can be omitted from the scaffold — developers fill it in based on their VPS provider. Comment the file heavily to guide first-time users.

### Pattern 8: Traefik Port Mode in Swarm

**What:** In Swarm, Traefik ports must use `mode: host` to bind directly to the host network interface (not through the Swarm load balancer). Without this, Traefik cannot get the real client IP for Cloudflare proxy detection.

```yaml
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml
traefik:
  ports:
    - target: 80
      published: 80
      protocol: tcp
      mode: host
    - target: 443
      published: 443
      protocol: tcp
      mode: host
```

### Anti-Patterns to Avoid

- **Top-level `labels:` in prod compose:** Swarm provider ignores them. Must be under `deploy.labels:`.
- **`providers.docker:` in prod Traefik config:** Docker standalone provider cannot read Swarm deploy labels. Use `providers.swarm:`.
- **`mode: ingress` (default) for Traefik ports:** Loses real client IP. Use `mode: host`.
- **Generating APP_SECRET inside the `if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]` block:** It must run unconditionally so `spin init` users also get a patched secret.
- **Omitting `insecureSkipVerify: true` from prod Traefik config:** FrankenPHP uses self-signed TLS internally; without this, Traefik refuses to connect to the backend.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ACME SSL certificate management | Custom cert renewal scripts | Traefik ACME + Let's Encrypt (built into prod `traefik.yml`) | Handles HTTP-01 challenge, renewal, storage atomically |
| Service discovery in Swarm | Health poll scripts | Docker Swarm restart policy + Traefik healthcheck labels | Swarm handles restarts; Traefik drains unhealthy before routing |
| Config versioning in Swarm | Dated config file names | MD5-hashed Docker config name (`traefik-${SPIN_MD5_HASH_TRAEFIK_YML}.yml`) | `spin deploy` computes hash automatically; stale configs get replaced |
| APP_SECRET generation | PHP random_bytes implementation | `openssl rand -hex 16` in bash | POSIX-available, no PHP dependency at template install time |
| Cloudflare IP detection | Custom X-Forwarded-For parsing | Traefik `forwardedHeaders.trustedIPs` + `proxyProtocol.trustedIPs` | Handles IPv4 + IPv6 Cloudflare ranges; maintained as a static list |

---

## Common Pitfalls

### Pitfall 1: Swarm Labels in Wrong Location
**What goes wrong:** Traefik labels placed under top-level `labels:` are invisible to the Swarm provider. No routing rules are registered; the service gets no traffic.
**Why it happens:** Dev compose correctly uses top-level `labels:` (Docker standalone provider). Swarm requires `deploy.labels:`.
**How to avoid:** Always use `deploy.labels:` in any service within a prod Swarm compose file.
**Warning signs:** Traefik dashboard shows no routes registered for the service after `docker stack deploy`.

### Pitfall 2: Missing `insecureSkipVerify: true` for FrankenPHP
**What goes wrong:** Traefik tries to verify the TLS certificate of the FrankenPHP backend. FrankenPHP's internal cert is self-signed. Traefik fails with a certificate verification error and returns 502 to the client.
**Why it happens:** FrankenPHP v2+ uses HTTP/2 internally with self-signed TLS. Traefik's default is to verify upstream certs.
**How to avoid:** Always include `serversTransport: insecureSkipVerify: true` in the prod Traefik config (mirror Laravel template exactly).
**Warning signs:** 502 Bad Gateway from Traefik when `scheme=https` is set in service labels.

### Pitfall 3: Traefik Port Mode Defaulting to Ingress
**What goes wrong:** With `mode: ingress` (the default short-form `"80:80"` syntax), Swarm routes traffic through the internal mesh. The real client IP is replaced by the Swarm mesh IP. Cloudflare proxy detection fails.
**Why it happens:** Short port syntax `"80:80"` always means `mode: ingress`. Only long-form syntax supports `mode: host`.
**How to avoid:** Use the long-form port syntax with `mode: host` for all Traefik ports (copy Laravel pattern).

### Pitfall 4: APP_SECRET Generation Conditional on SPIN_INSTALL_DEPENDENCIES
**What goes wrong:** If a developer runs `spin init` without `SPIN_INSTALL_DEPENDENCIES=true`, or uses the template in a CI context, the APP_SECRET patch never runs. The `.env` ships with an empty `APP_SECRET=` and Symfony refuses to start.
**Why it happens:** post-install.sh currently wraps the Composer install block with `if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]`. Naive placement of the APP_SECRET logic inside that block would make it conditional.
**How to avoid:** Place APP_SECRET generation OUTSIDE the `SPIN_INSTALL_DEPENDENCIES` guard, unconditionally.

### Pitfall 5: post-install.sh Patches .env Before .env Exists
**What goes wrong:** `line_in_file` fails if `.env` does not yet exist when the patch runs. The `.env` file is created by `composer create-project` (via the Symfony skeleton's `make:env` recipe) — it runs before `post-install.sh` for `new` action, but may not exist for `init` action if dependencies weren't installed.
**Why it happens:** `.env` is a project file, not a template file. It's generated by Composer during project creation.
**How to avoid:** Use `--ignore-missing` flag if patching `.env` that may not exist, OR only patch if the file exists: `[[ -f "$project_dir/.env" ]] && line_in_file ...`. The safer approach mirrors the `--ignore-missing` pattern already used for traefik.yml and .spin.yml.

### Pitfall 6: Traefik Config placeholder NOT matching post-install.sh search string
**What goes wrong:** post-install.sh searches for the exact string `changeme@example.com` in traefik.yml and .spin.yml. If the placeholder in the template files uses a different string (e.g., `your-email@example.com`), the patch silently does nothing (due to `--ignore-missing`).
**Why it happens:** Template file authored by planner/implementer uses different placeholder than what post-install.sh expects.
**How to avoid:** The prod `traefik.yml` MUST contain the literal string `changeme@example.com` in the ACME email field. The `.spin.yml` MUST contain `changeme@example.com` in `server_contact`. These are contract strings — do not deviate.

---

## Code Examples

### docker-compose.prod.yml — Complete Annotated Structure

```yaml
# Source: Derived from /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml
# Symfony adaptations: symfony_var volume, CADDY_SERVER_ROOT, /healthcheck path

services:

  traefik:
    ports:
      - target: 80
        published: 80
        protocol: tcp
        mode: host           # REQUIRED: host mode preserves real client IP
      - target: 443
        published: 443
        protocol: tcp
        mode: host
    networks:
      - web-public
    deploy:
      update_config:
        parallelism: 1
        delay: 5s
        order: stop-first    # Traefik is stateful (ports) — must stop first
      placement:
        constraints:
          - node.role==manager
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - certificates:/certificates
    configs:
      - source: traefik
        target: /etc/traefik/traefik.yml

  php:
    image: ${SPIN_IMAGE_NAME}   # Pre-built; `spin deploy` sets this variable
    environment:
      APP_ENV: prod
      PHP_OPCACHE_ENABLE: "1"
      CADDY_SERVER_ROOT: /var/www/html/public
      HEALTHCHECK_PATH: /healthcheck
      SSL_MODE: full             # FrankenPHP: tells Caddy to use HTTPS internally
    networks:
      - web-public
    volumes:
      - symfony_var:/var/www/html/var
    deploy:
      replicas: 1
      update_config:
        failure_action: rollback
        parallelism: 1
        delay: 5s
        order: start-first   # New container starts before old stops (zero-downtime)
      rollback_config:
        parallelism: 0
        order: stop-first
      restart_policy:
        condition: any
        delay: 10s
        max_attempts: 3
        window: 120s
      labels:                  # MUST be under deploy.labels — not top-level labels
        - "traefik.enable=true"
        - "traefik.http.routers.symfony.rule=Host(`${SPIN_APP_DOMAIN}`)"
        - "traefik.http.routers.symfony.entrypoints=websecure"
        - "traefik.http.routers.symfony.tls=true"
        - "traefik.http.routers.symfony.tls.certresolver=letsencryptresolver"
        # FrankenPHP defaults — post-install.sh patches these for fpm-* variants
        - "traefik.http.services.symfony.loadbalancer.server.port=8443"
        - "traefik.http.services.symfony.loadbalancer.server.scheme=https"
        # Health check
        - "traefik.http.services.symfony.loadbalancer.healthcheck.path=/healthcheck"
        - "traefik.http.services.symfony.loadbalancer.healthcheck.interval=30s"
        - "traefik.http.services.symfony.loadbalancer.healthcheck.timeout=5s"
        - "traefik.http.services.symfony.loadbalancer.healthcheck.scheme=http"

configs:
  traefik:
    name: "traefik-${SPIN_MD5_HASH_TRAEFIK_YML}.yml"
    file: ./.infrastructure/conf/traefik/prod/traefik.yml

volumes:
  certificates:
  symfony_var:

networks:
  web-public:
```

### prod traefik.yml — Complete File

```yaml
# Source: /Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/.infrastructure/conf/traefik/prod/traefik.yml
# Copied verbatim — Symfony template uses identical infrastructure

# Cloudflare TrustedIPs
x-trustedIps: &trustedIPs
  - "173.245.48.0/20"
  - "103.21.244.0/22"
  - "103.22.200.0/22"
  - "103.31.4.0/22"
  - "141.101.64.0/18"
  - "108.162.192.0/18"
  - "190.93.240.0/20"
  - "188.114.96.0/20"
  - "197.234.240.0/22"
  - "198.41.128.0/17"
  - "162.158.0.0/15"
  - "104.16.0.0/13"
  - "104.24.0.0/14"
  - "172.64.0.0/13"
  - "131.0.72.0/22"
  - "2400:cb00::/32"
  - "2606:4700::/32"
  - "2803:f800::/32"
  - "2405:b500::/32"
  - "2405:8100::/32"
  - "2a06:98c0::/29"
  - "2c0f:f248::/32"

serversTransport:
  insecureSkipVerify: true

providers:
  swarm:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
    forwardedHeaders:
      trustedIPs: *trustedIPs
    proxyProtocol:
      trustedIPs: *trustedIPs
  websecure:
    address: ":443"
    forwardedHeaders:
      trustedIPs: *trustedIPs
    proxyProtocol:
      trustedIPs: *trustedIPs

accessLog: {}
log:
  level: ERROR

api:
  dashboard: true
  insecure: true

certificatesResolvers:
  letsencryptresolver:
    acme:
      email: "changeme@example.com"
      storage: "/certificates/acme.json"
      httpChallenge:
        entryPoint: web
```

### post-install.sh Additions

```bash
# --- New: prod compose label patching (after Dockerfile ARG patches) ---

# Patch Traefik labels for fpm-nginx / fpm-apache (FrankenPHP is the shipped default)
if [[ "$SPIN_PHP_VARIATION" != "frankenphp" ]]; then
    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.server.port=' \
        '      - "traefik.http.services.symfony.loadbalancer.server.port=8080"'

    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.server.scheme=' \
        '      - "traefik.http.services.symfony.loadbalancer.server.scheme=http"'
fi

# --- New: APP_SECRET generation (unconditional — runs for new + init) ---

# Generate APP_SECRET if .env exists (created by composer create-project / symfony skeleton)
if [[ -f "$project_dir/.env" ]]; then
    APP_SECRET=$(openssl rand -hex 16)
    line_in_file --action replace \
        --file "$project_dir/.env" \
        'APP_SECRET=' \
        "APP_SECRET=${APP_SECRET}"
fi
```

### .env.example

```bash
# Symfony
APP_ENV=prod
APP_SECRET=                          # Auto-generated at install time by post-install.sh
APP_URL=https://localhost

# Database (uncomment and configure the one you use)
# PostgreSQL:
# DATABASE_URL="postgresql://app:changeme@127.0.0.1:5432/app?serverVersion=16&charset=utf8"
# MySQL / MariaDB:
# DATABASE_URL="mysql://app:changeme@127.0.0.1:3306/app?serverVersion=8.0.32&charset=utf8mb4"
# SQLite:
# DATABASE_URL="sqlite:///%kernel.project_dir%/var/data.db"

# Mailer (uncomment to use Mailpit in development)
# MAILER_DSN=smtp://mailpit:1025
```

### .spin.yml Scaffold

```yaml
# .spin.yml — Spin server configuration
# Full documentation: https://serversideup.net/open-source/spin/docs/server-configuration/spin-yml-usage

server_contact: changeme@example.com   # Patched at install time — change to your email
server_timezone: "Etc/UTC"
use_passwordless_sudo: true

users:
  - username: spin
    name: Spin User
    groups: ['sudo']
    authorized_keys:
      - public_key: "~/.ssh/id_ed25519.pub"   # Update to your SSH public key

servers:
  - server_name: web-1
    environment: production
    hardware_profile: your_hardware_profile   # Update to your VPS provider profile

environments:
  - name: production
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-----------------|--------------|--------|
| Traefik Docker provider for labels | Traefik Swarm provider for Swarm deploy labels | Traefik v2→v3 Swarm support | Labels MUST be in `deploy.labels:`, not top-level |
| Traefik `docker` key in providers | Traefik `swarm` key in providers | Traefik v3 | Config file change required |
| Short port syntax `"80:80"` | Long-form `mode: host` ports for Traefik | Docker Swarm best practice | Preserves real client IP for Cloudflare |

**Deprecated/outdated:**
- `providers.docker:` in Traefik config: Use `providers.swarm:` when deploying to Swarm. Docker provider cannot read `deploy.labels`.
- Top-level `labels:` in Swarm services: Swarm provider ignores them. Use `deploy.labels:`.

---

## Open Questions

1. **`SPIN_IMAGE_NAME` vs `SPIN_IMAGE_DOCKERFILE`**
   - What we know: The Laravel template uses `${SPIN_IMAGE_DOCKERFILE}`. The CONTEXT.md says "uses `${SPIN_IMAGE_NAME}` variable".
   - What's unclear: Whether the Spin ecosystem standardized on `SPIN_IMAGE_NAME` or `SPIN_IMAGE_DOCKERFILE`. Both may be valid; `SPIN_IMAGE_DOCKERFILE` appears to be the variable `spin deploy` actually injects.
   - Recommendation: Use `${SPIN_IMAGE_DOCKERFILE}` to match the Laravel template exactly, and document it as "change this if you're not using `spin deploy`". Add a comment matching Laravel's `# 👈 Change this if you're not using spin deploy`.

2. **Whether `CADDY_SERVER_ROOT` is needed in prod compose**
   - What we know: Dev compose sets `CADDY_SERVER_ROOT: /var/www/html/public`. The Dockerfile's deploy stage does not set it. FrankenPHP in the deploy image would default to `/var/www/html` unless the env var is set.
   - What's unclear: Whether `composer dump-env prod` bakes a Caddyfile that includes the document root, or whether the env var is still needed at runtime.
   - Recommendation: Include `CADDY_SERVER_ROOT: /var/www/html/public` in the prod compose environment block to be safe — same as dev.

3. **APP_SECRET patch timing relative to Symfony skeleton .env creation**
   - What we know: `composer create-project symfony/skeleton` creates `.env` with `APP_SECRET=` empty. The patch runs in post-install.sh after Composer finishes.
   - What's unclear: Whether `.env` is always present when post-install.sh runs for `spin init` (existing project) without Composer install.
   - Recommendation: Guard with `[[ -f "$project_dir/.env" ]]` as shown in the code example above. This handles both cases safely.

---

## Validation Architecture

> `nyquist_validation: true` — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — shell scripts, YAML, Markdown; no automated test harness |
| Config file | none — see Wave 0 |
| Quick run command | `bash -n template/docker-compose.prod.yml` (syntax) + `docker compose -f template/docker-compose.yml -f template/docker-compose.prod.yml config --quiet` |
| Full suite command | `docker compose -f template/docker-compose.yml -f template/docker-compose.prod.yml config` + `bash -n post-install.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROD-01 | `deploy.placement.constraints` present in prod compose | yaml-lint | `docker compose -f template/docker-compose.yml -f template/docker-compose.prod.yml config \| grep 'node.role'` | ❌ Wave 0 |
| PROD-02 | `image: ${SPIN_IMAGE_DOCKERFILE}` in php service | yaml-lint | `docker compose config \| grep SPIN_IMAGE` | ❌ Wave 0 |
| PROD-03 | Named volumes `symfony_var` and `certificates` declared | yaml-lint | `docker compose config \| grep -E 'symfony_var\|certificates'` | ❌ Wave 0 |
| PROD-04 | `APP_ENV=prod` and `PHP_OPCACHE_ENABLE=1` in env | yaml-lint | `docker compose config \| grep -E 'APP_ENV\|OPCACHE'` | ❌ Wave 0 |
| PROD-05 | Healthcheck label present with `/healthcheck` | yaml-lint | `docker compose config \| grep healthcheck` | ❌ Wave 0 |
| PROD-06 | `tls.certresolver=letsencryptresolver` label present | yaml-lint | `docker compose config \| grep letsencryptresolver` | ❌ Wave 0 |
| PROD-07 | FrankenPHP labels default to port 8443/scheme https | yaml-lint | `grep '8443' template/docker-compose.prod.yml` | ❌ Wave 0 |
| TRAF-03 | `providers.swarm` in prod traefik.yml | yaml-lint | `grep 'swarm' template/.infrastructure/conf/traefik/prod/traefik.yml` | ❌ Wave 0 |
| TRAF-04 | Cloudflare IP ranges in prod traefik.yml | yaml-lint | `grep '173.245.48' template/.infrastructure/conf/traefik/prod/traefik.yml` | ❌ Wave 0 |
| SPIN-10 | `.spin.yml` has `server_contact: changeme@example.com` | manual | `grep 'changeme' template/.spin.yml` | ❌ Wave 0 |
| DOC-01 | README.md exists with required sections | manual | `test -f README.md` | ❌ Wave 0 |
| DOC-02 | `.env.example` has `APP_SECRET=` and `APP_ENV=prod` | grep | `grep -E 'APP_SECRET\|APP_ENV' template/.env.example` | ❌ Wave 0 |

Most verification for this phase is grep/yaml-lint on generated files rather than unit tests. The real integration test is `docker compose config` resolving cleanly — which validates YAML structure and overlay merging.

### Sampling Rate
- **Per task commit:** `bash -n post-install.sh` + `docker compose -f template/docker-compose.yml -f template/docker-compose.prod.yml config --quiet`
- **Per wave merge:** Full config resolve + grep checks for critical labels
- **Phase gate:** All grep checks pass + `docker compose config` outputs clean YAML before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `template/docker-compose.prod.yml` — primary deliverable, does not exist yet
- [ ] `template/.infrastructure/conf/traefik/prod/traefik.yml` — replacing .gitignore stub
- [ ] `template/.spin.yml` — does not exist yet
- [ ] `template/.env.example` — does not exist yet

---

## Sources

### Primary (HIGH confidence)
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.prod.yml` — complete prod compose structure: Swarm deploy block, Traefik labels, named volumes, configs section
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/.infrastructure/conf/traefik/prod/traefik.yml` — complete Traefik prod config: Swarm provider, ACME HTTP-01, Cloudflare IPs, HTTP→HTTPS redirect
- `/Users/juliandouma/developer/oss/spin-template-symfony/template/docker-compose.dev.yml` — existing dev overlay: confirmed label syntax, volume names, network naming
- `/Users/juliandouma/developer/oss/spin-template-symfony/post-install.sh` — existing patching patterns: `line_in_file --action replace/exact`, `--ignore-missing`

### Secondary (MEDIUM confidence)
- `https://serversideup.net/open-source/spin/docs/server-configuration/spin-yml-usage` — .spin.yml structure, required fields, minimal example (fetched 2026-03-19)

### Tertiary (LOW confidence)
- None — all critical claims verified from primary sources

---

## Metadata

**Confidence breakdown:**
- Prod compose structure: HIGH — derived directly from Laravel reference template
- Traefik prod config: HIGH — copied verbatim from Laravel reference template
- post-install.sh patches: HIGH — pattern directly observed in existing post-install.sh
- .spin.yml structure: MEDIUM — from official docs (fetched live, structure confirmed)
- APP_SECRET generation: HIGH — `openssl rand -hex 16` is POSIX standard, Symfony convention
- Validation approach: MEDIUM — no existing test harness; grep-based checks are pragmatic for YAML/shell deliverables

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable infrastructure patterns; Cloudflare IP ranges change infrequently but check if > 30 days old)
