#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(".").resolve()

MAIN_ACTIVITY = """package __PACKAGE_NAME__

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private fun forceBlackWindow() {
        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        forceBlackWindow()
        super.onCreate(savedInstanceState)
        forceBlackWindow()
    }

    override fun onResume() {
        super.onResume()
        forceBlackWindow()
    }
}
"""

BLACK_TEST_ACTIVITY = """package __PACKAGE_NAME__

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

class TvNativeBlackTestActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forceBlackWindow()

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            isFocusable = true
            isFocusableInTouchMode = true
        }

        val label = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 22f
            text = "NATIVE BLACK TEST\\nBACK untuk keluar"
            textAlignment = View.TEXT_ALIGNMENT_CENTER
        }

        root.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        )

        setContentView(root)
        root.requestFocus()
    }

    override fun onResume() {
        super.onResume()
        forceBlackWindow()
    }

    private fun forceBlackWindow() {
        window.setBackgroundDrawableResource(android.R.color.black)
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
            setResult(RESULT_OK)
            finish()
            return true
        }
        return true
    }
}
"""

NATIVE_PLAYER_ACTIVITY = """package __PACKAGE_NAME__

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout

class TvNativePlayerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forceBlackWindow()
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            isFocusable = true
            isFocusableInTouchMode = true
        }
        setContentView(root)
        root.requestFocus()
    }

    override fun onResume() {
        super.onResume()
        forceBlackWindow()
    }

    private fun forceBlackWindow() {
        window.setBackgroundDrawableResource(android.R.color.black)
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
            setResult(RESULT_OK)
            finish()
            return true
        }
        return true
    }
}
"""

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-name", default="com.livego.premium")
    return parser.parse_args()

def ensure_package(package_name: str) -> None:
    if not re.fullmatch(r"[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+", package_name):
        raise SystemExit(f"[FAIL] Invalid package name: {package_name}")

def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")

def patch_manifest() -> None:
    app_name = "$" + "{applicationName}"
    manifest = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />

    <application
        android:label="LiveGO Premium"
        android:name="__APP_NAME__"
        android:icon="@mipmap/ic_launcher"
        android:banner="@drawable/tv_banner"
        android:hardwareAccelerated="true"
        android:resizeableActivity="true"
        android:usesCleartextTraffic="true">

        <activity
            android:name=".TvNativeBlackTestActivity"
            android:exported="false"
            android:theme="@style/NormalTheme"
            android:screenOrientation="landscape"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true" />

        <activity
            android:name=".TvNativePlayerActivity"
            android:exported="false"
            android:theme="@style/NormalTheme"
            android:screenOrientation="landscape"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true" />

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

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
</manifest>
""".replace("__APP_NAME__", app_name)
    write_text(ROOT / "android/app/src/main/AndroidManifest.xml", manifest)

def patch_kotlin(package_name: str) -> None:
    kotlin_root = ROOT / "android/app/src/main/kotlin"
    if kotlin_root.exists():
        for old in kotlin_root.rglob("*.kt"):
            old.unlink()
    package_dir = kotlin_root / package_name.replace(".", "/")
    write_text(package_dir / "MainActivity.kt", MAIN_ACTIVITY.replace("__PACKAGE_NAME__", package_name))
    write_text(package_dir / "TvNativeBlackTestActivity.kt", BLACK_TEST_ACTIVITY.replace("__PACKAGE_NAME__", package_name))
    write_text(package_dir / "TvNativePlayerActivity.kt", NATIVE_PLAYER_ACTIVITY.replace("__PACKAGE_NAME__", package_name))

def patch_styles() -> None:
    styles = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#000000</item>
        <item name="android:colorBackground">#000000</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowFullscreen">true</item>
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
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowDisablePreview">true</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:statusBarColor">#000000</item>
        <item name="android:navigationBarColor">#000000</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>
</resources>
"""
    styles_v31 = styles.replace(
        '<item name="android:colorBackground">#000000</item>',
        '<item name="android:colorBackground">#000000</item>\n        <item name="android:windowSplashScreenBackground">#000000</item>',
    )
    for rel, content in [
        ("android/app/src/main/res/values/styles.xml", styles),
        ("android/app/src/main/res/values-night/styles.xml", styles),
        ("android/app/src/main/res/values-v31/styles.xml", styles_v31),
        ("android/app/src/main/res/values-night-v31/styles.xml", styles_v31),
    ]:
        write_text(ROOT / rel, content)

