package com.example.scol.network

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.util.Base64
import android.util.Log
import com.example.BuildConfig
import com.example.scol.model.Lesson
import com.example.scol.model.LessonStep
import com.example.scol.model.Subject
import com.example.scol.model.TutorCharacter
import com.example.scol.model.pick
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

enum class LiveConnectionState {
    IDLE,
    CONNECTING,
    CONNECTED,
    MISSING_API_KEY,
    ERROR
}

data class LiveTranscriptItem(
    val id: Long,
    val fromChild: Boolean,
    val text: String
)

data class LiveTutorSessionConfig(
    val tutor: TutorCharacter,
    val lang: String,
    val tone: String,
    val childName: String,
    val subject: Subject,
    val lesson: Lesson,
    val currentStep: LessonStep?,
    val visualSummary: String
)

class GeminiLiveClient(private val context: Context) {
    companion object {
        private const val TAG = "GeminiLiveClient"
        private const val WS_URL =
            "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        private val LIVE_MODELS = listOf(
            "models/gemini-2.5-flash-native-audio-preview-12-2025",
            "models/gemini-live-2.5-flash-preview"
        )
        private const val INPUT_SAMPLE_RATE = 16000
        private const val OUTPUT_SAMPLE_RATE = 24000
    }

    private val okHttp = OkHttpClient.Builder()
        .connectTimeout(12, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _connectionState = MutableStateFlow(LiveConnectionState.IDLE)
    val connectionState: StateFlow<LiveConnectionState> = _connectionState.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _modelSpeaking = MutableStateFlow(false)
    val modelSpeaking: StateFlow<Boolean> = _modelSpeaking.asStateFlow()

    private val _micStreaming = MutableStateFlow(false)
    val micStreaming: StateFlow<Boolean> = _micStreaming.asStateFlow()

    private val _transcripts = MutableStateFlow<List<LiveTranscriptItem>>(emptyList())
    val transcripts: StateFlow<List<LiveTranscriptItem>> = _transcripts.asStateFlow()

    private var webSocket: WebSocket? = null
    private var activeConfig: LiveTutorSessionConfig? = null
    private var modelAttemptIndex = 0
    private var setupComplete = false
    private var onReadyPrompt: String? = null

    private var audioTrack: AudioTrack? = null
    private var audioQueue = Channel<ByteArray>(Channel.UNLIMITED)
    private var playbackJob: Job? = null
    private var speakingTimeoutJob: Job? = null

    private var audioRecord: AudioRecord? = null
    private var recordJob: Job? = null

    private var transcriptSeq = 1L
    private val currentModelBuffer = StringBuilder()
    private val currentUserBuffer = StringBuilder()

    /**
     * Invoked before Gemini Live starts outputting audio so other TTS engines stop cleanly.
     */
    var onAudioPlaybackStarting: (() -> Unit)? = null

    fun stopOutputAudioOnly() {
        flushAudioOutput()
    }

    fun hasValidApiKey(): Boolean {
        val key = BuildConfig.GEMINI_API_KEY.trim()
        return key.isNotEmpty() && key != "MY_GEMINI_API_KEY"
    }

    fun connect(config: LiveTutorSessionConfig, initialPrompt: String? = null) {
        disconnect()
        if (!hasValidApiKey()) {
            _connectionState.value = LiveConnectionState.MISSING_API_KEY
            _errorMessage.value = "Add GEMINI_API_KEY in the AI Studio Secrets panel to start Gemini Live."
            return
        }
        activeConfig = config
        onReadyPrompt = initialPrompt
        modelAttemptIndex = 0
        _transcripts.value = emptyList()
        currentModelBuffer.clear()
        currentUserBuffer.clear()
        openSocketForAttempt()
    }

    private fun openSocketForAttempt() {
        val config = activeConfig ?: return
        setupComplete = false
        _connectionState.value = LiveConnectionState.CONNECTING
        _errorMessage.value = null

        val apiKey = BuildConfig.GEMINI_API_KEY.trim()
        val req = Request.Builder()
            .url("$WS_URL?key=$apiKey")
            .build()

        startAudioOutputPlayer()

        webSocket = okHttp.newWebSocket(req, object : WebSocketListener() {
            override fun onOpen(ws: WebSocket, response: Response) {
                val model = LIVE_MODELS.getOrElse(modelAttemptIndex) { LIVE_MODELS.last() }
                val setupJson = buildSetupPayload(model, config)
                ws.send(setupJson.toString())
            }

            override fun onMessage(ws: WebSocket, text: String) {
                handleServerMessage(text)
            }

            override fun onMessage(ws: WebSocket, bytes: okio.ByteString) {
                handleServerMessage(bytes.utf8())
            }

            override fun onClosing(ws: WebSocket, code: Int, reason: String) {
                ws.close(1000, null)
            }

            override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                if (webSocket !== ws) return
                if (!setupComplete && modelAttemptIndex + 1 < LIVE_MODELS.size) {
                    modelAttemptIndex++
                    Log.w(TAG, "Live setup closed ($code: $reason); retrying with fallback model")
                    openSocketForAttempt()
                    return
                }
                _micStreaming.value = false
                _modelSpeaking.value = false
                if (!setupComplete && code != 1000) {
                    _connectionState.value = LiveConnectionState.ERROR
                    _errorMessage.value = reason.ifBlank { "Live connection closed ($code)" }
                } else {
                    _connectionState.value = LiveConnectionState.IDLE
                }
            }

            override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                if (webSocket !== ws) return
                if (!setupComplete && modelAttemptIndex + 1 < LIVE_MODELS.size) {
                    modelAttemptIndex++
                    openSocketForAttempt()
                    return
                }
                Log.e(TAG, "Live WebSocket failure", t)
                _micStreaming.value = false
                _modelSpeaking.value = false
                _connectionState.value = LiveConnectionState.ERROR
                _errorMessage.value = t.localizedMessage ?: "Unable to connect to Gemini Live."
            }
        })
    }

    private fun buildSetupPayload(model: String, config: LiveTutorSessionConfig): JSONObject {
        val sysText = buildSystemInstruction(config)
        return JSONObject().apply {
            put("setup", JSONObject().apply {
                put("model", model)
                put("generationConfig", JSONObject().apply {
                    put("responseModalities", JSONArray().apply { put("AUDIO") })
                    put("speechConfig", JSONObject().apply {
                        put("voiceConfig", JSONObject().apply {
                            put("prebuiltVoiceConfig", JSONObject().apply {
                                put("voiceName", config.tutor.liveVoiceName)
                            })
                        })
                    })
                })
                put("inputAudioTranscription", JSONObject())
                put("outputAudioTranscription", JSONObject())
                put("systemInstruction", JSONObject().apply {
                    put("parts", JSONArray().apply {
                        put(JSONObject().apply {
                            put("text", sysText)
                        })
                    })
                })
            })
        }
    }

    fun buildSystemInstruction(config: LiveTutorSessionConfig): String {
        val t = config.tutor
        val isMl = config.lang == "ml"
        val langLabel = if (isMl) {
            "Malayalam (മലയാളം — simple, warm, natural spoken Malayalam)"
        } else {
            "English (simple, warm Indian school English)"
        }
        val subjectName = pick(config.subject.name, if (isMl) "ml" else "en").ifBlank { pick(config.subject.name, "en") }
        val lessonTitle = pick(config.lesson.title, if (isMl) "ml" else "en").ifBlank { pick(config.lesson.title, "en") }
        val objective = pick(config.lesson.objective, if (isMl) "ml" else "en").ifBlank { pick(config.lesson.objective, "en") }
        val stepText = config.currentStep?.let { pick(it.text, config.lang) }.orEmpty()
        val lessonNotes = config.lesson.steps
            .filter { !it.isAsk }
            .take(8)
            .joinToString(" | ") { pick(it.text, config.lang).ifBlank { pick(it.text, "en") } }

        val toneGuidance = t.emotionDirection(config.tone)
        val languageEnforcement = if (isMl) {
            """
STRICT MALAYALAM MODE (MANDATORY):
- You MUST speak, teach, and explain EVERYTHING strictly in simple, natural spoken Malayalam (മലയാളം).
- Describe every visual detail, hint, praise, and even off-topic redirections in Malayalam. Do NOT speak whole sentences in English.
            """.trimIndent()
        } else {
            "Speak naturally in $langLabel."
        }

        return """
${t.personalityInstruction}

VOICE EMOTION MODE (${config.tone.uppercase()}):
$toneGuidance

STUDENT & LANGUAGE:
- Student's name: ${config.childName.ifBlank { "friend" }}
- Speak primarily in: $langLabel.
$languageEnforcement

ACTIVE LESSON CONTEXT (YOU ARE TEACHING THIS LESSON ONLY):
- Subject: $subjectName
- Lesson Title: $lessonTitle
${if (objective.isNotBlank()) "- Objective: $objective" else ""}
- Key lesson flow: $lessonNotes
- Current Step on Screen: ${stepText.ifBlank { "Starting the lesson" }}
${if (config.visualSummary.isNotBlank()) "- Current Board Visual: ${config.visualSummary}" else ""}

REAL-TIME VISION TUTOR BEHAVIOR:
1. You continuously see JPEG frames from the student's live SCOL lesson board or camera.
2. When explaining what you see, naturally describe the exact visual items visible right now (such as bundles of sticks, abacus beads in 100s/10s/1s, shapes, number lines, rulers, currency notes, or textbook pages) and walk the student through how they connect to this lesson!
3. Keep each spoken turn concise (1 to 3 short, vivid sentences) and end with a gentle check-in question from the lesson when helpful.

STRICT LESSON-ONLY GUARDRAIL (MANDATORY — NEVER BREAK THIS):
- You MUST ONLY teach and discuss topics directly related to this active SCOL lesson ("$lessonTitle" in "$subjectName"), the math/science concepts inside it, and what is visible on the board or camera for this lesson.
- NEVER answer out-of-topic questions (no movies, video games, sports, news, coding, cartoons, general trivia, politics, or unrelated subjects).
- If the student asks anything off-topic, warmly decline in character (one brief playful line in $langLabel) and immediately bring attention back to "$lessonTitle".
        """.trimIndent()
    }

    private fun handleServerMessage(raw: String) {
        try {
            val json = JSONObject(raw)

            if (json.has("setupComplete")) {
                setupComplete = true
                _connectionState.value = LiveConnectionState.CONNECTED
                val prompt = onReadyPrompt
                onReadyPrompt = null
                if (!prompt.isNullOrBlank()) {
                    sendTextMessage(prompt)
                }
                return
            }

            val serverContent = json.optJSONObject("serverContent") ?: return

            if (serverContent.optBoolean("interrupted", false)) {
                flushAudioOutput()
                finalizeTurnBuffers()
            }

            // Input speech transcription
            serverContent.optJSONObject("inputTranscription")?.optString("text")?.takeIf { it.isNotEmpty() }?.let { chunk ->
                currentUserBuffer.append(chunk)
                upsertLiveTranscript(fromChild = true, text = currentUserBuffer.toString())
            }

            // Output speech transcription
            serverContent.optJSONObject("outputTranscription")?.optString("text")?.takeIf { it.isNotEmpty() }?.let { chunk ->
                currentModelBuffer.append(chunk)
                upsertLiveTranscript(fromChild = false, text = currentModelBuffer.toString())
            }

            // Audio / text parts from modelTurn
            serverContent.optJSONObject("modelTurn")?.optJSONArray("parts")?.let { parts ->
                for (i in 0 until parts.length()) {
                    val part = parts.optJSONObject(i) ?: continue
                    val inline = part.optJSONObject("inlineData")
                    if (inline != null) {
                        val mime = inline.optString("mimeType", "")
                        val dataB64 = inline.optString("data", "")
                        if (mime.startsWith("audio/pcm") && dataB64.isNotEmpty()) {
                            val pcm = Base64.decode(dataB64, Base64.DEFAULT)
                            enqueueAudioOutput(pcm)
                        }
                    }
                    val txt = part.optString("text", "").trim()
                    if (txt.isNotEmpty() && currentModelBuffer.isEmpty()) {
                        currentModelBuffer.append(txt)
                        upsertLiveTranscript(fromChild = false, text = currentModelBuffer.toString())
                    }
                }
            }

            if (serverContent.optBoolean("turnComplete", false)) {
                finalizeTurnBuffers()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed parsing Gemini Live server message", e)
        }
    }

    private fun upsertLiveTranscript(fromChild: Boolean, text: String) {
        val clean = text.trim()
        if (clean.isEmpty()) return
        val list = _transcripts.value.toMutableList()
        val last = list.lastOrNull()
        if (last != null && last.fromChild == fromChild && last.id < 0L) {
            list[list.lastIndex] = last.copy(text = clean)
        } else {
            // Use negative temporary ID until turn finishes
            list.add(LiveTranscriptItem(id = -(transcriptSeq++), fromChild = fromChild, text = clean))
        }
        _transcripts.value = list
    }

    private fun finalizeTurnBuffers() {
        val list = _transcripts.value.map {
            if (it.id < 0L) it.copy(id = transcriptSeq++) else it
        }
        _transcripts.value = list
        currentModelBuffer.clear()
        currentUserBuffer.clear()
    }

    fun sendVideoFrame(jpegBytes: ByteArray, explainNowPrompt: String? = null) {
        val ws = webSocket ?: return
        if (!setupComplete) return
        val b64 = Base64.encodeToString(jpegBytes, Base64.NO_WRAP)
        val payload = JSONObject().apply {
            put("realtimeInput", JSONObject().apply {
                put("mediaChunks", JSONArray().apply {
                    put(JSONObject().apply {
                        put("mimeType", "image/jpeg")
                        put("data", b64)
                    })
                })
            })
        }
        ws.send(payload.toString())
        if (!explainNowPrompt.isNullOrBlank()) {
            sendTextMessage(explainNowPrompt)
        }
    }

    fun sendTextMessage(text: String) {
        val ws = webSocket ?: return
        val clean = text.trim()
        if (!setupComplete || clean.isEmpty()) return
        val payload = JSONObject().apply {
            put("clientContent", JSONObject().apply {
                put("turns", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "user")
                        put("parts", JSONArray().apply {
                            put(JSONObject().apply {
                                put("text", clean)
                            })
                        })
                    })
                })
                put("turnComplete", true)
            })
        }
        ws.send(payload.toString())
        finalizeTurnBuffers()
        val list = _transcripts.value.toMutableList()
        list.add(LiveTranscriptItem(id = transcriptSeq++, fromChild = true, text = clean))
        _transcripts.value = list
    }

    fun notifyLessonStepChanged(stepText: String, visualSummary: String, jpegBytes: ByteArray?, lang: String = activeConfig?.lang ?: "en") {
        if (!setupComplete) return
        if (jpegBytes != null) {
            sendVideoFrame(jpegBytes)
        }
        val msg = if (lang == "ml") {
            buildString {
                append("[പാഠം അടുത്ത ഘട്ടത്തിലേക്ക് മാറി] ")
                if (stepText.isNotBlank()) append("ഇപ്പോഴത്തെ ഘട്ടം: \"$stepText\". ")
                if (visualSummary.isNotBlank()) append("ബോർഡിലുള്ളത്: $visualSummary. ")
                append("ചിത്രം നോക്കി നിങ്ങളുടെ കഥാപാത്രത്തിന്റെ ശബ്ദത്തിൽ 1-2 ചെറിയ വാക്യങ്ങളിൽ മലയാളത്തിൽ മാത്രം വിശദീകരിക്കൂ.")
            }
        } else {
            buildString {
                append("[Lesson screen updated] ")
                if (stepText.isNotBlank()) append("Current lesson step: \"$stepText\". ")
                if (visualSummary.isNotBlank()) append("Visual: $visualSummary. ")
                append("Look at the updated image and briefly explain what you see in 1-2 short sentences in your character voice and emotion mode.")
            }
        }
        val ws = webSocket ?: return
        val payload = JSONObject().apply {
            put("clientContent", JSONObject().apply {
                put("turns", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "user")
                        put("parts", JSONArray().apply {
                            put(JSONObject().apply {
                                put("text", msg)
                            })
                        })
                    })
                })
                put("turnComplete", true)
            })
        }
        ws.send(payload.toString())
    }

    @SuppressLint("MissingPermission")
    fun startMicStreaming(): Boolean {
        if (_micStreaming.value) return true
        val minBuf = AudioRecord.getMinBufferSize(
            INPUT_SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(3200)
        return try {
            val rec = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                INPUT_SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuf * 2
            )
            if (rec.state != AudioRecord.STATE_INITIALIZED) {
                rec.release()
                return false
            }
            rec.startRecording()
            audioRecord = rec
            _micStreaming.value = true
            recordJob = scope.launch {
                val buf = ByteArray(minBuf)
                while (isActive && _micStreaming.value) {
                    val read = rec.read(buf, 0, buf.size)
                    if (read > 0 && setupComplete) {
                        val b64 = Base64.encodeToString(buf, 0, read, Base64.NO_WRAP)
                        val chunk = JSONObject().apply {
                            put("realtimeInput", JSONObject().apply {
                                put("mediaChunks", JSONArray().apply {
                                    put(JSONObject().apply {
                                        put("mimeType", "audio/pcm;rate=16000")
                                        put("data", b64)
                                    })
                                })
                            })
                        }
                        webSocket?.send(chunk.toString())
                    }
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Unable to start AudioRecord", e)
            _micStreaming.value = false
            false
        }
    }

    fun stopMicStreaming() {
        _micStreaming.value = false
        recordJob?.cancel()
        recordJob = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {
        }
        audioRecord = null
    }

    private fun startAudioOutputPlayer() {
        stopAudioOutputPlayer()
        audioQueue = Channel(Channel.UNLIMITED)
        val minBuf = AudioTrack.getMinBufferSize(
            OUTPUT_SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(4800)

        try {
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(OUTPUT_SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(minBuf * 2)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            track.play()
            audioTrack = track
            playbackJob = scope.launch {
                for (pcm in audioQueue) {
                    if (!isActive) break
                    _modelSpeaking.value = true
                    speakingTimeoutJob?.cancel()
                    track.write(pcm, 0, pcm.size)
                    speakingTimeoutJob = scope.launch {
                        delay(420)
                        _modelSpeaking.value = false
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed creating AudioTrack", e)
        }
    }

    private fun enqueueAudioOutput(pcm: ByteArray) {
        onAudioPlaybackStarting?.invoke()
        audioQueue.trySend(pcm)
    }

    private fun flushAudioOutput() {
        while (audioQueue.tryReceive().isSuccess) {
            // drain queued audio chunks on barge-in
        }
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.play()
        } catch (_: Exception) {
        }
        _modelSpeaking.value = false
    }

    private fun stopAudioOutputPlayer() {
        speakingTimeoutJob?.cancel()
        playbackJob?.cancel()
        playbackJob = null
        audioQueue.close()
        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (_: Exception) {
        }
        audioTrack = null
        _modelSpeaking.value = false
    }

    fun disconnect() {
        setupComplete = false
        onReadyPrompt = null
        stopMicStreaming()
        val ws = webSocket
        webSocket = null
        try {
            ws?.close(1000, "Session ended")
        } catch (_: Exception) {
        }
        stopAudioOutputPlayer()
        _connectionState.value = LiveConnectionState.IDLE
    }

    fun release() {
        disconnect()
        scope.cancel()
    }
}
