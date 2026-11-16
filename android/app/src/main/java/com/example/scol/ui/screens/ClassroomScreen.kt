package com.example.scol.ui.screens

import android.app.Activity
import android.graphics.Bitmap
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.BuildConfig
import com.example.scol.audio.ScolAudioEngine
import com.example.scol.data.ScolRepository
import com.example.scol.data.dayNumber
import com.example.scol.model.*
import com.example.scol.network.GeminiLiveClient
import com.example.scol.network.LiveConnectionState
import com.example.scol.network.LiveTutorSessionConfig
import com.example.scol.network.TutorBrainClient
import com.example.scol.tutor.*
import com.example.scol.ui.components.*
import com.example.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

data class CelebrationResult(
    val stars: Int,
    val xp: Int,
    val newDay: Boolean
)

@Composable
fun ClassroomScreen(
    subject: Subject,
    lesson: Lesson,
    repository: ScolRepository,
    audio: ScolAudioEngine,
    brain: TutorBrainClient,
    liveClient: GeminiLiveClient,
    onClose: () -> Unit,
    onOpenAsk: (lessonTitle: String, notes: String) -> Unit
) {
    val bundle by repository.bundle.collectAsState()
    val appState by repository.state.collectAsState()
    val speaking by audio.speaking.collectAsState()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val rootView = LocalView.current
    val window = remember(context) { context.findActivity()?.window }

    val hasGeminiKey = remember {
        val k = BuildConfig.GEMINI_API_KEY.trim()
        k.isNotEmpty() && k != "MY_GEMINI_API_KEY"
    }

    val brainTeaches = remember(lesson.id, appState.teachOn, bundle, hasGeminiKey) {
        appState.teachOn &&
            !lesson.id.endsWith("/revision") &&
            (hasGeminiKey || (bundle.brain["url"]?.toString() ?: "").isNotEmpty())
    }

    val director = remember(lesson.id) {
        TutorDirector(
            lesson = lesson,
            initialLang = appState.mainLang,
            initialTone = appState.tone,
            tutor = bundle.tutor(appState.tutorId),
            recordFor = { key -> repository.concept(key) },
            day = dayNumber(),
            phrases = bundle.phrases,
            audio = if (appState.voiceOn) audio else null,
            pickStyle = { available -> repository.pickStyle(available) },
            onStyleResult = { style, worked -> repository.recordStyle(style, worked) },
            childName = appState.childName,
            waitForTeaching = brainTeaches
        )
    }

    LaunchedEffect(appState.tone) {
        director.updateTone(appState.tone)
    }

    val snap by director.snapshot.collectAsState()
    var celebration by remember { mutableStateOf<CelebrationResult?>(null) }

    // Learning time stopwatch
    var startedAtMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    fun logTime() {
        val elapsedSec = ((System.currentTimeMillis() - startedAtMs) / 1000L).toInt().coerceIn(0, 20 * 60)
        startedAtMs = System.currentTimeMillis()
        if (elapsedSec > 0) repository.addLearningTime(elapsedSec)
    }

    // Interactive input state
    var typed by remember(snap.question) { mutableStateOf("") }
    var beads by remember(snap.question) { mutableStateOf(listOf(0, 0, 0)) }
    var explaining by remember { mutableStateOf(false) }

    // Gemini Live real-time board & camera tutor state
    var liveOpen by remember { mutableStateOf(false) }
    var cameraMode by remember { mutableStateOf(false) }
    var boardBoundsInRoot by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    var boardPreview by remember { mutableStateOf<Bitmap?>(null) }
    val liveConnState by liveClient.connectionState.collectAsState()

    // Peek + Walk gaze state
    var peek by remember { mutableStateOf(false) }
    var lastSpot by remember { mutableStateOf(snap.spot) }
    var walkLook by remember { mutableStateOf<Offset?>(null) }

    // Board tour state: root coordinate tracking
    var rootOffset by remember { mutableStateOf(Offset.Zero) }
    var rootSize by remember { mutableStateOf(Offset.Zero) }
    var homeCenterRoot by remember { mutableStateOf<Offset?>(null) }
    val boardTargets = remember { mutableStateMapOf<Int, Offset>() }
    var tourAtRoot by remember { mutableStateOf<Offset?>(null) }

    val notes = remember(lesson) {
        lesson.steps.filter { !it.isAsk }.joinToString(" ") { pick(it.text, "en") }
    }

    fun buildVisualSummary(): String {
        val q = snap.question
        if (q != null && snap.phase == Phase.ASKING) {
            return when (q.form) {
                "abacus" -> "Interactive Abacus: 100s=${beads[0]}, 10s=${beads[1]}, 1s=${beads[2]}"
                "measure" -> "Sliding Ruler ScaleBoard measuring ${q.visual?.args?.joinToString(" ") ?: "object"}"
                "build" -> "StickBuilder with shapes ${q.options.joinToString(", ")}"
                else -> "${q.visual?.kind ?: ""} ${q.visual?.args?.joinToString(" ") ?: ""}".trim()
            }
        }
        return snap.visual?.let { "${it.kind}: ${it.args.joinToString(" ")}" } ?: "Subject icon"
    }

    // Lifecycle pause logging
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE && snap.phase != Phase.FINISHED) {
                audio.stop()
                liveClient.disconnect()
                logTime()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            if (celebration == null) {
                logTime()
                repository.save()
            }
            liveClient.disconnect()
            audio.stop()
        }
    }

    // Stream live board snapshots when Live Tutor is open in Board Vision mode
    LaunchedEffect(liveOpen, cameraMode, liveConnState, snap.stepIndex, snap.phase, beads) {
        if (!liveOpen || cameraMode) return@LaunchedEffect
        delay(350)
        val captured = captureBoardRegionJpeg(rootView, window, boardBoundsInRoot)
        if (captured != null) {
            boardPreview = captured.second
            if (liveConnState == LiveConnectionState.CONNECTED) {
                liveClient.sendVideoFrame(captured.first)
            }
        }
        while (liveOpen && !cameraMode) {
            delay(2500)
            val frame = captureBoardRegionJpeg(rootView, window, boardBoundsInRoot)
            if (frame != null) {
                boardPreview = frame.second
                if (liveClient.connectionState.value == LiveConnectionState.CONNECTED) {
                    liveClient.sendVideoFrame(frame.first)
                }
            }
        }
    }

    // Announce lesson step changes to active Gemini Live session
    var lastLiveAnnouncedStep by remember { mutableIntStateOf(-1) }
    LaunchedEffect(liveOpen, liveConnState, snap.stepIndex, snap.lang) {
        if (liveOpen && liveConnState == LiveConnectionState.CONNECTED && lastLiveAnnouncedStep != snap.stepIndex) {
            val isInitial = lastLiveAnnouncedStep == -1
            lastLiveAnnouncedStep = snap.stepIndex
            if (!isInitial) {
                val cap = if (!cameraMode) captureBoardRegionJpeg(rootView, window, boardBoundsInRoot) else null
                if (cap != null) boardPreview = cap.second
                val stepTxt = snap.current?.let { pick(it.text, snap.lang) }.orEmpty()
                liveClient.notifyLessonStepChanged(stepTxt, buildVisualSummary(), cap?.first, snap.lang)
            }
        } else if (!liveOpen) {
            lastLiveAnnouncedStep = -1
        }
    }

    // Fetch Gemini / Brain teaching for current language & emotion mode
    var teachGen by remember { mutableIntStateOf(0) }
    LaunchedEffect(snap.lang, lesson.id, appState.tone) {
        if (!brainTeaches) return@LaunchedEffect
        val reqGen = ++teachGen
        val activeLang = snap.lang
        val activeTone = appState.tone
        val timeoutJob = scope.launch {
            delay(2600)
            if (reqGen == teachGen) director.stopWaiting()
        }
        val written = brain.teachLesson(
            bundle = bundle,
            lesson = lesson,
            lang = activeLang,
            tutor = director.tutor,
            tone = activeTone
        )
        timeoutJob.cancel()
        if (reqGen == teachGen && director.lang == activeLang) {
            director.setTeaching(written)
        }
    }

    // Peek timer while looking at board
    LaunchedEffect(snap.look, snap.phase) {
        peek = false
        if (snap.look == Look.BOARD && snap.phase == Phase.TALKING) {
            while (true) {
                delay(2600)
                peek = !peek
            }
        }
    }

    // Walk gaze on spot change
    LaunchedEffect(snap.spot) {
        if (snap.spot != lastSpot) {
            val dir = if (snap.spot.ordinal > lastSpot.ordinal) 1f else -1f
            lastSpot = snap.spot
            walkLook = Offset(dir, 0.1f)
            delay(700)
            walkLook = null
        }
    }

    // Clear targets when visual changes
    LaunchedEffect(snap.stepIndex, snap.visual) {
        boardTargets.clear()
        tourAtRoot = null
    }

    // Board tour execution when tutor talks about numbered visual items
    LaunchedEffect(snap.stepIndex, snap.phase, snap.touches, snap.bubble) {
        tourAtRoot = null
        val wanted = snap.touches
        if (wanted.isEmpty() || snap.phase != Phase.TALKING) return@LaunchedEffect
        delay(1050)
        val order = if (wanted.first() == -1) {
            boardTargets.keys.sorted()
        } else {
            wanted.filter { boardTargets.containsKey(it) }
        }
        if (order.isEmpty()) return@LaunchedEffect
        val chars = snap.bubble.length
        val perSec = if (snap.lang == "ml") 11f else 14f
        val sayingMs = ((chars / perSec) * 1000f).coerceIn(2500f, 30000f)
        val gapMs = ((sayingMs * 0.8f) / order.size).coerceIn(1000f, 2600f).toLong()
        for (itemIdx in order) {
            val pt = boardTargets[itemIdx]
            if (pt != null) {
                tourAtRoot = pt
            }
            delay(gapMs)
        }
        delay(800)
        tourAtRoot = null
    }

    // Return home smoothly when speech ends
    LaunchedEffect(speaking) {
        if (!speaking && tourAtRoot != null) {
            delay(700)
            tourAtRoot = null
        }
    }

    // Transition to celebration on lesson completion
    LaunchedEffect(snap.phase) {
        if (snap.phase == Phase.FINISHED && celebration == null) {
            logTime()
            val newDay = repository.finishLesson(lesson.id, snap.starsEarned, snap.xpEarned)
            celebration = CelebrationResult(
                stars = snap.starsEarned,
                xp = snap.xpEarned,
                newDay = newDay
            )
        }
    }

    BackHandler {
        if (celebration != null) {
            onClose()
        } else {
            audio.stop()
            onClose()
        }
    }

    val activeCelebration = celebration
    if (activeCelebration != null) {
        CelebrationScreen(
            result = activeCelebration,
            repository = repository,
            audio = audio,
            onFinish = onClose
        )
        return
    }

    val bgTint = lerp(ScolCream, subject.color, 0.07f)
    val lang = snap.lang
    val step = snap.current
    val otherLang = if (lang == "ml") "en" else "ml"
    val secondLine = when {
        appState.bilingual && step != null -> {
            val map = step.text as? Map<*, *>
            map?.get(otherLang)?.toString() ?: ""
        }
        snap.taughtByBrain -> snap.lessonLine
        else -> ""
    }

    val gaze = when {
        tourAtRoot != null -> Offset(-0.75f, -0.75f)
        walkLook != null -> walkLook!!
        else -> {
            val towardCenter = when (snap.spot) {
                Spot.LEFT -> 0.55f
                Spot.CENTER -> 0f
                Spot.RIGHT -> -0.55f
            }
            when (snap.look) {
                Look.BOARD -> if (peek) Offset.Zero else Offset(towardCenter, -0.9f)
                Look.ANSWERS -> Offset(towardCenter * 0.8f, 0.9f)
                Look.CHILD -> Offset.Zero
            }
        }
    }

    // Hop arc on step transition
    val hopAnim = remember { Animatable(0f) }
    LaunchedEffect(snap.hopCounter) {
        if (snap.hopCounter > 0) {
            hopAnim.snapTo(0f)
            hopAnim.animateTo(1f, animationSpec = tween(550, easing = FastOutSlowInEasing))
        }
    }

    val touring = tourAtRoot != null
    val avatarSizeDp by animateDpAsState(
        targetValue = if (touring) 56.dp else 88.dp,
        animationSpec = tween(450),
        label = "avatar_size"
    )
    val density = LocalDensity.current
    val avatarSizePx = with(density) { avatarSizeDp.toPx() }

    Scaffold(containerColor = bgTint) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .statusBarsPadding()
                .navigationBarsPadding()
                .onGloballyPositioned { coords ->
                    if (coords.isAttached) {
                        val b = coords.boundsInRoot()
                        rootOffset = b.topLeft
                        rootSize = Offset(b.width, b.height)
                    }
                }
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 600.dp)
                    .fillMaxSize()
                    .align(Alignment.TopCenter)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Top Bar: Close, Progress Bar, Language Toggle, Ask Mic Button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = {
                            audio.stop()
                            onClose()
                        },
                        modifier = Modifier.testTag("classroom_close_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close lesson",
                            tint = ScolInk,
                            modifier = Modifier.size(30.dp)
                        )
                    }

                    val animProgress by animateFloatAsState(
                        targetValue = snap.progress,
                        animationSpec = tween(400),
                        label = "lesson_progress"
                    )
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(14.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(ScolCloud)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(animProgress)
                                .fillMaxHeight()
                                .background(ScolMint)
                        )
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    fun connectLiveWithLang(targetLang: String) {
                        audio.stop()
                        scope.launch {
                            val cap = captureBoardRegionJpeg(rootView, window, boardBoundsInRoot)
                            if (cap != null) boardPreview = cap.second
                            val stepTxt = snap.current?.let { pick(it.text, targetLang) }.orEmpty()
                            val childLabel = appState.childName.ifBlank { if (targetLang == "ml") "കൂട്ടുകാരാ" else "friend" }
                            val greetingPrompt = if (targetLang == "ml") {
                                "$childLabel-നെ നിങ്ങളുടെ കഥാപാത്രത്തിന്റെ ശബ്ദത്തിൽ സ്നേഹത്തോടെ വിളിച്ച്, ബോർഡിലെ ചിത്രം നോക്കി ഈ ഘട്ടം മലയാളത്തിൽ മാത്രം വിശദീകരിക്കൂ: \"$stepTxt\"."
                            } else {
                                "Greet $childLabel briefly in your character voice and emotion mode, look at the lesson board image, and explain what you see for this step: \"$stepTxt\"."
                            }
                            liveClient.connect(
                                config = LiveTutorSessionConfig(
                                    tutor = director.tutor,
                                    lang = targetLang,
                                    tone = appState.tone,
                                    childName = appState.childName,
                                    subject = subject,
                                    lesson = lesson,
                                    currentStep = snap.current,
                                    visualSummary = buildVisualSummary()
                                ),
                                initialPrompt = greetingPrompt
                            )
                        }
                    }

                    OutlinedButton(
                        onClick = {
                            repository.switchLang()
                            val newLang = repository.state.value.mainLang
                            director.setLang(newLang)
                            if (liveOpen) {
                                connectLiveWithLang(newLang)
                            }
                        },
                        shape = RoundedCornerShape(50),
                        border = androidx.compose.foundation.BorderStroke(2.dp, ScolViolet),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        modifier = Modifier.testTag("classroom_lang_toggle")
                    ) {
                        Text(
                            text = if (lang == "ml") "English" else "മലയാളം",
                            color = ScolViolet,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 14.sp
                        )
                    }

                    Spacer(modifier = Modifier.width(6.dp))

                    FilledTonalButton(
                        onClick = {
                            if (liveOpen) {
                                liveOpen = false
                                liveClient.disconnect()
                            } else {
                                liveOpen = true
                                connectLiveWithLang(lang)
                            }
                        },
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = if (liveOpen) ScolCoral else ScolVioletSoft,
                            contentColor = if (liveOpen) Color.White else ScolVioletDeep
                        ),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                        modifier = Modifier
                            .height(40.dp)
                            .testTag("live_tutor_toggle_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = tr("liveTutor", lang),
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(tr("liveTutor", lang), fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                    }

                    Spacer(modifier = Modifier.width(6.dp))

                    IconButton(
                        onClick = {
                            if (liveOpen) {
                                liveOpen = false
                                liveClient.disconnect()
                            }
                            onOpenAsk(pick(lesson.title, "en"), notes)
                        },
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(ScolViolet)
                            .testTag("classroom_ask_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Mic,
                            contentDescription = tr("ask", lang),
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                // Board Area
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .onGloballyPositioned { coords ->
                            if (coords.isAttached) {
                                boardBoundsInRoot = coords.boundsInRoot()
                            }
                        }
                        .verticalScroll(rememberScrollState()),
                    contentAlignment = Alignment.Center
                ) {
                    val q = snap.question
                    if (q != null && snap.phase == Phase.ASKING) {
                        when (q.form) {
                            "abacus" -> AbacusPad(values = beads, onChanged = { beads = it })
                            "measure" -> {
                                val args = q.visual?.args ?: emptyList()
                                val len = args.firstOrNull()?.toIntOrNull() ?: 5
                                val emoji = args.getOrNull(1) ?: ""
                                ScaleBoard(length = len, emoji = emoji)
                            }
                            "build" -> StickBuilder(
                                options = q.options,
                                disabled = snap.wrongOptions,
                                onBuilt = { director.answer(it) }
                            )
                            else -> {
                                val v = snap.visual
                                if (v != null) {
                                    SoftCard(modifier = Modifier.fillMaxWidth()) {
                                        VisualView(
                                            visual = v,
                                            onTargetMeasured = { idx, offset -> boardTargets[idx] = offset }
                                        )
                                    }
                                } else {
                                    Text(subject.icon, fontSize = 64.sp)
                                }
                            }
                        }
                    } else {
                        var v = snap.visual
                        if (q != null && snap.phase == Phase.FEEDBACK) {
                            if (q.form == "abacus") {
                                val n = q.answer.toIntOrNull() ?: 0
                                v = VisualSpec("place", listOf("${n / 100}", "${(n / 10) % 10}", "${n % 10}"))
                            } else if (q.form == "build") {
                                v = VisualSpec("shapes", listOf(q.answer))
                            }
                        }
                        if (v != null) {
                            SoftCard(modifier = Modifier.fillMaxWidth()) {
                                VisualView(
                                    visual = v,
                                    onTargetMeasured = { idx, offset -> boardTargets[idx] = offset }
                                )
                            }
                        } else {
                            Text(subject.icon, fontSize = 64.sp)
                        }
                    }
                }

                if (liveOpen) {
                    Spacer(modifier = Modifier.height(8.dp))
                    LiveTutorDock(
                        tutor = director.tutor,
                        lang = lang,
                        liveClient = liveClient,
                        cameraMode = cameraMode,
                        boardPreview = boardPreview,
                        onToggleCamera = { useCam -> cameraMode = useCam },
                        onExplainWhatYouSee = {
                            scope.launch {
                                val boardExplainPrompt = if (lang == "ml") {
                                    "ഇപ്പോൾ ബോർഡിൽ കാണുന്നത് എന്താണെന്ന് നിങ്ങളുടെ കഥാപാത്രത്തിന്റെ ശബ്ദത്തിൽ മലയാളത്തിൽ ലളിതമായി വിശദീകരിക്കൂ."
                                } else {
                                    "Explain clearly what you see right now on my lesson board and help me with this step."
                                }
                                val camExplainPrompt = if (lang == "ml") {
                                    "ക്യാമറയിൽ കാണുന്നത് എന്താണെന്ന് മലയാളത്തിൽ മാത്രം ലളിതമായി വിശദീകരിക്കൂ, നമ്മുടെ പാഠവുമായി ബന്ധപ്പെടുത്തൂ."
                                } else {
                                    "Explain clearly what you see right now in front of you and connect it to our lesson."
                                }
                                if (!cameraMode) {
                                    val cap = captureBoardRegionJpeg(rootView, window, boardBoundsInRoot)
                                    if (cap != null) {
                                        boardPreview = cap.second
                                        liveClient.sendVideoFrame(
                                            cap.first,
                                            explainNowPrompt = boardExplainPrompt
                                        )
                                        return@launch
                                    }
                                }
                                liveClient.sendTextMessage(camExplainPrompt)
                            }
                        },
                        onCameraFrame = { jpeg ->
                            liveClient.sendVideoFrame(jpeg)
                        },
                        onClose = {
                            liveOpen = false
                            liveClient.disconnect()
                        }
                    )
                } else {
                    // Home slot spacer between board and speech bubble
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(92.dp)
                    ) {
                        val slotBias by animateFloatAsState(
                            targetValue = when (snap.spot) {
                                Spot.LEFT -> 0f
                                Spot.CENTER -> 0.5f
                                Spot.RIGHT -> 1f
                            },
                            animationSpec = tween(550, easing = FastOutSlowInEasing),
                            label = "tutor_spot"
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .wrapContentWidth(Alignment.Horizontal { size, space, _ ->
                                    ((space - size) * slotBias).toInt()
                                }),
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(88.dp)
                                    .onGloballyPositioned { coords ->
                                        if (coords.isAttached) {
                                            homeCenterRoot = coords.boundsInRoot().center
                                        }
                                    }
                            )
                        }
                    }

                    // Speech Bubble
                    val bubbleBorderColor = when (snap.mood) {
                        Mood.HAPPY -> ScolMint
                        Mood.CARING -> ScolSun
                        Mood.CALM -> ScolCloud
                    }
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 185.dp)
                            .clip(RoundedCornerShape(22.dp))
                            .background(Color.White)
                            .border(3.dp, bubbleBorderColor, RoundedCornerShape(22.dp))
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp)
                    ) {
                        if (snap.badge.isNotEmpty()) {
                            Box(
                                modifier = Modifier
                                    .padding(bottom = 6.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(ScolSun)
                                    .padding(horizontal = 10.dp, vertical = 3.dp)
                            ) {
                                Text(
                                    text = snap.badge,
                                    fontWeight = FontWeight.ExtraBold,
                                    fontSize = 13.sp,
                                    color = ScolInk
                                )
                            }
                        }
                        val q = snap.question
                        if (snap.phase == Phase.ASKING && q != null) {
                            val qText = pick(q.text, lang)
                            if (!snap.bubble.endsWith(qText)) {
                                Text(
                                    text = qText,
                                    fontSize = 16.sp,
                                    lineHeight = 21.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = ScolViolet,
                                    modifier = Modifier.padding(bottom = 6.dp)
                                )
                            }
                        }
                        Text(
                            text = snap.bubble,
                            fontSize = 19.sp,
                            lineHeight = 25.sp,
                            fontWeight = FontWeight.Bold,
                            color = ScolInk
                        )
                        if (secondLine.isNotEmpty() && (snap.phase == Phase.TALKING || snap.phase == Phase.ASKING || snap.phase == Phase.THINK_ASK)) {
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = secondLine,
                                fontSize = 15.sp,
                                lineHeight = 20.sp,
                                color = ScolMutedText
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Interactive Controls Area
                    ClassroomControls(
                        snap = snap,
                        lang = lang,
                        explaining = explaining,
                        typed = typed,
                        beads = beads,
                        onExplainMore = {
                            val curStep = snap.current ?: return@ClassroomControls
                            if (explaining) return@ClassroomControls
                            explaining = true
                            val what = pick(curStep.text, lang)
                            scope.launch {
                                val prompt = if (lang == "ml") {
                                    "ഇത് എനിക്ക് മനസ്സിലായില്ല. ഒരു ദിവസേനയുള്ള ഉദാഹരണത്തോടെ, മറ്റൊരു രീതിയിൽ ലളിതമായി പറഞ്ഞു തരാമോ? \"$what\""
                                } else {
                                    "I did not understand this. Please explain it again in a different, simple way with an everyday example: \"$what\""
                                }
                                val reply = brain.askBrain(
                                    bundle = bundle,
                                    question = prompt,
                                    lang = lang,
                                    tutorName = director.tutor.displayName("en"),
                                    lessonTitle = pick(lesson.title, lang).ifBlank { pick(lesson.title, "en") },
                                    notes = notes,
                                    tone = appState.tone,
                                    childName = appState.childName,
                                    tutor = director.tutor
                                )
                                explaining = false
                                director.tutorSays(reply.text)
                            }
                        },
                        onNext = { director.next() },
                        onHint = { director.showHint() },
                        onAnswer = { director.answer(it) },
                        onRevealThink = { director.revealThink() },
                        onRateThink = { director.rateThink(it) },
                        onTypeDigit = { d -> if (typed.length < 4) typed += d },
                        onBackspace = { if (typed.isNotEmpty()) typed = typed.dropLast(1) },
                        onSubmitTyped = {
                            if (typed.isNotEmpty()) {
                                val v = typed
                                typed = ""
                                director.answer(v)
                            }
                        }
                    )
                }
            }

            // Floating animated TutorAvatar overlay (glides to board items on tour)
            val targetRoot = if (liveOpen) null else when {
                tourAtRoot != null -> {
                    val raw = tourAtRoot!! + Offset(avatarSizePx * 0.62f, avatarSizePx * 0.58f)
                    val local = raw - rootOffset
                    val maxW = (rootSize.x - avatarSizePx / 2f).coerceAtLeast(avatarSizePx / 2f)
                    val maxH = (rootSize.y - avatarSizePx / 2f).coerceAtLeast(avatarSizePx / 2f)
                    Offset(
                        x = local.x.coerceIn(avatarSizePx / 2f, maxW),
                        y = local.y.coerceIn(avatarSizePx / 2f, maxH)
                    )
                }
                homeCenterRoot != null -> homeCenterRoot!! - rootOffset
                else -> null
            }

            if (targetRoot != null) {
                val animX by animateFloatAsState(
                    targetValue = targetRoot.x - avatarSizePx / 2f,
                    animationSpec = tween(durationMillis = if (touring) 650 else 500, easing = FastOutSlowInEasing),
                    label = "tutor_x"
                )
                val animY by animateFloatAsState(
                    targetValue = targetRoot.y - avatarSizePx / 2f,
                    animationSpec = tween(durationMillis = if (touring) 650 else 500, easing = FastOutSlowInEasing),
                    label = "tutor_y"
                )
                val hopY = -sin(hopAnim.value * PI.toFloat()) * with(density) { 22.dp.toPx() }
                val hopSquash = 1f - kotlin.math.abs(sin(hopAnim.value * PI.toFloat() * 2f)) * 0.06f

                Box(
                    modifier = Modifier
                        .offset { IntOffset(animX.roundToInt(), (animY + hopY).roundToInt()) }
                        .graphicsLayer { scaleY = hopSquash }
                ) {
                    TutorAvatar(
                        tutor = director.tutor,
                        size = avatarSizeDp,
                        talking = speaking,
                        mood = snap.mood,
                        gaze = gaze,
                        float = touring
                    )
                }
            }
        }
    }
}

