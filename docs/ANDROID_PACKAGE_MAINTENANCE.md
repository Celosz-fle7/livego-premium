# Android Package Maintenance

Current Android package/applicationId:

```text
com.livego.premium
```

Status:
- Android package has already been renamed from `com.example.livego_premium`.
- Do not recreate the Android folder again unless absolutely necessary.
- The recreate workflow was disabled after package migration.
- Future Android fixes should patch the existing `android/` folder directly.

Why:
- Recreating Android can reset Manifest, themes, window background, TV launcher, and player-related Activity/theme setup.
- Player/window stability depends on keeping Android theme and window settings stable.

Required Android checks after any Android patch:

```bash
grep -n "namespace\|applicationId" android/app/build.gradle
grep -R "package com.livego.premium" -n android/app/src/main/kotlin
grep -n "LAUNCHER\|LEANBACK_LAUNCHER\|tv_banner\|INTERNET\|WAKE_LOCK" android/app/src/main/AndroidManifest.xml
```

Expected:
- `namespace = "com.livego.premium"`
- `applicationId = "com.livego.premium"`
- Kotlin package: `package com.livego.premium`
- HP launcher and TV Leanback launcher must remain.
- Black LaunchTheme/NormalTheme should not be removed.
