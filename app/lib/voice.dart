// How the tutors speak. Every character has its own Gemini voice, made on the
// Scol server (the Gemini key never leaves the server) and kept there, so each
// line is made once for every child; the phone keeps its copy too, so a lesson
// heard once works offline. If the Gemini voice cannot be had, the character's
// Microsoft Edge voice speaks instead. The phone's own voice is never used:
// without internet a new line is shown as text only.
// While a line plays, [Speaker.mouth] follows the loudness of the sound itself
// (so the mouth moves with the words) and [Speaker.progress] says how far
// through the line the voice is (so the tutor touches the board on the word).
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'brain.dart' show deviceId;
import 'content.dart';
import 'edge_voice.dart';
import 'pcm_out.dart';

/// 'ml' if the text has Malayalam letters, otherwise 'en'.
String langOf(String text) => RegExp(r'[ഀ-ൿ]').hasMatch(text) ? 'ml' : 'en';

/// Must match clip_id() in tools/build_voice.py.
String clipId(String voice, String lang, String text) =>
    sha1.convert(utf8.encode('$voice|$lang|$text')).toString().substring(0, 20);

abstract class Speaker {
  ValueListenable<bool> get speaking;

  /// How open the mouth should be right now, 0 to 1, from the sound being played.
  ValueListenable<double> get mouth;

  /// How far through the current [say] the voice is, 0 to 1 (by letters of what is said).
  ValueListenable<double> get progress;
  /// Says [parts] one after another. [natural]: a greeting or chat, spoken by the Gemini Live voice
  /// (the most natural one) when the server can.
  Future<void> say(List<String> parts, String lang, TutorCharacter tutor, {bool natural = false});
  void prefetch(Iterable<String> texts, String lang, TutorCharacter tutor);
  void stop();
}

/// The voice, set up once when the app starts.
Speaker? appSpeaker;

/// Where the Scol server is ({'url': .., 'public_key': ..}); set when the app starts.
Map<String, dynamic> Function() voiceServer = () => const {};

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

/// How a mood changes the way the Gemini voice is asked to speak.
const toneStyle = {
  'happy': 'sounding extra cheerful and excited',
  'calm': 'speaking slowly, calmly and gently',
  'strict': 'speaking firmly and clearly, like a strict but kind teacher',
};

/// Loudness of a WAV file every 40 ms, 0 to 1, for the mouth. Null for anything that is not 16-bit mono WAV.
List<double>? wavEnvelope(Uint8List bytes, {int windowMs = 40}) {
  final w = wavPcm(bytes);
  return w == null ? null : pcmEnvelope(w.pcm, w.rate, windowMs: windowMs);
}

/// Loudness of 16-bit mono sound every [windowMs], 0 to 1.
List<double> pcmEnvelope(Uint8List pcm, int rate, {int windowMs = 40}) {
  final data = ByteData.sublistView(pcm);
  final per = max(1, rate * windowMs ~/ 1000);
  final out = <double>[];
  var peak = 1.0;
  for (var i = 0; i + 1 < pcm.length; i += per * 2) {
    var sum = 0.0;
    var n = 0;
    for (var j = i; j + 1 < pcm.length && j < i + per * 2; j += 2) {
      final v = data.getInt16(j, Endian.little).toDouble();
      sum += v * v;
      n++;
    }
    final rms = n == 0 ? 0.0 : sqrt(sum / n);
    out.add(rms);
    if (rms > peak) peak = rms;
  }
  return [for (final v in out) (v / (peak * 0.6)).clamp(0.0, 1.0).toDouble()];
}

