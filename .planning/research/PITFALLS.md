# Pitfalls Research

**Domain:** Docker template for Symfony 7 LTS + FrankenPHP (adapting from a Laravel-style Spin template)
**Researched:** 2026-03-18
**Confidence:** HIGH (most findings verified against official FrankenPHP docs, Symfony docs, and active GitHub issues)

---

## Critical Pitfalls

### Pitfall 1: Wrong Document Root in Caddyfile (All Routes Return 404)

**What goes wrong:**
FrankenPHP serves 404 for all Symfony routes when the Caddyfile's `root` directive points to the project root instead of `public/`. The `php_server` directive cannot locate `public/index.php` and the Symfony front controller never executes.

**Why it happens:**
Developers copying Caddyfile patterns from non-Symfony sources set `root * /var/www/html` instead of `root * /var/www/html/public`. PHP applications that use a flat structure (e.g., WordPress) are compatible with a project-root document root, but Symfony places all public assets and the front controller inside `public/`. This is one of the most common FrankenPHP + Symfony misconfigurations tracked in GitHub issues.

**How to avoid:**
In the Caddyfile (or Caddyfile fragment baked into the template), always set:
```
root * /var/www/html/public
php_server
```
Add a smoke test in the template validation step that sends a `curl` request to `/` and verifies a non-404 response.

**Warning signs:**
- All routes return 404 immediately after `docker compose up`
- FrankenPHP logs show "file not found" rather than PHP errors
- `/` returns 404 but static files in `public/` return 200

**Phase to address:**
Phase 1 (Dockerfile + Caddyfile scaffold) — get this right before anything else builds on top of it.

---

### Pitfall 2: FrankenPHP and Traefik Competing for Ports 80/443

**What goes wrong:**
FrankenPHP (via Caddy) and Traefik both attempt to bind to ports 80 and 443. In dev this causes `bind: address already in use` startup failures. In Swarm prod it causes containers to fail with port conflicts. Only the first service to start wins.

**Why it happens:**
FrankenPHP embeds Caddy, which handles TLS and HTTP by default on standard ports. The Spin Laravel template uses `fpm-nginx` where the PHP container is an internal service on port 8080 (Traefik routes to it). When naively swapping to `frankenphp`, developers forget that the image now also wants 80/443 for itself.

**How to avoid:**
Configure FrankenPHP to listen on an internal port only (e.g., 8080 HTTP) and expose no TLS. Let Traefik terminate SSL. In the Caddyfile:
```
:8080 {
    root * /var/www/html/public
    php_server
}
```
Set the Traefik label to point at port 8080 over HTTP scheme. FrankenPHP's Caddy should NOT manage ACME in this setup — Traefik manages certificates. Do NOT expose ports 80 or 443 from the PHP service in `docker-compose.yml`.

**Warning signs:**
- `Error starting userland proxy: listen tcp4 0.0.0.0:443: bind: address already in use`
- Traefik container starts, PHP container fails
- SSL works in Traefik dashboard but the PHP service is unreachable

**Phase to address:**
Phase 1 (Dockerfile + docker-compose scaffold) and Phase 2 (Traefik integration). Must be verified in dev before any prod work starts.

---

### Pitfall 3: FrankenPHP Worker Mode Incompatibility on Alpine (Stack Size Crash)

**What goes wrong:**
FrankenPHP running on Alpine Linux (`-alpine` image tag) uses musl libc, which has a default thread stack size too small for Symfony's DI container compilation. The symptom is a PHP fatal error: "Maximum call stack size of 83360 bytes reached during compilation" — or in some versions, the container freezes and becomes unresponsive without any error message.

**Why it happens:**
Alpine's musl libc sets a smaller default stack size than glibc (used by Debian). Symfony's DI container compilation is recursive and exceeds musl's limit. The official FrankenPHP docs explicitly note this and recommend either using the Debian image or setting a custom stack size at build time.

**How to avoid:**
Two options (pick one):
1. **Default to Debian** in the template. When users choose Alpine in `install.sh`, emit a visible warning that Alpine + FrankenPHP worker mode may require a manual stack size increase.
2. If Alpine is supported, inject `FRANKENPHP_CONFIG` at runtime to increase stack size, or rebuild with `XCADDY_GO_BUILD_FLAGS="-ldflags='-w -s -extldflags \"-Wl,-z,stack-size=0x80000\"'"` at image build time.

