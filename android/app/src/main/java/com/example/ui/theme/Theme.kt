package com.example.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val ScolLightColorScheme = lightColorScheme(
    primary = ScolViolet,
    onPrimary = Color.White,
    primaryContainer = ScolVioletSoft,
    onPrimaryContainer = ScolVioletDeep,
    secondary = ScolMint,
    onSecondary = Color.White,
    tertiary = ScolCoral,
    background = ScolCream,
    onBackground = ScolInk,
    surface = Color.White,
    onSurface = ScolInk,
    surfaceVariant = ScolVioletSoft,
    onSurfaceVariant = ScolMutedText,
    outline = ScolCloud
)

@Composable
fun ScolTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = ScolLightColorScheme,
        typography = Typography,
        content = content
    )
}
