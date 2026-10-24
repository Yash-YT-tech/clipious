# CONFIDENCE — evidence-based readiness assessment

Date: 2026-10-25
This is a qualitative assessment, not a statistical probability. "HIGH" means verified by
execution or direct live evidence; "MEDIUM" means source evidence plus partial execution;
"LOW"/"UNKNOWN" means unverified or device-dependent.

| Area | Confidence | Evidence | Remaining uncertainty |
|---|---|---|---|
| Repository integrity | HIGH | Upstream `master` `b9e7885` fetched; clean tracked tree; changes isolated on a branch; `.gitignore` updated for tooling/caches | None material |
| Build reproducibility | HIGH (this workspace) | Flutter 3.35.3 pinned and verified; dependencies resolved; Gradle configured; debug, profile and split profile APKs built. Final arm64 profile APK verified with `aapt2`, `apksigner`, `unzip -t` (`TEST.md` §5) | Requires the workspace-local JDK/NDK/CMake shims and ~8 GB scratch space; a clean machine should use a full JDK and real NDK |
| API compatibility | HIGH | Every endpoint used by the app probed live: stats, video, search, suggestions, trending, popular, channels, comments, feed, subscriptions, playlists, history | Future Invidious changes; exact model-parsing on all response variants |
| Instance connectivity (host) | HIGH | `0.0.0.0:5566`; LAN `192.168.1.4:5566` and Tailscale `100.109.64.77:5566` returned HTTP 200 | Device-side LAN routing, AP isolation, VPN behaviour |
| Instance connectivity (device) | HIGH (tablet) / UNKNOWN (phone) | Tablet (192.168.1.3) reached `192.168.1.4:5566`; server added and home/search loaded | Phone not connected; AP isolation elsewhere untested |
| Search and browsing | HIGH (tablet) | Videos/Channels/Playlists tabs, channel page, playlist page and video detail all loaded real data | Pagination and malformed-response edge cases |
| Video playback | HIGH for VOD (hardware H.264) / BLOCKED for live | VOD works with DASH on/off and Proxy+DASH; codec-aware quality with Auto; 1080p H.264 ~11% CPU; hold-to-2× verified; AV1 is labelled software. Live DASH is invalid (`PTNaNS`) and HLS is 403 | 4K AV1 is inherently laggy on this tablet; live is server-side; other devices untested |
| Playback performance | MEDIUM | Auto picks a hardware AVC track; 1080p H.264 and 2× hold played on-device; AV1/4K shown as software and sorted last | No frame-timing trace (Flutter bypasses HWUI `gfxinfo`); steady cold start 3.4–3.5 s |
| Motion smoothness | MEDIUM | Tokenized 100–350 ms motion, player/tab/queue fades, thumbnail/grid rebuild fixes and reduced-motion smoke verified; static UI screenshots match | No formal DevTools p95 trace yet; player-overlay progress split, skeleton tickers and eager comments remain |
| Startup | MEDIUM | Steady cold start 4.3–5.1 s → 3.4–3.5 s; warm start 0.83 s; first run after install ~8 s | DB/engine floor; bootstrap UI or faster DB open would be needed for lower cold times |
| Keyboard/focus | HIGH | One-shot search focus; route push/pop clears focus and calls `TextInput.hide`; video/quality/back leave keyboard/toolbar hidden | Other text-field dialogs were not exhaustively deep-linked |
| Responsive layout | MEDIUM | Width/height policy separates layout from feature gating; 533 portrait/landscape, 600+, foldable and wide-short cases covered by 10 tests; profile build verified | Tablet disconnected, so no physical rotation/layout pass in this change |
| Audio-only playback | HIGH | Position advanced, AudioFlinger active, controls worked on-device | Other codecs/devices |
| Downloads | HIGH | 144p download completed (ffmpeg-kit loaded), item appears in Downloads, and offline playback worked with Wi-Fi disabled | Larger downloads, storage pressure |
| Authentication | HIGH (host + device read-only) | Cookie session works host-side; device Subscriptions/Playlists/History loaded with the owner's login | Account mutations intentionally not exercised; token flow interactive |
| Persistence | HIGH | Cold start restored the server and settings; downloaded video persisted | Process-death edge cases |
| Android lifecycle/background | MEDIUM | Background playback continued, MediaStyle notification with actions verified | Media-session position reporting went stale after background/rotation; phone lifecycle untested |
| Phone compatibility | UNKNOWN | Phone not connected | Everything |
| Tablet compatibility | MEDIUM | Lenovo TB-8505F, Android 10: portrait, landscape, dialogs and playback tested | One device; 533 dp uses phone layout; tablet-specific sidebar not active |
| Security | MEDIUM | No credentials logged after fix; TLS verification not weakened; cleartext and plaintext credential storage documented | Broader hardening (encrypted storage, cleartext scoping) deferred |
| Regression coverage | HIGH | 39 unit tests; analysis error-free; broad physical-device pass including hold-to-2×, codec-aware quality and logged-in read-only screens | Integration tests not runnable; phone untested; no account mutations |
| Installation reproducibility | HIGH (tablet) / UNKNOWN (phone) | Signed APK installed and launched on the tablet; package/version/ABI/signature verified; manual and adb instructions documented | Phone not installed; debug signing key differs from store builds; arm64 only |

## What would raise confidence

1. Install and test the APK on the phone (the tablet pass is the reference).
2. Fix the server-side live DASH manifest (`PTNaNS`) or enable HLS, then retest live playback.
3. A second Invidious version/instance to test absolute/relative URL variants and comments.
4. A dedicated test account/server at `localhost:3000` to restore the integration test suite.
5. Token-login round-trip on a device.
6. A release build with the owner's signing key for daily use.

## Build artifact status

The APK is **BUILT AND VERIFIED** as an artifact (ZIP integrity, signature, package ID,
version, target SDK, arm64-only native code) and was **installed and exercised on the Lenovo
TB-8505F tablet**. The build used a profile engine and workspace-local toolchain shims; native
libraries are packaged unstripped, which is why the APK is ~231 MiB. The phone is not tested.

## Explicit non-claims

- The app is **not** claimed to be fully device-tested across devices; only one Android 10
  tablet was exercised.
- Phone compatibility is **not** confirmed. The tested tablet is not a guarantee for other
  tablets.
- Live-stream playback is **not** working; the server emits an invalid DASH manifest.
- The Invidious server was **not** modified, exposed, or reconfigured.
- No credentials are stored in the repository or reports.