The safest approach: default the template to Debian for FrankenPHP, with a documented note about Alpine.

**Warning signs:**
- Container starts then freezes on first request (especially the first DI-heavy request)
- "Maximum call stack size" PHP fatal errors in logs
- Worker mode unresponsive, no regular error output

**Phase to address:**
Phase 1 (base image selection in Dockerfile scaffold). The OS default in `install.sh` for FrankenPHP variation must be Debian, not Alpine.

---

### Pitfall 4: Binding the Entire Project as a Volume Overwrites the var/ Directory

**What goes wrong:**
In `docker-compose.dev.yml`, mounting `.:/var/www/html` for live editing causes the host's `var/` directory (which is usually empty or uninitialized) to shadow the container's pre-warmed `var/cache/` and `var/log/` directories. The result is Symfony running without its cache, causing extremely slow responses or "Unable to write in cache directory" errors with wrong permissions.

**Why it happens:**
The Laravel template mounts `.:/var/www/html` and it works because Laravel generates the cache at runtime into `storage/`. Symfony's cache lives in `var/cache/` and must be writable by the container user. When the bind mount overwrites this with the host directory, the container user (www-data or frankenphp UID) may not match the host UID, or the directory may be empty.

**How to avoid:**
Use a bind mount for the project root but add a named volume overlay for `var/`:
```yaml
volumes:
  - .:/var/www/html
  - symfony_var:/var/www/html/var
```
Then declare `symfony_var` as a named volume. This preserves the container-generated cache and log files independently from the host filesystem. Add `var/` to `.gitignore` and `.dockerignore` for the deploy stage.

**Warning signs:**
- `spin up` is slow (3-10 seconds per request in dev)
- Logs contain "Failed to write cache file" or permission denied errors in `var/cache/`
- `bin/console cache:clear` works but the issue returns after container restart

**Phase to address:**
Phase 2 (docker-compose.dev.yml development environment). This affects all local dev users immediately.

---

### Pitfall 5: Installing Symfony Skeleton Inside the Container Creates Root-Owned Files on macOS/Linux

**What goes wrong:**
Running `composer create-project symfony/skeleton` via `docker run` without `--user` flags creates project files owned by root inside the container. On the host, all generated files are owned by root, requiring `sudo` to edit them. `git init` and subsequent operations fail or produce confusing permission errors.

**Why it happens:**
The Laravel template's `install.sh` passes `--user "${SPIN_USER_ID}:${SPIN_GROUP_ID}"` to the Docker run command. If this is omitted or the Symfony adaptation forgets to pass `SPIN_USER_ID`/`SPIN_GROUP_ID` when calling `composer create-project symfony/skeleton`, the container runs as root and creates root-owned files.

**How to avoid:**
Always pass `--user "${SPIN_USER_ID}:${SPIN_GROUP_ID}"` in the `docker run` call within `new()` in `install.sh`. Verify by running `ls -la` in the generated project and confirming file ownership matches the host user. Mirror the exact pattern from `spin-template-laravel-basic/install.sh`.

**Warning signs:**
- After `spin new symfony myapp`, the project files require sudo to edit
- `git add .` complains about insufficient permissions
- IDE cannot save files in the project directory

**Phase to address:**
Phase 3 (install.sh and post-install.sh authoring). Must be tested on both macOS and Linux hosts.

---

### Pitfall 6: APP_ENV and APP_SECRET Overriding and .env File Priority Confusion

**What goes wrong:**
Symfony reads environment variables from the container environment first, then falls back to `.env`. When `APP_ENV=prod` is set as a real container environment variable (in docker-compose.prod.yml), Symfony does not load `.env` at all. If the `.env` template file committed to the repo contains a real `APP_SECRET` value, it's either ignored in prod (the real env var wins) or — more dangerously — the secret leaks into the repo if developers forget to remove it.

Additionally, if `DATABASE_URL` is defined in `.env`, it silently overrides the value configured via Docker Secrets or Swarm environment variables, because `.env` values are read before runtime secrets resolution.

**Why it happens:**
Symfony's dotenv loading behavior is environment-aware: in production (`APP_ENV=prod` as a real env var), `.env` is not processed. Developers moving from Laravel (where `.env` is always the authoritative source) assume the same behavior and commit placeholder values that later conflict.

