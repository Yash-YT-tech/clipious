# ANDROID_TEST_PLAN — automated device verification

Created: 2026-10-24
**Execution status:** tablet run completed (Lenovo TB-8505F, Android 10). Results and evidence
are in `TEST.md` §6. Phone, auth and live-stream tests remain pending/blocked.
Device: tablet serial `HA1D09AS`
App under test: Clipious `1.22.15` (`com.github.lamarios.clipious` unless the audit package is used)
Server: `http://192.168.1.4:5566` (LAN) or `http://100.109.64.77:5566` (Tailscale)

## 1. Safety and privacy rules (non-negotiable)

1. Keep Clipious in the foreground. Do not open Settings, personal apps, the notification
   shade, or the recents screen unless a test explicitly requires it.
2. Do not pull, list, or inspect personal files, photos, messages, accounts, or other app data.
3. Do not uninstall or clear data of any existing app. Do not change system settings.
4. **Do not log in to the Invidious account during automated UI tests.** Subscriptions,
   history, and playlists are personal data; authentication was already verified host-side.
5. If Artemis is used, do not enable its Accessibility Helper or send screenshots to a cloud
   model without explicit owner consent. Default: helper auto-install off, no cloud tasks.
6. If a personal notification or unrelated screen appears, pause, dismiss only the test app,
   and report it. Do not capture/upload it.
7. Downloads: skip by default (consumes device storage and may create files). Test only with
   owner approval and a short public video.
8. Uninstall only the test package created for this audit (if a separate package ID is used).

## 2. Tooling status

| Tool | Status | Location / notes |
|---|---|---|
| adb | Present | system `adb`, tablet visible but **unauthorized** |
| scrcpy 5.0.1 | Installed & verified (3 s recording) | `.tooling/scrcpy/scrcpy`; SHA-256 OK, bundled SDL3/ffmpeg/server |
| Artemis | Repository + Python env staged; CLI verified | `.tooling/artemis`; no API key, no tasks run, helper auto-install off |
| Flutter/Dart | Installed | `.tooling/flutter` (3.35.3 / Dart 3.9.2) |
| APK | Built & verified | `dist/clipious-1.22.15-arm64-profile.apk` (arm64, debug-signed) |
| Server | Live | Invidious `2026.08.04-48c6110`, LAN `192.168.1.4:5566` |

## 3. Preconditions and owner actions

1. On the tablet, accept the USB-debugging prompt: **Allow** and **Always allow from this
   computer**. `adb devices` must show `device`, not `unauthorized`.
2. Confirm the install strategy (separate audit package vs. existing app).
3. Confirm whether Artemis cloud inference is allowed. Without consent, tests use
   deterministic adb/UIAutomator only.
4. Keep the tablet on the same Wi-Fi as the Invidious host and unlocked during tests.

## 4. Install strategy

- Preferred: install a **separate test package** `com.github.lamarios.clipious.audit` so any
  existing Clipious install and its personal data are never touched. Requires a rebuild with
  an overridden application ID.
- If Clipious is not installed at all, the normal package may be used.
- Never uninstall the existing Clipious to make the debug-signed APK fit. Its signature
  differs from store builds; uninstalling would delete personal data.

## 5. Automation harness

- UI inspection: `adb shell uiautomator dump /sdcard/window.xml` + `adb pull` into
  `.tooling/testing/artifacts/<run>/`.
- Actions: `adb shell input tap/swipe/text/keyevent`; coordinates from the UI dump.
- Visual evidence: `adb exec-out screencap -p` and
  `scrcpy --no-audio --record=.tooling/testing/artifacts/<run>/session.mp4 --no-playback`
  (verify exact flags with `scrcpy --help`).
- Playback evidence: `adb shell dumpsys media_session`, progress-bar screenshots at two
  timestamps, and `adb logcat` filtered to the app for `ExoPlayer`, `MediaCodec`, and errors.
- Each run gets a directory with `device.txt`, `ui/*.xml`, `shots/*.png`, `logcat.txt`,
  `results.md`.

## 6. Test matrix

Status values: NOT RUN / PASS / FAIL / BLOCKED / SKIPPED (privacy).

| ID | Area | Steps (summary) | Expected | Evidence |
|---|---|---|---|---|
| P-01 | Preflight | `adb devices`, model/Android/ABI/size, package presence | `device` state; metadata recorded | device.txt |
| P-02 | Install | Install audit APK; launch | Installs, no crash on launch | screenshot, logcat |
| P-03 | Instance setup | Add `http://192.168.1.4:5566`, keep advanced test on; save/select | Accepted without thumbnail error | screenshots |
| P-04 | Home | Open Popular/Trending tabs | Lists load; thumbnails visible | screenshots |
| P-05 | Search | Search "music"; open result | Results and detail load | screenshots |
| P-06 | Search filters | Apply type/sort/date/duration | Results refresh, no error | screenshots |
| P-07 | Suggestions | Type in search field | Suggestions appear | screenshot |
| P-08 | Channel | Open channel from a video | Header, videos, tabs load | screenshots |
| P-09 | Playlist | Open a public playlist | Items and pagination load | screenshots |
| P-10 | Playback default | Play a short public video (DASH on, proxy off) | Video starts; progress advances | media_session, 2 screenshots, logcat |
| P-11 | Playback controls | Pause/resume/seek | Position changes correctly | media_session, screenshots |
| P-12 | Quality/track | Change quality/track if offered | Playback continues | screenshot |
| P-13 | Proxy mode | Enable "Proxy videos"; play another video | Starts via instance (no relative-URL failure) | media_session, logcat |
| P-14 | DASH off | Disable DASH; play | Starts with progressive stream | media_session, logcat |
| P-15 | Audio-only | Toggle audio-only mode | Audio plays; UI shows audio player | media_session |
| P-16 | Background | Home during playback; check notification controls | Playback continues; controls work | dumpsys, screenshot |
| P-17 | Rotation | Rotate during video; rotate home/tablet layout | Layout adapts; playback continues | screenshots |
| P-18 | Persistence | Force-stop, relaunch | Server/settings persist; no crash | screenshots |
| P-19 | Network loss | Airplane mode 10 s, restore | Clear error, then recovery | screenshots, logcat |
| P-20 | Logs | Inspect app logs/crash buffer | No secrets, no fatal exceptions | logcat |
| P-21 | Tablet UI | Multi-column grids, dialogs, keyboard/focus | No clipping/overlap | screenshots |
| A-01 | Auth/account | Login/subscriptions/history | — | **SKIPPED (personal data)** |

## 7. Pass/fail criteria

- **PASS:** expected screen/state is observed in the UI dump/screenshot, no fatal
  `AndroidRuntime`/`FATAL EXCEPTION`, and playback evidence advances (position changes or
  media session state is playing).
- **FAIL:** crash, ANR, permanent spinner (>30 s on LAN), playback error, wrong screen, or
  data-loss risk.
- **BLOCKED:** device unauthorized, network unreachable, or a required owner consent missing.
- A test is never marked PASS from source inspection alone.

## 8. Abort / rollback

- Stop on any unexpected personal-data screen, system dialog, or device authorization loss.
- Stop scrcpy and remove the temporary server; it leaves no permanent app.
- Uninstall only the audit package if one was installed; leave all other apps/data intact.
- Record the abort reason and last screenshot in the run directory.

## 9. Owner decisions required

1. Accept USB debugging on the tablet.
2. Separate audit package (recommended) or normal package (only if Clipious is absent).
3. Artemis cloud mode: off (deterministic adb only, default), or approved provider/key.
4. Optional: permission to test downloads and notification permissions.
