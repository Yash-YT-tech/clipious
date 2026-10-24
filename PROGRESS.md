# PROGRESS

Last updated: 2026-10-24 (session 2)

## Current phase

Phases 0–11 complete. Physical-device verification was performed on the connected tablet
(Lenovo TB-8505F, Android 10) and new defects were fixed (comments, `youtu.be` links, live
fallback). The phone was not connected, so phone verification remains pending.

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
| New tests (`url_utils`, `handle_response`, `comments`) | 21/21 pass |
| Server-independent settings/file-db tests | 7 pass, 3 fail (see `TEST.md`; environmental/pre-existing) |
| Live API (unauth + cookie auth) | stats, search, video, channel, comments, feed, subscriptions, playlists, history all 200 |
| APK | `dist/clipious-1.22.15-arm64-profile.apk` — 242,512,835 bytes, sha256 `4fc439e3…47b81`, arm64-v8a, debug-signed, `apksigner verify` OK |
| Tablet device tests | PASS for install, server add, home/search/channels/playlists, VOD DASH/progressive/proxy, quality, audio-only, background, downloads, offline, comments (after fix), rotation; live streams BLOCKED by server manifest. See `TEST.md` §6 |
| Phone device tests | NOT RUN (phone not connected) |

## Device verification summary

- Device: Lenovo TB-8505F, Android 10 (API 29), arm64-v8a, 800×1280 @ 240 dpi (533 dp),
  2.0 GB free; Clipious was not installed, so the normal package was used.
- The advanced server test accepted `http://192.168.1.4:5566` (relative-URL fixes verified).
- VOD playback works with DASH on, DASH off, and Proxy+DASH (`?local=true`); quality switching,
  audio-only, background playback, media notification, 144p download and offline playback all
  passed.
- Comments crashed initially on the live schema and now render after the fix.
- Live streams remain blocked by the server's DASH manifest (`PTNaNS`); HLS is 403. The app
  fails gracefully and stops the previous video.
- `youtu.be` links were fixed in the manifest; the official YouTube app remains the default
  handler on this device.
- Cold start is slow (~18–28 s) on this tablet.

## Build environment (resolved)

The host has a JRE-only Java installation, no Flutter, limited disk, and no NDK; the project
volume is nearly full. All toolchain components and caches were placed inside the workspace:
`.tooling/flutter`, `.tooling/jdk`, `.tooling/ndk` (shims), `.caches/`. The final build used a
project-local JDK, NDK/CMake shims, `android.enableJetifier=false`, and
`--no-tree-shake-icons`. Details and reproduction commands are in `TEST.md` §5 and
`INSTALLATION.md` §12.

## Blockers

1. **Phone not connected.** The tablet was tested; the phone still needs the same pass.
2. **Live streams blocked server-side.** Invidious emits `mediaPresentationDuration="PTNaNS"`
   in the live DASH manifest and HLS returns 403. Client-side fallback/error handling is in
   place; server-side manifest correction or HLS enablement is required for live playback.
3. **Auth/subscriptions/history were skipped on-device** to avoid reading personal data.
4. **Network-loss search test was partial** (overlay submission not captured).
5. **Integration test suite not runnable here.** It requires a separate Invidious at
   `localhost:3000` with user `test`/`test` and deletes subscriptions/history in teardown;
   running it against the owner's account would destroy data.
6. **Build workarounds are workspace-specific.** A clean machine needs a full JDK (with
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
- `aed4e97` docs: record final APK hash, proxy DASH behavior and test counts
- `9a2f145` docs: record the final documentation commit hash
- `f065ec1` docs: mark plan milestones complete and correct artifact wording
- `196b160` docs: research scrcpy/Artemis and add the device test plan
- `705bc7c` fix(player): fall back to DASH when a live stream has no progressive/HLS URL
- `499b6ca` fix(comments): accept Invidious's single authorThumbnail field
- `3a581a7` fix(android): handle youtu.be short links
- Final device-test documentation commit on this branch.

## Next actions (owner)

1. Install `dist/clipious-1.22.15-arm64-profile.apk` on the phone and run
   `TESTING_THINGS.md` §§A–D.
2. Add `http://192.168.1.4:5566` (not `localhost`); the tablet test is the reference.
3. For live streams, fix the Invidious DASH manifest (omit `mediaPresentationDuration` for
   dynamic/live) or enable HLS; the client now shows a clear error instead of freezing.
4. Optional: set Clipious as the handler for YouTube links (the official YouTube app is the
   current default) and verify `youtu.be` links.
5. Optional: build a release APK with your own signing key and a real NDK for daily use.
6. Optional: upstream the relative-URL/comments/link fixes (requires authorisation).
