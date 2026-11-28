package com.example.scol.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.*
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

@Composable
fun Chunky(
    onClick: (() -> Unit)?,
    modifier: Modifier = Modifier,
    color: Color = ScolViolet,
    radius: Dp = 20.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
    content: @Composable BoxScope.() -> Unit
) {
    val enabled = onClick != null
    val faceColor = if (enabled) color else ScolCloud
    val lipColor = darker(faceColor)
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val lift = if (pressed || !enabled) 0.dp else 5.dp

    Box(
        modifier = modifier
            .padding(top = 5.dp - lift)
            .clip(RoundedCornerShape(radius))
            .background(lipColor)
            .padding(bottom = lift)
            .let { base ->
                if (enabled) {
                    base.clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = onClick!!
                    )
                } else base
            }
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 52.dp)
                .clip(RoundedCornerShape(radius))
                .background(faceColor)
                .padding(contentPadding),
            contentAlignment = Alignment.Center
        ) {
            val textColor = if (enabled) Color.White else ScolDisabledText
            CompositionLocalProvider(
                LocalContentColor provides textColor,
                LocalTextStyle provides TextStyle(
                    color = textColor,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign = TextAlign.Center
                )
            ) {
                content()
            }
        }
    }
}

@Composable
fun SoftCard(
    modifier: Modifier = Modifier,
    color: Color = Color.White,
    padding: PaddingValues = PaddingValues(16.dp),
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(24.dp))
            .background(color)
            .border(2.dp, ScolCloud, RoundedCornerShape(24.dp))
            .padding(padding),
        content = content
    )
}

@Composable
fun Pill(
    emoji: String,
    text: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(30.dp))
            .background(Color.White)
            .border(2.dp, ScolCloud, RoundedCornerShape(30.dp))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "$emoji $text",
            fontWeight = FontWeight.ExtraBold,
            fontSize = 16.sp,
            color = ScolInk
        )
    }
}

object StarAnimationTracker {
    var shownStars: Int = -1
}

@Composable
fun StarPill(
    stars: Int,
    modifier: Modifier = Modifier,
    onPopSound: () -> Unit = {}
) {
    val from = remember(stars) {
        if (StarAnimationTracker.shownStars < 0) stars else StarAnimationTracker.shownStars
    }
    val anim = remember { Animatable(if (stars > from) 0f else 1f) }

    LaunchedEffect(stars) {
        if (stars > from) {
            kotlinx.coroutines.delay(150)
            onPopSound()
            anim.snapTo(0f)
            anim.animateTo(1f, animationSpec = tween(900, easing = FastOutSlowInEasing))
        } else {
            anim.snapTo(1f)
        }
        StarAnimationTracker.shownStars = stars
    }

    val v = anim.value
    val displayStars = (from + (stars - from) * v).roundToInt()
    val bounce = if (stars > from) 1f + 0.35f * sin(v * PI.toFloat()) else 1f

    Pill(
        emoji = "⭐",
        text = "$displayStars",
        modifier = modifier.graphicsLayer {
            scaleX = bounce
            scaleY = bounce
        }
    )
}
