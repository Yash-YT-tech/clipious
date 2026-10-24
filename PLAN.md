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
| T-18 | — | Device installation and playback verification | — | DONE (tablet) / phone pending | `TEST.md` §6 |
| T-19 | BUG-017 | Fix comments schema (`authorThumbnail`) and add tests | Medium | DONE | `499b6ca` |
| T-20 | BUG-018 | Fix `youtu.be` intent filter / remove autoVerify | Low | DONE | `3a581a7` |
| T-21 | BUG-019 | DASH fallback for live streams; stop stale playback | Medium | DONE (client) / live blocked server-side | `705bc7c` |
| T-22 | BUG-020…022 | Document media-session, startup and 533 dp findings | Low | DONE (docs) | — |
| T-23 | BUG-024 | Codec labels, hardware-first quality, Auto option | Medium | DONE | `3514960` |
| T-24 | FEATURE-001 | Hold-to-2× gesture with badge and speed restore | Medium | DONE | `3514960` |
| T-25 | — | Logged-in Subscriptions/Playlists/History read-only verification | Low | DONE (tablet) | `TEST.md` §6 |
| T-26 | MOTION-001 | Motion tokens, curves, player/tab/queue fades, reduced motion | Medium | DONE | `2209782` |
| T-27 | PERF-001…003 | Thumbnail render path, lazy grid, build scope, progress writes | High | DONE | `2209782` |
| T-28 | — | On-device UI parity, controls/2×/quality/tabs, reduced-motion smoke | Medium | DONE | `TEST.md` §7.5 |
| T-29 | — | Formal DevTools UI/raster p95 trace | Medium | NOT RUN | Next measured pass |

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
- Instance can be added without disabling the advanced test — **confirmed on the tablet**.
- Playback produces absolute URLs for DASH, HLS, progressive and proxied streams —
  **confirmed on the tablet** (DASH on/off, proxy+DASH).
- Hardware H.264/VP9 quality options are available and sorted first; Auto resets to adaptive
  selection; hold-to-2× works and restores the prior speed — **confirmed on the tablet**.
- Logged-in Subscriptions/Playlists/History load read-only — **confirmed on the tablet**.
- All nine project documents exist with real content.
- Remaining device tests are explicitly marked NOT TESTED (phone, auth, live, network-loss
  partial).

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
| M8 Physical-device verification | PARTIAL: tablet PASS (except live), logged-in read-only PASS; phone and account mutations pending |
| M9 Motion/performance pass | PARTIAL: UI parity, fades, thumbnail/grid fixes and reduced-motion verified; formal frame trace and remaining rebuild splits pending |

## 9. Deferred work

- Migrate tokens/SID to encrypted storage.
- Restrict cleartext traffic or add a user-configurable network security policy.
- Restore a runnable integration-test environment (separate Invidious at `localhost:3000`,
  dedicated user) or rewrite tests against mocks/fixtures.
- Upstream the relative-URL, comments and link fixes (requires owner authorisation).
- Phone verification (the tablet pass is the reference).
- Live playback: correct the Invidious DASH manifest (`PTNaNS`) or enable HLS server-side.
- Performance: investigate the ~18–28 s cold start on the Lenovo tablet.
- Tablet layout: decide whether a 533 dp device should use tablet views (currently phone).
- 4K AV1 playback: this tablet has no AV1 hardware decoder; the app now labels/sorts it and
  recommends Auto/H.264, but true 4K AV1 smoothness requires different hardware.
- Motion second pass: capture DevTools traces, split the player overlay's progress listeners,
  share skeleton tickers, and make comments/recommended lazy.
