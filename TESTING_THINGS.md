# TESTING_THINGS — physical Android checklist

This is the owner's manual test plan. It is written for the phone and tablet; no developer
tools are required beyond installing the APK (see `INSTALLATION.md`).

Record for each device once:

| Field | Phone | Tablet |
|---|---|---|
| Manufacturer / model | | |
| Android version | | |
| ABI (`adb shell getprop ro.product.cpu.abi`) | | |
| Screen size / orientation | | |
| App version shown in Settings | | |

**Important:** on the device, use a LAN/Tailscale address, **not** `localhost`:

- Wi-Fi/LAN: `http://192.168.1.4:5566`
- Tailscale: `http://100.109.64.77:5566`

Do not paste the Invidious password into reports, screenshots, or logs.

Status values: `NOT TESTED` / `PASS` / `FAIL` / `BLOCKED`.

## A. Installation and startup

| ID | Preconditions | Steps | Expected | Actual | Status | Notes |
|---|---|---|---|---|---|---|
| A-01 | APK available | Install the APK manually or with adb | Install succeeds; app icon "Clipious" appears | | NOT TESTED | |
| A-02 | A-01 | Launch the app | No crash; UI appears within a few seconds | | NOT TESTED | |
| A-03 | First launch | Complete/observe onboarding | Welcome wizard or main screen appears; no infinite spinner | | NOT TESTED | |
| A-04 | Server configured | Force-stop and relaunch | Instance URL and settings persist | | NOT TESTED | |

## B. Instance connectivity

| ID | Preconditions | Steps | Expected | Actual | Status | Notes |
|---|---|---|---|---|---|---|
| B-01 | Phone on same Wi-Fi | Add server `http://192.168.1.4:5566`; leave "also test server config" checked | Server is accepted (no thumbnail error); stats/video API works | | NOT TESTED | Key regression test |
| B-02 | Tablet on same Wi-Fi | Repeat B-01 | Same result | | NOT TESTED | |
| B-03 | Server added | Toggle "Proxy videos" on, then off | App still loads content in both modes | | NOT TESTED | |
| B-04 | Server added | Enter `http://192.168.1.4:9999` | Clear unreachable/error message; no endless spinner | | NOT TESTED | |
| B-05 | Server added | Enter `not-a-url` or `http://` | "Test and add" disabled or clear error | | NOT TESTED | |
| B-06 | Two servers (optional) | Switch between servers | Content reloads for the selected server | | NOT TESTED | |
| B-07 | Device offline | Disable Wi-Fi, open a tab | Error message appears within ~30 s; app recovers when Wi-Fi returns | | NOT TESTED | |
| B-08 | Tailscale installed | Use `http://100.109.64.77:5566` | Works outside the LAN | | NOT TESTED | Optional |

## C. Search and browsing

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| C-01 | Search for a common term (e.g. "music") | Results appear | | NOT TESTED |
| C-02 | Open a video result | Video detail loads with title, thumbnail, description | | NOT TESTED |
| C-03 | Search with spaces and non-Latin text | Results or a clean "no results" state; no crash | | NOT TESTED |
| C-04 | Open a channel from a video | Channel header, latest videos and tabs load | | NOT TESTED |
| C-05 | Open a playlist | Playlist header and videos load; scrolling paginates | | NOT TESTED |
| C-06 | Use search filters (sort/date/duration/type) | Results refresh; no error | | NOT TESTED |
| C-07 | Scroll a long list | Additional pages load; no duplicate/blank items | | NOT TESTED |
| C-08 | Press Back from detail screens | Returns to the previous screen without exiting unexpectedly | | NOT TESTED |

## D. Playback

Test once with default settings, once with "Proxy videos" enabled, and once with DASH
disabled in Clipious settings.

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| D-01 | Open a video and press play | Playback starts within a few seconds | | NOT TESTED |
| D-02 | Pause / resume | Position is preserved | | NOT TESTED |
| D-03 | Seek forward/back | Playback resumes at the new position | | NOT TESTED |
| D-04 | Change quality (if offered) | Video continues with the selected quality | | NOT TESTED |
| D-05 | Enable "Proxy videos", repeat D-01 | Playback still starts (relative URL fix) | | NOT TESTED |
| D-06 | Disable DASH in settings, repeat D-01 | Playback still starts | | NOT TESTED |
| D-07 | Switch video via recommendations/queue | New video plays; no stuck black screen | | NOT TESTED |
| D-08 | Lock/unlock screen during playback | Audio continues or resumes correctly | | NOT TESTED |
| D-09 | Background the app during playback | Audio continues; notification controls work | | NOT TESTED |
| D-10 | Rotate during playback | Video continues; layout adapts | | NOT TESTED |
| D-11 | Play an audio-only/music video in audio mode | Audio plays; notification artwork is visible (if available) | | NOT TESTED |
| D-12 | Play a live stream (optional) | Live playback starts or a clear error is shown | | NOT TESTED |
| D-13 | Interrupt network for ~10 s, restore | Player recovers or shows a clear error, not a permanent hang | | NOT TESTED |
| D-14 | Play a long video and seek near the end | Seeking works; progress is saved | | NOT TESTED |
| D-15 | Return to a partially watched video | Playback resumes near the saved position | | NOT TESTED |
| D-16 | Wait for controls to hide, then long-press the video and release | Plays at 2× while held with a `2x` badge; returns to the previous speed on release | | NOT TESTED |
| D-17 | Open Quality | Tracks show codec labels; H.264/VP9 first, AV1 (software) last; Auto is checked | | NOT TESTED |
| D-18 | Select 1080p H.264 if offered | Plays smoothly; 2160p AV1 may lag on this tablet | | NOT TESTED |

