# Phase 2: Development Environment - Research

**Researched:** 2026-03-18
**Domain:** Docker Compose, Traefik v3, named volumes, SSL, serversideup/php env vars
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Use Spin CLI naming convention: `docker-compose.yml` (base), `docker-compose.dev.yml` (dev overlay)
- PHP service named `php` — consistent with Spin ecosystem
- Base compose is minimal — just the `php` service definition, designed to be extended by overlays
- Keep it simple for v1 — localhost via `HostRegexp`, no configurable custom domains
- Generate fresh self-signed SSL certificates for this template (not copied from Laravel template)
- Traefik config: Docker provider for service auto-discovery + file provider for SSL certificates
- `.infrastructure/conf/traefik/dev/` directory with traefik.yml, traefik-certs.yml, and certificates/
- Traefik dashboard accessible in dev
- Bind mount `.:/var/www/html` for live code editing
- Named volume overlay on `var/` — prevents cache/log performance degradation on macOS
- `vendor/` stays in bind mount (no overlay) — IDE needs it for autocompletion and static analysis
- Dev compose builds from Dockerfile with `development` target, passes `USER_ID`/`GROUP_ID` args
- Dev compose includes only Traefik + PHP — minimal, unopinionated
- No Mailpit service shipped — document how to add it in README instead
- No Node service — users add their own frontend tooling if needed
- Delegate to serversideup/php env vars — no custom runtime configs

### Claude's Discretion
- Exact Traefik label configuration on the PHP service
- Network naming (likely `development` to match Laravel template)
- Exact self-signed cert generation parameters (CN, SAN, expiry)
- Build args passing in dev compose (USER_ID, GROUP_ID)

### Deferred Ideas (OUT OF SCOPE)
- Configurable local domain (custom .test domain, mkcert integration, dnsmasq for zero-config DNS) — future enhancement for v2 or pro template
- Node service for frontend asset compilation — users add if needed
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| COMP-01 | `docker-compose.yml` defines the `php` service with Symfony-appropriate configuration | Laravel base compose pattern shows minimal structure: traefik image + php service with depends_on |
| COMP-02 | Base compose file is minimal and designed to be extended by dev/prod overlays | Confirmed pattern: base file is ~6 lines, overlays add volumes/labels/networks |
| DEV-01 | `docker-compose.dev.yml` includes Traefik reverse proxy on ports 80/443 | Laravel dev compose pattern confirmed: traefik with ports 80:80 + 443:443 |
| DEV-02 | Dev compose mounts entire project directory into container for live editing | `.:/var/www/html/` bind mount pattern from Laravel reference |
| DEV-03 | Dev compose uses a named volume overlay for `var/` to prevent cache/log performance issues | Named volume declared + mounted at `/var/www/html/var` on top of bind mount |
| DEV-04 | Dev compose builds from Dockerfile with `development` target | `build: target: development` with USER_ID/GROUP_ID args confirmed from reference |
| DEV-05 | **OVERRIDDEN by CONTEXT.md** — No Mailpit service shipped; README docs only | N/A — explicitly decided against |
| DEV-06 | Dev compose defines a `development` network for service communication | Network name `development` confirmed from Laravel reference; matches Spin ecosystem |
| TRAF-01 | Dev Traefik config uses Docker provider with file provider for SSL certificates | Exact config documented from Laravel reference: docker provider + file provider for certs |
| TRAF-02 | Dev Traefik includes self-signed SSL certificates for local HTTPS | Fresh openssl generation required; cert + key files go in certificates/ subdirectory |
| TRAF-05 | `.infrastructure/` directory structure mirrors Laravel basic template | Confirmed: conf/traefik/dev/, conf/traefik/prod/, volume_data/ with .gitignore stubs |
</phase_requirements>

---

## Summary

Phase 2 produces the Docker Compose files and Traefik configuration that enable `spin up` to start a working local Symfony environment. The work is anchored on a well-understood reference: the `spin-template-laravel-basic` template, which this Symfony template is explicitly designed to mirror.

