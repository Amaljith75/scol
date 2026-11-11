#!/usr/bin/env python3
"""Makes the tutors' voices.

Every line a tutor can say (lesson text, hints, explanations, greetings) is
turned into a small sound file with Gemini's speech model, once, and saved in
voice/<tutor>/. The app downloads these files, so no key is ever inside the app
and nothing a child does is sent to Gemini.

Needs the GEMINI_API_KEY environment variable (a GitHub Actions secret).
Run again any time: it only makes the files that are missing.

    python3 tools/build_voice.py            # make missing files
    python3 tools/build_voice.py --count    # just say how many are missing
"""
import base64
import concurrent.futures as cf
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_content  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
VOICE = ROOT / "voice"
API = "https://generativelanguage.googleapis.com/v1beta"
MODEL = os.environ.get("SCOL_TTS_MODEL", "gemini-3.8-flash-tts")
OLD_MODEL = "gemini-2.5-flash-preview-tts"
MAX_SECONDS = int(os.environ.get("SCOL_VOICE_SECONDS", "2700"))
MAX_NEW = int(os.environ.get("SCOL_VOICE_MAX", "4000"))
THREADS = int(os.environ.get("SCOL_VOICE_THREADS", "3"))
LANGS = ("en", "ml")
EMOJI = re.compile("[\U0001F000-\U0001FFFF←-⇿☀-➿⬀-⯿️]")
SPOKEN = {
    "en": [("×", " times "), ("=", " equals "), ("+", " plus "), ("−", " minus "),
           (r"\bcm\b", "centimetres"), (r"\bkm\b", "kilometres"), (r"(?<=\d) m\b", " metres")],
    "ml": [("×", " ഗുണം "), ("=", " സമം "), ("+", " പ്ലസ് "), ("−", " മൈനസ് "),
           ("സെ.മീ", "സെന്റിമീറ്റർ"), ("കി.മീ", "കിലോമീറ്റർ")],
}


def clip_id(voice, lang, text):
    """Must match clipId() in app/lib/voice.dart."""
    return hashlib.sha1(f"{voice}|{lang}|{text}".encode("utf-8")).hexdigest()[:20]


def spoken(text, lang):
    out = EMOJI.sub(" ", text)
    for pat, rep in SPOKEN[lang]:
        out = re.sub(pat, rep, out) if pat.startswith(("\\", "(")) else out.replace(pat, rep)
    out = out.replace("?", "?").replace("...", ", ")
    return re.sub(r"\s+", " ", out).strip()


def lines_for(bundle, tutor):
    """Every (lang, text) this tutor may speak, in the order children meet them."""
    seen, out = set(), []

    def add(value, only=None):
        if isinstance(value, list):
            for v in value:
                add(v, only)
            return
        if isinstance(value, str):
            value = {only or "en": value}
        for lang in LANGS:
            t = (value or {}).get(lang)
            if isinstance(t, list):
                for x in t:
                    add({lang: x})
            elif t and (lang, t) not in seen and re.search(r"\w", EMOJI.sub("", t)):
                seen.add((lang, t))
                out.append((lang, t))

    for k in ("hello", "praise", "oops", "cheer"):
        add(tutor.get(k))
    for v in bundle.get("phrases", {}).values():
        add(v)
    for b in bundle["boards"]:
        for c in b["classes"]:
            for s in c["subjects"]:
                for ch in s["chapters"]:
                    for lesson in ch["lessons"]:
                        add(lesson.get("title"))
                        for alt in lesson.get("alts", {}).values():
                            add(alt.get("text"))
                        for st in lesson["steps"]:
                            add(st.get("text"))
                            add(st.get("hint"))
                            add(st.get("explain"))
                            if st.get("form") == "think":
                                add({k: st["answer"] for k in st.get("text", {})})
    return out


class Quota(Exception):
    pass


