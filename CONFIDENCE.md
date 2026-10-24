# CONFIDENCE — evidence-based readiness assessment

Date: 2026-10-24
This is a qualitative assessment, not a statistical probability. "HIGH" means verified by
execution or direct live evidence; "MEDIUM" means source evidence plus partial execution;
"LOW"/"UNKNOWN" means unverified or device-dependent.

| Area | Confidence | Evidence | Remaining uncertainty |
|---|---|---|---|
| Repository integrity | HIGH | Upstream `master` `b9e7885` fetched; clean tracked tree; changes isolated on a branch; `.gitignore` updated for tooling/caches | None material |
| Build reproducibility | HIGH (this workspace) | Flutter 3.35.3 pinned and verified; dependencies resolved; Gradle configured; debug, profile and split profile APKs built. Final arm64 profile APK verified with `aapt2`, `apksigner`, `unzip -t` (`TEST.md` §5) | Requires the workspace-local JDK/NDK/CMake shims and ~8 GB scratch space; a clean machine should use a full JDK and real NDK |
| API compatibility | HIGH | Every endpoint used by the app probed live: stats, video, search, suggestions, trending, popular, channels, comments, feed, subscriptions, playlists, history | Future Invidious changes; exact model-parsing on all response variants |
| Instance connectivity (host) | HIGH | `0.0.0.0:5566`; LAN `192.168.1.4:5566` and Tailscale `100.109.64.77:5566` returned HTTP 200 | Device-side LAN routing, AP isolation, VPN behaviour |
| Instance connectivity (device) | UNKNOWN | No device connected; the app previously used `localhost` on the PC | Owner must use the LAN/Tailscale URL and test |
| Search and browsing | MEDIUM | API verified; models compile; thumbnails resolved by existing widget | No device UI run; pagination/edge-case responses |
| Video playback | MEDIUM | Root cause identified and fixed for DASH/HLS/progressive/proxy URLs; resolver unit-tested; empty-stream guard | ExoPlayer codec/device behaviour; actual playback not run |
| Audio-only playback | MEDIUM | Relative adaptive/progressive URLs resolved; existing 1.22.15 audio fix retained | Device/just_audio behaviour |
| Downloads | MEDIUM | Relative thumbnail/stream URLs resolved; Dio timeouts; static analysis clean | Device storage, FFmpeg muxing, codec selection |
| Authentication | HIGH (host) / UNKNOWN (device) | Cookie login reproduced with valid credentials (302 + SID); token flow endpoint redirects correctly; auth endpoints return 200 with the session | Token flow requires interactive approval; device storage/UI |
| Persistence | MEDIUM | Existing Sembast/fileDb code path; server URL normalisation added | No device restart test; migration of pre-existing trailing-slash records (handled defensively) |
| Android lifecycle/background | LOW | Manifest permissions present/added; audio_service/Workmanager structure reviewed | No device background/rotation/process-death tests |
| Phone compatibility | UNKNOWN | No device connected | Everything |
| Tablet compatibility | UNKNOWN | Responsive layouts exist (`getDeviceType`, tablet views) but were not executed | Everything |
| Security | MEDIUM | No credentials logged after fix; TLS verification not weakened; cleartext and plaintext credential storage documented | Broader hardening (encrypted storage, cleartext scoping) deferred |
| Regression coverage | MEDIUM | 16 new unit tests; server-independent suite run; analysis error-free | Integration tests not runnable in this environment |
| Installation reproducibility | MEDIUM | Signed APK exists at `dist/clipious-1.22.15-arm64-profile.apk` (242,512,835 bytes, sha256 `58537dbf…ca458`), package/version/ABI/signature verified; manual and adb instructions documented | Not installed on a device yet; debug signing key differs from store builds; arm64 only |

## What would raise confidence

1. Owner installs the APK on phone and tablet and completes `TESTING_THINGS.md` sections A–D.
2. `adb logcat` from a playback failure, if any, to distinguish network, manifest and codec
   errors.
3. A second Invidious instance or version to test absolute/relative URL variants.
4. A dedicated test account/server at `localhost:3000` to restore the integration test suite.
5. Token-login round-trip on a device.
6. A release build with the owner's signing key for daily use.

## Build artifact status

The APK is **BUILT AND VERIFIED** as an artifact (ZIP integrity, signature, package ID,
version, target SDK, arm64-only native code). It is **NOT DEVICE-TESTED**. The build used a
profile engine and workspace-local toolchain shims; native libraries are packaged unstripped,
which is why the APK is ~210 MiB.

## Explicit non-claims

- The app is **not** claimed to be fully device-tested.
- Phone/tablet compatibility is **not** confirmed.
- The Invidious server was **not** modified, exposed, or reconfigured.
- No credentials are stored in the repository or reports.
