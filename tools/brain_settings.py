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


try:
    models = [m.get("id") for m in call("/models").get("data", [])]
    print("Models this key can use:", ", ".join(sorted(filter(None, models))))
    if models and cfg["model"] not in models:
        sys.exit(f"Model {cfg['model']!r} is not in that list. Pick one of them in content/_app/brain.json.")
    out = call("/chat/completions", {"model": cfg["model"], "max_tokens": 60, "messages": [
        {"role": "user", "content": "In one short sentence for an 8-year-old: why do plants need water?"}]})
    print("Test answer:", out["choices"][0]["message"]["content"].strip()[:200])
except urllib.error.HTTPError as e:
    sys.exit(f"The AI provider refused the key or model: HTTP {e.code} {e.read().decode()[:300]}")

with open("brain.env", "w") as f:
    f.write(f"BRAIN_API_KEY={key}\nBRAIN_BASE_URL={base}\nBRAIN_MODEL={cfg['model']}\n"
            f"BRAIN_DEVICE_LIMIT={cfg.get('device_limit', 40)}\nBRAIN_DAILY_LIMIT={cfg.get('daily_limit', 1500)}\n")
print("Settings ready for", cfg["model"], "at", base)
