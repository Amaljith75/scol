# Adding lessons to Scol

Everything the tutor teaches lives in this folder. The app has no lessons of its own:
add a file here, and it appears in the app as a stepping stone on the learning path, taught by the tutor.

## 1. Where things go

```
content/
  kerala-scert/                  <- a board (syllabus)
    board.json
    class-3/                     <- a class
      maths/                     <- a subject
        subject.json
        01-chapter-name/         <- a chapter (the number sets the order)
          chapter.json
          notes.md               <- quick way: plain notes
          01-first-lesson.md     <- full way: a designed lesson
          02-second-lesson.md
          images/                <- pictures used by this chapter (optional)
  cbse/
    ...same shape...
  _inbox/                        <- raw material, not shown in the app
```

Folders for both boards, Classes 1 to 4, are already created. To add a chapter:

1. Open the subject folder, for example `content/kerala-scert/class-3/maths/`.
2. Create a folder such as `01-numbers-up-to-999`.
3. Add `chapter.json` (copy the one below).
4. Add `notes.md`, or lesson files, or both.
5. Commit. Within a few minutes the lessons are checked, built into the app, and sent to phones that already have the app installed (they pick up new lessons the next time the app is opened with internet).

On a phone, GitHub's "Add file > Create new file" works: type the full path, for example
`content/cbse/class-2/maths/01-shapes/notes.md`, and the folders are created for you.

### chapter.json

```json
{
  "title": { "en": "Numbers up to 999", "ml": "999 വരെയുള്ള സംഖ്യകൾ" },
  "verified": false,
  "source": "SCERT Class 3 Maths textbook, Unit 1",
  "objectives": [
    { "en": "Read and write three-digit numbers" }
  ]
}
```

Set `"verified": true` only after someone has checked the lessons against the real textbook.
Until then, parents see a small note saying some lessons are still unchecked.

## 2. The quick way: `notes.md`

Write notes the way you would in a notebook. Each `## Heading` becomes one short lesson.
The tutor reads each paragraph aloud, shows the pictures, and asks the questions.

```
lang: en

## Counting in tens
When we count in tens, we jump ten steps each time: 10, 20, 30, 40.

Visual: numberline 0 50 30
Example: 3 jumps of ten take us to 30.

Q: What comes after 40 when we count in tens?
A: 50
Hint: Jump ten more steps from 40.

Q: Which is bigger?
A: 50
Options: 30 | 50

Q: Why is 43 bigger than 34?
A: Because 43 has 4 tens and 34 has only 3 tens.
```

- `lang: ml` at the top if the notes are in Malayalam.
- A blank line starts a new speech bubble. Keep paragraphs short: one idea each.
- `Q:` followed by `A:` makes a question.
  - Answer is a number: the child types it on a number pad.
  - `Options:` given: the child taps one of the choices.
  - Otherwise: the tutor asks, the child thinks, taps "Show answer", and says whether they got it.
- `Hint:` is what the tutor says after a first wrong answer.
- `Visual:` puts a picture on the board (list below).

## 3. The full way: a lesson file

Use this when you want both languages, hints, explanations, and tracking of common mistakes.
Any `.md` file in a chapter folder other than `notes.md` is a lesson. File names set the order.

```
# Equal groups
title.ml: തുല്യ കൂട്ടങ്ങൾ
objective: Count objects arranged in equal groups.
concept: equal-groups
concept.name: Counting equal groups
concept.name.ml: തുല്യ കൂട്ടങ്ങൾ എണ്ണൽ

## say
en: Look! I have 3 baskets. Each basket has 4 mangoes.
ml: നോക്കൂ! എന്റെ കയ്യിൽ 3 കൊട്ടകളുണ്ട്.
visual: groups 3 4 🥭

## ask
form: choice
en: How many mangoes are there in all?
ml: ആകെ എത്ര മാങ്ങയുണ്ട്?
visual: groups 3 4 🥭
options: 7 | 12 | 34
answer: 12
hint.en: Count basket by basket: 4, then 8, then...
explain.en: 4 and 4 and 4 make 12.
mistake 7: added 3 and 4 instead of counting every group
```

| Line | Meaning |
| --- | --- |
| `# Title` | Lesson name in English. `title.ml:` for Malayalam. |
| `concept:` | The idea this lesson teaches. Questions with the same concept are judged together, even across lessons. Use short names like `equal-groups`. |
| `## say` | The tutor explains. Needs `en:` and/or `ml:`. `visual:` is optional. |
| `## ask` | The tutor asks. `form:` is `choice`, `number`, `think`, or a touch activity: `abacus`, `measure`, `build`. |
| `## story` | Another way to explain this lesson's idea, as a short story. Used only after a child gets a question wrong twice. |
| `## picture` | Another way to explain it, with a `visual:` line and one or two sentences. |
| `options:` | Choices separated by `\|`. Add `options.ml:` for Malayalam choices in the same order. |
| `answer:` | The right answer. For `choice` it must match one of the options exactly. |
| `hint.en:` / `hint.ml:` | Said after the first wrong answer. The tutor never gives the answer straight away. |
| `explain.en:` / `explain.ml:` | Said after a second wrong answer. The question then comes back later in the lesson. |
| `mistake 7:` | If the child answers 7, remember why. If the same mistake repeats, the parent report says so in these words. |
| `level:` | 1 = basic, 2 = same idea in a new situation. |

