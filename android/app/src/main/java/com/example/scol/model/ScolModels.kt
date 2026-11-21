package com.example.scol.model

import androidx.compose.ui.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

const val RAW_BASE = "https://raw.githubusercontent.com/Amaljith75/scol/main/"
const val CONTENT_URL = "${RAW_BASE}app/assets/content/bundle.json"

/**
 * Picks the right language from a String or localized Map {"en": ..., "ml": ...}.
 */
fun pick(text: Any?, lang: String): String {
    return when (text) {
        is String -> text
        is Map<*, *> -> {
            val v = text[lang] ?: text["en"] ?: text.values.firstOrNull()
            v?.toString() ?: ""
        }
        is JSONObject -> {
            val v = if (text.has(lang) && !text.isNull(lang)) text.optString(lang)
            else if (text.has("en") && !text.isNull("en")) text.optString("en")
            else {
                val keys = text.keys()
                if (keys.hasNext()) text.optString(keys.next()) else ""
            }
            v
        }
        else -> ""
    }
}

fun parseLocalizedValue(raw: Any?): Any? {
    return when (raw) {
        is JSONObject -> {
            val map = mutableMapOf<String, Any?>()
            val keys = raw.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                map[k] = parseJsonValue(raw.opt(k))
            }
            map
        }
        is String -> raw
        else -> raw?.toString()
    }
}

fun parseJsonValue(raw: Any?): Any? {
    return when (raw) {
        null, JSONObject.NULL -> null
        is JSONObject -> {
            val map = mutableMapOf<String, Any?>()
            val keys = raw.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                map[k] = parseJsonValue(raw.opt(k))
            }
            map
        }
        is JSONArray -> {
            (0 until raw.length()).map { parseJsonValue(raw.opt(it)) }
        }
        else -> raw
    }
}

fun parseColorHex(hex: String?, defaultColor: Long = 0xFF5B6CFF): Color {
    val clean = (hex ?: "").replace("#", "").trim()
    val parsed = clean.toLongOrNull(16) ?: defaultColor
    val argb = if (clean.length <= 6) (parsed or 0xFF000000L) else parsed
    return Color(argb)
}

