---
phase: 04-production-and-ship
verified: 2026-03-19T21:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 4: Production and Ship — Verification Report

**Phase Goal:** The template supports Docker Swarm production deployment with Let's Encrypt SSL and per-runtime Traefik labels, and is documented well enough for a developer to go from zero to live
**Verified:** 2026-03-19T21:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Prod compose defines a Swarm-mode deployment with rolling updates and rollback | VERIFIED | `deploy:` block with `update_config` (failure_action: rollback, order: start-first) and `rollback_config` present in `docker-compose.prod.yml` lines 43-57; `node.role==manager` placement constraint present |
| 2 | Traefik in prod uses Let's Encrypt ACME HTTP-01 for SSL certificates | VERIFIED | `certificatesResolvers.letsencryptresolver.acme.httpChallenge.entryPoint: web` in `traefik.yml` lines 62-68; `providers.swarm` (not `providers.docker`) at line 30 |
| 3 | FrankenPHP labels default to port 8443/scheme https in prod compose | VERIFIED | `loadbalancer.server.port=8443` and `loadbalancer.server.scheme=https` under `deploy.labels` at lines 64-65 of `docker-compose.prod.yml` |
| 4 | HTTP requests redirect to HTTPS in production | VERIFIED | `entryPoints.web.http.redirections.entrypoint.to: websecure` + `scheme: https` in `traefik.yml` lines 38-41 |
| 5 | .spin.yml has changeme@example.com placeholder for post-install.sh patching | VERIFIED | `server_contact: changeme@example.com` at line 4 of `template/.spin.yml`; `post-install.sh` patches it via `line_in_file --action exact` at lines 106-115 |
| 6 | post-install.sh patches prod compose labels when user selects fpm-nginx or fpm-apache | VERIFIED | `if [[ "$SPIN_PHP_VARIATION" != "frankenphp" ]]` block at lines 54-64 of `post-install.sh`; replaces port=8443 with port=8080 and scheme=https with scheme=http in `docker-compose.prod.yml`; placed BEFORE `SPIN_INSTALL_DEPENDENCIES` conditional |
| 7 | post-install.sh generates a random APP_SECRET and patches it into .env unconditionally | VERIFIED | `APP_SECRET=$(openssl rand -hex 16)` block at lines 66-73 of `post-install.sh`; guarded by `[[ -f "$project_dir/.env" ]]`; placed BEFORE `SPIN_INSTALL_DEPENDENCIES` conditional (line 76) — runs for both `spin new` and `spin init` |
| 8 | .env.example contains Symfony-appropriate variables with APP_SECRET placeholder | VERIFIED | `APP_ENV=prod`, `APP_SECRET=` (empty), `APP_URL=https://localhost`, commented DATABASE_URL examples for PostgreSQL/MySQL/SQLite, commented `MAILER_DSN=smtp://mailpit:1025` all present |
| 9 | README documents installation, required changes, running commands, and Mailpit add-on | VERIFIED | `spin new symfony` command, `spin deploy <environment-name>`, Required Changes section with `.env.production`, Let's Encrypt email (`changeme@example.com`), `bin/console` commands, and Mailpit compose snippet all present; no Laravel-specific content |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `template/docker-compose.prod.yml` | Production Swarm compose overlay | VERIFIED | 83 lines; contains `deploy:`, `mode: host`, `SPIN_IMAGE_DOCKERFILE`, `SPIN_MD5_HASH_TRAEFIK_YML`, `symfony_var`, `certificates`, `deploy.labels` (not top-level) |
| `template/.infrastructure/conf/traefik/prod/traefik.yml` | Production Traefik config with ACME | VERIFIED | 69 lines; `providers.swarm`, `insecureSkipVerify: true`, 22 Cloudflare IP ranges (173.245.48.0/20 through 2c0f:f248::/32), HTTP-to-HTTPS redirect, `letsencryptresolver`, `changeme@example.com` |
| `template/.spin.yml` | Starter Spin configuration | VERIFIED | 22 lines; `server_contact: changeme@example.com`, `users`, `servers`, `environments` sections |
| `post-install.sh` | Prod label patching and APP_SECRET generation | VERIFIED | Valid bash syntax (`bash -n` passes); fpm-* label patching block and APP_SECRET generation both present and OUTSIDE `SPIN_INSTALL_DEPENDENCIES` conditional |
| `template/.env.example` | Symfony environment variable template | VERIFIED | `APP_SECRET=` (empty placeholder), `APP_ENV=prod`, `APP_URL=https://localhost`, DATABASE_URL and MAILER_DSN commented examples |
| `README.md` | Project documentation | VERIFIED | 171 lines; covers full install-to-deploy workflow; `spin new symfony`, `spin deploy`, Required Changes, `bin/console` commands, Mailpit add-on, Advanced Configuration |
| `template/.infrastructure/conf/traefik/prod/.gitignore` | Must NOT exist (replaced by traefik.yml) | VERIFIED | File does not exist — stub correctly replaced |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `template/docker-compose.prod.yml` | `template/docker-compose.yml` | Compose overlay extends base services | VERIFIED | File declares `services:` at top level with only `traefik` and `php` overrides; extends base compose pattern; `php` service adds `image:`, `environment:`, `deploy:` atop base `depends_on` |
| `template/docker-compose.prod.yml` | `template/.infrastructure/conf/traefik/prod/traefik.yml` | `configs` section with `SPIN_MD5_HASH_TRAEFIK_YML` | VERIFIED | `configs.traefik.name: "traefik-${SPIN_MD5_HASH_TRAEFIK_YML}.yml"` and `file: ./.infrastructure/conf/traefik/prod/traefik.yml` at lines 72-75 |
| `post-install.sh` | `template/docker-compose.prod.yml` | `line_in_file --action replace` for port and scheme labels | VERIFIED | Two `line_in_file --action replace` calls targeting `$project_dir/docker-compose.prod.yml` for `loadbalancer.server.port=` and `loadbalancer.server.scheme=` at lines 55-63 |
| `post-install.sh` | `template/.spin.yml` | `line_in_file --action exact` for changeme@example.com | VERIFIED | `line_in_file --action exact --ignore-missing` targeting `$project_dir/.spin.yml` with `"changeme@example.com"` at lines 112-115 |
| `post-install.sh` | `template/.infrastructure/conf/traefik/prod/traefik.yml` | `line_in_file --action exact` for changeme@example.com | VERIFIED | `line_in_file --action exact --ignore-missing` targeting `$project_dir/.infrastructure/conf/traefik/prod/traefik.yml` with `"changeme@example.com"` at lines 106-109 |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PROD-01 | 04-01-PLAN.md | docker-compose.prod.yml uses Docker Swarm mode with deployment constraints | SATISFIED | `deploy.placement.constraints: [node.role==manager]` verified in compose |
| PROD-02 | 04-01-PLAN.md | Prod compose uses pre-built image (not Dockerfile build) for deployment | SATISFIED | `image: ${SPIN_IMAGE_DOCKERFILE}` with comment "Change this if you're not using spin deploy" |
| PROD-03 | 04-01-PLAN.md | Prod compose includes named volumes for var/log, var/cache, and Let's Encrypt certificates | SATISFIED | `symfony_var:/var/www/html/var` covers entire Symfony `var/` (includes `cache/` and `log/`); `certificates:/certificates` for ACME certs. Single volume covers both subdirectory concerns. |
| PROD-04 | 04-01-PLAN.md | Prod compose sets APP_ENV=prod, PHP_OPCACHE_ENABLE=1 | SATISFIED | Both present in `php.environment` in compose |
| PROD-05 | 04-01-PLAN.md | Prod compose configures Traefik health check using appropriate health endpoint | SATISFIED | `healthcheck.path=/healthcheck` with `interval=30s`, `timeout=5s`, `scheme=http` in `deploy.labels` |
| PROD-06 | 04-01-PLAN.md | Prod compose enables HTTPS via Let's Encrypt with HTTP→HTTPS redirect | SATISFIED | `tls.certresolver=letsencryptresolver` in compose; HTTP redirect in `traefik.yml` redirections block |
| PROD-07 | 04-01-PLAN.md | Prod compose Traefik labels adapt to selected runtime — FrankenPHP port=8443/scheme=https; fpm-* port=8080/scheme=http | SATISFIED | Compose ships with FrankenPHP defaults; `post-install.sh` patches to 8080/http for non-frankenphp variations |
| TRAF-03 | 04-01-PLAN.md | Prod Traefik config uses Swarm provider with ACME HTTP-01 challenge for Let's Encrypt | SATISFIED | `providers.swarm` and `certificatesResolvers.letsencryptresolver.acme.httpChallenge` both present |
| TRAF-04 | 04-01-PLAN.md | Prod Traefik includes Cloudflare trusted IPs for proper client IP detection | SATISFIED | All 22 Cloudflare IPv4 and IPv6 ranges present in YAML anchor `&trustedIPs`, applied to both `web` and `websecure` entrypoints via `forwardedHeaders.trustedIPs` and `proxyProtocol.trustedIPs` |
| SPIN-10 | 04-01-PLAN.md | Starter .spin.yml with sensible defaults and changeme@example.com placeholder | SATISFIED | `template/.spin.yml` with `server_contact: changeme@example.com`, full users/servers/environments scaffold |
| DOC-01 | 04-02-PLAN.md | README.md with installation instructions, required configuration changes, and running commands | SATISFIED | README covers `spin new symfony`, Required Changes (env.production, production URL, Let's Encrypt email), Symfony commands (`bin/console`, composer), Mailpit add-on, Advanced Configuration |
| DOC-02 | 04-02-PLAN.md | .env.example with Symfony-appropriate environment variables (APP_ENV, APP_SECRET, APP_URL) | SATISFIED | All three present; DATABASE_URL and MAILER_DSN commented examples also present |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps exactly PROD-01 through PROD-07, TRAF-03, TRAF-04, SPIN-10, DOC-01, DOC-02 to Phase 4. No orphaned requirements found.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | No anti-patterns found |

No TODOs, FIXMEs, placeholder returns, empty handlers, or stub implementations detected in any phase 4 deliverable. `bash -n post-install.sh` passes. All key strings present and substantive.

---

### Human Verification Required

The following items cannot be verified programmatically and require a real deployment to confirm:

#### 1. Let's Encrypt certificate issuance

**Test:** Deploy to a server with a real domain (DNS pointing to server IP), run `spin deploy production`, and observe that Traefik issues a certificate via HTTP-01 challenge.
**Expected:** `https://<domain>` loads with a valid Let's Encrypt certificate; no browser security warnings.
**Why human:** Requires live DNS, a reachable server on port 80, and Let's Encrypt's CA to issue; cannot simulate in a grep-based check.

#### 2. post-install.sh fpm-* label patching at install time

**Test:** Run `spin new symfony` selecting `fpm-nginx` as the PHP variation. Inspect `docker-compose.prod.yml` in the generated project.
**Expected:** `loadbalancer.server.port=8080` and `loadbalancer.server.scheme=http` in the prod compose labels (not 8443/https).
**Why human:** Requires Spin's install flow with `SPIN_PHP_VARIATION=fpm-nginx` set; cannot invoke `post-install.sh` with a real Spin context in this environment.

#### 3. APP_SECRET generation at install time

**Test:** Run `spin new symfony`, wait for install to complete, inspect `template/.env`.
**Expected:** `APP_SECRET=<32-char hex string>` (not empty).
**Why human:** Requires a live `spin new` invocation with Composer install and a generated `.env` file.

#### 4. end-to-end zero-to-live developer workflow

**Test:** Follow README from start to finish: `spin new symfony`, configure `.env.production`, `spin provision`, `spin deploy production`.
**Expected:** Application accessible at configured domain with HTTPS, `bin/console` commands work via `spin run php`.
**Why human:** Requires a complete cloud server environment; validates the README's claim that a developer can "go from zero to live" following only the README.

---

### Gaps Summary

No gaps. All 9 observable truths verified, all 7 artifacts exist and are substantive (not stubs), all 5 key links confirmed wired, all 12 requirement IDs satisfied. The phase goal is achieved.

---

## Commit Verification

All phase 4 commits exist in the git history:

| Commit | Description |
|--------|-------------|
| `bbd19e4` | feat(04-01): add docker-compose.prod.yml with Swarm deployment config |
| `6881452` | feat(04-01): add prod Traefik config with ACME and .spin.yml scaffold |
| `ad016d9` | docs(04-01): complete prod infrastructure plan |
| `e04bad8` | feat(04-02): extend post-install.sh with prod label patching and APP_SECRET generation |
| `eb112b7` | feat(04-02): create .env.example and README.md |
| `ae28399` | docs(04-02): complete post-install, env, and README plan — phase 04 done |

---

_Verified: 2026-03-19T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
