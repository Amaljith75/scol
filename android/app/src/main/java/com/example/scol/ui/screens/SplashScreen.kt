package com.example.scol.ui.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import com.example.scol.ui.components.buildCreaturePath
import com.example.ui.theme.ScolCream
import com.example.ui.theme.ScolViolet
import com.example.ui.theme.ScolVioletDeep
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

private fun seg(t: Float, a: Float, b: Float): Float = ((t - a) / (b - a)).coerceIn(0f, 1f)

private fun elasticOut(x: Float): Float {
    if (x == 0f || x == 1f) return x
    val c4 = (2.0 * PI) / 3.0
    return (2.0.pow(-10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0).toFloat()
}

@Composable
fun SplashScreen(
    onDone: () -> Unit
) {
    val tAnim = remember { Animatable(0f) }
    val textMeasurer = rememberTextMeasurer()

    LaunchedEffect(Unit) {
        tAnim.animateTo(1f, animationSpec = tween(durationMillis = 2000, easing = LinearEasing))
        onDone()
    }

    val t = tAnim.value

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ScolCream)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDone
            )
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height

            // 1. Liquid colour rising
            val rise = FastOutSlowInEasing.transform(seg(t, 0f, 0.5f))
            val level = h * (1.08f - rise * 1.2f)
            val amp = h * 0.035f * (1f - rise * 0.7f)
            val wave = Path().apply {
                moveTo(0f, h)
                var x = 0f
                while (x <= w + 16f) {
                    val y = level +
                        amp * sin(x / w * 2f * PI.toFloat() * 1.4f + t * 9f) +
                        amp * 0.5f * sin(x / w * 2f * PI.toFloat() * 2.6f - t * 13f)
                    lineTo(x, y)
                    x += 12f
                }
                lineTo(w, h)
                close()
            }
            drawPath(
                path = wave,
                brush = Brush.verticalGradient(colors = listOf(ScolViolet, ScolVioletDeep))
            )

            // 2. Creature bobs up out of the liquid
            val up = elasticOut(seg(t, 0.32f, 0.8f))
            val r = min(w, h) * 0.2f
            val c = Offset(w / 2f, h * 0.46f + (1f - up) * (h * 0.6f))
            if (t > 0.3f) {
                val body = buildCreaturePath("blob", c, r, (t * 2.2f).toDouble())
                drawPath(body, color = Color(0xFFF6F1FF))

                val lookX = if (t < 0.62f) -1f else if (t < 0.78f) 1f else 0f
                val lookY = if (t < 0.78f) -0.2f else 0f
                val blink = t in 0.83f..0.87f
                val dark = Color(0xFF23243A)
                for (side in listOf(-1f, 1f)) {
                    val e = Offset(c.dxOrX() + side * r * 0.34f, c.y)
                    if (blink) {
                        drawLine(
                            color = dark,
                            start = Offset(e.x - r * 0.16f, e.y),
                            end = Offset(e.x + r * 0.16f, e.y),
                            strokeWidth = r * 0.07f,
                            cap = StrokeCap.Round
                        )
                        continue
                    }
                    val p = e + Offset(lookX, lookY) * (r * 0.07f)
                    drawCircle(color = dark, radius = r * 0.2f, center = p)
                    drawCircle(
                        color = Color.White,
                        radius = r * 0.06f,
                        center = Offset(p.x + r * 0.06f, p.y - r * 0.07f)
                    )
                }
            }

            // 3. Name fade-in
            val fade = seg(t, 0.7f, 0.9f)
            if (fade > 0f) {
                val style = TextStyle(
                    color = Color.White.copy(alpha = fade),
                    fontSize = (r * 0.26f).sp,
                    fontWeight = FontWeight.Black,
                    letterSpacing = 1.5.sp
                )
                val layoutResult = textMeasurer.measure("scol", style = style)
                drawText(
                    textLayoutResult = layoutResult,
                    topLeft = Offset(
                        (w - layoutResult.size.width) / 2f,
                        h * 0.46f + r * 1.25f + (1f - fade) * 16f
                    )
                )
            }
        }
    }
}

private fun Offset.dxOrX(): Float = x
