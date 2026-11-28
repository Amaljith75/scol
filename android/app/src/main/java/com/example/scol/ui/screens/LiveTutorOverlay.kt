package com.example.scol.ui.screens

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import android.view.Window
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.scol.model.TutorCharacter
import com.example.scol.model.tr
import com.example.scol.network.GeminiLiveClient
import com.example.scol.network.LiveConnectionState
import com.example.scol.network.LiveTranscriptItem
import com.example.scol.tutor.Mood
import com.example.scol.ui.components.TutorAvatar
import com.example.ui.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.roundToInt

tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

suspend fun captureBoardRegionJpeg(
    rootView: View,
    window: Window?,
    boundsInRoot: androidx.compose.ui.geometry.Rect?
): Pair<ByteArray, Bitmap>? {
    if (rootView.width <= 0 || rootView.height <= 0) return null
    val cropRect = if (boundsInRoot != null && boundsInRoot.width > 16f && boundsInRoot.height > 16f) {
        val loc = IntArray(2)
        rootView.getLocationInWindow(loc)
        val left = (boundsInRoot.left.roundToInt() + loc[0]).coerceIn(0, rootView.width - 1)
        val top = (boundsInRoot.top.roundToInt() + loc[1]).coerceIn(0, rootView.height - 1)
        val right = (boundsInRoot.right.roundToInt() + loc[0]).coerceIn(left + 1, rootView.width)
        val bottom = (boundsInRoot.bottom.roundToInt() + loc[1]).coerceIn(top + 1, rootView.height)
        Rect(left, top, right, bottom)
    } else {
        Rect(0, 0, rootView.width, rootView.height)
    }

    val rawBitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && window != null) {
        val bmp = Bitmap.createBitmap(cropRect.width(), cropRect.height(), Bitmap.Config.ARGB_8888)
        val ok = suspendCancellableCoroutine { cont ->
            try {
                PixelCopy.request(
                    window,
                    cropRect,
                    bmp,
                    { res ->
                        if (cont.isActive) cont.resume(res == PixelCopy.SUCCESS)
                    },
                    Handler(Looper.getMainLooper())
                )
            } catch (_: Exception) {
                if (cont.isActive) cont.resume(false)
            }
        }
        if (ok) bmp else {
            bmp.recycle()
            null
        }
    } else {
        try {
            val full = Bitmap.createBitmap(rootView.width, rootView.height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(full)
            rootView.draw(canvas)
            val cropped = Bitmap.createBitmap(full, cropRect.left, cropRect.top, cropRect.width(), cropRect.height())
            if (cropped !== full) full.recycle()
            cropped
        } catch (_: Exception) {
            null
        }
    } ?: return null

    return withContext(Dispatchers.Default) {
        val maxSide = max(rawBitmap.width, rawBitmap.height).toFloat()
        val scale = if (maxSide > 640f) 640f / maxSide else 1f
        val scaled = if (scale < 1f) {
            val w = (rawBitmap.width * scale).roundToInt().coerceAtLeast(1)
            val h = (rawBitmap.height * scale).roundToInt().coerceAtLeast(1)
            Bitmap.createScaledBitmap(rawBitmap, w, h, true).also { rawBitmap.recycle() }
        } else {
            rawBitmap
        }
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 72, out)
        out.toByteArray() to scaled
    }
}

private fun imageProxyToJpeg(image: ImageProxy): ByteArray? {
    val planes = image.planes
    if (planes.size < 3) return null
    val yBuf = planes[0].buffer
    val uBuf = planes[1].buffer
    val vBuf = planes[2].buffer
    val ySize = yBuf.remaining()
    val uSize = uBuf.remaining()
    val vSize = vBuf.remaining()
    val nv21 = ByteArray(ySize + uSize + vSize)
    yBuf.get(nv21, 0, ySize)
    vBuf.get(nv21, ySize, vSize)
    uBuf.get(nv21, ySize + vSize, uSize)

    val yuv = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
    val rawOut = ByteArrayOutputStream()
    yuv.compressToJpeg(Rect(0, 0, image.width, image.height), 72, rawOut)
    val rawBytes = rawOut.toByteArray()

    val bmp = BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size) ?: return rawBytes
    val rot = image.imageInfo.rotationDegrees
    val rotated = if (rot != 0) {
        val matrix = Matrix().apply { postRotate(rot.toFloat()) }
        Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true).also { bmp.recycle() }
    } else bmp

    val maxSide = max(rotated.width, rotated.height).toFloat()
    val finalBmp = if (maxSide > 640f) {
        val s = 640f / maxSide
        Bitmap.createScaledBitmap(
            rotated,
            (rotated.width * s).roundToInt().coerceAtLeast(1),
            (rotated.height * s).roundToInt().coerceAtLeast(1),
            true
        ).also { rotated.recycle() }
    } else rotated

    val out = ByteArrayOutputStream()
    finalBmp.compress(Bitmap.CompressFormat.JPEG, 70, out)
    finalBmp.recycle()
    return out.toByteArray()
}