The core complexity is the named volume overlay pattern (bind mount + named volume on `var/`) and the Traefik label strategy for the PHP service. The label strategy has a known wrinkle: the template supports multiple PHP runtime variations (FrankenPHP vs fpm-nginx/fpm-apache), which differ on port and scheme. Since the dev compose is the default state before `install.sh` runs (Phase 3), it must ship with one set of labels — FrankenPHP defaults — and `install.sh` will patch them for other variations. This is consistent with how the production compose handles the same problem.

The dev environment uses HTTP-only communication between Traefik and the PHP container (port 8080), with Traefik terminating TLS at its edge. SSL_MODE is left unset (defaults to `off`) in dev. No self-signed cert management within the PHP container is needed — Traefik handles HTTPS at the edge using the pre-generated certificates in `.infrastructure/conf/traefik/dev/certificates/`.

**Primary recommendation:** Mirror the Laravel basic template structure exactly, substituting `laravel` service name labels for `symfony`, removing node/mailpit services, adding the `var/` named volume overlay, and setting `CADDY_SERVER_ROOT=/var/www/html/public` as the only required env var in dev compose.

---

## Standard Stack

### Core

| Library/Tool | Version | Purpose | Why Standard |
|---|---|---|---|
| Traefik | v3.6 (from Laravel reference) | Dev reverse proxy, HTTPS termination | Spin ecosystem standard; already in base compose |
| Docker Compose | v2 (file format version implicit) | Orchestration | Spin CLI requires `docker-compose.yml` naming |
| OpenSSL | 3.x (system) | Self-signed cert generation | Ships with macOS/Linux; no extra tooling needed |

### Supporting

| Library/Tool | Version | Purpose | When to Use |
|---|---|---|---|
| serversideup/php | via Dockerfile ARG | Runtime image | Already established in Phase 1 |
| axllent/mailpit | latest | Email testing | NOT shipped — README-documented add-on |

### Installation

No package installation required for this phase — all components are Docker images pulled at runtime.

---

## Architecture Patterns

### File Structure to Create

```
template/
├── docker-compose.yml                          # Base: traefik image + php service stub
├── docker-compose.dev.yml                      # Dev overlay: volumes, labels, network, build
└── .infrastructure/
    └── conf/
        └── traefik/
            └── dev/
                ├── traefik.yml                 # Traefik static config (docker + file providers)
                ├── traefik-certs.yml           # Dynamic config pointing to cert files
                └── certificates/
                    ├── local-dev.pem           # Self-signed cert (generated fresh)
                    └── local-dev-key.pem       # Private key
```

Note: `.infrastructure/conf/traefik/prod/` and `.infrastructure/volume_data/` belong to later phases (TRAF-05 requires mirroring the full structure, so stub .gitignore files should be created for those directories).

### Pattern 1: Base Compose — Minimal Service Stub

**What:** `docker-compose.yml` declares only the traefik image and php service with depends_on. No volumes, no networks, no labels.
**When to use:** Always — this is the Spin ecosystem convention. The base file is extended by dev/prod overlays.

```yaml
# Source: spin-template-laravel-basic/template/docker-compose.yml (verified)
services:

  traefik:
    image: traefik:v3.6

  php:
    depends_on:
      - traefik
```

### Pattern 2: Dev Overlay — Full Service Definition

**What:** `docker-compose.dev.yml` adds everything needed for local development via Compose merge.
**When to use:** Dev only — invoked by `spin up` which sets `COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml`.

