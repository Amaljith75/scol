package com.example

import com.example.scol.model.*
import com.example.scol.tutor.Phase
import com.example.scol.tutor.TutorDirector
import org.junit.Assert.*
import org.junit.Test

class ExampleUnitTest {

    @Test
    fun pickAndTr_returnLocalizedStrings() {
        val localized = mapOf("en" to "Hello", "ml" to "നമസ്കാരം")
        assertEquals("Hello", pick(localized, "en"))
        assertEquals("നമസ്കാരം", pick(localized, "ml"))
        assertEquals("Plain", pick("Plain", "ml"))
        assertEquals("Let's go!", tr("go", "en"))
        assertEquals("തുടങ്ങാം!", tr("go", "ml"))
    }

    @Test
    fun conceptRecord_masteryProgressionAndRevision() {
        val record = ConceptRecord()
        assertEquals(Understanding.NOT_STARTED, record.status)

        // Repeated mistake triggers MISCONCEPTION
        record.record("choice", "failed", day = 1, millis = 4000L, mistakeNotes = listOf("reversed digits"))
        record.record("choice", "failed", day = 1, millis = 4000L, mistakeNotes = listOf("reversed digits"))
        assertEquals("reversed digits", record.repeatedMistake)
        assertEquals(Understanding.MISCONCEPTION, record.status)
        assertTrue(record.needsRevision(today = 1))

        // 3 first-try correct across 2 forms reaches SECURE
        record.record("choice", "first", day = 2, millis = 4000L)
        record.record("number", "first", day = 2, millis = 4000L)
        record.record("abacus", "first", day = 2, millis = 4000L)
        assertEquals(Understanding.SECURE, record.status)
        assertFalse(record.needsRevision(today = 3))
        assertTrue(record.needsRevision(today = 10))
    }

    @Test
    fun tutorDirector_handlesHintWrongAttemptAndCompletion() {
        val step1 = LessonStep(
            type = "say",
            text = mapOf("en" to "Look at the sticks"),
            visual = VisualSpec("sticks", listOf("3"))
        )
        val step2 = LessonStep(
            type = "ask",
            text = mapOf("en" to "How many sticks?"),
            form = "choice",
            options = listOf("2", "3", "4"),
            answer = "3",
            hint = mapOf("en" to "Count one by one")
        )
        val lesson = Lesson(
            id = "test_lesson",
            title = mapOf("en" to "Sticks"),
            steps = listOf(step1, step2)
        )
        val records = mutableMapOf<String, ConceptRecord>()
        val director = TutorDirector(
            lesson = lesson,
            initialLang = "en",
            tutor = TutorCharacter.fallback,
            recordFor = { records.getOrPut(it) { ConceptRecord() } },
            day = 10
        )

        assertEquals(Phase.TALKING, director.snapshot.value.phase)
        director.next()

        assertEquals(Phase.ASKING, director.snapshot.value.phase)
        assertTrue(director.snapshot.value.canHint)
        director.showHint()
        assertTrue(director.snapshot.value.hintShown)

        // Wrong answer stays in ASKING with option disabled
        director.answer("2")
        assertEquals(Phase.ASKING, director.snapshot.value.phase)
        assertTrue(director.snapshot.value.wrongOptions.contains("2"))

        // Correct answer enters FEEDBACK then FINISHED
        director.answer("3")
        assertEquals(Phase.FEEDBACK, director.snapshot.value.phase)
        director.next()
        assertEquals(Phase.FINISHED, director.snapshot.value.phase)
    }

    @Test
    fun tutorCharacters_haveDistinctVoicesAndPersonalities() {
        val ids = listOf("minnu", "tiko", "pompy", "zizu", "koko")
        val tutors = ids.map { id ->
            TutorCharacter(id = id, name = mapOf("en" to id), shape = "blob", colorValue = 0xFF5B6CFFL)
        }

        // Distinct Gemini Live voices across all 5 tutors
        val liveVoices = tutors.map { it.liveVoiceName }
        assertEquals(listOf("Aoede", "Puck", "Kore", "Zephyr", "Charon"), liveVoices)
        assertEquals(5, liveVoices.toSet().size)

        // Distinct TTS pitch & rate tuning and non-empty localized tags + instructions
        assertEquals(5, tutors.map { it.ttsPitch }.toSet().size)
        assertEquals(5, tutors.map { it.ttsRate }.toSet().size)
        tutors.forEach { tutor ->
            assertTrue(tutor.personalityTag("en").isNotBlank())
            assertTrue(tutor.personalityTag("ml").isNotBlank())
            assertTrue(tutor.personalityInstruction.isNotBlank())
        }
    }

    @Test
    fun tutorCharacters_emotionModesTuneVoiceAndPrompts() {
        val ollie = TutorCharacter(id = "koko", name = mapOf("en" to "Ollie"), shape = "bean", colorValue = 0xFFFF884DL)
        val tones = listOf("happy", "normal", "calm", "strict")
        val directions = tones.map { ollie.emotionDirection(it) }
        assertEquals(4, directions.toSet().size)

        // Emotion modes visibly adjust fallback TTS pitch/rate too
        assertTrue(ollie.effectiveTtsPitch("happy") > ollie.effectiveTtsPitch("calm"))
        assertTrue(ollie.effectiveTtsRate("happy") > ollie.effectiveTtsRate("calm"))

        // Malayalam & English Gemini TTS prompts preserve exact verbatim text and character/mood
        val mlPrompt = ollie.ttsStylePrompt("കൂട്ടുകാരാ, നമുക്ക് എണ്ണാം!", "ml", "happy")
        assertTrue(mlPrompt.contains("Malayalam"))
        assertTrue(mlPrompt.contains("happy"))
        assertTrue(mlPrompt.contains("Ollie"))
        assertTrue(mlPrompt.contains("കൂട്ടുകാരാ, നമുക്ക് എണ്ണാം!"))
    }
}
