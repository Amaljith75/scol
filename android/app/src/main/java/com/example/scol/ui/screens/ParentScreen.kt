package com.example.scol.ui.screens

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.scol.audio.ScolAudioEngine
import com.example.scol.data.ScolRepository
import com.example.scol.model.*
import com.example.scol.network.TutorBrainClient
import com.example.scol.ui.components.Pill
import com.example.scol.ui.components.SoftCard
import com.example.ui.theme.*
import kotlinx.coroutines.launch
import kotlin.math.ceil
import kotlin.random.Random

@Composable
fun ParentGateDialog(
    onDismiss: () -> Unit,
    onUnlock: () -> Unit
) {
    val a = remember { 3 + Random.nextInt(7) }
    val b = remember { 3 + Random.nextInt(7) }
    var answerInput by remember { mutableStateOf("") }
    var wrong by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("For parents", fontWeight = FontWeight.Black) },
        text = {
            Column {
                Text("To continue, what is $a × $b?", fontSize = 17.sp)
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedTextField(
                    value = answerInput,
                    onValueChange = {
                        answerInput = it
                        wrong = false
                    },
                    singleLine = true,
                    isError = wrong,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    placeholder = { Text("Answer") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("parent_gate_input")
                )
                if (wrong) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("Try again", color = ScolCoral, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (answerInput.trim() == "${a * b}") {
                        onUnlock()
                    } else {
                        wrong = true
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = ScolViolet),
                modifier = Modifier.testTag("parent_gate_open_button")
            ) {
                Text("Open")
            }
        }
    )
}

fun studyTimeLabel(minute: Int): String {
    val h = minute / 60
    val m = minute % 60
    val h12 = if (h % 12 == 0) 12 else h % 12
    val suffix = if (h < 12) "AM" else "PM"
    return "$h12:${m.toString().padLeft(2, '0')} $suffix"
}

private fun String.padLeft(len: Int, ch: Char): String =
    if (length >= len) this else ch.toString().repeat(len - length) + this

private fun statusWords(r: ConceptRecord): String = when (r.status) {
    Understanding.SECURE ->
        "Understands this well. Answered correctly several times, in different kinds of questions."
    Understanding.CHECKING ->
        "Getting it right so far. Scol will check a few more times before counting it as learned."
    Understanding.MISCONCEPTION ->
        "Keeps making the same mistake: ${r.repeatedMistake}. Scol will teach this again in a different way."
    Understanding.NEEDS_HELP ->
        "Still finds this hard. Scol will bring it back for practice."
    Understanding.NOT_STARTED ->
        "Not started yet."
}

