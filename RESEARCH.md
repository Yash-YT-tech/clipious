# RESEARCH — Clipious ↔ self-hosted Invidious

Research date: 2026-10-24
Project checkout: `b9e78851666ab37c9f87adc7d49522a0028414a2` (`master`, 2025-09-13, version `1.22.15+6077`)

## 1. Scope and method

This document records what was verified about the local Clipious checkout, the upstream
projects, and the live self-hosted Invidious instance before application changes were made.

Methods used:

| Method | Status | Notes |
|---|---|---|
| Local source inspection | Done | Repository, models, service layer, player, manifests, build files |
| Live API probing of `http://localhost:5566` | Done | `curl` and Python `urllib`; unauthenticated and authenticated (cookie session) |
| GitHub REST API (issues, source) | Done | `api.github.com`, `raw.githubusercontent.com` |
| WebFetch of official Invidious API documentation | Done | <https://docs.invidious.io/api/> |
| Local SearXNG (`http://localhost:8888`) | Available, not needed | Search endpoint returns HTTP 200 |
| Crawl4AI (`http://137.23.49.2:8888`) | Available, not needed | `/health` reports version `0.9.3` |
| Scrapling MCP (`http://10.0.0.27:8082/mcp`) | **Unavailable** | Connection timeout (HTTP 000); no results were invented |
| Android emulator | **Not used** | Explicitly prohibited; no image was downloaded |
| Physical Android device | **Not connected** | `adb devices -l` empty at analysis time |

## 2. Environment facts

| Item | Value | Evidence |
|---|---|---|
| Working tree | Git repo, branch `fix/invidious-android-compatibility` | `git status`, `git log` |
| Upstream | `https://github.com/lamarios/clipious` | `git remote -v` |
| Application ID | `com.github.lamarios.clipious` | `android/app/build.gradle` |
| Flutter pin | 3.35.3 stable, commit `a402d9a4376add5bc2d6b1e33e53edaae58c07f8` | `.gitmodules`, `submodules/flutter` gitlink, Flutter releases JSON |
| Dart | 3.9.2 | `flutter --version` |
| Java | OpenJDK 21.0.12 | `java -version` |
| Android SDK | platforms 35/36, build-tools 35.0.1/36.0.0, platform-tools 34.0.4 | `$ANDROID_HOME` |
| Android cmdline-tools | Missing | `flutter doctor -v` |
| compileSdk / targetSdk / minSdk | 36 / 36 / 24 | `android/app/build.gradle` |
| Invidious | `2026.08.04-48c6110`, branch `v2.20260804.1` | `GET /api/v1/stats` |
| Invidious binding | `0.0.0.0:5566` (LAN `192.168.1.4`, Tailscale `100.109.64.77`) | `ss -tln`, `ip addr` |
| Host firewall | No `ufw`; iptables INPUT policy ACCEPT with Tailscale chain | `iptables -L` |

## 3. Clipious architecture (as found)

- Flutter/Dart app, feature-first layout under `lib/<feature>/{models,states,views}`.
- State management: `bloc`/`freezed`; routing: `auto_route`.
- Persistence: `sembast` over `sqflite` (`clipious.db`) for the main isolate; plain JSON
  files under `fileDb/` for the WorkManager background isolate (`lib/utils/file_db.dart`).
- HTTP: `package:http` in `lib/service.dart`; `Dio` only for downloads.
- Playback: `better_player`/ExoPlayer via `river_player` for video, `just_audio` for audio-only;
  `audio_service` foreground service for background playback.
- API base URL is stored as a `Server` record (`url`, `authToken`, `sidCookie`,
  `customHeaders`, `inUse`). Endpoint paths are concatenated directly onto `server.url`.
- Authentication supports two mechanisms:
  1. Browser token flow: `/authorize_token` → `clipious-auth://?token=…`, stored as a Bearer token.
  2. Cookie login: `POST /login?type=invidious` with `email`/`password`, stores the `SID` cookie.