**How to avoid:**
- The `.env` file committed to the repo should contain only non-sensitive defaults and variable names with empty values (e.g., `APP_SECRET=` not `APP_SECRET=changethis`)
- Document in the template README that secrets must be supplied via Swarm secrets or real container env vars in prod
- Ensure the Traefik email (`SERVER_CONTACT`) substitution uses the correct file and does not affect `.env` parsing

**Warning signs:**
- Production app behaves differently from dev despite identical code
- `bin/console debug:container --env-vars` shows unexpected values
- Secrets defined in Docker Swarm secrets are ignored; `.env` values take precedence

**Phase to address:**
Phase 4 (docker-compose.prod.yml and Swarm deployment). Document the behavior in `.env.example` comments.

---

### Pitfall 7: Symfony Worker Mode Entity Manager Stale State Between Requests

**What goes wrong:**
In FrankenPHP worker mode, the Symfony kernel persists across requests. Doctrine's EntityManager accumulates entity identity map state across requests. After request N modifies an entity, request N+1 (on the same worker thread) may receive a stale cached version from the identity map, not reflecting database changes made by other processes or requests handled by other threads.

**Why it happens:**
Worker mode keeps services alive between requests for performance. Doctrine's EntityManager is not inherently request-scoped in this model. Symfony 7.4+ introduced native FrankenPHP worker mode support with automatic kernel reset, but Doctrine's EntityManager reset behavior in Symfony 7.4+ has known issues (entity managers not properly reopened between requests in some versions — tracked in FrankenPHP issue #1707).

**How to avoid:**
- Use Symfony 7.4+ for native worker mode support (it handles kernel reset automatically)
- Verify the installed Symfony version uses the worker mode integration from `runtime/frankenphp-symfony`
- Include `frankenphp_loop_max` configuration (default 500 requests per worker restart) as a safety net against memory leaks
- Instruct template users in the README to test their app under worker mode before assuming traditional PHP-FPM behavior

**Warning signs:**
- Stale data returned to users (read entity shows old values)
- Memory usage grows linearly per request (no plateau)
- Inconsistent behavior under load testing (some requests correct, others stale)

**Phase to address:**
Phase 1 (Caddyfile/worker mode configuration) and documented in template README.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode `APP_SECRET=changeme` in `.env` | Template "just works" on first run | Security disaster if users forget to rotate; misleads developers about secrets management | Never — use an empty value and document it |
| Mount `var/` via bind mount instead of named volume | Simpler compose file | 2-5x dev performance penalty; permission errors on fresh clones | Never for FrankenPHP/Symfony |
| Default Alpine OS for FrankenPHP | Smaller image size | Stack size crashes in worker mode; container freezes with no useful error | Only if build-time stack size increase is explicitly configured |
| Skip `--user` flag in post-install Docker run commands | Fewer flags to manage | Root-owned project files on host; breaks developer workflow immediately | Never |
| Expose port 443 directly from PHP service | Simpler Traefik-less setup | Port conflicts; prevents multi-service Swarm deployments | Only for single-service no-Traefik setup (not this template's goal) |
| Copy Laravel's `.env.example` structure verbatim | Quick start | Laravel-specific keys (e.g., `APP_KEY` format, `MIX_*`) confuse Symfony users | Never — create a Symfony-appropriate `.env.example` |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Traefik + FrankenPHP | Telling Traefik to forward to port 443 (HTTPS) on the PHP container | Configure Traefik to forward HTTP to the internal port (8080) and let Traefik terminate TLS |
| FrankenPHP + Symfony DI | Assuming warm cache is available at container start without running `cache:warmup` | Add `php bin/console cache:warmup` to the Dockerfile `deploy` stage RUN command |
| Mailpit + Symfony Mailer | Configuring `MAILER_DSN` with a port that conflicts with Mailpit's actual SMTP port | Mailpit listens on port 1025 for SMTP; set `MAILER_DSN=smtp://mailpit:1025` in dev compose |
| Docker Swarm secrets + Symfony | Leaving `DATABASE_URL` in `.env` when also configuring it via Swarm secrets | Remove or empty the key in `.env`; the file value wins over runtime secrets when both are present |
| serversideup/php frankenphp image + healthcheck | Using `HEALTHCHECK_PATH=/healthcheck` which Symfony does not expose by default | Use the Caddy metrics endpoint `localhost:2019/metrics` or add a `/healthcheck` route to Symfony |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Development bind mount for `var/` without named volume override | Every page load is 3-10x slower than expected in dev | Use a named volume for `var/`; never bind-mount the cache directory to the host | Immediately on first `spin up` |
| Worker mode without `frankenphp_loop_max` | Memory grows unbounded; container OOM-killed after hours of use | Set `frankenphp_loop_max 500` (or similar) in Caddyfile worker config | After extended uptime (hours to days depending on app size) |
| No `cache:warmup` in deploy stage | First request after deploy is 5-15x slower (cache generation on-demand) | Run `php bin/console cache:warmup --no-debug` in Dockerfile `deploy` stage | On every cold deploy |
| Alpine FrankenPHP with default stack size under Symfony load | Container freezes or crashes under moderate concurrency | Use Debian image or increase stack size at build time | Under concurrent load that triggers deep DI recursion |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing `.env` with a real `APP_SECRET` | Secret leaks to any repo reader; all Symfony security tokens (CSRF, remember-me cookies) can be forged | `.env` must contain only empty or obviously fake values; real secrets go in Docker Swarm secrets |
| Exposing the Caddy admin API port (2019) publicly | Full Caddy config read/write access to anyone who reaches port 2019 | Never expose port 2019 in docker-compose; the admin API is for localhost introspection only |
| Using `APP_ENV=dev` in production because it "shows more errors" | Full stack traces, internal paths, and environment info exposed to users | Enforce `APP_ENV=prod` in docker-compose.prod.yml; never leave dev mode in prod |
| Mounting Docker socket into the PHP service | PHP code (or an attacker) can control the Docker daemon | Only Traefik needs the Docker socket; never mount it into the PHP service |
| Self-signed certificates committed to the repo | MITM attacks possible if users trust these certs system-wide | Self-signed dev certs are acceptable in `.infrastructure/` for local use only; document they must never be used in production |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| `install.sh` header still says "Let's get Laravel launched!" | Confuses Symfony developers; erodes trust in the template | Update all Laravel-specific messaging to Symfony; change ASCII header text and prompts |
| No Symfony-specific health route documented | Developers don't know how to configure their load balancer or Swarm health check | Document the Caddy metrics endpoint and recommend adding a `/healthcheck` controller action |
| Worker mode enabled in dev without code-watching | Developers edit code but changes require manual container restart | Configure FrankenPHP watch mode for dev (`FRANKENPHP_CONFIG: watch`) but warn about Docker bind mount detection limitations |
| No `.env` guidance for Symfony vs. Laravel differences | Developers set `APP_KEY` (a Laravel concept) instead of `APP_SECRET` | Template `.env.example` must use Symfony variable names with inline comments explaining each one |
| `post-install.sh` installs Laravel-specific packages (e.g., `serversideup/spin` as Laravel dep) | Package resolution errors or wrong dependencies installed | Remove Laravel-specific composer require calls; keep only Symfony-compatible packages |

---

## "Looks Done But Isn't" Checklist

- [ ] **Caddyfile document root:** Often set to `/var/www/html` — verify it points to `/var/www/html/public`
- [ ] **Traefik port label:** Often copied as port 8080 from nginx images — verify the label matches the actual port FrankenPHP listens on in the Caddyfile
- [ ] **Cache warmup in deploy stage:** Often skipped "because Symfony does it automatically" — verify `php bin/console cache:warmup --no-debug` runs in Dockerfile `deploy` stage
- [ ] **Named volume for var/:** Often omitted from dev compose — verify `docker-compose.dev.yml` includes a named volume overlay for `/var/www/html/var`
- [ ] **Install.sh user flag:** Often dropped in adaptation — verify `docker run` in `new()` passes `--user "${SPIN_USER_ID}:${SPIN_GROUP_ID}"`
- [ ] **APP_ENV in prod compose:** Often missing or left as `dev` — verify `docker-compose.prod.yml` sets `APP_ENV=prod`
- [ ] **Alpine + FrankenPHP warning:** Often silently selected — verify `install.sh` emits a clear warning when Alpine + FrankenPHP is chosen
- [ ] **Worker mode loop max:** Often unconfigured — verify `frankenphp_loop_max` is set in the worker Caddyfile
- [ ] **Healthcheck route exists or metrics endpoint used:** Often `HEALTHCHECK_PATH=/healthcheck` but no Symfony route — verify the health check endpoint is reachable
- [ ] **Laravel-specific strings removed:** Often missed in search-replace — verify no references to `laravel`, `artisan`, `APP_KEY`, or `storage/` remain in template files

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong document root (all 404s) | LOW | Update `root *` in Caddyfile to point to `public/`, rebuild container, restart |
| Port 80/443 conflict with Traefik | LOW | Remove port mappings from PHP service in compose, change Caddyfile to internal port, restart |
| Alpine stack size crash | MEDIUM | Rebuild with Debian base image tag; or rebuild custom FrankenPHP binary with increased stack size |
| Root-owned project files from install | MEDIUM | `sudo chown -R $(id -u):$(id -g) .` on host; fix `--user` flag in install.sh; re-run |
| Stale entity manager in worker mode | MEDIUM | Add `frankenphp_loop_max 100` as temporary safety net; investigate ResetInterface on affected services |
| APP_SECRET committed to repo | HIGH | Rotate the secret immediately; force-push history rewrite or GitHub secret scanning; update all prod secrets |
| var/ bind mount performance | LOW | Add named volume to dev compose; restart with fresh volume |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Wrong document root (404 all routes) | Phase 1: Dockerfile + Caddyfile scaffold | `curl -I http://localhost` returns non-404 after `spin up` |
| Traefik/FrankenPHP port conflict | Phase 1 + Phase 2: Compose + Traefik setup | Both Traefik and PHP containers start cleanly; Traefik routes to PHP |
| Alpine stack size crash | Phase 1: Base image selection in install.sh | FrankenPHP worker mode completes 100 concurrent requests without freezing |
| var/ bind mount performance | Phase 2: docker-compose.dev.yml | `time curl localhost` shows sub-200ms response in dev |
| Root-owned files from install | Phase 3: install.sh authoring | `ls -la` in new project shows host user owns all files |
| APP_ENV/APP_SECRET env var confusion | Phase 4: docker-compose.prod.yml | `bin/console debug:container --env-vars` in prod mode shows correct values |
| Worker mode entity manager staleness | Phase 1 (Caddyfile config) + README | Doctrine entity reads consistent across 1000 sequential requests in worker mode |
| Laravel strings in template | Phase 3: post-install.sh + template files | `grep -r "laravel\|artisan\|APP_KEY" template/` returns no results |

---

## Sources

- FrankenPHP Worker Mode docs: https://frankenphp.dev/docs/worker/
- FrankenPHP Performance docs: https://frankenphp.dev/docs/performance/
- FrankenPHP Docker docs: https://frankenphp.dev/docs/docker/
- Alpine FrankenPHP freeze/crash issue: https://github.com/php/frankenphp/issues/1722
- Stack size fatal error issue: https://github.com/php/frankenphp/issues/380
- Watch mode + Docker bind mount issue: https://github.com/php/frankenphp/issues/1616
- Symfony kernel reset services discussion: https://github.com/symfony/symfony/issues/59997
- Entity manager not reopened between requests: https://github.com/php/frankenphp/issues/1707
- Worker mode best practices discussion: https://github.com/php/frankenphp/discussions/1486
- Worker mode Symfony compatibility guide: https://github.com/php/frankenphp/discussions/2174
- FrankenPHP behind Traefik discussion: https://github.com/php/frankenphp/issues/344
- Symfony file permissions docs: https://symfony.com/doc/current/setup/file_permissions.html
- Symfony configuration docs (env var priority): https://symfony.com/doc/current/configuration.html
- APP_SECRET not set in production issue: https://github.com/dunglas/symfony-docker/issues/798
- Missing worker config breaks prod build: https://github.com/dunglas/symfony-docker/issues/769
- Symfony Docker permission issues: https://github.com/dunglas/symfony-docker/issues/414
- FrankenPHP running from project root (not public/) issue: https://github.com/php/frankenphp/issues/1723
- OPcache and .env reload issue: https://github.com/php/frankenphp/issues/457
- serversideup/php FrankenPHP image docs: https://serversideup.net/open-source/docker-php/docs/image-variations/frankenphp

---
*Pitfalls research for: Spin Template Symfony — Symfony 7 LTS + FrankenPHP Docker Template*
*Researched: 2026-03-18*