private fun statusColor(u: Understanding): Color = when (u) {
    Understanding.SECURE -> ScolMint
    Understanding.CHECKING -> ScolSun
    Understanding.MISCONCEPTION, Understanding.NEEDS_HELP -> ScolCoral
    Understanding.NOT_STARTED -> ScolCloud
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ParentScreen(
    repository: ScolRepository,
    audio: ScolAudioEngine,
    brain: TutorBrainClient,
    onBack: () -> Unit,
    onResetToOnboarding: () -> Unit
) {
    BackHandler {
        audio.stop()
        onBack()
    }

    val bundle by repository.bundle.collectAsState()
    val state by repository.state.collectAsState()
    val voiceStatus by audio.voiceStatus.collectAsState()
    val speaking by audio.speaking.collectAsState()
    val subjects = remember(bundle, state) { repository.mySubjects() }
    val hasSamples = remember(subjects) {
        subjects.any { s -> s.chapters.any { !it.verified && it.lessons.isNotEmpty() } }
    }

    var reportLang by remember { mutableStateOf(if (state.lang == "ml") "ml" else "en") }
    var reading by remember { mutableStateOf(false) }
    var showTimeDialog by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    LaunchedEffect(speaking) {
        if (!speaking && reading) reading = false
    }

    DisposableEffect(Unit) {
        onDispose { audio.stop() }
    }

    val report = remember(reportLang, state, bundle) { repository.weeklyReport(reportLang) }

    Scaffold(
        containerColor = ScolCream,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "${state.childName.ifBlank { "Child" }}'s learning",
                        fontWeight = FontWeight.Black,
                        color = ScolInk
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        audio.stop()
                        onBack()
                    }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = ScolInk
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = ScolCream)
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentAlignment = Alignment.TopCenter
        ) {
            LazyColumn(
                modifier = Modifier
                    .widthIn(max = 640.dp)
                    .fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 36.dp)
            ) {
                // Weekly Report
                item {
                    SectionHeading("Weekly report")
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("en" to "English", "ml" to "മലയാളം").forEach { (code, label) ->
                            FilterChip(
                                selected = reportLang == code,
                                onClick = {
                                    audio.stop()
                                    reportLang = code
                                    reading = false
                                },
                                label = { Text(label) }
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    SoftCard(modifier = Modifier.fillMaxWidth()) {
                        if (report.isNotEmpty()) {
                            Text(
                                text = report.first(),
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Black,
                                color = ScolInk
                            )
                        }
                        report.drop(1).forEach { para ->
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(text = para, fontSize = 15.sp, lineHeight = 21.sp, color = ScolInk)
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Button(
                                onClick = {
                                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_TEXT, report.joinToString("\n\n"))
                                    }
                                    context.startActivity(Intent.createChooser(shareIntent, "Share progress"))
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = ScolViolet),
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("parent_share_button")
                            ) {
                                Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Share")
                            }
                            OutlinedButton(
                                onClick = {
                                    if (reading) {
                                        audio.stop()
                                        reading = false
                                        return@OutlinedButton
                                    }
                                    reading = true
                                    val tutor = bundle.tutor(state.tutorId)
                                    scope.launch {
                                        var lines = report
                                        if (state.askEnabled || state.teachOn) {
                                            val told = brain.tellProgress(
                                                bundle = bundle,
                                                facts = repository.progressFacts(reportLang),
                                                lang = reportLang,
                                                tutor = tutor,
                                                childName = state.childName,
                                                tone = state.tone
                                            )
                                            if (!told.isNullOrBlank()) lines = listOf(told)
                                        }
                                        if (reading) {
                                            audio.say(lines, reportLang, tutor, state.tone)
                                        }
                                    }
                                },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("parent_listen_button")
                            ) {
                                Icon(
                                    imageVector = if (reading) Icons.Default.Stop else Icons.AutoMirrored.Filled.VolumeUp,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(if (reading) "Stop" else "Listen")
                            }
                        }
                    }
                }

                // Today and so far
                item {
                    SectionHeading("Today and so far")
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        val todayMins = ceil(state.todaySeconds / 60.0).toInt()
                        Pill("⏱️", "$todayMins min today")
                        Pill("📚", "${state.lessonStars.lengthOrSize()} lessons done")
                        Pill("📅", "${state.learningDays} learning days")
                        Pill("🔥", "best streak ${state.bestStreak}")
                    }
                }

                // Concept Mastery
                item {
                    SectionHeading("What ${state.childName.ifBlank { "your child" }} understands")
                    Text(
                        text = "Scol does not treat one right answer as \"learned\". It looks at several answers, in more than one question style, and at mistakes that repeat.",
                        color = ScolMutedText,
                        lineHeight = 20.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))

                    subjects.forEach { s ->
                        val keys = linkedSetOf<String>()
                        s.lessons.forEach { l ->
                            l.steps.forEach { st ->
                                if (st.isAsk && repository.concepts.containsKey(st.concept)) {
                                    keys.add(st.concept)
                                }
                            }
                        }
                        if (keys.isNotEmpty()) {
                            Text(
                                text = "${s.icon} ${pick(s.name, "en")}",
                                fontWeight = FontWeight.ExtraBold,
                                fontSize = 16.sp,
                                color = ScolInk,
                                modifier = Modifier.padding(top = 6.dp, bottom = 6.dp)
                            )
                            keys.forEach { k ->
                                val rec = repository.concepts[k] ?: return@forEach
                                SoftCard(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(bottom = 8.dp),
                                    padding = PaddingValues(12.dp)
                                ) {
                                    Row(verticalAlignment = Alignment.Top) {
                                        Box(
                                            modifier = Modifier
                                                .padding(top = 4.dp, end = 10.dp)
                                                .size(14.dp)
                                                .clip(CircleShape)
                                                .background(statusColor(rec.status))
                                        )
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = bundle.conceptName(k, "en"),
                                                fontWeight = FontWeight.ExtraBold,
                                                fontSize = 16.sp,
                                                color = ScolInk
                                            )
                                            Spacer(modifier = Modifier.height(2.dp))
                                            Text(
                                                text = statusWords(rec),
                                                lineHeight = 19.sp,
                                                color = ScolInk,
                                                fontSize = 14.sp
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (repository.concepts.isEmpty()) {
                        SoftCard(modifier = Modifier.fillMaxWidth()) {
                            Text("Nothing yet. This fills in after the first lesson.", color = ScolInk)
                        }
                    }
                    if (hasSamples) {
                        Spacer(modifier = Modifier.height(12.dp))
                        SoftCard(color = Color(0xFFFFF1D6), modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = "Note: some lessons shown now are samples and have not yet been checked against the school textbook.",
                                color = ScolInk,
                                fontSize = 14.sp
                            )
                        }
                    }
                }

                // Settings
                item {
                    SectionHeading("Settings")

                    Text("Tutor language", fontWeight = FontWeight.Bold, color = ScolInk)
                    ChipGroup(
                        values = listOf("en", "ml", "both"),
                        current = state.lang,
                        label = { v -> mapOf("en" to "English", "ml" to "മലയാളം", "both" to "Both")[v] ?: v },
                        onPick = { v -> repository.updateState { it.copy(lang = v) } }
                    )

                    Spacer(modifier = Modifier.height(10.dp))
                    Text("Tutor (personality & voice)", fontWeight = FontWeight.Bold, color = ScolInk)
                    ChipGroup(
                        values = bundle.tutors.map { it.id },
                        current = state.tutorId,
                        label = { id ->
                            val t = bundle.tutor(id)
                            "${t.displayName("en")} (${t.liveVoiceName})"
                        },
                        onPick = { id -> repository.updateState { it.copy(tutorId = id) } }
                    )

                    Spacer(modifier = Modifier.height(10.dp))
                    Text("Tutor's voice & emotion mode", fontWeight = FontWeight.Bold, color = ScolInk)
                    ChipGroup(
                        values = listOf("happy", "normal", "calm", "strict"),
                        current = state.tone,
                        label = { v ->
                            mapOf(
                                "happy" to "😄 Happy",
                                "normal" to "🙂 Normal",
                                "calm" to "😌 Calm",
                                "strict" to "🧐 Strict"
                            )[v] ?: v
                        },
                        onPick = { v -> repository.updateState { it.copy(tone = v) } }
                    )
                    Text(
                        text = "Controls the Gemini voice emotion and speaking style across live tutoring and read-aloud lessons.",
                        color = ScolMutedText,
                        fontSize = 13.sp
                    )

                    Spacer(modifier = Modifier.height(10.dp))
                    Text("Daily learning time limit", fontWeight = FontWeight.Bold, color = ScolInk)
                    ChipGroup(
                        values = listOf(15, 30, 45, 60),
                        current = state.dailyLimitMin,
                        label = { v -> "$v min" },
                        onPick = { v -> repository.updateState { it.copy(dailyLimitMin = v) } }
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    ParentSwitchRow(
                        title = "Tutor speaks aloud",
                        subtitle = "Plays tutor voice clips where available, or reads lines aloud using speech synthesis; turns off all spoken audio when disabled.",
                        checked = state.voiceOn,
                        testTag = "parent_voice_switch",
                        onCheckedChange = { v -> repository.updateState { it.copy(voiceOn = v) } }
                    )
                    if (voiceStatus.isNotEmpty()) {
                        Text(
                            text = "Voice: $voiceStatus",
                            color = ScolCoral,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                    }

                    ParentSwitchRow(
                        title = "The tutor teaches in its own words",
                        subtitle = "Before a level starts, the tutor brain turns each teaching step into a natural explanation: starting from what your child knows and pointing at pieces on the board. Questions and answers stay exact.",
                        checked = state.teachOn,
                        testTag = "parent_teach_switch",
                        onCheckedChange = { v -> repository.updateState { it.copy(teachOn = v) } }
                    )

                    ParentSwitchRow(
                        title = "Let my child ask the tutor questions",
                        subtitle = "Your child can speak or type a question about the lesson using the Ask mic button. Off unless you turn it on.",
                        checked = state.askEnabled,
                        testTag = "parent_ask_switch",
                        onCheckedChange = { v -> repository.updateState { it.copy(askEnabled = v) } }
                    )

                    ParentSwitchRow(
                        title = "Daily study reminders",
                        subtitle = "At ${studyTimeLabel(state.studyMinute)} every day, and a gentle nudge if a level is left halfway.",
                        checked = state.remindersOn,
                        testTag = "parent_reminders_switch",
                        onCheckedChange = { v -> repository.updateState { it.copy(remindersOn = v) } }
                    )

                    if (state.remindersOn) {
                        OutlinedButton(
                            onClick = { showTimeDialog = true },
                            modifier = Modifier.padding(top = 4.dp)
                        ) {
                            Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Study time: ${studyTimeLabel(state.studyMinute)}")
                        }
                    }
                }

                // Account
                item {
                    SectionHeading("Account")
                    OutlinedButton(
                        onClick = {
                            repository.updateState { it.copy(onboarded = false) }
                            onResetToOnboarding()
                        },
                        modifier = Modifier.testTag("parent_change_setup_button")
                    ) {
                        Text("Change syllabus, class or subjects")
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = { showDeleteDialog = true },
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = ScolCoral),
                        modifier = Modifier.testTag("parent_delete_data_button")
                    ) {
                        Text("Delete all of my child's data")
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "App Build 9 · Lessons version ${bundle.version}",
                        color = ScolDisabledText,
                        fontSize = 12.sp
                    )
                }
            }
        }
    }

    if (showTimeDialog) {
        val presets = listOf(7 * 60, 16 * 60, 17 * 60, 18 * 60, 19 * 60, 20 * 60)
        AlertDialog(
            onDismissRequest = { showTimeDialog = false },
            title = { Text("Choose study time", fontWeight = FontWeight.Black) },
            text = {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    presets.forEach { m ->
                        FilterChip(
                            selected = state.studyMinute == m,
                            onClick = {
                                repository.updateState { it.copy(studyMinute = m) }
                                showTimeDialog = false
                            },
                            label = { Text(studyTimeLabel(m)) }
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showTimeDialog = false }) { Text("Done") }
            }
        )
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete everything?", fontWeight = FontWeight.Black) },
            text = {
                Text("This removes your child's name, progress and settings from this phone. It cannot be undone.")
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Keep") }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showDeleteDialog = false
                        repository.eraseEverything()
                        onResetToOnboarding()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = ScolCoral)
                ) {
                    Text("Delete")
                }
            }
        )
    }
}

private fun Map<String, Int>.lengthOrSize(): Int = this.size

@Composable
private fun SectionHeading(title: String) {
    Text(
        text = title,
        fontSize = 20.sp,
        fontWeight = FontWeight.Black,
        color = ScolInk,
        modifier = Modifier.padding(top = 22.dp, bottom = 10.dp)
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun <T> ChipGroup(
    values: List<T>,
    current: T,
    label: (T) -> String,
    onPick: (T) -> Unit
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        values.forEach { v ->
            FilterChip(
                selected = v == current,
                onClick = { onPick(v) },
                label = { Text(label(v)) }
            )
        }
    }
}

@Composable
private fun ParentSwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    testTag: String,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(text = title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = ScolInk)
            Spacer(modifier = Modifier.height(2.dp))
            Text(text = subtitle, fontSize = 13.sp, lineHeight = 18.sp, color = ScolMutedText)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.testTag(testTag)
        )
    }
}
