package com.example.scol.network

import android.content.Context
import com.example.BuildConfig
import com.example.scol.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom
import java.util.concurrent.TimeUnit

data class BrainAnswer(val text: String, val ok: Boolean = true)
data class TaughtStep(val say: String, val touch: List<Int> = emptyList())

class TutorBrainClient(private val context: Context) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(12, TimeUnit.SECONDS)
        .readTimeout(35, TimeUnit.SECONDS)
        .build()

    private fun hasGeminiKey(): Boolean {
        val k = BuildConfig.GEMINI_API_KEY.trim()
        return k.isNotEmpty() && k != "MY_GEMINI_API_KEY"
    }

    private fun deviceId(): String {
        val prefs = context.getSharedPreferences("scol_device_prefs", Context.MODE_PRIVATE)
        var id = prefs.getString("device_id", null)
        if (id == null) {
            val rnd = SecureRandom()
            val bytes = ByteArray(12)
            rnd.nextBytes(bytes)
            id = bytes.joinToString("") { "%02x".format(it) }
            prefs.edit().putString("device_id", id).apply()
        }
        return id
    }

    private fun sorry(kind: String, lang: String): String {
        val ml = lang == "ml"
        return when (kind) {
            "offline" -> if (ml) "ചോദ്യങ്ങൾക്ക് ഉത്തരം പറയാൻ എനിക്ക് ഇന്റർനെറ്റ് വേണം. ഓൺലൈനാകുമ്പോൾ വീണ്ടും ചോദിക്കൂ." else "I need the internet to answer questions. Let us try again when we are online."
            "limit" -> if (ml) "ഇന്ന് നമ്മൾ ഒരുപാട് ചോദ്യങ്ങൾ ചോദിച്ചു! ബാക്കി നാളെ ചോദിക്കാം." else "We asked lots of questions today! Let us ask more tomorrow."
            else -> if (ml) "ഇപ്പോൾ ഉത്തരം കിട്ടിയില്ല. ടീച്ചറോട് ചോദിക്കാമോ, അല്ലെങ്കിൽ വീണ്ടും ശ്രമിക്കൂ?" else "Hmm, I could not think of an answer just now. Can you ask your teacher, or try again?"
        }
    }

    private fun callGeminiText(
        systemPrompt: String,
        userPrompt: String,
        expectJson: Boolean = false
    ): String? {
        val key = BuildConfig.GEMINI_API_KEY.trim()
        if (key.isEmpty() || key == "MY_GEMINI_API_KEY") return null
        val url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$key"

        val payload = JSONObject().apply {
            put("systemInstruction", JSONObject().apply {
                put("parts", JSONArray().apply {
                    put(JSONObject().apply { put("text", systemPrompt) })
                })
            })
            put("contents", JSONArray().apply {
                put(JSONObject().apply {
                    put("role", "user")
                    put("parts", JSONArray().apply {
                        put(JSONObject().apply { put("text", userPrompt) })
                    })
                })
            })
            if (expectJson) {
                put("generationConfig", JSONObject().apply {
                    put("responseMimeType", "application/json")
                })
            }
        }

        return try {
            val req = Request.Builder()
                .url(url)
                .addHeader("Content-Type", "application/json")
                .post(payload.toString().toRequestBody("application/json".toMediaType()))
                .build()
            client.newCall(req).execute().use { res ->
                if (!res.isSuccessful) return null
                val body = res.body?.string() ?: return null
                val parts = JSONObject(body)
                    .optJSONArray("candidates")
                    ?.optJSONObject(0)
                    ?.optJSONObject("content")
                    ?.optJSONArray("parts") ?: return null
                val sb = StringBuilder()
                for (i in 0 until parts.length()) {
                    sb.append(parts.optJSONObject(i)?.optString("text", "") ?: "")
                }
                sb.toString().trim().takeIf { it.isNotEmpty() }
            }
        } catch (_: Exception) {
            null
        }
    }

    suspend fun askBrain(
        bundle: Bundle,
        question: String,
        lang: String,
        tutorName: String,
        lessonTitle: String,
        notes: String,
        tone: String = "normal",
        about: String = "",
        childName: String = "",
        progress: String = "",
        history: List<Pair<String, String>> = emptyList(),
        tutor: TutorCharacter? = null
    ): BrainAnswer = withContext(Dispatchers.IO) {
        val resolvedTutor = tutor ?: bundle.tutors.firstOrNull {
            it.displayName("en").equals(tutorName, ignoreCase = true)
        } ?: TutorCharacter.fallback

        // Primary Brain: Gemini AI with character personality, emotion mode, Malayalam rule, and lesson-only guardrail
        if (hasGeminiKey()) {
            val ml = lang == "ml"
            val langInstruction = if (ml) {
                "LANGUAGE RULE (MANDATORY): Explain EVERYTHING in simple, warm, natural spoken Malayalam (മലയാളം). Do not reply in English."
            } else {
                "LANGUAGE RULE: Reply in simple, clear, warm Indian school English."
            }
            val sysPrompt = """
${resolvedTutor.personalityInstruction}
${resolvedTutor.emotionDirection(tone)}
$langInstruction

STUDENT: ${childName.ifBlank { "friend" }}
ACTIVE LESSON: "$lessonTitle"
LESSON CONTEXT: $notes
${if (progress.isNotBlank()) "PROGRESS: $progress" else ""}

STRICT LESSON-ONLY GUARDRAIL:
- ONLY answer questions about the active lesson "$lessonTitle".
- NEVER answer out-of-topic questions (no movies, games, politics, coding, general trivia, or unrelated topics).
- If the question is off-topic, warmly decline in character in 1 short sentence and guide the child back to "$lessonTitle".
- Keep your reply concise (2 to 4 short sentences), spoken naturally so it sounds great read aloud.
            """.trimIndent()

            val histText = if (history.isNotEmpty()) {
                history.takeLast(4).joinToString("\n") { (q, a) -> "Child: $q\nTutor: $a" } + "\n"
            } else ""
            val answer = callGeminiText(sysPrompt, "${histText}Child asks: $question")
            if (!answer.isNullOrBlank()) {
                return@withContext BrainAnswer(answer, ok = true)
            }
        }

        // Secondary fallback: bundle brain endpoint if configured
        val url = bundle.brain["url"]?.toString() ?: ""
        val publicKey = bundle.brain["public_key"]?.toString() ?: ""
        if (url.isEmpty()) return@withContext BrainAnswer(sorry("error", lang), ok = false)

        try {
            val histArr = JSONArray().apply {
                val recent = if (history.size > 6) history.takeLast(6) else history
                for ((q, a) in recent) {
                    put(JSONArray(listOf(q, a)))
                }
            }
            val guardedNotes = buildString {
                if (notes.isNotBlank()) append(notes).append(" ")
                append("[STRICT RULE: Only answer questions about the current lesson '$lessonTitle'. Politely decline any out-of-topic questions and guide the student back to the lesson.]")
            }
            val payload = JSONObject().apply {
                put("question", question)
                put("lang", lang)
                put("tutor", tutorName)
                put("about", about)
                put("lesson", lessonTitle)
                put("notes", guardedNotes)
                put("tone", tone)
                put("child", childName.trim())
                put("progress", progress)
                put("history", histArr)
                put("device", deviceId())
            }
            val req = Request.Builder()
                .url(url)
                .addHeader("content-type", "application/json")
                .addHeader("apikey", publicKey)
                .post(payload.toString().toRequestBody("application/json".toMediaType()))
                .build()

            client.newCall(req).execute().use { res ->
                if (res.code == 429) return@withContext BrainAnswer(sorry("limit", lang), ok = false)
                if (!res.isSuccessful) return@withContext BrainAnswer(sorry("error", lang), ok = false)
                val body = res.body?.string() ?: return@withContext BrainAnswer(sorry("error", lang), ok = false)
                val answer = JSONObject(body).optString("answer", "").trim()
                if (answer.isEmpty()) BrainAnswer(sorry("error", lang), ok = false) else BrainAnswer(answer)
            }
        } catch (_: Exception) {
            BrainAnswer(sorry("offline", lang), ok = false)
        }
    }

    suspend fun teachLesson(
        bundle: Bundle,
        lesson: Lesson,
        lang: String,
        tutor: TutorCharacter,
        tone: String
    ): List<TaughtStep?>? = withContext(Dispatchers.IO) {
        // Primary Brain: Gemini AI teaches every lesson step in the character's voice, emotion mode, and chosen language
        if (hasGeminiKey()) {
            val ml = lang == "ml"
            val stepsArr = JSONArray()
            for ((idx, s) in lesson.steps.withIndex()) {
                stepsArr.put(JSONObject().apply {
                    put("index", idx)
                    put("type", if (s.isAsk) "ask" else "say")
                    put("text", pick(s.text, lang))
                    if (s.visual != null) {
                        put("visual", "${s.visual.kind} ${s.visual.args.joinToString(" ")}".trim())
                    }
                    if (s.isAsk) {
                        put("answer", s.answer)
                    }
                })
            }

            val langRule = if (ml) {
                "Write EVERY 'say' string completely in natural, simple, kid-friendly spoken Malayalam (മലയാളം). Never switch to English."
            } else {
                "Write EVERY 'say' string in clear, warm, kid-friendly Indian school English."
            }

            val sysPrompt = """
${tutor.personalityInstruction}
${tutor.emotionDirection(tone)}
$langRule

You are preparing the step-by-step spoken lines for the SCOL lesson "${pick(lesson.title, lang)}".
Objective: ${pick(lesson.objective, lang)}
Return ONLY a JSON object with this schema:
{"steps": [{"say": "1-2 short warm spoken sentences matching your character and emotion", "touch": [1]}]}
Rules:
- The "steps" array MUST have exact length ${lesson.steps.size}, in the exact same order.
- For "ask" steps, keep the exact question meaning clear and don't reveal the answer.
- "touch" is optional 1-based item indices (e.g. [1, 2]) when pointing at items on the visual board, or [].
            """.trimIndent()

            val rawJson = callGeminiText(sysPrompt, "Steps:\n$stepsArr", expectJson = true)
            val parsed = parseTaughtStepsJson(rawJson, lesson.steps.size)
            if (parsed != null) {
                return@withContext parsed
            }
        }

        // Fallback to remote bundle brain if Gemini key missing or failed
        val url = bundle.brain["url"]?.toString() ?: ""
        val publicKey = bundle.brain["public_key"]?.toString() ?: ""
        if (url.isEmpty()) return@withContext null

        try {
            val stepsArr = JSONArray()
            for (s in lesson.steps) {
                val obj = JSONObject().apply {
                    put("t", if (s.isAsk) "ask" else "say")
                    put("text", pick(s.text, lang))
                    if (s.visual != null) {
                        put("visual", "${s.visual.kind} ${s.visual.args.joinToString(" ")}".trim())
                    }
                    if (s.label.isNotEmpty()) put("label", s.label)
                    if (s.isAsk) {
                        put("form", s.form)
                        put("answer", s.answer)
                        if (s.options.isNotEmpty()) put("options", JSONArray(s.options))
                    }
                }
                stepsArr.put(obj)
            }
            val payload = JSONObject().apply {
                put("mode", "teach")
                put("lang", lang)
                put("tutor", tutor.displayName("en"))
                put("about", pick(tutor.about, "en"))
                put("tone", tone)
                put("lesson", pick(lesson.title, "en"))
                put("objective", pick(lesson.objective, "en"))
                put("steps", stepsArr)
                put("device", deviceId())
            }
            val req = Request.Builder()
                .url(url)
                .addHeader("content-type", "application/json")
                .addHeader("apikey", publicKey)
                .post(payload.toString().toRequestBody("application/json".toMediaType()))
                .build()

            client.newCall(req).execute().use { res ->
                if (!res.isSuccessful) return@withContext null
                val body = res.body?.string() ?: return@withContext null
                parseTaughtStepsJson(body, lesson.steps.size)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun parseTaughtStepsJson(raw: String?, expectedSize: Int): List<TaughtStep?>? {
        if (raw.isNullOrBlank()) return null
        return try {
            val cleaned = raw.trim()
                .removePrefix("```json")
                .removePrefix("```")
                .removeSuffix("```")
                .trim()
            val arr = JSONObject(cleaned).optJSONArray("steps") ?: return null
            if (arr.length() != expectedSize) return null
            (0 until arr.length()).map { i ->
                val item = arr.optJSONObject(i) ?: return@map null
                val say = item.optString("say", "").trim()
                if (say.isEmpty()) null else {
                    val touchArr = item.optJSONArray("touch")
                    val touches = if (touchArr != null) {
                        (0 until touchArr.length()).mapNotNull { ti ->
                            val num = touchArr.optInt(ti, -99)
                            if (num > 0) num else null
                        }
                    } else emptyList()
                    TaughtStep(say = say, touch = touches)
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    suspend fun tellProgress(
        bundle: Bundle,
        facts: String,
        lang: String,
        tutor: TutorCharacter,
        childName: String,
        tone: String
    ): String? = withContext(Dispatchers.IO) {
        val name = childName.trim().ifEmpty { if (lang == "ml") "കുട്ടി" else "your child" }
        if (hasGeminiKey()) {
            val ml = lang == "ml"
            val langRule = if (ml) {
                "Explain the progress report completely in simple, warm, natural Malayalam (മലയാളം)."
            } else {
                "Explain the progress report in warm, clear Indian school English."
            }
            val sysPrompt = """
${tutor.personalityInstruction}
${tutor.emotionDirection(tone)}
$langRule
Give a brief 2-3 sentence spoken progress summary for the parent of $name based strictly on the provided facts.
            """.trimIndent()
            val told = callGeminiText(sysPrompt, "Progress facts:\n$facts")
            if (!told.isNullOrBlank()) {
                return@withContext told
            }
        }

        val url = bundle.brain["url"]?.toString() ?: ""
        val publicKey = bundle.brain["public_key"]?.toString() ?: ""
        if (url.isEmpty()) return@withContext null

        try {
            val payload = JSONObject().apply {
                put("mode", "report") // the Scol brain server's progress mode (supabase/functions/brain)
                put("report", facts)
                put("lang", lang)
                put("tutor", tutor.displayName("en"))
                put("about", pick(tutor.about, "en"))
                put("tone", tone)
                put("device", deviceId())
            }
            val req = Request.Builder()
                .url(url)
                .addHeader("content-type", "application/json")
                .addHeader("apikey", publicKey)
                .post(payload.toString().toRequestBody("application/json".toMediaType()))
                .build()

            client.newCall(req).execute().use { res ->
                if (!res.isSuccessful) return@withContext null
                val body = res.body?.string() ?: return@withContext null
                val raw = JSONObject(body).optString("answer", "").trim()
                if (raw.isEmpty()) null else raw.replace("{name}", name)
            }
        } catch (_: Exception) {
            null
        }
    }
}
