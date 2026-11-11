#!/usr/bin/env python3
"""Adjusts the Android project that Flutter generates during the build:
app name, app icon, internet permission (to fetch new lessons and voices)
and text-to-speech."""
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
    s = re.sub(r"(<manifest[^>]*>)",
               r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>'
               r'\n    <queries><intent><action android:name="android.intent.action.TTS_SERVICE"/></intent></queries>',
               s, count=1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Scol"', s, count=1)
manifest.write_text(s)

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
