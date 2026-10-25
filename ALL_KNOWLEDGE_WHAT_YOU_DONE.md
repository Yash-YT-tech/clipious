# ALL KNOWLEDGE — Clipious, Flutter, Android/iOS, AI Agents, and Production

This is an engineering decision log and evidence trail, not a transcript of private
token-by-token reasoning. It records what was observed, which options were considered,
why a choice was made, how it was verified, and what should be done differently next
time. That is more reusable than a raw chain of thought.

Snapshot before this file was added:

- Repository: `https://github.com/Yash-YT-tech/clipious`
- Branch: `fix/invidious-android-compatibility`
- Main/branch commit: `b11cb3d7`
- APK: `dist/clipious-1.22.15-arm64-profile.apk`
- APK SHA-256: `15df93a2b4c48ac941426f90865076b297ff3334d4a411a98072f85f631863d1`
- Working tree: clean before this file
- Toolchain: removed after push (see `WHAT_TO_DEL_AND_KEEP.md`)
- Free space after cleanup: 18 GB

The current workspace no longer contains Flutter/JDK/Gradle caches, so this file cannot
rebuild the APK until the toolchain is redownloaded. The source, tests, docs, `.git`, APK,
and test evidence remain.

---

## 1. What Clipious is

Clipious is an Android client for a self-hosted or public **Invidious** instance. It is a
Flutter app with phone, tablet and Android TV interfaces. The upstream project is
`lamarios/clipious`, licensed **AGPL-3.0**. This fork adds compatibility repairs,
performance work and a responsive layout policy.

The app talks directly to Invidious HTTP APIs and to third-party privacy services such
as SponsorBlock and Return YouTube Dislike. It does not contain a YouTube player SDK or a
custom backend. Video playback uses a fork/family of `better_player` via `river_player`,
which wraps AndroidX Media3/ExoPlayer on Android.

Important product constraint: this is not an official YouTube client and does not use
YouTube APIs. Any production or commercial use needs a serious review of the AGPL,
YouTube/Invidious terms, app-store policy and copyright requirements. See §12.

### What “done” meant

The goal was not to redesign Clipious. It was to:

1. Make the existing app work reliably against a self-hosted Invidious instance.
2. Repair user-visible bugs without removing features.
3. Improve playback and UI performance on a weak Android tablet.
4. Add requested playback features (2× hold, codec-aware quality).
5. Preserve the existing visual design and settings.
6. Verify on a real device, build an installable artifact, document everything, and push it.
7. Clean up redownloadable storage without deleting source.

---

## 2. Constraints and operating rules

These constraints shaped almost every decision:

- All tooling, SDKs, caches and build artifacts had to live inside the project directory
  (`.tooling/`, `.caches/`). An early attempt to download Flutter into `/home` was stopped.
- No Android emulator. Testing used a physical Lenovo TB-8505F tablet.
- Do not read or modify personal data on the device. Authenticated screens were checked
  read-only; no subscribe/add/delete operations.
- Never write the Invidious password, SID cookie, or GitHub token into source, logs,
  screenshots, commits or docs.
- No destructive Git operations without authorization (`git clean`, `reset --hard`,
  force push).
- Do not push to GitHub until explicitly authorized. The owner later authorized pushes.
- The app had to stay usable on a 2 GB RAM, Android 10, 800×1280, 60 Hz tablet.
- Preserve features and settings. Performance work must not “optimize away” functionality.

The test device was disconnected partway through, so the final responsive-layout pass was
verified with breakpoint/widget tests and a profile build, not a fresh device install.

---

## 3. Stack map

### Application

| Layer | Technology |
|---|---|
| UI | Flutter 3.35.3 / Dart 3, Material 3, `dynamic_color` |
| State | `flutter_bloc` 9, `freezed`, cubits, immutable state |
| Routing | `auto_route` 10, nested tab routers, `AutoRouterObserver` |
| Video | `river_player` (BetterPlayer/ExoPlayer wrapper), AndroidX Media3 |
| Audio | `audio_service`, `just_audio`, audio_session |
| Networking | `http` + Dio, custom timeout client, JSON decode |
| Local DB | `sembast` + `sembast_sqflite`, legacy file DB |
| Images | `cached_network_image`, `flutter_svg` |
| Motion | `flutter_animate`, `flutter_fadein`, implicit Flutter animations |
| Downloads | Dio + `ffmpeg_kit_flutter_new_full` |
| Background | `workmanager`, `awesome_notifications` |
| Device | `device_info_plus`, `package_info_plus`, `wakelock_plus`, `simple_pip_mode` |
| Auth | Invidious cookie session / token; browser auth via `flutter_web_auth_2` |
| Links | YouTube deep links, share intent, `url_launcher` |

### Android build

- `compileSdk 36`, `targetSdk 36`, `minSdk 24`
- AGP 8.6.0, Kotlin 2.1.0, Java/Kotlin 21
- R8/minify + resource shrinking for release
- ABI version-code split; arm64-v8a profile APK was the device artifact
- Debug build was ~696 MB; profile arm64 was ~232 MB because it omits the debug engine
  and Vulkan validation layers. Profile is AOT, not JIT-debug.
- Local build uses project-local JDK/Flutter and small NDK/CMake/Gradle shims.

### Inspection/testing tools

`flutter analyze`, `flutter test`, `adb`, `uiautomator dump`, `screencap`, `screenrecord`,
`scrcpy 5.0.1`, `dumpsys media_session`, `dumpsys input_method`, `logcat`, `apksigner`,
`aapt2`, `unzip -t`, `curl`, Python JSON parsing, `git`, DevTools (planned).

---

## 4. Architecture map

### Startup

`lib/main.dart` now:

1. Initializes logging, HTTP overrides and the Flutter binding.
2. Opens `PackageInfo` and the Sembast/Sqflite DB **in parallel**.
3. Starts the TV check and selected-server check in parallel.
4. Constructs the router.
5. Runs the app.
6. Defers notification initialization and high-refresh display setup to a post-frame
   callback.
