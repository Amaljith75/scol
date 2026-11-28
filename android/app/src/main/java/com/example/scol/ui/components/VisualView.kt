package com.example.scol.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.SubcomposeAsyncImage
import com.example.scol.model.RAW_BASE
import com.example.scol.model.VisualSpec
import com.example.ui.theme.*
import kotlinx.coroutines.delay
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * Tracks screen coordinates (in root window space) of numbered board items
 * so the floating TutorAvatar can glide over the board and touch each item.
 */
@Composable
fun BoardItem(
    index: Int,
    onTargetMeasured: (Int, Offset) -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier.onGloballyPositioned { coords ->
            if (coords.isAttached) {
                val rect = coords.boundsInRoot()
                onTargetMeasured(index, rect.center)
            }
        },
        content = content
    )
}

@Composable
fun PopItem(
    index: Int,
    gapMs: Int = 60,
    content: @Composable () -> Unit
) {
    val scale = remember { Animatable(0f) }
    LaunchedEffect(index) {
        delay((gapMs * index).toLong())
        scale.animateTo(
            targetValue = 1f,
            animationSpec = spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessMediumLow)
        )
    }
    Box(
        modifier = Modifier.graphicsLayer {
            val s = scale.value
            alpha = s.coerceIn(0f, 1f)
            scaleX = s
            scaleY = s
        }
    ) {
        content()
    }
}