def _post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={
        "x-goog-api-key": os.environ["GEMINI_API_KEY"], "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:400]
        if e.code == 429:
            if not _mode.get("told"):
                _mode["told"] = True
                print(f"  Gemini says the limit is reached: {detail}", flush=True)
            raise Quota(detail) from None
        raise RuntimeError(f"HTTP {e.code}: {detail}") from None


def _find_audio(node):
    """Find the base64 audio wherever the API put it in its answer."""
    if isinstance(node, dict):
        data = node.get("data")
        if isinstance(data, str) and len(data) > 800:
            return base64.b64decode(data)
        for v in node.values():
            found = _find_audio(v)
            if found:
                return found
    elif isinstance(node, list):
        for v in node:
            found = _find_audio(v)
            if found:
                return found
    return None


_mode = {"api": "interactions"}


def synth(text, voice, style):
    if _mode["api"] == "interactions":
        body = {"model": MODEL,
                "input": [{"type": "user_input", "content": [{
                    "type": "text", "text": text,
                    "annotations": [{"type": "speech_metadata", "style": style}]}]}],
                "response_format": {"type": "audio"},
                "generation_config": {"speech_config": [{"voice": voice}]}}
        try:
            audio = _find_audio(_post(f"{API}/interactions", body))
            if audio:
                return audio
            raise RuntimeError("no audio in answer")
        except Quota:
            raise
        except RuntimeError as e:
            print(f"  new speech API did not work ({e}); switching to the older one", flush=True)
            _mode["api"] = "generate"
    body = {"contents": [{"parts": [{"text": f"Say this as {style}: {text}"}]}],
            "generationConfig": {"responseModalities": ["AUDIO"], "speechConfig": {
                "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}}}}
    audio = _find_audio(_post(f"{API}/models/{OLD_MODEL}:generateContent", body))
    if not audio:
        raise RuntimeError("no audio in answer")
    return audio


def to_mp3(audio, dest):
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
        f.write(audio)
        src = f.name
    fmt = [] if audio[:4] == b"RIFF" else ["-f", "s16le", "-ar", "24000", "-ac", "1"]
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *fmt, "-i", src,
                        "-ac", "1", "-ar", "24000", "-b:a", "40k", str(dest)], check=True)
    finally:
        os.unlink(src)


def write_index():
    index = {d.name: sorted(p.stem for p in d.glob("*.mp3")) for d in sorted(VOICE.iterdir()) if d.is_dir()} \
        if VOICE.exists() else {}
    VOICE.mkdir(exist_ok=True)
    (VOICE / "index.json").write_text(json.dumps(index, separators=(",", ":")) + "\n")
    return sum(len(v) for v in index.values())


def main():
    bundle = build_content.build()
    if build_content.errors:
        print("Lessons have problems; fix them first (python3 tools/build_content.py).")
        return 1
    jobs, wanted = [], {}
    for tutor in bundle.get("tutors", []):
        keep = wanted.setdefault(tutor["id"], set())
        for lang, text in lines_for(bundle, tutor):
            cid = clip_id(tutor["voice"], lang, text)
            keep.add(cid)
            dest = VOICE / tutor["id"] / f"{cid}.mp3"
            if not dest.exists():
                jobs.append((tutor, lang, text, dest))
    # Remove sound files for lines that no longer exist.
    removed = 0
    for tid, keep in wanted.items():
        for p in (VOICE / tid).glob("*.mp3") if (VOICE / tid).exists() else []:
            if p.stem not in keep:
                p.unlink()
                removed += 1
    total = sum(len(v) for v in wanted.values())
    print(f"{total} lines in all, {len(jobs)} still need a voice, {removed} old files removed.", flush=True)
    if "--count" in sys.argv or not jobs:
        write_index()
        return 0
    if not os.environ.get("GEMINI_API_KEY"):
        print("GEMINI_API_KEY is not set, so no voices were made. "
              "Add it under the repository's Settings > Secrets and variables > Actions.")
        write_index()
        return 0

    start, made, failed, quota_hits = time.time(), 0, 0, 0
    jobs = jobs[:MAX_NEW]

    def work(job):
        tutor, lang, text, dest = job
        if time.time() - start > MAX_SECONDS:
            return "skip"
        last = "fail"
        for attempt in range(4):
            try:
                audio = synth(spoken(text, lang), tutor["voice"], tutor.get("style", "a friendly teacher"))
                dest.parent.mkdir(parents=True, exist_ok=True)
                to_mp3(audio, dest)
                return "ok"
            except Quota:
                last = "quota"
                time.sleep(20 * (attempt + 1))
            except Exception as e:  # noqa: BLE001
                last = "fail"
                if attempt == 3:
                    print(f"  failed: {tutor['id']} {lang} {text[:40]!r}: {e}", flush=True)
                time.sleep(3)
        return last

    with cf.ThreadPoolExecutor(THREADS) as pool:
        for n, result in enumerate(pool.map(work, jobs), 1):
            made += result == "ok"
            failed += result == "fail"
            quota_hits += result == "quota"
            if n % 25 == 0:
                print(f"  {n}/{len(jobs)} done, {made} made", flush=True)
            if (quota_hits >= 6 or (failed >= 12 and made == 0)) and start:
                print("Stopping early: the speech service is refusing requests "
                      "(daily limit reached, or the key cannot use this model).", flush=True)
                start = 0  # makes the remaining jobs skip
    count = write_index()
    print(f"Made {made} new voice files ({failed} failed). {count} files in voice/ now. "
          f"{max(0, total - count)} still to do on the next run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