@Composable
fun CameraVisionPreview(
    onFrameCaptured: (ByteArray) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val latestCallback by rememberUpdatedState(onFrameCaptured)

    DisposableEffect(Unit) {
        onDispose { executor.shutdown() }
    }

    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            val future = ProcessCameraProvider.getInstance(ctx)
            future.addListener({
                try {
                    val provider = future.get()
                    val preview = Preview.Builder().build().apply {
                        surfaceProvider = previewView.surfaceProvider
                    }
                    var lastSentMs = 0L
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .apply {
                            setAnalyzer(executor) { image ->
                                val now = System.currentTimeMillis()
                                if (now - lastSentMs >= 1000L) {
                                    lastSentMs = now
                                    val jpeg = imageProxyToJpeg(image)
                                    if (jpeg != null) {
                                        latestCallback(jpeg)
                                    }
                                }
                                image.close()
                            }
                        }
                    provider.unbindAll()
                    provider.bindToLifecycle(
                        lifecycleOwner,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis
                    )
                } catch (_: Exception) {
                }
            }, ContextCompat.getMainExecutor(ctx))
            previewView
        },
        modifier = modifier
    )
}

@Composable
fun LiveTutorDock(
    tutor: TutorCharacter,
    lang: String,
    liveClient: GeminiLiveClient,
    cameraMode: Boolean,
    boardPreview: Bitmap?,
    onToggleCamera: (Boolean) -> Unit,
    onExplainWhatYouSee: () -> Unit,
    onCameraFrame: (ByteArray) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    val connState by liveClient.connectionState.collectAsState()
    val errorMsg by liveClient.errorMessage.collectAsState()
    val modelSpeaking by liveClient.modelSpeaking.collectAsState()
    val micStreaming by liveClient.micStreaming.collectAsState()
    val transcripts by liveClient.transcripts.collectAsState()

    val context = LocalContext.current
    var textDraft by remember { mutableStateOf("") }

    val micPermLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            liveClient.startMicStreaming()
        }
    }

    val cameraPermLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            onToggleCamera(true)
        }
    }

    // Start mic streaming automatically once connected if permission already granted
    LaunchedEffect(connState) {
        if (connState == LiveConnectionState.CONNECTED) {
            val hasMic = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            if (hasMic) {
                liveClient.startMicStreaming()
            }
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(Color.White)
            .border(3.dp, ScolViolet, RoundedCornerShape(24.dp))
            .padding(14.dp)
    ) {
        // Header row: Avatar + Character personality/voice + End Live button
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TutorAvatar(
                tutor = tutor,
                size = 64.dp,
                talking = modelSpeaking,
                mood = if (connState == LiveConnectionState.CONNECTED) Mood.HAPPY else Mood.CALM,
                float = modelSpeaking
            )
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = tutor.displayName(lang),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Black,
                        color = ScolInk
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(ScolVioletSoft)
                            .padding(horizontal = 8.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "${tutor.personalityTag(lang)} · ${tutor.liveVoiceName}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = ScolVioletDeep,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
                Spacer(modifier = Modifier.height(3.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val statusDot = when (connState) {
                        LiveConnectionState.CONNECTED -> ScolMint
                        LiveConnectionState.CONNECTING -> ScolSun
                        LiveConnectionState.MISSING_API_KEY, LiveConnectionState.ERROR -> ScolCoral
                        LiveConnectionState.IDLE -> ScolCloud
                    }
                    Box(
                        modifier = Modifier
                            .size(9.dp)
                            .clip(CircleShape)
                            .background(statusDot)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = when (connState) {
                            LiveConnectionState.CONNECTED ->
                                if (cameraMode) tr("liveWatchingCamera", lang) else tr("liveWatchingBoard", lang)
                            LiveConnectionState.CONNECTING -> tr("liveConnecting", lang)
                            LiveConnectionState.MISSING_API_KEY -> tr("liveNeedKey", lang)
                            LiveConnectionState.ERROR -> errorMsg ?: "Connection error"
                            LiveConnectionState.IDLE -> tr("liveReady", lang)
                        },
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = ScolMutedText,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            Spacer(modifier = Modifier.width(6.dp))
            Button(
                onClick = onClose,
                colors = ButtonDefaults.buttonColors(containerColor = ScolCoral),
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                modifier = Modifier.testTag("live_end_button")
            ) {
                Icon(Icons.Default.CallEnd, contentDescription = tr("endTalk", lang), modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(tr("endTalk", lang), fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Vision mode strip + Lesson-only badge + Explain what you see trigger
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Board vs Camera thumbnail preview showing what Gemini sees
            Box(
                modifier = Modifier
                    .size(width = 72.dp, height = 52.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(ScolCream)
                    .border(2.dp, ScolCloud, RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center
            ) {
                if (cameraMode) {
                    CameraVisionPreview(
                        onFrameCaptured = onCameraFrame,
                        modifier = Modifier.fillMaxSize()
                    )
                } else if (boardPreview != null) {
                    Image(
                        bitmap = boardPreview.asImageBitmap(),
                        contentDescription = "What Gemini sees on the lesson board",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                } else {
                    Icon(Icons.Default.Visibility, contentDescription = null, tint = ScolViolet)
                }
            }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    FilterChip(
                        selected = !cameraMode,
                        onClick = { onToggleCamera(false) },
                        label = { Text(tr("boardVision", lang), fontSize = 11.sp) },
                        leadingIcon = { Icon(Icons.Default.Visibility, contentDescription = null, modifier = Modifier.size(14.dp)) },
                        modifier = Modifier.height(30.dp).testTag("live_board_mode_chip")
                    )
                    FilterChip(
                        selected = cameraMode,
                        onClick = {
                            if (cameraMode) {
                                onToggleCamera(false)
                            } else {
                                val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                                    PackageManager.PERMISSION_GRANTED
                                if (granted) onToggleCamera(true) else cameraPermLauncher.launch(Manifest.permission.CAMERA)
                            }
                        },
                        label = { Text(tr("cameraVision", lang), fontSize = 11.sp) },
                        leadingIcon = { Icon(Icons.Default.PhotoCamera, contentDescription = null, modifier = Modifier.size(14.dp)) },
                        modifier = Modifier.height(30.dp).testTag("live_camera_mode_chip")
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color(0xFFE7F7EE))
                            .padding(horizontal = 7.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "📚 ${tr("lessonOnlyBadge", lang)}",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = ScolMint
                        )
                    }
                    AssistChip(
                        onClick = onExplainWhatYouSee,
                        enabled = connState == LiveConnectionState.CONNECTED,
                        label = { Text("👁️ ${tr("explainSee", lang)}", fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                        modifier = Modifier.height(28.dp).testTag("live_explain_see_button")
                    )
                }
            }
        }

        if (connState == LiveConnectionState.MISSING_API_KEY) {
            Spacer(modifier = Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color(0xFFFFF1D6))
                    .padding(10.dp)
            ) {
                Text(
                    text = tr("liveKeyHint", lang),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = ScolInk
                )
            }
        }

        // Live transcripts
        if (transcripts.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 120.dp),
                reverseLayout = true
            ) {
                items(transcripts.reversed(), key = { it.id }) { item ->
                    LiveTranscriptBubble(item)
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Mic + text input bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = textDraft,
                onValueChange = { textDraft = it },
                placeholder = { Text(tr("askLessonType", lang), fontSize = 13.sp) },
                singleLine = true,
                shape = RoundedCornerShape(22.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = ScolVioletSoft,
                    unfocusedContainerColor = ScolVioletSoft,
                    focusedBorderColor = ScolViolet,
                    unfocusedBorderColor = Color.Transparent
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = {
                    val msg = textDraft.trim()
                    if (msg.isNotEmpty() && connState == LiveConnectionState.CONNECTED) {
                        liveClient.sendTextMessage(msg)
                        textDraft = ""
                    }
                }),
                modifier = Modifier
                    .weight(1f)
                    .testTag("live_text_input")
            )
            Spacer(modifier = Modifier.width(8.dp))
            val hasText = textDraft.trim().isNotEmpty()
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            hasText -> ScolViolet
                            micStreaming -> ScolCoral
                            else -> ScolViolet
                        }
                    )
                    .clickable {
                        if (hasText) {
                            if (connState == LiveConnectionState.CONNECTED) {
                                liveClient.sendTextMessage(textDraft)
                                textDraft = ""
                            }
                        } else if (micStreaming) {
                            liveClient.stopMicStreaming()
                        } else {
                            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                                PackageManager.PERMISSION_GRANTED
                            if (granted) {
                                liveClient.startMicStreaming()
                            } else {
                                micPermLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        }
                    }
                    .testTag("live_mic_send_button"),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = when {
                        hasText -> Icons.AutoMirrored.Filled.Send
                        micStreaming -> Icons.Default.Mic
                        else -> Icons.Default.MicOff
                    },
                    contentDescription = if (hasText) "Send" else "Toggle microphone",
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

@Composable
private fun LiveTranscriptBubble(item: LiveTranscriptItem) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        contentAlignment = if (item.fromChild) Alignment.CenterEnd else Alignment.CenterStart
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(if (item.fromChild) ScolViolet else Color(0xFFF3F0FA))
                .padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            Text(
                text = item.text,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (item.fromChild) Color.White else ScolInk
            )
        }
    }
}