@Composable
private fun ClassroomControls(
    snap: DirectorSnapshot,
    lang: String,
    explaining: Boolean,
    typed: String,
    beads: List<Int>,
    onExplainMore: () -> Unit,
    onNext: () -> Unit,
    onHint: () -> Unit,
    onAnswer: (String) -> Unit,
    onRevealThink: () -> Unit,
    onRateThink: (Boolean) -> Unit,
    onTypeDigit: (String) -> Unit,
    onBackspace: () -> Unit,
    onSubmitTyped: () -> Unit
) {
    val q = snap.question
    when (snap.phase) {
        Phase.TALKING -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Chunky(
                    modifier = Modifier
                        .weight(1f)
                        .testTag("explain_more_button"),
                    color = Color.White,
                    onClick = if (explaining) null else onExplainMore
                ) {
                    if (explaining) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(22.dp),
                            strokeWidth = 3.dp,
                            color = ScolViolet
                        )
                    } else {
                        Text(
                            text = "🤔 ${tr("explainMore", lang)}",
                            color = ScolInk,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                }
                Chunky(
                    modifier = Modifier
                        .weight(1f)
                        .testTag("next_step_button"),
                    color = ScolViolet,
                    onClick = onNext
                ) {
                    Text("${tr("next", lang)}  ▶")
                }
            }
        }

        Phase.FEEDBACK -> {
            Chunky(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("continue_button"),
                color = ScolMint,
                onClick = onNext
            ) {
                Text(tr("continue", lang))
            }
        }

        Phase.THINK_ASK -> {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = tr("think", lang),
                    textAlign = TextAlign.Center,
                    color = ScolMutedText,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Chunky(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("show_answer_button"),
                    color = ScolViolet,
                    onClick = onRevealThink
                ) {
                    Text(tr("showAnswer", lang))
                }
            }
        }

        Phase.THINK_REVEAL -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Chunky(
                    modifier = Modifier.weight(1f),
                    color = ScolSun,
                    onClick = { onRateThink(false) }
                ) {
                    Text("🤔 ${tr("notYet", lang)}", color = ScolInk)
                }
                Chunky(
                    modifier = Modifier.weight(1f),
                    color = ScolMint,
                    onClick = { onRateThink(true) }
                ) {
                    Text("👍 ${tr("gotIt", lang)}")
                }
            }
        }

        Phase.FINISHED -> {
            Spacer(modifier = Modifier.height(52.dp))
        }

        Phase.ASKING -> {
            Column(modifier = Modifier.fillMaxWidth()) {
                when (q?.form) {
                    "build" -> {
                        Text(
                            text = tr("dragSticks", lang),
                            textAlign = TextAlign.Center,
                            color = ScolMutedText,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp)
                        )
                    }
                    "abacus" -> {
                        Text(
                            text = tr("moveBeads", lang),
                            textAlign = TextAlign.Center,
                            color = ScolMutedText,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp)
                        )
                        Chunky(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("abacus_check_button"),
                            color = ScolMint,
                            onClick = { onAnswer("${beads[0] * 100 + beads[1] * 10 + beads[2]}") }
                        ) {
                            Text("${tr("check", lang)} ✓")
                        }
                    }
                    "choice" -> {
                        q.options.forEachIndexed { idx, opt ->
                            val isWrong = snap.wrongOptions.contains(opt)
                            Box(modifier = Modifier.padding(bottom = 8.dp)) {
                                Chunky(
                                    modifier = Modifier.testTag("choice_option_$idx"),
                                    color = Color.White,
                                    onClick = if (isWrong) null else ({ onAnswer(opt) })
                                ) {
                                    Text(
                                        text = q.optionLabel(idx, lang),
                                        fontSize = 20.sp,
                                        color = if (isWrong) ScolDisabledText else ScolInk
                                    )
                                }
                            }
                        }
                    }
                    else -> {
                        if (q?.form == "measure") {
                            Text(
                                text = tr("slideScale", lang),
                                textAlign = TextAlign.Center,
                                color = ScolMutedText,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 8.dp)
                            )
                        }
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(52.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(Color.White)
                                .border(3.dp, ScolViolet, RoundedCornerShape(16.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = typed.ifEmpty { "?" },
                                fontSize = 28.sp,
                                fontWeight = FontWeight.Black,
                                color = if (typed.isEmpty()) ScolCloud else ScolInk
                            )
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        val rows = listOf(
                            listOf("1", "2", "3", "4", "5"),
                            listOf("6", "7", "8", "9", "0")
                        )
                        rows.forEach { row ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 6.dp),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                row.forEach { k ->
                                    Chunky(
                                        modifier = Modifier
                                            .weight(1f)
                                            .testTag("keypad_$k"),
                                        color = Color.White,
                                        radius = 14.dp,
                                        contentPadding = PaddingValues(vertical = 8.dp),
                                        onClick = { onTypeDigit(k) }
                                    ) {
                                        Text(k, fontSize = 22.sp, color = ScolInk)
                                    }
                                }
                            }
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Chunky(
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("keypad_backspace"),
                                color = Color.White,
                                onClick = if (typed.isEmpty()) null else onBackspace
                            ) {
                                Text("⌫", color = if (typed.isEmpty()) ScolDisabledText else ScolInk)
                            }
                            Chunky(
                                modifier = Modifier
                                    .weight(2f)
                                    .testTag("number_check_button"),
                                color = ScolMint,
                                onClick = if (typed.isEmpty()) null else onSubmitTyped
                            ) {
                                Text("${tr("check", lang)} ✓")
                            }
                        }
                    }
                }

                if (snap.canHint) {
                    Spacer(modifier = Modifier.height(10.dp))
                    Chunky(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("hint_button"),
                        color = Color.White,
                        onClick = onHint
                    ) {
                        Text("💡 ${tr("hint", lang)}", color = ScolInk)
                    }
                }
            }
        }
    }
}

