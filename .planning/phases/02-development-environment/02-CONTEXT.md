# Phase 2: Development Environment - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Docker Compose base config + dev overlay with Traefik reverse proxy, self-signed SSL, volume mounts for live editing, and a named `var/` volume overlay. Does NOT include production compose, install scripts, or documentation — those are later phases.

</domain>

<decisions>
## Implementation Decisions

### Compose Structure
- Use Spin CLI naming convention: `docker-compose.yml` (base), `docker-compose.dev.yml` (dev overlay), `docker-compose.prod.yml` (Phase 4)
- Modern `compose.yaml` syntax was considered but Spin CLI requires `docker-compose.yml` for `spin up` / `spin deploy` compatibility
- PHP service named `php` — consistent with Spin ecosystem
- Base compose is minimal — just the `php` service definition, designed to be extended by overlays

### Traefik + SSL
- Keep it simple for v1 — localhost via `HostRegexp`, no configurable custom domains
- Generate fresh self-signed SSL certificates for this template (not copied from Laravel template)
- Traefik config: Docker provider for service auto-discovery + file provider for SSL certificates
- `.infrastructure/conf/traefik/dev/` directory with traefik.yml, traefik-certs.yml, and certificates/
- Traefik dashboard accessible in dev

### Volume Strategy
- Bind mount `.:/var/www/html` for live code editing
- Named volume overlay on `var/` — prevents cache/log performance degradation on macOS
- `vendor/` stays in bind mount (no overlay) — IDE needs it for autocompletion and static analysis
- Dev compose builds from Dockerfile with `development` target, passes `USER_ID`/`GROUP_ID` args

### Services
- Dev compose includes only Traefik + PHP — minimal, unopinionated
- No Mailpit service shipped — document how to add it in README instead (it's just a service definition + `MAILER_DSN` env var)
- No Node service — users add their own frontend tooling if needed

### Claude's Discretion
- Exact Traefik label configuration on the PHP service
- Network naming (likely `development` to match Laravel template)
- Exact self-signed cert generation parameters (CN, SAN, expiry)
- Build args passing in dev compose (USER_ID, GROUP_ID)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spin Template Reference
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.yml` — Laravel base compose pattern
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/docker-compose.dev.yml` — Laravel dev compose with Traefik, Mailpit, Node
- `/Users/juliandouma/Developer/oss/spin/spin-template-laravel-basic/template/.infrastructure/conf/traefik/dev/` — Laravel dev Traefik config and SSL certs

### Phase 1 Output
- `/Users/juliandouma/Developer/oss/spin-template-symfony/template/Dockerfile` — The Dockerfile this compose references (development target)

### serversideup/php
- Environment variable specification: https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `template/Dockerfile` — Already has `development` target with USER_ID/GROUP_ID args, ready for compose to reference

### Established Patterns
- serversideup/php env vars for runtime config (no custom Caddyfile/nginx/apache)
- Spin CLI convention: `docker-compose.yml` + `docker-compose.dev.yml` + `$SPIN_ENV` for environment switching

### Integration Points
- `docker-compose.dev.yml` builds from `template/Dockerfile` with `--target development`
- Traefik labels on `php` service route traffic to the container
- `.infrastructure/` directory already exists (has `entrypoint.d/`), Traefik configs go alongside

</code_context>

<specifics>
## Specific Ideas

- "The best code is no code at all" — keep compose files as minimal as possible, delegate to serversideup/php defaults
- Mailpit is trivially addable (service + env var) — document in README, don't ship

</specifics>

<deferred>
## Deferred Ideas

- Configurable local domain (custom .test domain, mkcert integration, dnsmasq for zero-config DNS) — future enhancement for v2 or pro template
- Node service for frontend asset compilation — users add if needed

</deferred>

---

*Phase: 02-development-environment*
*Context gathered: 2026-03-18*