```yaml
# Source: spin-template-laravel-basic/template/docker-compose.dev.yml (verified, adapted)
services:
  traefik:
    ports:
      - "80:80"
      - "443:443"
    networks:
      development:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./.infrastructure/conf/traefik/dev/traefik.yml:/traefik.yml:ro
      - ./.infrastructure/conf/traefik/dev/traefik-certs.yml:/traefik-certs.yml
      - ./.infrastructure/conf/traefik/dev/certificates/:/certificates

  php:
    build:
      target: development
      args:
        USER_ID: ${SPIN_USER_ID}
        GROUP_ID: ${SPIN_GROUP_ID}
    environment:
      CADDY_SERVER_ROOT: /var/www/html/public   # FrankenPHP document root
    volumes:
      - .:/var/www/html/                        # DEV-02: full bind mount
      - symfony_var:/var/www/html/var           # DEV-03: named volume overlay on var/
    networks:
      - development
    depends_on:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.symfony.rule=HostRegexp(`localhost`)"
      - "traefik.http.routers.symfony.entrypoints=web"
      - "traefik.http.services.symfony.loadbalancer.server.port=8080"
      - "traefik.http.services.symfony.loadbalancer.server.scheme=http"

networks:
  development:

volumes:
  symfony_var:
```

### Pattern 3: Named Volume Overlay (var/ Performance Fix)

**What:** Mount the entire project as a bind mount, then overlay a named Docker volume on `var/` to prevent macOS file-system performance degradation from Symfony's cache and log writes.
**Why:** Symfony writes to `var/cache/` and `var/log/` constantly. On macOS, Docker Desktop bind mounts have significant I/O overhead. A named volume uses Docker's native storage driver and eliminates this.
**Critical detail:** `vendor/` intentionally stays in the bind mount so IDEs can access it for autocompletion.

```yaml
# Compose volume definition (named, no special driver needed)
volumes:
  symfony_var:

# Service volume mounts — order matters for overlay
volumes:
  - .:/var/www/html/               # full bind mount first
  - symfony_var:/var/www/html/var  # named volume overlays var/ on top
```

**How it works:** Docker processes mounts in order. The bind mount covers everything including `var/`. The subsequent named volume mount at `var/` "wins" for that subtree, making it use Docker's native storage.

### Pattern 4: Traefik Static Config (traefik.yml)

**What:** Static Traefik config enabling Docker provider (label-based discovery) plus file provider (SSL cert loading).

```yaml
# Source: spin-template-laravel-basic/template/.infrastructure/conf/traefik/dev/traefik.yml (verified)
serversTransport:
  insecureSkipVerify: true   # Required: Traefik → PHP uses HTTP, but certs exist

providers:
  docker:
    exposedByDefault: false
  file:
    filename: /traefik-certs.yml
    watch: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

accessLog: {}
log:
  level: ERROR

api:
  dashboard: true
  insecure: true              # Dashboard accessible without auth in dev
```

### Pattern 5: Traefik Certificate Config (traefik-certs.yml)

**What:** Traefik dynamic config pointing to self-signed certificate files.

```yaml
# Source: spin-template-laravel-basic/template/.infrastructure/conf/traefik/dev/traefik-certs.yml (verified)
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /certificates/local-dev.pem
        keyFile: /certificates/local-dev-key.pem
  certificates:
    - certFile: /certificates/local-dev.pem
      keyFile: /certificates/local-dev-key.pem
      stores:
        - default
```

### Pattern 6: Self-Signed Certificate Generation

**What:** Fresh self-signed cert for localhost. Must include SAN (Subject Alternative Name) because modern browsers reject certs without it.
**Command (OpenSSL 1.1.1+):**

