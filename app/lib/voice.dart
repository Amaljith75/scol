// How the tutors speak. Lines a tutor with a ready-made voice says have a
// sound file (see tools/build_voice.py). The app downloads each file once and
// keeps it, so lessons also work offline. Anything without a file (other
// tutors, live answers, lines not made yet) is read by the phone's own voice.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'edge_voice.dart';

/// 'ml' if the text has Malayalam letters, otherwise 'en'.
String langOf(String text) => RegExp(r'[\u0D00-\u0D7F]').hasMatch(text) ? 'ml' : 'en';

/// Must match clip_id() in tools/build_voice.py.
String clipId(String voice, String lang, String text) =>
    sha1.convert(utf8.encode('$voice|$lang|$text')).toString().substring(0, 20);

abstract class Speaker {
  ValueListenable<bool> get speaking;
  Future<void> say(List<String> parts, String lang, TutorCharacter tutor);
  void prefetch(Iterable<String> texts, String lang, TutorCharacter tutor);
  void stop();
}

/// The voice, set up once when the app starts.
Speaker? appSpeaker;

class VoiceSpeaker implements Speaker {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  final FlutterTts _tts = FlutterTts();
  AudioPlayer? _player; // a fresh player for every line, so an old line can never block a new one
  Map<String, Set<String>> _index = {};
  String? _dir;
  int _gen = 0;
  static const _indexKey = 'voice_index_v1';
  static final _noise = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2190}-\u{21FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]',
      unicode: true);

  @override
  ValueListenable<bool> get speaking => _speaking;

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_indexKey);
      if (cached != null) _index = _parseIndex(cached);
      if (!kIsWeb) _dir = (await getApplicationSupportDirectory()).path;
    } catch (_) {}
    unawaited(_refreshIndex());
  }

  Map<String, Set<String>> _parseIndex(String body) {
    final j = (jsonDecode(body) as Map).cast<String, dynamic>();
    return j.map((k, v) => MapEntry(k, (v as List).map((e) => '$e').toSet()));
  }

  Future<void> _refreshIndex() async {
    try {
      final res = await http.get(Uri.parse('${rawBase}voice/index.json')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      _index = _parseIndex(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_indexKey, res.body);
    } catch (_) {}
  }

  /// Saves bytes so a half-written file is never played.
  Future<File> _save(String name, List<int> bytes) async {
    final file = File('$_dir/$name');
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp.rename(file.path);
  }

  /// The ready-made sound file for a line, downloading it if needed. Null if there is none.
  Future<Source?> _clip(TutorCharacter tutor, String lang, String text) async {
    final voice = tutor.voiceFor(lang);
    if (voice.isEmpty) return null;
    final id = clipId(voice, lang, text);
    if (!(_index[tutor.id]?.contains(id) ?? false)) return null;
    final url = '${rawBase}voice/${tutor.id}/$id.mp3';
    if (kIsWeb || _dir == null) return UrlSource(url);
    try {
      final file = File('$_dir/voice_${tutor.id}_$id.mp3');
      if (await file.exists()) return DeviceFileSource(file.path);
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return DeviceFileSource((await _save('voice_${tutor.id}_$id.mp3', res.bodyBytes)).path);
    } catch (_) {
      return null;
    }
  }

  /// No ready-made file: make the line now in the tutor's Edge voice (needs internet).
  Future<Source?> _live(TutorCharacter tutor, String lang, String text) async {
    final voice = tutor.voiceFor(lang);
    if (voice.isEmpty || !voice.endsWith('Neural') || kIsWeb || _dir == null) return null;
    final name = 'live_${clipId(voice, lang, text)}.mp3';
    try {
      final file = File('$_dir/$name');
      if (await file.exists()) return DeviceFileSource(file.path);
      final bytes = await edgeSpeak(spokenText(text, lang), voice, rate: tutor.rate, pitch: tutor.pitch)
          .timeout(const Duration(seconds: 15));
      return DeviceFileSource((await _save(name, bytes)).path);
    } catch (_) {
      return null;
    }
  }

  @override
  void prefetch(Iterable<String> texts, String lang, TutorCharacter tutor) {
    if (kIsWeb) return;
    () async {
      for (final t in texts) {
        if (t.isNotEmpty) await _clip(tutor, langOf(t), t);
      }
    }();
  }

  /// Plays one sound to the end (or until a newer line starts).
  Future<bool> _play(Source source) async {
    final player = AudioPlayer();
    _player = player;
    final done = Completer<void>();
    final subs = [
      player.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      }),
    ];
    try {
      await player.play(source);
      // Never wait longer than the sound itself (plus a little), even if no "finished" signal comes.
      final length = await player.getDuration() ?? const Duration(seconds: 20);
      await done.future.timeout(length + const Duration(seconds: 2), onTimeout: () {});
      return true;
    } catch (_) {
      return false;
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
      if (identical(_player, player)) _player = null;
      unawaited(player.dispose().catchError((_) {}));
    }
  }

  @override
  Future<void> say(List<String> parts, String lang, TutorCharacter tutor) async {
    final token = ++_gen;
    await _halt();
    if (token != _gen) return;
    _speaking.value = true;
    for (final part in parts) {
      if (token != _gen) return;
      if (part.replaceAll(_noise, '').trim().isEmpty) continue;
      lang = langOf(part); // English lessons read in English even when the app is in Malayalam
      final source = await _clip(tutor, lang, part) ?? await _live(tutor, lang, part);
      if (token != _gen) return;
      final played = source != null && await _play(source);
      if (!played && token == _gen) {
        try {
          await _tts.setLanguage(lang == 'ml' ? 'ml-IN' : 'en-IN');
          await _tts.setSpeechRate(0.42);
          await _tts.setPitch(1.0 + 0.12 * tutor.energy.clamp(0.5, 1.8));
          await _tts.speak(spokenText(part, lang));
        } catch (_) {
          // No voice at all on this device: the lesson still works with text.
        }
      }
    }
    if (token == _gen) _speaking.value = false;
  }

  Future<void> _halt() async {
    final p = _player;
    _player = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void stop() {
    _gen++;
    unawaited(_halt());
    _speaking.value = false;
  }
}

/// Reads symbols the way a teacher would say them. Must match spoken() in tools/build_voice.py
/// in spirit (the files are made there; this is for lines spoken live).
String spokenText(String text, String lang) {
  final ml = lang == 'ml';
  var out = text.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), ' ');
  out = out
      .replaceAll('×', ml ? ' ഗുണം ' : ' times ')
      .replaceAll('=', ml ? ' സമം ' : ' equals ')
      .replaceAll('+', ml ? ' പ്ലസ് ' : ' plus ')
      .replaceAll('−', ml ? ' മൈനസ് ' : ' minus ');
  if (ml) {
    out = out.replaceAll('സെ.മീ', 'സെന്റിമീറ്റർ').replaceAll('കി.മീ', 'കിലോമീറ്റർ');
  } else {
    out = out.replaceAll(RegExp(r'\bcm\b'), 'centimetres').replaceAll(RegExp(r'\bkm\b'), 'kilometres');
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}
