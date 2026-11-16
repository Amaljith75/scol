package com.example.scol.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.scol.model.TutorCharacter
import com.example.scol.tutor.Mood
import kotlinx.coroutines.delay
import kotlin.math.*
import kotlin.random.Random

fun creatureRadius(shape: String, a: Double, t: Double): Double {
    val wobble = 0.035 * sin(3 * a + t * 2 * PI) + 0.025 * sin(2 * a - t * 4 * PI)
    return when (shape) {
        "spiky" -> 0.70 + 0.30 * abs(cos(4 * a + 0.4)).pow(2.2) + wobble * 0.6
        "cloud" -> 0.80 + 0.17 * abs(sin(3 * a + 0.5)) + wobble * 0.5
        "flower" -> 0.70 + 0.28 * abs(cos(2.5 * a)) + wobble * 0.5
        "bean" -> {
            val squash = 1.0 / sqrt(cos(a) * cos(a) + (sin(a) / 0.76) * (sin(a) / 0.76))
            squash * 0.96 + wobble
        }
        else -> 0.86 + 0.07 * sin(3 * a + 1.0) + 0.05 * sin(2 * a + 2.0) + wobble * 1.6
    }
}

fun buildCreaturePath(shape: String, c: Offset, r: Float, t: Double): Path {
    val path = Path()
    val n = 96
    for (i in 0..n) {
        val a = i.toDouble() / n * 2.0 * PI
        val rr = r * creatureRadius(shape, a, t).toFloat()
        val px = c.x + rr * cos(a).toFloat()
        val py = c.y + rr * sin(a).toFloat()
        if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
    }
    path.close()
    return path
}

@Composable
fun TutorAvatar(
    tutor: TutorCharacter,
    modifier: Modifier = Modifier,
    size: Dp = 96.dp,
    talking: Boolean = false,
    mood: Mood = Mood.CALM,
    gaze: Offset = Offset.Zero,
    float: Boolean = false
) {
    val infiniteTransition = rememberInfiniteTransition(label = "tutor_wobble")
    val t by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 3200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "t"
    )

    var blink by remember { mutableStateOf(false) }
    var wander by remember { mutableStateOf(Offset.Zero) }
    var smoothEyes by remember { mutableStateOf(gaze) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(1800L + Random.nextLong(2800L))
            blink = true
            delay(130L)
            blink = false
        }
    }

    LaunchedEffect(Unit) {
        while (true) {
            wander = Offset(Random.nextFloat() - 0.5f, Random.nextFloat() - 0.5f) * 0.35f
            delay(1100L + Random.nextLong(1900L))
        }
    }

    val targetEyes = remember(gaze, wander) {
        val clamped = if (gaze.getDistance() > 1f) gaze / gaze.getDistance() else gaze
        clamped + wander * (if (clamped == Offset.Zero) 1f else 0.3f)
    }

    val animEyeX by animateFloatAsState(targetValue = targetEyes.x, animationSpec = tween(220), label = "eyeX")
    val animEyeY by animateFloatAsState(targetValue = targetEyes.y, animationSpec = tween(220), label = "eyeY")
    smoothEyes = Offset(animEyeX, animEyeY)

    val e = tutor.energy.toDouble()
    val hopAmp = if (mood == Mood.HAPPY) 0.10 else 0.035
    val freq = if (e > 1.4) 2.0 else 1.0
    val bobFrac = -(abs(sin(t * 2.0 * PI * freq))) * hopAmp * e.coerceIn(0.6, 1.6)
    val floatFrac = if (float) sin(t * 2.0 * PI) * 0.06 else 0.0

    Canvas(
        modifier = modifier
            .size(size)
            .graphicsLayer {
                translationX = (floatFrac * this.size.width).toFloat()
                translationY = ((bobFrac + 0.04) * this.size.height).toFloat()
            }
    ) {
        val s = this.size.width
        val c = Offset(s / 2f, s / 2f)
        val bodyColor = tutor.color
        val dark = Color(0xFF23243A)

        // Floor shadow
        drawOval(
            color = Color(0x22000000),
            topLeft = Offset(s / 2f - s * 0.25f, s * 0.94f),
            size = Size(s * 0.5f, s * 0.06f)
        )

        // Jelly creature body
        val path = buildCreaturePath(tutor.shape, c, s * 0.46f, t.toDouble())
        drawPath(path, color = bodyColor)

        clipPath(path) {
            drawCircle(
                color = Color(0x33FFFFFF),
                radius = s * 0.24f,
                center = Offset(s * 0.34f, s * 0.26f)
            )
        }

        // Eyes
        val eyeStyle = tutor.eyes
        val eyeR = s * when (eyeStyle) {
            "wide" -> 0.125f
            "soft" -> 0.085f
            else -> 0.105f
        }
        val gap = s * if (tutor.shape == "bean") 0.17f else 0.14f
        val eyeY = s * 0.46f
        val lookShift = Offset(smoothEyes.x * s * 0.03f, smoothEyes.y * s * 0.025f)

        for (side in listOf(-1f, 1f)) {
            var r = eyeR
            if (eyeStyle == "curious" && side > 0f) r = eyeR * 1.22f
            val centre = Offset(s / 2f + side * gap, eyeY) + lookShift
            if (blink) {
                drawLine(
                    color = dark,
                    start = centre.copy(x = centre.x - r * 0.8f),
                    end = centre.copy(x = centre.x + r * 0.8f),
                    strokeWidth = s * 0.03f,
                    cap = StrokeCap.Round
                )
                continue
            }
            drawCircle(color = Color.White, radius = r, center = centre)
            val pupilR = r * 0.58f
            val pupil = centre + Offset(smoothEyes.x, smoothEyes.y) * (r - pupilR) * 0.95f
            drawCircle(color = dark, radius = pupilR, center = pupil)
            drawCircle(
                color = Color.White,
                radius = pupilR * 0.3f,
                center = Offset(pupil.x + pupilR * 0.3f, pupil.y - pupilR * 0.35f)
            )
            if (eyeStyle == "sleepy") {
                // Heavy sleepy eyelid like Ollie in Build 8
                drawArc(
                    color = bodyColor,
                    startAngle = 180f,
                    sweepAngle = 180f,
                    useCenter = true,
                    topLeft = Offset(centre.x - r * 1.05f, centre.y - r * 1.05f),
                    size = Size(r * 2.1f, r * 1.9f)
                )
                drawLine(
                    color = dark,
                    start = Offset(centre.x - r * 0.95f, centre.y - r * 0.12f),
                    end = Offset(centre.x + r * 0.95f, centre.y - r * 0.12f),
                    strokeWidth = s * 0.022f,
                    cap = StrokeCap.Round
                )
            }
        }

        // Mouth
        val mouth = Offset(s / 2f, s * 0.64f) + lookShift
        val mouthOpen = talking && (((t * 14f).toInt() % 2) == 0)
        if (mouthOpen) {
            drawOval(
                color = dark,
                topLeft = Offset(mouth.x - s * 0.055f, mouth.y - s * 0.045f),
                size = Size(s * 0.11f, s * 0.09f)
            )
        } else {
            val mw = if (mood == Mood.HAPPY) s * 0.2f else s * 0.13f
            val mh = s * 0.11f
            drawArc(
                color = dark,
                startAngle = 22f,
                sweepAngle = 136f,
                useCenter = false,
                topLeft = Offset(mouth.x - mw / 2f, mouth.y - s * 0.035f - mh / 2f),
                size = Size(mw, mh),
                style = Stroke(width = s * 0.03f, cap = StrokeCap.Round)
            )
        }
    }
}
