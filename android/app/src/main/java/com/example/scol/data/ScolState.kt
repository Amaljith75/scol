package com.example.scol.data

import android.content.Context
import com.example.scol.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

fun dayNumber(): Int = (System.currentTimeMillis() / 86_400_000L).toInt()

data class AppStateSnapshot(
    val onboarded: Boolean = false,
    val childName: String = "",
    val boardId: String = "kerala-scert",
    val classNumber: Int = 3,
    val lang: String = "en", // en | ml | both
    val bothMain: String = "ml",
    val tone: String = "normal", // happy | normal | calm | strict
    val tutorId: String = "koko", // Ollie default as requested
    val voiceOn: Boolean = true,
    val dailyLimitMin: Int = 30,
    val askEnabled: Boolean = false,
    val teachOn: Boolean = true,
    val remindersOn: Boolean = true,
    val studyMinute: Int = 18 * 60,
    val subjectKeys: List<String> = emptyList(),
    val stars: Int = 0,
    val xp: Int = 0,
    val streak: Int = 0,
    val bestStreak: Int = 0,
    val learningDays: Int = 0,
    val lastActiveDay: Int = 0,
    val today: Int = 0,
    val todaySeconds: Int = 0,
    val todayLessons: Int = 0,
    val lessonStars: Map<String, Int> = emptyMap(),
    val versionTick: Int = 0
) {
    val bilingual: Boolean get() = lang == "both"
    val mainLang: String get() = if (lang == "both") bothMain else lang
    val dailyGoal: Int get() = 2
    val timeUp: Boolean get() = todaySeconds >= dailyLimitMin * 60
    val liveStreak: Int get() = if (lastActiveDay >= dayNumber() - 1) streak else 0
}

class ScolRepository(private val context: Context) {
    private val prefs = context.getSharedPreferences("scol_state_prefs", Context.MODE_PRIVATE)
    private val stateKey = "scol_state_v1"
    private val cacheKey = "content_cache_v1"

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(12, TimeUnit.SECONDS)
        .build()

    private val _bundle = MutableStateFlow(Bundle())
    val bundle: StateFlow<Bundle> = _bundle.asStateFlow()

    private val _state = MutableStateFlow(AppStateSnapshot())
    val state: StateFlow<AppStateSnapshot> = _state.asStateFlow()

    val concepts: MutableMap<String, ConceptRecord> = mutableMapOf()
    val history: MutableMap<Int, IntArray> = mutableMapOf() // day -> [seconds, lessons]
    val styleStats: MutableMap<String, IntArray> = mutableMapOf() // style -> [worked, tried]

    init {
        loadBundleFromAssets()
        loadAppState()
    }

    private fun loadBundleFromAssets() {
        try {
            val raw = context.assets.open("content/bundle.json").bufferedReader().use { it.readText() }
            var b = Bundle.parse(raw)
            val cached = prefs.getString(cacheKey, null)
            if (cached != null) {
                try {
                    val c = Bundle.parse(cached)
                    if (c.built > b.built && c.boards.isNotEmpty()) b = c
                } catch (_: Exception) {
                }
            }
            _bundle.value = b
        } catch (_: Exception) {
        }
    }

