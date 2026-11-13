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
  AudioPlayer? _player;
  Map<String, Set<String>> _index = {};
  String? _dir;
  int _gen = 0;
  Completer<void>? _waiter;
  static const _indexKey = 'voice_index_v1';
  static final _noise = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2190}-\u{21FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]',
      unicode: true);

  @override
  ValueListenable<bool> get speaking => _speaking;

  Future<void> init() async {
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) => _release());
      _player = p;
    } catch (_) {}
    try {
      _tts.awaitSpeakCompletion(true);
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

  void _release() {
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  /// The sound file for a line, downloading it if needed. Null if there is none.
  Future<Source?> _clip(TutorCharacter tutor, String lang, String text) async {
    final voice = tutor.voiceFor(lang);
    if (voice.isEmpty) return null;
    final id = clipId(voice, lang, text);
    if (!(_index[tutor.id]?.contains(id) ?? false)) return null;
    final url = '${rawBase}voice/${tutor.id}/$id.mp3';
    if (kIsWeb || _dir == null) return UrlSource(url);
    try {
      final file = File('$_dir/voice_${tutor.id}_$id.mp3');
      if (!await file.exists()) {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return null;
        await file.writeAsBytes(res.bodyBytes, flush: true);
      }
      return DeviceFileSource(file.path);
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

  @override
  Future<void> say(List<String> parts, String lang, TutorCharacter tutor) async {
    final token = ++_gen;
    _haltSound();
    _speaking.value = true;
    for (final part in parts) {
      if (token != _gen) return;
      if (part.replaceAll(_noise, '').trim().isEmpty) continue;
      lang = langOf(part); // English lessons read in English even when the app is in Malayalam
      final clip = await _clip(tutor, lang, part);
      if (token != _gen) return;
      var played = false;
      final player = _player;
      if (clip != null && player != null) {
        try {
          final waiter = Completer<void>();
          _waiter = waiter;
          await player.play(clip);
          await waiter.future.timeout(const Duration(seconds: 45), onTimeout: () {});
          played = true;
        } catch (_) {}
      }
      if (!played && token == _gen) {
        try {
          await _tts.setLanguage(lang == 'ml' ? 'ml-IN' : 'en-IN');
          await _tts.setSpeechRate(0.42);
          await _tts.setPitch(1.0 + 0.12 * tutor.energy.clamp(0.5, 1.8));
          await _tts.speak(part
              .replaceAll(_noise, ' ')
              .replaceAll('×', lang == 'ml' ? ' ഗുണം ' : ' times ')
              .replaceAll('=', lang == 'ml' ? ' സമം ' : ' equals '));
        } catch (_) {
          // No voice at all on this device: the lesson still works with text.
        }
      }
    }
    if (token == _gen) _speaking.value = false;
  }

  void _haltSound() {
    _release();
    try {
      _player?.stop().catchError((_) {});
    } catch (_) {}
    try {
      _tts.stop().catchError((_) {});
    } catch (_) {}
  }

  @override
  void stop() {
    _gen++;
    _haltSound();
    _speaking.value = false;
  }
}