data class TutorCharacter(
    val id: String,
    val name: Any?,
    val shape: String, // blob | spiky | cloud | flower | bean
    val colorValue: Long,
    val voice: Map<String, String> = emptyMap(),
    val eyes: String = "round", // round | wide | soft | curious | sleepy
    val energy: Float = 1.0f,
    val rate: String = "+0%",
    val pitch: String = "+0Hz",
    val about: Any? = null,
    val hello: Any? = null,
    val praise: Any? = null,
    val oops: Any? = null,
    val cheer: Any? = null,
    val readyMade: Boolean = false
) {
    val color: Color get() = Color(colorValue)

    fun displayName(lang: String): String = pick(name, lang)

    fun voiceFor(lang: String): String = voice[lang] ?: ""

    val liveVoiceName: String
        get() = when (id) {
            "minnu" -> "Aoede"   // Mio: gentle & warm storyteller
            "tiko" -> "Puck"     // Leo: energetic & playful game master
            "pompy" -> "Kore"    // Yuki: calm, patient, unhurried
            "zizu" -> "Zephyr"   // Ruby: bright & endlessly curious
            "koko" -> "Charon"   // Ollie: funny, relaxed buddy
            else -> "Charon"
        }

    val ttsPitch: Float
        get() = when (id) {
            "minnu" -> 1.08f
            "tiko" -> 1.14f
            "pompy" -> 0.96f
            "zizu" -> 1.18f
            "koko" -> 0.88f
            else -> 1.0f
        }

    val ttsRate: Float
        get() = when (id) {
            "minnu" -> 0.94f
            "tiko" -> 1.08f
            "pompy" -> 0.86f
            "zizu" -> 1.02f
            "koko" -> 0.95f
            else -> 1.0f
        }

    fun effectiveTtsPitch(tone: String): Float = when (tone) {
        "happy" -> (ttsPitch * 1.07f).coerceIn(0.6f, 1.5f)
        "calm" -> (ttsPitch * 0.94f).coerceIn(0.6f, 1.5f)
        "strict" -> (ttsPitch * 0.90f).coerceIn(0.6f, 1.5f)
        else -> ttsPitch
    }

    fun effectiveTtsRate(tone: String): Float = when (tone) {
        "happy" -> (ttsRate * 1.06f).coerceIn(0.65f, 1.4f)
        "calm" -> (ttsRate * 0.88f).coerceIn(0.65f, 1.4f)
        "strict" -> (ttsRate * 0.98f).coerceIn(0.65f, 1.4f)
        else -> ttsRate
    }

    fun emotionDirection(tone: String): String = when (tone) {
        "happy" -> "Speak with joyful, upbeat, bubbly excitement, bright smiling energy, and celebratory warmth."
        "calm" -> "Speak with a very soft, gentle, soothing, slow, and deeply reassuring calm voice."
        "strict" -> "Speak with a crisp, firm, disciplined, focused schoolteacher tone—clear, serious, and structured, never rude."
        else -> "Speak with a warm, friendly, encouraging, and natural conversational tone."
    }

    fun ttsStylePrompt(text: String, lang: String, tone: String): String {
        val langRule = if (lang == "ml") {
            "in clear, natural spoken Malayalam (മലയാളം)"
        } else {
            "in clear, natural Indian school English"
        }
        val charTone = when (id) {
            "minnu" -> "like Mio, a gentle warm storyteller"
            "tiko" -> "like Leo, an energetic playful game-master"
            "pompy" -> "like Yuki, a calm and patient teacher"
            "zizu" -> "like Ruby, a bright curious explorer"
            "koko" -> "like Ollie, a funny relaxed best buddy"
            else -> "like a warm school tutor"
        }
        val moodCue = when (tone) {
            "happy" -> "with extra happy, cheerful, excited emotion"
            "calm" -> "with slow, soothing, gentle calm emotion"
            "strict" -> "with firm, crisp, focused, serious teacher emotion"
            else -> "with warm, friendly, encouraging emotion"
        }
        return "Read aloud ONLY the exact text below verbatim (do not add, translate, or change any words), speaking $charTone $moodCue $langRule:\n$text"
    }

    fun personalityTag(lang: String): String = when (id) {
        "minnu" -> if (lang == "ml") "കഥ പറയുന്ന സുഹൃത്ത്" else "Warm Storyteller"
        "tiko" -> if (lang == "ml") "കളി ചാമ്പ്യൻ" else "Energetic Game-Master"
        "pompy" -> if (lang == "ml") "ശാന്തയായ അധ്യാപിക" else "Calm & Patient"
        "zizu" -> if (lang == "ml") "ജിജ്ഞാസയുള്ള കൂട്ടുകാരി" else "Curious Explorer"
        "koko" -> if (lang == "ml") "തമാശക്കാരൻ കൂട്ടുകാരൻ" else "Funny & Relaxed"
        else -> "Personal Tutor"
    }

    val personalityInstruction: String
        get() = when (id) {
            "minnu" -> "You are Mio (മിയോ), a gentle, warm-hearted tutor who loves turning maths and school concepts into tiny, cozy everyday stories with mangoes, birds, and home scenes. Speak softly, tenderly, and encouragingly."
            "tiko" -> "You are Leo (ലിയോ), a high-energy, super-enthusiastic tutor who treats every lesson step and question like an exciting game level to win! Use upbeat cheers like 'Awesome move!' or 'Level up!' while keeping explanations crisp."
            "pompy" -> "You are Yuki (യൂകി), a calm, soothing, deeply patient tutor who never rushes. Pause gently between ideas, reassure the child that taking time is wonderful, and guide them one tiny step at a time."
            "zizu" -> "You are Ruby (റൂബി), an endlessly curious explorer who loves asking 'Why?' and 'Look closely!' alongside the child, spotting clues in pictures like a friendly detective."
            "koko" -> "You are Ollie (ഒല്ലി), a funny, laid-back best buddy who makes learning feel like chatting with a clever friend—using light, goofy kid-friendly comparisons while staying focused on the lesson."
            else -> "You are a warm, encouraging SCOL school tutor."
        }

    fun praiseList(lang: String): List<String> {
        val p = praise
        if (p is Map<*, *>) {
            val list = p[lang] ?: p["en"]
            if (list is List<*> && list.isNotEmpty()) {
                return list.mapNotNull { it?.toString() }
            }
        }
        return listOf("Well done!")
    }

    companion object {
        val fallback = TutorCharacter(
            id = "minnu",
            name = mapOf("en" to "Mio", "ml" to "മിയോ"),
            shape = "blob",
            colorValue = 0xFFFFB81FL
        )

        fun fromJson(j: JSONObject): TutorCharacter {
            val hex = j.optString("color", "#FFB81F").replace("#", "")
            val parsedColor = (hex.toLongOrNull(16) ?: 0xFFB81FL) or 0xFF000000L
            val voiceMap = mutableMapOf<String, String>()
            val voiceRaw = j.opt("voice")
            if (voiceRaw is JSONObject) {
                val keys = voiceRaw.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    voiceMap[k] = voiceRaw.optString(k)
                }
            } else if (voiceRaw is String && voiceRaw.isNotEmpty()) {
                voiceMap["en"] = voiceRaw
                voiceMap["ml"] = voiceRaw
            }
            return TutorCharacter(
                id = j.optString("id", "tutor"),
                name = parseLocalizedValue(j.opt("name")),
                shape = j.optString("shape", "blob"),
                colorValue = parsedColor,
                voice = voiceMap,
                eyes = j.optString("eyes", "round"),
                energy = j.optDouble("energy", 1.0).toFloat(),
                rate = j.optString("rate", "+0%"),
                pitch = j.optString("pitch", "+0Hz"),
                about = parseLocalizedValue(j.opt("about")),
                hello = parseLocalizedValue(j.opt("hello")),
                praise = parseLocalizedValue(j.opt("praise")),
                oops = parseLocalizedValue(j.opt("oops")),
                cheer = parseLocalizedValue(j.opt("cheer")),
                readyMade = j.optBoolean("ready_made", false)
            )
        }
    }
}