### Touch activities

```
## ask
form: abacus
en: Move the beads to show the number 235.
answer: 235

## ask
form: measure
en: Slide the scale until its 0 is at the start of the pencil. How long is the pencil?
visual: ruler 6 ✏️
answer: 6
mistake 8: read the scale without putting 0 at the start

## ask
form: build
en: Drag the sticks to build the shape that has 3 sides.
options: triangle | rectangle
answer: triangle
```

- `abacus`: the child moves beads on hundreds, tens and ones rods. The answer is a number up to 999.
- `measure`: the object starts 2 cm from the left, so the child must slide the scale first. Reading without sliding gives the length plus 2, which is worth listing as a `mistake`.
- `build`: the child drags sticks onto one of the outlines. Shapes can be `triangle`, `rectangle` or `square`.

### Explaining another way

Give every lesson one `## story` and one `## picture`. When a child misses a question twice, the tutor corrects it,
then tells the story or shows the picture and asks again. The app notes which of the two led to a right answer
and uses that one first next time.

For the tutor to count an idea as understood, a child must answer correctly at least three times,
in at least two question styles. So give every concept both `choice` and `number` questions,
and at least one question that looks different from the examples.

## 4. Pictures the tutor can show

| Write this | Shows |
| --- | --- |
| `visual: groups 3 4 🥭` | 3 baskets with 4 mangoes each |
| `visual: count 7 ⭐` | 7 stars in a row |
| `visual: numberline 0 50 30` | A number line from 0 to 50 with 30 marked |
| `visual: text 3 × 4 = 12` | Big text on the board |
| `visual: emoji 🐘 🐅` | Big emoji |
| `visual: array 3 6 🪑` | 3 rows of 6 chairs |
| `visual: shapes circle triangle rectangle square` | Coloured shapes in a row |
| `visual: sticks 12` | 12 small sticks |
| `visual: place 3 4 2` | An abacus showing 3 hundreds, 4 tens, 2 ones |
| `visual: notes 100 100 10 1` | Money notes and coins |
| `visual: ruler 7 ✏️` | A scale with a 7 cm pencil lying on it |
| `visual: pattern 10 20 30 ?` | A row of cards, with `?` for the missing one |
| `visual: split 1000 300 ?` | A number and the two parts it splits into |
| `visual: steps 200 + 100 = 300 / 30 + 40 = 70` | Working shown line by line (separate lines with ` / `) |
| `visual: image tiger.png` | A picture file from this chapter's `images/` folder (needs internet) |
| `visual: picture 🌱 💧` | A cartoon drawn from the step's own English words by the "Make pictures" workflow (Gemini) and saved in `images/`. The emoji, if given, show until the picture has arrived or without internet. Change the words and a new picture is drawn. |

Pieces of every picture pop in one after another, so the child watches it being built. The tutor floats over the
picture and touches the pieces it talks about (each group, shape, row, card or corner is a piece the tutor brain can name).
Prefer `picture` over `emoji` for things a small symbol shows badly (soil, a rain gauge, a toilet): a brown square is not soil to a child.

## 5. Adding a new subject, class or board

- **Subject:** create a folder such as `hindi/` inside the class folder with a `subject.json`:
  `{ "name": { "en": "Hindi", "ml": "ഹിന്ദി" }, "icon": "🪔", "color": "#8E5BFF", "order": 5 }`
- **Class:** create `class-5/` inside the board folder.
- **Board:** create a new folder beside `kerala-scert/` with a `board.json`:
  `{ "name": { "en": "ICSE" }, "order": 3 }`

No app changes are needed for any of these.

## 6. The tutors and their voices

- **Characters** are in `content/_app/tutors.json`: name, body shape (`blob`, `spiky`, `cloud`, `flower`, `bean`),
  colour, eye style, voice, and the things each one says (hello, praise, encouragement). Add a new block to add a new tutor.
- **Shared lines** the tutors say (such as "We will try this one again in a little while") are in `content/_app/phrases.json`.
- **Voices** are made automatically. Whenever lessons change, every new line is turned into a sound file with
  Gemini's speech model and saved in the `voice/` folder. This needs the Gemini key saved once as a repository secret
  named `GEMINI_API_KEY` (repository **Settings > Secrets and variables > Actions > New repository secret**).
  Never put the key in a file: this repository is public.
- If a voice file is not ready yet, the app reads that line with the phone's own voice.

## 7. If something is wrong

Every commit is checked automatically. If a file has a mistake, the check fails and tells you the
file and line, for example:

```
content/cbse/class-3/maths/01-shapes/02-corners.md (line 14): answer "3" is not one of the options
```

Nothing broken is ever sent to children: the app keeps the last good set of lessons until the mistake is fixed.
See the result under the repository's **Actions** tab.

## 8. Rules for content

- Follow the textbook's chapter order and learning objectives, but write explanations in your own words.
  Do not copy textbook text or pictures: SCERT and NCERT books are copyrighted.
- Do not invent chapters. If you are not sure a topic is in the syllabus, leave it out.
- Keep sentences short. One idea per speech bubble. Use things a child in Kerala sees every day.
- Malayalam text should be read by a fluent speaker before `verified` is set to true.
