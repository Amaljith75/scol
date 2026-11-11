#!/usr/bin/env python3
"""Turns everything in content/ into one file the app reads.

    python3 tools/build_content.py          # check + build
    python3 tools/build_content.py --check  # check only

It never guesses: if a lesson file has a mistake, it prints the file and
line and stops, so broken lessons never reach children.
"""
import hashlib
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
OUT = ROOT / "app" / "assets" / "content" / "bundle.json"

LANGS = ("en", "ml")
VISUALS = {  # kind -> (min args, max args)
    "groups": (3, 3),      # groups <how many groups> <items in each> <emoji>
    "count": (2, 2),       # count <how many> <emoji>
    "array": (3, 3),       # array <rows> <in each row> <emoji>
    "numberline": (2, 3),  # numberline <from> <to> [marked number]
    "shapes": (1, 8),      # shapes circle triangle rectangle square
    "sticks": (1, 1),      # sticks 7
    "place": (3, 3),       # place <hundreds> <tens> <ones>   (an abacus)
    "notes": (1, 12),      # notes 100 100 10 1               (money)
    "ruler": (1, 2),       # ruler <length in cm> [emoji]
    "pattern": (2, 10),    # pattern 10 20 30 ?
    "split": (3, 3),       # split 1000 300 ?                 (a number and its two parts)
    "steps": (1, 99),      # steps 200 + 100 = 300 / 30 + 40 = 70
    "text": (1, 99),       # text 3 x 4 = 12
    "emoji": (1, 99),      # emoji 🍎 🍌
    "image": (1, 1),       # image picture.png  (file in the chapter's images/ folder)
}
SHAPES = ("circle", "triangle", "rectangle", "square")
FORMS = ("choice", "number", "think")
KEY = re.compile(r"^([a-z][a-z_]*(?:\.[a-z]+)*)(?: ([^:]{1,40}))?:\s*(.*)$")
errors = []


def err(path, line, msg):
    where = str(path.relative_to(ROOT)) + (f" (line {line})" if line else "")
    errors.append(f"  {where}: {msg}")


def load_json(path, required=()):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        err(path, 0, f"not valid JSON - {e}")
        return {}
    for k in required:
        if isinstance(data, dict) and k not in data:
            err(path, 0, f'missing "{k}"')
    return data


def loc(value):
    """Accept "text" or {"en": .., "ml": ..}; always return a dict."""
    if isinstance(value, str):
        return {"en": value}
    return {k: v for k, v in (value or {}).items() if k in LANGS and v}


def parse_visual(spec, path, line, chapter_dir):
    parts = spec.split()
    if not parts:
        return None
    kind, args = parts[0], parts[1:]
    if kind not in VISUALS:
        err(path, line, f'unknown visual "{kind}". Use one of: {", ".join(VISUALS)}')
        return None
    lo, hi = VISUALS[kind]
    if not lo <= len(args) <= hi:
        err(path, line, f'visual "{kind}" needs {lo}{"" if lo == hi else "-" + str(hi)} values')
        return None
    def ints(values, lo_v=0, hi_v=9999):
        ok = all(re.fullmatch(r"-?\d+", v) and lo_v <= int(v) <= hi_v for v in values)
        if not ok:
            err(path, line, f'visual "{kind}" needs whole numbers between {lo_v} and {hi_v}')
        return ok

    if kind in ("groups", "array"):
        if not ints(args[:2], 1, 60):
            return None
        if int(args[0]) * int(args[1]) > 60:
            err(path, line, "too many objects to show (max 60)")
    elif kind == "count":
        if not ints(args[:1], 1, 60):
            return None
    elif kind == "numberline":
        if not ints(args):
            return None
    elif kind == "sticks":
        if not ints(args, 1, 30):
            return None
    elif kind == "place":
        if not ints(args, 0, 9):
            return None
    elif kind == "notes":
        if not ints(args, 1, 2000):
            return None
    elif kind == "ruler":
        if not ints(args[:1], 1, 15):
            return None
    elif kind == "shapes":
        bad = [x for x in args if x not in SHAPES]
        if bad:
            err(path, line, f'unknown shape "{bad[0]}". Use: {", ".join(SHAPES)}')
            return None
    elif kind == "steps":
        args = [x.strip() for x in " ".join(args).split(" / ") if x.strip()]
        if len(args) > 5:
            err(path, line, "steps: at most 5 lines")
    if kind == "image":
        img = chapter_dir / "images" / args[0]
        if not img.is_file():
            err(path, line, f"image not found: {img.relative_to(ROOT)}")
        args = [str(img.relative_to(ROOT)).replace("\\", "/")]
    if kind == "text":
        args = [" ".join(args)]
    return {"kind": kind, "args": args}


