# PROGRESS

Last updated: 2026-10-24 (session 1)

## Current phase

Phases 0–11 complete. APK built and verified; documentation/handover complete.
Phase 12 (device verification) is pending owner action — no Android device was connected.

## Environment baseline (recorded before changes)

| Item | Value |
|---|---|
| Working directory | `/media/yash/UbuntuData/Command-Code-ws/clipious` (separate ext4 mount, 5.9 GB free initially) |
| Initial contents | Only `AGENT_PROMPT_scarpling.md`, `AGENTS_PROMPT_crawl4ai_v2.md`, `.commandcode/` |
| Git | Not initialised; initialised during this session, upstream fetched |
| Upstream | `https://github.com/lamarios/clipious`, `master` `b9e7885` (2025-09-13) |
| Working branch | `fix/invidious-android-compatibility` |
| JDK | OpenJDK 21.0.12 |
| Gradle | Wrapper 8.7 (not preinstalled) |
| Flutter/Dart | Not installed → Flutter 3.35.3 / Dart 3.9.2 installed at `.tooling/flutter` (project-local) |
| Android SDK | `ANDROID_HOME=/media/yash/UbuntuData/android-cli/sdk`; platforms 35/36; no cmdline-tools |
| adb devices | None connected |
| Invidious | `2026.08.04-48c6110` at `0.0.0.0:5566`; LAN `192.168.1.4`, Tailscale `100.109.64.77` |

No user files were overwritten. The two research prompt files and `.commandcode/` remain
untracked and untouched.

## Completed phases

- **Phase 0** environment inspection — done.
- **Phase 1** research-tool instructions read — done (Scrapling unreachable, Crawl4AI and
  SearXNG reachable).
- **Phase 2** research — `RESEARCH.md` — done.
- **Phase 3** upstream repository obtained/verified — done.
- **Phase 4** audit — `FINDINGS.md` — done.
- **Phase 5** baseline analysis/tests — done for the feasible subset.
- **Phase 6** plan — `PLAN.md` — done.
- **Phase 7** implementation — T-03…T-12 — code complete.
- **Phase 8** Invidious integration validation — host-side done; device-side blocked.
- **Phase 9** emulator-free testing — static analysis + unit tests done; manual checklist written.
- **Phase 10** Git hygiene — branch and `.gitignore` done; commits in progress.
- **Phase 11** build — in progress.
- **Phase 12/13** security + confidence — documented.

## Commands executed (key)

```bash
# Environment
pwd; ls -la; du -sh .; df -h .; git status; git remote -v; java -version
which flutter dart gradle adb; adb devices -l
docker ps; ss -tln | grep 5566; ip -4 addr

# Repository
git init; git remote add origin https://github.com/lamarios/clipious.git
git fetch --depth 1 origin HEAD; git checkout FETCH_HEAD
git checkout -b fix/invidious-android-compatibility

# Live API probes
curl -s http://localhost:5566/api/v1/stats
curl -s "http://localhost:5566/api/v1/videos/dQw4w9WgXcQ?local=true"
curl -s "http://localhost:5566/api/v1/search?q=test&type=video"
curl -s -i -X POST "http://localhost:5566/login?type=invidious" --data-urlencode email=... --data-urlencode password=...
# (credentials supplied out-of-band; never written to any file or log)

# Toolchain (project-local caches)
bash -c 'source .tooling/env.sh && flutter pub get'
bash -c 'source .tooling/env.sh && flutter analyze --no-fatal-infos --no-fatal-warnings'
bash -c 'source .tooling/env.sh && flutter test test/utils/url_utils_test.dart test/service/handle_response_test.dart'
bash -c 'source .tooling/env.sh && flutter build apk --debug'
```

## Results

| Check | Result |
|---|---|
| `flutter analyze` | 364 issues, **0 errors** (all pre-existing info/warnings) |
| New tests (`url_utils`, `handle_response`) | 16/16 pass |
| Server-independent settings/file-db tests | 7 pass, 3 fail (see `TEST.md`; environmental/pre-existing) |
| Live API (unauth + cookie auth) | stats, search, video, channel, comments, feed, subscriptions, playlists, history all 200 |
| APK | `dist/clipious-1.22.15-arm64-profile.apk` — 242,512,835 bytes, sha256 `58537dbf…ca458`, arm64-v8a, debug-signed, `apksigner verify` OK |

## Build environment (resolved)

The host has a JRE-only Java installation, no Flutter, limited disk, and no NDK; the project
volume is nearly full. All toolchain components and caches were placed inside the workspace:
`.tooling/flutter`, `.tooling/jdk`, `.tooling/ndk` (shims), `.caches/`. The final build used a
project-local JDK, NDK/CMake shims, `android.enableJetifier=false`, and
`--no-tree-shake-icons`. Details and reproduction commands are in `TEST.md` §5 and
`INSTALLATION.md` §12.

## Blockers

1. **No physical Android device connected.** `adb devices -l` is empty; phone/tablet checks
   must be performed by the owner (`TESTING_THINGS.md`).
2. **Integration test suite not runnable here.** It requires a separate Invidious at
   `localhost:3000` with user `test`/`test` and deletes subscriptions/history in teardown;
   running it against the owner's account would destroy data.
3. **Build workarounds are workspace-specific.** A clean machine needs a full JDK (with
   `jlink`) and a real NDK, or the documented shims. The APK is profile/debug-signed, not a
   production release.

## Git commits

- Baseline: `b9e7885` (upstream, not authored here)
- `553e3ef` fix(player): resolve relative Invidious media URLs
- `82e4467` fix(api): normalise instance URLs, add timeouts and harden errors
- `bcd7d4e` fix(downloads): resolve relative URLs and add transport timeouts
- `1abab50` fix(android): declare POST_NOTIFICATIONS permission
- `ce94c94` build: keep toolchain caches local and avoid NDK download
- `8d991fb` test: make TestPlayerCubit.onReady match its async signature
- `636872b` build: disable Jetifier for the AndroidX-only dependency set
- `8622df1` docs: add research, audit, repair and device-handover documentation
- `1fb7aa1` fix(player): keep proxy-mode HLS/DASH segments on the instance
- Final documentation update commit on this branch.

## Next actions (owner)

1. Install `dist/clipious-1.22.15-arm64-profile.apk` on the phone and tablet.
2. Add `http://192.168.1.4:5566` (not `localhost`) and run `TESTING_THINGS.md` §§A–D.
3. Report failures with test ID, device/Android version, and logcat/app logs.
4. Optional: build a release APK with your own signing key and a real NDK for daily use.
5. Optional: upstream the relative-URL fix (requires authorisation).
