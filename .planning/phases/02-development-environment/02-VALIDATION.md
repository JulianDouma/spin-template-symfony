---
phase: 2
slug: development-environment
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | file existence + grep + docker compose config validation |
| **Config file** | template/docker-compose.yml, template/docker-compose.dev.yml |
| **Quick run command** | `grep -q "php:" template/docker-compose.yml && grep -q "traefik:" template/docker-compose.dev.yml` |
| **Full suite command** | `docker compose -f template/docker-compose.yml -f template/docker-compose.dev.yml config --quiet` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick grep checks
- **After every plan wave:** Run `docker compose config --quiet` validation
- **Before `/gsd:verify-work`:** Full config validation must pass
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | COMP-01,02 | grep | `grep -q "php:" template/docker-compose.yml` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | DEV-01..06 | grep | `grep -q "traefik:" template/docker-compose.dev.yml` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | TRAF-01,02 | file | `test -f template/.infrastructure/conf/traefik/dev/traefik.yml` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | TRAF-02 | file | `test -f template/.infrastructure/conf/traefik/dev/certificates/local-dev.pem` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | TRAF-05 | dir | `test -d template/.infrastructure/conf/traefik/dev` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `template/docker-compose.yml` — base compose with php service
- [ ] `template/docker-compose.dev.yml` — dev overlay with Traefik, volumes
- [ ] `template/.infrastructure/conf/traefik/dev/traefik.yml` — Traefik dev config
- [ ] `template/.infrastructure/conf/traefik/dev/traefik-certs.yml` — cert file provider config
- [ ] `template/.infrastructure/conf/traefik/dev/certificates/` — self-signed SSL certs

*Existing infrastructure: template/Dockerfile from Phase 1*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Services start without errors | DEV-01 | Requires Docker daemon + Symfony app installed | Run `docker compose -f docker-compose.yml -f docker-compose.dev.yml up` after Phase 3 installs Symfony |
| HTTPS works at localhost | TRAF-02 | Requires running Traefik + browser | Visit `https://localhost` after services are running |
| Live code editing works | DEV-02 | Requires running container + file edit | Edit a PHP file and verify change in browser |
| var/ uses named volume | DEV-03 | Requires running container | Run `docker volume ls` and verify symfony_var volume exists |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
