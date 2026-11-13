// How the tutors speak. Every line is a Microsoft Edge voice, never the phone's
// own voice. Lines a tutor with a ready-made voice says have a sound file (see
// tools/build_voice.py); the app downloads each file once and keeps it, so
// lessons also work offline. Other tutors, other moods, the brain's teaching
// and answers, and the parent report are made on the phone in the tutor's Edge
// voice (long text is made sentence by sentence, so it starts quickly) and kept.
// Without internet a new line is shown as text only.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'edge_voice.dart';

/// 'ml' if the text has Malayalam letters, otherwise 'en'.
String langOf(String text) => RegExp(r'[ഀ-ൿ]').hasMatch(text) ? 'ml' : 'en';

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

/// What happened with the voice most recently, for the Parents area: '' when all is well,
/// otherwise a short note such as "Edge voice: no internet". Helps find out why a line was silent.
final ValueNotifier<String> voiceStatus = ValueNotifier('');

/// The tutor's mood chosen by the parent: happy | normal | calm | strict.
String Function() voiceTone = () => 'normal';

/// How each mood changes the voice: [speed change in %, pitch change in Hz].
const toneShift = {
  'happy': [8, 10],
  'normal': [0, 0],
  'calm': [-12, -4],
  'strict': [-2, -14],
};