    suspend fun refreshBundleOnline(): Boolean = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder().url(CONTENT_URL).build()
            httpClient.newCall(req).execute().use { res ->
                if (!res.isSuccessful) return@withContext false
                val body = res.body?.string() ?: return@withContext false
                val fresh = Bundle.parse(body)
                if (fresh.built > _bundle.value.built && fresh.boards.isNotEmpty()) {
                    _bundle.value = fresh
                    prefs.edit().putString(cacheKey, body).apply()
                    return@withContext true
                }
            }
        } catch (_: Exception) {
        }
        false
    }

    private fun loadAppState() {
        val raw = prefs.getString(stateKey, null)
        if (raw != null) {
            try {
                fromJson(JSONObject(raw))
            } catch (_: Exception) {
            }
        }
        rollDay()
    }

    private fun rollDay() {
        val d = dayNumber()
        val cur = _state.value
        if (cur.today != d) {
            _state.value = cur.copy(today = d, todaySeconds = 0, todayLessons = 0)
        }
    }

    fun updateState(transform: (AppStateSnapshot) -> AppStateSnapshot) {
        val updated = transform(_state.value)
        _state.value = updated.copy(versionTick = updated.versionTick + 1)
        save()
    }

    fun switchLang() {
        updateState { cur ->
            if (cur.bilingual) {
                cur.copy(bothMain = if (cur.bothMain == "ml") "en" else "ml")
            } else {
                cur.copy(lang = if (cur.lang == "ml") "en" else "ml")
            }
        }
    }

    fun save() {
        try {
            prefs.edit().putString(stateKey, toJson().toString()).apply()
        } catch (_: Exception) {
        }
    }

    fun eraseEverything() {
        concepts.clear()
        history.clear()
        styleStats.clear()
        _state.value = AppStateSnapshot(today = dayNumber())
        prefs.edit().remove(stateKey).apply()
    }

    fun concept(key: String): ConceptRecord = concepts.getOrPut(key) { ConceptRecord() }

    fun addLearningTime(seconds: Int) {
        rollDay()
        val d = _state.value.today
        val arr = history.getOrPut(d) { intArrayOf(0, 0) }
        arr[0] += seconds
        history.keys.filter { it < d - 40 }.forEach { history.remove(it) }
        updateState { it.copy(todaySeconds = it.todaySeconds + seconds) }
    }

    fun pickStyle(available: List<String>): String {
        for (s in available) {
            if ((styleStats[s]?.get(1) ?: 0) == 0) return s
        }
        fun rate(s: String): Double {
            val v = styleStats[s] ?: return 0.0
            return if (v[1] == 0) 0.0 else v[0].toDouble() / v[1]
        }
        return available.maxByOrNull { rate(it) } ?: available.first()
    }

    fun recordStyle(style: String, worked: Boolean) {
        val st = styleStats.getOrPut(style) { intArrayOf(0, 0) }
        st[1]++
        if (worked) st[0]++
        save()
    }

    val bestStyle: String?
        get() {
            val tried = styleStats.values.sumOf { it[1] }
            if (tried < 3 || styleStats.isEmpty()) return null
            var best: String? = null
            var bestRate = 0.0
            for ((k, v) in styleStats) {
                val r = if (v[1] == 0) 0.0 else v[0].toDouble() / v[1]
                if (r > bestRate) {
                    bestRate = r
                    best = k
                }
            }
            return best
        }

    fun weekTotals(): Triple<Int, Int, Int> {
        val t = dayNumber()
        var days = 0
        var secs = 0
        var levels = 0
        for ((d, v) in history) {
            if (d > t - 7 && d <= t && (v[0] > 0 || v[1] > 0)) {
                days++
                secs += v[0]
                levels += v[1]
            }
        }
        val mins = (secs + 59) / 60
        return Triple(days, mins, levels)
    }

    fun finishLesson(lessonId: String, earnedStars: Int, earnedXp: Int): Boolean {
        rollDay()
        val cur = _state.value
        val before = cur.lessonStars[lessonId] ?: 0
        var newStars = cur.stars
        val updatedLessonStars = cur.lessonStars.toMutableMap()
        if (earnedStars > before) {
            newStars += (earnedStars - before)
            updatedLessonStars[lessonId] = earnedStars
        }
        val d = cur.today
        val arr = history.getOrPut(d) { intArrayOf(0, 0) }
        arr[1]++

        var newDay = false
        var newLearningDays = cur.learningDays
        var newStreak = cur.streak
        var newBest = cur.bestStreak
        var newLastActive = cur.lastActiveDay
        if (cur.lastActiveDay != d) {
            newDay = true
            newLearningDays++
            newStreak = if (cur.lastActiveDay == d - 1) cur.streak + 1 else 1
            if (newStreak > newBest) newBest = newStreak
            newLastActive = d
        }

        _state.value = cur.copy(
            stars = newStars,
            xp = cur.xp + earnedXp,
            todayLessons = cur.todayLessons + 1,
            learningDays = newLearningDays,
            streak = newStreak,
            bestStreak = newBest,
            lastActiveDay = newLastActive,
            lessonStars = updatedLessonStars,
            versionTick = cur.versionTick + 1
        )
        save()
        return newDay
    }

    fun mySubjects(): List<Subject> {
        val cur = _state.value
        val all = _bundle.value.subjectsFor(cur.boardId, cur.classNumber)
        val mine = if (cur.subjectKeys.isEmpty()) all else all.filter { cur.subjectKeys.contains(it.key) }
        return mine.filter { it.lessons.isNotEmpty() } + mine.filter { it.lessons.isEmpty() }
    }

    fun isDone(lesson: Lesson): Boolean = _state.value.lessonStars.containsKey(lesson.id)

    fun nextLesson(subject: Subject): Lesson? = subject.lessons.firstOrNull { !isDone(it) }

    fun weakConcepts(subject: Subject): List<String> {
        val today = dayNumber()
        val keys = linkedSetOf<String>()
        for (l in subject.lessons) {
            for (st in l.steps) {
                if (st.isAsk && concepts[st.concept]?.needsRevision(today) == true) {
                    keys.add(st.concept)
                }
            }
        }
        return keys.toList()
    }

    fun revisionLesson(subject: Subject): Lesson? {
        val weak = weakConcepts(subject).toSet()
        if (weak.isEmpty()) return null
        val qs = subject.lessons
            .filter { isDone(it) }
            .flatMap { it.steps }
            .filter { it.isAsk && weak.contains(it.concept) }
            .shuffled()
            .take(5)
        if (qs.isEmpty()) return null
        return Lesson(
            id = "${subject.id}/revision",
            title = mapOf("en" to "Practice time", "ml" to "പരിശീലന സമയം"),
            steps = listOf(
                LessonStep(
                    type = "say",
                    text = mapOf(
                        "en" to "Some of these were tricky last time. Let us try them again, slowly.",
                        "ml" to "കഴിഞ്ഞ തവണ ഇവയിൽ ചിലത് അല്പം പ്രയാസമായിരുന്നു. നമുക്ക് പതുക്കെ ഒന്നുകൂടി നോക്കാം."
                    )
                )
            ) + qs
        )
    }

    fun weeklyReport(lang: String): List<String> {
        val ml = lang == "ml"
        val cur = _state.value
        val b = _bundle.value
        val name = cur.childName.ifBlank { if (ml) "കുട്ടി" else "Your child" }
        val (days, mins, levels) = weekTotals()
        val out = mutableListOf<String>()
        out.add(if (ml) "$name: ഈ ആഴ്ചയിലെ പഠന റിപ്പോർട്ട് (Scol)" else "$name's learning this week (Scol)")
        if (days == 0) {
            out.add(
                if (ml) "ഈ ആഴ്ച $name Scol-ൽ പഠിച്ചിട്ടില്ല. ദിവസവും 10 മിനിറ്റ് മതി. ഒരുമിച്ച് ഒരു ലെവൽ ചെയ്തു തുടങ്ങാം."
                else "$name has not used Scol this week. Ten minutes a day is enough. Try starting one level together."
            )
        } else {
            out.add(
                if (ml) "ഈ ആഴ്ച $name $days ദിവസം പഠിച്ചു, ആകെ ഏകദേശം $mins മിനിറ്റ്. $levels ലെവലുകൾ പൂർത്തിയാക്കി. ഇതുവരെ ${cur.stars} നക്ഷത്രങ്ങൾ നേടി."
                else "This week $name learned on $days ${if (days == 1) "day" else "days"}, about $mins minutes in all, and finished $levels ${if (levels == 1) "level" else "levels"}. Stars so far: ${cur.stars}."
            )
        }

        val secure = mutableListOf<String>()
        val checking = mutableListOf<String>()
        val weak = mutableListOf<String>()
        val repeated = mutableListOf<String>()

        for ((key, r) in concepts) {
            val n = b.conceptName(key, lang)
            when (r.status) {
                Understanding.SECURE -> secure.add(n)
                Understanding.CHECKING -> checking.add(n)
                Understanding.MISCONCEPTION -> {
                    weak.add(n)
                    val m = r.repeatedMistake
                    if (m != null) repeated.add(if (ml) n else "$n ($m)")
                }
                Understanding.NEEDS_HELP -> weak.add(n)
                Understanding.NOT_STARTED -> {}
            }
        }

        fun formatList(xs: List<String>): String =
            xs.take(6).joinToString(", ") + if (xs.size > 6) (if (ml) " തുടങ്ങിയവ" else " and more") else ""

        if (secure.isNotEmpty()) {
            out.add(if (ml) "നന്നായി മനസ്സിലാക്കിയവ: ${formatList(secure)}." else "Understands well: ${formatList(secure)}.")
        }
        if (checking.isNotEmpty()) {
            out.add(if (ml) "ശരിയായി വരുന്നുണ്ട്, കുറച്ചുകൂടി പരിശോധിക്കാനുണ്ട്: ${formatList(checking)}." else "Getting these right so far; Scol will check a few more times: ${formatList(checking)}.")
        }
        if (weak.isNotEmpty()) {
            out.add(if (ml) "ഇനിയും പരിശീലനം വേണ്ടവ: ${formatList(weak)}. ഇവ Scol വീണ്ടും പഠിപ്പിക്കും." else "Still needs practice: ${formatList(weak)}. Scol will teach these again.")
        }
        if (repeated.isNotEmpty()) {
            out.add(if (ml) "ഒരേ തെറ്റ് ആവർത്തിക്കുന്നത്: ${formatList(repeated)}. വീട്ടിൽ ചെറിയ സാധനങ്ങൾ വെച്ച് ഇത് ഒരുമിച്ച് ചെയ്തു നോക്കുന്നത് സഹായിക്കും." else "The same mistake keeps coming up in: ${formatList(repeated)}. Trying it together at home with small objects will help.")
        }
        if (secure.isEmpty() && checking.isEmpty() && weak.isEmpty()) {
            out.add(if (ml) "എന്തെല്ലാം മനസ്സിലായി എന്ന് പറയാൻ ഇനിയും കുറച്ച് ലെവലുകൾ കൂടി വേണം." else "A few more levels are needed before Scol can say what has been understood.")
        }

        val bs = bestStyle
        if (bs != null) {
            out.add(
                if (ml) {
                    if (bs == "story") "$name-ന് കഥകളിലൂടെ വിശദീകരിക്കുമ്പോഴാണ് കൂടുതൽ മനസ്സിലാകുന്നത്."
                    else "$name-ന് ചിത്രങ്ങളിലൂടെ വിശദീകരിക്കുമ്പോഴാണ് കൂടുതൽ മനസ്സിലാകുന്നത്."
                } else {
                    if (bs == "story") "$name seems to understand best when an idea is told as a story."
                    else "$name seems to understand best when an idea is shown as a picture."
                }
            )
        }
        return out
    }

    fun progressFacts(lang: String): String {
        val name = _state.value.childName.trim()
        val lines = weeklyReport(lang)
        return lines.joinToString("\n") { l -> if (name.isEmpty()) l else l.replace(name, "{name}") }
    }

    private fun toJson(): JSONObject {
        val cur = _state.value
        return JSONObject().apply {
            put("onboarded", cur.onboarded)
            put("childName", cur.childName)
            put("boardId", cur.boardId)
            put("classNumber", cur.classNumber)
            put("lang", cur.lang)
            put("bothMain", cur.bothMain)
            put("tone", cur.tone)
            put("tutorId", cur.tutorId)
            put("voiceOn", cur.voiceOn)
            put("dailyLimitMin", cur.dailyLimitMin)
            put("askEnabled", cur.askEnabled)
            put("teachOn", cur.teachOn)
            put("remindersOn", cur.remindersOn)
            put("studyMinute", cur.studyMinute)
            put("subjectKeys", JSONArray(cur.subjectKeys))
            put("stars", cur.stars)
            put("xp", cur.xp)
            put("streak", cur.streak)
            put("bestStreak", cur.bestStreak)
            put("learningDays", cur.learningDays)
            put("lastActiveDay", cur.lastActiveDay)
            put("today", cur.today)
            put("todaySeconds", cur.todaySeconds)
            put("todayLessons", cur.todayLessons)
            put("lessonStars", JSONObject(cur.lessonStars as Map<*, *>))
            put("concepts", JSONObject().apply {
                concepts.forEach { (k, v) -> put(k, v.toJson()) }
            })
            put("history", JSONObject().apply {
                history.forEach { (k, v) -> put(k.toString(), JSONArray(listOf(v[0], v[1]))) }
            })
            put("styleStats", JSONObject().apply {
                styleStats.forEach { (k, v) -> put(k, JSONArray(listOf(v[0], v[1]))) }
            })
        }
    }

    private fun fromJson(j: JSONObject) {
        val subjectsArr = j.optJSONArray("subjectKeys")
        val subjects = if (subjectsArr != null) {
            (0 until subjectsArr.length()).map { subjectsArr.optString(it) }
        } else emptyList()

        val lStars = mutableMapOf<String, Int>()
        j.optJSONObject("lessonStars")?.let { obj ->
            val keys = obj.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                lStars[k] = obj.optInt(k, 0)
            }
        }

        concepts.clear()
        j.optJSONObject("concepts")?.let { obj ->
            val keys = obj.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                obj.optJSONObject(k)?.let { concepts[k] = ConceptRecord.fromJson(it) }
            }
        }

        history.clear()
        j.optJSONObject("history")?.let { obj ->
            val keys = obj.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val d = k.toIntOrNull()
                val arr = obj.optJSONArray(k)
                if (d != null && arr != null && arr.length() == 2) {
                    history[d] = intArrayOf(arr.optInt(0), arr.optInt(1))
                }
            }
        }

        styleStats.clear()
        j.optJSONObject("styleStats")?.let { obj ->
            val keys = obj.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val arr = obj.optJSONArray(k)
                if (arr != null && arr.length() == 2) {
                    styleStats[k] = intArrayOf(arr.optInt(0), arr.optInt(1))
                }
            }
        }

        _state.value = AppStateSnapshot(
            onboarded = j.optBoolean("onboarded", false),
            childName = j.optString("childName", ""),
            boardId = j.optString("boardId", "kerala-scert"),
            classNumber = j.optInt("classNumber", 3),
            lang = j.optString("lang", "en"),
            bothMain = j.optString("bothMain", "ml"),
            tone = j.optString("tone", "normal"),
            tutorId = j.optString("tutorId", "koko"),
            voiceOn = j.optBoolean("voiceOn", true),
            dailyLimitMin = j.optInt("dailyLimitMin", 30),
            askEnabled = j.optBoolean("askEnabled", false),
            teachOn = j.optBoolean("teachOn", true),
            remindersOn = j.optBoolean("remindersOn", true),
            studyMinute = j.optInt("studyMinute", 18 * 60),
            subjectKeys = subjects,
            stars = j.optInt("stars", 0),
            xp = j.optInt("xp", 0),
            streak = j.optInt("streak", 0),
            bestStreak = j.optInt("bestStreak", 0),
            learningDays = j.optInt("learningDays", 0),
            lastActiveDay = j.optInt("lastActiveDay", 0),
            today = j.optInt("today", 0),
            todaySeconds = j.optInt("todaySeconds", 0),
            todayLessons = j.optInt("todayLessons", 0),
            lessonStars = lStars
        )
    }
}