7. Settings initialization performs the legacy file-DB sync after the first frame.

This reduced steady cold start from roughly 4.3–5.1 s to 3.4–3.5 s; warm start is ~0.83 s.
The first launch immediately after installing the APK can still be ~8 s because Android is
dex-verifying/warming the package.

### Routing and shell

`lib/router.dart` uses `RootStackRouter` with separate phone, tablet and TV routes.
`AutoRoute` pushes `MaterialPage` routes; the app uses the standard Android Zoom page
transition (300 ms). `MyRouteObserver`:

- clears the focused text field and calls `TextInput.hide` on every push/pop;
- keeps the mini-player state correct when navigating.

The home shell uses a bottom `NavigationBar` for compact widths and a `NavigationRail` for
wide layouts. Video, channel and search screens have nested tab routers.

### State and data

The app is Bloc-first:

- `AppCubit`: server, login state, home layout, first tab.
- `SettingsCubit`: persisted settings and package info.
- `PlayerCubit`: queue, playback state, media events, mini/fullscreen transitions.
- `VideoPlayerCubit`/`AudioPlayerCubit`: implement `MediaPlayerCubit` and own the actual
  controllers.
- Screen cubits: home, search, channel, playlist, comments, downloads, notifications.
- `Service`: one HTTP client for Invidious, SponsorBlock, DeArrow, Return YouTube Dislike,
  Imgur and instance discovery.

Typical flow:

```
Invidious HTTP API
  -> Service (timeout, JSON, error normalization, URL resolution)
  -> Cubit (loading/error/items/progress)
  -> View (BlocBuilder/select)
  -> river_player/ExoPlayer for media
```

### Player

`PlayerCubit` owns app-level playback state and sends `MediaCommand`s. `VideoPlayerCubit`
and `AudioPlayerCubit` apply those commands to `river_player`/`just_audio`. The player
overlay is mounted in the root `MainScreen` stack, which is why mini/fullscreen state and
navigation interact. Progress events are throttled; the play queue is a `ListQueue`.
Downloads are separate Dio/ffmpeg work with progress events.

### Storage

Sembast over Sqflite stores servers, settings, search history, filters, progress,
downloads and caches. A legacy `FileDB` handles some notification/locale settings. The
server object holds URL, headers, auth token/SID. Credentials are currently stored in this
local DB; encrypted storage is deferred hardening, not production-ready.

### Responsive policy

Two concepts are deliberately separate:

- `getDeviceType()` uses the physical shortest-side rule for **feature/setting gating**
  (for example, the phone-only fullscreen-on-rotate setting).
- `useWideLayout()` uses the **current window** for layout only:
  - compact portrait <600 dp: phone shell;
  - 533 dp tablet landscape, 600 dp+ and foldables: wide shell;
  - wide-but-short phone landscape: compact shell.

This avoids breaking feature flags while allowing a 533 dp tablet to use a rail/two-pane
layout in landscape.

---

## 5. Toolchain: why the build was hard

This machine did not start with a usable Flutter Android toolchain.

Problems encountered:

1. **JRE-only system Java.** Gradle’s Android plugin needs a full JDK with `jlink`; the
   system install lacked it. A project-local JDK was used.
2. **No Flutter SDK.** Flutter 3.35.3 (matching the project’s submodule pin) was installed
   under `.tooling/flutter`.
3. **Disk pressure.** The project volume hit ~2 MB free during an early build.
   - Jetifier was consuming ~4.2 GB; the app is AndroidX-only, so it was disabled.
   - Disposable Gradle/Flutter caches were cleared.
   - Build was switched to a profile arm64-only APK.
4. **NDK/CMake.** Flutter’s Gradle plugin uses CMake/NDK only to strip native libraries;
   the project uses pre-stripped `.so` files. A project-local NDK descriptor/toolchain
   shim was created. The shim is intentionally a no-op strip; GNU strip cannot process
   ARM64 here.
5. **AGP rejected conflicting SDK homes.** `ANDROID_SDK_HOME` and `ANDROID_USER_HOME`
   pointing at different paths caused failure; only `ANDROID_USER_HOME` is used.
6. **`--no-tree-shake-icons`.** The local SDK lacked the `const_finder` artifact, so the
   build used this flag. This affects APK size, not runtime frame time.
7. **Shallow Git clone.** The local repo was shallow at `b9e7885`. A push failed with
   “did not receive expected object”; fetching `--unshallow` restored the missing object.
8. **GitHub token permission.** The first token could read but not write. A temp-ref test
   returned 403. After Contents write was granted, the push succeeded.

Representative build command:

```bash
source .tooling/env.sh
flutter build apk --profile --split-per-abi \
  --target-platform android-arm64 --no-pub --no-tree-shake-icons
```

Debug vs profile vs release:

- Debug: fastest iteration, huge APK, JIT, validation overhead. Not representative.
- Profile: AOT, near-release performance, debuggable service protocol, still debug-signed.
- Release: R8/minify/shrink; needs a real signing key. Required for Play/AAB.

The signed artifact currently in `dist/` is a **profile, debug-signed** build. It is fine
for owner testing, not for store distribution.

---

## 6. Timeline and decision log

### Phase 1 — Audit before changing code

What was done:

- Read README, pubspec, Android config, router, service, player and storage code.
- Mapped routes, cubits, API endpoints and player flow.
- Probed the self-hosted Invidious instance from the host with `curl`.
- Ran `flutter analyze` and existing tests to establish a baseline.
- Checked the tablet’s Android version, ABI, screen metrics and free space.

Why: changing code before understanding the data/API/player flow creates fake fixes.
The host API probes distinguished server bugs from client bugs.

### Phase 2 — Compatibility fixes

Root causes and fixes:

