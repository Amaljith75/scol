package com.example.scol.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Base64
import com.example.BuildConfig
import com.example.R
import com.example.scol.model.RAW_BASE
import com.example.scol.model.TutorCharacter
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

class ScolAudioEngine(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val http = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val voiceDir = File(context.cacheDir, "scol_voice").apply { mkdirs() }
    private val geminiVoiceDir = File(context.cacheDir, "scol_gemini_voice").apply { mkdirs() }

    private var mediaPlayer: MediaPlayer? = null
    private var geminiTrack: AudioTrack? = null
    private var speakJob: Job? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    private val speechEpoch = AtomicLong(0L)

    private val _speaking = MutableStateFlow(false)
    val speaking: StateFlow<Boolean> = _speaking.asStateFlow()

    private val _voiceStatus = MutableStateFlow("")
    val voiceStatus: StateFlow<String> = _voiceStatus.asStateFlow()

    var voiceEnabled: Boolean = true
    var voiceTone: String = "normal"

    /**
     * Invoked before any read-aloud starts so external players (such as GeminiLiveClient)
     * stop immediately and never overlap or mix with read-aloud audio.
     */
    var onBeforeSpeechPlay: (() -> Unit)? = null

    init {
        try {
            tts = TextToSpeech(context.applicationContext) { status ->
                ttsReady = status == TextToSpeech.SUCCESS
            }
        } catch (_: Exception) {
        }
    }

    private fun hasGeminiKey(): Boolean {
        val k = BuildConfig.GEMINI_API_KEY.trim()
        return k.isNotEmpty() && k != "MY_GEMINI_API_KEY"
    }

    fun playSound(name: String, volume: Float = 0.9f) {
        if (!voiceEnabled) return
        val resId = when (name) {
            "complete" -> R.raw.complete
            "correct" -> R.raw.correct
            "oops" -> R.raw.oops
            "pop" -> R.raw.pop
            "star1" -> R.raw.star1
            "star2" -> R.raw.star2
            "star3" -> R.raw.star3
            "whoosh" -> R.raw.whoosh
            else -> return
        }
        try {
            val mp = MediaPlayer.create(context, resId) ?: return
            mp.setVolume(volume, volume)
            mp.setOnCompletionListener { it.release() }
            mp.start()
        } catch (_: Exception) {
        }
    }

    private fun clipId(vararg keys: String): String {
        val raw = keys.joinToString("|")
        val bytes = MessageDigest.getInstance("SHA-1").digest(raw.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }.take(24)
    }

    private fun cleanForSpeech(text: String): String {
        return text.replace(Regex("[\\uD83C-\\uDBFF\\uDC00-\\uDFFF]+"), " ").trim()
    }

    fun say(parts: List<String>, lang: String, tutor: TutorCharacter, tone: String = voiceTone) {
        stop()
        if (!voiceEnabled) return
        val lines = parts.map { it.trim() }.filter { it.isNotEmpty() }
        if (lines.isEmpty()) return

        val myEpoch = speechEpoch.incrementAndGet()
        onBeforeSpeechPlay?.invoke()

        speakJob = scope.launch {
            _speaking.value = true
            for (line in lines) {
                if (!isActive || speechEpoch.get() != myEpoch) break

                // 1) Primary: Gemini character voice + emotion mode
                val playedGemini = tryPlayGeminiVoice(line, lang, tutor, tone, myEpoch)
                if (playedGemini) continue
                if (!isActive || speechEpoch.get() != myEpoch) break

                // 2) Fallback A: Ready-made Edge TTS clip (stop Phone TTS / Gemini first so zero overlap)
                stopAllPlayersOnly()
                val playedMp3 = tryPlayReadyMadeClip(line, lang, tutor, myEpoch)
                if (playedMp3) continue
                if (!isActive || speechEpoch.get() != myEpoch) break

                // 3) Fallback B: On-device Phone TTS with character & emotion tuning (never overlaps MP3/Gemini)
                stopAllPlayersOnly()
                _voiceStatus.value = "Phone TTS (${tutor.displayName("en")} · $tone)"
                speakWithTts(line, lang, tutor, tone, myEpoch)
            }
            if (speechEpoch.get() == myEpoch) {
                _speaking.value = false
            }
        }
    }

    private suspend fun tryPlayGeminiVoice(
        text: String,
        lang: String,
        tutor: TutorCharacter,
        tone: String,
        epoch: Long
    ): Boolean {
        if (!hasGeminiKey()) return false
        val clean = cleanForSpeech(text)
        if (clean.isEmpty()) return false

        val voiceName = tutor.liveVoiceName
        val id = clipId("gemini_tts_v1", tutor.id, voiceName, tone, lang, clean)
        val pcmFile = File(geminiVoiceDir, "${tutor.id}_$id.pcm")
        val rateFile = File(geminiVoiceDir, "${tutor.id}_$id.rate")

        val audioData: Pair<ByteArray, Int>? = withContext(Dispatchers.IO) {
            if (pcmFile.exists() && pcmFile.length() > 256) {
                val savedRate = rateFile.takeIf { it.exists() }?.readText()?.trim()?.toIntOrNull() ?: 24000
                return@withContext pcmFile.readBytes() to savedRate
            }
            fetchGeminiTtsPcm(clean, lang, tutor, tone)?.also { (pcm, rate) ->
                try {
                    pcmFile.writeBytes(pcm)
                    rateFile.writeText(rate.toString())
                } catch (_: Exception) {
                }
            }
        }

        if (audioData == null || speechEpoch.get() != epoch) return false
        val (pcm, sampleRate) = audioData
        if (pcm.isEmpty()) return false

        _voiceStatus.value = "Gemini ($voiceName · $tone)"
        return playPcmTrack(pcm, sampleRate, epoch)
    }

    private fun fetchGeminiTtsPcm(
        cleanText: String,
        lang: String,
        tutor: TutorCharacter,
        tone: String
    ): Pair<ByteArray, Int>? {
        val key = BuildConfig.GEMINI_API_KEY.trim()
        if (key.isEmpty() || key == "MY_GEMINI_API_KEY") return null

        val url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$key"
        val prompt = tutor.ttsStylePrompt(cleanText, lang, tone)

        val payload = JSONObject().apply {
            put("contents", JSONArray().apply {
                put(JSONObject().apply {
                    put("parts", JSONArray().apply {
                        put(JSONObject().apply { put("text", prompt) })
                    })
                })
            })
            put("generationConfig", JSONObject().apply {
                put("responseModalities", JSONArray().apply { put("AUDIO") })
                put("speechConfig", JSONObject().apply {
                    put("voiceConfig", JSONObject().apply {
                        put("prebuiltVoiceConfig", JSONObject().apply {
                            put("voiceName", tutor.liveVoiceName)
                        })
                    })
                })
            })
        }

        return try {
            val req = Request.Builder()
                .url(url)
                .addHeader("Content-Type", "application/json")
                .post(payload.toString().toRequestBody("application/json".toMediaType()))
                .build()
            http.newCall(req).execute().use { res ->
                if (!res.isSuccessful) return null
                val body = res.body?.string() ?: return null
                val root = JSONObject(body)
                val parts = root.optJSONArray("candidates")
                    ?.optJSONObject(0)
                    ?.optJSONObject("content")
                    ?.optJSONArray("parts") ?: return null
                for (i in 0 until parts.length()) {
                    val inline = parts.optJSONObject(i)?.optJSONObject("inlineData") ?: continue
                    val dataB64 = inline.optString("data", "")
                    if (dataB64.isEmpty()) continue
                    val mime = inline.optString("mimeType", "")
                    val rateMatch = Regex("rate=(\\d+)").find(mime)
                    val sampleRate = rateMatch?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 24000
                    val pcm = Base64.decode(dataB64, Base64.DEFAULT)
                    if (pcm.isNotEmpty()) return pcm to sampleRate
                }
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private suspend fun playPcmTrack(pcm: ByteArray, sampleRate: Int, epoch: Long): Boolean {
        if (speechEpoch.get() != epoch) return false
        stopAllPlayersOnly()
        onBeforeSpeechPlay?.invoke()

        return withContext(Dispatchers.IO) {
            if (speechEpoch.get() != epoch) return@withContext false
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(4800)

            var track: AudioTrack? = null
            try {
                track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(minBuf * 2)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()

                if (speechEpoch.get() != epoch) {
                    track.release()
                    return@withContext false
                }
                geminiTrack = track
                track.play()

                var offset = 0
                val chunkSize = 4096
                while (offset < pcm.size && isActive && speechEpoch.get() == epoch) {
                    val len = minOf(chunkSize, pcm.size - offset)
                    val written = track.write(pcm, offset, len)
                    if (written <= 0) break
                    offset += written
                }

                // Wait briefly so final PCM samples finish playing cleanly
                if (isActive && speechEpoch.get() == epoch) {
                    delay(180)
                }
                speechEpoch.get() == epoch
            } catch (_: Exception) {
                false
            } finally {
                try {
                    track?.pause()
                    track?.flush()
                    track?.stop()
                    track?.release()
                } catch (_: Exception) {
                }
                if (geminiTrack === track) geminiTrack = null
            }
        }
    }

    private suspend fun tryPlayReadyMadeClip(
        text: String,
        lang: String,
        tutor: TutorCharacter,
        epoch: Long
    ): Boolean {
        if (!tutor.readyMade || speechEpoch.get() != epoch) return false
        val voiceName = tutor.voiceFor(lang)
        if (voiceName.isEmpty()) return false
        val id = clipId(voiceName, lang, text).take(20)
        val file = File(voiceDir, "${tutor.id}_$id.mp3")

        val ready = withContext(Dispatchers.IO) {
            if (file.exists() && file.length() > 100) return@withContext true
            try {
                val url = "${RAW_BASE}voice/${tutor.id}/$id.mp3"
                val req = Request.Builder().url(url).build()
                http.newCall(req).execute().use { res ->
                    if (!res.isSuccessful) return@withContext false
                    val bytes = res.body?.bytes() ?: return@withContext false
                    if (bytes.size < 100) return@withContext false
                    file.writeBytes(bytes)
                    true
                }
            } catch (_: Exception) {
                false
            }
        }

        if (!ready || speechEpoch.get() != epoch) return false
        _voiceStatus.value = "Edge TTS ($voiceName)"
        onBeforeSpeechPlay?.invoke()
        return suspendCancellableCoroutine { cont ->
            try {
                val mp = MediaPlayer().apply {
                    setDataSource(file.absolutePath)
                    setOnCompletionListener {
                        it.release()
                        if (mediaPlayer === it) mediaPlayer = null
                        if (cont.isActive) cont.resume(true) {}
                    }
                    setOnErrorListener { it, _, _ ->
                        it.release()
                        if (mediaPlayer === it) mediaPlayer = null
                        if (cont.isActive) cont.resume(false) {}
                        true
                    }
                    prepare()
                    start()
                }
                mediaPlayer = mp
                cont.invokeOnCancellation {
                    try {
                        mp.stop()
                        mp.release()
                    } catch (_: Exception) {
                    }
                }
            } catch (_: Exception) {
                if (cont.isActive) cont.resume(false) {}
            }
        }
    }

    private suspend fun speakWithTts(
        text: String,
        lang: String,
        tutor: TutorCharacter,
        tone: String,
        epoch: Long
    ) {
        if (speechEpoch.get() != epoch) return
        val engine = tts
        if (!ttsReady || engine == null) {
            delay((text.length * 45L).coerceIn(900L, 4500L))
            return
        }
        val clean = cleanForSpeech(text)
        if (clean.isEmpty()) return

        onBeforeSpeechPlay?.invoke()
        suspendCancellableCoroutine<Unit> { cont ->
            val locale = if (lang == "ml") Locale.Builder().setLanguage("ml").setRegion("IN").build()
            else Locale.Builder().setLanguage("en").setRegion("IN").build()
            engine.language = locale
            engine.setPitch(tutor.effectiveTtsPitch(tone))
            engine.setSpeechRate(tutor.effectiveTtsRate(tone))
            val uid = "scol_${System.nanoTime()}"
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    if (utteranceId == uid && cont.isActive) cont.resume(Unit) {}
                }
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    if (utteranceId == uid && cont.isActive) cont.resume(Unit) {}
                }
            })
            val res = engine.speak(clean, TextToSpeech.QUEUE_FLUSH, null, uid)
            if (res == TextToSpeech.ERROR && cont.isActive) {
                cont.resume(Unit) {}
            }
            cont.invokeOnCancellation {
                try {
                    engine.stop()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun stopAllPlayersOnly() {
        try {
            geminiTrack?.let {
                it.pause()
                it.flush()
                it.stop()
                it.release()
            }
        } catch (_: Exception) {
        }
        geminiTrack = null

        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {
        }
        mediaPlayer = null

        try {
            tts?.stop()
        } catch (_: Exception) {
        }
    }

    fun stop() {
        speechEpoch.incrementAndGet()
        speakJob?.cancel()
        speakJob = null
        stopAllPlayersOnly()
        _speaking.value = false
    }

    fun release() {
        stop()
        scope.cancel()
        try {
            tts?.shutdown()
        } catch (_: Exception) {
        }
    }
}
