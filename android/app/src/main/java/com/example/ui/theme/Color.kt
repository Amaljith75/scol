package com.example.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.core.graphics.ColorUtils

// Build 8 Brand Colors (from app/lib/widgets/ui.dart)
val ScolViolet = Color(0xFF7B5CFA)
val ScolVioletDeep = Color(0xFF5B3FD6)
val ScolVioletSoft = Color(0xFFEDE7FF)
val ScolCream = Color(0xFFF8F5FF)
val ScolInk = Color(0xFF2A2350)
val ScolCoral = Color(0xFFFF6B5E)
val ScolMint = Color(0xFF2BB673)
val ScolSun = Color(0xFFFFC233)
val ScolCloud = Color(0xFFE7E1F5)
val ScolMutedText = Color(0xFF6B6F80)
val ScolDisabledText = Color(0xFF9A948A)
val ScolNavInactive = Color(0xFF8A84A6)

val ScolChapterColors = listOf(
    Color(0xFFFF8A3D), // orange
    Color(0xFF2FA8F5), // sky
    Color(0xFF2BB673), // green
    Color(0xFFE5488B), // pink
    Color(0xFF19B5A5), // teal
    Color(0xFFF2A413)  // amber
)

val ScolVisualPalette = listOf(
    ScolCoral,
    ScolViolet,
    ScolMint,
    ScolSun,
    Color(0xFFE5488B)
)

fun darker(color: Color, amount: Float = 0.18f): Color {
    val hsl = FloatArray(3)
    val argb = android.graphics.Color.argb(
        (color.alpha * 255).toInt(),
        (color.red * 255).toInt(),
        (color.green * 255).toInt(),
        (color.blue * 255).toInt()
    )
    ColorUtils.colorToHSL(argb, hsl)
    hsl[2] = (hsl[2] - amount).coerceIn(0f, 1f)
    return Color(ColorUtils.HSLToColor(hsl))
}