- **Relative media URLs** from Invidious are invalid for native players.
  Added `resolveInstanceUrl` and used it for DASH/HLS/progressive/captions, downloads,
  thumbnails and notification artwork.
- **Add-server advanced test** falsely rejected relative thumbnails; fixed.
- **No request timeouts** caused hangs; added a timeout HTTP client.
- **Trailing slashes** produced `//api/...` and HTML redirects; normalized instance URLs.
- **Malformed/non-JSON responses** were confusing; normalized into
  `InvidiousServiceError`.
- **Login error leakage:** error strings could contain the `SID` cookie; sanitized.
- **Android 13+ notifications** lacked `POST_NOTIFICATIONS`; added.
- **Comments crash:** Invidious returned `authorThumbnail` (string), while the model
  expected a list. Accepted both and null lists.
- **`youtu.be` links:** the intent filter required `/watch` and used `autoVerify` on
  unowned domains. Split filters and removed autoVerify.
- **Live/stale playback:** a live stream with no progressive/HLS source but a `dashUrl`
  must use DASH; if no source, stop the previous player and show an error.

### Phase 3 — Device testing without an emulator

Method:

- `adb devices -l`, `getprop`, `dumpsys package`.
- Install the APK and launch; capture UI with `uiautomator dump`.
- Tap with `adb shell input`.
- Capture screenshots with `screencap`.
- Record with scrcpy for visual verification.
- Inspect state with `dumpsys media_session`, `dumpsys input_method`, `logcat`.
- Use public test videos, not personal content.
- For authenticated screens: read-only checks only; no mutations.

Constraints:

- No emulator.
- No reading personal apps/photos/messages; no launcher capture.
- The tablet was a weak device, which exposed real performance/codec issues.
- The phone was never connected; phone tests are still pending.

### Phase 4 — Performance and playback quality

Observed:

- Default Auto playback selected **720p H.264 hardware** and was smooth.
- The quality menu exposed 2160p/1440p/1080p **AV1** tracks without codec labels.
  The tablet has no AV1 hardware decoder, so AV1 ran in software and lagged.
- 1080p H.264 hardware played with a low CPU sample (~11% in the observed window).

Fixes:

- Label quality tracks with codec; mark AV1 as software.
- Sort H.264/VP9/HEVC before AV1.
- Add `Auto (Recommended)` that clears manual track selection.
- Add a warning that AV1/4K may lag.
- Keep every original quality available.

Why: the app cannot make 4K AV1 smooth on a CPU without AV1 hardware. The correct UX is
to make the hardware path the default and disclose the tradeoff, not to remove features.

### Phase 5 — Hold-to-2× playback

Implemented:

- Long-press the video surface → temporary 2.0×.
- `2x` badge while held.
- Release restores the exact previous speed.
- Temporary speed is not persisted as the remembered speed.
- Gesture is disabled while controls are visible/mini/PiP.

Verified with logs (`Hold speed start: 1.0 -> 2.0`, `Hold speed stop -> 1.0`) and a badge
screenshot, on Auto/720p and 1080p H.264.

### Phase 6 — Motion and perceived smoothness

Research:

- Material 3: short 50–200 ms, medium 250–400 ms, long 450–600 ms, extra-long 700–1000 ms.
- Standard `Cubic(0.2,0,0,1)`, decelerate `Cubic(0,0,0,1)`, accelerate
  `Cubic(0.3,0,1,1)`.
- Flutter: 16.67 ms at 60 Hz, 8.33 ms at 120 Hz; avoid `saveLayer`, repeated opacity,
  clipping, eager lists and animating layout properties.
- Pinned Flutter 3.35: Android default `ZoomPageTransitionsBuilder` is 300 ms.
  `FadeForwardsPageTransitionsBuilder` is hard-coded to **800 ms**, so it was rejected.

Implemented:

- Motion tokens 100/150/200/250/300/350/500 ms with standard/decelerate/accelerate curves.
- Player chrome fades instead of hard cuts.
- 2× badge animates; player-tab content fades.
- Queue scroll 1000 → 350 ms; highlight 500 → 200 ms; mini progress 750 → 500 ms.
- Mini-player drag no longer retargets implicit animations every frame.
- Thumbnail server lookup moved out of `build`; decode capped to display width; image
  request kept mounted; `RepaintBoundary`.
- Home grid uses `GridView.builder`; download app-bar rebuilds are scoped.
- Progress is emitted before a throttled DB write.
- Reduced-motion support for new fades and page transitions.

Not changed: page transition style/duration, layout, colors, typography, component
hierarchy, settings, codec logic, or account behavior.

### Phase 7 — Keyboard/IME cleanup

Root cause:

- `SearchScreen` used `autofocus: query == null`. Focus and the IME connection persisted
  across pushes, so Gboard’s floating toolbar could remain over video/quality sheets.

Fix:

- Search focus is one-shot only when the search route is opened.
- Every route push/pop calls `FocusManager.primaryFocus?.unfocus()` and
  `TextInput.hide`.
- Search still shows the keyboard on entry; video/quality/back leave it hidden.

### Phase 8 — Startup optimization

Changes:

- Parallel `PackageInfo` + DB open.
- Parallel TV + server checks.
- File-DB sync moved into settings initialization after `runApp`.
- Notifications and high-refresh setup deferred to a post-frame callback.

Measured:

- Cold steady: 4.29/5.06 s → 3.40/3.46 s (further runs 3.40–3.47 s).
- Warm/hot: 0.83 s.
- First after install: ~8 s (Android dex/verification warm-up).

Honest limitation: this is not “instant” cold start. Reaching that needs a bootstrap
loading screen or a faster/lighter database open.

### Phase 9 — Responsive layout

Problem:

- `getDeviceType()` used `shortestSide < 600`; the 800×1280/240 dpi tablet is 533 dp, so it
  stayed phone-classified even in landscape.

Fix:

- Kept `getDeviceType()` for feature/setting gating.
- Added `useWideLayout()` based on current width/height for shell/layout:
  - compact portrait: phone;
  - 533 dp landscape, 600+ and foldables: wide;
  - wide-but-short phone landscape: compact.
- Applied to home nav/rail, video tabs, search, channel, player sizing, playlist grids,
  banner placeholders and content max width.
- Added 6 breakpoint tests + 4 `DeviceWidget` tests.

Why separate policies: changing device type globally would hide phone-only settings and
alter feature behavior. Layout should adapt; product features should not silently change.

### Phase 10 — Git and delivery

- Local history was clean; all changes were committed in small logical commits.
- The target repo had an unrelated `Initial commit` on `main`; the exact local branch was
  pushed.
- The owner then explicitly requested the repo populated, so `main` was force-updated to
  the exact local commit with `--force-with-lease`.
- A later clone was shallow and a push failed on a missing object; `git fetch --unshallow`
  fixed it without rewriting history.
- The token initially lacked Contents write; a temp-ref test proved the permission gap.
  After the owner granted write permission, the push succeeded.
- Final remote `main` and branch matched the local hash before the cleanup doc.

Production note: force-pushing `main` is acceptable only on a personal/empty repo with
explicit authorization. In a team/business repo, protect `main`, use PRs, required checks,
signed commits/tags and a release branch.

### Phase 11 — Storage cleanup

- Deleted only redownloadable SDKs/caches/build outputs.
- Kept source, tests, docs, `.git`, APK, test evidence, NDK shims, env script and token file.
- Project 17 GB → 440 MB; free space 1.6 GB → 18 GB.
- Wrote `WHAT_TO_DEL_AND_KEEP.md` with exact paths/sizes, optional deletions, future space
  requirement and redownload steps.

Tradeoff: the app cannot be rebuilt now until Flutter/JDK/Gradle/pub are redownloaded.
That is acceptable because the source and artifact are preserved; it is not acceptable if
you need to iterate immediately.

---

## 7. Bug and fix catalog

The full details are in `FINDINGS.md` and `FIXES.md`. High-level catalog:

| Area | Problem | Root cause | Resolution |
|---|---|---|---|
| Media URLs | DASH/progressive/captions failed | Invidious returns relative URLs; native players need absolute | URL resolver across API/player/downloads/artwork |
| Add server | Advanced test rejected valid server | Thumbnail URL was relative | Accept and resolve relative URLs |
| HTTP | Hangs/no clear errors | No timeout; non-2xx/non-JSON not normalized | Timeout client + typed errors |
| URL normalization | `//api` and HTML redirects | Trailing slash | Normalize instance URL |
| Login | SID could appear in errors | Raw server error text | Sanitize credentials |
| Notifications | Permission missing on Android 13+ | Manifest missing `POST_NOTIFICATIONS` | Added permission |
| Comments | Crash: `Null` not `List` | `authorThumbnail` string vs list | Accept both/null |
| Deep links | `youtu.be` not handled | Filter required `/watch`, autoVerify on unowned domains | Split filters, remove autoVerify |
| Live | Live playback failed/stale player | No HLS, zero progressive, only `dashUrl`; PTNaNS manifest | DASH fallback, stop old player, clear error |
| Quality | 4K/1080p lag | AV1 software decode; menu hid codec | Codec labels, hardware-first sort, Auto |
| Player | No hold-to-2× | Feature absent | Long-press gesture with restore |
| Motion | Hard cuts, 1000 ms motions, ad-hoc timings | One 250 ms token everywhere | Motion tokens/fades/shorter timings |
| Keyboard | Stray keyboard/floating IME | Persistent search autofocus/IME connection | One-shot focus + TextInput.hide on routes |
| Startup | 4–5 s cold | Blocking DB/package/file sync/notifications | Parallelize/defer |
| Layout | 533 dp tablet stayed phone in landscape | Shortest-side-only classification | Separate window-based wide policy |
| Responsive tests | No coverage | No layout tests | 10 breakpoint/widget tests |

Known external/remaining issues:

- Live streams blocked by the server’s invalid DASH manifest (`PTNaNS`) and HLS 403.
- 4K AV1 is software-decoded on this tablet; Auto/1080p H.264 is the smooth path.
- Phone testing not done.
- Formal DevTools UI/raster p95 trace not captured.
- Player overlay still listens to progress ticks; skeleton placeholders own per-row
  tickers; comments/recommended still build eager columns. These are documented second-pass
  performance opportunities.
- Cleartext HTTP is enabled for the owner’s LAN instance; credentials are not encrypted at
  rest. Production hardening is not complete.

---

## 8. How testing was done

### 8.1 Static analysis

```bash
source .tooling/env.sh
flutter analyze --no-fatal-infos --no-fatal-warnings
```

Result: 0 errors; pre-existing infos/warnings remained. Analyze catches type errors,
missing imports, invalid widget APIs and some dead code, but not behavior.

### 8.2 Unit and widget tests

```bash
flutter test \
  test/utils/responsive_test.dart \
  test/utils/responsive_widget_test.dart \
  test/utils/motion_test.dart \
  test/utils/codec_utils_test.dart \
  test/utils/url_utils_test.dart \
  test/service/handle_response_test.dart \
  test/comments/comment_json_test.dart
```

Result: 39/39 at the last run. Coverage included:

- URL normalization/resolution/proxy parameter.
- Response handling for success/error/non-JSON/empty.
- Comment schema variations.
- Codec labels.
- Motion token/reduced-motion behavior.
- Responsive breakpoints and `DeviceWidget`.

There are no golden tests and no full app widget tests. That is a gap for production.

### 8.3 Host API verification

`curl` against the self-hosted Invidious instance verified:

- stats, video, search, suggestions, trending, popular, channels, comments, feed,
  subscriptions, playlists, history;
