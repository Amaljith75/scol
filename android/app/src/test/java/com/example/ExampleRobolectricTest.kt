package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.scol.data.ScolRepository
import com.example.scol.model.*
import com.example.scol.network.GeminiLiveClient
import com.example.scol.network.LiveConnectionState
import com.example.scol.network.LiveTutorSessionConfig
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class ExampleRobolectricTest {

    @Test
    fun readStringAndBundleFromContext() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val appName = context.getString(R.string.app_name)
        assertEquals("SCOL Studio", appName)

        val repo = ScolRepository(context)
        val bundle = repo.bundle.value
        assertTrue(bundle.boards.isNotEmpty())
        assertEquals("koko", repo.state.value.tutorId)
        assertEquals("Ollie", pick(bundle.tutor("koko").name, "en"))

        val subjects = bundle.subjectsFor("kerala-scert", 3)
        assertTrue(subjects.any { it.key == "maths" && it.lessons.size >= 24 })
    }

    @Test
    fun geminiLiveClient_enforcesLessonOnlyGuardrailAndHandlesMissingKey() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val repo = ScolRepository(context)
        val bundle = repo.bundle.value
        val subject = bundle.subjectsFor("kerala-scert", 3).first { it.key == "maths" }
        val lesson = subject.lessons.first()
        val tutor = bundle.tutor("zizu")

        val client = GeminiLiveClient(context)
        val config = LiveTutorSessionConfig(
            tutor = tutor,
            lang = "en",
            tone = "warm",
            childName = "Anu",
            subject = subject,
            lesson = lesson,
            currentStep = lesson.steps.firstOrNull(),
            visualSummary = "Abacus showing 3 hundreds, 2 tens, 5 ones"
        )

        val prompt = client.buildSystemInstruction(config)
        assertTrue(prompt.contains(tutor.personalityInstruction))
        assertTrue(prompt.contains(pick(lesson.title, "en")))
        assertTrue(prompt.contains("STRICT LESSON-ONLY GUARDRAIL"))
        assertTrue(prompt.contains("NEVER answer out-of-topic questions"))
        assertTrue(prompt.contains("Abacus showing 3 hundreds, 2 tens, 5 ones"))

        // When BuildConfig.GEMINI_API_KEY is still the placeholder, connect() reports MISSING_API_KEY gracefully
        if (!client.hasValidApiKey()) {
            client.connect(config)
            assertEquals(LiveConnectionState.MISSING_API_KEY, client.connectionState.value)
        }

        // Verify Malayalam mode & strict emotion mode in system instruction
        val mlConfig = config.copy(lang = "ml", tone = "strict")
        val mlPrompt = client.buildSystemInstruction(mlConfig)
        assertTrue(mlPrompt.contains("STRICT MALAYALAM MODE"))
        assertTrue(mlPrompt.contains("VOICE EMOTION MODE (STRICT)"))
        assertTrue(mlPrompt.contains(tutor.emotionDirection("strict")))

        // Verify mutual exclusion hook between ScolAudioEngine and GeminiLiveClient
        val audio = com.example.scol.audio.ScolAudioEngine(context)
        var liveAudioStopped = false
        audio.onBeforeSpeechPlay = { liveAudioStopped = true }
        audio.say(listOf("ഹലോ കൂട്ടുകാരാ"), "ml", tutor, "happy")
        assertTrue(liveAudioStopped)
        audio.release()

        client.release()
    }
}