@Composable
fun VisualChip(
    text: String,
    color: Color = Color.White,
    borderColor: Color = ScolCloud,
    textColor: Color = ScolInk,
    fontSizeSp: Int = 22
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(color)
            .border(3.dp, borderColor, RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = fontSizeSp.sp,
            fontWeight = FontWeight.Black,
            color = textColor
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun VisualView(
    visual: VisualSpec,
    onTargetMeasured: (Int, Offset) -> Unit,
    modifier: Modifier = Modifier
) {
    val kind = visual.kind
    val args = visual.args
    fun n(i: Int): Int = args.getOrNull(i)?.toIntOrNull() ?: 0

    Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        when (kind) {
            "groups" -> {
                val groups = n(0)
                val each = n(1)
                val emoji = args.getOrNull(2) ?: "●"
                val emojiSp = if (groups * each > 24) 18 else 26
                FlowRowBox {
                    for (g in 0 until groups) {
                        PopItem(g, gapMs = 130) {
                            BoardItem(g + 1, onTargetMeasured) {
                                Box(
                                    modifier = Modifier
                                        .padding(4.dp)
                                        .clip(RoundedCornerShape(18.dp))
                                        .background(Color(0xFFFFF1D6))
                                        .border(3.dp, ScolSun, RoundedCornerShape(18.dp))
                                        .padding(8.dp)
                                ) {
                                    val cols = if (each > 6) 5 else 3
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        var idx = 0
                                        while (idx < each) {
                                            Row {
                                                for (c in 0 until cols) {
                                                    if (idx < each) {
                                                        Text(emoji, fontSize = emojiSp.sp, modifier = Modifier.padding(1.dp))
                                                        idx++
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

            "count" -> {
                val count = n(0)
                val emoji = args.getOrNull(1) ?: "●"
                FlowRowBox {
                    for (i in 0 until count) {
                        PopItem(i) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Text(emoji, fontSize = 28.sp, modifier = Modifier.padding(3.dp))
                            }
                        }
                    }
                }
            }

            "array" -> {
                val rows = n(0)
                val cols = n(1)
                val emoji = args.getOrNull(2) ?: "●"
                val emojiSp = if (cols > 5) 22 else 28
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    for (r in 0 until rows) {
                        PopItem(r, gapMs = 140) {
                            BoardItem(r + 1, onTargetMeasured) {
                                Row {
                                    for (c in 0 until cols) {
                                        Text(emoji, fontSize = emojiSp.sp, modifier = Modifier.padding(2.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            "numberline" -> {
                val from = n(0)
                val to = n(1)
                val mark = if (args.size > 2) n(2) else null
                val span = kotlin.math.abs(to - from)
                val step = if (span <= 10) 1 else ceil(span / 10.0).toInt().coerceAtLeast(1)
                val ticks = mutableListOf<Int>()
                var v = from
                while (v <= to) {
                    ticks.add(v)
                    v += step
                }
                Column(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        ticks.forEachIndexed { i, tick ->
                            PopItem(i) {
                                BoardItem(i + 1, onTargetMeasured) {
                                    Box(
                                        modifier = Modifier
                                            .size(30.dp)
                                            .clip(CircleShape)
                                            .background(if (tick == mark) ScolCoral else Color.Transparent),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = "$tick",
                                            fontSize = 13.sp,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = if (tick == mark) Color.White else ScolInk
                                        )
                                    }
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(ScolViolet)
                    )
                }
            }

            "shapes" -> {
                FlowRowBox {
                    args.forEachIndexed { i, shape ->
                        val w = if (shape == "rectangle") 84.dp else 58.dp
                        val color = ScolVisualPalette[i % ScolVisualPalette.size]
                        PopItem(i, gapMs = 110) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Box(modifier = Modifier.padding(8.dp).size(width = w, height = 58.dp)) {
                                    Canvas(modifier = Modifier.fillMaxSize()) {
                                        val sw = size.width
                                        val sh = size.height
                                        val path = Path().apply {
                                            when (shape) {
                                                "circle" -> addOval(androidx.compose.ui.geometry.Rect(3f, 3f, sw - 3f, sh - 3f))
                                                "triangle" -> {
                                                    moveTo(sw / 2f, 4f)
                                                    lineTo(sw - 4f, sh - 4f)
                                                    lineTo(4f, sh - 4f)
                                                    close()
                                                }
                                                else -> addRoundRect(
                                                    androidx.compose.ui.geometry.RoundRect(
                                                        3f, 3f, sw - 3f, sh - 3f,
                                                        CornerRadius(8f, 8f)
                                                    )
                                                )
                                            }
                                        }
                                        drawPath(path, color = color)
                                        drawPath(
                                            path,
                                            color = darker(color),
                                            style = Stroke(width = 8f, join = StrokeJoin.Round)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            "sticks" -> {
                val count = n(0)
                FlowRowBox {
                    for (i in 0 until count) {
                        PopItem(i) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Box(
                                    modifier = Modifier
                                        .padding(6.dp)
                                        .graphicsLayer { rotationZ = ((i % 3) - 1) * 12f }
                                        .size(width = 8.dp, height = 46.dp)
                                        .clip(RoundedCornerShape(4.dp))
                                        .background(Color(0xFFB07A3B))
                                )
                            }
                        }
                    }
                }
            }

            "place" -> {
                val labels = listOf("100", "10", "1")
                val colors = listOf(ScolCoral, ScolViolet, ScolMint)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(20.dp),
                    verticalAlignment = Alignment.Bottom
                ) {
                    for (p in 0 until 3) {
                        val count = n(p)
                        BoardItem(p + 1, onTargetMeasured) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Box(
                                    modifier = Modifier.size(width = 44.dp, height = 148.dp),
                                    contentAlignment = Alignment.BottomCenter
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .width(6.dp)
                                            .height(148.dp)
                                            .clip(RoundedCornerShape(3.dp))
                                            .background(ScolInk)
                                    )
                                    Column(
                                        verticalArrangement = Arrangement.Bottom,
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        for (b in 0 until count) {
                                            PopItem(p * 3 + (count - b), gapMs = 70) {
                                                Box(
                                                    modifier = Modifier
                                                        .padding(bottom = 2.dp)
                                                        .size(width = 34.dp, height = 14.dp)
                                                        .clip(RoundedCornerShape(7.dp))
                                                        .background(colors[p])
                                                )
                                            }
                                        }
                                    }
                                }
                                Box(modifier = Modifier.size(width = 56.dp, height = 6.dp).background(ScolInk))
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(labels[p], fontWeight = FontWeight.Black, fontSize = 16.sp, color = colors[p])
                            }
                        }
                    }
                }
            }

            "notes" -> {
                FlowRowBox {
                    args.forEachIndexed { i, arg ->
                        val amt = n(i)
                        val bg = when {
                            amt >= 100 -> Color(0xFFD9F2E3)
                            amt >= 10 -> Color(0xFFFFE3D1)
                            else -> Color(0xFFFFF1B8)
                        }
                        val br = when {
                            amt >= 100 -> ScolMint
                            amt >= 10 -> ScolCoral
                            else -> ScolSun
                        }
                        PopItem(i, gapMs = 100) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Box(modifier = Modifier.padding(4.dp)) {
                                    VisualChip(text = "₹$arg", color = bg, borderColor = br, fontSizeSp = 20)
                                }
                            }
                        }
                    }
                }
            }

            "ruler" -> {
                val len = n(0)
                val maxCm = max(10, len + 2)
                val emoji = args.getOrNull(1) ?: ""
                Column(modifier = Modifier.fillMaxWidth()) {
                    if (emoji.isNotEmpty()) {
                        BoardItem(1, onTargetMeasured) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth((len.toFloat() / maxCm).coerceIn(0.15f, 0.9f))
                                    .height(32.dp)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(ScolVisualPalette[len % ScolVisualPalette.size])
                                    .padding(horizontal = 8.dp),
                                horizontalArrangement = Arrangement.End,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(emoji, fontSize = 20.sp)
                            }
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                    }
                    BoardItem(2, onTargetMeasured) {
                        RulerStrip(maxCm = maxCm, modifier = Modifier.fillMaxWidth().height(46.dp))
                    }
                }
            }

            "pattern" -> {
                FlowRowBox {
                    args.forEachIndexed { i, item ->
                        PopItem(i, gapMs = 110) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Box(modifier = Modifier.padding(3.dp)) {
                                    if (item == "?") {
                                        VisualChip("?", color = Color(0xFFFFF1B8), borderColor = ScolSun, textColor = ScolCoral)
                                    } else {
                                        VisualChip(item, fontSizeSp = if (item.length > 3) 18 else 22)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            "split" -> {
                val top = args.getOrElse(0) { "?" }
                val left = args.getOrElse(1) { "?" }
                val right = args.getOrElse(2) { "?" }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    PopItem(0) {
                        BoardItem(1, onTargetMeasured) {
                            VisualChip(
                                text = top,
                                color = if (top == "?") Color(0xFFFFF1B8) else Color.White,
                                borderColor = if (top == "?") ScolSun else ScolViolet,
                                textColor = if (top == "?") ScolCoral else ScolInk,
                                fontSizeSp = 26
                            )
                        }
                    }
                    Canvas(modifier = Modifier.size(150.dp, 34.dp)) {
                        drawLine(ScolViolet, Offset(size.width / 2f, 2f), Offset(size.width * 0.22f, size.height - 2f), 8f, StrokeCap.Round)
                        drawLine(ScolViolet, Offset(size.width / 2f, 2f), Offset(size.width * 0.78f, size.height - 2f), 8f, StrokeCap.Round)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(26.dp)) {
                        PopItem(1, gapMs = 200) {
                            BoardItem(2, onTargetMeasured) {
                                VisualChip(
                                    text = left,
                                    color = if (left == "?") Color(0xFFFFF1B8) else Color.White,
                                    borderColor = if (left == "?") ScolSun else ScolViolet,
                                    textColor = if (left == "?") ScolCoral else ScolInk,
                                    fontSizeSp = 26
                                )
                            }
                        }
                        PopItem(2, gapMs = 200) {
                            BoardItem(3, onTargetMeasured) {
                                VisualChip(
                                    text = right,
                                    color = if (right == "?") Color(0xFFFFF1B8) else Color.White,
                                    borderColor = if (right == "?") ScolSun else ScolViolet,
                                    textColor = if (right == "?") ScolCoral else ScolInk,
                                    fontSizeSp = 26
                                )
                            }
                        }
                    }
                }
            }

            "steps" -> {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    args.forEachIndexed { i, line ->
                        PopItem(i, gapMs = 450) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Text(
                                    text = line,
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.Black,
                                    color = if (i == args.lastIndex && args.size > 1) ScolCoral else ScolViolet,
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.padding(vertical = 3.dp)
                                )
                            }
                        }
                    }
                }
            }

            "text" -> {
                PopItem(0) {
                    BoardItem(1, onTargetMeasured) {
                        Text(
                            text = args.joinToString(" "),
                            fontSize = 46.sp,
                            fontWeight = FontWeight.Black,
                            color = ScolViolet,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }

            "emoji" -> {
                FlowRowBox {
                    args.forEachIndexed { i, em ->
                        PopItem(i, gapMs = 150) {
                            BoardItem(i + 1, onTargetMeasured) {
                                Text(em, fontSize = 56.sp, modifier = Modifier.padding(4.dp))
                            }
                        }
                    }
                }
            }

            "picture" -> {
                val emojiFallback: @Composable () -> Unit = {
                    FlowRowBox {
                        args.forEachIndexed { i, em ->
                            PopItem(i, gapMs = 150) {
                                BoardItem(i + 1, onTargetMeasured) {
                                    Text(em, fontSize = 56.sp, modifier = Modifier.padding(4.dp))
                                }
                            }
                        }
                    }
                }
                if (visual.image.isEmpty()) {
                    emojiFallback()
                } else {
                    BoardItem(1, onTargetMeasured) {
                        SubcomposeAsyncImage(
                            model = "$RAW_BASE${visual.image}",
                            contentDescription = "Lesson picture",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier
                                .heightIn(max = 190.dp)
                                .clip(RoundedCornerShape(18.dp)),
                            loading = { emojiFallback() },
                            error = { emojiFallback() }
                        )
                    }
                }
            }

            "image" -> {
                val file = args.firstOrNull() ?: ""
                BoardItem(1, onTargetMeasured) {
                    SubcomposeAsyncImage(
                        model = "$RAW_BASE$file",
                        contentDescription = "Lesson image",
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .heightIn(max = 190.dp)
                            .clip(RoundedCornerShape(16.dp)),
                        error = { Text("🖼️", fontSize = 64.sp) }
                    )
                }
            }
        }
    }
}

@Composable
fun RulerStrip(maxCm: Int, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val unit = size.width / (maxCm + 1)
        drawRoundRect(
            color = Color(0xFFFFE9A8),
            cornerRadius = CornerRadius(16f, 16f)
        )
        for (i in 0..maxCm) {
            val x = unit * (i + 0.5f)
            drawLine(ScolInk, Offset(x, 0f), Offset(x, size.height * 0.45f), strokeWidth = 4f)
            if (i < maxCm) {
                drawLine(ScolInk, Offset(x + unit / 2f, 0f), Offset(x + unit / 2f, size.height * 0.25f), strokeWidth = 2f)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FlowRowBox(content: @Composable FlowRowScope.() -> Unit) {
    FlowRow(
        horizontalArrangement = Arrangement.Center,
        verticalArrangement = Arrangement.Center,
        content = content
    )
}