@Composable
fun CelebrationScreen(
    result: CelebrationResult,
    repository: ScolRepository,
    audio: ScolAudioEngine,
    onFinish: () -> Unit
) {
    val bundle by repository.bundle.collectAsState()
    val state by repository.state.collectAsState()
    val lang = state.mainLang
    val tutor = remember(bundle, state.tutorId) { bundle.tutor(state.tutorId) }

    var shownStars by remember { mutableIntStateOf(0) }
    var leaving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        audio.playSound("complete")
        launch {
            delay(900)
            if (state.voiceOn) {
                audio.say(listOf(pick(tutor.cheer, lang)), lang, tutor)
            }
        }
        for (i in 0 until 3) {
            delay(if (i == 0) 700L else 520L)
            shownStars = i + 1
            if (i < result.stars) {
                audio.playSound("star${i + 1}")
            }
        }
    }

    val titleScale = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        titleScale.animateTo(
            targetValue = 1f,
            animationSpec = spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow)
        )
    }

    val flyProgress = remember { Animatable(0f) }

    Scaffold(containerColor = ScolVioletSoft) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .statusBarsPadding()
                .navigationBarsPadding(),
            contentAlignment = Alignment.Center
        ) {
            // Rising sparkles while stars pop in
            if (!leaving) {
                for (k in 0 until 7) {
                    val inf = rememberInfiniteTransition(label = "spark_$k")
                    val v by inf.animateFloat(
                        initialValue = 0f,
                        targetValue = 1f,
                        animationSpec = infiniteRepeatable(
                            animation = tween(1400 + k * 180, easing = LinearEasing),
                            repeatMode = RepeatMode.Restart
                        ),
                        label = "spark_v_$k"
                    )
                    Text(
                        text = if (k % 2 == 0) "✨" else "⭐",
                        fontSize = (14 + 10 * (k % 3)).sp,
                        modifier = Modifier
                            .align(Alignment.Center)
                            .offset(
                                x = ((-140 + k * 46)).dp,
                                y = ((140f - v * 360f)).dp
                            )
                            .alpha((1f - v).coerceIn(0f, 1f))
                    )
                }
            }

            Column(
                modifier = Modifier
                    .widthIn(max = 520.dp)
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                TutorAvatar(tutor = tutor, size = 160.dp, mood = Mood.HAPPY, float = true)
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = tr("lessonDone", lang),
                    textAlign = TextAlign.Center,
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Black,
                    color = ScolInk,
                    modifier = Modifier.graphicsLayer {
                        scaleX = titleScale.value
                        scaleY = titleScale.value
                    }
                )
                Spacer(modifier = Modifier.height(12.dp))

                // Stars row (animates up and fades when continuing)
                Row(
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .height(76.dp)
                        .graphicsLayer {
                            if (leaving) {
                                val fp = flyProgress.value
                                translationY = -fp * 320f
                                translationX = fp * 160f
                                scaleX = 1f - fp * 0.65f
                                scaleY = 1f - fp * 0.65f
                                alpha = (1f - fp * 1.1f).coerceIn(0f, 1f)
                            }
                        }
                ) {
                    for (i in 0 until 3) {
                        val starScale by animateFloatAsState(
                            targetValue = if (i < shownStars) 1f else 0f,
                            animationSpec = spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMediumLow),
                            label = "star_$i"
                        )
                        val earned = i < result.stars
                        Text(
                            text = if (earned) "⭐" else "☆",
                            fontSize = 54.sp,
                            color = if (earned) Color.Unspecified else Color(0xFFC9A94A),
                            modifier = Modifier
                                .padding(horizontal = 4.dp)
                                .graphicsLayer {
                                    scaleX = starScale
                                    scaleY = starScale
                                }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pill("⚡", "+${result.xp} XP")
                    if (result.newDay) {
                        Pill("🔥", "${state.streak} ${tr("dayStreak", lang)}")
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                Chunky(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("celebration_continue_button"),
                    color = ScolMint,
                    onClick = {
                        if (leaving) return@Chunky
                        leaving = true
                        audio.playSound("whoosh")
                        scope.launch {
                            flyProgress.animateTo(1f, animationSpec = tween(700, easing = FastOutEaseInEasing))
                            onFinish()
                        }
                    }
                ) {
                    Text(tr("continue", lang))
                }
            }
        }
    }
}

private val FastOutEaseInEasing = CubicBezierEasing(0.4f, 0f, 1f, 1f)
