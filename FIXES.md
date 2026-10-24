# FIXES — implemented repairs

All changes are on branch `fix/invidious-android-compatibility` based on upstream `b9e7885`.
Commit hashes are filled in after the incremental commits.

## FIX-001 — Resolve relative media URLs (BUG-001, BUG-011)

- **Root cause:** Invidious returns relative URLs for DASH (`/api/manifest/dash/id/…`),
  proxied progressive/adaptive streams (`/videoplayback?…`), thumbnails and captions.
  Clipious passed them directly to ExoPlayer/`just_audio`. DASH is enabled by default, so
  the default playback path was affected even without proxy mode.
- **Files:** `lib/utils/url_utils.dart` (new), `lib/player/states/video_player.dart`,
  `lib/player/states/audio_player.dart`, `lib/settings/models/db/server.dart`.
- **Change:**
  - Added `normalizeInstanceUrl()` and `resolveInstanceUrl()` (absolute URLs unchanged,
    relative/absolute-path URLs resolved against the instance, path prefixes preserved).
  - Video: resolve HLS/DASH/progressive URLs, resolution-switch URLs and caption URLs;
    add `local=true` to HLS/DASH manifests in proxy mode so their segments stay local;
    guard empty `formatStreams`; fall back to progressive if `dashUrl` is absent.
  - Audio-only: resolve progressive and adaptive audio URLs.
  - `Server.headersForUrl()` normalises the base URL before the prefix check, so custom
    headers still apply to resolved URLs.
- **Tests:** `test/utils/url_utils_test.dart` — 11 cases, all pass.
- **Regression risk:** Low. Absolute URLs (and therefore public-instance playback) are
  returned unchanged. `isHls`/DASH track selection behaviour is preserved.
- **Commit:** `553e3ef` (URL resolver, player/audio/artwork; also covers FIX-009/FIX-010) and
  `1fb7aa1` (proxy-mode manifest `local=true`).

## FIX-002 — Accept relative thumbnails when adding a server (BUG-002)

- **Root cause:** The advanced add-server check treated any relative thumbnail URL as a
  misconfiguration and refused to save the server.
- **Files:** `lib/settings/states/add_server.dart`.
- **Change:** Normalise the URL before duplicate detection, validate it as HTTP(S) with a
  non-empty host, and keep the advanced test as a real `getVideo` API/schema check without
  rejecting relative URLs.
- **Tests:** Covered indirectly by static analysis; live API confirms relative thumbnails.
  Device confirmation pending.
- **Regression risk:** Low. Servers with genuinely broken absolute thumbnail hosts are no
  longer rejected at add time; the app already falls back between thumbnail URLs.

## FIX-003 — Downloads handle relative URLs and timeouts (BUG-003)

- **Root cause:** `Dio` received relative thumbnail and (in proxy mode) stream URLs.
- **Files:** `lib/downloads/states/download_manager.dart`.
- **Change:** Resolve thumbnail/video/audio URLs; apply custom headers to the resolved URL;
  add 30 s connect and 60 s receive timeouts.
- **Tests:** Static analysis; no automated download test (requires device storage/codecs).
- **Regression risk:** Low–medium: download selection logic unchanged; only URL/transport.

## FIX-004 — HTTP request timeout (BUG-004)

- **Root cause:** `package:http` has no default timeout.
- **Files:** `lib/service.dart`.
- **Change:** `Service` wraps `http.Client` in `_TimeoutClient` with a 30-second timeout.
- **Tests:** Covered by compile/analyze; timeout path not unit-tested.
- **Regression risk:** Low. Long polling is not used; all endpoints are short requests.

## FIX-005 — Normalise instance URLs (BUG-005)

- **Root cause:** Concatenating paths onto a URL with a trailing slash produced `//api/…`,
  which the instance redirects to the HTML UI (302).
- **Files:** `lib/service.dart`, `lib/settings/states/add_server.dart`,
  `lib/settings/models/db/server.dart`, `lib/utils/url_utils.dart`.
- **Change:** Trim whitespace and strip all trailing slashes in `buildRequest` and before
  storing a server.
- **Tests:** `test/utils/url_utils_test.dart`.
- **Regression risk:** Low.

## FIX-006 — Declare `POST_NOTIFICATIONS` (BUG-006)

- **Root cause:** Android 13+ requires the manifest permission before the runtime request
  can succeed.
- **Files:** `android/app/src/main/AndroidManifest.xml`.
- **Change:** Added `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`.
- **Tests:** Manifest inspection; runtime behaviour requires a device.
- **Regression risk:** Very low.

## FIX-007 — Do not expose the session cookie in login errors (BUG-007)

- **Root cause:** The failure message included the response `set-cookie` header.
- **Files:** `lib/service.dart`.
- **Change:** Report only the HTTP status; no credential material is logged.
- **Tests:** Code inspection.
- **Regression risk:** Very low.

## FIX-008 — Robust response handling (BUG-008)

- **Root cause:** Unguarded `jsonDecode` and no status check for non-empty JSON bodies.
- **Files:** `lib/service.dart`.
- **Change:** Translate decoding failures to `InvidiousServiceError`; preserve server
  `error` messages; reject non-2xx responses after error extraction.
- **Tests:** `test/service/handle_response_test.dart` — 5 cases, all pass.
- **Regression risk:** Low. Empty 2xx bodies still return `null` (existing behaviour).

## FIX-009 — Resolve TV channel banner (BUG-009)

- **Files:** `lib/channels/views/tv/screens/channel.dart`.
- **Change:** Resolve `authorBanners` URL against the selected server in a `FutureBuilder`.
- **Tests:** Static analysis; TV/device rendering not tested.
- **Regression risk:** Very low.

## FIX-010 — Resolve media notification artwork (BUG-010)

- **Files:** `lib/player/states/player.dart`.
- **Change:** Resolve the thumbnail URL before constructing `MediaItem.artUri`.
- **Tests:** Static analysis; notification rendering requires a device.
- **Regression risk:** Very low.

## Commit map

| Fix | Commit |
|---|---|
| FIX-001 (URL resolver, player/audio/artwork, TV banner) | `553e3ef`, `1fb7aa1` |
| FIX-002 (add-server validation) | `82e4467` |
| FIX-003 (downloads) | `bcd7d4e` |
| FIX-004 (timeouts) | `82e4467` |
| FIX-005 (URL normalisation) | `553e3ef`, `82e4467` |
| FIX-006 (notifications manifest) | `1abab50` |
| FIX-007 (cookie logging) | `82e4467` |
| FIX-008 (response handling) | `82e4467` |
| FIX-009 (TV banner) | `553e3ef` |
| FIX-010 (notification artwork) | `553e3ef` |
| Test helper fix | `8d991fb` |
| Build environment (local toolchain, NDK/cache policy) | `ce94c94` |
| Jetifier disabled for AndroidX-only build | `636872b` |
| Research/audit/handover documentation | `8622df1`, `aed4e97` |

## Incomplete / not fixed

| Finding | Reason |
|---|---|
| BUG-012 cleartext HTTP | Required for arbitrary HTTP instances; changing would break the owner's current setup. Documented. |
| BUG-013 plaintext credentials | Larger security hardening; not required for functionality. Documented. |
| BUG-015 integration tests | Need a dedicated Invidious test server/user; running them would delete real subscriptions/history. |
| BUG-016 stale public-server tests | Pre-existing test defect, unrelated to the integration; left untouched. |
