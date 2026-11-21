package com.example.scol.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// ---------------- 1. Interactive Abacus (Hundreds, Tens, Ones) ----------------
@Composable
fun AbacusPad(
    values: List<Int>,
    onChanged: (List<Int>) -> Unit,
    modifier: Modifier = Modifier
) {
    val labels = listOf("100", "10", "1")
    val colors = listOf(ScolCoral, ScolViolet, ScolMint)
    val rodHeight = 164.dp
    val slot = 16.dp

    SoftCard(
        modifier = modifier,
        padding = PaddingValues(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            for (r in 0 until 3) {
                var boxHeightPx by remember { mutableFloatStateOf(400f) }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .size(width = 72.dp, height = rodHeight)
                            .onSizeChanged { boxHeightPx = it.height.toFloat() }
                            .pointerInput(r, values) {
                                detectTapGestures { offset ->
                                    val fromBottom = (boxHeightPx - offset.y).coerceAtLeast(0f)
                                    val slotPx = boxHeightPx / 10f
                                    val count = (fromBottom / slotPx).toInt().coerceIn(0, 9)
                                    val next = values.toMutableList()
                                    next[r] = if (count == next[r]) (count - 1).coerceAtLeast(0) else count
                                    onChanged(next)
                                }
                            }
                            .pointerInput(r, values) {
                                detectDragGestures { change, _ ->
                                    change.consume()
                                    val fromBottom = (boxHeightPx - change.position.y).coerceAtLeast(0f)
                                    val slotPx = boxHeightPx / 10f
                                    val count = (fromBottom / slotPx).toInt().coerceIn(0, 9)
                                    if (count != values[r]) {
                                        val next = values.toMutableList()
                                        next[r] = count
                                        onChanged(next)
                                    }
                                }
                            },
                        contentAlignment = Alignment.BottomCenter
                    ) {
                        Box(
                            modifier = Modifier
                                .width(7.dp)
                                .height(rodHeight)
                                .clip(RoundedCornerShape(4.dp))
                                .background(ScolInk)
                        )
                        Column(
                            verticalArrangement = Arrangement.Bottom,
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            for (b in 0 until values[r]) {
                                Box(
                                    modifier = Modifier
                                        .padding(bottom = 3.dp)
                                        .size(width = 54.dp, height = slot - 3.dp)
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(colors[r])
                                        .border(2.dp, darker(colors[r]), RoundedCornerShape(10.dp))
                                )
                            }
                        }
                    }
                    Box(
                        modifier = Modifier
                            .size(width = 84.dp, height = 7.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(ScolInk)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(labels[r], fontWeight = FontWeight.Black, fontSize = 17.sp, color = colors[r])
                }
            }
        }
    }
}

