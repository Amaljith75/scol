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

class PcmOut {
  PcmOut._();
  static final PcmOut instance = PcmOut._();

  final List<Uint8List> _queue = [];
  int _rate = 0;
  bool _ready = false;
  bool _feeding = false;
  Completer<void>? _drained;
  final Stopwatch _clock = Stopwatch();
  int _playedBefore = 0; // frames that finished before the clock was last started

  /// About how many frames have reached the speaker since [begin], for the mouth and the progress bar.
  int get framesPlayed => _rate == 0 ? 0 : _playedBefore + _clock.elapsedMilliseconds * _rate ~/ 1000;

  Future<void> _setup(int rate) async {
    if (_ready && rate == _rate) return;
    if (_ready) await FlutterPcmSound.release();
    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await FlutterPcmSound.setup(sampleRate: rate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(rate ~/ 10); // ask for more when under 100 ms is left
    FlutterPcmSound.setFeedCallback(_onFeed);
    _rate = rate;
    _ready = true;
  }

  void _onFeed(int remaining) {
    if (_queue.isNotEmpty) {
      final chunk = _queue.removeAt(0);
      FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(chunk)));
    } else if (remaining == 0) {
      _feeding = false;
      _clock.stop();
      final d = _drained;
      _drained = null;
      if (d != null && !d.isCompleted) d.complete();
    }
  }

  /// Starts a fresh sound: anything still queued from before is dropped.
  Future<void> begin(int rate) async {
    await stop();
    await _setup(rate);
    _playedBefore = 0;
    _clock
      ..reset()
      ..start();
  }

  /// Adds sound to play after what is queued (100 ms pieces, so stopping is quick).
  void add(Uint8List pcm) {
    if (!_ready || pcm.isEmpty) return;
    final piece = max(2, _rate ~/ 10) * 2;
    for (var i = 0; i < pcm.length; i += piece) {
      final c = Uint8List.sublistView(pcm, i, min(pcm.length, i + piece));
      _queue.add(c);
    }
    if (!_feeding) {
      _feeding = true;
      if (!_clock.isRunning) _clock.start();
      if (!FlutterPcmSound.start()) _onFeed(0);
    }
  }

  /// Completes when everything added so far has been played (or [stop] was called).
  Future<void> drained() {
    if (!_feeding && _queue.isEmpty) return Future.value();
    return (_drained ??= Completer<void>()).future;
  }

  /// Plays one whole sound and waits for its end.
  Future<void> play(Uint8List pcm, int rate) async {
    await begin(rate);
    add(pcm);
    await drained();
  }

  /// Drops what is queued and silences the speaker at once.
  Future<void> stop() async {
    _queue.clear();
    _clock.stop();
    final d = _drained;
    _drained = null;
    if (d != null && !d.isCompleted) d.complete();
    if (_feeding && _ready) {
      _feeding = false;
      _ready = false; // release() silences what is already in the speaker's buffer
      try {
        await FlutterPcmSound.release();
      } catch (_) {}
    }
    _feeding = false;
  }
}