- Media post-processing optionally adds SponsorBlock and DeArrow data from external services.

## 4. Invidious API findings (live instance)

All probes were executed on 2026-10-24 against `http://localhost:5566`.

| Endpoint | Result |
|---|---|
| `/api/v1/stats` | 200, `software.name = invidious` |
| `/api/v1/videos/dQw4w9WgXcQ` | 200, full schema incl. `formatStreams`, `adaptiveFormats`, `dashUrl`, `captions`, `recommendedVideos` |
| `/api/v1/trending?region=US` | 200 |
| `/api/v1/popular` | 200 (items typed `shortVideo` in this response) |
| `/api/v1/search?q=…` | 200; `q`, `sort`, `date`, `duration`, `type`, `region` accepted |
| `/api/v1/search/suggestions?q=…` | 200 |
| `/api/v1/channels/:id` and `/videos` | 200 |
| `/api/v1/comments/:id` | 200 |
| `/api/v1/auth/*` without credentials | **403** `{"error":"Request must be authenticated"}` |
| `/api/v1/auth/feed`, `/subscriptions`, `/playlists`, `/history` with valid SID | 200 |
| `/api/v1/auth/notifications` | 403 "path not found" (not used by Clipious) |
| `POST /login?type=invidious` valid credentials | 302 + `Set-Cookie: SID=…; HttpOnly; SameSite=Lax` |
| `POST /login?type=invidious` invalid credentials | 401 (no cookie) |
| `GET /authorize_token?…` unauthenticated | 302 to `/login?referer=…` (expected interactive flow) |

### 4.1 Relative media URLs (critical)

With `?local=true` the API returns **relative** URLs:

- `formatStreams[].url`: `/videoplayback?expire=…`
- `adaptiveFormats[].url`: `/videoplayback?…`
- `dashUrl`: `/api/manifest/dash/id/<id>` (also relative without `local`)
- `videoThumbnails[].url`: `/vi/<id>/maxres.jpg`
- `captions[].url`: `/api/v1/captions/<id>?label=…`
- `hlsUrl`: `null` for the tested VOD

Absolute `googlevideo.com` URLs appear for `formatStreams`/`adaptiveFormats` when
`local` is not requested. The instance itself serves `/vi/…` and `/videoplayback` correctly
(verified with HTTP 200 / 206).

Source evidence that `local` is an API query flag:
`src/invidious/routes/api/v1/videos.cr` (upstream `master`, fetched 2026-10-24) reads
`env.params.query["local"]?` and passes `proxy` into the JSON serializer.

Additional media checks (2026-10-24):

- `/api/manifest/dash/id/<id>` returns **302** to `/companion/api/manifest/dash/id/<id>`;
  following the redirect returns **200** `application/dash+xml`.
- Without `local`, the DASH manifest `BaseURL` values are absolute `googlevideo.com` URLs.
- With `?local=true`, the manifest `BaseURL` values are local
  `/companion/videoplayback?...&host=...` paths. Proxy mode therefore requires the
  parameter on the manifest URL.
- A relative progressive stream from `?local=true` served `206 Partial Content`
  (`Content-Range: bytes 0-1023/11829048`, `video/mp4`).
- A relative caption URL served `200 text/vtt`.

The current API documentation does **not** document `local`:
<https://docs.invidious.io/api/> (accessed 2026-10-24). This is consistent with the
parameter being legacy/undocumented but still honoured by the deployed version.

Implication: any code that hands an API URL directly to ExoPlayer, `just_audio`, or Dio
must resolve it against the instance origin first. This is the root cause of the reported
"cannot play any video" class of failures on recent Invidious versions.

### 4.2 Authentication

The live instance accepts the supplied account through the cookie endpoint. The `SID`
cookie is a session credential; it is stored by Clipious in its private database
(`Server.sidCookie`). The token flow (`/authorize_token`) is the preferred mechanism
because it yields a revocable bearer token, but it requires interactive browser approval.