data class VisualSpec(
    val kind: String,
    val args: List<String> = emptyList(),
    val image: String = ""
) {
    companion object {
        fun fromJson(j: JSONObject?): VisualSpec? {
            if (j == null) return null
            val kind = j.optString("kind", "")
            if (kind.isEmpty()) return null
            val argsArr = j.optJSONArray("args")
            val args = if (argsArr != null) {
                (0 until argsArr.length()).map { argsArr.opt(it)?.toString() ?: "" }
            } else emptyList()
            return VisualSpec(
                kind = kind,
                args = args,
                image = j.optString("image", "")
            )
        }
    }
}

data class LessonStep(
    val type: String, // say | ask
    val text: Any?,
    val visual: VisualSpec? = null,
    val form: String = "", // choice | number | think | abacus | measure | build
    val options: List<String> = emptyList(),
    val optionsMl: List<String> = emptyList(),
    val answer: String = "",
    val hint: Any? = null,
    val explain: Any? = null,
    val concept: String = "",
    val level: Int = 1,
    val mistakes: Map<String, String> = emptyMap(),
    val label: String = ""
) {
    val isAsk: Boolean get() = type == "ask"

    fun isCorrect(given: String): Boolean =
        given.trim().equals(answer.trim(), ignoreCase = true)

    fun optionLabel(i: Int, lang: String): String =
        if (lang == "ml" && optionsMl.size == options.size) optionsMl[i] else options[i]

    companion object {
        fun fromJson(j: JSONObject): LessonStep {
            val optArr = j.optJSONArray("options")
            val options = if (optArr != null) {
                (0 until optArr.length()).map { optArr.opt(it)?.toString() ?: "" }
            } else emptyList()

            val optMlArr = j.optJSONArray("optionsMl")
            val optionsMl = if (optMlArr != null) {
                (0 until optMlArr.length()).map { optMlArr.opt(it)?.toString() ?: "" }
            } else emptyList()

            val mistakesMap = mutableMapOf<String, String>()
            val mistakesObj = j.optJSONObject("mistakes")
            if (mistakesObj != null) {
                val keys = mistakesObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    mistakesMap[k] = mistakesObj.optString(k)
                }
            }

            return LessonStep(
                type = j.optString("t", "say"),
                text = parseLocalizedValue(j.opt("text")),
                visual = VisualSpec.fromJson(j.optJSONObject("visual")),
                form = j.optString("form", ""),
                options = options,
                optionsMl = optionsMl,
                answer = j.opt("answer")?.takeIf { it != JSONObject.NULL }?.toString() ?: "",
                hint = parseLocalizedValue(j.opt("hint")),
                explain = parseLocalizedValue(j.opt("explain")),
                concept = j.optString("concept", ""),
                level = j.optInt("level", 1),
                mistakes = mistakesMap,
                label = j.optString("label", "")
            )
        }
    }
}

