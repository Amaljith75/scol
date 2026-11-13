# The tutor brain and voices: how to change them

Scol has two separate "AI" jobs. No key is ever inside the app.

| Job | What it does | Where it runs | What it uses now |
| --- | --- | --- | --- |
| **Brain** | Teaches each level in the tutor's own words, answers the child's questions (🎙️) and "🤔 Explain more" | The `brain` function in the Supabase project `scol` | A list of AIs tried in turn: OpenRouter free → Google Gemini → Gemini Lite → Kimi |
| **Voice** | Speaks every line in a natural voice | Mio's lesson lines: made ahead in GitHub ("Make tutor voices"). Everything else: made on the phone | Microsoft Edge voices |

Lessons are fixed text in `content/`, checked by people. Questions, hints, answers and explanations after a mistake
are always said exactly as written. The teaching steps (`## say`) are different: before a level starts, the brain
reads the whole lesson and writes what the tutor says at each teaching step, like a real tutor would: it starts from
something the child knows, points at the picture on the board, keeps every fact and number of the written step, adds
nothing new, and ends with a small check or a bridge to the next step. The written lesson line stays on screen under
the tutor's words, so a parent can always see the checked text.

How this stays within free AI limits: a level is written **once** per language, tutor and mood, and the result is kept
on the server (table `brain_teach`) and on the phone. Every other child gets the same words without asking the AI
again, and a level that was taught once works offline. The teach request sends only lesson text and a random
phone id, never anything about the child. Parents can turn it off in the Parents area ("The tutor teaches in its own
words"); then the tutor reads the lines as written, as before. The `PROMPT_VERSION` constant in the brain function
makes every level be written again when the teaching prompt changes.

The child's own questions and "Explain more" are still answered live, one call each.

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
A level served from the server's memory does not count; only a level written for the first time does.

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
  Mio also works offline. Other tutors' lines, the brain's teaching and answers, and every line in a mood other than
  normal are made on the phone the first time they are needed (the whole lesson is prepared while the child listens
  to the first line) and kept, so the second time is offline too.
  Making every tutor ready-made would add about 60 MB per tutor to the repository.
- **When does the phone's own voice speak?** Only when a line has no ready-made file and the Edge voice cannot be
  made within 15 seconds (no internet, a very slow connection, or Edge refusing). The app now refreshes its list of
  ready-made files when a level starts, looks for a ready-made file even when its list is old, learns the server's
  clock if Edge refuses (a phone clock that is off used to mean no Edge voice at all), and in a mood other than
  normal falls back to the normal-mood ready-made file before the phone's voice. If a whole lesson is still read by
  the phone, check the "Make tutor voices" run in the Actions tab: lines it could not make are listed there.
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
