// Plays raw 16-bit mono sound (PCM) straight to the speaker, the way the
// Gemini voices are made: no media player and no file decoding in between, so
// a line starts at once and ends cleanly. Used for the characters' Gemini
// voices and for Gemini Live. One sound at a time.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Gives a short fade in and fade out to a 16-bit little-endian sound, and cuts the silence at both ends,
/// so playback never starts or stops on a click. Returns a new buffer.
Uint8List smoothPcm(Uint8List pcm, int rate, {int fadeInMs = 8, int fadeOutMs = 45}) {
  final n = pcm.length ~/ 2;
  if (n == 0) return pcm;
  final src = ByteData.sublistView(pcm);
  // Trim near-silence at the ends (keeping a little air).
  const quiet = 120;
  var start = 0;
  while (start < n && src.getInt16(start * 2, Endian.little).abs() < quiet) {
    start++;
  }
  if (start >= n) return Uint8List(0); // all silence: nothing to play
  var end = n;
  while (end > start && src.getInt16((end - 1) * 2, Endian.little).abs() < quiet) {
    end--;
  }
  start = max(0, start - rate * 20 ~/ 1000);
  end = min(n, end + rate * 60 ~/ 1000);
  if (end <= start) return Uint8List(0);
  final out = ByteData((end - start) * 2);
  final fin = max(1, rate * fadeInMs ~/ 1000);
  final fout = max(1, rate * fadeOutMs ~/ 1000);
  final len = end - start;
  for (var i = 0; i < len; i++) {
    var v = src.getInt16((start + i) * 2, Endian.little).toDouble();
    if (i < fin) v *= i / fin;
    if (i > len - fout) v *= max(0, len - i) / fout;
    out.setInt16(i * 2, v.round().clamp(-32768, 32767), Endian.little);
  }
  return out.buffer.asUint8List();
}

/// The PCM samples of a 16-bit mono WAV file, and its sample rate. Null if it is not one.
({Uint8List pcm, int rate})? wavPcm(Uint8List bytes) {
  if (bytes.length < 46 || String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
  final data = ByteData.sublistView(bytes);
  final rate = data.getUint32(24, Endian.little);
  final channels = data.getUint16(22, Endian.little);
  final bits = data.getUint16(34, Endian.little);
  if (bits != 16 || channels != 1 || rate == 0) return null;
  var off = 12;
  while (off + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(off, off + 4));
    final size = data.getUint32(off + 4, Endian.little);
    if (id == 'data') {
      final from = off + 8;
      final to = min(bytes.length, from + size) & ~1;
      return (pcm: Uint8List.sublistView(bytes, from, to), rate: rate);
    }
    off += 8 + size + (size & 1);
  }
  return null;
}

/// A soft breath or sigh, made from shaped noise, to play quietly before a line now and then so the tutor
/// sounds like a person. [sigh] is a longer, lower breath out. Same random [seed], same sound.
Uint8List breathPcm(int rate, {bool sigh = false, int seed = 0}) {
  final rnd = Random(seed);
  final inMs = sigh ? 380 : 300;
  final outMs = sigh ? 720 : 0;
  final n = rate * (inMs + outMs + 90) ~/ 1000;
  final out = ByteData(n * 2);
  final inN = rate * inMs ~/ 1000;
  final outN = rate * outMs ~/ 1000;
  // Two one-pole filters make a soft band of noise: airy breath in, lower breath out.
  var low = 0.0, lower = 0.0;
  for (var i = 0; i < n; i++) {
    final white = rnd.nextDouble() * 2 - 1;
    final inhale = i < inN;
    final a = inhale ? 0.35 : 0.18; // how much high sound passes
    low += a * (white - low);
    lower += 0.04 * (low - lower);
    final band = low - lower;
    double env;
    if (inhale) {
      final x = i / inN;
      env = sin(pi * x) * (0.6 + 0.4 * x);
    } else if (i < inN + outN) {
      final x = (i - inN) / outN;
      env = pow(sin(pi * min(1.0, x * 1.6)), 1.4).toDouble() * (1 - x * 0.5) * 0.9;
    } else {
      env = 0;
    }
    final v = band * env * (sigh ? 5200 : 4200);
    out.setInt16(i * 2, v.round().clamp(-32768, 32767), Endian.little);
  }
  return out.buffer.asUint8List();
}

/// Plays raw sound. While a sound is "open" (Gemini Live still sending) the speaker is kept fed with
/// silence so it never runs dry: a dry Android speaker buffer can buzz like a radio. Every sound ends
/// with a short stretch of silence, then the speaker is closed.
class PcmOut {
  PcmOut._();
  static final PcmOut instance = PcmOut._();

