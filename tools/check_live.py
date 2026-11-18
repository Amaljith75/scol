#!/usr/bin/env python3
"""Deploy check for Gemini Live: asks the Scol server for a one-use pass (as the app does),
connects to Gemini Live with it, and waits for the tutor's voice. Prints what happened;
never prints the pass. Needs: pip install websockets"""
import asyncio
import json
import sys
import urllib.request

import websockets

brain = json.load(open("content/_app/brain.json"))
req = urllib.request.Request(brain["url"], data=json.dumps({
    "mode": "live", "device": "deploy-check-0001", "lang": "en", "tutor": "Mio",
    "about": "Gentle and warm.", "tone": "normal"}).encode(),
    headers={"content-type": "application/json", "apikey": brain.get("public_key", "")})
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        live = json.load(r)
except urllib.error.HTTPError as e:
    print(f"Live pass: the server answered HTTP {e.code}: {e.read().decode()[:300]}")
    sys.exit(1)
print("Live pass: received; model", live.get("model"), "; rules", len(live.get("rules", "")), "characters")


async def talk():
    url = f"{live['url']}?access_token={urllib.parse.quote(live['token'])}"
    async with websockets.connect(url, max_size=None, open_timeout=20) as ws:
        await ws.send(json.dumps({"setup": {
            "model": live["model"],
            "generationConfig": {"responseModalities": ["AUDIO"], "speechConfig": {
                "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": "Aoede"}}}},
            "outputAudioTranscription": {},
            "systemInstruction": {"parts": [{"text": live.get("rules", "You are a friendly tutor.")}]}}}))
        msg = json.loads(await asyncio.wait_for(ws.recv(), 20))
        if "setupComplete" not in msg:
            print("Live: unexpected first answer:", str(msg)[:300])
            return False
        print("Live: connected with the pass")
        await ws.send(json.dumps({"clientContent": {"turns": [{"role": "user", "parts": [
            {"text": "Say hello to a child in one short sentence."}]}], "turnComplete": True}}))
        audio, words = 0, ""
        while True:
            m = json.loads(await asyncio.wait_for(ws.recv(), 30))
            sc = m.get("serverContent", {})
            for p in sc.get("modelTurn", {}).get("parts", []):
                if p.get("inlineData", {}).get("mimeType", "").startswith("audio/pcm"):
                    audio += len(p["inlineData"]["data"]) * 3 // 4
            words += sc.get("outputTranscription", {}).get("text", "")
            if sc.get("turnComplete"):
                break
        print(f"Live: the tutor answered with {audio} bytes of voice: {words.strip()[:160]!r}")
        return audio > 0

import urllib.parse  # noqa: E402

try:
    ok = asyncio.run(talk())
except Exception as e:  # noqa: BLE001
    print("Live: failed:", str(e)[:300])
    ok = False
sys.exit(0 if ok else 1)
