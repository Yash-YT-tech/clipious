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

Result: **21/21 passed** (`+21: All tests passed!`).

| File | Cases | Result |
|---|---|---|
| `test/utils/url_utils_test.dart` | 11 | PASS |
| `test/service/handle_response_test.dart` | 5 | PASS |
| `test/comments/comment_json_test.dart` | 5 | PASS |

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
| SHA-256 | `4fc439e38f0ce9ae34bf6a2e5804734be5e0a1ee0cba8822236844fbc6647b81` |
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

## 6. Physical device verification (tablet)

Device: **Lenovo TB-8505F**, Android **10 (API 29)**, arm64-v8a, 800×1280 @ 240 dpi
(533 dp shortest side), 2.0 GB free. Clipious was not installed; the normal package was
installed. Evidence: UIAutomator dumps, `screencap`, `dumpsys media_session/notification/
audio_flinger`, and app logcat, stored in `.tooling/testing/artifacts/run-20261024-220727/`.

| Area | Result | Evidence |
|---|---|---|
| Install / launch | PASS | Installed 1.22.15 (60773); no crash. First frame 17.7 s; cold start ~20–28 s |
| Add self-hosted server (advanced test) | PASS | `http://192.168.1.4:5566` accepted; no thumbnail error |
| Home / Popular / Trending | PASS | Real cards and thumbnails rendered |
| Search: Videos / Channels / Playlists | PASS | All tabs loaded real results |
| Video detail | PASS | Title, metadata, description, tabs, mini-player |
| VOD playback, DASH on | PASS | `state=3`, position advanced, no codec/ExoPlayer errors |
| VOD playback, DASH off | PASS | Progressive 360p; `state=3` |
| VOD playback, Proxy + DASH | PASS | `Playing url (dash true) …?local=true`; `state=3` |
| Quality switching | PASS | Adaptive list 2160p→144p; 480p selected; playback continued |
| Audio tracks | PASS (single) | Only `hi - hi` track exposed |
| Audio-only mode | PASS | Position advanced; AudioFlinger active; pause/seek controls |
| Background playback / notification | PASS | Position advanced while backgrounded; MediaStyle notification with Rewind/Pause/Stop/Fast-forward |
| Download | PASS | 144p (~1.5 MB) downloaded; download icon changed to a checkmark; thumbnail present |
| Offline playback | PASS | Wi-Fi disabled (ping unreachable); downloaded Rick Astley played from local storage |
| Comments tab | **FAIL → FIXED → PASS** | Initially `type 'Null' is not a subtype of List<dynamic>`; after fix authors/timestamps/text render |
| Channel page | PASS | Banner, description, subscribe, tabs, latest videos |
| Playlist page | PASS | Header, play button, video list, mini-player |
| Rotation / landscape | PASS with caveat | 1280×800 landscape; full-screen player; audio continued. Media-session position reporting went stale while backgrounded/rotated (AudioFlinger still active; internal position had advanced) |
| Deep link `youtube.com/watch?v=` | PASS | Opened the Rick Astley detail |
| Deep link `youtu.be/<id>` | FIXED (manifest), not implicitly proven | Filter now correct; the installed official YouTube app remains the default handler, so implicit resolution still selects YouTube |
| Live stream | **BLOCKED (server)** | Invidious DASH manifest has `mediaPresentationDuration="PTNaNS"`; ExoPlayer rejects it; HLS endpoints return 403. App now tries DASH, shows a clear error, and stops the previous video |
| Network-loss search | PARTIAL | Search overlay/keyboard interaction did not submit reliably; no explicit offline error captured |
| Auth / subscriptions / history | SKIPPED | Personal data; not opened |
| Notifications (Android 13+ permission) | N/A | Device is Android 10; media notification itself verified |
| Tablet-specific layout | PARTIAL | At 533 dp the app uses its phone layout; landscape uses 2 columns. The 600 dp `DeviceType.tablet` threshold is not met |

## 7. Not run / blocked

| Item | Status | Reason |
|---|---|---|
| Physical phone tests | NOT RUN | Phone not connected (`adb devices` showed only the tablet) |
| Token login round-trip | NOT RUN | Requires interactive browser approval |
| Auth / subscriptions / history | SKIPPED | Would read personal account data |
| Live playback | BLOCKED | Invalid Invidious DASH manifest (`PTNaNS`); HLS disabled/403 |
| Network-loss search error | PARTIAL | Overlay submission not captured |
| Release APK | NOT RUN | No signing key; profile APK is the owner-test artifact |
| Integration test suite | NOT RUN | Requires dedicated test server/account; destructive teardown |
| Emulator tests | NOT RUN | Prohibited by project constraints |

## 8. Known limitations

- The phone is untested; the tablet is a single Android 10 / arm64 device.
- Live streams are blocked by the server's invalid DASH manifest; the app fails gracefully.
- Cold start is slow (~18–28 s) on this tablet.
- The media-session position can stop updating while backgrounded/rotated even though audio
  continues; the internal position and AudioFlinger show progress.
- At 533 dp, the app uses the phone layout; the 600 dp tablet threshold is not met.
- The official YouTube app is still the default handler for YouTube links; Clipious is now a
  valid alternative handler.
- The build environment has no `cmdline-tools`; Gradle/Flutter emitted a license-status
  warning. This does not block the build.
- Disk space is tight (~2.7 GB free after testing); see `PROGRESS.md`.
