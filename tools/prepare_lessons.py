#!/usr/bin/env python3
"""Gets every lesson ready on the Scol server before any child opens it, so the app
never waits for the AI:

1. asks the tutor brain to teach each lesson (each tutor, English and Malayalam),
   which the server keeps (brain_teach table);
2. asks for every line a child can hear in each character's own Gemini voice,
   which the server keeps (the public "voices" storage bucket).

What is already kept is answered at once and costs nothing, so this can run every
day: each run does a little more until everything is ready. The requests are built
exactly as the app builds them (app/lib/brain.dart, app/lib/voice.dart), so the
app finds the same kept answers.

    python3 tools/prepare_lessons.py            # needs SUPABASE_ACCESS_TOKEN (for the pre-warm pass)
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_content  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MAX_TEACH = int(os.environ.get("SCOL_PREPARE_TEACH", "200"))
MAX_SPEAK = int(os.environ.get("SCOL_PREPARE_SPEAK", "900"))
MAX_SECONDS = int(os.environ.get("SCOL_PREPARE_SECONDS", "2700"))
LANGS = ("en", "ml")
EMOJI = re.compile("[\U0001F000-\U0001FFFF☀-➿️]")
DEFAULT_STYLE = "a warm, friendly teacher talking to a young child"


def pick(value, lang):
    """Like pick() in app/lib/content.dart, for single lines."""
    if isinstance(value, str):
        return value
    if isinstance(value, dict) and value:
        v = value.get(lang, value.get("en", next(iter(value.values()))))
        return v if isinstance(v, str) else ""
    return ""


def pick_all(value, lang):
    if isinstance(value, str):
        return [value] if value else []
    if isinstance(value, list):
        return [str(x) for x in value]
    if isinstance(value, dict) and value:
        v = value.get(lang, value.get("en", next(iter(value.values()))))
        if isinstance(v, list):
            return [str(x) for x in v]
        return [v] if v else []
    return []


def spoken(text, lang):
    """spokenText() in app/lib/voice.dart."""
    ml = lang == "ml"
    out = EMOJI.sub(" ", text)
    out = (out.replace("×", " ഗുണം " if ml else " times ").replace("=", " സമം " if ml else " equals ")
           .replace("+", " പ്ലസ് " if ml else " plus ").replace("−", " മൈനസ് " if ml else " minus "))
    if ml:
        out = out.replace("സെ.മീ", "സെന്റിമീറ്റർ").replace("കി.മീ", "കിലോമീറ്റർ")
    else:
        out = re.sub(r"\bcm\b", "centimetres", out)
        out = re.sub(r"\bkm\b", "kilometres", out)
    return re.sub(r"\s+", " ", out).strip()


def sentence_pieces(text, limit=220):
    """sentencePieces() in app/lib/voice.dart."""
    parts = re.split(r"(?<=[.!?।])\s+|(?<=[.!?])(?=[A-Zഀ-ൿ])", text)
    out, cur = [], ""
    for raw in parts:
        p = raw.strip()
        if not p:
            continue
        if not cur:
            cur = p
        elif len(cur) + len(p) + 1 <= limit:
            cur = f"{cur} {p}"
        else:
            out.append(cur)
            cur = p
    if cur:
        out.append(cur)
    fine = []
    for o in out:
        if len(o) <= limit * 1.6:
            fine.append(o)
            continue
        piece = ""
        for c in re.split(r"(?<=,)\s+", o):
            if piece and len(piece) + len(c) > limit:
                fine.append(piece)
                piece = c
            else:
                piece = f"{piece} {c}" if piece else c
        if piece:
            fine.append(piece)
    return fine


def pieces(text):
    """_pieces() in app/lib/voice.dart."""
    return [text] if len(text) <= 260 else sentence_pieces(text)


def lang_of(text):
    return "ml" if re.search(r"[ഀ-ൿ]", text) else "en"


def teach_request(lesson, lang, tutor, tone="normal", variant=0):
    """teachRequest() in app/lib/brain.dart."""
    steps = []
    for s in lesson["steps"]:
        ask = s.get("t") == "ask"
        step = {"t": "ask" if ask else "say", "text": pick(s.get("text"), lang)}
        v = s.get("visual")
        if v:
            step["visual"] = f"{v['kind']} {' '.join(str(a) for a in v.get('args', []))}".strip()
        if s.get("label"):
            step["label"] = s["label"]
        if ask:
            step["form"] = s.get("form", "")
            step["answer"] = s.get("answer", "")
            if s.get("options"):
                step["options"] = s["options"]
        steps.append(step)
    return {"mode": "teach", "variant": variant, "lang": lang, "tutor": pick(tutor["name"], "en"),
            "about": pick(tutor.get("about"), "en"), "tone": tone, "lesson": pick(lesson["title"], "en"),
            "objective": pick(lesson.get("objective"), "en"), "steps": steps}


class Server:
    def __init__(self, url, public_key, token):
        self.url, self.public_key, self.token = url, public_key, token
        self.calls = {"teach": 0, "speak": 0}
        self.kept = {"teach": 0, "speak": 0}

    def post(self, body, timeout=120):
        data = json.dumps({**body, "device": "prepare-lessons-01"}).encode()
        req = urllib.request.Request(self.url, data=data, headers={
            "content-type": "application/json", "apikey": self.public_key, "x-scol-prewarm": self.token})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    return json.load(r)
            except urllib.error.HTTPError as e:
                if e.code in (429, 503) and attempt < 2:
                    time.sleep(20 * (attempt + 1))
                    continue
                return {"error": f"HTTP {e.code} {e.read().decode('utf-8', 'replace')[:160]}"}
            except Exception as e:  # noqa: BLE001
                if attempt < 2:
                    time.sleep(5)
                    continue
                return {"error": str(e)}
        return {"error": "gave up"}


def main():
    bundle = build_content.build()
    if build_content.errors:
        print("Lessons have problems; fix them first.")
        return 1
    brain = bundle["brain"]
    token = hashlib.sha256(("scol-prewarm|" + os.environ.get("SUPABASE_ACCESS_TOKEN", "")).encode()).hexdigest()[:40]
    if not os.environ.get("SUPABASE_ACCESS_TOKEN"):
        print("SUPABASE_ACCESS_TOKEN is not set: the server would hold this to a phone's daily limits. Stopping.")
        return 0
    server = Server(brain["url"], brain.get("public_key", ""), token)
    deadline = time.time() + MAX_SECONDS
    tutors = bundle["tutors"]
    tutors = sorted(tutors, key=lambda t: t["id"] != "minnu")  # the default tutor first
    lessons = [l for b in bundle["boards"] for c in b["classes"] for s in c["subjects"]
               for ch in s["chapters"] for l in ch["lessons"]]
    phrases = bundle.get("phrases", {})
    print(f"{len(lessons)} lessons, {len(tutors)} tutors, languages {', '.join(LANGS)}", flush=True)

    def speak(tutor, text):
        if server.calls["speak"] >= MAX_SPEAK or time.time() > deadline:
            return False
        for piece in pieces(text):
            if not piece.strip() or "{name}" in piece:
                continue
            lang = lang_of(piece)
            out = server.post({"mode": "speak", "text": spoken(piece, lang), "lang": lang,
                               "voice": tutor.get("gemini_voice", ""), "style": tutor.get("style") or DEFAULT_STYLE})
            if out.get("by") == "cache":
                server.kept["speak"] += 1
            else:
                server.calls["speak"] += 1
                if out.get("error"):
                    print(f"  voice failed ({tutor['id']}): {out['error']}", flush=True)
                    if "voice_unavailable" in out["error"] or "daily_limit" in out["error"]:
                        return False
        return True

    for tutor in tutors:
        if not tutor.get("gemini_voice"):
            continue
        for lang in LANGS:
            shared = [*pick_all(tutor.get("hello"), lang), *pick_all(tutor.get("praise"), lang),
                      *pick_all(tutor.get("oops"), lang), *pick_all(tutor.get("cheer"), lang)]
            for v in phrases.values():
                shared += pick_all(v, lang)
            for line in shared:
                if not speak(tutor, line):
                    break
            for lesson in lessons:
                if time.time() > deadline:
                    break
                says = []
                if server.calls["teach"] < MAX_TEACH:
                    out = server.post(teach_request(lesson, lang, tutor), timeout=180)
                    if out.get("by") == "cache":
                        server.kept["teach"] += 1
                    else:
                        server.calls["teach"] += 1
                    if out.get("error"):
                        print(f"  teaching failed ({tutor['id']}, {lang}, {lesson['id']}): {out['error']}", flush=True)
                    says = [s.get("say", "") if isinstance(s, dict) else str(s) for s in out.get("steps", [])]
                lines = [*says]
                for s in lesson["steps"]:
                    lines += [pick(s.get("text"), lang), pick(s.get("hint"), lang), pick(s.get("explain"), lang)]
                for a in lesson.get("alts", {}).values():
                    lines.append(pick(a.get("text"), lang))
                for line in lines:
                    if line and not speak(tutor, line):
                        break
        print(f"- {tutor['id']}: teaching made {server.calls['teach']} (kept {server.kept['teach']}), "
              f"voices made {server.calls['speak']} (kept {server.kept['speak']})", flush=True)
    print(f"Done. New teaching: {server.calls['teach']}, new voice lines: {server.calls['speak']}; "
          f"already ready: {server.kept['teach']} teaching, {server.kept['speak']} voice lines.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
