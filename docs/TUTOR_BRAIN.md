# The tutor brain and voices: how to change them

Scol has two separate "AI" jobs. No key is ever inside the app.

| Job | What it does | Where it runs | What it uses now |
| --- | --- | --- | --- |
| **Brain** | Answers the child's questions (🎙️) and "🤔 Explain more" | The `brain` function in the Supabase project `scol` | A list of AIs tried in turn: OpenRouter free → Google Gemini → Gemini Lite → Kimi |
| **Voice** | Speaks every line in a natural voice | Mio's lesson lines: made ahead in GitHub ("Make tutor voices"). Everything else: made on the phone | Microsoft Edge voices |

Lessons are fixed text in `content/`, checked by people, so the tutor never says something wrong about the lesson
or the screen. The AI explains *extra*: when the child asks, or taps "Explain more". Generating every lesson line
live with AI was left out on purpose: free AI limits (50 a day on OpenRouter) would run out in one lesson, and a
wrong fact cannot be checked before a child hears it.

## When one AI runs out, the next one answers

`content/_app/brain.json` has a `providers` list. The brain tries them top to bottom: if one is busy, out of free
requests or broken, the next one answers. The app does not change. Each entry:

```json
{
  "name": "Google Gemini",
  "base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
  "model": "gemini-flash-latest",
  "key_secret": "GEMINI_API_KEY"
}
```

- **Reorder** the list to change which AI is asked first.
- **Add a company:** any service that speaks the OpenAI "chat completions" format works. Add its key as a GitHub
  secret, then add an entry. Examples:

| Company | base_url | example model | key_secret |
| --- | --- | --- | --- |
| OpenRouter | `https://openrouter.ai/api/v1` | `google/gemma-4-31b-it:free` | `OPENROUTER_API_KEY` |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | `gemini-flash-latest` | `GEMINI_API_KEY` |
| Hugging Face | `https://router.huggingface.co/v1` | `Qwen/Qwen3-32B` (any chat model it lists) | `HF_TOKEN` |
| Kimi (Moonshot) | `https://api.moonshot.ai/v1` | `kimi-k3` | `KIMI_API_KEY` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` | `DEEPSEEK_API_KEY` |

- **Wrong model name?** The deploy log ("Deploy tutor brain" in the Actions tab) tests every AI in English and
  Malayalam, and when a name is wrong it prints the names that key can use.
- `fallback_models` (OpenRouter only) are other free models tried inside the same OpenRouter account. Note that
  OpenRouter's free limit (50 a day) counts for the whole account, so a *different company* is the real backup.

Commit the change: the deploy runs by itself. Edit only the values; the file must stay complete, from `{` to `}`.

**Limits** (also in `brain.json`): `device_limit` questions per phone per day (40) and `daily_limit` for all phones
together (1000). They stop anyone from running up your bill, because the server address in the app is public.

**Mood:** the parent's "Tutor's mood" setting (Happy, Normal, Calm, Strict) is sent along, so answers match the mood.

## Voices

Each tutor in `content/_app/tutors.json` has a `voice` per language, plus `rate` (speed) and `pitch`:

```json
"voice": { "en": "en-IN-PrabhatNeural", "ml": "ml-IN-MidhunNeural" }, "rate": "+6%", "pitch": "+8Hz"
```

Indian Edge voices: English `en-IN-NeerjaNeural`, `en-IN-NeerjaExpressiveNeural` (women), `en-IN-PrabhatNeural`
(man); Malayalam `ml-IN-SobhanaNeural` (woman), `ml-IN-MidhunNeural` (man). Any other Edge voice name works too
(the full list: run `pip install edge-tts` then `edge-tts --list-voices`). Different `rate` and `pitch` make the
same voice sound like a different character.

- **Add a new voice to a tutor:** change its `voice`, `rate` or `pitch`, commit. Nothing else is needed.
- **Add a new tutor:** copy a tutor block, give it a new `id`, name and voice.
- `"ready_made": true` (only Mio now): the "Make tutor voices" workflow makes all lesson lines ahead of time, so
  Mio also works offline. Other tutors' lines are made on the phone the first time they are needed (the whole
  lesson is prepared while the child listens to the first line) and kept, so the second time is offline too.
  Making every tutor ready-made would add about 60 MB per tutor to the repository.
- The mood setting changes speed and pitch on top of the tutor's own setting.

Hugging Face also has free Malayalam voice models (for example AI4Bharat's Indic Parler-TTS). They need a GPU
server to run fast enough, so they are a later option, not a free one.

**Before a paid launch:** the Edge voices are free but not licensed for commercial apps. Switch to a licensed
voice service (for example Azure Speech, which has these same voices, Google Cloud Text-to-Speech or Sarvam AI).

## Malayalam lessons

Maths has Malayalam written by hand. EVS Malayalam was added by AI with the "Add Malayalam to lessons" workflow
(`tools/translate_lessons.py`): it only adds `ml:` lines and keeps every English line exactly, and a file is saved
only if it passes the lesson check. **A Malayalam teacher should read the EVS Malayalam before launch.** To add
Malayalam to new English lessons, run that workflow from the Actions tab.

## Children's data

When questions are on, the words of the question and the lesson topic go to the brain and to the AI company.
The child's name, progress and voice recording are never sent; speech is turned into words by the phone.
Questions are off until a parent turns them on, and the switch explains this. Before launch, have the consent wording
checked against India's DPDP rules for children's data.
