# INSTALLATION — Clipious debug build

Last updated: 2026-10-24

## 1. Supported devices

| Requirement | Value |
|---|---|
| Android version | 7.0 (API 24) or newer |
| Architecture | **arm64-v8a** for the APK described here (most phones/tablets since ~2015) |
| Network | Same LAN as the Invidious host, or Tailscale |
| Storage | ~250 MB free for installation/updates |

This build is a **debug** APK: it is larger than a release build, is marked debuggable, and is
signed with a local debug key. Use it for testing. A release build requires your own signing
key (see §11).

## 2. Artifact

| Item | Value |
|---|---|
| Build command | `bash -c 'source .tooling/env.sh && flutter build apk --profile --split-per-abi --target-platform android-arm64 --no-pub --no-tree-shake-icons'` |
| APK path | `dist/clipious-1.22.15-arm64-profile.apk` |
| Size | 242,512,835 bytes (231.3 MiB) |
| SHA-256 | `58537dbf99ddcd741ec5d7b234575caa0e766fd56cdd45300501e5d8281ca458` |
| Package ID | `com.github.lamarios.clipious` |
| Version | `1.22.15`, versionCode `60773` |
| Build mode | **profile** (AOT, debug-signed, installable) |
| Signing | Android debug key (`CN=Android Debug`) |
| ABI | `arm64-v8a` only |
| Min / target SDK | 24 / 36 |
| Built | 2026-10-24 |

Verify locally:

```bash
ls -lh dist/clipious-1.22.15-arm64-profile.apk
sha256sum dist/clipious-1.22.15-arm64-profile.apk
# Expected:
# 58537dbf99ddcd741ec5d7b234575caa0e766fd56cdd45300501e5d8281ca458
```

The APK was verified with the Android SDK tools: `aapt2 dump badging` reports
`package name='com.github.lamarios.clipious' versionCode='60773' versionName='1.22.15'`,
`targetSdkVersion='36'`, `native-code: 'arm64-v8a'`; `apksigner verify` succeeds with the
Android debug certificate.

A debug APK was also built successfully but is ~696 MB (debug engine + Vulkan validation
layer) and was removed to conserve disk space. Rebuild it only when verbose debug logs are
required:

```bash
bash -c 'source .tooling/env.sh && flutter build apk --debug --target-platform android-arm64 --no-pub'
```

## 3. Install manually (no computer)

1. Copy `dist/clipious-1.22.15-arm64-profile.apk` to the phone/tablet (USB, cloud drive, or
   `adb push`).
2. Open the file with the device's file manager.
3. Allow "Install unknown apps" for the file manager/browser when prompted.
4. Tap **Install** and then **Open**.

If a version of Clipious from F-Droid, GitHub Releases, or another source is already
installed, Android will reject this APK with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` because the
signing key differs. You must either keep the existing app or uninstall it first
(**uninstalling deletes app data**; see §8).

## 4. Install with USB debugging (`adb`)

```bash
# 1. Confirm the device and its ABI
adb devices -l
adb shell getprop ro.product.cpu.abi   # must be arm64-v8a for this APK

# 2. Install (replace an existing build signed with the same key, keep its data)
adb install -r dist/clipious-1.22.15-arm64-profile.apk

# 3. Verify the package
adb shell pm list packages | grep com.github.lamarios.clipious
adb shell dumpsys package com.github.lamarios.clipious | grep -E "versionName|versionCode"

# 4. Launch
adb shell monkey -p com.github.lamarios.clipious -c android.intent.category.LAUNCHER 1
```

If `adb` reports `no devices`, enable Developer options → USB debugging, reconnect the cable,
and accept the RSA prompt on the device. Do not use an emulator.

## 5. Configure the Invidious instance

**Do not use `http://localhost:5566/` on the phone or tablet.** `localhost` is the device
itself. Use an address that routes to the computer running Invidious:

- Wi-Fi/LAN: `http://192.168.1.4:5566`
- Tailscale: `http://100.109.64.77:5566`

Steps:

1. Open Clipious. If the welcome wizard appears, choose to add your own server.
2. Enter the URL (no trailing slash is required; the app normalises it).
3. Leave **"Also test server config"** enabled. It should now succeed.
4. Save and select the server.

The Invidious service listens on `0.0.0.0:5566` and was confirmed reachable at both addresses
from the host. If the device cannot connect, test the same URL in the device browser:
`http://192.168.1.4:5566/api/v1/stats` should return JSON. If the browser fails too, the
problem is network/AP isolation or a firewall, not Clipious.