```bash
# Source: OpenSSL docs; verified against OpenSSL 3.6.1 on system
openssl req -x509 -nodes -newkey rsa:4096 -sha256 \
  -days 3650 \
  -keyout .infrastructure/conf/traefik/dev/certificates/local-dev-key.pem \
  -out .infrastructure/conf/traefik/dev/certificates/local-dev.pem \
  -subj "/C=US/ST=Local/L=Local/O=Symfony Dev/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

**Parameters:**
- `-nodes`: No passphrase (required — containers can't enter a passphrase)
- `rsa:4096`: 4096-bit key (industry standard)
- `-days 3650`: 10-year expiry (avoids renewal hassle in dev)
- `CN=localhost` + SAN `DNS:localhost,IP:127.0.0.1`: Browser compatibility requires SAN

The generated files are committed to the repository (they are self-signed dev certs, not secrets).

### Anti-Patterns to Avoid

- **Router entrypoint using `websecure` in dev:** The Laravel reference uses `entrypoints=web` (HTTP). Traefik handles HTTPS termination on `websecure`, but the router that matches incoming requests uses `web` (port 80) then Traefik upgrades to HTTPS internally via the cert files. Use `web` for the router entrypoint in dev to keep things simple.
- **Setting SSL_MODE in dev compose:** Not needed. SSL_MODE is a PHP container setting. In dev, Traefik terminates TLS — the PHP container only speaks HTTP (port 8080). SSL_MODE=full is for production only.
- **Omitting `insecureSkipVerify: true`:** If ever switching to HTTPS backend (port 8443), Traefik needs this to trust the self-signed cert inside the container. For now with HTTP backend, it's harmless but should be kept for consistency with the reference.
- **Bind-mounting the Docker socket as read-write:** Always `:ro`. Traefik only needs to read container events.

---

## FrankenPHP vs fpm-nginx Label Strategy

This is the critical question for this phase. The template supports both variations via `PHP_VARIATION` build arg. The Traefik labels differ:

| Variation | Internal Port | Scheme | SSL_MODE |
|-----------|--------------|--------|----------|
| `frankenphp` | 8080 (HTTP to Traefik) | http | off (dev) / full (prod) |
| `fpm-nginx` | 8080 (HTTP) | http | off (always — nginx handles nothing re: TLS) |
| `fpm-apache` | 8080 (HTTP) | http | off (always) |

**Key insight from Laravel production compose (verified):** The production compose uses `port=8443` + `scheme=https` with `SSL_MODE: full` on the FrankenPHP service. This means Traefik speaks HTTPS to the PHP container using the container's internal self-signed cert. This is a "mutual TLS" pattern at the Traefik-to-backend level.

**For dev compose:** All variations use HTTP port 8080. No SSL_MODE needed. Labels are:
```
traefik.http.services.symfony.loadbalancer.server.port=8080
traefik.http.services.symfony.loadbalancer.server.scheme=http
```

**For production compose (Phase 4):** FrankenPHP needs `port=8443` + `scheme=https` + `SSL_MODE: full`. fpm-nginx/fpm-apache use `port=8080` + `scheme=http`. `install.sh` (Phase 3, RT-03) will patch these labels based on selected variation.

**Decision for dev compose:** Ship with FrankenPHP-compatible defaults (port 8080, scheme http). All three variations use identical labels in dev since all use HTTP to Traefik. No patching needed for dev compose labels — the variation difference only matters for production.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSL certificate management in PHP container | Custom cert scripts | serversideup/php default handling | Container has built-in SSL cert generation; for dev, Traefik handles TLS entirely |
| Custom Nginx/Caddy config files for document root | Caddyfile, nginx.conf | `CADDY_SERVER_ROOT` env var | serversideup/php supports full config via env vars — no config files needed |
| Custom health check routes | Symfony controller | serversideup/php built-in `/healthcheck` | `/healthcheck` is baked in to all image variations; no code required |
| macOS volume performance tuning | Custom delegated/cached mounts | Named volume overlay on `var/` | Named volumes bypass macOS VirtioFS/gRPC-FUSE overhead entirely |

---

## Common Pitfalls

### Pitfall 1: Missing SAN in Self-Signed Certificate

**What goes wrong:** Chrome, Firefox, and Safari all reject certificates without a Subject Alternative Name extension (since ~2017). The browser shows NET::ERR_CERT_COMMON_NAME_INVALID.
**Why it happens:** Older openssl tutorials only show `-subj` with CN. CN alone is insufficient for modern browsers.
**How to avoid:** Always include `-addext "subjectAltName=DNS:localhost,IP:127.0.0.1"` in openssl command.
**Warning signs:** Browser HTTPS error immediately on first `spin up`.

### Pitfall 2: Named Volume Overlay Eating vendor/ on First Start

**What goes wrong:** If a named volume is accidentally mounted at `/var/www/html` (covering everything) rather than `/var/www/html/var`, composer dependencies installed inside the container during build won't be visible.
**Why it happens:** Typo in volume mount path, or misunderstanding the overlay scope.
**How to avoid:** Named volume mounts at `/var/www/html/var` specifically. The bind mount `.:/var/www/html/` must come first in the volumes list.
**Warning signs:** `php bin/console` fails with "class not found" on first start despite working Dockerfile.

### Pitfall 3: HostRegexp Routing in Traefik v3

**What goes wrong:** Traefik v3 changed the HostRegexp syntax from v2. Using v2 syntax breaks routing silently — requests get no response.
**Why it happens:** Many tutorials use v2 syntax. The Laravel reference uses v3 syntax.
**How to avoid:** Use `` HostRegexp(`localhost`) `` (v3 syntax — just the hostname pattern, no regex wrapping). In Traefik v2 it was `` HostRegexp(`{catchall:.*}`) `` style.
**Warning signs:** Traefik dashboard shows router but all requests return 404.

### Pitfall 4: CADDY_SERVER_ROOT Not Set

**What goes wrong:** FrankenPHP serves from `/var/www/html` instead of `/var/www/html/public`. Symfony's front controller (`index.php`) is in `public/` so all requests return the raw directory listing or a 404.
**Why it happens:** serversideup/php FrankenPHP variation defaults CADDY_SERVER_ROOT to `/var/www/html/public`, but only if the env var is set. Confirmed default in docs is `/var/www/html/public`.
**How to avoid:** Explicitly set `CADDY_SERVER_ROOT: /var/www/html/public` in dev compose (belt-and-suspenders). Same for NGINX_WEBROOT and APACHE_DOCUMENT_ROOT for those variations — but those are handled by install.sh patching in Phase 3.
**Warning signs:** Browser shows directory listing or `vendor/` directory instead of Symfony app.

### Pitfall 5: Docker Socket Permission in Dev

**What goes wrong:** Traefik can't connect to Docker socket on Linux hosts (works fine on macOS with Docker Desktop).
**Why it happens:** On Linux, Docker socket is owned by `docker` group; the Traefik container runs as root by default so it works, but if a custom user is set it breaks.
**How to avoid:** Don't set a custom user on the Traefik service. Keep default (root) for Docker socket access. Mount as `:ro`.
**Warning signs:** Traefik shows no services discovered despite containers running.

---

## Code Examples

### Complete docker-compose.yml (Base)

```yaml
# Source: adapted from spin-template-laravel-basic/template/docker-compose.yml (verified)
services:

  traefik:
    image: traefik:v3.6

  php:
    depends_on:
      - traefik
