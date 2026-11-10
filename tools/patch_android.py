#!/usr/bin/env python3
"""Adjusts the Android project that Flutter generates during the build:
app name, internet permission (to fetch new lessons) and text-to-speech."""
import re
import sys
from pathlib import Path

manifest = Path(sys.argv[1]) / "android/app/src/main/AndroidManifest.xml"
s = manifest.read_text()
if "android.permission.INTERNET" not in s:
    s = re.sub(r"(<manifest[^>]*>)",
               r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>'
               r'\n    <queries><intent><action android:name="android.intent.action.TTS_SERVICE"/></intent></queries>',
               s, count=1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Scol"', s, count=1)
manifest.write_text(s)
print("Android project patched.")
