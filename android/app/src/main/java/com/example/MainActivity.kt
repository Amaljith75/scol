package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.example.scol.audio.ScolAudioEngine
import com.example.scol.data.ScolRepository
import com.example.scol.model.Lesson
import com.example.scol.model.Subject
import com.example.scol.network.GeminiLiveClient
import com.example.scol.network.TutorBrainClient
import com.example.scol.ui.screens.*
import com.example.ui.theme.ScolTheme

private sealed class ScolRoute {
    data object Splash : ScolRoute()
    data object Onboarding : ScolRoute()
    data object Home : ScolRoute()
    data class Path(val subject: Subject) : ScolRoute()
    data class Classroom(val subject: Subject, val lesson: Lesson) : ScolRoute()
    data object Parents : ScolRoute()
}

private data class AskRequest(
    val lessonTitle: String,
    val notes: String
)

class MainActivity : ComponentActivity() {
    private lateinit var repository: ScolRepository
    private lateinit var audio: ScolAudioEngine
    private lateinit var brain: TutorBrainClient
    private lateinit var liveClient: GeminiLiveClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        repository = ScolRepository(applicationContext)
        audio = ScolAudioEngine(applicationContext)
        brain = TutorBrainClient(applicationContext)
        liveClient = GeminiLiveClient(applicationContext)

        audio.onBeforeSpeechPlay = { liveClient.stopOutputAudioOnly() }
        liveClient.onAudioPlaybackStarting = { audio.stop() }

        setContent {
            ScolTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val state by repository.state.collectAsState()
                    val bundle by repository.bundle.collectAsState()

                    LaunchedEffect(state.voiceOn) {
                        audio.voiceEnabled = state.voiceOn
                    }

                    LaunchedEffect(state.tone) {
                        audio.voiceTone = state.tone
                    }

                    // Quietly refresh curriculum bundle from GitHub in the background
                    LaunchedEffect(Unit) {
                        repository.refreshBundleOnline()
                    }

                    var route by remember { mutableStateOf<ScolRoute>(ScolRoute.Splash) }
                    var returnSubject by remember { mutableStateOf<Subject?>(null) }
                    var showParentGate by remember { mutableStateOf(false) }
                    var askRequest by remember { mutableStateOf<AskRequest?>(null) }
                    var showAskDisabledDialog by remember { mutableStateOf(false) }

                    fun openAsk(lessonTitle: String, notes: String) {
                        if (!state.askEnabled) {
                            showAskDisabledDialog = true
                        } else {
                            askRequest = AskRequest(lessonTitle, notes)
                        }
                    }

                    LaunchedEffect(state.onboarded, route) {
                        if (route == ScolRoute.Onboarding && state.onboarded) {
                            route = ScolRoute.Home
                        }
                    }

                    // Navigate back cleanly if system back is pressed on sub-screens
                    BackHandler(enabled = route !is ScolRoute.Splash && route !is ScolRoute.Home && route !is ScolRoute.Onboarding) {
                        audio.stop()
                        route = when (route) {
                            is ScolRoute.Classroom -> {
                                val s = returnSubject
                                if (s != null) ScolRoute.Path(s) else ScolRoute.Home
                            }
                            is ScolRoute.Path, ScolRoute.Parents -> ScolRoute.Home
                            else -> ScolRoute.Home
                        }
                    }

                    when (val current = route) {
                        ScolRoute.Splash -> {
                            SplashScreen(
                                onDone = {
                                    route = if (repository.state.value.onboarded) {
                                        ScolRoute.Home
                                    } else {
                                        ScolRoute.Onboarding
                                    }
                                }
                            )
                        }

                        ScolRoute.Onboarding -> {
                            OnboardingScreen(
                                repository = repository
                            )
                        }

                        ScolRoute.Home -> {
                            HomeScreen(
                                repository = repository,
                                audio = audio,
                                onOpenSubject = { subject ->
                                    returnSubject = subject
                                    route = ScolRoute.Path(subject)
                                },
                                onOpenLesson = { subject, lesson ->
                                    returnSubject = null
                                    route = ScolRoute.Classroom(subject, lesson)
                                },
                                onOpenAsk = { lessonTitle ->
                                    openAsk(lessonTitle, "")
                                },
                                onOpenParents = {
                                    showParentGate = true
                                }
                            )
                        }

                        is ScolRoute.Path -> {
                            PathScreen(
                                subject = current.subject,
                                repository = repository,
                                onBack = { route = ScolRoute.Home },
                                onOpenLesson = { subject, lesson ->
                                    returnSubject = subject
                                    route = ScolRoute.Classroom(subject, lesson)
                                }
                            )
                        }

                        is ScolRoute.Classroom -> {
                            ClassroomScreen(
                                subject = current.subject,
                                lesson = current.lesson,
                                repository = repository,
                                audio = audio,
                                brain = brain,
                                liveClient = liveClient,
                                onClose = {
                                    val s = returnSubject
                                    route = if (s != null) {
                                        // Re-resolve subject from latest bundle if refreshed
                                        val refreshed = repository.mySubjects().firstOrNull { it.id == s.id } ?: s
                                        ScolRoute.Path(refreshed)
                                    } else {
                                        ScolRoute.Home
                                    }
                                },
                                onOpenAsk = { lessonTitle, notes ->
                                    openAsk(lessonTitle, notes)
                                }
                            )
                        }

                        ScolRoute.Parents -> {
                            ParentScreen(
                                repository = repository,
                                audio = audio,
                                brain = brain,
                                onBack = { route = ScolRoute.Home },
                                onResetToOnboarding = { route = ScolRoute.Onboarding }
                            )
                        }
                    }

                    if (showParentGate) {
                        ParentGateDialog(
                            onDismiss = { showParentGate = false },
                            onUnlock = {
                                showParentGate = false
                                route = ScolRoute.Parents
                            }
                        )
                    }

                    if (showAskDisabledDialog) {
                        AskDisabledDialog(
                            lang = state.mainLang,
                            onDismiss = { showAskDisabledDialog = false }
                        )
                    }

                    val activeAsk = askRequest
                    if (activeAsk != null) {
                        AskBottomSheet(
                            lessonTitle = activeAsk.lessonTitle,
                            notes = activeAsk.notes,
                            repository = repository,
                            audio = audio,
                            brain = brain,
                            onDismiss = { askRequest = null }
                        )
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::liveClient.isInitialized) {
            liveClient.release()
        }
        if (::audio.isInitialized) {
            audio.release()
        }
    }
}
