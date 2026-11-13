#!/usr/bin/env python3
"""Used by the 'Deploy tutor brain' workflow. Reads the list of AIs in
content/_app/brain.json, finds each key among the repository secrets, tests
each one, and writes the server settings to brain.env (never printed)."""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

cfg = json.load(open("content/_app/brain.json"))
# The workflow passes these secrets in (add a name here and in brain.yml for a new company).
KNOWN = ["BRAIN_API_KEY", "KIMI_API_KEY", "MOONSHOT_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY",
         "DEEPSEEK_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY", "HF_TOKEN", "HUGGINGFACE_API_KEY"]
secrets = {n: os.environ[n].strip() for n in KNOWN if os.environ.get(n, "").strip()}
print("AI key secrets found:", ", ".join(sorted(secrets)) or "none")


def call(base, key, body):
    req = urllib.request.Request(base.rstrip("/") + "/chat/completions", data=json.dumps(body).encode(),
                                 headers={"authorization": f"Bearer {key}", "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)


ready = []
for p in cfg["providers"]:
    name, key = p.get("name", p["model"]), secrets.get(p.get("key_secret", ""))
    if not key:
        print(f"- {name}: skipped, no secret named {p.get('key_secret')}")
        continue
    models = [p["model"], *p.get("fallback_models", [])]
    works = False
    for q in ("In one short sentence for an 8-year-old: why do plants need water?",
              "ഒരു എട്ടു വയസ്സുകാരനോട് ഒരു ചെറിയ വാക്യത്തിൽ: ചെടികൾക്ക് വെള്ളം എന്തിന്?"):
        body = {"model": p["model"], "max_tokens": 700, "messages": [{"role": "user", "content": q}], **p.get("extra", {})}
        if len(models) > 1:
            body["models"] = models
        t = time.time()
        try:
            out = call(p["base_url"], key, body)
            text = (out["choices"][0]["message"].get("content") or "").strip()
            print(f"- {name} [{out.get('model', p['model'])}] {time.time() - t:.1f}s: {text[:160]}")
            works = works or bool(text)
        except urllib.error.HTTPError as e:
            print(f"- {name}: HTTP {e.code} {' '.join(e.read().decode().split())[:300]}")
            if e.code == 404:  # wrong model name: show the names this key can use
                try:
                    req = urllib.request.Request(p["base_url"].rstrip("/") + "/models", headers={"authorization": f"Bearer {key}"})
                    ids = [m.get("id", "") for m in json.load(urllib.request.urlopen(req, timeout=30)).get("data", [])]
                    print("  models this key can use:", ", ".join(i for i in ids if "embed" not in i)[:1500])
                except Exception as e2:  # noqa: BLE001
                    print("  could not list models:", e2)
                break
        except Exception as e:  # noqa: BLE001
            print(f"- {name}: {e}")
    if not works:
        print(f"  ({name} did not answer now; it stays in the list in case it is only busy)")
    ready.append({"name": name, "base_url": p["base_url"], "model": p["model"],
                  "fallback_models": p.get("fallback_models", []), "extra": p.get("extra", {}), "key": key})

if not ready:
    sys.exit("No AI has a key. Add the secrets named in content/_app/brain.json.")
blob = base64.b64encode(json.dumps(ready).encode()).decode()
with open("brain.env", "w") as f:
    f.write(f"BRAIN_PROVIDERS_B64={blob}\nBRAIN_DEVICE_LIMIT={cfg.get('device_limit', 40)}\n"
            f"BRAIN_DAILY_LIMIT={cfg.get('daily_limit', 1000)}\n")
print("Order the brain will try:", " -> ".join(p["name"] for p in ready))
