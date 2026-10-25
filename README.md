# Clipious — Yash Edition

An independently maintained Android client for [Invidious](https://invidious.io),
built with Flutter. This edition is maintained by **Yash Tathe** and focuses on
compatibility, playback quality, performance, responsive layout and a cleaner
day-to-day experience.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.en.html)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)](https://flutter.dev/)

## Download

Get the current build from **Yash’s releases**:

**[Download the latest APK](https://github.com/Yash-YT-tech/clipious/releases/latest)**

The current release is an **arm64-v8a, profile, debug-signed** build intended for
testing and personal use. It is not a Play Store release. For production distribution,
use a properly signed AAB/APK.

## What this edition improves

This fork keeps the Clipious feature set and adds/fixes:

- Reliable handling of relative Invidious media, thumbnail, caption and download URLs.
- Better server validation, timeouts and non-JSON/error responses.
- Fixed comments for Invidious’s `authorThumbnail` response shape.
- Correct `youtu.be` and `youtube.com/watch` link handling.
- Codec-aware quality selection:
  - H.264 / VP9 / HEVC options are shown first.
  - AV1 is labelled as software-decoded on devices without AV1 hardware.
  - **Auto (Recommended)** returns to adaptive hardware selection.
  - 4K AV1 remains available but is not recommended on low-end devices.
- **Hold-to-2× playback:** long-press the video for 2×, release to restore the
  previous speed. The temporary speed is not saved as the remembered speed.
- Smoother player chrome, tab transitions and queue motion with reduced-motion support.
- Faster thumbnails/grids and reduced rebuild pressure.
- One-shot search focus; the keyboard/IME no longer follows you into videos or quality
  sheets.
- Faster startup (parallel initialization and post-frame deferrals).
- Window-ratio-aware layout:
  - compact portrait: phone shell;
  - 533 dp tablet landscape, 600 dp+ and foldables: wide shell;
  - wide-but-short phones: compact shell.
- Existing settings, playback behavior and account features are preserved.

## Features

- Self-hosted or public Invidious servers
- Subscriptions and feed
- Playlists and watch history
- Video/audio playback, background playback, PiP
- DASH/progressive playback and quality selection
- Downloads and offline playback
- SponsorBlock and DeArrow
- Return YouTube Dislike
- Search, channels, comments and recommendations
- Android TV interface
- Responsive phone/tablet layouts

## Install

1. Download the APK from [Releases](https://github.com/Yash-YT-tech/clipious/releases/latest).
2. Allow installation from your file manager/browser if Android asks.
3. Install and add your Invidious server URL.

Because this build uses the Android debug signing key, installing it over an official
Clipious/F-Droid build with a different key will not work. Uninstalling first deletes
app data; back up anything you need.

## Build from source

Requirements:

- Flutter 3.35.3 (or a compatible stable Flutter 3.x)
- Full JDK 21 with `jlink`
- Android SDK with platform 36 and build-tools 36.0.0
- An Android device or emulator for testing

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --profile --split-per-abi \
  --target-platform android-arm64 --no-tree-shake-icons
```

The APK is written under `build/app/outputs/flutter-apk/`.

See [`INSTALLATION.md`](./INSTALLATION.md) for the exact toolchain and device
instructions, and [`WHAT_TO_DEL_AND_KEEP.md`](./WHAT_TO_DEL_AND_KEEP.md) for rebuild
space/redownload requirements.

## Testing

The project’s current test suite covers URL/response handling, comment schemas, codec
labels, motion/reduced-motion behavior and responsive breakpoints. Device testing was
done on a Lenovo TB-8505F (Android 10, arm64) without an emulator.

Known limitations:

- Live streams are blocked by the server’s invalid DASH manifest (`PTNaNS`); HLS returns
  403 on the tested instance.
- 4K AV1 is software-decoded on older tablets; use Auto or 1080p H.264 for smooth playback.
- Phone and iOS testing are not complete.
- The release APK is profile/debug-signed, not a production-signed build.

## Report an issue

Use [Yash’s issue tracker](https://github.com/Yash-YT-tech/clipious/issues).

## Maintainer

**Yash Tathe** — [@Yash-YT-tech](https://github.com/Yash-YT-tech)

## Upstream and attribution

This is an independent fork of **Clipious**, originally created by **Paul Fauchon** and
the Clipious contributors:

- Upstream: https://github.com/lamarios/clipious
- Original copyright: Copyright (C) 2023 Paul Fauchon
- Fork modifications: Copyright (C) 2026 Yash Tathe

This fork is not affiliated with or endorsed by the upstream project. GitHub’s
contributor graph includes inherited upstream history; that history and its authorship
are intentionally preserved.

The original project is licensed under the **GNU Affero General Public License v3.0**.
This fork remains under the same license. See [`LICENSE`](./LICENSE).

## License

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU Affero General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but **without any
warranty**; without even the implied warranty of merchantability or fitness for a
particular purpose. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this
program. If not, see <https://www.gnu.org/licenses/>.

## Liability

This tool is provided for lawful use with Invidious. The maintainer takes no
responsibility for third-party instances, misuse, downloading, or use that violates
applicable law or platform terms. Review the law and the terms that apply to you before
using or distributing this app.
