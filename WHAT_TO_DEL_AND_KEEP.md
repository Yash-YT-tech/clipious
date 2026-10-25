# What To Delete and Keep

Last updated: 2026-10-25

This cleanup removed only redownloadable SDKs, caches and generated build output.
No application source, tests, docs, git history, signing data or credentials were
deleted.

## Result

| Metric | Before | After |
|---|---:|---:|
| Project directory | ~17 GB | **440 MB** |
| Free space on `/media/yash/UbuntuData` | 1.6 GB | **18 GB** |
| Freed | — | **~16.4 GB** |

## Deleted (safe to redownload/regenerate)

| Path | Size | What it was | How it comes back |
|---|---:|---|---|
| `.caches/gradle/` | 7.6 GB | Gradle dependency/daemon cache | Automatic on the next Gradle build |
| `.caches/uv/` | 1.1 GB | Python/uv cache used by Artemis | Recreated by `uv` if Artemis is used |
| `.caches/pub/` | 471 MB | Dart/Flutter package cache | `flutter pub get` |
| `.caches/android/`, `.caches/config/`, `.caches/data/`, `.caches/cache/` | ~4 MB | AGP preferences, debug keystore, small caches | Regenerated on build |
| `build/` | 3.9 GB | Flutter/Gradle build output and test cache | `flutter build ...` |
| `.dart_tool/` | 358 MB | Dart tool/package metadata | `flutter pub get` |
| `.tooling/flutter/` | 2.3 GB | Flutter SDK 3.35.3 | Download Flutter 3.35.3 (see below) |
| `.tooling/jdk/` | 286 MB | Project-local JDK used for Gradle/jlink | Download/install a full JDK 21 (see below) |
| `.tooling/scrcpy/` | 44 MB | scrcpy 5.0.1 screen viewer/recorder | Download scrcpy 5.0.1 if screen control is needed |
| `.tooling/artemis/` (everything except `.env`) | 1.2 GB | Artemis source, venv/docs | Re-clone/rebuild Artemis if needed |
| `android/.gradle/` | 24 MB | Android Gradle project cache | Automatic on the next build |
| **Total removed** | **~16.2 GB** | | |

## Kept (do not delete)

| Path | Size | Why |
|---|---:|---|
| `lib/`, `test/`, `android/`, `ios/`, `assets/`, `pubspec.yaml`, `pubspec.lock` | application source | **Code — required** |
| `README.md`, `RESEARCH.md`, `PLAN.md`, `FINDINGS.md`, `FIXES.md`, `PROGRESS.md`, `TEST.md`, `CONFIDENCE.md`, `TESTING_THINGS.md`, `INSTALLATION.md` | docs | Project history/instructions |
| `.git/` | 91 MB | Full local history; never delete |
| `dist/clipious-1.22.15-arm64-profile.apk` | 232 MB | Built installable artifact; optional to delete if you only need source |
| `.tooling/testing/` | 48 MB | Device screenshots/recordings used as evidence; optional to delete if not needed |
| `.tooling/ndk/` | 84 KB | Project-local NDK/CMake/Gradle shims used by this build setup |
| `.tooling/env.sh` | 4 KB | Sets project-local SDK/cache paths for builds |
| `.tooling/artemis/.env` | 8 KB | Preserved credential/config file (Git-ignored; never commit) |

`ANDROID_HOME` is external at `/media/yash/UbuntuData/android-cli/sdk` and was **not**
deleted by this cleanup. It contains the Android SDK/build-tools/platform-tools.

## Optional further deletions

Only if you do not need them immediately:

| Path | Size | Consequence |
|---|---:|---|
| `dist/` | 232 MB | APK must be rebuilt (requires the toolchain again) |
| `.tooling/testing/` | 48 MB | Screenshots/recordings referenced by the test docs are lost |

Deleting both adds ~280 MB free, but is not necessary for normal source work.

## Free space needed for future work

- **Source-only edits / reading / git:** no extra toolchain space.
- **Analyze + tests:** toolchain + pub cache, roughly **4–6 GB**.
- **Full clean profile APK build:** plan for **~16 GB** of downloads/build space:
  - Flutter SDK ~2.3 GB
  - JDK ~300 MB
  - pub cache ~0.5 GB
  - Gradle cache ~7.6 GB (grows during build)
  - build output ~3.9 GB
  - APK/artifacts ~0.3 GB
  - Android SDK is external; if it also has to be downloaded, allow another **2–3 GB**.
- Current free space is **18 GB**. That is enough for one clean rebuild, but tight if
  Android SDK also needs re-downloading. **20–22 GB free is the comfortable target**.
- If you keep another large project on the same volume, free space before rebuilding.

## Redownload / rebuild steps

### 1. Flutter SDK 3.35.3

```bash
mkdir -p .tooling
# Option A: official Linux archive (version used by this project)
curl -L -o /tmp/flutter_linux_3.35.3-stable.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.35.3-stable.tar.xz
tar -xf /tmp/flutter_linux_3.35.3-stable.tar.xz -C .tooling
rm /tmp/flutter_linux_3.35.3-stable.tar.xz
.tooling/flutter/bin/flutter --version
```

### 2. Full JDK 21 (must include `jlink`)

Install/extract a full JDK 21 (Temurin or Ubuntu headless JDK) into the path expected by
`.tooling/env.sh`:

```text
.tooling/jdk/usr/lib/jvm/java-21-openjdk-amd64
```

If you use a different directory layout, update `JAVA_HOME` in `.tooling/env.sh`.
A JRE-only install is not sufficient; Gradle needs `jlink`.

### 3. Android SDK

The SDK is external and was not deleted:

```text
/media/yash/UbuntuData/android-cli/sdk
```

If it is missing, install command-line tools and then:

```bash
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

Keep `ANDROID_HOME`/`ANDROID_SDK_ROOT` pointed at that directory (`.tooling/env.sh`
already does this).

### 4. Dart packages and Gradle

```bash
source .tooling/env.sh
flutter pub get
```

Gradle dependencies are downloaded automatically on the first build into
`.caches/gradle` because `.tooling/env.sh` sets `GRADLE_USER_HOME`.

### 5. Build the APK

```bash
source .tooling/env.sh
flutter build apk --profile --split-per-abi \
  --target-platform android-arm64 --no-pub --no-tree-shake-icons
```

The APK is written to `build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk`.

### 6. Optional: scrcpy 5.0.1

Download the Linux x86_64 scrcpy 5.0.1 release and extract it to `.tooling/scrcpy`;
this is only needed for screen mirroring/recording.

### 7. Optional: Artemis

Artemis is not required to build or run Clipious. If needed, re-clone/install it under
`.tooling/artemis`; its preserved `.env` remains at `.tooling/artemis/.env` and must
never be committed.

## Notes

- The Android APK in `dist/` is debug-signed/profile-built. Rebuilding it requires the
  toolchain above.
- Never delete `.git`, source, docs, `.tooling/artemis/.env`, or `.tooling/ndk`.
- `.env`, `.tooling/`, `dist/`, and the agent-prompt files are Git-ignored and are not
  part of the pushed repository.