class VoiceSpeaker implements Speaker {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  final ValueNotifier<double> _mouth = ValueNotifier(0);
  final ValueNotifier<double> _progress = ValueNotifier(0);
  AudioPlayer? _player; // a fresh player for every line, so an old line can never block a new one
  Map<String, Set<String>> _index = {};
  DateTime _indexAt = DateTime.fromMillisecondsSinceEpoch(0); // when the list of ready-made files was last fetched
  final Set<String> _missing = {}; // ready-made files looked for and not found, so we ask only once
  final Map<String, Future<Source?>> _making = {}; // lines being fetched right now, so two asks share one fetch
  final Map<String, List<double>?> _envelopes = {};
  String? _dir;
  int _gen = 0;
  static const _indexKey = 'voice_index_v1';
  static final _noise = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2190}-\u{21FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]',
      unicode: true);

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  ValueListenable<double> get mouth => _mouth;

  @override
  ValueListenable<double> get progress => _progress;

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

  String _style(TutorCharacter tutor) {
    final mood = toneStyle[voiceTone()];
    final base = tutor.style.isEmpty ? 'a warm, friendly teacher talking to a young child' : tutor.style;
    return mood == null ? base : '$base, $mood';
  }

  /// The line in the character's own Gemini voice: the phone's copy, or the Scol server's (made there once).
  Future<Source?> _gemini(TutorCharacter tutor, String lang, String text, {bool natural = false}) async {
    final voice = tutor.geminiVoice;
    final server = voiceServer();
    final url = '${server['url'] ?? ''}';
    if (voice.isEmpty || kIsWeb || _dir == null) return null;
    final style = _style(tutor);
    final name = 'gem3_${clipId('$voice|$style${natural ? '|live' : ''}', lang, text)}.wav';
    final file = File('$_dir/$name');
    if (await file.exists()) return DeviceFileSource(file.path);
    if (url.isEmpty) return null;
    try {
      final res = await http
          .post(Uri.parse(url),
              headers: {'content-type': 'application/json', 'apikey': '${server['public_key'] ?? ''}'},
              body: jsonEncode({
                'mode': 'speak',
                'text': spokenText(text, lang),
                'lang': lang,
                'voice': voice,
                'style': style,
                if (natural) 'live': true,
                'device': await deviceId(),
              }))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        voiceStatus.value = 'Gemini voice: the server answered ${res.statusCode}';
        return null;
      }
      final where = '${(jsonDecode(utf8.decode(res.bodyBytes)) as Map)['url'] ?? ''}';
      if (where.isEmpty) return null;
      final audio = await http.get(Uri.parse(where)).timeout(const Duration(seconds: 30));
      if (audio.statusCode != 200 || audio.bodyBytes.length < 1000) return null;
      voiceStatus.value = '';
      return DeviceFileSource((await _save(name, audio.bodyBytes)).path);
    } catch (e) {
      voiceStatus.value = 'Gemini voice: ${describeVoiceError(e)}';
      return null;
    }
  }

  /// The ready-made sound file for a line, downloading it if needed. Null if there is none.
  Future<Source?> _clip(TutorCharacter tutor, String lang, String text) async {
    final voice = tutor.voiceFor(lang);
    if (voice.isEmpty || voiceTone() != 'normal') return null;
    final id = clipId(voice, lang, text);
    final listed = _index[tutor.id]?.contains(id) ?? false;
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

  /// The character's Edge voice, made on the phone (needs internet): the stand-in when Gemini cannot speak.
  Future<Source?> _edge(TutorCharacter tutor, String lang, String text, {int tries = 2}) async {
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
        return DeviceFileSource((await _save(name, bytes)).path);
      } catch (e) {
        voiceStatus.value = 'Edge voice: ${describeVoiceError(e)}';
        if (attempt + 1 < tries) await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
    return null;
  }

  /// The best sound for a line: the Gemini voice, else a ready-made file, else the Edge voice.
  /// Null means the line stays silent (shown as text). Two asks for one line share one fetch.
  Future<Source?> _source(TutorCharacter tutor, String lang, String text, {bool natural = false}) {
    final key = '${tutor.id}|${voiceTone()}|$lang|$natural|$text';
    final running = _making[key];
    if (running != null) return running;
    final made = () async {
      try {
        return await _gemini(tutor, lang, text, natural: natural) ?? await _clip(tutor, lang, text) ?? await _edge(tutor, lang, text);
      } finally {
        _making.remove(key);
      }
    }();
    _making[key] = made;
    return made;
  }

  /// The pieces a line is spoken in: short lines whole, long ones sentence by sentence so the first is quick.
  List<String> _pieces(String text) => text.length <= 260 ? [text] : sentencePieces(text);

  @override
  void prefetch(Iterable<String> texts, String lang, TutorCharacter tutor) {
    if (kIsWeb) return;
    final lines = <String>[
      for (final t in texts.toSet())
        if (t.replaceAll(_noise, '').trim().isNotEmpty) ..._pieces(t),
    ];
    () async {
      if (DateTime.now().difference(_indexAt) > const Duration(minutes: 10)) unawaited(_refreshIndex());
      // Three at a time, in the order the child will hear them.
      var next = 0;
      Future<void> worker() async {
        while (next < lines.length) {
          final t = lines[next++];
          await _source(tutor, langOf(t), t);
        }
      }

      await Future.wait([worker(), worker(), worker()]);
    }();
  }

  Future<List<double>?> _envelopeOf(Source source) async {
    if (source is! DeviceFileSource || !source.path.endsWith('.wav')) return null;
    if (_envelopes.containsKey(source.path)) return _envelopes[source.path];
    try {
      final env = wavEnvelope(await File(source.path).readAsBytes());
      if (_envelopes.length > 200) _envelopes.remove(_envelopes.keys.first);
      return _envelopes[source.path] = env;
    } catch (_) {
      return null;
    }
  }

  /// Plays a Gemini voice line as raw sound (like the Gemini Live app does): smooth start and end,
  /// the mouth following its loudness and [progress] from [from] to [to].
  Future<bool> _playPcm(String path, double from, double to, int token, {Breath breath = Breath.none}) async {
    final w = wavPcm(await File(path).readAsBytes());
    if (w == null || token != _gen) return false;
    var pcm = smoothPcm(w.pcm, w.rate);
    if (pcm.isEmpty) return true;
    final envelope = pcmEnvelope(pcm, w.rate);
    final ms = max(1, pcm.length ~/ 2 * 1000 ~/ w.rate);
    // A quiet breath before the words, now and then; the mouth and the board wait for the words.
    var lead = 0;
    if (breath != Breath.none) {
      final b = breathPcm(w.rate, sigh: breath == Breath.sigh, seed: _rnd.nextInt(1 << 20));
      final gap = Uint8List(w.rate * 70 ~/ 1000 * 2);
      lead = (b.length + gap.length) ~/ 2;
      pcm = Uint8List.fromList([...b, ...gap, ...pcm]);
    }
    final out = PcmOut.instance;
    final ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (token != _gen) return;
      final t = max(0, out.framesPlayed - lead) * 1000 ~/ w.rate;
      _progress.value = from + (to - from) * (t / ms).clamp(0.0, 1.0);
      _mouth.value = envelope[(t ~/ 40).clamp(0, envelope.length - 1)];
    });
    try {
      await out.play(pcm, w.rate);
      return true;
    } catch (e) {
      voiceStatus.value = 'Playing a sound failed: ${describeVoiceError(e)}';
      return false;
    } finally {
      ticker.cancel();
      _mouth.value = 0;
    }
  }

  /// Plays one sound to the end (or until a newer line starts), moving the mouth with its loudness
  /// and [progress] from [from] to [to].
  Future<bool> _play(Source source, double from, double to, int token, {Breath breath = Breath.none}) async {
    if (source is DeviceFileSource && source.path.endsWith('.wav')) {
      final ok = await _playPcm(source.path, from, to, token, breath: breath);
      if (ok || token != _gen) return ok;
    }
    final player = AudioPlayer();
    _player = player;
    final done = Completer<void>();
    final envelope = await _envelopeOf(source);
    final subs = [
      player.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      }),
    ];
    Timer? ticker;
    try {
      await player.play(source);
      final clock = Stopwatch()..start();
      final length = await player.getDuration() ?? const Duration(seconds: 20);
      final ms = max(1, length.inMilliseconds);
      ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (token != _gen) return;
        final t = clock.elapsedMilliseconds;
        _progress.value = from + (to - from) * (t / ms).clamp(0.0, 1.0);
        if (envelope != null && envelope.isNotEmpty) {
          _mouth.value = envelope[(t ~/ 40).clamp(0, envelope.length - 1)];
        } else {
          // No loudness to read (an Edge mp3): open and close at the pace of syllables.
          _mouth.value =
              (sin(t / 1000 * 2 * pi * 4.2) * 0.5 + 0.5) * (0.6 + 0.4 * sin(t / 1000 * 2 * pi * 0.9).abs());
        }
      });
      await done.future.timeout(length + const Duration(seconds: 2), onTimeout: () {});
      return true;
    } catch (e) {
      voiceStatus.value = 'Playing a sound failed: ${describeVoiceError(e)}';
      return false;
    } finally {
      ticker?.cancel();
      _mouth.value = 0;
      for (final s in subs) {
        await s.cancel();
      }
      if (identical(_player, player)) _player = null;
      unawaited(player.dispose().catchError((_) {}));
    }
  }

  @override
  Future<void> say(List<String> parts, String lang, TutorCharacter tutor, {bool natural = false}) async {
    final token = ++_gen;
    await _halt();
    if (token != _gen) return;
    _progress.value = 0;
    _speaking.value = true;
    final pieces = <String>[
      for (final part in parts)
        if (part.replaceAll(_noise, '').trim().isNotEmpty) ..._pieces(part),
    ];
    final total = max(1, pieces.fold<int>(0, (a, p) => a + p.length));
    Future<Source?> fetch(int i) =>
        i < pieces.length ? _source(tutor, langOf(pieces[i]), pieces[i], natural: natural) : Future<Source?>.value(null);
    final breath = _nextBreath(pieces);
    var next = fetch(0);
    var done = 0;
    for (var i = 0; i < pieces.length; i++) {
      if (token != _gen) return;
      final source = await next;
      next = fetch(i + 1); // the next piece is made while this one plays
      if (token != _gen) return;
      final from = done / total;
      done += pieces[i].length;
      if (source != null) {
        await _play(source, from, done / total, token, breath: i == 0 ? breath : Breath.none);
      } else {
        _progress.value = done / total; // silent: the words stay on screen
      }
    }
    if (token == _gen) {
      _progress.value = 1;
      _speaking.value = false;
    }
  }

  final Random _rnd = Random();
  int _sinceBreath = 0;

  /// Now and then (about one line in seven, never two close together) the tutor takes a quiet breath
  /// before speaking, and once in a while a soft sigh, like a person. Never before a short word of praise.
  Breath _nextBreath(List<String> pieces) {
    _sinceBreath++;
    final words = pieces.join(' ').split(RegExp(r'\s+')).length;
    if (words < 6 || _sinceBreath < 4 || _rnd.nextDouble() > 0.16) return Breath.none;
    _sinceBreath = 0;
    return _rnd.nextDouble() < 0.3 ? Breath.sigh : Breath.breath;
  }

  Future<void> _halt() async {
    final p = _player;
    _player = null;
    _mouth.value = 0;
    try {
      await PcmOut.instance.stop();
    } catch (_) {}
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

enum Breath { none, breath, sigh }

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