data class Lesson(
    val id: String,
    val title: Any?,
    val objective: Any? = null,
    val minutes: Int = 5,
    val steps: List<LessonStep>,
    val alts: Map<String, LessonStep> = emptyMap()
) {
    companion object {
        fun fromJson(j: JSONObject): Lesson {
            val stepsArr = j.optJSONArray("steps")
            val steps = if (stepsArr != null) {
                (0 until stepsArr.length()).mapNotNull {
                    stepsArr.optJSONObject(it)?.let { obj -> LessonStep.fromJson(obj) }
                }
            } else emptyList()

            val altsMap = mutableMapOf<String, LessonStep>()
            val altsObj = j.optJSONObject("alts")
            if (altsObj != null) {
                val keys = altsObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    val obj = altsObj.optJSONObject(k)
                    if (obj != null) {
                        val copy = JSONObject(obj.toString())
                        copy.put("t", "say")
                        copy.put("label", k)
                        altsMap[k] = LessonStep.fromJson(copy)
                    }
                }
            }

            return Lesson(
                id = j.optString("id"),
                title = parseLocalizedValue(j.opt("title")),
                objective = parseLocalizedValue(j.opt("objective")),
                minutes = j.optInt("minutes", 5),
                steps = steps,
                alts = altsMap
            )
        }
    }
}

data class Chapter(
    val id: String,
    val title: Any?,
    val verified: Boolean,
    val lessons: List<Lesson>
) {
    companion object {
        fun fromJson(j: JSONObject): Chapter {
            val arr = j.optJSONArray("lessons")
            val lessons = if (arr != null) {
                (0 until arr.length()).mapNotNull {
                    arr.optJSONObject(it)?.let { obj -> Lesson.fromJson(obj) }
                }
            } else emptyList()
            return Chapter(
                id = j.optString("id"),
                title = parseLocalizedValue(j.opt("title")),
                verified = j.optBoolean("verified", false),
                lessons = lessons
            )
        }
    }
}

data class Subject(
    val id: String,
    val key: String,
    val name: Any?,
    val icon: String,
    val colorValue: Long,
    val paletteValues: List<Long>,
    val chapters: List<Chapter>
) {
    val color: Color get() = Color(colorValue)
    val lessons: List<Lesson> get() = chapters.flatMap { it.lessons }

    companion object {
        fun fromJson(j: JSONObject): Subject {
            val hex = j.optString("color", "#5B6CFF").replace("#", "")
            val parsedColor = (hex.toLongOrNull(16) ?: 0x5B6CFFL) or 0xFF000000L

            val palArr = j.optJSONArray("palette")
            val palette = if (palArr != null) {
                (0 until palArr.length()).map { idx ->
                    val h = palArr.optString(idx, "#5B6CFF").replace("#", "")
                    (h.toLongOrNull(16) ?: 0x5B6CFFL) or 0xFF000000L
                }
            } else emptyList()

            val chArr = j.optJSONArray("chapters")
            val chapters = if (chArr != null) {
                (0 until chArr.length()).mapNotNull {
                    chArr.optJSONObject(it)?.let { obj -> Chapter.fromJson(obj) }
                }
            } else emptyList()

            return Subject(
                id = j.optString("id"),
                key = j.optString("key", ""),
                name = parseLocalizedValue(j.opt("name")),
                icon = j.optString("icon", "📘"),
                colorValue = parsedColor,
                paletteValues = palette,
                chapters = chapters
            )
        }
    }
}