  final List<Uint8List> _queue = [];
  int _rate = 0;
  bool _ready = false;
  bool _feeding = false;
  bool _open = false; // more sound may still come
  bool _tailFed = false;
  int _gen = 0;
  Completer<void>? _drained;
  final Stopwatch _clock = Stopwatch();
  int _fed = 0; // frames handed over since begin, silence included
  final List<(int, int)> _pads = []; // where silence was put in (start frame, length), not part of the sound

  /// About how many frames of the sound itself (not the silence put in) have reached the speaker since [begin].
  int get framesPlayed {
    if (_rate == 0) return 0;
    final t = _clock.elapsedMilliseconds * _rate ~/ 1000;
    var p = t;
    for (final (start, len) in _pads) {
      if (start < t) p -= min(len, t - start);
    }
    return max(0, p);
  }

  Future<void> _setup(int rate) async {
    if (_ready && rate == _rate) return;
    if (_ready) await FlutterPcmSound.release();
    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await FlutterPcmSound.setup(sampleRate: rate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(rate ~/ 8); // ask for more when under 125 ms is waiting
    FlutterPcmSound.setFeedCallback(_onFeed);
    _rate = rate;
    _ready = true;
  }

  void _feed(Uint8List chunk, {bool silence = false}) {
    final frames = chunk.length ~/ 2;
    if (silence) _pads.add((_fed, frames));
    _fed += frames;
    // A copy of exactly this piece: the plugin sends the whole buffer behind a view, so a view of a
    // longer sound would play all of that sound again (the tutor 'repeating' and stuttering).
    final own = Uint8List.fromList(chunk);
    FlutterPcmSound.feed(PcmArrayInt16(bytes: own.buffer.asByteData()));
  }

  Uint8List _silence(int ms) => Uint8List(max(2, _rate * ms ~/ 1000) * 2);

  void _onFeed(int remaining) {
    if (!_feeding) return;
    if (_queue.isNotEmpty) {
      _feed(_queue.removeAt(0));
    } else if (_open) {
      _feed(_silence(60), silence: true); // waiting for more: keep the speaker playing silence
    } else if (!_tailFed) {
      _tailFed = true;
      _feed(_silence(260), silence: true); // let the voice ring out into silence
    } else if (remaining == 0) {
      _feeding = false;
      _clock.stop();
      final d = _drained;
      _drained = null;
      if (d != null && !d.isCompleted) d.complete();
      // Close the speaker once the silence has played, unless a new sound started.
      final gen = _gen;
      Future<void>.delayed(const Duration(milliseconds: 250), () async {
        if (gen != _gen || _feeding || !_ready) return;
        _ready = false;
        try {
          await FlutterPcmSound.release();
        } catch (_) {}
      });
    }
  }

  /// Starts a fresh sound: anything still queued from before is dropped. With [open], the sound
  /// keeps going (as silence) until [finish] is called, for sound that arrives in pieces.
  Future<void> begin(int rate, {bool open = false}) async {
    await stop();
    _gen++;
    await _setup(rate);
    _open = open;
    _tailFed = false;
    _fed = 0;
    _pads.clear();
    _clock.reset();
  }

  /// Adds sound to play after what is queued (100 ms pieces, so stopping is quick).
  void add(Uint8List pcm) {
    if (!_ready || pcm.isEmpty) return;
    final piece = max(2, _rate ~/ 10) * 2;
    for (var i = 0; i < pcm.length; i += piece) {
      _queue.add(Uint8List.sublistView(pcm, i, min(pcm.length, i + piece)));
    }
    _tailFed = false;
    if (!_feeding) {
      _feeding = true;
      if (!_clock.isRunning) _clock.start();
      // Start with a little silence so the first word is not clipped, then the sound.
      _feed(_silence(40), silence: true);
      FlutterPcmSound.start();
    }
  }

  /// No more sound will come for this one: it ends (with silence) once what is queued has played.
  void finish() {
    _open = false;
    if (!_feeding && _drained != null) {
      final d = _drained;
      _drained = null;
      if (!d!.isCompleted) d.complete();
    }
  }

  /// Completes when everything added so far has been played and [finish] was called (or [stop]).
  Future<void> drained() {
    if (!_feeding && _queue.isEmpty && !_open) return Future.value();
    return (_drained ??= Completer<void>()).future;
  }

  /// Plays one whole sound and waits for its end.
  Future<void> play(Uint8List pcm, int rate) async {
    await begin(rate);
    add(pcm);
    finish();
    await drained();
  }

  /// Drops what is queued and silences the speaker at once.
  Future<void> stop() async {
    _gen++;
    _queue.clear();
    _open = false;
    _clock.stop();
    final d = _drained;
    _drained = null;
    if (d != null && !d.isCompleted) d.complete();
    final wasFeeding = _feeding;
    _feeding = false;
    if (wasFeeding && _ready) {
      _ready = false; // release() silences what is already in the speaker's buffer
      try {
        await FlutterPcmSound.release();
      } catch (_) {}
    }
  }
}
