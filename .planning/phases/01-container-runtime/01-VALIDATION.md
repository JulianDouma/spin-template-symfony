---
phase: 1
slug: container-runtime
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | docker build + shell assertions |
| **Config file** | Dockerfile (template/Dockerfile) |
| **Quick run command** | `docker build --target development --build-arg PHP_VARIATION=frankenphp -t test-symfony .` |
| **Full suite command** | `docker build --target deploy --build-arg PHP_VARIATION=frankenphp -t test-symfony . && docker run --rm test-symfony php -v` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `docker build --target development --build-arg PHP_VARIATION=frankenphp -t test-symfony .`
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | DOCK-01 | build | `docker build --target development .` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | DOCK-02 | build | `docker build --build-arg PHP_VERSION=8.4 --build-arg PHP_VARIATION=fpm-nginx .` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | DOCK-03 | build | `docker build --target development --build-arg USER_ID=1000 --build-arg GROUP_ID=1000 .` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | DOCK-04 | build | `docker build --target deploy .` | ❌ W0 | ⬜ pending |
| 01-01-05 | 01 | 1 | DOCK-05 | build | `docker build --target ci .` | ❌ W0 | ⬜ pending |
| 01-01-06 | 01 | 1 | RT-01 | runtime | `docker run --rm test-symfony env \| grep CADDY_SERVER_ROOT` | ❌ W0 | ⬜ pending |
| 01-01-07 | 01 | 1 | RT-02 | runtime | `docker run --rm test-symfony curl -s http://localhost:8080/healthcheck` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `template/Dockerfile` — multi-stage Dockerfile with all targets
- [ ] `template/.infrastructure/entrypoint.d/10-cache-warmup.sh` — entrypoint hook for Symfony cache warmup
- [ ] `.dockerignore` — exclude .git, .planning, node_modules, var/cache, var/log

*Existing infrastructure: none (greenfield)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ARG interpolation produces correct image tag | DOCK-02 | Requires inspecting build output for FROM line | Run `docker build --build-arg PHP_VERSION=8.4 --build-arg PHP_VARIATION=fpm-nginx .` and verify output shows `FROM serversideup/php:8.4-fpm-nginx` |
| Alpine suffix appended correctly | DOCK-02 | OS suffix logic needs visual verification | Run with `--build-arg PHP_OS_SUFFIX=-alpine` and verify tag |

*All other behaviors have automated verification via docker build.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