## E. User data and account behaviour

Authentication is optional. Cookie login was verified on the host side; if you use it, enter
the account identifier `yash` and the password supplied separately.

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| E-01 | Settings → server → Cookie login with valid credentials | "Logged in" state; no error | | NOT TESTED |
| E-02 | Open Subscriptions/feed while logged in | Subscriptions and feed load | | NOT TESTED |
| E-03 | Subscribe/unsubscribe a channel | State changes and survives a restart | | NOT TESTED |
| E-04 | Create a playlist; add a video; remove it | Playlist operations succeed | | NOT TESTED |
| E-05 | Open watch history (logged in) | History loads | | NOT TESTED |
| E-06 | Log out | Credentials cleared; authenticated features show the login state | | NOT TESTED |
| E-07 | Restart the app | Selected server, settings and login state persist | | NOT TESTED |
| E-08 | Check app logs/screens | No password, SID cookie or bearer token is visible | | NOT TESTED |

## F. Phone usability

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| F-01 | Portrait: browse home/search/channel | No overflow or clipped controls | | NOT TESTED |
| F-02 | Landscape: same screens | Readable layout; no overlap | | NOT TESTED |
| F-03 | Open the keyboard in search | Field stays visible; results not obscured | | NOT TESTED |
| F-04 | Tap all main controls | Touch targets are usable (≥ 48 dp) | | NOT TESTED |
| F-05 | Press system Back on each screen | Predictable navigation | | NOT TESTED |
| F-06 | Increase system font size | Text remains readable; no severe clipping | | NOT TESTED |

## G. Tablet usability

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| G-01 | Portrait home/search | Uses the larger width sensibly (grid/multi-column) | | NOT TESTED |
| G-02 | Landscape home/search | No huge empty margins or stretched thumbnails | | NOT TESTED |
| G-03 | Open a video in landscape | Player uses the available space; controls reachable | | NOT TESTED |
| G-04 | Open dialogs (add server, login, filters) | Dialog width is appropriate; no clipping | | NOT TESTED |
| G-05 | Rotate on each main screen | Layout adapts without losing state | | NOT TESTED |
| G-06 | Playlist/channel grids | Multiple columns display correctly | | NOT TESTED |
| G-07 | Keyboard/focus (tablet keyboard or remote) | Focus is visible and navigation works | | NOT TESTED |

## H. Lifecycle and resilience

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| H-01 | Minimise and reopen | App returns to the same screen | | NOT TESTED |
| H-02 | Switch Wi-Fi ↔ mobile data | Content reloads; no permanent error | | NOT TESTED |
| H-03 | Toggle Airplane mode on/off | Clear error, then recovery | | NOT TESTED |
| H-04 | Lock/unlock the device | App/player state is sane | | NOT TESTED |
| H-05 | Rotate during playback repeatedly | No crash; playback continues | | NOT TESTED |
| H-06 | Force-stop and reopen | App starts cleanly | | NOT TESTED |
| H-07 | Reboot the device and open the app | App starts; settings persist | | NOT TESTED |
| H-08 | Low-memory/background pressure (optional) | App does not crash on return | | NOT TESTED |

## I. Regression and stability

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| I-01 | Repeat B-01, D-01, D-05 after a restart | Still pass | | NOT TESTED |
| I-02 | Use the app for ~15 minutes across screens | No crash, no ANR | | NOT TESTED |
| I-03 | Check Android notification settings | Clipious notifications can be enabled (Android 13+) | | NOT TESTED |
| I-04 | Enable subscription notifications and wait for a check | Notification appears (if new videos exist) | | NOT TESTED |
| I-05 | Compare phone vs tablet results | Note any device-specific differences | | NOT TESTED |

## Reporting a failure

Send back:

1. Test ID (e.g. `D-05`).
2. Device and Android version.
3. Steps taken and what happened instead.
4. Whether it also fails on the other device.
5. Relevant app log lines (Settings → logs) and, if available, `adb logcat` output.
6. Whether the same URL plays in the Invidious web UI on the device's browser.

Do not include the account password, cookies, or tokens in reports.