Clipious's cookie login expects exactly HTTP 302 plus a `Set-Cookie` starting with `SID=`.
Both conditions were reproduced live, so the mechanism is compatible with this instance.

### 4.3 URL normalisation

`//api/v1/stats` returns **302** (redirect to the web UI), not JSON. A stored instance URL
with a trailing slash therefore breaks every request; `buildRequest` previously concatenated
the path blindly. `http://host:5566/` entered in the UI was stripped by the add-server flow,
but old records or URLs with multiple trailing slashes could still fail.

## 5. Upstream issues (evidence)

| Issue | Relevance |
|---|---|
| [#705](https://github.com/lamarios/clipious/issues/705) "Cannot play any video", 1.22.15 + private Invidious 2025.09.13 | Directly matches this setup; discussion mentions DASH settings and thumbnail configuration. Still open. |
| [#675](https://github.com/lamarios/clipious/issues/675) "Videos stopped playing" | Maintainer suggested HTTPS/local-proxy/DASH; user reported proxy mode fixed playback. |
| [#708](https://github.com/lamarios/clipious/issues/708) 404 thumbnail blocks playback | Thumbnail fallback/UI issue, not the root cause here. |
| [#700](https://github.com/lamarios/clipious/issues/700) audio-only fails | Fixed in 1.22.15, the version in this checkout. |
| [#692](https://github.com/lamarios/clipious/issues/692), [#659](https://github.com/lamarios/clipious/issues/659), [#683](https://github.com/lamarios/clipious/issues/683) | Self-hosted/token-login reports; some are public-instance API lockdown, some are configuration. |
| [#653](https://github.com/lamarios/clipious/issues/653) API lockdown / user agent | The app now sends `Clipious/<version>` via `MyHttpOverrides`. |

No upstream commit fixes the relative-URL handling as of `master` (`b9e7885`).

## 6. Android-specific findings

- `INTERNET`, `WAKE_LOCK`, foreground-service and media-playback permissions are declared.
- `POST_NOTIFICATIONS` was **missing** despite runtime notification permission requests;
  Android 13+ needs it in the manifest.
- Cleartext HTTP is permitted globally via `network_security_config.xml`
  (`cleartextTrafficPermitted="true"`, system + user CAs). This is necessary for arbitrary
  user-supplied HTTP instances, but it is broader than an HTTPS-only policy. Documented,
  not weakened further; HTTPS remains recommended.
- `android:enableOnBackInvokedCallback="false"` is set; back handling uses
  `back_button_interceptor`.
- Min SDK 24, target 36. No emulator was installed; no device was connected.

## 7. Network architecture: `localhost` is not the phone

`localhost:5566` on an Android device refers to the device itself. For the phone/tablet the
instance must be addressed by a routable address:

- LAN: `http://192.168.1.4:5566/` (host reachable on `eno1`, confirmed with HTTP 200)
- Tailscale: `http://100.109.64.77:5566/` (confirmed HTTP 200 from the host)

The container publishes `0.0.0.0:5566->3000/tcp`. LAN client isolation, AP isolation, or a
host firewall can still block the device. These were not changed. Remote/public exposure was
not configured and is out of scope unless explicitly requested.

## 8. Verified facts vs inferences

**Verified**

- API endpoints, shapes, relative URLs and authenticated access on the live instance.
- Auth cookie mechanism works with the supplied account (credentials not recorded here).
- Flutter pin is 3.35.3 and matches the repository.
- Source code paths and defects listed in `FINDINGS.md`.

**Inferred (not yet device-verified)**

- ExoPlayer/`just_audio` fail on relative URLs (the code passes them through unchanged);
  this is a well-defined platform requirement, not a statistical inference.
- The relative-URL defect is the primary cause of playback failure for this instance.
- Notifications on Android 13+ may be suppressed without the manifest permission.

**Unverified / gaps**

- Physical-device behaviour on the owner's phone and tablet.
- LAN firewall / AP-isolation behaviour from the devices.
- Token (`/authorize_token`) flow end-to-end, which requires interactive approval.
- Behaviour with a reverse proxy under a sub-path and HTTPS.
- Audio/video playback of live streams and DASH with the owner's exact codecs.

## 9. Sources

Accessed 2026-10-24 unless stated otherwise.

1. Clipious repository — <https://github.com/lamarios/clipious> (`master` `b9e7885`).
2. Clipious issues #705, #708, #700, #692, #683, #675, #659, #653 —
   `https://api.github.com/repos/lamarios/clipious/issues/<n>`.
3. Invidious API documentation — <https://docs.invidious.io/api/>.
4. Invidious source `src/invidious/routes/api/v1/videos.cr` —
   <https://raw.githubusercontent.com/iv-org/invidious/master/src/invidious/routes/api/v1/videos.cr>.
5. Flutter releases manifest — <https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json>.
6. Android notification permission — <https://developer.android.com/develop/ui/views/notifications/notification-permission>.
7. Live instance `http://localhost:5566` (stats, search, videos, channels, comments, auth).

## 10. Android automation tooling (2026-10-24)

### scrcpy

- Source: <https://github.com/genymobile/scrcpy> (only official release source).
- Version: **5.0.1**, official Linux x86_64 static build
  `scrcpy-linux-x86_64-v5.0.1.tar.gz`.
- SHA-256 verified against the official `SHA256SUMS.txt`:
  `9f969d30cc574816077edecda65719c1c70b0aee1df1ba5fa00779ac07b8fd6e` — **OK**.
- Installed locally at `.tooling/scrcpy/scrcpy` (44 MB with its bundled `adb`,
  `scrcpy-server`, SDL 3.4.18 and libavcodec). `scrcpy --version` runs successfully.
- **Recording verified on the tablet:** `scrcpy --no-audio --no-playback --time-limit=3
  --record=…` produced a 236 KB MP4; an extracted frame shows the app's fixed Comments tab.
- Capabilities: screen mirroring, keyboard/mouse/input injection, audio forwarding (Android
  11+), recording, virtual display, screen-off mirroring. It installs **nothing permanent**
  on the device; it pushes a temporary server while running.
- Requirement: USB debugging authorized on the device.

### Artemis (google/artemis)

- Source: <https://github.com/google/artemis>, Apache-2.0.
- It is **not** a simple device controller. It is a Python 3.12+ autonomous agent
  (LangGraph/LangChain, FastAPI, MCP) that perceives screenshots/UI hierarchies and asks a
  **cloud vision model** (Gemini / OpenAI / Anthropic / OpenRouter / xAI) what to do.
- Requirements: Python 3.12+ (host has 3.12.3), `uv` (present), an API key for at least one
  provider, and network access. Dependencies include `opencv-python`, `langchain-*`,
  `google-genai`, `uiautomator2`, and `fastapi`.
- Default behaviour installs an **Artemis Accessibility Helper** on the device
  (`ARTEMIS_HELPER_AUTO_INSTALL=true`). This can be disabled with
  `ARTEMIS_HELPER_AUTO_INSTALL=false`; `ARTEMIS_HIERARCHY_BACKEND=uiautomator` uses the
  UIAutomator hierarchy instead (which may install a temporary UIAutomator2 server APK).
- The default model preset is a Gemini Flash model plus a specialized Gemini ER model for
  coordinate grounding. The configuration is in `config/artemis.jsonc`; credentials go in
  `.env`.
- **Privacy implication:** using Artemis sends screenshots and UI text from the tablet to the
  chosen model provider. That is incompatible with "do not touch personal data" unless the
  screen is restricted to the test app and the owner explicitly consents to cloud inference.
- Setup performed locally: repository cloned to `.tooling/artemis` (59 MB), dependency
  installation under `.tooling/artemis/.venv` with `UV_CACHE_DIR` inside `.caches/uv`.
  `artemis --help` works. `.env` sets `ARTEMIS_HELPER_AUTO_INSTALL=false`,
  `ARTEMIS_HIERARCHY_BACKEND=uiautomator` and `ARTEMIS_KEEP_DEVICE_AWAKE=false`, with **no
  API key**. **No Artemis task or cloud inference has been run.**

### Device state after authorization

- Tablet serial `HA1D09AS`: **Lenovo TB-8505F**, Android **10 (API 29)**, arm64-v8a,
  800×1280 physical, density 240 → **533 dp shortest side**, 2.0 GB free.
- Clipious was not installed; the arm64 profile APK was installed and exercised.
- Device tests used adb/UIAutomator + screencap + `dumpsys media_session/notification/
  audio_flinger`; scrcpy 5.0.1 is available for visual control/recording.
- Results: server add, home/search/channels/playlists, VOD DASH/progressive/proxy, quality,
  audio-only, background/notification, 144p download, offline playback, comments (after fix),
  channel/playlist pages and rotation passed. Live streams are blocked by the server's
  invalid DASH manifest; auth/subscriptions/history were skipped for privacy.

### Tester comparison and chosen approach

| Option | Cloud? | Device install? | Assessment |
|---|---|---|---|
| **adb + UIAutomator dump + screencap** | No | No | **Chosen.** Flutter semantics are exposed as `content-desc` on this device; fastest to start, no extra runtime, works on API 29 |
| scrcpy 5.0.1 | No | Temporary server only | Chosen for visual/control and recording; not a test runner |
| Maestro CLI | No | No (driver via UIAutomator) | Viable YAML runner, API 29 supported, but adds a JVM tool; unnecessary because the semantics dump was sufficient |
| Appium + UiAutomator2 | No | Driver/server | Heavier (Node/Appium), robust but slower to set up; not needed |
| Flutter `integration_test` | No | Debug/test APK | Most reliable for widget-level assertions, but requires adding test code and a debug 696 MB APK; not chosen for breadth/time |
| Artemis | **Yes (VLM)** | Accessibility helper optional | Staged locally but **not used**: cloud screenshot upload conflicts with the privacy constraint |

**Privacy boundary:** keep Clipious in the foreground, do not open other apps, do not pull
personal files, do not log in to the Invidious account during automated UI tests. No Artemis
task or cloud inference was run.

### Device-specific findings from the run

- `authorThumbnail` (string) comments caused a raw type-cast error; fixed and verified.
- `youtu.be` links were resolved by the official YouTube app because the manifest required
  `/watch` and used `autoVerify`; fixed, though YouTube remains the default handler.
- Live DASH is invalid (`mediaPresentationDuration="PTNaNS"`); HLS endpoints return 403.
- Invidious exposes multiple codecs per resolution. On this tablet the 2160p/1440p/1080p
  entries in the quality sheet were **AV1** (e.g. 2160p 26.2 Mbit/s, 1080p 6.92 Mbit/s), which
  is software-decoded and caused the reported high-quality lag. Hardware **H.264** 1080p
  (5.89–6.93 Mbit/s) played with a ~11% CPU sample; Auto selects a hardware AVC track. The
  app now labels AV1 as software, sorts hardware codecs first and offers Auto.
- Long-press playback (temporary 2×) was implemented and verified on-device (`1.0 -> 2.0 ->
  1.0`); the badge appears while held.
- Logged-in Subscriptions/Playlists/History screens loaded read-only with the owner's cookie
  session; no account mutations were performed.
- Cold start is ~18–28 s; media-session progress can go stale after background/rotation while
  audio continues (AudioFlinger active).

Sources: scrcpy README/`doc/linux.md` and release `SHA256SUMS.txt`; Artemis `README.md`,
`pyproject.toml`, `.env.example`, `config/artemis.jsonc`, `start.sh`. Accessed 2026-10-24.
