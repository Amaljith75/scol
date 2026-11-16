package com.example.scol.ui.screens

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.example.scol.audio.ScolAudioEngine
import com.example.scol.data.ScolRepository
import com.example.scol.model.pick
import com.example.scol.model.tr
import com.example.scol.network.TutorBrainClient
import com.example.scol.tutor.Mood
import com.example.scol.ui.components.TutorAvatar
import com.example.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun AskDisabledDialog(
    lang: String,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(tr("askTitle", lang), fontWeight = FontWeight.Black) },
        text = { Text(tr("askOff", lang), lineHeight = 22.sp) },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("OK", fontWeight = FontWeight.Bold)
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AskBottomSheet(
    lessonTitle: String,
    notes: String,
    repository: ScolRepository,
    audio: ScolAudioEngine,
    brain: TutorBrainClient,
    onDismiss: () -> Unit
) {
    val bundle by repository.bundle.collectAsState()
    val state by repository.state.collectAsState()
    val speaking by audio.speaking.collectAsState()
    val lang = state.mainLang
    val tutor = remember(bundle, state.tutorId) { bundle.tutor(state.tutorId) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var inputText by remember { mutableStateOf("") }
    var heardText by remember { mutableStateOf("") }
    var listening by remember { mutableStateOf(false) }
    var thinking by remember { mutableStateOf(false) }
    var micMissing by remember { mutableStateOf(false) }
    var liveTalk by remember { mutableStateOf(true) }
    val chat = remember { mutableStateListOf<Pair<String, String>>() }

    val speechAvailable = remember { SpeechRecognizer.isRecognitionAvailable(context) }
    var recognizer by remember { mutableStateOf<SpeechRecognizer?>(null) }

    fun sendQuestion(raw: String) {
        val q = raw.trim()
        if (q.length < 2 || thinking) return
        try {
            recognizer?.stopListening()
        } catch (_: Exception) {
        }
        listening = false
        thinking = true
        inputText = ""
        heardText = ""

        scope.launch {
            val reply = brain.askBrain(
                bundle = bundle,
                question = q,
                lang = lang,
                tutorName = tutor.displayName("en"),
                about = pick(tutor.about, "en"),
                lessonTitle = lessonTitle,
                notes = notes,
                tone = state.tone,
                childName = state.childName,
                progress = repository.progressFacts(lang),
                history = chat.toList(),
                tutor = tutor
            )
            thinking = false
            chat.add(q to reply.text)
            if (state.voiceOn) {
                audio.say(listOf(reply.text), lang, tutor, state.tone)
            }
        }
    }

    fun startSpeechCapture() {
        if (thinking) return
        audio.stop()
        if (!speechAvailable) {
            micMissing = true
            return
        }
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            micMissing = true
            return
        }
        try {
            val rec = recognizer ?: SpeechRecognizer.createSpeechRecognizer(context).also { recognizer = it }
            rec.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    listening = true
                    heardText = ""
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    listening = false
                }
                override fun onError(error: Int) {
                    listening = false
                }
                override fun onResults(results: Bundle?) {
                    listening = false
                    val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val phrase = list?.firstOrNull()?.trim().orEmpty()
                    if (phrase.length >= 2) {
                        sendQuestion(phrase)
                    }
                }
                override fun onPartialResults(partialResults: Bundle?) {
                    val list = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val phrase = list?.firstOrNull().orEmpty()
                    if (phrase.isNotEmpty()) heardText = phrase
                }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, if (lang == "ml") "ml-IN" else "en-IN")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            listening = true
            rec.startListening(intent)
        } catch (_: Exception) {
            listening = false
            micMissing = true
        }
    }

    val permLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            micMissing = false
            startSpeechCapture()
        } else {
            micMissing = true
        }
    }

    // Re-listen in live talk mode after tutor finishes speaking
    var wasSpeaking by remember { mutableStateOf(false) }
    LaunchedEffect(speaking) {
        if (wasSpeaking && !speaking && liveTalk && !listening && !thinking && chat.isNotEmpty()) {
            startSpeechCapture()
        }
        wasSpeaking = speaking
    }

    LaunchedEffect(Unit) {
        audio.stop()
        if (speechAvailable) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            if (granted) {
                startSpeechCapture()
            } else {
                permLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        } else {
            micMissing = true
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            try {
                recognizer?.destroy()
            } catch (_: Exception) {
            }
            audio.stop()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color.White,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = 18.dp, vertical = 10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TutorAvatar(
                    tutor = tutor,
                    size = 76.dp,
                    talking = speaking,
                    mood = if (thinking) Mood.CARING else Mood.HAPPY,
                    gaze = if (listening) Offset.Zero else Offset(0.6f, 0.6f)
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = when {
                        thinking -> tr("askThinking", lang)
                        listening -> tr("askListening", lang)
                        else -> tr("askPrompt", lang).replace("{name}", tutor.displayName(lang))
                    },
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = ScolInk,
                    modifier = Modifier.weight(1f)
                )
                if (liveTalk) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Button(
                        onClick = {
                            audio.stop()
                            try {
                                recognizer?.stopListening()
                            } catch (_: Exception) {
                            }
                            liveTalk = false
                            listening = false
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = ScolCoral),
                        shape = RoundedCornerShape(50),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                        modifier = Modifier.testTag("ask_end_talk_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.CallEnd,
                            contentDescription = tr("endTalk", lang),
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(tr("endTalk", lang), fontWeight = FontWeight.Bold)
                    }
                }
            }

            if (chat.isEmpty() && !thinking) {
                Spacer(modifier = Modifier.height(6.dp))
                SuggestionChip(
                    onClick = { sendQuestion(tr("myProgress", lang)) },
                    label = { Text(tr("myProgress", lang), fontWeight = FontWeight.Bold) }
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 60.dp, max = 240.dp),
                reverseLayout = true
            ) {
                if (heardText.isNotEmpty()) {
                    item { AskBubble(heardText, mine = true, faint = true) }
                }
                items(chat.reversed()) { (q, a) ->
                    Column {
                        AskBubble(q, mine = true)
                        AskBubble(a, mine = false)
                    }
                }
            }

            if (micMissing) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = tr("askNoMic", lang),
                    color = ScolMutedText,
                    fontSize = 13.sp
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text(tr("askType", lang)) },
                    singleLine = true,
                    shape = RoundedCornerShape(24.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = ScolVioletSoft,
                        unfocusedContainerColor = ScolVioletSoft,
                        focusedBorderColor = ScolViolet,
                        unfocusedBorderColor = Color.Transparent
                    ),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { sendQuestion(inputText) }),
                    modifier = Modifier
                        .weight(1f)
                        .testTag("ask_input_field")
                )

                Spacer(modifier = Modifier.width(10.dp))

                val fabColor by animateColorAsState(
                    targetValue = if (listening) ScolCoral else ScolViolet,
                    label = "ask_mic_color"
                )
                val hasTyped = inputText.trim().isNotEmpty()

                Box(
                    modifier = Modifier
                        .size(58.dp)
                        .clip(CircleShape)
                        .background(fabColor)
                        .clickable {
                            when {
                                listening -> {
                                    try {
                                        recognizer?.stopListening()
                                    } catch (_: Exception) {
                                    }
                                    listening = false
                                }
                                hasTyped -> sendQuestion(inputText)
                                else -> {
                                    audio.stop()
                                    liveTalk = true
                                    if (!speechAvailable) {
                                        micMissing = true
                                    } else {
                                        val granted = ContextCompat.checkSelfPermission(
                                            context,
                                            Manifest.permission.RECORD_AUDIO
                                        ) == PackageManager.PERMISSION_GRANTED
                                        if (granted) startSpeechCapture() else permLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                    }
                                }
                            }
                        }
                        .testTag("ask_action_button"),
                    contentAlignment = Alignment.Center
                ) {
                    when {
                        thinking -> CircularProgressIndicator(
                            color = Color.White,
                            strokeWidth = 3.dp,
                            modifier = Modifier.size(26.dp)
                        )
                        listening -> Icon(
                            imageVector = Icons.Default.Stop,
                            contentDescription = "Stop listening",
                            tint = Color.White,
                            modifier = Modifier.size(30.dp)
                        )
                        hasTyped -> Icon(
                            imageVector = Icons.AutoMirrored.Filled.Send,
                            contentDescription = "Send question",
                            tint = Color.White,
                            modifier = Modifier.size(26.dp)
                        )
                        else -> Icon(
                            imageVector = Icons.Default.Mic,
                            contentDescription = "Speak question",
                            tint = Color.White,
                            modifier = Modifier.size(30.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))
        }
    }
}

@Composable
private fun AskBubble(
    text: String,
    mine: Boolean,
    faint: Boolean = false
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        contentAlignment = if (mine) Alignment.CenterEnd else Alignment.CenterStart
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(
                    when {
                        mine && faint -> ScolVioletSoft
                        mine -> ScolViolet
                        else -> Color(0xFFF3F0FA)
                    }
                )
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(
                text = text,
                fontSize = 16.sp,
                lineHeight = 22.sp,
                color = if (mine && !faint) Color.White else ScolInk,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
