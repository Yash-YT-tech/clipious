# TEST — execution record

Date: 2026-10-24
Toolchain: Flutter 3.35.3 / Dart 3.9.2, OpenJDK 21.0.12, Gradle 8.7 wrapper,
Android SDK platforms 35/36. No emulator. No physical device connected.
All tooling and caches are project-local under `.tooling/` and `.caches/`.

## 1. Strategy

1. Static analysis (`flutter analyze`) for compile-level correctness.
2. Pure unit tests for the new URL resolver and response handler.
3. Existing server-independent tests.
4. Live HTTP validation of every Invidious endpoint used by the app, unauthenticated and
   authenticated (host side, in-memory cookie jar, credentials never persisted).
5. Debug APK build.
6. Manual physical-device checklist in `TESTING_THINGS.md` (owner executes).

Tests that need a device or a dedicated `localhost:3000` Invidious user are **NOT RUN**;
they are not reported as passing.

## 2. Static analysis

```bash
bash -c 'source .tooling/env.sh && flutter analyze --no-fatal-infos --no-fatal-warnings'
```

| Run | Result |
|---|---|
| Baseline before edits | 367 issues, **1 error** (`test/test_player_cubit.dart:7`, body might complete normally) |
| After edits | 364 issues, **0 errors** |

Remaining issues are pre-existing infos/warnings (missing type annotations, deprecated
Workmanager `isInDebugMode`, `invalid_annotation_target` on `json_annotation`, pubspec sort).
The one baseline error was a test-helper bug and was fixed.

## 3. Unit / widget tests

Command:

```bash
bash -c 'source .tooling/env.sh && flutter test test/utils/url_utils_test.dart test/service/handle_response_test.dart'
```

Result: **16/16 passed** (`+16: All tests passed!`).

| File | Cases | Result |
|---|---|---|
| `test/utils/url_utils_test.dart` | 11 | PASS |
| `test/service/handle_response_test.dart` | 5 | PASS |

Server-independent existing tests:

```bash
bash -c 'source .tooling/env.sh && flutter test test/settings test/utils/file_db_test.dart test/widget_test.dart'
```

Result: **7 passed, 3 failed** (`+7 -3`).

| Test | Result | Classification |
|---|---|---|
| `settings_test.dart` (2) | PASS | — |
| `app_log_test.dart` (1) | PASS | — |
| `file_db_test.dart` (4) | PASS | — |
| `server_settings_test.dart` | FAIL | **Environmental**: calls `loginWithCookies` against `http://localhost:3000`, which is not running. Not run against the owner's account. |
| `server_list_settings_test.dart` ("save public servers") | FAIL | **Pre-existing test defect**: `getPublicServers()` is commented out, so `publicServers` is empty; test asserts non-empty. Unrelated to this work. |
| `server_list_settings_test.dart` ("switching server") | FAIL | Same pre-existing test defect. |

Server-dependent tests deliberately **NOT RUN**:

- `test/channels/state/channel_test.dart`
- `test/subscription_management/state/manage_subscriptions_test.dart`
- `test/subscription_management/state/subscribe_button_test.dart`
- `test/videos/state/add_to_playlist_test.dart`
- `test/videos/state/video_test.dart`

Reason: `test/utils/server.dart` logs in as `test`/`test` at `localhost:3000` and its teardown
deletes **all subscriptions, playlists and history** for that account. Running it against the
owner's `yash` account would destroy real data.

## 4. Live Invidious API validation (host side)

Target: `http://localhost:5566`, Invidious `2026.08.04-48c6110`.

| Check | Command (abridged) | Result |
|---|---|---|
| Stats/software | `curl /api/v1/stats` | 200, `invidious` |
| Video | `curl /api/v1/videos/dQw4w9WgXcQ` | 200, schema parsed by models |
| Video + local proxy | `curl /api/v1/videos/dQw4w9WgXcQ?local=true` | 200, **relative** stream URLs (root cause) |
| Search | `curl "/api/v1/search?q=hello%20world&type=video"` | 200 |
| Search sorts | `sort=relevance|views|date|rating|upload_date` | 200 (unknown values ignored) |
| Suggestions | `/api/v1/search/suggestions?q=test` | 200 |
| Trending | `/api/v1/trending?region=US` | 200 |
| Popular | `/api/v1/popular` | 200 |
| Channel | `/api/v1/channels/:id` (+ `/videos`, `sort_by=newest|oldest|popular`) | 200 |
| Comments | `/api/v1/comments/:id` | 200 |
| Unauthenticated auth endpoint | `/api/v1/auth/subscriptions` | 403 `{"error":"Request must be authenticated"}` |
| Cookie login | `POST /login?type=invidious` | 302 + `SID` cookie |
| Invalid login | same with invalid password | 401, no cookie |
| Authenticated feed | `/api/v1/auth/feed` with SID | 200 |
| Authenticated subscriptions | `/api/v1/auth/subscriptions` | 200 |
| Authenticated playlists | `/api/v1/auth/playlists` | 200 |
| Authenticated history | `/api/v1/auth/history` | 200 |
| Double slash | `/ /api/v1/stats` (two slashes) | 302 → confirms trailing-slash bug |
| Thumbnail | `/vi/dQw4w9WgXcQ/maxres.jpg` | 200 `image/jpeg` |
| DASH manifest | `/api/manifest/dash/id/:id` | 302 → `/companion/api/manifest/dash/id/:id`; following redirect returns 200 `application/dash+xml` |
| DASH without local | manifest `BaseURL` | absolute `googlevideo.com` URLs |
| DASH with local | `/companion/api/manifest/dash/id/:id?local=true` | manifest `BaseURL` = `/companion/videoplayback?...` (local segments) |
| Proxied progressive stream | `/videoplayback` from `?local=true`, `Range: bytes=0-1023` | 206, `video/mp4`, `Content-Range: bytes 0-1023/11829048` |
| Captions | relative caption URL from the video response | 200 `text/vtt` |

