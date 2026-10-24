# FINDINGS — Clipious Android audit

Audit date: 2026-10-24
Baseline: upstream `b9e7885` (version `1.22.15+6077`), branch `fix/invidious-android-compatibility`
Target server: Invidious `2026.08.04-48c6110` at `http://localhost:5566`

Classification key:

- **Confirmed** — reproduced against the live server and/or conclusively demonstrated by source.
- **Likely** — strong source evidence, not reproduced on a device.
- **Potential** — plausible weakness requiring further verification.
- **Not a bug** — investigated and found to be expected behaviour.

Status values: **FIXED** (change implemented, automated test/build status in `TEST.md`),
**OPEN**, **DEFERRED**, **NOT A BUG**.

## Summary table

| ID | Sev. | Class | Area | Title | Status |
|---|---|---|---|---|---|
| BUG-001 | Critical | Confirmed | Playback | Relative Invidious media URLs are passed to native players unchanged | FIXED |
| BUG-002 | High | Confirmed | Instance setup | Advanced server test rejects relative thumbnail URLs, blocking self-hosted instances | FIXED |
| BUG-003 | High | Confirmed | Downloads | Download manager passes relative thumbnail/stream URLs to Dio | FIXED |
| BUG-004 | Medium | Confirmed | Networking | No HTTP timeouts; unreachable instance hangs indefinitely | FIXED |
| BUG-005 | Medium | Confirmed | Networking | Trailing slash in instance URL produces `//api/...` → 302 HTML | FIXED |
| BUG-006 | Medium | Confirmed | Android | `POST_NOTIFICATIONS` missing for Android 13+ | FIXED |
| BUG-007 | Medium | Confirmed | Security | Login error could include `Set-Cookie` (session ID) in logs/errors | FIXED |
| BUG-008 | Medium | Confirmed | API errors | Non-JSON errors raise `FormatException`; some non-2xx JSON bodies returned as success | FIXED |
| BUG-009 | Low | Confirmed | TV UI | TV channel banner uses a relative URL directly | FIXED |
| BUG-010 | Low | Confirmed | Media session | Notification artwork URI may be relative | FIXED |
| BUG-011 | Medium | Confirmed | Playback | Empty `formatStreams` causes `RangeError` | FIXED (with BUG-001) |
| BUG-012 | Medium | Potential | Security | Cleartext HTTP permitted globally | DEFERRED / documented |
| BUG-013 | Low | Potential | Security | Session credentials stored in plaintext app DB | DEFERRED / documented |
| BUG-014 | Info | Confirmed | Auth | Cookie login flow is compatible with this instance | NOT A BUG |
| BUG-015 | Low | Confirmed | Tests | Existing integration tests assume a separate localhost:3000 test server | OPEN (documented) |
| BUG-016 | Low | Confirmed | Tests | `server_list_settings_test.dart` assumes a public-server list that is never fetched | OPEN (pre-existing) |
| BUG-017 | High | Confirmed | Comments | Invidious returns `authorThumbnail` (string) but the model casts `authorThumbnails` (list) → Comments tab crashes | FIXED |
| BUG-018 | Medium | Confirmed | Android links | `youtu.be` filter required `/watch`; `autoVerify` on non-owned domains excluded Clipious as a handler | FIXED |
| BUG-019 | High | Confirmed/External | Live playback | Live DASH manifest has `mediaPresentationDuration="PTNaNS"`; HLS endpoints return 403 | BLOCKED (server); app fails gracefully |
| BUG-020 | Low | Confirmed | Playback telemetry | Media-session position stops updating in background/rotation while audio continues | OPEN (documented) |
| BUG-021 | Low | Confirmed | Performance | Cold start takes ~18–28 s on the Lenovo tablet | OPEN (documented) |
| BUG-022 | Low | Potential | Tablet UI | 533 dp tablet is classified as phone; tablet-specific layouts are not used | OPEN (documented) |
| BUG-023 | Info | Confirmed | Deep links | A video whose Invidious response is an empty 200 shows “Could not load the video” | NOT A BUG (server response) |
| BUG-024 | High | Confirmed | Performance/quality | 2160p/1440p/1080p options are AV1, software-decoded on this tablet, causing lag; menu hid codec and had no Auto | FIXED (codec labels, hardware-first sort, Auto) |
| FEATURE-001 | — | Implemented | Playback | No hold-to-2× gesture | DONE (badge + restore) |