```

### Complete docker-compose.dev.yml

```yaml
# Source: adapted from spin-template-laravel-basic/template/docker-compose.dev.yml (verified)
services:
  traefik:
    ports:
      - "80:80"
      - "443:443"
    networks:
      development:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./.infrastructure/conf/traefik/dev/traefik.yml:/traefik.yml:ro
      - ./.infrastructure/conf/traefik/dev/traefik-certs.yml:/traefik-certs.yml
      - ./.infrastructure/conf/traefik/dev/certificates/:/certificates

  php:
    build:
      target: development
      args:
        USER_ID: ${SPIN_USER_ID}
        GROUP_ID: ${SPIN_GROUP_ID}
    environment:
      CADDY_SERVER_ROOT: /var/www/html/public
    volumes:
      - .:/var/www/html/
      - symfony_var:/var/www/html/var
    networks:
      - development
    depends_on:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.symfony.rule=HostRegexp(`localhost`)"
      - "traefik.http.routers.symfony.entrypoints=web"
      - "traefik.http.services.symfony.loadbalancer.server.port=8080"
      - "traefik.http.services.symfony.loadbalancer.server.scheme=http"

networks:
  development:

volumes:
  symfony_var:
```

### serversideup/php Key Environment Variables for Dev

```yaml
# Source: https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification (verified)

# FrankenPHP (default variation)
CADDY_SERVER_ROOT: /var/www/html/public   # Document root (default is already this value)