Credentials were supplied out-of-band for this validation and were not written to any file,
log, report, or commit.

## 5. Build

Environment setup:

```bash
bash -c 'source .tooling/env.sh && flutter pub get'
bash -c 'source .tooling/env.sh && flutter build apk --debug --target-platform android-arm64 --no-pub'
```

| Attempt | Result |
|---|---|
| 1 | **FAILED** — AGP `AndroidLocationsException`: `ANDROID_SDK_HOME` and `ANDROID_USER_HOME` pointed at different paths. |
| 2 | **FAILED** — AGP tried to download NDK `26.1.10909125` into the shared Android SDK (outside the workspace). Stopped. |
| 3 | **FAILED** — `jlink` missing: the installed `/usr/lib/jvm/java-21-openjdk-amd64` is a JRE, not a JDK. |
| 4 | **FAILED** — Gradle still resolved the system JRE for `JdkImageTransform`; the project JDK's `bin/java` was a symlink and reported the system `java.home`. |
| 5 | **FAILED** — CMake/NDK shim incomplete (`android.toolchain.cmake`, `platforms/android-24`, ABI metadata); later `NullPointerException` with `LANGUAGES NONE`. |
| 6 | **FAILED** — `ENOSPC` during `mergeDebugNativeLibs` (project volume full). |
| 7 | **SUCCESS** — debug APK built (`app-debug.apk`, 696 MB). Removed after verification to save space. |
| 8 | **SUCCESS** — profile APK built (`app-profile.apk`, 301 MB). Removed. |
| 9 | **SUCCESS (final)** — split-per-ABI profile APK built and verified:

| Final artifact | Value |
|---|---|
| Path | `dist/clipious-1.22.15-arm64-profile.apk` |
| Size | 242,512,835 bytes (231.3 MiB) |
| SHA-256 | `58537dbf99ddcd741ec5d7b234575caa0e766fd56cdd45300501e5d8281ca458` |
| Package / version | `com.github.lamarios.clipious`, `1.22.15` (60773) |
| ABI | `arm64-v8a` |
| Signature | Android debug key, `apksigner verify` OK |
| ZIP integrity | `unzip -t` OK |

Build-environment fixes (workspace-only, documented in `INSTALLATION.md` §12):

- single `ANDROID_USER_HOME` inside `.caches/`;
- project-local headless JDK with `jlink` and a real `bin/java` (`java.home` resolves inside
  `.tooling/jdk`);
- `.tooling/ndk` metadata/toolchain shims and a language-enabled empty CMake project so the
  NDK-required stripping step configures without compiling native code;
- `android.enableJetifier=false`;
- `--no-tree-shake-icons` because `const_finder.dart.snapshot` is absent from this SDK.

The final build command:

```bash
bash -c 'source .tooling/env.sh && flutter build apk --profile --split-per-abi \
  --target-platform android-arm64 --no-pub --no-tree-shake-icons'
```

APK validation commands and results:

```bash
aapt2 dump badging dist/clipious-1.22.15-arm64-profile.apk
# package name='com.github.lamarios.clipious' versionCode='60773' versionName='1.22.15'
# targetSdkVersion:'36'  native-code: 'arm64-v8a'
apksigner verify --print-certs dist/clipious-1.22.15-arm64-profile.apk
# Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
unzip -t dist/clipious-1.22.15-arm64-profile.apk   # ZIP_OK
```

## 6. Not run / blocked

| Item | Status | Reason |
|---|---|---|
| Physical phone tests | NOT RUN | No device connected (`adb devices -l` empty) |
| Physical tablet tests | NOT RUN | Same |
| Token login round-trip | NOT RUN | Requires interactive browser approval |
| Video/audio playback on device | NOT RUN | No device |
| Downloads on device | NOT RUN | No device storage/codecs |
| Notification delivery on Android 13+ | NOT RUN | No device |
| Release APK | NOT RUN | No signing key; debug APK is the intended owner-test artifact |
| Integration test suite | NOT RUN | Requires dedicated test server/account; destructive teardown |
| Emulator tests | NOT RUN | Prohibited by project constraints |

## 7. Known limitations

- Device behaviour, codec support, LAN reachability and orientation/tablet layouts are
  unverified.
- The build environment has no `cmdline-tools`; Gradle/Flutter emitted a license-status
  warning. This does not necessarily block the build; result recorded above.
- Disk space is tight (~2.8 GB free at build time); see `PROGRESS.md`.