// ---------------- 2. Sliding Scale Ruler Board ----------------
@Composable
fun ScaleBoard(
    length: Int,
    emoji: String = "",
    modifier: Modifier = Modifier
) {
    var shiftCm by remember(length, emoji) { mutableFloatStateOf(0f) }
    var widthPx by remember { mutableFloatStateOf(800f) }
    val maxCm = 14
    val startAt = 2f

    SoftCard(
        modifier = modifier.fillMaxWidth(),
        padding = PaddingValues(vertical = 14.dp, horizontal = 8.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(118.dp)
                .onSizeChanged { widthPx = it.width.toFloat() }
        ) {
            val unitPx = widthPx / 13f
            val density = androidx.compose.ui.platform.LocalDensity.current
            val unitDp = with(density) { unitPx.toDp() }

            // Object lying 2.5 units from left
            Box(
                modifier = Modifier
                    .offset(x = unitDp * (startAt + 0.5f), y = 6.dp)
                    .size(width = unitDp * length, height = 34.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(ScolCoral)
                    .padding(end = 6.dp),
                contentAlignment = Alignment.CenterEnd
            ) {
                Text(emoji, fontSize = 22.sp)
            }

            // Draggable ruler strip below
            Column(
                modifier = Modifier
                    .offset(x = unitDp * shiftCm, y = 46.dp)
                    .pointerInput(unitPx) {
                        detectDragGestures(
                            onDragEnd = { shiftCm = kotlin.math.round(shiftCm) }
                        ) { change, dragAmount ->
                            change.consume()
                            shiftCm = (shiftCm + dragAmount.x / unitPx).coerceIn(-1f, 6f)
                        }
                    },
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                RulerStrip(
                    maxCm = maxCm,
                    modifier = Modifier.size(width = unitDp * (maxCm + 1), height = 46.dp)
                )
                Text("↔", fontSize = 18.sp, fontWeight = FontWeight.Black, color = ScolViolet)
            }
        }
    }
}

// ---------------- 3. Interactive Stick Shape Builder ----------------
private val SHAPE_SIDES = mapOf("triangle" to 3, "rectangle" to 4, "square" to 4)

@Composable
fun StickBuilder(
    options: List<String>,
    disabled: Set<String>,
    onBuilt: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val placed = remember(options) { mutableStateMapOf<String, Int>() }
    val scope = rememberCoroutineScope()
    var pendingDone by remember { mutableStateOf(false) }

    fun addStick(shape: String) {
        if (disabled.contains(shape) || pendingDone) return
        val need = SHAPE_SIDES[shape] ?: 4
        val now = (placed[shape] ?: 0) + 1
        if (now > need) return
        placed[shape] = now
        if (now == need) {
            pendingDone = true
            scope.launch {
                delay(450)
                pendingDone = false
                onBuilt(shape)
                placed[shape] = 0
            }
        }
    }

    val used = placed.values.sum()

    SoftCard(
        modifier = modifier.fillMaxWidth(),
        padding = PaddingValues(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            options.forEach { shape ->
                val isDisabled = disabled.contains(shape)
                val count = placed[shape] ?: 0
                val widthDp = if (shape == "rectangle") 128.dp else 96.dp
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .clickable(enabled = !isDisabled) { addStick(shape) }
                        .padding(6.dp)
                ) {
                    Canvas(modifier = Modifier.size(width = widthDp, height = 96.dp)) {
                        val w = size.width
                        val h = size.height
                        val m = 20f
                        val pts = if (shape == "triangle") {
                            listOf(Offset(w / 2f, m), Offset(w - m, h - m), Offset(m, h - m))
                        } else {
                            listOf(Offset(m, m), Offset(w - m, m), Offset(w - m, h - m), Offset(m, h - m))
                        }
                        val dash = PathEffect.dashPathEffect(floatArrayOf(16f, 14f), 0f)
                        for (i in pts.indices) {
                            val a = pts[i]
                            val b = pts[(i + 1) % pts.size]
                            if (i < count) {
                                drawLine(
                                    color = Color(0xFFB07A3B),
                                    start = a,
                                    end = b,
                                    strokeWidth = 18f,
                                    cap = StrokeCap.Round
                                )
                            } else {
                                drawLine(
                                    color = if (isDisabled) ScolCloud else Color(0xFFB9AEE0),
                                    start = a,
                                    end = b,
                                    strokeWidth = 8f,
                                    cap = StrokeCap.Round,
                                    pathEffect = dash
                                )
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Sticks tray
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color(0xFFFFF1D6))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val remaining = (6 - used).coerceIn(0, 6)
                for (i in 0 until 6) {
                    if (i < remaining) {
                        Box(
                            modifier = Modifier
                                .graphicsLayer { rotationZ = ((i % 3) - 1) * 10f }
                                .size(width = 10.dp, height = 52.dp)
                                .clip(RoundedCornerShape(5.dp))
                                .background(Color(0xFFB07A3B))
                                .clickable {
                                    // Tap a stick to place onto the first non-disabled shape
                                    val target = options.firstOrNull { !disabled.contains(it) } ?: return@clickable
                                    addStick(target)
                                }
                        )
                    } else {
                        Spacer(modifier = Modifier.size(width = 10.dp, height = 52.dp))
                    }
                }
            }
        }
    }
}
