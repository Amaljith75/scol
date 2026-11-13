#!/usr/bin/env python3
"""Draws the cartoon pictures the tutor shows on the board.

A lesson step with "visual: picture 🌱 💧" gets a simple, friendly cartoon drawn
from the step's own English words with Gemini's image model, saved once in the
chapter's images/ folder, and shown to every child from there (the emoji, if any,
are shown until the picture has arrived on the phone). Run again any time: it
only draws pictures that are missing.

    python3 tools/build_pictures.py            # draw missing pictures
    python3 tools/build_pictures.py --count    # just say how many are missing
Needs GEMINI_API_KEY and Pillow (pip install pillow).
"""
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_content  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
API = "https://generativelanguage.googleapis.com/v1beta"
MODEL = os.environ.get("SCOL_IMAGE_MODEL", "gemini-2.5-flash-image")
MAX_SECONDS = int(os.environ.get("SCOL_PICTURE_SECONDS", "2400"))
MAX_NEW = int(os.environ.get("SCOL_PICTURE_MAX", "300"))
SIZE = 640  # longest side, in pixels; keeps the repository small

STYLE = ("A simple, warm, friendly cartoon illustration for a children's school book (children aged 7 to 9 in "
         "Kerala, India). Flat colours, thick clean outlines, soft shading, plain light background, one clear "
         "scene, everything large and easy to recognise. No text, no letters, no numbers, no labels, no speech "
         "bubbles. Show exactly this: ")


def pictures(bundle):
    """Every (prompt, file) a picture visual needs, without repeats."""
    out = {}

    def take(v):
        if isinstance(v, dict) and v.get("kind") == "picture" and v.get("image") and v.get("prompt"):
            out.setdefault(v["image"], v["prompt"])

    for b in bundle["boards"]:
        for c in b["classes"]:
            for s in c["subjects"]:
                for ch in s["chapters"]:
                    for lesson in ch["lessons"]:
                        for st in lesson["steps"]:
                            take(st.get("visual"))
                        for alt in lesson.get("alts", {}).values():
                            take(alt.get("visual"))
    return out


def find_image(node):
    if isinstance(node, dict):
        data = node.get("inlineData") or node.get("inline_data")
        if isinstance(data, dict) and str(data.get("mimeType", data.get("mime_type", ""))).startswith("image/"):
            return base64.b64decode(data["data"])
        for v in node.values():
            found = find_image(v)
            if found:
                return found
    elif isinstance(node, list):
        for v in node:
            found = find_image(v)
            if found:
                return found
    return None


def draw(prompt):
    body = {"contents": [{"parts": [{"text": STYLE + prompt}]}],
            "generationConfig": {"responseModalities": ["IMAGE"]}}
    req = urllib.request.Request(f"{API}/models/{MODEL}:generateContent", data=json.dumps(body).encode(),
                                 headers={"x-goog-api-key": os.environ["GEMINI_API_KEY"], "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        png = find_image(json.load(r))
    if not png:
        raise RuntimeError("no picture in the answer")
    from PIL import Image
    img = Image.open(io.BytesIO(png)).convert("RGB")
    img.thumbnail((SIZE, SIZE))
    out = io.BytesIO()
    img.save(out, "PNG", optimize=True)
    return out.getvalue()


def main():
    bundle = build_content.build()
    if build_content.errors:
        print("Lessons have problems; fix them first (python3 tools/build_content.py).")
        return 1
    wanted = pictures(bundle)
    todo = {f: p for f, p in wanted.items() if not (ROOT / f).is_file()}
    print(f"{len(wanted)} pictures in the lessons, {len(todo)} still to draw.", flush=True)
    if "--count" in sys.argv or not todo:
        return 0
    if not os.environ.get("GEMINI_API_KEY"):
        print("GEMINI_API_KEY is not set, so no pictures were drawn.")
        return 0
    deadline = time.time() + MAX_SECONDS
    made = failed = quota = 0
    for f, prompt in list(todo.items())[:MAX_NEW]:
        if time.time() > deadline or quota >= 3:
            break
        try:
            png = draw(prompt)
            dest = ROOT / f
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(png)
            made += 1
            print(f"  drew {f} ({len(png) // 1024} KB): {prompt[:60]}", flush=True)
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:300]
            if e.code == 429:
                quota += 1
                print(f"  Gemini says the limit is reached: {detail}", flush=True)
                time.sleep(30)
            else:
                failed += 1
                print(f"  failed: {prompt[:50]!r}: HTTP {e.code} {detail}", flush=True)
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"  failed: {prompt[:50]!r}: {e}", flush=True)
    if quota >= 3:
        print("Stopping early: Gemini's daily limit is reached. The daily run will continue.")
    print(f"Drew {made} pictures ({failed} failed). {len(todo) - made} still to do.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
