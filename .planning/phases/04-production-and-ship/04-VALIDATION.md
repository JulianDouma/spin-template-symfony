---
phase: 4
slug: production-and-ship
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash syntax check + grep + file existence |
| **Config file** | template/docker-compose.prod.yml, template/.infrastructure/conf/traefik/prod/traefik.yml |
| **Quick run command** | `grep -q "deploy:" template/docker-compose.prod.yml && grep -q "acme" template/.infrastructure/conf/traefik/prod/traefik.yml` |
| **Full suite command** | `bash -n post-install.sh && grep -q "deploy:" template/docker-compose.prod.yml && test -f template/.spin.yml && test -f README.md && test -f template/.env.example` |
| **Estimated runtime** | ~3 seconds |

---

## Sampling Rate

- **After every task commit:** Run relevant grep checks
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must pass
- **Max feedback latency:** 3 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | PROD-01..07 | grep | `grep -q "deploy:" template/docker-compose.prod.yml` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | TRAF-03,04 | grep | `grep -q "acme" template/.infrastructure/conf/traefik/prod/traefik.yml` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | SPIN-10 | file | `test -f template/.spin.yml` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | DOC-01 | file | `test -f README.md && grep -q "spin new symfony" README.md` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 1 | DOC-02 | file | `test -f template/.env.example && grep -q "APP_SECRET" template/.env.example` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `template/docker-compose.prod.yml` — prod compose with Swarm deploy config
- [ ] `template/.infrastructure/conf/traefik/prod/traefik.yml` — prod Traefik with ACME
- [ ] `template/.spin.yml` — starter Spin config
- [ ] `template/.env.example` — Symfony env vars
- [ ] `README.md` — documentation

*Existing infrastructure: Dockerfile, base/dev compose, Traefik dev config, install.sh, post-install.sh from Phases 1-3*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `docker stack deploy` starts services | PROD-01 | Requires Docker Swarm mode | Initialize Swarm and run `docker stack deploy -c docker-compose.yml -c docker-compose.prod.yml symfony` |
| Let's Encrypt cert issued | PROD-06 | Requires public domain + DNS | Deploy to a server with a real domain |
| post-install.sh label patching | RT-03 ext | Requires running install.sh with fpm-nginx | Run `spin new symfony` with fpm-nginx and verify prod compose labels |
| APP_SECRET auto-generated | DOC-02 ext | Requires running post-install.sh | Check `.env` after install for non-placeholder APP_SECRET |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 3s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
