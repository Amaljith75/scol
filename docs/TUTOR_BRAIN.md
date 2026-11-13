# The tutor brain and voices: how to change them

Scol has two separate "AI" jobs. Neither key is ever inside the app.

| Job | What it does | Where it runs | What it uses now |
| --- | --- | --- | --- |
| **Brain** | Answers the questions a child asks with the 🎙️ button | A small server: the `brain` function in the Supabase project `scol` | Kimi (`kimi-k3`) |
| **Voice** | Turns every line Mio says into a sound file, ahead of time | GitHub, in the "Make tutor voices" workflow | Microsoft Edge voices |

Lessons themselves are **not** written by the AI while a child learns. They are fixed text in `content/`,
checked by people, so the tutor never says something wrong about the lesson or the screen. The brain is only
used for the child's own questions.

## One-time setup (needed before questions work)

1. **Top up your Kimi account.** The key works, but Kimi refuses requests because the account balance is empty
   ("suspended due to insufficient balance"). Add credit at platform.kimi.ai.
2. **Give GitHub permission to update the server.** Create a token at
   https://supabase.com/dashboard/account/tokens and save it in the GitHub repository as a secret named
   `SUPABASE_ACCESS_TOKEN` (Settings > Secrets and variables > Actions > New repository secret).
3. Open **Actions > Deploy tutor brain > Run workflow**. The log shows which key it found, which models that key
   can use, a test answer, and finally an answer from the live server.
4. In the app, a parent turns on **Let my child ask the tutor questions** in the Parents area.

## Changing the AI model or company (no new app needed)

Everything is in `content/_app/brain.json`:

```json
{
  "base_url": "https://api.moonshot.ai/v1",
  "model": "kimi-k3",
  "key_secret": "KIMI_API_KEY"
}
```

- **Another Kimi model:** change `model`. The deploy log lists the models your key can use.
- **A new Kimi key:** replace the `KIMI_API_KEY` secret in GitHub, then run **Deploy tutor brain**.
- **Another company:** any service that speaks the OpenAI "chat completions" format works. Add its key as a GitHub
  secret, then set `base_url`, `model` and `key_secret`:

| Company | base_url | example model | key_secret |
| --- | --- | --- | --- |
| Kimi (Moonshot) | `https://api.moonshot.ai/v1` | `kimi-k3` | `KIMI_API_KEY` |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | `gemini-2.5-flash` | `GEMINI_API_KEY` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` | `OPENAI_API_KEY` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` | `DEEPSEEK_API_KEY` |
| OpenRouter | `https://openrouter.ai/api/v1` | any listed model | `OPENROUTER_API_KEY` |

Commit the change: the deploy runs by itself and the app uses the new brain straight away.
If your secret has a different name, add that name to the lists in `.github/workflows/brain.yml` and
`tools/brain_settings.py`.

**Limits** (also in `brain.json`): `device_limit` questions per phone per day (40) and `daily_limit` for all phones
together (1500). They stop anyone from running up your bill, because the server address in the app is public.

## Changing Mio's voice, or giving other tutors a voice

In `content/_app/tutors.json`, each tutor has a `voice`:

- `{"en": "en-IN-NeerjaExpressiveNeural", "ml": "ml-IN-SobhanaNeural"}`: Microsoft Edge voices (Mio now).
  Other Edge voices: `en-IN-PrabhatNeural`, `ml-IN-MidhunNeural`. `rate` and `pitch` adjust speed and tone.
- `"Sulafat"` (or another Gemini voice name): Gemini speech, using the `GEMINI_API_KEY` secret.
- `""`: no sound files; the phone's own voice reads the lines.

The "Make tutor voices" workflow makes only the files that are missing, so giving a second tutor a voice just
adds that tutor's files. Live answers from the brain are read by the phone's own voice.

**Before a paid launch:** the Edge voices are free but not licensed for commercial apps. Switch to a licensed
voice service (for example Azure Speech, Google Cloud Text-to-Speech, Sarvam AI, or AI4Bharat's open models).

## Children's data

When questions are on, the words of the question and the lesson topic go to the brain and to the AI company.
The child's name, progress and voice recording are never sent; speech is turned into words by the phone.
Questions are off until a parent turns them on, and the switch explains this. Before launch, have the consent wording
checked against India's DPDP rules for children's data.