# fpm-nginx variation (install.sh patches this in for fpm-nginx)
NGINX_WEBROOT: /var/www/html/public       # Document root

# fpm-apache variation (install.sh patches this in for fpm-apache)
APACHE_DOCUMENT_ROOT: /var/www/html/public  # Document root

# SSL_MODE — NOT set in dev (left at default "off")
# Production uses: SSL_MODE: full (FrankenPHP only)
```

### Directory Stub .gitignore Files

```
# .infrastructure/conf/traefik/prod/.gitignore (stub for TRAF-05)
# .infrastructure/volume_data/.gitignore (stub for TRAF-05)
*
!.gitignore
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Traefik v2 HostRegexp syntax | Traefik v3 simplified HostRegexp | Traefik v3 (April 2024) | Syntax change — v2 patterns break silently in v3 |
| `delegated`/`cached` Docker volume mount options | Named volume overlay | Docker Desktop 4.x+ | Old options were removed; named volume is the correct macOS perf solution |
| mkcert for local SSL | Committed self-signed certs | Ongoing | Spin template approach — simpler, no local tooling requirement |
| `compose.yaml` naming | `docker-compose.yml` naming | N/A | Spin CLI requires the older naming for `spin up`/`spin deploy` |

**Deprecated/outdated:**
- `docker-compose.yml` `version:` key: Removed in Compose v2 — do NOT include a `version:` field
- Traefik v2 label syntax like `HostRegexp(\`{catchall:.*}\`)`: Broken in v3, use `HostRegexp(\`localhost\`)` instead
- `delegated` and `cached` volume mount options: Silently ignored in modern Docker Desktop

---

## Open Questions

1. **Does Traefik route `websecure` (443) automatically when using self-signed certs, or does the PHP router also need `entrypoints=websecure`?**
   - What we know: Laravel reference only sets `entrypoints=web` on the PHP router. Traefik terminates HTTPS at its edge independently of the router entrypoint.
   - What's unclear: Whether `https://localhost` works without a websecure router for the PHP service.
   - Recommendation: Follow the Laravel reference exactly (entrypoints=web only). Traefik serves HTTPS on port 443 to clients regardless of backend router configuration when using the file provider cert.

2. **Should `CADDY_SERVER_ROOT` be set explicitly or rely on the serversideup/php default?**
   - What we know: Default is confirmed as `/var/www/html/public` per docs. Explicit is safer.
   - Recommendation: Set it explicitly — documentation says default but explicit is better than implicit for a template.

3. **`symfony_var` named volume — will it pre-populate from the bind mount on first start?**
   - What we know: Docker's named volume overlay does NOT pre-populate from the bind mount; it starts empty.
   - Impact: On first `spin up`, `var/cache/` and `var/log/` will be empty, which is correct — Symfony creates them on first request or via `cache:warmup`.
   - Recommendation: No action needed; Symfony handles empty `var/` gracefully.

---

## Validation Architecture