- cookie login and SID;
- proxied stream 206;
- captions;
- DASH redirect/companion URLs.

This separated server failures from client parsing failures.

### 8.4 Device verification

No emulator; physical Lenovo TB-8505F, Android 10, arm64, 800×1280, 533 dp.

Tools:

```bash
adb devices -l
adb install -r app-arm64-v8a-profile.apk
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml
adb shell input tap X Y
adb exec-out screencap -p > shot.png
adb shell dumpsys media_session
adb shell dumpsys input_method
adb logcat
scrcpy --no-audio
```

Tested:

- install/launch, server add/advanced test;
- Home/Popular/Trending, search tabs, channels, playlists;
- video detail, comments, recommended, queue;
- DASH on/off/proxy, audio-only, quality switching, 2× hold;
- background playback/notification, PiP/rotation;
- download and offline playback;
- logged-in Subscriptions/Playlists/History read-only;
- keyboard/IME behavior;
- reduced-motion mode;
- static UI parity screenshots.

Limitations:

- no phone;
- no account mutations;
- no live playback (server-blocked);
- no formal frame trace;
- one device/OS/ABI;
- tablet disconnected for the responsive pass.

### 8.5 Build verification

```bash
apksigner verify dist/clipious-1.22.15-arm64-profile.apk
unzip -t dist/clipious-1.22.15-arm64-profile.apk
sha256sum dist/clipious-1.22.15-arm64-profile.apk
```

Artifact: 242,578,371 bytes, SHA-256
`15df93a2b4c48ac941426f90865076b297ff3334d4a411a98072f85f631863d1`.
Installed on the tablet; debug-signed profile build.

### 8.6 What a production test plan must add

- Golden/screenshot tests for key screens.
- `integration_test` or Patrol flows on a device matrix.
- API contract tests with recorded fixtures.
- Migration tests for DB schema.
- Accessibility tests (TalkBack, large text, RTL).
- Performance traces with UI/raster p95 and startup metrics.
- Network failure/latency injection.
- Battery/thermal/background restrictions.
- Release AAB install/upgrade/signing tests.
- Phone, tablet, foldable, Android TV, Android versions.
- Security review and secret scanning.

---

## 9. Android knowledge that mattered

### Manifest and intents

- Deep links need exact host/path filters. Multiple `<data>` elements in one filter merge
  constraints; `youtu.be` and `youtube.com/watch` need separate filters.
- `autoVerify` only for domains you control.
- Android 13+ needs `POST_NOTIFICATIONS`.
- Cleartext HTTP is blocked by default on newer Android unless explicitly configured;
  this app needs HTTP for a LAN Invidious instance, so cleartext is currently allowed.
  Production should restrict it with a network security config and require HTTPS.

### Codecs and playback

- Invidious exposes H.264, VP9 and AV1 tracks at the same resolution.
- Old/low-end devices may hardware-decode H.264/VP9 but software-decode AV1.
- ExoPlayer’s adaptive selector normally avoids unsupported codecs, but a manual quality
  choice can force a software track.
- 4K on a 720p/800p display is wasted bandwidth and decode work. Auto or 1080p H.264 is
  usually the right recommendation.
- MediaCodec/OMX logs (`OMX.MTK.VIDEO.DECODER.AVC`, `MtkACodec`) prove which decoder is
  active.
- `dumpsys gfxinfo` is not useful for Flutter UI because Flutter does not use HWUI frame
  stats; use DevTools/VM timeline instead.

### Build/release

- APK is for direct install/testing; AAB is for Play.
- Debug signing is not distribution signing. Use Play App Signing or a secure keystore.
- Split per ABI for smaller installs; version-code suffix logic exists.
- R8/minify/shrink in release can break reflection/serialization; test release builds.
- Pin the NDK/AGP/Kotlin versions and keep a reproducible toolchain.
- A profile build is AOT but debuggable; it is the right performance test artifact when
  release signing is unavailable.

### Performance

- 60 Hz frame budget is 16.67 ms; 120 Hz is 8.33 ms.
- Avoid rebuilding the whole screen on each progress tick.
- Avoid animating layout properties (constraints, width, height, margin) during gestures.
- Use `ListView.builder`/`GridView.builder`, `RepaintBoundary`, cached image decode sizes.
- Avoid dozens of independent infinite animation controllers.
- Measure on the low-end device, not only on the development machine.

### Security

- Do not log cookies/tokens.
- Store credentials in `flutter_secure_storage`/Keystore, not plaintext Sembast.
- Use HTTPS and a narrow cleartext policy.
- Treat the Invidious instance as untrusted; validate URLs/response sizes.
- Use least-privilege GitHub tokens, never commit `.env`.

---

## 10. iOS knowledge (important, but not tested here)

This repository is an Android client; its iOS target was not built or device-tested in
this work. Do not claim iOS support from the Android APK.

To ship a Flutter app on iOS:

- Build on macOS with Xcode; install CocoaPods; use a valid signing team/provisioning
  profile.
- Configure Bundle ID, entitlements, background audio, PiP, ATS/HTTPS, icons and launch
  screen.
- Use TestFlight for beta; App Store Connect for review/release.
- Implement account deletion and privacy disclosures if accounts exist.
- Respect App Store review guidelines and platform policies. Apps that proxy YouTube
  content can face policy/legal risk; review before building a business.
- Plan for macOS CI runners (GitHub Actions macOS, Codemagic, Xcode Cloud) because Linux
  cannot build iOS.
- Test on multiple iPhones/iPads, Dynamic Island/safe areas, text scaling, RTL, and
  background audio.
- Flutter UI is shared, but platform channels, file paths, notifications, PiP, downloads
  and background execution need platform-specific code/testing.

---

## 11. Responsive and adaptive design

### Breakpoints

Material’s common width classes are compact (<600), medium (600–839) and expanded (840+).
This app uses:

- compact portrait: phone shell;
- wide window (533 dp landscape, 600+ or foldable): wide shell;
- wide-but-short phone: compact shell.

Why a separate policy: device class is useful for feature gating, but layout should react
to the **current window**. Rotation and foldable resizing must not require a restart.

### Rules

- Use `MediaQuery.sizeOf`/`LayoutBuilder`, not hard-coded pixel widths.
- Respect safe areas, status/navigation bars, display cutouts and gesture insets.
- Do not assume a fixed number of columns; compute from width and content.
- Use directional edges (`EdgeInsetsDirectional`) for RTL.
- Test text scale 1.0, 1.3 and 2.0; avoid fixed-height text containers.
- Avoid overflow: use `Flexible`, `Wrap`, `FittedBox` carefully, ellipsis, and scrollable
  detail pages.
- Use rail vs bottom nav by available width, not device brand.
- Keep content max-width on very wide screens for readability.
- Test 4:3, 16:10, 16:9, 19.5:9, foldable inner/outer, tablet portrait/landscape.

### What was preserved

No colors, typography, icons, spacing or component hierarchy were changed in the
responsive pass. Only shell/layout selection changed.

---

## 12. Motion and visual craft (avoiding AI slop)

### Motion rules used

- Micro feedback: 100–150 ms.
- Small state change: 150–200 ms.
- Component enter/exit: 200–250 ms.
- Navigation: 250–300 ms; existing Android Zoom stays 300 ms.
- Complex emphasis: max 350–400 ms; do not animate routine UI for 800–1000 ms.
- Standard curve `Cubic(0.2,0,0,1)`, decelerate for entering, accelerate for exiting.
- Honor OS reduced-motion.
- Never animate layout constraints during a drag; use transforms/opacity and commit state
  at gesture end.
- No per-row infinite tickers; one shared animation where possible.

### Design anti-slop checklist

- Use the existing design system, not a new one. Reuse Clipious colors, typography,
  spacing, icons and component patterns.
- Do not add gradients, glassmorphism, giant radii, floating blobs or random shadows just
  to look “modern.”
- Do not add emoji, lorem ipsum or fake metrics.
- Do not redesign navigation without a product reason.
- Keep content density appropriate for a media app; do not turn everything into cards.
- Use real states: loading, empty, error, offline, buffering, permission denied.
- Make typography hierarchy obvious; limit font sizes/weights; use consistent spacing.
- Use platform conventions for back, search, sheets and dialogs.
- Make dark theme intentional, not pure black everywhere unless the app’s design says so.
- Use motion to explain state changes, not to decorate.
- Check contrast, touch targets (≥48 dp), text scaling, RTL and landscape.
- Compare screenshots at rest before/after; motion changes must not shift layout.

### For new features

1. Write a one-page brief: user problem, success metric, non-goals.
2. Map existing components/tokens; reuse before inventing.
3. Define states and error paths.
4. Prototype with real data and long titles.
5. Set a performance budget.
6. Review on a low-end device and with large text/RTL.
7. Add tests/goldens.
8. Ship behind a flag if risk is high.

---

## 13. Production and business readiness

### 13.1 Legal/licensing first

Clipious is **AGPL-3.0**. If you modify it and distribute it, or provide it as a network
service, AGPL source-disclosure obligations may apply. A commercial product needs legal
review of:

- AGPL compliance and source offer;
- Invidious/YouTube terms and API usage;
- copyright/content rights;
- app-store policies for third-party video clients;
- privacy law (GDPR/DPDP/CCPA), cookies/tokens, analytics and account deletion;
- SponsorBlock/DeArrow/Return YouTube Dislike terms.

This is not legal advice. Do not build a paid business on assumptions.

### 13.2 Architecture for production

Current architecture is a direct client to Invidious. For a business:

- Add a backend/API gateway you control for auth, rate limits, caching, observability and
  secrets. Do not put user tokens in the client.
- Use OIDC/OAuth for account identity; short-lived access tokens and refresh rotation.
- Store tokens in platform secure storage (Keystore/Keychain).
- Add request signing/HTTPS/certificate pinning where appropriate.
- Cache metadata and media responsibly; respect upstream limits.
- Use a job queue for downloads/notifications; avoid unbounded client work.
- Add structured logs, metrics and traces; redact credentials and personal data.
- Feature flags/remote config for rollout; kill switches for broken backends.
- Database migrations with backups and rollback.
- Define SLOs: crash-free sessions, startup p95, playback start time, API error rate.

### 13.3 Security/privacy

- Remove cleartext by default; allow a user-configured LAN exception.
- Encrypt credentials at rest.
- Do not log SID/cookies/tokens; scrub error messages.
- Add dependency scanning/SBOM and pin Git dependencies (e.g. `river_player: master` is
  not reproducible for production).
- Review WebView/auth redirects and intent handling.
- Validate deep links and external URLs.
- Add account deletion/export and data-retention policy for a business.
- Conduct threat modeling and a third-party security review before launch.

### 13.4 Release engineering

- CI: format, analyze, unit/widget tests, build, sign, artifact checks.
- CD: internal track → closed testing → staged rollout; TestFlight for iOS.
- Use Play App Signing; store keys in a secret manager, not Git.
- Build AAB for Play; keep APK for direct/enterprise.
- Versioning/versionCode automation; changelog and migration notes.
- Staged rollout with crash/ANR monitoring; rollback plan.
- Keep reproducible toolchain versions and lockfiles.
- Sign tags/commits; protect `main`; require review.

### 13.5 Operations

- Crash reporting (Crashlytics/Sentry) with privacy controls.
- Analytics only with consent; avoid sending video titles/URLs unless necessary.
- Monitor API error rates by endpoint, playback errors by codec/device, startup and frame
  timing.
- Support workflow: logs export, diagnostics screen, redacted feedback.
- On-call/alerting for auth/playback outages.
- Cost model: bandwidth, proxy, storage, support, legal/compliance.