class Block:
    def __init__(self, kind, line):
        self.kind, self.line, self.fields, self.lines = kind, line, {}, {}


def read_blocks(path, known_keys):
    """Split a lesson file into a header block and '## say' / '## ask' blocks."""
    blocks = [Block("header", 1)]
    last = None
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.rstrip()
        if line.startswith("## "):
            blocks.append(Block(line[3:].strip().lower(), n))
            last = None
            continue
        if line.startswith("# ") and blocks[-1].kind == "header":
            blocks[-1].fields["title.en"] = line[2:].strip()
            continue
        if not line.strip():
            continue
        m = KEY.match(line.strip())
        if m and m.group(1) in known_keys:
            key = m.group(1) + (" " + m.group(2).strip() if m.group(2) else "")
            blocks[-1].fields[key] = m.group(3).strip()
            blocks[-1].lines[key] = n
            last = key
        elif last:
            blocks[-1].fields[last] += " " + line.strip()
        else:
            err(path, n, f'did not understand this line: "{line.strip()[:50]}"')
    return blocks


def text_of(fields, name, short=False):
    out = {}
    for lang in LANGS:
        v = fields.get(f"{name}.{lang}") or (fields.get(lang) if short else None)
        if v:
            out[lang] = v
    if "en" not in out and fields.get(name):
        out["en"] = fields[name]
    return out


HEADER_KEYS = {"title", "title.en", "title.ml", "objective", "objective.en", "objective.ml",
               "concept", "concept.name", "concept.name.en", "concept.name.ml", "minutes"}
STEP_KEYS = {"en", "ml", "visual", "label", "form", "options", "options.ml", "answer",
             "hint", "hint.en", "hint.ml", "explain", "explain.en", "explain.ml",
             "concept", "concept.name", "level", "mistake"}


def make_ask(f, lines, path, line, scope, default_concept, chapter_dir, text):
    form = f.get("form", "choice" if f.get("options") else "number")
    if form not in FORMS:
        err(path, line, f'form must be one of: {", ".join(FORMS)}')
    answer = f.get("answer", "").strip()
    options = [o.strip() for o in f.get("options", "").split("|") if o.strip()]
    if not text:
        err(path, line, "question has no text (add an 'en:' or 'ml:' line)")
    if not answer:
        err(path, line, "question has no 'answer:' line")
    if form == "choice":
        if len(options) < 2:
            err(path, line, "choice question needs 'options: a | b | c'")
        elif answer not in options:
            err(path, line, f'answer "{answer}" is not one of the options')
    if form == "number" and answer and not re.fullmatch(r"\d{1,6}", answer):
        err(path, line, "number question needs a whole-number answer")
    concept = f.get("concept", default_concept)
    if not concept:
        err(path, line, "question has no concept (add 'concept:' at the top of the lesson)")
    mistakes = {k[len("mistake "):]: v for k, v in f.items() if k.startswith("mistake ")}
    step = {"t": "ask", "form": form, "text": text, "answer": answer,
            "concept": f"{scope}#{concept}", "level": int(f.get("level", "1") or 1)}
    if options:
        step["options"] = options
        ml = [o.strip() for o in f.get("options.ml", "").split("|") if o.strip()]
        if ml and len(ml) != len(options):
            err(path, line, "'options.ml' must have the same number of choices as 'options'")
        elif ml:
            step["optionsMl"] = ml
    for name in ("hint", "explain"):
        t = text_of(f, name)
        if t:
            step[name] = t
    if mistakes:
        step["mistakes"] = mistakes
    if f.get("visual"):
        v = parse_visual(f["visual"], path, lines.get("visual", line), chapter_dir)
        if v:
            step["visual"] = v
    return step, concept


