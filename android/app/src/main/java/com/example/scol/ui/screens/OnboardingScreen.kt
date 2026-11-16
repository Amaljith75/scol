package com.example.scol.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.scol.data.ScolRepository
import com.example.scol.model.pick
import com.example.scol.tutor.Mood
import com.example.scol.ui.components.Chunky
import com.example.scol.ui.components.TutorAvatar
import com.example.ui.theme.*

private val ONBOARDING_TITLES = listOf(
    "Welcome to Scol",
    "What is your child's name?",
    "Which syllabus does your child follow?",
    "Which class?",
    "Which language should the tutor use?",
    "Which subjects is your child studying?",
    "When should your child study each day?",
    "Let your child pick a friend to learn with!"
)

@Composable
fun OnboardingScreen(
    repository: ScolRepository
) {
    val bundle by repository.bundle.collectAsState()
    val state by repository.state.collectAsState()

    var step by remember { mutableIntStateOf(0) }
    var childName by remember { mutableStateOf(state.childName) }
    var boardId by remember { mutableStateOf(state.boardId.ifEmpty { "kerala-scert" }) }
    var classNumber by remember { mutableIntStateOf(state.classNumber) }
    var lang by remember { mutableStateOf(state.lang) }
    var tutorId by remember { mutableStateOf(state.tutorId) }
    var selectedSubjects by remember { mutableStateOf(state.subjectKeys.toSet()) }
    var studyMinute by remember { mutableIntStateOf(state.studyMinute) }

    val availableSubjects = remember(bundle, boardId, classNumber) {
        bundle.subjectsFor(boardId, classNumber)
    }

    val canGoOn = when (step) {
        1 -> childName.trim().isNotEmpty()
        2 -> boardId.isNotEmpty()
        5 -> selectedSubjects.isNotEmpty() || availableSubjects.isEmpty()
        else -> true
    }

    fun next() {
        if (step == 4) {
            selectedSubjects = availableSubjects.map { it.key }.toSet()
        }
        if (step < ONBOARDING_TITLES.lastIndex) {
            step++
            return
        }
        repository.updateState { cur ->
            cur.copy(
                childName = childName.trim(),
                boardId = boardId,
                classNumber = classNumber,
                lang = lang,
                tutorId = tutorId,
                subjectKeys = selectedSubjects.toList(),
                studyMinute = studyMinute,
                onboarded = true
            )
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ScolCream)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 560.dp)
                .fillMaxSize()
        ) {
            // Top progress row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (step > 0) {
                    IconButton(onClick = { step-- }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = ScolInk
                        )
                    }
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(12.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(ScolCloud)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth((step + 1).toFloat() / ONBOARDING_TITLES.size)
                            .fillMaxHeight()
                            .background(ScolMint)
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            Text(
                text = ONBOARDING_TITLES[step],
                fontSize = 26.sp,
                fontWeight = FontWeight.Black,
                color = ScolInk,
                lineHeight = 32.sp
            )

            Spacer(modifier = Modifier.height(18.dp))

            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                when (step) {
                    0 -> {
                        item {
                            Text(
                                text = "Scol is a personal tutor for your child. The tutor explains each lesson, shows examples, asks questions, and checks whether your child has really understood.\n\nThis setup is for a parent and takes about a minute.\n\nYour child's name and progress stay on this phone. Nothing is sent anywhere.",
                                fontSize = 17.sp,
                                lineHeight = 25.sp,
                                color = ScolInk
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            AssistChip(
                                onClick = {
                                    repository.updateState { cur ->
                                        cur.copy(
                                            childName = "Anu",
                                            boardId = "kerala-scert",
                                            classNumber = 3,
                                            lang = "en",
                                            tutorId = "koko",
                                            subjectKeys = bundle.subjectsFor("kerala-scert", 3).map { it.key },
                                            onboarded = true
                                        )
                                    }
                                },
                                label = { Text("⚡ Quick Demo Setup (Anu • Class 3 • Ollie)") },
                                modifier = Modifier.testTag("onboarding_demo_button")
                            )
                        }
                    }

                    1 -> {
                        item {
                            OutlinedTextField(
                                value = childName,
                                onValueChange = { if (it.length <= 20) childName = it },
                                placeholder = { Text("First name or nickname") },
                                singleLine = true,
                                keyboardOptions = KeyboardOptions(
                                    capitalization = KeyboardCapitalization.Words,
                                    imeAction = ImeAction.Done
                                ),
                                keyboardActions = KeyboardActions(onDone = { if (canGoOn) next() }),
                                shape = RoundedCornerShape(18.dp),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedContainerColor = Color.White,
                                    unfocusedContainerColor = Color.White
                                ),
                                textStyle = LocalTextStyle.current.copy(fontSize = 22.sp, fontWeight = FontWeight.Bold),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("onboarding_name_input")
                            )
                        }
                    }

                    2 -> {
                        items(bundle.boards.size) { i ->
                            val b = bundle.boards[i]
                            val enName = pick(b.name, "en")
                            val mlName = pick(b.name, "ml")
                            OnboardingOption(
                                label = enName,
                                sub = if (mlName != enName) mlName else null,
                                leading = "🏫",
                                selected = boardId == b.id,
                                onClick = { boardId = b.id }
                            )
                        }
                    }

                    3 -> {
                        val classes = bundle.board(boardId)?.classes ?: emptyList()
                        items(classes.size) { i ->
                            val c = classes[i]
                            OnboardingOption(
                                label = "Class ${c.number}",
                                leading = "🎒",
                                selected = classNumber == c.number,
                                onClick = { classNumber = c.number }
                            )
                        }
                    }

                    4 -> {
                        item {
                            OnboardingOption(
                                label = "English",
                                leading = "Aa",
                                selected = lang == "en",
                                onClick = { lang = "en" }
                            )
                        }
                        item {
                            OnboardingOption(
                                label = "മലയാളം",
                                leading = "അ",
                                selected = lang == "ml",
                                onClick = { lang = "ml" }
                            )
                        }
                        item {
                            OnboardingOption(
                                label = "Both together",
                                sub = "English first, with Malayalam shown below",
                                leading = "🔁",
                                selected = lang == "both",
                                onClick = { lang = "both" }
                            )
                        }
                    }

                    5 -> {
                        if (availableSubjects.isEmpty()) {
                            item {
                                Text(
                                    text = "Lessons for this class are on the way! Tap Next to continue.",
                                    fontSize = 16.sp,
                                    color = ScolMutedText
                                )
                            }
                        } else {
                            items(availableSubjects.size) { i ->
                                val s = availableSubjects[i]
                                val isSel = selectedSubjects.contains(s.key)
                                OnboardingOption(
                                    label = pick(s.name, if (lang == "ml") "ml" else "en"),
                                    sub = if (s.lessons.isEmpty()) "Lessons are on the way!" else "${s.lessons.size} levels",
                                    leading = s.icon,
                                    selected = isSel,
                                    onClick = {
                                        selectedSubjects = if (isSel) selectedSubjects - s.key else selectedSubjects + s.key
                                    }
                                )
                            }
                        }
                    }

                    6 -> {
                        val presets = listOf(
                            16 * 60 to "4:00 PM (After school)",
                            17 * 60 + 30 to "5:30 PM (Evening)",
                            18 * 60 to "6:00 PM (Recommended)",
                            19 * 60 to "7:00 PM (Before dinner)"
                        )
                        items(presets.size) { i ->
                            val (minVal, label) = presets[i]
                            OnboardingOption(
                                label = label,
                                leading = "⏰",
                                selected = studyMinute == minVal,
                                onClick = { studyMinute = minVal }
                            )
                        }
                    }

                    7 -> {
                        items(bundle.tutors.size) { i ->
                            val t = bundle.tutors[i]
                            val isSel = tutorId == t.id
                            Chunky(
                                color = if (isSel) ScolViolet else Color.White,
                                onClick = { tutorId = t.id }
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    TutorAvatar(
                                        tutor = t,
                                        size = 76.dp,
                                        mood = if (isSel) Mood.HAPPY else Mood.CALM
                                    )
                                    Spacer(modifier = Modifier.width(14.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "${pick(t.name, "en")} · ${pick(t.name, "ml")}",
                                            fontSize = 20.sp,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = if (isSel) Color.White else ScolInk
                                        )
                                        Text(
                                            text = "${t.personalityTag("en")} · ${t.liveVoiceName} voice",
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = if (isSel) Color.White.copy(alpha = 0.9f) else ScolViolet
                                        )
                                        Text(
                                            text = pick(t.about, if (lang == "ml") "ml" else "en"),
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = if (isSel) Color.White.copy(alpha = 0.85f) else ScolMutedText
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            Chunky(
                modifier = Modifier.testTag("onboarding_next_button"),
                color = ScolMint,
                onClick = if (canGoOn) ({ next() }) else null
            ) {
                Text(if (step == ONBOARDING_TITLES.lastIndex) "Start learning" else "Next")
            }
        }
    }
}

@Composable
private fun OnboardingOption(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    leading: String? = null,
    sub: String? = null
) {
    Chunky(
        color = if (selected) ScolViolet else Color.White,
        onClick = onClick
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (leading != null) {
                Text(leading, fontSize = 28.sp, modifier = Modifier.padding(end = 12.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = label,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = if (selected) Color.White else ScolInk
                )
                if (sub != null) {
                    Text(
                        text = sub,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (selected) Color.White.copy(alpha = 0.8f) else ScolMutedText
                    )
                }
            }
            if (selected) {
                Icon(Icons.Default.CheckCircle, contentDescription = "Selected", tint = Color.White)
            }
        }
    }
}
