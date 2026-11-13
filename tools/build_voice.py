#!/usr/bin/env python3
"""Makes the tutors' voices.

Every line a tutor can say (lesson text, hints, explanations, greetings) is
turned into a small sound file once, and saved in voice/<tutor>/. The app
downloads these files, so no key is ever inside the app and nothing a child
does is sent to a voice service.

Which voice a tutor uses is set in content/_app/tutors.json ("voice"):
  {"en": "en-IN-NeerjaExpressiveNeural", "ml": "ml-IN-SobhanaNeural"}
      Microsoft Edge voices (free, no key; fine for testing and demos, not
      licensed for a paid launch)
  "Sulafat"   a Gemini voice (needs the GEMINI_API_KEY secret)
  "" or none  no voice files; the phone's own voice reads the lines
Run again any time: it only makes the files that are missing.

    python3 tools/build_voice.py            # make missing files
    python3 tools/build_voice.py --count    # just say how many are missing
"""
import base64
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
THREADS = int(os.environ.get("SCOL_VOICE_THREADS", "4"))
LANGS = ("en", "ml")
EMOJI = re.compile("[\U0001F000-\U0001FFFF←-⇿☀-➿⬀-⯿️]")
SPOKEN = {
    "en": [("×", " times "), ("=", " equals "), ("+", " plus "), ("−", " minus "),
           (r"\bcm\b", "centimetres"), (r"\bkm\b", "kilometres"), (r"(?<=\d) m\b", " metres")],
    "ml": [("×", " ഗുണം "), ("=", " സമം "), ("+", " പ്ലസ് "), ("−", " മൈനസ് "),
           ("സെ.മീ", "സെന്റിമീറ്റർ"), ("കി.മീ", "കിലോമീറ്റർ")],
}


def voice_for(tutor, lang):
    v = tutor.get("voice") or ""
    return v.get(lang, "") if isinstance(v, dict) else v


def is_edge(voice):
    return voice.endswith("Neural")


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


def edge_voices_ok(voices):
    """Swap any Edge voice that no longer exists for a close one, so a run never silently fails."""
    import asyncio
    import edge_tts
    have = {v["ShortName"] for v in asyncio.run(edge_tts.list_voices())}
    out = {}
    for v in voices:
        if v in have:
            out[v] = v
            continue
        prefix = v.split("-")[0] + "-" + v.split("-")[1] + "-"
        alt = sorted(x for x in have if x.startswith(prefix))
        if not alt:
            sys.exit(f"Edge has no voice for {prefix[:-1]}")
        print(f"  Edge voice {v} not found; using {alt[0]}")
        out[v] = alt[0]
    return out


def make_edge(jobs, deadline):
    import asyncio
    import edge_tts
    real = edge_voices_ok({j[4] for j in jobs})
    sem = asyncio.Semaphore(THREADS)
    done = {"ok": 0, "fail": 0}

    async def one(tutor, lang, text, dest, voice):
        if time.time() > deadline:
            return
        async with sem:
            for attempt in range(3):
                try:
                    tmp = dest.with_suffix(".part")
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    await edge_tts.Communicate(spoken(text, lang), real[voice],
                                               rate=tutor.get("rate", "-6%"), pitch=tutor.get("pitch", "+0Hz")).save(str(tmp))
                    if tmp.stat().st_size < 1500:
                        raise RuntimeError("audio too short")
                    tmp.rename(dest)
                    done["ok"] += 1
                    if done["ok"] % 50 == 0:
                        print(f"  {done['ok']} made", flush=True)
                    return
                except Exception as e:  # noqa: BLE001
                    if attempt == 2:
                        done["fail"] += 1
                        print(f"  failed: {lang} {text[:40]!r}: {e}", flush=True)
                    await asyncio.sleep(2 + attempt * 3)

    async def run():
        await asyncio.gather(*(one(*j) for j in jobs))

    asyncio.run(run())
    return done["ok"], done["fail"]


def make_gemini(jobs, deadline):
    if not os.environ.get("GEMINI_API_KEY"):
        print("GEMINI_API_KEY is not set, so no Gemini voices were made.")
        return 0, 0
    made = failed = quota_hits = 0
    for tutor, lang, text, dest, voice in jobs:
        if time.time() > deadline or quota_hits >= 3:
            break
        try:
            audio = synth(spoken(text, lang), voice, tutor.get("style", "a friendly teacher"))
            dest.parent.mkdir(parents=True, exist_ok=True)
            to_mp3(audio, dest)
            made += 1
        except Quota:
            quota_hits += 1
            time.sleep(20)
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"  failed: {lang} {text[:40]!r}: {e}", flush=True)
    if quota_hits >= 3:
        print("Stopping early: Gemini's daily limit is reached.")
    return made, failed


def main():
    bundle = build_content.build()
    if build_content.errors:
        print("Lessons have problems; fix them first (python3 tools/build_content.py).")
        return 1
    jobs, wanted = [], {}
    for tutor in bundle.get("tutors", []):
        keep = wanted.setdefault(tutor["id"], set())
        for lang, text in lines_for(bundle, tutor):
            voice = voice_for(tutor, lang)
            if not voice:
                continue
            cid = clip_id(voice, lang, text)
            keep.add(cid)
            dest = VOICE / tutor["id"] / f"{cid}.mp3"
            if not dest.exists():
                jobs.append((tutor, lang, text, dest, voice))
    # Remove sound files for lines (or tutors) that no longer have a voice.
    removed = 0
    if VOICE.exists():
        for d in VOICE.iterdir():
            if d.is_dir():
                for f in d.glob("*.mp3"):
                    if f.stem not in wanted.get(d.name, set()):
                        f.unlink()
                        removed += 1
                if not any(d.iterdir()):
                    d.rmdir()
    total = sum(len(v) for v in wanted.values())
    print(f"{total} lines have a voice, {len(jobs)} still to make, {removed} old files removed.", flush=True)
    if "--count" in sys.argv or not jobs:
        write_index()
        return 0
    jobs = jobs[:MAX_NEW]
    deadline = time.time() + MAX_SECONDS
    edge = [j for j in jobs if is_edge(j[4])]
    made, failed = make_edge(edge, deadline) if edge else (0, 0)
    m2, f2 = make_gemini([j for j in jobs if not is_edge(j[4])], deadline)
    count = write_index()
    print(f"Made {made + m2} new voice files ({failed + f2} failed). {count} files in voice/ now. "
          f"{max(0, total - count)} still to do.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