data class SchoolClass(
    val number: Int,
    val subjects: List<Subject>
)

data class Board(
    val id: String,
    val name: Any?,
    val classes: List<SchoolClass>
)

data class Bundle(
    val version: String = "",
    val built: Long = 0L,
    val boards: List<Board> = emptyList(),
    val concepts: Map<String, Any?> = emptyMap(),
    val tutors: List<TutorCharacter> = listOf(TutorCharacter.fallback),
    val phrases: Map<String, Any?> = emptyMap(),
    val brain: Map<String, Any?> = emptyMap()
) {
    fun phrase(key: String, lang: String): String = pick(phrases[key], lang)

    fun tutor(id: String): TutorCharacter =
        tutors.firstOrNull { it.id == id } ?: tutors.firstOrNull() ?: TutorCharacter.fallback

    fun board(id: String): Board? = boards.firstOrNull { it.id == id }

    fun subjectsFor(boardId: String, classNumber: Int): List<Subject> {
        val b = board(boardId) ?: return emptyList()
        return b.classes.firstOrNull { it.number == classNumber }?.subjects ?: emptyList()
    }

    fun conceptName(key: String, lang: String): String {
        val n = pick(concepts[key], lang)
        return n.ifEmpty { key.substringAfterLast("#").replace("-", " ") }
    }

    companion object {
        fun parse(source: String): Bundle {
            val j = JSONObject(source)
            val tutorsArr = j.optJSONArray("tutors")
            val tutorsList = if (tutorsArr != null) {
                (0 until tutorsArr.length()).mapNotNull {
                    tutorsArr.optJSONObject(it)?.let { obj -> TutorCharacter.fromJson(obj) }
                }
            } else emptyList()

            val boardsArr = j.optJSONArray("boards")
            val boardsList = if (boardsArr != null) {
                (0 until boardsArr.length()).mapNotNull { bi ->
                    val bj = boardsArr.optJSONObject(bi) ?: return@mapNotNull null
                    val classesArr = bj.optJSONArray("classes")
                    val classesList = if (classesArr != null) {
                        (0 until classesArr.length()).mapNotNull { ci ->
                            val cj = classesArr.optJSONObject(ci) ?: return@mapNotNull null
                            val subsArr = cj.optJSONArray("subjects")
                            val subsList = if (subsArr != null) {
                                (0 until subsArr.length()).mapNotNull { si ->
                                    subsArr.optJSONObject(si)?.let { Subject.fromJson(it) }
                                }
                            } else emptyList()
                            SchoolClass(number = cj.optInt("number"), subjects = subsList)
                        }
                    } else emptyList()
                    Board(
                        id = bj.optString("id"),
                        name = parseLocalizedValue(bj.opt("name")),
                        classes = classesList
                    )
                }
            } else emptyList()

            @Suppress("UNCHECKED_CAST")
            val phrasesMap = (parseJsonValue(j.optJSONObject("phrases")) as? Map<String, Any?>) ?: emptyMap()
            @Suppress("UNCHECKED_CAST")
            val brainMap = (parseJsonValue(j.optJSONObject("brain")) as? Map<String, Any?>) ?: emptyMap()
            @Suppress("UNCHECKED_CAST")
            val conceptsMap = (parseJsonValue(j.optJSONObject("concepts")) as? Map<String, Any?>) ?: emptyMap()

            return Bundle(
                version = j.optString("version", ""),
                built = j.optLong("built", 0L),
                boards = boardsList,
                concepts = conceptsMap,
                tutors = if (tutorsList.isEmpty()) listOf(TutorCharacter.fallback) else tutorsList,
                phrases = phrasesMap,
                brain = brainMap
            )
        }
    }
}

