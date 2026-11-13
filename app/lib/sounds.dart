// Little reward sounds: a ding for a right answer, rising notes for the stars,
// a fanfare when a level is done. Made in code (tools-free) and shipped as assets.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'state.dart';

/// Plays assets/sounds/<name>.wav once, quietly failing on devices that cannot.
Future<void> playSound(String name, {double volume = 0.9}) async {
  if (!appState.voiceOn) return;
  try {
    final p = AudioPlayer();
    await p.play(AssetSource('sounds/$name.wav'), volume: volume);
    unawaited(Future<void>.delayed(const Duration(seconds: 4), () => p.dispose().catchError((_) {})));
  } catch (_) {}
}
