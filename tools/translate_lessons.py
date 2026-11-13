#!/usr/bin/env python3
"""Adds Malayalam lines to lessons that only have English, using an AI
(Gemini, key from the GEMINI_API_KEY secret). Every English line stays exactly
as it was; the AI may only add 'ml' lines. A file is changed only if the result
passes those checks, so a bad answer is skipped, never saved.
AI translations should be read by a Malayalam teacher before a paid launch.
Usage: python3 tools/translate_lessons.py [folder ...]   (default: every lesson)"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEY = os.environ.get("GEMINI_API_KEY", "").strip()
BASE = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
MODELS = ["gemini-3.5-flash", "gemini-flash-lite-latest", "gemini-flash-latest"]
ML_KEYS = {"ml", "title.ml", "objective.ml", "concept.name.ml", "hint.ml", "explain.ml", "options.ml"}
EN_FOR = {"en": "ml", "title": "title.ml", "concept.name": "concept.name.ml", "hint.en": "hint.ml",
          "explain.en": "explain.ml", "options": "options.ml"}

RULES = """You translate lessons of a learning app for Class 3 children in Kerala into Malayalam.
Return the SAME file with Malayalam lines ADDED. Rules:
- Keep every existing line exactly as it is, in the same order. Do not change, drop or reorder any line.
- Directly after each line starting with "en:" add a line "ml: <Malayalam>".
- After "title:" (or the first "# " heading) add "title.ml:", after "concept.name:" add "concept.name.ml:",
  after "hint.en:" add "hint.ml:", after "explain.en:" add "explain.ml:".
- After an "options:" line of a choice question whose options are words, add "options.ml:" with the same number of
  choices in the same order, separated by " | ". Skip options.ml if the options are only numbers.
- Write simple, natural Malayalam the way the Kerala SCERT Class 3 Malayalam-medium textbook would say it, for a
  7-year-old. Keep Kerala plant, food and place names in their usual Malayalam form (cheera = ചീര, chemparathi = ചെമ്പരത്തി).
- Keep numbers as digits. Keep emojis out of ml lines unless the English line has them.
- Output only the file, no explanations, no code fences."""


def ask(text):
    for model in MODELS:
        body = {"model": model, "temperature": 0.2, "reasoning_effort": "low",
                "messages": [{"role": "system", "content": RULES}, {"role": "user", "content": text}]}
        for attempt in range(3):
            req = urllib.request.Request(BASE, data=json.dumps(body).encode(),
                                         headers={"authorization": f"Bearer {KEY}", "content-type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    out = json.load(r)["choices"][0]["message"]["content"] or ""
                return re.sub(r"^```\w*\n|\n```\s*$", "", out.strip()) + "\n"
            except urllib.error.HTTPError as e:
                print(f"    {model}: HTTP {e.code}")
                if e.code in (404, 400, 503):
                    break  # busy or not available: try the next model now
                time.sleep(10 * (attempt + 1))
            except Exception as e:  # noqa: BLE001
                print(f"    {model}: {e}")
                time.sleep(5)
    return None


def key_of(line):
    m = re.match(r"^([a-z.]+):", line.strip())
    return m.group(1) if m else None


def check(original, result):
    """The result must be the original plus Malayalam lines only."""
    old = [l for l in original.splitlines() if l.strip()]
    new = [l for l in result.splitlines() if l.strip()]
    i = 0
    added = []
    for line in new:
        if i < len(old) and line.rstrip() == old[i].rstrip():
            i += 1
        elif key_of(line) in ML_KEYS and re.search(r"[ഀ-ൿ\d]", line):
            added.append(line)
        else:
            return f"unexpected line: {line[:80]}"
    if i != len(old):
        return f"lost a line: {old[i][:80]}"
    need = sum(1 for l in old if key_of(l) == "en")
    got = sum(1 for l in added if key_of(l) == "ml")
    return None if got >= need else f"only {got} of {need} lines translated"


def main():
    if not KEY:
        sys.exit("Add the GEMINI_API_KEY secret.")
    roots = [Path(a) for a in sys.argv[1:]] or [Path("content")]
    files = sorted(p for r in roots for p in r.rglob("*.md") if not p.name.startswith("_"))
    todo = [p for p in files if re.search(r"^en:", p.read_text(), re.M) and not re.search(r"^ml:", p.read_text(), re.M)]
    print(f"{len(todo)} lessons need Malayalam")
    done = 0
    for p in todo:
        text = p.read_text()
        for attempt in range(2):
            out = ask(text)
            problem = "no answer" if out is None else check(text, out)
            if not problem:
                break
            print(f"  {p}: {problem} (try {attempt + 1})")
        if problem:
            continue
        p.write_text(out)
        if subprocess.run([sys.executable, "tools/build_content.py"], capture_output=True).returncode != 0:
            print(f"  {p}: lesson check failed, kept English only")
            p.write_text(text)
            continue
        done += 1
        print(f"  {p}: added Malayalam", flush=True)
    print(f"Done: {done} of {len(todo)}")


main()