def parse_lesson(path, scope, chapter_dir):
    blocks = read_blocks(path, HEADER_KEYS | STEP_KEYS)
    head = blocks[0].fields
    title = text_of(head, "title")
    if not title:
        err(path, 1, "lesson needs a title: first line should be '# Lesson name'")
    default_concept = head.get("concept", "")
    concepts = {}
    if default_concept:
        concepts[f"{scope}#{default_concept}"] = text_of(head, "concept.name") or title
    steps = []
    for b in blocks[1:]:
        f = b.fields
        text = text_of(f, "text", short=True)
        if b.kind == "say":
            if not text:
                err(path, b.line, "'## say' needs an 'en:' or 'ml:' line")
            step = {"t": "say", "text": text}
            if f.get("label"):
                step["label"] = f["label"]
            if f.get("visual"):
                v = parse_visual(f["visual"], path, b.lines.get("visual", b.line), chapter_dir)
                if v:
                    step["visual"] = v
            steps.append(step)
        elif b.kind == "ask":
            step, concept = make_ask(f, b.lines, path, b.line, scope, default_concept, chapter_dir, text)
            key = step["concept"]
            concepts.setdefault(key, text_of(f, "concept.name") or {"en": concept.replace("-", " ").capitalize()})
            steps.append(step)
        else:
            err(path, b.line, f'unknown block "## {b.kind}". Use "## say" or "## ask"')
    if not steps:
        err(path, 1, "lesson has no steps")
    lesson = {"title": title, "steps": steps, "minutes": int(head.get("minutes", "5") or 5)}
    obj = text_of(head, "objective")
    if obj:
        lesson["objective"] = obj
    return lesson, concepts


def parse_notes(path, scope, chapter_dir, chapter_title):
    """notes.md: plain notes. Every '## Heading' becomes a small tutor-led lesson."""
    lang, concept = "en", ""
    lessons, concepts = [], {}
    cur = None  # current lesson
    para, pending = [], None  # pending question
    visual = None

    def start(title):
        nonlocal cur
        cur = {"title": {lang: title}, "steps": [], "minutes": 4}
        lessons.append(cur)

    def flush_para(label=None):
        nonlocal para, visual
        if para:
            if cur is None:
                start(next(iter(chapter_title.values()), "Notes"))
            step = {"t": "say", "text": {lang: " ".join(para)}}
            if label:
                step["label"] = label
            if visual:
                step["visual"] = visual
                visual = None
            cur["steps"].append(step)
            para = []

    def flush_q(n):
        nonlocal pending, visual
        if not pending:
            return
        q = pending
        pending = None
        if "answer" not in q:
            err(path, q["line"], "this 'Q:' has no 'A:' line after it")
            return
        c = concept or re.sub(r"[^a-z0-9]+", "-", next(iter(cur["title"].values())).lower()).strip("-") or "notes"
        f = {"answer": q["answer"], "options": q.get("options", ""), "concept": c}
        if "hint" in q:
            f["hint." + lang] = q["hint"]
        if not q.get("options") and not re.fullmatch(r"\d{1,6}", q["answer"]):
            f["form"] = "think"
        step, _ = make_ask(f, {}, path, q["line"], scope, c, chapter_dir, {lang: q["text"]})
        if visual:
            step["visual"] = visual
            visual = None
        concepts.setdefault(step["concept"], dict(cur["title"]))
        cur["steps"].append(step)

    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        low = line.lower()
        if cur is None and not para and low.startswith("lang:"):
            lang = line[5:].strip() if line[5:].strip() in LANGS else "en"
            continue
        if low.startswith("concept:") and not pending:
            flush_para()
            concept = line[8:].strip()
            continue
        if line.startswith("## "):
            flush_para()
            flush_q(n)
            start(line[3:].strip())
            concept = ""
            continue
        if line.startswith("# "):
            continue
        if not line:
            flush_para()
            continue
        if low.startswith("q:"):
            flush_para()
            flush_q(n)
            if cur is None:
                start(next(iter(chapter_title.values()), "Notes"))
            pending = {"text": line[2:].strip(), "line": n}
        elif low.startswith("a:") and pending:
            pending["answer"] = line[2:].strip()
        elif low.startswith("options:") and pending:
            pending["options"] = line[8:].strip()
        elif low.startswith("hint:") and pending:
            pending["hint"] = line[5:].strip()
        elif low.startswith("visual:"):
            flush_para()
            flush_q(n)
            visual = parse_visual(line[7:].strip(), path, n, chapter_dir)
            # A picture belongs to the paragraph just above it, if there is one.
            if visual and cur and cur["steps"] and cur["steps"][-1]["t"] == "say" \
                    and "visual" not in cur["steps"][-1]:
                cur["steps"][-1]["visual"] = visual
                visual = None
        elif low.startswith("example:"):
            flush_para()
            flush_q(n)
            para = [line[8:].strip()]
            flush_para("example")
        else:
            flush_q(n)
            para.append(line)
    flush_para()
    flush_q(0)
    return [l for l in lessons if l["steps"]], concepts


def ordered_dirs(path):
    return sorted(p for p in path.iterdir() if p.is_dir() and not p.name.startswith(("_", ".")))