/// Adds a mood's change to a tutor's own setting, e.g. ('-6%', 8) -> '+2%'.
String shiftProsody(String base, int by, String unit) {
  final n = (int.tryParse(base.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0) + by;
  return '${n >= 0 ? '+' : ''}$n$unit';
}

/// Cuts a long line into sentences of at most [max] letters, so each piece is made quickly
/// and the first one can play while the next is still being made.
List<String> sentencePieces(String text, {int max = 220}) {
  final parts = text.split(RegExp(r'(?<=[.!?।])\s+|(?<=[.!?])(?=[A-Zഀ-ൿ])'));
  final out = <String>[];
  var cur = '';
  for (final raw in parts) {
    final p = raw.trim();
    if (p.isEmpty) continue;
    if (cur.isEmpty) {
      cur = p;
    } else if ((cur.length + p.length + 1) <= max) {
      cur = '$cur $p';
    } else {
      out.add(cur);
      cur = p;
    }
  }
  if (cur.isNotEmpty) out.add(cur);
  // A single sentence longer than max is cut at commas.
  final fine = <String>[];
  for (final o in out) {
    if (o.length <= max * 1.6) {
      fine.add(o);
      continue;
    }
    var piece = '';
    for (final c in o.split(RegExp(r'(?<=,)\s+'))) {
      if (piece.isNotEmpty && piece.length + c.length > max) {
        fine.add(piece);
        piece = c;
      } else {
        piece = piece.isEmpty ? c : '$piece $c';
      }
    }
    if (piece.isNotEmpty) fine.add(piece);
  }
  return fine;
}

class VoiceSpeaker implements Speaker {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  AudioPlayer? _player; // a fresh player for every line, so an old line can never block a new one
  Map<String, Set<String>> _index = {};
  DateTime _indexAt = DateTime.fromMillisecondsSinceEpoch(0); // when the list of ready-made files was last fetched
  final Set<String> _missing = {}; // ready-made files looked for and not found, so we ask only once
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
      _indexAt = DateTime.now();
      _missing.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_indexKey, res.body);
    } catch (_) {}
  }

  /// Saves bytes so a half-written file is never played.
  Future<File> _save(String name, List<int> bytes) async {
    final file = File('$_dir/$name');
    final tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.part'); // two downloads of one line never clash
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp.rename(file.path);
  }

  /// The ready-made sound file for a line, downloading it if needed. Null if there is none.
  /// Ready-made files are in the normal mood, so other moods skip them unless [anyMood] says
  /// a normal-mood file is better than silence.
  Future<Source?> _clip(TutorCharacter tutor, String lang, String text, {bool anyMood = false}) async {
    final voice = tutor.voiceFor(lang);
    if (voice.isEmpty || (!anyMood && voiceTone() != 'normal')) return null;
    final id = clipId(voice, lang, text);
    final listed = _index[tutor.id]?.contains(id) ?? false;
    // A tutor with ready-made lines may have new ones our list does not know yet: look once anyway.
    if (!listed && (!tutor.readyMade || _missing.contains(id))) return null;
    final url = '${rawBase}voice/${tutor.id}/$id.mp3';
    try {
      if (kIsWeb || _dir == null) return listed ? UrlSource(url) : null;
      final file = File('$_dir/voice_${tutor.id}_$id.mp3');
      if (await file.exists()) return DeviceFileSource(file.path);
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) _missing.add(id);
      if (res.statusCode != 200) return null;
      return DeviceFileSource((await _save('voice_${tutor.id}_$id.mp3', res.bodyBytes)).path);
    } catch (_) {
      return null;
    }
  }

  /// No ready-made file: make the line now in the tutor's Edge voice (needs internet).
  /// Tries three times, because one slow or refused connection should not silence the tutor.
  Future<Source?> _live(TutorCharacter tutor, String lang, String text, {int tries = 3}) async {
    final voice = tutor.voiceFor(lang);
    if (voice.isEmpty || !voice.endsWith('Neural') || kIsWeb || _dir == null) return null;
    final shift = toneShift[voiceTone()] ?? const [0, 0];
    final rate = shiftProsody(tutor.rate, shift[0], '%');
    final pitch = shiftProsody(tutor.pitch, shift[1], 'Hz');
    final name = 'live_${clipId('$voice|$rate|$pitch', lang, text)}.mp3';
    final file = File('$_dir/$name');
    if (await file.exists()) return DeviceFileSource(file.path);
    for (var attempt = 0; attempt < tries; attempt++) {
      try {
        final bytes = await edgeSpeak(spokenText(text, lang), voice, rate: rate, pitch: pitch)
            .timeout(const Duration(seconds: 20));
        voiceStatus.value = '';
        return DeviceFileSource((await _save(name, bytes)).path);
      } catch (e) {
        voiceStatus.value = 'Edge voice: ${describeVoiceError(e)}';
        if (attempt + 1 < tries) await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
    return null;
  }

  /// The best sound for a line: the ready-made file, else made now in the tutor's Edge voice, else
  /// (in a mood other than normal) the ready-made normal-mood file. Null means the line stays silent.
  Future<Source?> _source(TutorCharacter tutor, String lang, String text, {int tries = 3}) async {
    final s = await _clip(tutor, lang, text) ?? await _live(tutor, lang, text, tries: tries);
    if (s != null || voiceTone() == 'normal') return s;
    return _clip(tutor, lang, text, anyMood: true);
  }

  /// The pieces a line is spoken in: a ready-made file plays whole; anything made live is
  /// made sentence by sentence.
  List<String> _pieces(TutorCharacter tutor, String lang, String text) {
    final voice = tutor.voiceFor(lang);
    final listed = voice.isNotEmpty && (_index[tutor.id]?.contains(clipId(voice, lang, text)) ?? false);
    if (listed || tutor.readyMade && text.length <= 220) return [text];
    return sentencePieces(text);
  }

  @override
  void prefetch(Iterable<String> texts, String lang, TutorCharacter tutor) {
    if (kIsWeb) return;
    final lines = texts.toSet();
    () async {
      // New lessons bring new ready-made files: make sure our list of them is fresh.
      if (DateTime.now().difference(_indexAt) > const Duration(minutes: 10)) await _refreshIndex();
      // Get every line of the lesson ready while the child listens to the first ones.
      for (final t in lines) {
        if (t.replaceAll(_noise, '').trim().isEmpty) continue;
        for (final piece in _pieces(tutor, langOf(t), t)) {
          await _source(tutor, langOf(piece), piece, tries: 1);
        }
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
    } catch (e) {
      voiceStatus.value = 'Playing a sound failed: ${describeVoiceError(e)}';
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
    // Every piece of every part, in order. The next piece is made while the current one plays.
    final pieces = <String>[
      for (final part in parts)
        if (part.replaceAll(_noise, '').trim().isNotEmpty) ..._pieces(tutor, langOf(part), part),
    ];
    Future<Source?> fetch(int i) => i < pieces.length ? _source(tutor, langOf(pieces[i]), pieces[i]) : Future.value(null);
    var next = fetch(0);
    for (var i = 0; i < pieces.length; i++) {
      if (token != _gen) return;
      final source = await next;
      next = fetch(i + 1);
      if (token != _gen) return;
      if (source != null) await _play(source);
      // No sound could be made (no internet): the words stay on screen; the phone's own voice is never used.
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
