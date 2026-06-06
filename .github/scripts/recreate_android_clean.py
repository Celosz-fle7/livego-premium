#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(".")
package_name = "com.livego.premium"
kotlin_package_dir = "com/livego/premium"

manifest = root / "android/app/src/main/AndroidManifest.xml"
manifest.parent.mkdir(parents=True, exist_ok=True)
manifest.write_text(f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- Universal APK: Android phone/tablet + Android TV. -->
    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />

    <application
        android:label="LiveGO Premium"
        android:name="${{applicationName}}"
        android:icon="@mipmap/ic_launcher"
        android:banner="@drawable/tv_banner"
        android:hardwareAccelerated="true"
        android:resizeableActivity="true"
        android:usesCleartextTraffic="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''', encoding="utf-8")

kotlin_root = root / "android/app/src/main/kotlin"
if kotlin_root.exists():
    for old in kotlin_root.rglob("MainActivity.kt"):
        old.unlink()

kotlin_dir = kotlin_root / kotlin_package_dir
kotlin_dir.mkdir(parents=True, exist_ok=True)
(kotlin_dir / "MainActivity.kt").write_text(f'''package {package_name}

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {{
    private fun forceBlackWindow() {{
        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
    }}

    override fun onCreate(savedInstanceState: Bundle?) {{
        forceBlackWindow()
        super.onCreate(savedInstanceState)
        forceBlackWindow()
    }}

    override fun onResume() {{
        super.onResume()
        forceBlackWindow()
    }}
}}
''', encoding="utf-8")

styles_base = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#000000</item>
        <item name="android:colorBackground">#000000</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowDisablePreview">true</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:statusBarColor">#000000</item>
        <item name="android:navigationBarColor">#000000</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>

    <style name="NormalTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#000000</item>
        <item name="android:colorBackground">#000000</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowDisablePreview">true</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:statusBarColor">#000000</item>
        <item name="android:navigationBarColor">#000000</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>
</resources>
'''

styles_v31 = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#000000</item>
        <item name="android:colorBackground">#000000</item>
        <item name="android:windowSplashScreenBackground">#000000</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowDisablePreview">true</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:statusBarColor">#000000</item>
        <item name="android:navigationBarColor">#000000</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>

    <style name="NormalTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#000000</item>
        <item name="android:colorBackground">#000000</item>
        <item name="android:windowSplashScreenBackground">#000000</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowDisablePreview">true</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:statusBarColor">#000000</item>
        <item name="android:navigationBarColor">#000000</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>
</resources>
'''

for rel, content in [
    ("android/app/src/main/res/values/styles.xml", styles_base),
    ("android/app/src/main/res/values-night/styles.xml", styles_base),
    ("android/app/src/main/res/values-v31/styles.xml", styles_v31),
    ("android/app/src/main/res/values-night-v31/styles.xml", styles_v31),
]:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

black_layer = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/black" />
</layer-list>
'''

for rel in [
    "android/app/src/main/res/drawable/launch_background.xml",
    "android/app/src/main/res/drawable-v21/launch_background.xml",
    "android/app/src/main/res/drawable/tv_banner.xml",
]:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(black_layer, encoding="utf-8")

for gradle in [
    root / "android/app/build.gradle",
    root / "android/app/build.gradle.kts",
]:
    if not gradle.exists():
        continue
    text = gradle.read_text(encoding="utf-8")
    text = re.sub(r'namespace\s*=\s*["\'][^"\']+["\']', f'namespace = "{package_name}"', text)
    text = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', f'applicationId = "{package_name}"', text)
    gradle.write_text(text, encoding="utf-8")

print("[OK] Android universal black bootstrap patched")
print("[OK] package/applicationId:", package_name)
print("[OK] phone launcher + leanback launcher enabled")
print("[OK] no forced landscape")