def build():
    boards, concepts = [], {}
    for bdir in ordered_dirs(CONTENT):
        meta = load_json(bdir / "board.json", ("name",)) if (bdir / "board.json").exists() else None
        if meta is None:
            err(bdir, 0, "folder has no board.json")
            continue
        board = {"id": bdir.name, "name": loc(meta.get("name")), "order": meta.get("order", 99), "classes": []}
        for cdir in ordered_dirs(bdir):
            m = re.fullmatch(r"class-(\d+)", cdir.name)
            if not m:
                err(cdir, 0, 'class folders must be named like "class-3"')
                continue
            klass = {"id": cdir.name, "number": int(m.group(1)), "subjects": []}
            for sdir in ordered_dirs(cdir):
                if not (sdir / "subject.json").exists():
                    err(sdir, 0, "folder has no subject.json")
                    continue
                smeta = load_json(sdir / "subject.json", ("name",))
                scope = f"{bdir.name}/{cdir.name}/{sdir.name}"
                subject = {"id": scope, "key": sdir.name, "name": loc(smeta.get("name")),
                           "icon": smeta.get("icon", "📘"), "color": smeta.get("color", "#5B6CFF"),
                           "order": smeta.get("order", 99), "chapters": []}
                for chdir in ordered_dirs(sdir):
                    if not (chdir / "chapter.json").exists():
                        err(chdir, 0, "folder has no chapter.json")
                        continue
                    cmeta = load_json(chdir / "chapter.json", ("title",))
                    ctitle = loc(cmeta.get("title"))
                    chapter = {"id": f"{scope}/{chdir.name}", "title": ctitle,
                               "verified": bool(cmeta.get("verified", False)),
                               "source": cmeta.get("source", ""),
                               "objectives": [loc(o) for o in cmeta.get("objectives", [])],
                               "lessons": []}
                    files = sorted(p for p in chdir.glob("*.md") if p.name.lower() not in ("readme.md",))
                    for f in files:
                        if f.name.lower() == "notes.md":
                            ls, cs = parse_notes(f, scope, chdir, ctitle)
                            for i, l in enumerate(ls, 1):
                                l["id"] = f"{chapter['id']}/notes-{i}"
                                l["fromNotes"] = True
                                chapter["lessons"].append(l)
                        else:
                            l, cs = parse_lesson(f, scope, chdir)
                            l["id"] = f"{chapter['id']}/{f.stem}"
                            chapter["lessons"].append(l)
                        concepts.update({k: v for k, v in cs.items() if k not in concepts})
                    subject["chapters"].append(chapter)
                klass["subjects"].append(subject)
            klass["subjects"].sort(key=lambda s: (s["order"], s["key"]))
            board["classes"].append(klass)
        board["classes"].sort(key=lambda c: c["number"])
        boards.append(board)
    boards.sort(key=lambda b: (b["order"], b["id"]))
    app_dir = CONTENT / "_app"
    tutors = load_json(app_dir / "tutors.json") if (app_dir / "tutors.json").exists() else []
    phrases = load_json(app_dir / "phrases.json") if (app_dir / "phrases.json").exists() else {}
    for t in tutors if isinstance(tutors, list) else []:
        for k in ("id", "name", "shape", "color", "voice"):
            if k not in t:
                err(app_dir / "tutors.json", 0, f'tutor is missing "{k}"')
    body = {"boards": boards, "concepts": concepts, "tutors": tutors, "phrases": phrases}
    digest = hashlib.sha256(json.dumps(body, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
    return {"version": digest, **body}


def main():
    bundle = build()
    if errors:
        print(f"\nFound {len(errors)} problem(s) in content/ - nothing was built:\n")
        print("\n".join(errors))
        return 1
    lessons = sum(len(ch["lessons"]) for b in bundle["boards"] for c in b["classes"]
                  for s in c["subjects"] for ch in s["chapters"])
    if "--check" not in sys.argv:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        # "built" only moves forward when the content really changed, so the
        # app can tell which copy of the lessons is the newest.
        built = int(time.time())
        if OUT.exists():
            try:
                old = json.loads(OUT.read_text(encoding="utf-8"))
                if old.get("version") == bundle["version"]:
                    built = old.get("built", built)
            except Exception:  # noqa: BLE001
                pass
        bundle["built"] = built
        OUT.write_text(json.dumps(bundle, ensure_ascii=False, sort_keys=True, indent=1) + "\n", encoding="utf-8")
    print(f"Content OK: {len(bundle['boards'])} boards, {lessons} lessons, "
          f"{len(bundle['concepts'])} concepts. Version {bundle['version']}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
