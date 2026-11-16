package com.example.scol.tutor

import com.example.scol.audio.ScolAudioEngine
import com.example.scol.model.*
import com.example.scol.network.TaughtStep
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.random.Random

enum class Phase { TALKING, ASKING, FEEDBACK, THINK_ASK, THINK_REVEAL, FINISHED }
enum class Spot { LEFT, CENTER, RIGHT }
enum class Mood { CALM, HAPPY, CARING }
enum class Look { CHILD, BOARD, ANSWERS }

private data class QueueItem(
    val step: LessonStep,
    val retry: Boolean = false,
    val style: String? = null
)

data class DirectorSnapshot(
    val stepIndex: Int = 0,
    val totalSteps: Int = 0,
    val progress: Float = 0f,
    val phase: Phase = Phase.TALKING,
    val spot: Spot = Spot.LEFT,
    val mood: Mood = Mood.CALM,
    val look: Look = Look.CHILD,
    val bubble: String = "",
    val badge: String = "",
    val lessonLine: String = "",
    val taughtByBrain: Boolean = false,
    val visual: VisualSpec? = null,
    val question: LessonStep? = null,
    val current: LessonStep? = null,
    val wrongOptions: Set<String> = emptySet(),
    val hintShown: Boolean = false,
    val canHint: Boolean = false,
    val starsEarned: Int = 3,
    val xpEarned: Int = 10,
    val touches: List<Int> = emptyList(),
    val lang: String = "en",
    val hopCounter: Int = 0,
    val updateTick: Int = 0
)

