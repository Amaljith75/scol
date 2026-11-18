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
# The newest Gemini key wins: the first of these names that is set (a new key can be added under any of them).
GEMINI_NAMES = ["NEW_GEMINI_API_KEY", "GEMINI_NEW_API_KEY", "GEMINI_NEW_KEY", "NEW_GEMINI_KEY", "GEMINI_LIVE_API_KEY",
                "GEMINI_LIVE_KEY", "GEMINI_KEY", "GEMINI_API_KEY"]
KNOWN = ["BRAIN_API_KEY", "KIMI_API_KEY", "MOONSHOT_API_KEY", "OPENAI_API_KEY", *GEMINI_NAMES,
         "DEEPSEEK_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY", "HF_TOKEN", "HUGGINGFACE_API_KEY"]
secrets = {n: os.environ[n].strip() for n in KNOWN if os.environ.get(n, "").strip()}
print("AI key secrets found:", ", ".join(sorted(secrets)) or "none")
gemini_name = next((n for n in GEMINI_NAMES if n in secrets), None)
if gemini_name:
    secrets["GEMINI_API_KEY"] = secrets[gemini_name]
    print(f"Gemini key: using the secret {gemini_name} (for teaching, talking and the characters' voices)")
    try:
        req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/models?pageSize=300",
                                     headers={"x-goog-api-key": secrets[gemini_name]})
        names = [m.get("name", "") for m in json.load(urllib.request.urlopen(req, timeout=30)).get("models", [])]
        print("  voice (TTS) models this key can use:", ", ".join(n for n in names if "tts" in n) or "none")
    except Exception as e:  # noqa: BLE001
        print("  could not list models:", e)
else:
    print("No Gemini key secret found: the characters' Gemini voices will not work.")


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
# The pre-warm workflow proves itself with this token; both workflows derive it from the Supabase token.
import hashlib  # noqa: E402
prewarm = hashlib.sha256(("scol-prewarm|" + os.environ.get("SUPABASE_ACCESS_TOKEN", "")).encode()).hexdigest()[:40]
with open("brain.env", "w") as f:
    f.write(f"BRAIN_PROVIDERS_B64={blob}\nBRAIN_DEVICE_LIMIT={cfg.get('device_limit', 40)}\n"
            f"BRAIN_DAILY_LIMIT={cfg.get('daily_limit', 1000)}\n"
            f"BRAIN_TTS_DEVICE_LIMIT={cfg.get('voice_device_limit', 400)}\nBRAIN_TTS_DAILY_LIMIT={cfg.get('voice_daily_limit', 8000)}\n"
            f"BRAIN_TTS_MODELS={','.join(cfg.get('voice_models', ['gemini-3.8-flash-tts', 'gemini-2.5-flash-preview-tts']))}\n"
            f"BRAIN_GEMINI_KEY={secrets.get('GEMINI_API_KEY', '')}\n"
            f"BRAIN_LIVE_MODEL={cfg.get('live_model', 'models/gemini-2.5-flash-native-audio-preview-12-2025')}\n"
            f"PREWARM_TOKEN={prewarm if os.environ.get('SUPABASE_ACCESS_TOKEN') else ''}\n")
print("Order the brain will try:", " -> ".join(p["name"] for p in ready))
