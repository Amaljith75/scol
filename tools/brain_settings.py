#!/usr/bin/env python3
"""Used by the 'Deploy tutor brain' workflow. Reads content/_app/brain.json and
the repository secrets, finds the AI key, checks it works, and writes the
server settings to brain.env (never printed)."""
import json
import os
import sys
import urllib.error
import urllib.request

cfg = json.load(open("content/_app/brain.json"))
# The workflow passes these secrets in (add a name here and in brain.yml for a new provider).
KNOWN = ["BRAIN_API_KEY", "KIMI_API_KEY", "MOONSHOT_API_KEY", "KIMI_KEY", "KIMI_AI_API_KEY", "KIMI",
         "OPENAI_API_KEY", "GEMINI_API_KEY", "DEEPSEEK_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY"]
secrets = {n: os.environ[n] for n in KNOWN if os.environ.get(n, "").strip()}
names = sorted(secrets)
print("AI key secrets found:", ", ".join(names) or "none")

name = cfg.get("key_secret", "")
if name not in secrets:
    # Fall back to a secret whose name says which provider it is for.
    guesses = [n for n in names if any(w in n.upper() for w in ("KIMI", "MOONSHOT"))]
    if not guesses:
        sys.exit(f"No secret named {name!r}. Add it under Settings > Secrets and variables > Actions, "
                 "or put the right name in content/_app/brain.json as key_secret.")
    print(f"No secret named {name}; using {guesses[0]} instead.")
    name = guesses[0]
key = secrets[name].strip()
base = cfg["base_url"].rstrip("/")


def call(path, body=None):
    req = urllib.request.Request(base + path, data=json.dumps(body).encode() if body else None,
                                 headers={"authorization": f"Bearer {key}", "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)


fallbacks = [m for m in cfg.get("fallback_models", []) if m]
try:
    available = {m.get("id") for m in call("/models").get("data", [])}
except urllib.error.HTTPError as e:
    sys.exit(f"The AI provider refused the key: HTTP {e.code} {e.read().decode()[:300]}")
if available and cfg["model"] not in available:
    free = sorted(m for m in available if m and m.endswith(":free")) or sorted(filter(None, available))
    sys.exit(f"Model {cfg['model']!r} is not offered. Pick one of these in content/_app/brain.json: " + ", ".join(free[:40]))
for m in fallbacks:
    if available and m not in available:
        print(f"Note: fallback model {m} is not offered any more; it will be skipped.")
fallbacks = [m for m in fallbacks if not available or m in available]

import time  # noqa: E402
ok = False
for m in [cfg["model"], *fallbacks]:
    for q in ("In one or two short sentences for an 8-year-old: why do plants need water?",
              "ഒരു എട്ടു വയസ്സുകാരനോട് ഒന്നോ രണ്ടോ ചെറിയ വാക്യത്തിൽ: ചെടികൾക്ക് വെള്ളം എന്തിന്?"):
        t = time.time()
        try:
            out = call("/chat/completions", {"model": m, "max_tokens": 700, "messages": [{"role": "user", "content": q}]})
            text = (out["choices"][0]["message"].get("content") or "").strip()
            print(f"[{m}] {time.time() - t:.1f}s: {text[:220]}")
            ok = ok or bool(text)
        except urllib.error.HTTPError as e:
            print(f"[{m}] failed: HTTP {e.code} {e.read().decode()[:200]}")
if not ok:
    sys.exit("No model gave an answer. Check the key, the account balance, or choose another model.")

with open("brain.env", "w") as f:
    f.write(f"BRAIN_API_KEY={key}\nBRAIN_BASE_URL={base}\nBRAIN_MODEL={cfg['model']}\n"
            f"BRAIN_FALLBACK_MODELS={','.join(fallbacks)}\n"
            f"BRAIN_DEVICE_LIMIT={cfg.get('device_limit', 40)}\nBRAIN_DAILY_LIMIT={cfg.get('daily_limit', 1500)}\n")
print("Settings ready for", cfg["model"], "at", base)