class TutorDirector(
    val lesson: Lesson,
    initialLang: String,
    initialTone: String = "normal",
    val tutor: TutorCharacter,
    private val recordFor: (String) -> ConceptRecord,
    private val day: Int,
    private val phrases: Map<String, Any?> = emptyMap(),
    private val audio: ScolAudioEngine? = null,
    private val pickStyle: ((List<String>) -> String)? = null,
    private val onStyleResult: ((String, Boolean) -> Unit)? = null,
    val childName: String = "",
    waitForTeaching: Boolean = false,
    greet: Boolean = true
) {
    var tone: String = initialTone
        private set

    fun updateTone(newTone: String) {
        tone = newTone
    }
    private val rnd = Random.Default
    private val queue = lesson.steps.map { QueueItem(it) }.toMutableList()
    private val usedStyles = mutableSetOf<String>()
    private var styleReported = false
    private var index = 0
    private var teaching: List<TaughtStep?>? = null
    private var intro = ""
    private var introSaid = false
    private var hold = waitForTeaching
    private var attempts = 0
    private val mistakes = mutableListOf<String>()
    private var askedAtMs = System.currentTimeMillis()
    private var questionsCount = 0
    private var firstTryRight = 0
    private var hopCounter = 0

    var lang: String = initialLang
        private set

    private val _snapshot = MutableStateFlow(DirectorSnapshot(lang = initialLang))
    val snapshot: StateFlow<DirectorSnapshot> = _snapshot.asStateFlow()

    private var currentSpot = Spot.LEFT
    private var currentMood = Mood.CALM
    private var currentLook = Look.CHILD
    private var currentPhase = Phase.TALKING
    private var currentBubble = ""
    private var currentBadge = ""
    private var currentVisual: VisualSpec? = null
    private var currentQuestion: LessonStep? = null
    private val wrongOptions = mutableSetOf<String>()
    private var hintShown = false

    init {
        if (greet) intro = pickIntro()
        enterStep()
    }

    private fun pickIntro(): String {
        val map = phrases["intro"] as? Map<*, *> ?: return ""
        val raw = map[lang] ?: map["en"]
        val rawList = (raw as? List<*>)?.mapNotNull { it?.toString() } ?: return ""
        var options = rawList
        if (childName.trim().isEmpty()) {
            options = options.filter { !it.contains("{name}") }
        }
        if (options.isEmpty()) return ""
        return options[rnd.nextInt(options.size)].replace("{name}", childName.trim())
    }

    private fun ph(key: String): String {
        val p = pick(phrases[key], lang)
        return p.ifEmpty { tr(key, lang) }
    }

    private val praiseList: List<String>
        get() = if (tone == "strict") listOf(ph("praiseStrict")) else tutor.praiseList(lang)

    private val oopsText: String
        get() = if (tone == "strict") ph("oopsStrict") else pick(tutor.oops, lang)

    private fun taught(step: LessonStep): TaughtStep? {
        val t = teaching ?: return null
        val i = lesson.steps.indexOfFirst { it === step }
        return if (i in t.indices) t[i] else null
    }

    fun setTeaching(perStep: List<TaughtStep?>?) {
        teaching = if (perStep != null && perStep.size == lesson.steps.size) perStep else null
        val curPhase = _snapshot.value.phase
        val again = hold || (curPhase == Phase.TALKING && teaching != null)
        hold = false
        if (again) {
            enterStep()
        } else {
            emitState()
        }
    }

    fun stopWaiting() {
        if (!hold) return
        hold = false
        val p = _snapshot.value.phase
        if (p == Phase.TALKING || p == Phase.ASKING || p == Phase.THINK_ASK) {
            enterStep()
        }
    }

    fun setLang(newLang: String) {
        if (newLang == lang) return
        lang = newLang
        teaching = null
        if (intro.isNotEmpty() && !introSaid) intro = pickIntro()
        val p = _snapshot.value.phase
        if (p == Phase.TALKING || p == Phase.ASKING || p == Phase.THINK_ASK) {
            enterStep()
        } else {
            emitState()
        }
    }

    private fun say(parts: List<String>) {
        val said = parts.filter { it.isNotEmpty() }
        currentBubble = said.joinToString(" ")
        if (!hold) audio?.say(said, lang, tutor, tone)
    }

    private fun enterStep() {
        if (index >= queue.size) {
            currentPhase = Phase.FINISHED
            currentQuestion = null
            currentMood = Mood.HAPPY
            currentSpot = Spot.CENTER
            currentLook = Look.CHILD
            audio?.stop()
            emitState()
            return
        }
        val item = queue[index]
        val step = item.step
        currentVisual = step.visual
        wrongOptions.clear()
        hintShown = false
        attempts = 0
        mistakes.clear()
        currentMood = Mood.CALM
        styleReported = false
        currentBadge = if (step.label in listOf("example", "story", "picture")) tr(step.label, lang) else ""
        val text = pick(step.text, lang)

        if (!step.isAsk) {
            currentQuestion = null
            currentPhase = Phase.TALKING
            currentSpot = if (currentVisual == null) Spot.CENTER else if (index % 2 == 0) Spot.LEFT else Spot.RIGHT
            currentLook = if (currentVisual == null) Look.CHILD else Look.BOARD
            val hello = if (index == 0 && !introSaid) intro else ""
            if (hello.isNotEmpty() && !hold) introSaid = true
            say(listOf(hello, taught(step)?.say ?: text))
        } else {
            hold = false
            currentQuestion = step
            currentPhase = if (step.form == "think") Phase.THINK_ASK else Phase.ASKING
            currentSpot = Spot.RIGHT
            currentLook = Look.ANSWERS
            askedAtMs = System.currentTimeMillis()
            say(if (item.retry) listOf(ph("again"), text) else listOf(text))
        }
        hopCounter++
        emitState()
    }

    fun next() {
        if (currentPhase == Phase.TALKING || currentPhase == Phase.FEEDBACK) {
            index++
            enterStep()
        }
    }

    fun tutorSays(text: String) {
        if (text.trim().isEmpty()) return
        currentMood = Mood.HAPPY
        currentLook = Look.CHILD
        currentBadge = ""
        say(listOf(text))
        emitState()
    }

    fun showHint() {
        val q = currentQuestion ?: return
        if (currentPhase != Phase.ASKING || hintShown) return
        val hintText = pick(q.hint, lang)
        if (hintText.isEmpty()) return
        hintShown = true
        currentMood = Mood.CARING
        currentLook = Look.BOARD
        say(listOf(hintText))
        emitState()
    }

    fun answer(given: String) {
        val q = currentQuestion ?: return
        if (currentPhase != Phase.ASKING) return
        val millis = System.currentTimeMillis() - askedAtMs
        val style = queue[index].style
        if (style != null && !styleReported) {
            styleReported = true
            onStyleResult?.invoke(style, q.isCorrect(given) && attempts == 0)
        }

        if (q.isCorrect(given)) {
            audio?.playSound("correct")
            val clean = attempts == 0 && !hintShown && !queue[index].retry
            finishQuestion(if (clean) "first" else "help", millis)
            currentMood = Mood.HAPPY
            currentLook = Look.CHILD
            val praise = praiseList
            val explain = pick(q.explain, lang)
            say(if (clean || explain.isEmpty()) listOf(praise[rnd.nextInt(praise.size)]) else listOf(praise.first(), explain))
        } else {
            audio?.playSound("oops")
            attempts++
            wrongOptions.add(given)
            q.mistakes[given]?.let { mistakes.add(it) }
            currentMood = Mood.CARING
            val oops = oopsText
            if (attempts == 1) {
                val hint = pick(q.hint, lang)
                hintShown = true
                currentLook = Look.BOARD
                say(listOf(oops, hint.ifEmpty { ph("lookAgain") }))
            } else {
                finishQuestion("failed", millis)
                currentLook = Look.CHILD
                val explain = pick(q.explain, lang)
                val shown = if (q.options.contains(q.answer)) q.optionLabel(q.options.indexOf(q.answer), lang) else q.answer
                val body = explain.ifEmpty { "${tr("answerIs", lang)} $shown." }
                val alreadyQueued = queue.drop(index + 1).any { it.retry && it.step === q }
                val left = lesson.alts.keys.filter { !usedStyles.contains(it) }
                if (!queue[index].retry && !alreadyQueued && left.isNotEmpty()) {
                    val mode = pickStyle?.invoke(left) ?: left.first()
                    val chosen = if (left.contains(mode)) mode else left.first()
                    usedStyles.add(chosen)
                    queue.addAll(index + 1, listOf(QueueItem(lesson.alts[chosen]!!), QueueItem(q, retry = true, style = chosen)))
                    say(listOf(body, ph("anotherWay")))
                } else if (!queue[index].retry && !alreadyQueued) {
                    queue.add(QueueItem(q, retry = true))
                    say(listOf(body, ph("tryLater")))
                } else {
                    say(listOf(body))
                }
            }
        }
        emitState()
    }

    private fun finishQuestion(outcome: String, millis: Long) {
        val q = currentQuestion ?: return
        questionsCount++
        if (outcome == "first") firstTryRight++
        recordFor(q.concept).record(
            form = q.form,
            outcome = outcome,
            day = day,
            millis = millis,
            mistakeNotes = mistakes.toList()
        )
        currentPhase = Phase.FEEDBACK
    }

    fun revealThink() {
        val q = currentQuestion ?: return
        if (currentPhase != Phase.THINK_ASK) return
        currentPhase = Phase.THINK_REVEAL
        currentLook = Look.CHILD
        say(listOf(q.answer))
        emitState()
    }

    fun rateThink(gotIt: Boolean) {
        val q = currentQuestion ?: return
        if (currentPhase != Phase.THINK_REVEAL) return
        recordFor(q.concept).record(form = "think", outcome = if (gotIt) "first" else "failed", day = day)
        index++
        enterStep()
    }

    private fun emitState() {
        val step = queue.getOrNull(index)?.step
        val taughtStep = step?.let { taught(it) }
        val touchesList = if (step != null && currentPhase == Phase.TALKING) {
            taughtStep?.touch ?: if (step.visual != null) listOf(-1) else emptyList()
        } else emptyList()

        val stars = if (questionsCount == 0) 3 else {
            val share = firstTryRight.toFloat() / questionsCount
            if (share >= 0.99f) 3 else if (share >= 0.6f) 2 else 1
        }
        val xp = 10 + 5 * firstTryRight
        val total = queue.size
        val prog = if (total == 0) 1f else (index.toFloat() / total).coerceIn(0f, 1f)

        _snapshot.value = DirectorSnapshot(
            stepIndex = index,
            totalSteps = total,
            progress = prog,
            phase = currentPhase,
            spot = currentSpot,
            mood = currentMood,
            look = currentLook,
            bubble = currentBubble,
            badge = currentBadge,
            lessonLine = step?.let { pick(it.text, lang) } ?: "",
            taughtByBrain = currentPhase == Phase.TALKING && step != null && taughtStep != null,
            visual = currentVisual,
            question = currentQuestion,
            current = step,
            wrongOptions = wrongOptions.toSet(),
            hintShown = hintShown,
            canHint = currentPhase == Phase.ASKING && !hintShown && pick(currentQuestion?.hint, lang).isNotEmpty(),
            starsEarned = stars,
            xpEarned = xp,
            touches = touchesList,
            lang = lang,
            hopCounter = hopCounter,
            updateTick = _snapshot.value.updateTick + 1
        )
    }
}
