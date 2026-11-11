# How Scol is built

This is the team's map of the project. Parents and customers should read the main README instead.

## The repository

```
content/      Every lesson, organised board > class > subject > chapter. Plain text files.
              content/_app/ holds the tutor characters and the lines they share.
tools/        build_content.py checks the lessons and packs them into one bundle for the app.
              build_voice.py turns every tutor line into a sound file with Gemini speech.
voice/        The sound files, one folder per tutor, plus index.json.
app/          The Android app (Flutter). app/branding/ holds the icon.
.github/      On every push: check lessons, test the app, build scol.apk, publish under Releases.
              A second workflow makes the voice files.
docs/         This file.
```

## The one rule that shapes everything

**The app contains no lessons, and the lessons contain no app code.**

- Curriculum lives in `content/` as text. Adding a board, class, subject or chapter is adding a folder.
- `tools/build_content.py` turns it into `app/assets/content/bundle.json`. If any file has a mistake, the build stops and names the file and line.
- The app reads only the bundle. On start it also checks GitHub for a newer bundle, so new lessons reach installed phones without a new app.

## The tutor is in control

The classroom screen does not know how to teach. It only draws what the **Tutor Director** (`app/lib/tutor.dart`) tells it and passes the child's taps back:

| The Director can | What the child sees |
| --- | --- |
| say something | speech bubble, read aloud |
| show a picture | the board changes |
| move | the tutor walks to the left, centre or right, eyes leading the way |
| look | eyes go to the board while teaching, to the answers while asking, to the child while talking |
| ask (choice / number / think) | answer buttons or number pad |
| give a hint, explain, praise | bubble changes colour, tutor's mood changes |
| bring a question back | the lesson gets longer for this child only |
| choose the next lesson | the "Next for you" card on the home screen |

Today the Director follows the written lesson and adapts with rules (hint first, explain second, re-ask later, weak ideas before new ones). The next stage puts an AI model behind the same set of controls. Screens, lessons and the learning record stay as they are.

## Modules

| Module in the brief | Where it is now | State |
| --- | --- | --- |
| Curriculum Management | `content/`, `tools/build_content.py`, `app/lib/content.dart` | Working. Class 3 Maths (Kerala) Part 1 written: 6 units, 24 levels. Other classes scaffolded. |
| AI Tutor and Conversation | `app/lib/tutor.dart` (Director), `content/_app/tutors.json` | Five characters. Scripted and rule-based. No live AI conversation yet. |
| Adaptive Learning | Director re-teaching; `revisionLesson` and `nextLesson` in `app/lib/state.dart` | Working, rule-based. |
| Assessment | `app/lib/mastery.dart` | Working. Evidence across attempts, question styles, speed and repeated mistakes. |
| Gamification and Rewards | `state.dart`, home, path and celebration screens | Stars, XP, streak, badges, path. |
| Voice and Speech | `tools/build_voice.py`, `app/lib/voice.dart` | Each tutor has a Gemini voice, pre-made per line, cached on the phone; phone voice as fallback. No listening yet. |
| Timetable and Revision | Tutor's pick on home; daily goal; daily time limit | Simple version. No parent-set schedule yet. |
| Parent Dashboard | `app/lib/screens/parent.dart` | Plain-words report and controls. English only. |
| Child Safety and Privacy | Parent gate; all data on device; no accounts; no recording | Good for this stage. Must be redesigned before any data leaves the phone. |

## Why the voices are made in advance

The tutors only say lines that are written in the lessons, so each line can be turned into sound once and reused by every child. That gives natural Gemini voices in English and Malayalam with no waiting, no cost per child, no key inside the app, lessons that work offline, and nothing about a child ever sent to an AI service. The key is stored only as the GitHub secret `GEMINI_API_KEY`.

## Not built yet, on purpose

1. **Live AI conversation.** It needs a small server so the AI key never sits inside the app, a filter so the tutor stays on the lesson, and a monthly cost per child that fits a ₹199-299 price. The Director is ready for it.
2. **Voice input.** Recognising a six-year-old speaking Malayalam mixed with English is hard, and recordings of children need verifiable parental consent under the DPDP rules. Test with a few families before building around it.
3. **Accounts and cloud sync (Supabase).** Not needed to prove the learning cycle. Adding them brings consent, retention and deletion duties.
4. **Payments.**

## Things to decide early

- **Content is the real work.** Two boards, four classes and four subjects is roughly 250 chapters. The app is ready for them, but each needs writing and checking by someone who knows the textbook. Start with one class and one subject, and test it with children before writing the rest.
- **Textbook copyright.** Follow the chapter order and objectives; write explanations in our own words. Do not put scanned textbook pages in this public repository.
- **Malayalam quality.** The Malayalam in the app and sample lessons was drafted quickly and needs a fluent reader's review.
- **Does it teach?** The claim "knows whether your child understood" should be tested: check a few children on paper after a week and compare with what the parent report says.

## Building the app yourself

Not needed for content work: every push builds `scol.apk` and puts it under Releases.

```
python3 tools/build_content.py
cd app
flutter create --platforms=android --org com.scolapp --project-name scol .
python3 ../tools/patch_android.py .
flutter test
flutter run
```
