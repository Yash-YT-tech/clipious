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

## FIX-011 — Comments schema compatibility (BUG-017)

- **Files:** `lib/comments/models/comment.dart`, `lib/comments/models/video_comments.dart`,
  `test/comments/comment_json_test.dart`
- **Change:** normalize Invidious's singular `authorThumbnail` into `authorThumbnails`, default
  missing lists to `[]`, and tolerate a null top-level comments array.
- **Tests:** 5 new unit tests; on-device Comments tab verified after reinstall.
- **Commit:** `499b6ca`.

## FIX-012 — YouTube short-link intent filter (BUG-018)

- **Files:** `android/app/src/main/AndroidManifest.xml`
- **Change:** remove the `/watch` path from `youtu.be`, remove `autoVerify` (Clipious cannot
  verify YouTube domains), and keep `youtu.be` in a separate filter.
- **Verification:** the installed resolver table now shows a separate `youtu.be` filter with
  no path. The official YouTube app remains the device's default handler.
- **Commit:** `3a581a7`.

## FIX-013 — Live-stream DASH fallback and stale playback (BUG-019)

- **Files:** `lib/player/states/video_player.dart`
- **Change:** when there is no HLS/progressive source but `dashUrl` exists, use DASH even if the
  user disabled it; if no source exists, dispose the old controller and emit an error instead
  of leaving the previous video playing.
- **Verification:** on-device, the app now attempts the live DASH manifest, shows an error for
  the server's `PTNaNS` manifest, and stops the previous video. Live playback itself remains
  blocked server-side.
- **Commit:** `705bc7c`.

## FIX-014 — Codec-aware quality menu and Auto (BUG-024)

- **Files:** `lib/utils/codec_utils.dart`, `lib/player/states/video_player.dart`,
  `lib/player/views/components/player_controls.dart`, `test/utils/codec_utils_test.dart`
- **Change:** label tracks with codec (AV1 as software), sort H.264/VP9/HEVC before AV1, add
  Auto (Recommended) that clears manual selection, and show an AV1/4K warning. Track labels
  and selection indices use the same sorted list.
- **Tests:** 5 codec-label unit tests; on-device labels, ordering, Auto selection and
  1080p H.264 hardware playback verified.
- **Limitation:** 4K AV1 remains software-decoded on this tablet; manual selection still
  available but may lag.
- **Commit:** `3514960`.

## FIX-015 — Hold-to-2× playback (FEATURE-001)

- **Files:** `lib/player/states/interfaces/media_player.dart`,
  `lib/player/states/video_player.dart`, `lib/player/states/audio_player.dart`,
  `lib/player/states/player_controls.dart`,
  `lib/player/views/components/player_controls.dart`
- **Change:** long-press the video to set 2.0×; show a `2x` badge; restore the previous speed
  on release. Temporary speed is not persisted as the remembered speed (guarded at the
  speed-event handlers).
- **Tests:** on-device logs `1.0 -> 2.0` / `1.0` with the badge visible; verified on Auto/720p
  and 1080p H.264.
- **Commit:** `3514960`.

## FIX-016 — Motion tokens, fades and reduced motion (MOTION-001)

- **Files:** `lib/globals.dart`, `lib/utils/views/motion.dart`, `lib/main.dart`,
  `player_controls.dart`, `player.dart`, `expanded_player.dart`, `home.dart`, `video_queue.dart`,
  `compact_video.dart`, `video.dart`, `channel.dart`, `player_placeholder.dart`,
  `mini_player_progress.dart`.
- **Change:** 100/150/200/250/300/350/500 ms tokens; standard/decelerate/accelerate curves;
  player chrome and 2× badge fades; player-tab fade; faster queue/highlight/mini progress;
  reduced-motion wrapper; existing 300 ms Android Zoom page transition preserved.
- **Verification:** on-device screenshots at rest unchanged; controls fade in/out; tabs and queue
  render; 2× hold still works; reduced-motion mode launched/used without exceptions.
- **Commit:** `2209782`.

## FIX-017 — Thumbnail rebuild/decode path (PERF-001)

- **File:** `lib/utils/views/components/thumbnail.dart`.
- **Change:** resolve selected server from `AppCubit` instead of a DB future in `build`; keep
  the image request mounted; cap decode to display width × DPR; remove the decoration
  animation; add `RepaintBoundary`; reduce fades.
- **Verification:** Home/grid/player/settings thumbnails load; layout unchanged; no exceptions.
- **Commit:** `2209782`.

