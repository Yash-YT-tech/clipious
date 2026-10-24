# PLAN — Clipious with self-hosted Invidious

Created: 2026-10-24
Baseline: `b9e7885` (Clipious `1.22.15+6077`)
Target: Android phone + tablet, Invidious `2026.08.04-48c6110`

## 1. Objectives

1. Establish a reproducible environment and evidence baseline.
2. Make instance configuration, search, browsing, authentication, playback, downloads and
   persistence work against the self-hosted Invidious instance.
3. Fix confirmed defects without rewriting working subsystems.
4. Keep all tooling, caches and build outputs inside this workspace (owner instruction).
5. Produce an installable APK and a physical-device verification plan for the owner.
6. Document verified facts separately from untested assumptions.

## 2. Scope and exclusions

**In scope**

- Android Flutter client, API layer, models as needed, player URL handling, downloads,
  settings/persistence, manifest, and network/security configuration.
- Live API validation against `http://localhost:5566`.
- APK build and adb/manual installation instructions.

**Out of scope / not changed**

- Invidious server configuration, Docker compose, firewall, DNS, or public exposure.
- Creating/deleting Invidious users or modifying the owner's subscriptions/history.
- Emulator installation (prohibited) or Android SDK reinstallation.
- iOS/desktop/web parity.
- Migrating credentials to the Android keystore (documented follow-up).
- Upstream pull requests (not authorised).

## 3. Architecture overview

```
Flutter UI (bloc/cubit, auto_route)
  └─ Service (package:http, 30 s timeout, URL normalisation)
       ├─ Invidious REST API (/api/v1/…)   ← instance base URL from Sembast
       ├─ SponsorBlock / DeArrow (optional, external)
       └─ Media URL resolution (url_utils)
             ├─ BetterPlayer / ExoPlayer (video, DASH, HLS)
             ├─ just_audio (audio-only)
             └─ Dio (downloads)
Persistence: Sembast+sqflite (main isolate) / JSON files (WorkManager isolate)
```

## 4. Prioritised tasks

| Task | Findings | Description | Risk | Status | Commit |
|---|---|---|---|---|---|
| T-01 | — | Environment, repo and toolchain baseline | Low | DONE | see PROGRESS.md |
| T-02 | — | Research Clipious/Invidious API and auth | Low | DONE | see PROGRESS.md |
| T-03 | BUG-001, BUG-011 | Resolve relative media URLs; guard empty streams | Medium | DONE | see PROGRESS.md |
| T-04 | BUG-002 | Stop rejecting relative thumbnails; normalise/validate server URL | Low | DONE | see PROGRESS.md |
| T-05 | BUG-003 | Resolve download URLs; add Dio timeouts | Medium | DONE | see PROGRESS.md |
| T-06 | BUG-004 | Add global HTTP request timeout | Low | DONE | see PROGRESS.md |
| T-07 | BUG-005 | Normalise trailing slashes everywhere | Low | DONE | see PROGRESS.md |
| T-08 | BUG-006 | Declare `POST_NOTIFICATIONS` | Low | DONE | see PROGRESS.md |
| T-09 | BUG-007 | Remove cookie from login error path | Low | DONE | see PROGRESS.md |
| T-10 | BUG-008 | Robust response/error decoding | Low | DONE | see PROGRESS.md |
| T-11 | BUG-009, BUG-010 | Resolve TV banner and notification artwork URLs | Low | DONE | see PROGRESS.md |
| T-12 | — | Regression tests for URL resolution and response handling | Low | DONE | see PROGRESS.md |
| T-13 | — | Static analysis and server-independent tests | Low | DONE | see PROGRESS.md |
| T-14 | — | Build arm64 profile APK | Medium | DONE | artifact in `dist/` |
| T-15 | BUG-012, BUG-013 | Document cleartext and credential-storage trade-offs | Low | DONE (docs) | — |
| T-16 | — | Physical-device checklist and installation guide | Low | DONE (docs) | — |
| T-17 | BUG-015, BUG-016 | Fix/provide test server for integration tests | Medium | DEFERRED | — |
| T-18 | — | Device installation and playback verification | — | BLOCKED (no device) | — |

Dependencies: T-03…T-11 depend on T-01/T-02; T-13 depends on T-03…T-12; T-14 depends on T-13;
T-18 depends on T-14 and owner-connected hardware.

## 5. Repair strategy

- Small, reviewable diffs; one logical concern per commit.
- New pure helper (`url_utils.dart`) with unit tests instead of duplicating string logic.
- Preserve existing public behaviour: absolute URLs pass through unchanged.
- Do not modify generated `*.g.dart`/`*.freezed.dart` files.
- Do not change the Invidious deployment.
- Keep the `.tooling/` SDK and `.caches/` out of Git via `.gitignore`.

## 6. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Disk exhaustion on the 99 GB volume (94 % used) | Build failure | Project-local caches, remove SDK archive after extraction, monitor `df`, avoid duplicate artifacts |
| DASH/proxy behaviour differs on device | Playback still broken | Resolve all URL forms; owner device test with and without DASH/proxy; logs |
| Auth credentials unavailable in test harness | Unverified logged-in flows on device | Cookie login verified live from host; token flow documented; owner tests |
| Clearing server config during testing | Data loss | Integration tests not run against the real account; no server changes |
| Cleartext HTTP | Security exposure | Documented; HTTPS recommended; no global TLS weakening added |
| CompileSdk 36 with AGP 8.6 | Build warning/failure | Build will confirm; document any warning |

## 7. Acceptance criteria

- `flutter analyze` reports no **errors**.
- New regression tests pass.
- APK is produced and its path/size recorded.
- Instance can be added without disabling the advanced test (verified by code path; device
  confirmation pending).
- Playback code produces absolute URLs for DASH, HLS, progressive and proxied streams
  (unit-tested resolver; device confirmation pending).
- All nine project documents exist with real content.
- Remaining device tests are explicitly marked NOT TESTED.

## 8. Milestones

| Milestone | Status |
|---|---|
| M0 Environment + Git baseline | DONE |
| M1 Research (`RESEARCH.md`) | DONE |
| M2 Audit (`FINDINGS.md`) | DONE |
| M3 Baseline tests/analysis | DONE |
| M4 Implementation (T-03…T-11) | DONE (code) |
| M5 Regression tests | DONE |
| M6 APK build | DONE (arm64 profile APK verified) |
| M7 Documentation/handover | DONE |
| M8 Physical-device verification | BLOCKED / owner action |

## 9. Deferred work

- Migrate tokens/SID to encrypted storage.
- Restrict cleartext traffic or add a user-configurable network security policy.
- Restore a runnable integration-test environment (separate Invidious at `localhost:3000`,
  dedicated user) or rewrite tests against mocks/fixtures.
- Upstream the relative-URL fix (requires owner authorisation).