nyquist_validation is enabled (config.json: `"nyquist_validation": true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — this phase produces config files only |
| Config file | N/A |
| Quick run command | `docker compose -f docker-compose.yml -f docker-compose.dev.yml config` (validates compose syntax) |
| Full suite command | `spin up -d && curl -k https://localhost/` (smoke test) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-01 | `docker-compose.yml` has traefik + php services | smoke | `docker compose -f docker-compose.yml config --quiet` | ❌ Wave 0 |
| COMP-02 | Base compose is valid and minimal | smoke | `docker compose -f docker-compose.yml config --quiet` | ❌ Wave 0 |
| DEV-01 | Dev compose adds Traefik on 80/443 | smoke | `docker compose -f docker-compose.yml -f docker-compose.dev.yml config \| grep -E "80:80\|443:443"` | ❌ Wave 0 |
| DEV-02 | Bind mount `.:/var/www/html/` present | smoke | `docker compose -f docker-compose.yml -f docker-compose.dev.yml config \| grep "var/www/html"` | ❌ Wave 0 |
| DEV-03 | Named volume overlay on `var/` present | smoke | `docker compose -f docker-compose.yml -f docker-compose.dev.yml config \| grep symfony_var` | ❌ Wave 0 |
| DEV-04 | Build target is `development` | smoke | `docker compose -f docker-compose.yml -f docker-compose.dev.yml config \| grep "target: development"` | ❌ Wave 0 |
| DEV-06 | `development` network declared | smoke | `docker compose -f docker-compose.yml -f docker-compose.dev.yml config \| grep "development:"` | ❌ Wave 0 |
| TRAF-01 | traefik.yml has docker + file providers | manual | Inspect `.infrastructure/conf/traefik/dev/traefik.yml` | ❌ Wave 0 |
| TRAF-02 | Self-signed certs present and valid | smoke | `openssl x509 -in .infrastructure/conf/traefik/dev/certificates/local-dev.pem -noout -text \| grep "Subject Alternative Name"` | ❌ Wave 0 |
| TRAF-05 | .infrastructure/ directory structure correct | smoke | `ls .infrastructure/conf/traefik/dev/ .infrastructure/volume_data/` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `docker compose -f docker-compose.yml -f docker-compose.dev.yml config --quiet`
- **Per wave merge:** All smoke commands above
- **Phase gate:** Full `spin up -d` smoke test before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] No test files exist — this phase produces YAML/config files; validation is via `docker compose config` and manual inspection
- [ ] `openssl` must be available on developer machine (standard on macOS/Linux)
- [ ] `docker compose config` (Compose V2) must be available — verify with `docker compose version`

---

## Sources

### Primary (HIGH confidence)
- `spin-template-laravel-basic/template/docker-compose.yml` — base compose pattern (read directly)
- `spin-template-laravel-basic/template/docker-compose.dev.yml` — dev overlay pattern with Traefik, labels, named network (read directly)
- `spin-template-laravel-basic/template/.infrastructure/conf/traefik/dev/traefik.yml` — Traefik static config (read directly)
- `spin-template-laravel-basic/template/.infrastructure/conf/traefik/dev/traefik-certs.yml` — cert file provider config (read directly)
- `spin-template-laravel-basic/template/docker-compose.prod.yml` — production FrankenPHP labels with port=8443/scheme=https/SSL_MODE=full (read directly, critical reference)
- https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification — env var names and defaults (fetched)
- https://serversideup.net/open-source/docker-php/docs/image-variations/frankenphp — FrankenPHP ports and SSL config (fetched)
- https://serversideup.net/open-source/docker-php/docs/deployment-and-production/configuring-ssl — SSL_MODE values and usage (fetched)

### Secondary (MEDIUM confidence)
- https://serversideup.net/open-source/docker-php/docs/getting-started/default-configurations — port defaults for both variations (fetched, consistent with primary docs)
- https://raymii.org/s/tutorials/OpenSSL_generate_self_signed_cert_with_Subject_Alternative_name_oneliner.html — openssl SAN syntax (web search, cross-verified with openssl man page behavior)

### Tertiary (LOW confidence)
- https://community.traefik.io/t/https-passthrough-from-traefik-to-caddy/23411 — Traefik TCP passthrough (fetched; not used — HTTP backend chosen for dev)

---

## Metadata

**Confidence breakdown:**
- Base and dev compose structure: HIGH — read directly from canonical Laravel reference
- Traefik config files: HIGH — read directly from canonical reference; copied structure is proven
- Named volume overlay pattern: HIGH — Docker Compose documented behavior, confirmed via STATE.md decisions
- serversideup/php env vars: HIGH — fetched from official docs
- FrankenPHP label strategy (port=8080 for dev): HIGH — confirmed from prod reference + SSL docs stating HTTP-to-backend is preferred
- Self-signed cert generation: MEDIUM — standard openssl; SAN flag is well-documented

**Research date:** 2026-03-18
**Valid until:** 2026-04-17 (30 days — Traefik and serversideup/php are actively maintained but stable)