## FIX-018 — Player drag/progress timings (PERF-002)

- **Files:** `lib/player/states/player.dart`, `lib/player/views/components/player.dart`.
- **Change:** zero implicit animation durations during drag; emit position before a throttled
  5-second DB write; save on pause/hide; 200 ms mini/full snap.
- **Verification:** player controls, mini/full layout, 2× hold and tab content verified.
- **Commit:** `2209782`.

## FIX-019 — Lazy grid and build scope (PERF-003)

- **Files:** `lib/videos/views/components/video_list.dart`,
  `lib/downloads/views/components/download_app_bar_button.dart`,
  `lib/home/views/screens/home.dart`.
- **Change:** `GridView.builder` with identical geometry, cacheExtent and RepaintBoundary;
  download app-bar `buildWhen`; settings `select` for home layout.
- **Verification:** Home grid screenshots identical; scroll/no exceptions.
- **Commit:** `2209782`.

## FIX-020 — One-shot search focus and route input cleanup (BUG-025)

- **Files:** `lib/search/views/screens/search.dart`, `lib/router.dart`.
- **Change:** search focus is requested once when the search route opens (and only when there
  is no prefilled query); `MyRouteObserver` clears focus and sends `TextInput.hide` on every
  push/pop.
- **Verification:** search entry shows the keyboard; opening a video or quality sheet leaves the
  keyboard and Gboard floating toolbar hidden; returning to search does not reopen it until the
  field is tapped.
- **Commit:** `72a7e31`.

## FIX-021 — Startup parallelization and post-frame deferral (BUG-021)

- **Files:** `lib/main.dart`, `lib/settings/states/settings.dart`.
- **Change:** `PackageInfo` and database opening run in parallel; TV and server checks run in
  parallel; file-DB sync moved into settings initialization; notifications and high-refresh
  setup run after the first frame.
- **Verification:** steady cold start 4.3–5.1 s → 3.4–3.5 s; warm start 0.83 s; first launch
  after install still ~8 s due to Android dex/verification warm-up.
- **Commit:** `72a7e31`.

## FIX-022 — Window-ratio-aware layout policy (BUG-022)

- **Files:** `lib/utils.dart`, `DeviceWidget`, home shell, video detail, search, channel, player,
  playlist grid/inner view, subscription management, banner placeholders.
- **Change:** added `useWideLayoutForSize` / `useWideLayout` independent of feature-gating
  `getDeviceType()`. Compact portrait <600 dp stays phone; 533 dp landscape, 600 dp+ and
  foldable widths use wide; wide-but-short phones stay compact.
- **Verification:** 6 breakpoint tests + 4 `DeviceWidget` tests; 39/39 total; profile build.
  Physical rotation/layout check pending because the tablet is disconnected.
- **Commit:** `e486fea`.

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
| FIX-011 comment schema | `499b6ca` |
| FIX-012 youtu.be links | `3a581a7` |
| FIX-013 live DASH/stale playback | `705bc7c` |
| FIX-014 codec-aware quality/Auto | `3514960` |
| FIX-015 hold-to-2× | `3514960` |
| FIX-016 motion system/fades | `2209782` |
| FIX-017 thumbnail render path | `2209782` |
| FIX-018 player drag/progress | `2209782` |
| FIX-019 lazy grid/build scope | `2209782` |
| FIX-020 search focus/IME cleanup | `72a7e31` |
| FIX-021 startup parallelization | `72a7e31` |
| FIX-022 window-ratio layout | `e486fea` |
| scrcpy/Artemis research + test plan | `196b160` |
| Device-test results documentation | `a2570d2` |

## Incomplete / not fixed

| Finding | Reason |
|---|---|
| BUG-012 cleartext HTTP | Required for arbitrary HTTP instances; changing would break the owner's current setup. Documented. |
| BUG-013 plaintext credentials | Larger security hardening; not required for functionality. Documented. |
| BUG-015 integration tests | Need a dedicated Invidious test server/user; running them would delete real subscriptions/history. |
| BUG-016 stale public-server tests | Pre-existing test defect, unrelated to the integration; left untouched. |
| BUG-019 live playback | Server emits an invalid DASH manifest (`PTNaNS`) and HLS is 403; app-side fallback/error handling added, but live video remains blocked. |
| BUG-020 stale media-session position | Audio continues; progress reporting only. Needs an audio_service progress update fix. |
| BUG-021 slow cold start | Performance investigation, not a functional failure. |
| BUG-022 533 dp tablet classification | Threshold choice; changing it affects large phones and other layouts. |
