#!/usr/bin/env python3
"""Adjusts the Android project that Flutter generates during the build:
app name and icon; permissions for the internet (new lessons, voices, questions),
the microphone (asking questions) and notifications (study reminders); and the
build settings the reminders need."""
import re
import shutil
import sys
from pathlib import Path

app = Path(sys.argv[1])
res = app / "android/app/src/main/res"
brand = app / "branding"

manifest = app / "android/app/src/main/AndroidManifest.xml"
s = manifest.read_text()
if "android.permission.INTERNET" not in s:
    s = re.sub(r"(<manifest[^>]*>)", r'''\1
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <queries>
        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
        <intent><action android:name="android.speech.RecognitionService"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
    </queries>''', s, count=1)
if "ScheduledNotificationReceiver" not in s:
    s = s.replace("</application>", '''    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Scol"', s, count=1)
manifest.write_text(s)

# Reminders need newer Java features on older phones ("desugaring").
kts = app / "android/app/build.gradle.kts"
groovy = app / "android/app/build.gradle"
if kts.exists():
    g = kts.read_text()
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(g)
elif groovy.exists():
    g = groovy.read_text()
    if "coreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(g)

# Icon: plain files for old phones, a full-bleed "adaptive" icon for new ones.
for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    (res / f"mipmap-{d}").mkdir(parents=True, exist_ok=True)
    shutil.copy(brand / f"ic_launcher_{d}.png", res / f"mipmap-{d}/ic_launcher.png")
(res / "drawable-nodpi").mkdir(parents=True, exist_ok=True)
shutil.copy(brand / "ic_launcher_art.png", res / "drawable-nodpi/ic_launcher_art.png")
shutil.copy(brand / "ic_launcher_blank.png", res / "drawable-nodpi/ic_launcher_blank.png")
(res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
(res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@drawable/ic_launcher_art"/>\n'
    '    <foreground android:drawable="@drawable/ic_launcher_blank"/>\n'
    '</adaptive-icon>\n')
print("Android project patched.")
