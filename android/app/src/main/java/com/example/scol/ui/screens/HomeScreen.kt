package com.example.scol.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.scol.audio.ScolAudioEngine
import com.example.scol.data.ScolRepository
import com.example.scol.model.Lesson
import com.example.scol.model.Subject
import com.example.scol.model.Understanding
import com.example.scol.model.pick
import com.example.scol.model.tr
import com.example.scol.tutor.Mood
import com.example.scol.ui.components.*
import com.example.ui.theme.*
import kotlin.math.min

private data class NextPlan(
    val subject: Subject,
    val lesson: Lesson,
    val isRevision: Boolean
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    repository: ScolRepository,
    audio: ScolAudioEngine,
    onOpenSubject: (Subject) -> Unit,
    onOpenLesson: (Subject, Lesson) -> Unit,
    onOpenAsk: (String) -> Unit,
    onOpenParents: () -> Unit
) {
    val bundle by repository.bundle.collectAsState()
    val state by repository.state.collectAsState()
    val lang = state.mainLang
    val tutor = remember(bundle, state.tutorId) { bundle.tutor(state.tutorId) }
    val subjects = remember(bundle, state) { repository.mySubjects() }

    val plan: NextPlan? = remember(subjects, state) {
        var found: NextPlan? = null
        for (s in subjects) {
            val r = repository.revisionLesson(s)
            if (r != null) {
                found = NextPlan(s, r, true)
                break
            }
        }
        if (found == null) {
            val open = subjects.filter { repository.nextLesson(it) != null }
            if (open.isNotEmpty()) {
                val s = open[state.todayLessons % open.size]
                val nextL = repository.nextLesson(s)
                if (nextL != null) found = NextPlan(s, nextL, false)
            }
        }
        found
    }

    val hasLessons = subjects.any { it.lessons.isNotEmpty() }
    val message = when {
        state.timeUp -> tr("timeUp", lang)
        plan == null -> tr(if (hasLessons) "allDone" else "comingSoon", lang)
        else -> {
            val title = if (plan.isRevision) tr("practice", lang) else pick(plan.lesson.title, lang)
            "${tr("nextUp", lang)}: $title"
        }
    }

    var showRewardsSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (state.voiceOn) {
            val parts = mutableListOf(pick(tutor.hello, lang))
            when {
                state.timeUp -> parts.add(bundle.phrase("timeUp", lang))
                plan == null -> parts.add(bundle.phrase(if (hasLessons) "allDone" else "comingSoon", lang))
                else -> {
                    parts.add(bundle.phrase("nextUp", lang))
                    parts.add(if (plan.isRevision) bundle.phrase("practice", lang) else pick(plan.lesson.title, lang))
                    parts.add(bundle.phrase("tapGo", lang))
                }
            }
            audio.say(parts, lang, tutor)
        }
    }

    Scaffold(
        containerColor = ScolCream,
        bottomBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White)
                    .navigationBarsPadding()
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(2.dp).background(ScolCloud))
                Row(modifier = Modifier.fillMaxWidth()) {
                    HomeTabItem("🏠", tr("home", lang), active = true, tag = "home_tab_home", onClick = {})
                    HomeTabItem("🎙️", tr("ask", lang), active = false, tag = "home_tab_ask") {
                        onOpenAsk(if (plan != null) pick(plan.lesson.title, "en") else "")
                    }
                    HomeTabItem("🏆", tr("rewards", lang), active = false, tag = "home_tab_rewards") {
                        showRewardsSheet = true
                    }
                    HomeTabItem("👪", tr("parents", lang), active = false, tag = "home_tab_parents") {
                        audio.stop()
                        onOpenParents()
                    }
                }
            }
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
                    .widthIn(max = 600.dp)
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                contentPadding = PaddingValues(vertical = 16.dp)
            ) {
                // Header: Hi, Name! + Flame + Stars
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${tr("hi", lang)}, ${state.childName}! 👋",
                            fontSize = 26.sp,
                            fontWeight = FontWeight.Black,
                            color = ScolInk,
                            modifier = Modifier.weight(1f)
                        )
                        Pill("🔥", "${state.liveStreak}")
                        Spacer(modifier = Modifier.width(8.dp))
                        StarPill(
                            stars = state.stars,
                            onPopSound = { audio.playSound("pop", 0.7f) }
                        )
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                }

                // Tutor plan card
                item {
                    SoftCard(color = ScolVioletSoft, modifier = Modifier.fillMaxWidth()) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            TutorAvatar(
                                tutor = tutor,
                                size = 104.dp,
                                mood = Mood.HAPPY,
                                float = true,
                                gaze = if (plan == null) Offset.Zero else Offset(0.7f, 0.75f)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(Color.White)
                                    .padding(14.dp)
                            ) {
                                Text(
                                    text = "${tutor.displayName(lang)} · ${tutor.personalityTag(lang)}",
                                    fontWeight = FontWeight.ExtraBold,
                                    color = darker(tutor.color, 0.2f),
                                    fontSize = 14.sp
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = message,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = ScolInk,
                                    lineHeight = 23.sp
                                )
                                if (plan != null && !state.timeUp) {
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = "${plan.subject.icon} ${pick(plan.subject.name, lang)}",
                                        fontSize = 14.sp,
                                        color = ScolMutedText
                                    )
                                }
                            }
                        }

                        if (plan != null && !state.timeUp) {
                            Spacer(modifier = Modifier.height(14.dp))
                            Chunky(
                                modifier = Modifier.testTag("home_lets_go_button"),
                                color = ScolViolet,
                                onClick = {
                                    audio.stop()
                                    onOpenLesson(plan.subject, plan.lesson)
                                }
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.Center
                                ) {
                                    Text(tr("go", lang), fontSize = 22.sp)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Icon(
                                        imageVector = Icons.Default.PlayArrow,
                                        contentDescription = "Go",
                                        tint = Color.White,
                                        modifier = Modifier.size(30.dp)
                                    )
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                }

                // Today's goal card
                item {
                    SoftCard(modifier = Modifier.fillMaxWidth()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("🎯", fontSize = 30.sp)
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "${tr("todayGoal", lang)}: ${min(state.todayLessons, state.dailyGoal)}/${state.dailyGoal} ${tr("lessons", lang)}",
                                    fontWeight = FontWeight.ExtraBold,
                                    fontSize = 16.sp,
                                    color = ScolInk
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(14.dp)
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(ScolCloud)
                                ) {
                                    val ratio = (state.todayLessons.toFloat() / state.dailyGoal).coerceIn(0f, 1f)
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth(ratio)
                                            .fillMaxHeight()
                                            .background(ScolSun)
                                    )
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                }

                // Subjects heading
                item {
                    Text(
                        text = tr("subjects", lang),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Black,
                        color = ScolInk
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                }

                // Subjects list
                if (subjects.isEmpty()) {
                    item {
                        SoftCard(modifier = Modifier.fillMaxWidth()) {
                            Text(tr("comingSoon", lang), fontSize = 17.sp, color = ScolInk)
                        }
                    }
                } else {
                    items(subjects.size, key = { subjects[it].id }) { i ->
                        val s = subjects[i]
                        val total = s.lessons.size
                        val done = s.lessons.count { repository.isDone(it) }
                        Box(modifier = Modifier.padding(bottom = 12.dp)) {
                            Chunky(
                                modifier = Modifier.testTag("home_subject_${s.key}"),
                                color = s.color,
                                contentPadding = PaddingValues(14.dp),
                                onClick = {
                                    audio.stop()
                                    onOpenSubject(s)
                                }
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(58.dp)
                                            .clip(RoundedCornerShape(18.dp))
                                            .background(Color.White.copy(alpha = 0.24f)),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(s.icon, fontSize = 30.sp)
                                    }
                                    Spacer(modifier = Modifier.width(14.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = pick(s.name, lang),
                                            fontSize = 20.sp,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = Color.White,
                                            textAlign = TextAlign.Start
                                        )
                                        Spacer(modifier = Modifier.height(6.dp))
                                        if (total == 0) {
                                            Text(
                                                text = tr("comingSoon", lang),
                                                fontSize = 13.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = Color.White
                                            )
                                        } else {
                                            Box(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .height(10.dp)
                                                    .clip(RoundedCornerShape(6.dp))
                                                    .background(Color.White.copy(alpha = 0.28f))
                                            ) {
                                                Box(
                                                    modifier = Modifier
                                                        .fillMaxWidth(done.toFloat() / total)
                                                        .fillMaxHeight()
                                                        .background(Color.White)
                                                )
                                            }
                                            Spacer(modifier = Modifier.height(4.dp))
                                            Text(
                                                text = "$done / $total",
                                                fontSize = 13.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = Color.White
                                            )
                                        }
                                    }
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                        contentDescription = "Open",
                                        tint = Color.White,
                                        modifier = Modifier.size(34.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showRewardsSheet) {
        val lessonsDone = state.lessonStars.size
        val secureCount = repository.concepts.values.count { it.status == Understanding.SECURE }
        val badges = listOf(
            Triple("🌱", "First lesson", lessonsDone >= 1),
            Triple("📚", "5 lessons", lessonsDone >= 5),
            Triple("🔥", "3 days in a row", state.bestStreak >= 3),
            Triple("🌟", "7 days in a row", state.bestStreak >= 7),
            Triple("⭐", "10 stars", state.stars >= 10),
            Triple("🧠", "Really understood an idea", secureCount >= 1)
        )

        ModalBottomSheet(
            onDismissRequest = { showRewardsSheet = false },
            containerColor = Color.White,
            shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StarPill(stars = state.stars)
                    Pill("⚡", "${state.xp} XP")
                    Pill("🔥", "${state.bestStreak}")
                }
                Spacer(modifier = Modifier.height(16.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    badges.forEach { (emoji, label, unlocked) ->
                        Column(
                            modifier = Modifier
                                .width(100.dp)
                                .alpha(if (unlocked) 1f else 0.35f),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(72.dp)
                                    .clip(CircleShape)
                                    .background(Color.White)
                                    .border(4.dp, ScolSun, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(emoji, fontSize = 34.sp)
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = label,
                                textAlign = TextAlign.Center,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                color = ScolInk
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun RowScope.HomeTabItem(
    emoji: String,
    label: String,
    active: Boolean,
    tag: String,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .weight(1f)
            .testTag(tag)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(if (active) ScolVioletSoft else Color.Transparent)
                .padding(horizontal = 18.dp, vertical = 4.dp)
        ) {
            Text(emoji, fontSize = 24.sp)
        }
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.ExtraBold,
            color = if (active) ScolViolet else ScolNavInactive
        )
    }
}