### 13.6 Monetization/support

Options: self-hosted license/support, managed hosting, paid apps, IAP/subscriptions,
donations, enterprise deployment. Each has store/payment/privacy implications. RevenueCat
or store IAP for mobile; Stripe for web; entitlement service; restore purchases; refunds;
tax compliance. Avoid ads that leak viewing behavior; privacy is the product.

### 13.7 Store policy risk

Third-party YouTube/Invidious clients have platform/legal risk. Before investing, verify
current YouTube terms, Invidious project status/licensing, app-store rules for
downloading/proxying video, and copyright takedown exposure. Have a contingency: a
self-hosted media app with user-provided sources, or a different content model.

---

## 14. AI-agent workflow that worked

### What worked

- **Plan mode for multi-file work.** Read-only exploration, then a plan with exact files,
  acceptance criteria and rollback.
- **Parallel exploration agents.** One mapped motion; one audited performance; one mapped
  theming/constraints. Independent context produced better coverage.
- **File:line evidence.** Every finding cited a real location; this reduced hallucination.
- **Small commits by concern.** Compatibility fixes, quality, motion, keyboard/startup,
  responsive, docs. Easy to review/revert.
- **Verification-first prompts.** “Run analyze/tests, build, install, test this flow” rather
  than “make it better.”
- **Tool use over memory.** Read package source (`river_player`), API responses, device
  logs. Do not invent APIs.
- **Explicit constraints.** Project-local tooling, no personal data, no secrets, no
  destructive git, preserve UI.
- **Stop and check when a visual preference was ambiguous.** For page transitions, research
  showed Flutter’s FadeForwards is 800 ms; preserving the existing 300 ms Zoom was safer.

### What caused friction

- Context length: a long session compacted and required a handoff summary.
- Disk/toolchain issues consumed time.
- A `git push` failed because of shallow history and token permissions.
- Background shell commands swallowed variables in one test command.
- Device UI automation needs coordinates/state checks; stale dumps cause misses.
- A 4K AV1 assumption was wrong until codec logs/API data proved it.

### Prompt patterns that produce quality

Ask for:

1. “Read these files and cite exact lines; do not change anything yet.”
2. “List assumptions and unknowns; distinguish server vs client issues.”
3. “Give one concrete plan with file paths, tests, and rollback.”
4. “Implement only this phase; do not touch unrelated behavior.”
5. “Run analyze/tests; build; verify on device; show evidence.”
6. “Preserve the existing design; do not add new visual language.”
7. “Check whether this is a device/decoder limitation before calling it a bug.”
8. “No secrets in logs; use a temporary askpass, never a token in the command.”

### Agent guardrails

- Use plan mode for changes spanning multiple files.
- Use read-only exploration first; parallelize audits.
- Pin dependencies; do not let an agent upgrade everything.
- Force file reads before edits; review diffs.
- Never let an agent push with a token embedded in a URL/history.
- Require tests and a build artifact check.
- Require a privacy/data rule for device tests.
- Keep a decision log; do not rely on chat memory.

### AI limits to design around

- Models can invent APIs or misread old versions; read the pinned package source.
- Long contexts lose detail; keep docs/checklists in the repo.
- Models tend to over-animate/over-redesign; constrain with design tokens and screenshots.
- Models may “fix” a server problem in the client; verify with API probes first.
- Models may delete tooling/caches prematurely; snapshot artifacts first.
- Models are poor at judging “feel”; use slow-motion recording and real-device checks.

---

## 15. How to build faster next time

### Toolchain/caching

- Use a **published Docker/devcontainer** image with Flutter, JDK, Android SDK and Gradle
  preinstalled, plus cache volumes. This avoids the project-local shim adventure.
- Or use Nix/devenv for pinned, reproducible toolchains.
- Keep Flutter SDK, pub cache, Gradle cache and Android SDK **outside** disposable build
  directories (but inside an allowed cache volume). Do not delete them between iterations.
- Cache Gradle with `GRADLE_USER_HOME`; enable Gradle build cache; keep `pubspec.lock`.
- Use a `Makefile`/`justfile`:
  - `make bootstrap`
  - `make analyze`
  - `make test`
  - `make apk`
  - `make device-smoke`
- Use CI for full builds; local agents should do fast analyze/tests and targeted device
  installs.

### Build-time choices

- Build only the ABI you need (`--target-platform android-arm64`).
- Use profile for performance testing; debug only for debugging.
- Do not `flutter clean` unless a cache is corrupt.
- Use incremental builds; avoid deleting `.dart_tool`/Gradle caches.
- Use `--no-pub` after a successful `pub get`.
- For release, build AAB once in CI; sign there.
- Pin `river_player` to a commit, not `master`, for reproducibility.

### Parallelism

- Run independent audits in parallel (architecture, motion, performance, security).
- Run unit tests and analysis before device work.
- Use one agent for code and another for verification/review, but keep commits small.
- Do not parallelize writes to the same files.

### Device/CI testing

- For production, use Firebase Test Lab/BrowserStack/Genymotion SaaS or a device farm.
  This is faster and covers more devices than one tablet.
- Use `integration_test`/Patrol for core flows; Maestro is useful for black-box flows.
- Golden/screenshot tests catch layout regressions.
- Keep a short smoke suite for every PR and a longer nightly matrix.

---

## 16. How to test “perfectly”

There is no perfect, but you can make failure expensive to ship:

1. **Static**: format, analyze, dependency audit, secret scan.
2. **Unit**: pure logic, parsing, URL/error handling, tokens.
3. **Widget/golden**: states, layouts, text scale, RTL, dark/light.
4. **Contract**: recorded Invidious responses; schema variations.
5. **Integration**: app flows on device/emulator with a test server.
6. **Device matrix**: low-end/high-end, phone/tablet/foldable/TV, Android 10–16,
   iOS current/previous, 60/120 Hz.
