---
phase: 3
slug: install-scripts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash syntax check + grep assertions |
| **Config file** | install.sh, post-install.sh, meta.yml |
| **Quick run command** | `bash -n install.sh && bash -n post-install.sh` |
| **Full suite command** | `bash -n install.sh && bash -n post-install.sh && grep -q "symfony" meta.yml` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash -n` syntax check on modified scripts
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must pass
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | SPIN-01 | grep | `grep -q "symfony" meta.yml` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | SPIN-02..05 | syntax | `bash -n install.sh` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | SPIN-06..08, RT-03 | syntax | `bash -n post-install.sh` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 1 | SPIN-09 | dir | `test -d template/` | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `meta.yml` — template registration with Spin CLI
- [ ] `install.sh` — interactive prompts + new()/init() dispatch
- [ ] `post-install.sh` — Symfony skeleton install + file patching

*Existing infrastructure: template/ directory with Dockerfile, compose files, Traefik config from Phases 1-2*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `spin new symfony` runs end-to-end | SPIN-02 | Requires Spin CLI + Docker daemon + interactive prompts | Run `spin new symfony test-app` and complete all prompts |
| Symfony skeleton is installed | SPIN-06 | Requires Docker pull + composer create-project | Verify `vendor/` and `symfony.lock` exist after `spin new` |
| PHP extensions prompt works | SPIN-03 | Interactive terminal input | Select different PHP versions and verify Dockerfile ARG changes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