// ---------------- Mastery Tracking (from app/lib/mastery.dart) ----------------
enum class Understanding {
    NOT_STARTED,
    NEEDS_HELP,
    MISCONCEPTION,
    CHECKING,
    SECURE
}

class ConceptRecord {
    var firstTry: Int = 0
    var withHelp: Int = 0
    var failed: Int = 0
    var quick: Int = 0
    var thinkYes: Int = 0
    var thinkNo: Int = 0
    var lastDay: Int = 0
    val forms: MutableSet<String> = mutableSetOf()
    val mistakes: MutableMap<String, Int> = mutableMapOf()
    val recent: MutableList<Int> = mutableListOf()

    val total: Int get() = firstTry + withHelp + failed + quick

    fun record(
        form: String,
        outcome: String, // first | help | failed
        day: Int,
        millis: Long = 5000L,
        mistakeNotes: List<String> = emptyList()
    ) {
        lastDay = day
        for (m in mistakeNotes) {
            mistakes[m] = (mistakes[m] ?: 0) + 1
        }
        if (form == "think") {
            if (outcome == "first") thinkYes++ else thinkNo++
            return
        }
        if (outcome == "first" && form == "choice" && millis < 1000L) {
            quick++
            return
        }
        when (outcome) {
            "first" -> {
                firstTry++
                forms.add(form)
            }
            "help" -> withHelp++
            else -> failed++
        }
        recent.add(if (outcome == "first") 1 else 0)
        if (recent.size > 6) recent.removeAt(0)
    }

    val repeatedMistake: String?
        get() {
            var best: String? = null
            var count = 1
            for ((k, v) in mistakes) {
                if (v > count) {
                    best = k
                    count = v
                }
            }
            return best
        }

    val status: Understanding
        get() {
            if (total == 0 && thinkYes + thinkNo == 0) return Understanding.NOT_STARTED
            val last3 = if (recent.size >= 3) recent.takeLast(3) else recent
            val last3Right = last3.size == 3 && last3.all { it == 1 }
            if (firstTry >= 3 && forms.size >= 2 && last3Right) return Understanding.SECURE
            val last2Right = recent.size >= 2 && recent[recent.size - 1] == 1 && recent[recent.size - 2] == 1
            if (repeatedMistake != null && !last2Right) return Understanding.MISCONCEPTION
            if (recent.isNotEmpty() && recent.last() == 1) return Understanding.CHECKING
            if (recent.isEmpty() && thinkYes > thinkNo) return Understanding.CHECKING
            return Understanding.NEEDS_HELP
        }

    fun needsRevision(today: Int): Boolean {
        val s = status
        if (s == Understanding.NEEDS_HELP || s == Understanding.MISCONCEPTION) return true
        return s == Understanding.SECURE && today - lastDay >= 7
    }

    fun toJson(): JSONObject = JSONObject().apply {
        put("f", firstTry)
        put("h", withHelp)
        put("x", failed)
        put("q", quick)
        put("ty", thinkYes)
        put("tn", thinkNo)
        put("d", lastDay)
        put("forms", JSONArray(forms.toList()))
        put("m", JSONObject(mistakes as Map<*, *>))
        put("r", JSONArray(recent))
    }

    companion object {
        fun fromJson(j: JSONObject): ConceptRecord {
            val r = ConceptRecord().apply {
                firstTry = j.optInt("f", 0)
                withHelp = j.optInt("h", 0)
                failed = j.optInt("x", 0)
                quick = j.optInt("q", 0)
                thinkYes = j.optInt("ty", 0)
                thinkNo = j.optInt("tn", 0)
                lastDay = j.optInt("d", 0)
            }
            j.optJSONArray("forms")?.let { arr ->
                for (i in 0 until arr.length()) r.forms.add(arr.optString(i))
            }
            j.optJSONObject("m")?.let { m ->
                val keys = m.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    r.mistakes[k] = m.optInt(k, 0)
                }
            }
            j.optJSONArray("r")?.let { arr ->
                for (i in 0 until arr.length()) r.recent.add(arr.optInt(i))
            }
            return r
        }
    }
}