## 6. Optional authentication

Two mechanisms exist:

1. **Token login (recommended):** server settings → token login. A browser opens the instance
   login page; sign in and approve the requested scopes; the app receives a bearer token.
2. **Cookie login:** server settings → cookie login. Enter the account identifier and
   password. This was verified against the instance from the host; the app stores the `SID`
   session cookie in its private database.

Never share the password, token, or `SID` cookie in screenshots or reports.

## 7. Launch and verify

1. Open Clipious.
2. Open the home tabs (Popular/Trending/Search) and search for a video.
3. Play a video.
4. In server settings, toggle **Proxy videos** and play another video.
5. Check Settings → video player for the DASH toggle and test with DASH on and off.

## 8. Update and uninstall

**Update (same signing key):**

```bash
adb install -r dist/clipious-1.22.15-arm64-profile.apk
```

App data (server URL, settings, history, downloads) is preserved when the package ID and
signing key are unchanged.

**Uninstall (data loss):**

```bash
adb uninstall com.github.lamarios.clipious
```

Uninstalling removes the app database, downloaded videos, settings, and login session. There
is no in-app export for server credentials; note the instance URL before uninstalling.

## 9. Permissions

Declared in the manifest:

- Internet, network state
- Wake lock, foreground service, media playback foreground service
- Notifications (`POST_NOTIFICATIONS`, Android 13+) — requested when you enable
  notifications
- Vibration, boot completed, exact alarm (background checks)
- Legacy write-external-storage (Android ≤ 9 only)

The app may ask for notification permission when you enable background/channel/playlist
notifications. Grant it if you want those notifications.

## 10. Collecting logs

```bash
# Live log, filtered to the app
adb logcat --pid=$(adb shell pidof -s com.github.lamarios.clipious)

# Crash buffer
adb logcat -b crash -d
```

In-app logs: Settings → app logs (copy/share). Review before sharing; do not include
credentials.

## 11. Release build (optional, owner signing key)

The repository's release config expects a keystore via `ANDROID_KEY_FILE`:

```bash
export ANDROID_KEY_FILE=/path/to/key.properties
bash -c 'source .tooling/env.sh && flutter build apk --release --target-platform android-arm64'
```

`key.properties` must contain `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
Do not commit the keystore or the properties file. A release APK can replace this debug APK
only if it is signed with the same key (it is not), so uninstall the debug build first.

## 12. Build-environment note

The pinned Flutter SDK is installed at `.tooling/flutter` and all caches under `.caches/`
(gitignored), per the workspace-only constraint. The following workspace-only workarounds
were needed because the project volume has limited free space and the machine has a JRE-only
system Java:

- A headless OpenJDK 21 package was extracted to `.tooling/jdk` (with runtime libs from the
  installed JRE) because the system JDK lacks `jlink`, which AGP's `JdkImageTransform`
  requires. `JAVA_HOME`/Gradle point at it via `.tooling/env.sh`.
- AGP's default NDK download (which would write outside the workspace) was avoided by
  pointing `ndkPath` at `.tooling/ndk`. Flutter's Gradle plugin configures an intentionally
  empty CMake project only to make AGP require an NDK for symbol stripping; the local SDK
  shims provide a language-enabled empty CMake project and a no-op `llvm-strip`, so no
  native code is compiled and native libraries are packaged unstripped.
- `android.enableJetifier=false` (all dependencies are AndroidX; the project dexes and builds
  without Jetifier).
- `--no-tree-shake-icons` is required because this Flutter 3.35.3 SDK installation does not
  ship `const_finder.dart.snapshot`.

These are build-environment accommodations, not changes to application behaviour. On a
normal development machine with a full JDK and a real NDK, remove `.tooling/ndk` and install
the NDK; `android/app/build.gradle` only uses the local shim when `.tooling/ndk` exists.

## 13. Known limitations

- This APK is arm64-only. If a device reports `armeabi-v7a`, rebuild with
  `--target-platform android-arm`.
- The APK is a profile build signed with the Android debug key. It is not suitable for
  distribution; use your own release key for that.
- The APK is ~210 MiB because `ffmpeg-kit-full` and the Flutter engine are bundled
  unstripped. A release build with a real NDK strip tool would be much smaller.
- HTTP is used for the local instance. On untrusted networks, prefer Tailscale or an HTTPS
  reverse proxy; do not expose Invidious publicly without authentication and TLS.
- Physical-device behaviour is not yet verified; use `TESTING_THINGS.md`.
