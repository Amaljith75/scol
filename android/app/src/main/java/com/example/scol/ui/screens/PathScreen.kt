package com.example.scol.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.scol.data.ScolRepository
import com.example.scol.model.Lesson
import com.example.scol.model.Subject
import com.example.scol.model.pick
import com.example.scol.model.tr
import com.example.scol.tutor.Mood
import com.example.scol.ui.components.Chunky
import com.example.scol.ui.components.StarPill
import com.example.scol.ui.components.TutorAvatar
import com.example.ui.theme.*
import kotlin.math.sin

@Composable
fun PathScreen(
    subject: Subject,
    repository: ScolRepository,
    onBack: () -> Unit,
    onOpenLesson: (Subject, Lesson) -> Unit
) {
    val bundle by repository.bundle.collectAsState()
    val state by repository.state.collectAsState()
    val lang = state.mainLang
    val tutor = remember(bundle, state.tutorId) { bundle.tutor(state.tutorId) }
    val current = remember(subject, state) { repository.nextLesson(subject) }
    val revision = remember(subject, state) { repository.revisionLesson(subject) }
    val snackbarHostState = remember { SnackbarHostState() }
    var snackMessage by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(snackMessage) {
        snackMessage?.let {
            snackbarHostState.showSnackbar(it)
            snackMessage = null
        }
    }

    val palette = remember(subject) {
        if (subject.paletteValues.isEmpty()) ScolChapterColors
        else subject.paletteValues.map { Color(it) }
    }

    Scaffold(
        containerColor = ScolCream,
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .statusBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 600.dp)
                    .fillMaxSize()
            ) {
                // Header
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 8.dp, top = 8.dp, end = 16.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier.testTag("path_back_button")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = ScolInk,
                            modifier = Modifier.size(30.dp)
                        )
                    }
                    Text(
                        text = "${subject.icon} ${pick(subject.name, lang)}",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Black,
                        color = ScolInk,
                        modifier = Modifier.weight(1f)
                    )
                    StarPill(stars = state.stars)
                }

                if (subject.lessons.isEmpty()) {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        TutorAvatar(tutor = tutor, size = 140.dp)
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = tr("comingSoon", lang),
                            fontSize = 20.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = ScolInk
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp)
                    ) {
                        if (revision != null) {
                            item {
                                Chunky(
                                    modifier = Modifier.testTag("path_practice_button"),
                                    color = ScolCoral,
                                    onClick = { onOpenLesson(subject, revision) }
                                ) {
                                    Text("💪 ${tr("practice", lang)}")
                                }
                                Spacer(modifier = Modifier.height(18.dp))
                            }
                        }

                        var levelIndex = 0
                        subject.chapters.forEachIndexed { ci, ch ->
                            val chColor = palette[ci % palette.size]
                            item(key = "ch_${ch.id}") {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(top = 6.dp, bottom = 18.dp)
                                        .clip(RoundedCornerShape(18.dp))
                                        .background(chColor)
                                        .padding(horizontal = 16.dp, vertical = 12.dp)
                                ) {
                                    Text(
                                        text = pick(ch.title, lang),
                                        color = Color.White,
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }
                            }

                            ch.lessons.forEach { l ->
                                val done = repository.isDone(l)
                                val isCurrent = l === current
                                val stars = state.lessonStars[l.id] ?: 0
                                val xOffsetFraction = sin(levelIndex * 1.1).toFloat() * 0.55f
                                levelIndex++
                                val displayLevel = levelIndex

                                item(key = "lvl_${l.id}") {
                                    val bias = (xOffsetFraction + 1f) / 2f
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(bottom = 18.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .wrapContentWidth(Alignment.Horizontal { size, space, _ ->
                                                    ((space - size) * bias).toInt()
                                                }),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            if (isCurrent && xOffsetFraction > 0f) {
                                                TutorAvatar(
                                                    tutor = tutor,
                                                    size = 64.dp,
                                                    mood = Mood.HAPPY,
                                                    gaze = Offset(0.9f, 0.1f)
                                                )
                                                Spacer(modifier = Modifier.width(6.dp))
                                            }
                                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                                Chunky(
                                                    modifier = Modifier
                                                        .width(92.dp)
                                                        .testTag("path_level_${l.id}"),
                                                    radius = 46.dp,
                                                    contentPadding = PaddingValues(vertical = 20.dp),
                                                    color = when {
                                                        done -> chColor
                                                        isCurrent -> ScolViolet
                                                        else -> ScolCloud
                                                    },
                                                    onClick = {
                                                        if (done || isCurrent) {
                                                            onOpenLesson(subject, l)
                                                        } else {
                                                            snackMessage = tr("locked", lang)
                                                        }
                                                    }
                                                ) {
                                                    val labelText = when {
                                                        done -> "★".repeat(stars) + "☆".repeat((3 - stars).coerceAtLeast(0))
                                                        isCurrent -> tr("start", lang)
                                                        else -> "🔒"
                                                    }
                                                    Text(
                                                        text = labelText,
                                                        fontSize = if (done) 20.sp else if (isCurrent) 15.sp else 24.sp,
                                                        color = Color.White
                                                    )
                                                }
                                                Spacer(modifier = Modifier.height(6.dp))
                                                Text(
                                                    text = "${tr("level", lang)} $displayLevel\n${pick(l.title, lang)}",
                                                    textAlign = TextAlign.Center,
                                                    fontSize = 14.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = if (done || isCurrent) ScolInk else ScolDisabledText,
                                                    modifier = Modifier.width(150.dp)
                                                )
                                            }
                                            if (isCurrent && xOffsetFraction <= 0f) {
                                                Spacer(modifier = Modifier.width(6.dp))
                                                TutorAvatar(
                                                    tutor = tutor,
                                                    size = 64.dp,
                                                    mood = Mood.HAPPY,
                                                    gaze = Offset(-0.9f, 0.1f)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
