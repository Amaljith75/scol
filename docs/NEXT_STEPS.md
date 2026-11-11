# What to build next

## Do first (to finish this MVP)

1. **Turn on the voices.** Add the Gemini key as the repository secret `GEMINI_API_KEY`, then run the
   "Make tutor voices" workflow from the Actions tab. Listen to ten English and ten Malayalam lines for each tutor.
   If a voice does not suit a character, change `voice` or `style` in `content/_app/tutors.json` and run it again.
2. **Read the Malayalam.** Every Malayalam line in `content/` was drafted without a native reader. Fix what sounds
   unnatural for an eight-year-old; the voice for a changed line is remade automatically.
3. **Check the lessons against the textbook** with a Class 3 teacher, then set `"verified": true` in each `chapter.json`.
4. **Test with five children.** Sit beside them. Note where they get stuck, bored, or tap without reading.
   After a week, give a short paper test and compare with what the parent report says they understand.

## Features worth adding, in order

| Feature | Why | What it needs |
| --- | --- | --- |
| **Ask the tutor** (the child asks a question and the tutor answers about the current level) | The main thing a scripted tutor cannot do | A small server (a Supabase function) holding the Gemini key; answers limited to the current lesson; a daily limit per child; parent consent, because the child's question leaves the phone |
| **Speak the answer** (voice input for number and one-word answers) | Six-year-olds type slowly | Speech recognition tested on real children speaking Malayalam and English; clear parental consent for the microphone |
| **Touch activities**: drag sticks to build a shape, drag beads on the abacus, measure with a movable scale, match pairs that make 100 | Maths at this age is learned with hands | New question types in the lesson format and the app |
| **Explain it another way**: after a repeated mistake, the tutor switches method (picture, story, or step-by-step) and remembers which works for this child | The "adapts to each child" promise | Two or three alternative explanations per idea in the lessons; a preference score in the learning record |
| **Story mode per unit**: each unit is one adventure (a school fest, a pencil factory, a forest sports day) and each level moves the story on | Keeps children coming back for the next level | Writing; a short intro and outro scene per level |
| **Weekly parent report on WhatsApp**, in Malayalam | Parents will not open the app to check | A share button first (no server needed), automatic sending later |
| **Daily timetable** set by the parent (minutes per day, days per week) with the tutor planning revision | Asked for in the brief; needs more than one subject to matter | More content first |
| **Tutor dress-up** bought with stars (hats, colours) | Gives stars a purpose without pushing screen time | Small art job |
| **Teacher mode**: one phone or projector, whole class answers together | A route into schools | Later |

## Things to avoid for now

- Open-ended chat with the AI. For young children it is hard to keep safe and on-topic, and it costs money per message.
- Leaderboards between children. They reward the fastest, not the ones who are learning.
- Building Classes 1, 2 and 4 before Class 3 Maths has been tested with real children.

## Costs to watch

- Voice files: made once per line, so the cost grows with the amount of content, not with the number of children.
- "Ask the tutor" would be the first cost that grows with every child. Decide a daily limit before launching it,
  and check that the cost per child stays well below the ₹199-299 subscription.