---

## BUG-001 — Relative media URLs break playback

- **Severity:** Critical
- **Class:** Confirmed (live API + source)
- **Files:** `lib/player/states/video_player.dart`, `lib/player/states/audio_player.dart`
- **Baseline lines:** video player URL selection ~258–305; audio player ~119–146

**Defect.** With `local=true` (the app's "Proxy videos" setting), Invidious returns
`formatStreams[].url` and `adaptiveFormats[].url` as `/videoplayback?...`. Independently,
`dashUrl` is returned as `/api/manifest/dash/id/<id>` even without `local`. Clipious passed
these values straight to `BetterPlayerDataSource` / `AudioSource.uri`. Native players require
an absolute URI.

**Evidence.**

- Live `GET /api/v1/videos/dQw4w9WgXcQ?local=true` → `formatStreams[0].url = "/videoplayback?..."`,
  `dashUrl = "/api/manifest/dash/id/dQw4w9WgXcQ"`.
- The player only rewrote absolute `https://…googlevideo.com/` URLs when proxy mode was on.
- DASH is enabled by default (`use-dash` defaults to `true`), so the default path used the
  relative `dashUrl`.
- `/api/manifest/dash/id/<id>` redirects to `/companion/...`; adding `local=true` changes the
  manifest `BaseURL` from googlevideo to `/companion/videoplayback`, so proxy mode needs the
  parameter on the manifest URL.
- Upstream issue #705 reports "cannot play any video" on Clipious 1.22.15 with a recent
  self-hosted Invidious.

**Impact.** Video playback fails (black screen / player error) for this instance; proxy-mode
audio-only fails; resolution switching uses relative URLs.

**Repair.** Added `lib/utils/url_utils.dart` (`normalizeInstanceUrl`, `resolveInstanceUrl`,
`addLocalProxyParameter`) and resolved HLS/DASH/progressive/adaptive/caption URLs against the
instance origin before handing them to players. Proxy-mode HLS/DASH manifests get
`local=true`. Added an explicit empty-stream guard.

**Regression tests.** `test/utils/url_utils_test.dart` (11 cases).

## BUG-002 — Add-server test falsely rejects self-hosted instances

- **Severity:** High
- **Class:** Confirmed (live API + source)
- **Files:** `lib/settings/states/add_server.dart`
- **Baseline:** `validateServer()` advanced test

**Defect.** The "also test server config" check fetched a video and threw
`WrongThumbnailUrl` if **any** thumbnail URL started with `/`. This Invidious instance
returns all video thumbnails as `/vi/<id>/…`, so adding the server with the default checked
option always failed. The app's own `Thumbnail` widget already resolves relative thumbnail
URLs (`lib/utils/views/components/thumbnail.dart`), proving relative URLs are supported.

**Impact.** The owner cannot add the self-hosted instance through the normal UI unless the
advanced check is manually disabled; the error text points at a server-side thumbnail
configuration change that is not required.

**Repair.** Normalised the entered URL, validated it as an HTTP(S) URL with a host, and kept
the advanced test as a real API/schema check (`getVideo`) without rejecting relative URLs.

## BUG-003 — Downloads fail on relative URLs

- **Severity:** High
- **Class:** Confirmed (source + live API)
- **Files:** `lib/downloads/states/download_manager.dart`

**Defect.** `Dio.download()` received `ImageObject.getBestThumbnail(...).url` directly, which
is `/vi/...` on this instance. `Dio` requires an absolute request URI. In proxy mode, the
audio/video adaptive URLs are also relative.

**Repair.** Resolve thumbnail, video and audio URLs against the selected instance before
downloading; added Dio connect/receive timeouts; custom headers are now applied to the
resolved URL.

## BUG-004 — No request timeouts

- **Severity:** Medium
- **Class:** Confirmed (source)
- **Files:** `lib/service.dart`

**Defect.** `package:http` has no default timeout. An offline/incorrectly addressed instance
left the UI in a loading state until the OS closed the socket, including SponsorBlock/DeArrow
lookups to external hosts.

**Repair.** `Service` now wraps its client in `_TimeoutClient` with a 30-second timeout for
every request. Download requests use 30 s connect / 60 s receive timeouts.

## BUG-005 — Trailing slash in instance URL

- **Severity:** Medium
- **Class:** Confirmed (live server)
- **Files:** `lib/service.dart` (`buildRequest`), `lib/settings/states/add_server.dart`

**Defect.** `'${server.url}$path'` with `server.url = http://host:5566/` produces
`http://host:5566//api/v1/stats`. The live instance answers **302** (HTML UI redirect), not
JSON; `handleResponse` returned `null` or parsing threw. The add-server flow stripped only
one trailing slash and checked duplicates before normalising.

**Repair.** `normalizeInstanceUrl()` trims whitespace and all trailing slashes. It is applied
in `buildRequest`, add-server validation, and `Server.headersForUrl`.

## BUG-006 — Missing `POST_NOTIFICATIONS`

- **Severity:** Medium
- **Class:** Confirmed (manifest + Android platform requirement)
- **Files:** `android/app/src/main/AndroidManifest.xml`

**Defect.** The app requests notification permission at runtime
(`SettingsCubit.setBackgroundNotifications`) and creates channel/playlist notifications, but
the manifest did not declare `android.permission.POST_NOTIFICATIONS`. On Android 13+ the
runtime permission request cannot succeed.

**Repair.** Declared the permission. Runtime request behaviour was left unchanged.

## BUG-007 — Session cookie could be exposed in an error message

- **Severity:** Medium
- **Class:** Confirmed (source)
- **Files:** `lib/service.dart` (`loginWithCookies`)

**Defect.** An unexpected login response produced an error string containing
`response.headers['set-cookie']`, which can include the `SID` session credential; the catch
block logged it.

**Repair.** Error now reports only the HTTP status. Credentials are never logged or written to
documentation.

## BUG-008 — Error responses mishandled

- **Severity:** Medium
- **Class:** Confirmed (source)
- **Files:** `lib/service.dart` (`handleResponse`)

**Defect.** (a) A non-JSON body (HTML 401/502/302) caused an uncaught `FormatException`.
(b) A non-2xx JSON body without an `error` key was returned as a successful value.

**Repair.** JSON decoding is guarded and translated to `InvidiousServiceError`; status codes
outside 2xx are rejected after extracting the server's `error` message.

## BUG-009 — TV channel banner relative URL

- **Severity:** Low
- **Class:** Confirmed (source + live API)
- **Files:** `lib/channels/views/tv/screens/channel.dart`

**Defect.** `CachedNetworkImage` received `authorBanners[].url` directly; this Invidious
returns `/vi/…`-style relative banner/thumbnail paths. Phone/tablet used the resolving
`Thumbnail` widget; TV did not.

**Repair.** Resolve the banner against the current server before rendering.

## BUG-010 — Media notification artwork relative URL

- **Severity:** Low
- **Class:** Confirmed (source + live API)
- **Files:** `lib/player/states/player.dart` (`getMediaItem`)

**Defect.** `MediaItem.artUri` used the raw thumbnail URL. Relative URLs produce an invalid
URI and missing lockscreen/notification artwork.

**Repair.** Resolve against the selected server before constructing the `artUri`.

## BUG-011 — Empty progressive stream list

- **Severity:** Medium
- **Class:** Confirmed (source)
- **Files:** `lib/player/states/video_player.dart`

**Defect.** When HLS was absent, the code took `formatStreams[length - 1]` without checking
for an empty list. Live/upcoming/limited videos can return no progressive streams.

**Repair.** Guarded the list; if no playable source exists (HLS/DASH/progressive), report a
player error instead of throwing `RangeError`.

## BUG-012 — Global cleartext HTTP

- **Severity:** Medium
- **Class:** Potential
- **Files:** `android/app/src/main/res/xml/network_security_config.xml`

`cleartextTrafficPermitted="true"` applies to every host and user CAs are trusted. This is
required to support arbitrary user-entered HTTP instances (including the owner's LAN server)
and is common for Invidious clients, but it allows any plaintext traffic. Tightening it would
break configurable HTTP instances. **Deferred**; HTTPS is recommended in `INSTALLATION.md`.

## BUG-013 — Plaintext credentials at rest

- **Severity:** Low
- **Class:** Potential
- **Files:** `lib/utils/sembast_sqflite_database.dart`, `lib/settings/models/db/server.dart`

The `authToken` and `sidCookie` are stored in the app-private SQLite/Sembast database without
platform keystore encryption. The data is sandboxed, but a rooted device or backup extraction
could read it. **Deferred**; migrating to `flutter_secure_storage` is a larger change and was
not needed for the reported functionality.

## BUG-014 — Cookie authentication compatibility

- **Severity:** Info
- **Class:** Confirmed (live server)
- **Status:** **NOT A BUG**

`POST /login?type=invidious` with valid credentials returned 302 and
`Set-Cookie: SID=…; HttpOnly; SameSite=Lax`; invalid credentials returned 401 with no cookie.
This exactly matches `loginWithCookies`' expectations. No change required. The token flow
remains the recommended option for revocable credentials.

## BUG-015 — Integration tests require a separate test account/server

- **Severity:** Low
- **Class:** Confirmed
- **Files:** `test/globals.dart`, `test/utils/server.dart`, several `*_test.dart`

Tests hard-code `http://localhost:3000` and user `test`/`test`. They also delete all
subscriptions, playlists and history during teardown. They were **not** run against the
owner's account. This is a test-environment limitation, not an application defect.

## BUG-016 — Stale public-server list test

- **Severity:** Low
- **Class:** Confirmed
- **Files:** `test/settings/state/server_list_settings_test.dart`

`getPublicServers()` is commented out but the tests assert that `publicServers` is non-empty.
They fail in a clean checkout independently of these changes. Not modified.

---

## BUG-017 — Comments tab crashes on the current Invidious schema

- **Severity:** High
- **Class:** Confirmed (device + live API)
- **Files:** `lib/comments/models/comment.dart`, `lib/comments/models/video_comments.dart`
- **Device:** Lenovo TB-8505F, Android 10; video `gYpI_LDUbFo`

Invidious returns each comment with `authorThumbnail` (a **string**). The model declared
`List<ImageObject> authorThumbnails`; generated code did
`(json['authorThumbnails'] as List<dynamic>)`, which threw
`type 'Null' is not a subtype of type 'List<dynamic>'` and rendered that raw error in the
Comments tab. `VideoComments.comments` had the same risk if the API returned null.

**Repair:** `Comment.fromJson` normalizes a single `authorThumbnail` into the list form
(width/height 0) and defaults a missing list to `[]`; `VideoComments.fromJson` defaults a
null comments list to `[]`. Five regression tests added. Verified on-device after reinstall:
authors, timestamps and comment text render.

## BUG-018 — YouTube short links cannot open Clipious

- **Severity:** Medium
- **Class:** Confirmed (manifest + device)
- **Files:** `android/app/src/main/AndroidManifest.xml`

The `youtu.be` data element required `pathPrefix="/watch"`, but short links are
`https://youtu.be/<id>`. The whole filter also used `autoVerify="true"` on youtube.com /
youtu.be, domains Clipious cannot verify, so Android did not offer it as a handler. Android
resolved the links to `com.google.android.youtube/.UrlActivity`.

**Repair:** removed the path constraint, removed `autoVerify`, and moved `youtu.be` into a
separate intent filter so Android does not merge the `/watch` path from the youtube.com
entries. The app's parser already handled `youtu.be/<id>`. The installed YouTube app is still
the user's default handler; Clipious is now a valid alternative (the shell
`query-activities` command only reports the default handler, so implicit-choice behavior was
not forced).

## BUG-019 — Live streams fail on this Invidious version

- **Severity:** High
- **Class:** Confirmed / external
- **Evidence:** `/api/manifest/dash/id/rFZHOHl-L8A` returns a manifest with
  `type="static"` and `mediaPresentationDuration="PTNaNS"`; ExoPlayer 1.4.1 throws
  `NumberFormatException: For input string: "PTNaNS"`. `/api/manifest/hls_variant/...` and
  `/api/manifest/hls_playlist/...` return **403**. The live video has `hlsUrl: null`,
  zero `formatStreams`, and only `dashUrl`.

**Repair (client):** when there is no HLS/progressive source but a `dashUrl` exists, use DASH
even if the user disabled it. On failure, dispose the old controller and show the error, so
the previous video does not keep playing behind a mismatched title. Live playback itself
remains blocked until the server emits a valid DASH manifest (omit `mediaPresentationDuration`
for dynamic manifests) or enables HLS.

## BUG-020 — Stale media-session position

- **Severity:** Low
- **Class:** Confirmed
- **Evidence:** After home/rotation, `dumpsys media_session` kept `position=159079` with no
  timestamp updates, while `media.audio_flinger` showed an active track and the internal
  position had advanced to 208 s (revealed when a media key paused it). Audio continued.

Not fixed; affects progress reporting/UI only on this Android 10 device.

## BUG-021 — Slow cold start

First draw took **17.7 s** (`ActivityTaskManager: Fully drawn … +17s682ms`); later cold starts
took ~20–28 s. The app loads a large profile engine, initializes the DB/notifications and
fetches home data. Not fixed; performance investigation recommended.

## BUG-022 — 533 dp tablet uses the phone layout

`getDeviceType()` uses `shortestSide < 600`. The Lenovo panel is 800×1280 at 240 dpi =
**533 dp**, so it is classified as a phone. Portrait uses one column; landscape uses two
columns and full-screen playback. Tablet-specific views/sidebar are not activated. This is a
design threshold choice, not a crash; documented for the owner.

## BUG-023 — Empty video response for a deep link

`GET /api/v1/videos/jNQXAC9IVRw` returns **HTTP 200 with Content-Length 0** on this instance.
The app shows “Could not load the video”. This is a server response, not a client parsing bug.

## BUG-024 — High-quality playback lag is AV1 software decoding

- **Severity:** High (performance/UX)
- **Class:** Confirmed (device + Invidious API)
- **Device:** Lenovo TB-8505F, Android 10 (MediaTek, no AV1 hardware)

The quality sheet exposed tracks by resolution/bitrate only. Invidious returns multiple
codecs per resolution; on Big Buck Bunny and Costa Rica the 2160p/1440p/1080p entries in the
sheet were **AV1** (e.g. 2160p 26.2 Mbit/s, 1080p 6.92 Mbit/s). This tablet decodes AV1 in
software, producing high CPU and lag. The default ExoPlayer auto track was 720p **H.264**
(hardware) and played smoothly. The 1080p H.264 track (5.89–6.93 Mbit/s) also played with a
~11% CPU sample.

**Repair:** label every track with its codec (`AV1 (software)`, `H.264`, `VP9`, `HEVC`); sort
hardware-friendly codecs first and AV1 last; add an **Auto (Recommended)** option that clears
manual selection and lets ExoPlayer pick a supported track; show a warning that AV1/4K may
lag. Five quality-related unit tests cover codec detection.

**Limitation:** 4K AV1 cannot be made smooth on this hardware; the app now guides the user to
Auto or 1080p H.264 while keeping every original quality available.

## FEATURE-001 — Hold the video for temporary 2× playback

Implemented a long-press on the video surface: speed becomes 2.0× while held, a `2x` badge is
shown, and releasing restores the previous speed. The temporary speed is not persisted as the
remembered playback speed. Verified on-device with logs `Hold speed start: 1.0 -> 2.0` and
`Hold speed stop -> 1.0` (badge visible in the capture).

## Investigated and found acceptable

- Search sort/date/duration parameters, including `rating`/`date`, are accepted by the
  instance (unknown values are ignored rather than rejected).
- Channel `sort_by=newest|oldest|popular` is accepted.
- `published` is parsed as either an epoch integer or an ISO string (`Video._parsePublished`),
  matching current and older responses.
- `useProxy` adds `local=true` to API requests; this is intentional and now produces
  resolvable relative URLs.
- `utf16` request headers on GET requests are odd but ignored by the server; left unchanged.
- Feed, subscriptions, playlists and history endpoints match the models when authenticated.
- Cleartext is required for the owner's current HTTP server; documented rather than removed.
- Logged-in Subscriptions, Playlists and History screens loaded read-only with the owner's
  session; no mutations were performed.
