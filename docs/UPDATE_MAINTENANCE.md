# LiveGo TV In-App Update Maintenance

## Purpose

The TV app can update without uninstalling first.

The flow is:

1. Account → Periksa Update
2. App downloads `livego-version.json` from GitHub Release
3. App compares `versionCode`
4. App downloads the APK from `apkUrl`
5. App opens Android Package Installer

Android still asks the user to confirm installation. Silent install is not available for a normal sideloaded app.

## Required release assets

Upload these to the latest GitHub Release:

- `livego-version.json`
- the APK referenced by `apkUrl`

Example JSON:

{
  "versionName": "1.0.25",
  "versionCode": 25,
  "apkUrl": "https://github.com/Celosz-fle7/livego-premium/releases/download/v1.0.25/livego-tv.apk",
  "sha256": "",
  "changelog": [
    "Fix Player back return",
    "Improve Home cache"
  ],
  "required": false
}

## Critical Android rules

Update-over-install only works when:

- `applicationId` / packageName is the same
- signing key is the same
- new APK `versionCode` is higher

If signing key changes, Android shows signature conflict and the user must uninstall once.

## Current updater files

Flutter:

- `lib/tv/update/tv_update_model.dart`
- `lib/tv/update/tv_update_service.dart`
- `lib/tv/update/tv_update_screen.dart`
- Account update action opens `TvUpdateScreen`

Android:

- `MainActivity.kt`
- `AndroidManifest.xml`
- `android/app/src/main/res/xml/livego_update_paths.xml`

## Rule

Do not mix updater work with Player, Home focus, Source Manager, API provider, or cache patches.

## Dependency Rule

Use `androidx.core:core`, not `androidx.core:core-ktx`, for the updater FileProvider.

Reason:
- `core-ktx` can pull a newer Kotlin stdlib.
- The current Android/Flutter build may still resolve older `kotlin-stdlib-jdk7/jdk8`.
- Mixing those versions causes `checkReleaseDuplicateClasses` failures.

## Kotlin Dependency Alignment Rule

Release build can fail with duplicate Kotlin classes when Gradle resolves mixed stdlib versions, for example:
- `kotlin-stdlib:1.8.22`
- `kotlin-stdlib-jdk7:1.7.10`
- `kotlin-stdlib-jdk8:1.7.10`

Root Gradle now aligns these artifacts to `1.8.22`:
- `kotlin-stdlib`
- `kotlin-stdlib-jdk7`
- `kotlin-stdlib-jdk8`

Do not remove this alignment while Media3/updater/native Android dependencies are active.