7. **Performance**: startup, scroll, navigation, player controls, memory, thermal.
8. **Accessibility**: TalkBack/VoiceOver, large text, contrast, reduced motion.
9. **Security/privacy**: auth storage, logs, deep links, cleartext, dependency CVEs.
10. **Release**: signed AAB/APK, install/upgrade, migration, rollback, store pre-launch.
11. **Observability**: crash-free sessions, API errors, playback errors, startup p95.
12. **Business**: account deletion, billing restore, support, legal/compliance.

Measure, don’t guess:

- Profile-mode DevTools UI/raster frame times.
- `am start -W` for cold/warm startup.
- `dumpsys media_session`, codec logs, CPU samples for playback.
- Screenshots/video for visual/feel checks.
- Crash/ANR dashboards in production.

---

## 17. Checklists

### New feature

- [ ] Problem/user value and non-goals.
- [ ] Existing component/token reuse.
- [ ] States: loading, empty, error, offline, permission, long text.
- [ ] Responsive at 320–1280+ dp; portrait/landscape/foldable.
- [ ] RTL and text scale 1.3/2.0.
- [ ] Performance budget and measurement.
- [ ] Unit/widget/golden/integration tests.
- [ ] Accessibility labels/contrast/touch targets.
- [ ] Analytics/privacy review.
- [ ] Feature flag/rollback.
- [ ] Docs/changelog.

### Release

- [ ] Version/versionCode bumped.
- [ ] Tests/analyze/goldens green.
- [ ] Signed AAB/APK; Play App Signing configured.
- [ ] Proguard/R8 release build tested.
- [ ] Upgrade from previous version tested.
- [ ] Privacy policy/permissions/store listing.
- [ ] Staged rollout and crash monitoring.
- [ ] Rollback plan.

### Security

- [ ] No secrets in Git, logs, screenshots, build artifacts.
- [ ] Tokens in secure storage; least privilege.
- [ ] HTTPS/ATS/network security config.
- [ ] Deep-link validation.
- [ ] Dependency audit/pinning.
- [ ] Redacted error reporting.
- [ ] Account deletion/export if accounts exist.

### AI-agent task

- [ ] Plan mode for 3+ files/architecture.
- [ ] Exact files and constraints in prompt.
- [ ] Read before edit; no invented APIs.
- [ ] Small commits; one concern.
- [ ] Analyze/tests/build/device evidence.
- [ ] Secrets/privacy rules stated.
- [ ] Diff review and rollback.
- [ ] Update docs/decisions.

---

## 18. Evidence and sources

Repo docs:

- `RESEARCH.md` — Invidious/Clipious/device research.
- `PLAN.md` — phased plan and milestones.
- `FINDINGS.md` — bug root causes and evidence.
- `FIXES.md` — changes and commits.
- `TEST.md` — commands, test matrix, metrics.
- `CONFIDENCE.md` — readiness/uncertainty.
- `TESTING_THINGS.md` — owner manual checks.
- `INSTALLATION.md` — build/install steps.
- `PROGRESS.md` — session history.
- `WHAT_TO_DEL_AND_KEEP.md` — storage cleanup/rebuild guide.

External references used:

- Material 3 motion: https://m3.material.io/styles/motion/easing-and-duration
- Material motion values: https://www.designref.ai/design-systems/material-design/motion
- Flutter performance: https://docs.flutter.dev/perf/best-practices
- Flutter rendering: https://docs.flutter.dev/perf/rendering-performance
- Flutter page transitions: https://api.flutter.dev/flutter/material/PageTransitionsTheme-class.html
- Flutter reduced motion: https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html
- Pinned Flutter SDK source: `.tooling/flutter/packages/flutter/lib/src/material/page_transitions_theme.dart` (SDK was later removed; redownload per `WHAT_TO_DEL_AND_KEEP.md`).

Device evidence was under `.tooling/testing/artifacts/run-20261024-220727/` and was kept.
It includes search/keyboard, controls, quality, 2× badge, tabs/queue, Home parity and
reduced-motion screenshots.

---

## 19. Glossary

- **Invidious**: self-hostable YouTube front end/API.
- **DASH**: adaptive streaming manifest; video/audio tracks may be separate.
- **HLS**: HTTP Live Streaming; Invidious live endpoints were 403 here.
- **AV1/VP9/H.264**: video codecs; hardware support varies.
- **ExoPlayer/Media3**: Android playback engine used by `river_player`.
- **AOT**: ahead-of-time compilation (profile/release).
- **JIT**: just-in-time (debug).
- **AAB**: Android App Bundle for Play.
- **AGP**: Android Gradle Plugin.
- **IME**: input method editor/keyboard.
- **p95**: 95th percentile; a frame-time/startup metric.
- **Golden test**: screenshot-based widget test.
- **R8**: Android code shrinker/optimizer.
- **PiP**: picture-in-picture.
- **AGPL-3.0**: copyleft license with network-use source obligations.

---

## 20. The shortest possible summary

The app works because the client now normalizes Invidious URLs and errors, handles the
real comment schema and Android intents, selects hardware-decodable video, stops stale
players, and presents clear failures. It feels smoother because motion is tokenized,
player chrome fades, thumbnails/grids rebuild less, and progress writes no longer block the
UI. It feels more finished because the keyboard no longer follows navigation, startup work
is deferred, and layout adapts to the current window. It is not production-ready yet:
credentials are not encrypted, cleartext is allowed, live playback is server-blocked,
phone/iOS are untested, there is no formal frame trace, and the AGPL/YouTube/Invidious
legal and app-store risks need review.

The fastest way to improve next time is to invest in a reproducible toolchain/CI, pin
dependencies, keep caches, use plan mode + parallel audits, test on a device farm and
goldens, measure with DevTools, and constrain AI agents with the existing design system
and evidence-based acceptance criteria.