def patch_drawables() -> None:
    black = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/black" />
</layer-list>
"""
    for rel in [
        "android/app/src/main/res/drawable/launch_background.xml",
        "android/app/src/main/res/drawable-v21/launch_background.xml",
    ]:
        write_text(ROOT / rel, black)

    banner = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="320dp"
    android:height="180dp"
    android:viewportWidth="320"
    android:viewportHeight="180">
    <path android:fillColor="#05080D" android:pathData="M0,0h320v180h-320z" />
    <path android:fillColor="#00E5FF" android:pathData="M118,52l84,38l-84,38z" />
</vector>
"""
    write_text(ROOT / "android/app/src/main/res/drawable/tv_banner.xml", banner)

def patch_gradle(package_name: str) -> None:
    files = [p for p in [ROOT / "android/app/build.gradle", ROOT / "android/app/build.gradle.kts"] if p.exists()]
    if not files:
        raise SystemExit("[FAIL] Missing android/app/build.gradle or build.gradle.kts")
    for gradle in files:
        text = gradle.read_text(encoding="utf-8")
        text = re.sub(r"""namespace\s*=\s*["'][^"']+["']""", f'namespace = "{package_name}"', text)
        text = re.sub(r"""applicationId\s*=\s*["'][^"']+["']""", f'applicationId = "{package_name}"', text)
        gradle.write_text(text, encoding="utf-8")

def audit(package_name: str) -> None:
    errors = []
    gradle_files = [p for p in [ROOT / "android/app/build.gradle", ROOT / "android/app/build.gradle.kts"] if p.exists()]
    for gradle in gradle_files:
        text = gradle.read_text(encoding="utf-8")
        if f'namespace = "{package_name}"' not in text:
            errors.append(f"{gradle} namespace not patched")
        if f'applicationId = "{package_name}"' not in text:
            errors.append(f"{gradle} applicationId not patched")

    manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    for marker in [
        "android.intent.category.LAUNCHER",
        "android.intent.category.LEANBACK_LAUNCHER",
        "android.software.leanback",
        "android.hardware.touchscreen",
        "android.permission.INTERNET",
        "android.permission.ACCESS_NETWORK_STATE",
        "android.permission.WAKE_LOCK",
        "@drawable/tv_banner",
    ]:
        if marker not in manifest:
            errors.append(f"manifest missing {marker}")

    package_dir = ROOT / "android/app/src/main/kotlin" / package_name.replace(".", "/")
    for name in ["MainActivity.kt", "TvNativeBlackTestActivity.kt", "TvNativePlayerActivity.kt"]:
        p = package_dir / name
        if not p.exists():
            errors.append(f"missing {p}")
        elif f"package {package_name}" not in p.read_text(encoding="utf-8"):
            errors.append(f"package mismatch in {p}")

    if errors:
        print("[FAIL] Android universal audit failed:")
        for error in errors:
            print(f"- {error}")
        raise SystemExit(1)

    print("[OK] Android universal audit passed")
    print(f"[OK] package/applicationId = {package_name}")
    print("[OK] HP launcher + TV Leanback launcher enabled")
    print("[OK] black theme and TV banner installed")

def main() -> None:
    args = parse_args()
    package_name = args.package_name.strip()
    ensure_package(package_name)
    patch_manifest()
    patch_kotlin(package_name)
    patch_styles()
    patch_drawables()
    patch_gradle(package_name)
    audit(package_name)

if __name__ == "__main__":
    main()
