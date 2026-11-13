// Speaks any text in a Microsoft Edge voice, live, straight from the phone.
// Used for lines that have no ready-made sound file: the parent report, live
// answers from the tutor brain, and anything new. No key is needed.
// The connection details follow the open-source edge-tts library (7.3.1).
// Note: these voices are fine for testing and demos, but are not licensed for a
// paid launch (see docs/TUTOR_BRAIN.md).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

BigInt _b(int v) => BigInt.from(v);

// ---------------- Sec-MS-GEC token (port of generate_sec_ms_gec_v2) ----------------

// Constant tables from edge-tts 7.3.1 (edge_tts/drm.py).
final _initial = [_b(0x6a09e667), _b(0xbb67ae85), _b(0x3c6ef372), _b(0xa54ff53a), _b(0x510e527f), _b(0x9b05688c), _b(0x1f83d9ab), _b(0x5be0cd19)];
final _state0 = [_b(0xfd9fbea2), _b(0x91243ce7), _b(0xbe499094), _b(0xcd2e1e0a), _b(0x6c006f49), _b(0x4bd35ab), _b(0xfeb0a7e4), _b(0x3effbd2)];
final _schedule = [_b(0xeb24bf9e), _b(0x1558691f), _b(0xa0c09ee2), _b(0xcfa32ba), _b(0xa622ee8c), _b(0xd1dd9491), _b(0xc0dd25a0), _b(0xf9e70ab6), _b(0xf0c31573), _b(0x7058ce4e), _b(0x7188e606), _b(0xe5ab33), _b(0xd258b060), _b(0x72766564)];
final _rc = [_b(0x428a2f98), _b(0x71374491), _b(0xb5c0fbcf), _b(0xe9b5dba5), _b(0x3956c25b), _b(0x59f111f1), _b(0x923f82a4), _b(0xab1c5ed5), _b(0xd807aa98), _b(0x12835b01), _b(0x243185be), _b(0x550c7dc3), _b(0x72be5d74), _b(0x80deb1fe), _b(0x9bdc06a7), _b(0xc19bf174), _b(0xe49b69c1), _b(0xefbe4786), _b(0xfc19dc6), _b(0x240ca1cc), _b(0x2de92c6f), _b(0x4a7484aa), _b(0x5cb0a9dc), _b(0x76f988da), _b(0x983e5152), _b(0xa831c66d), _b(0xb00327c8), _b(0xbf597fc7), _b(0xc6e00bf3), _b(0xd5a79147), _b(0x6ca6351), _b(0x14292967), _b(0x27b70a85), _b(0x2e1b2138), _b(0x4d2c6dfc), _b(0x53380d13), _b(0x650a7354), _b(0x766a0abb), _b(0x81c2c92e), _b(0x92722c85), _b(0xa2bfe8a1), _b(0xa81a664b), _b(0xc24b8b70), _b(0xc76c51a3), _b(0xd192e819), _b(0xd6990624), _b(0xf40e3585), _b(0x106aa070), _b(0x19a4c116), _b(0x1e376c08), _b(0x2748774c), _b(0x34b0bcb5), _b(0x391c0cb3), _b(0x4ed8aa4a), _b(0x5b9cca4f), _b(0x682e6ff3), _b(0x748f82ee), _b(0x78a5636f), _b(0x84c87814), _b(0x8cc70208), _b(0x90befffa), _b(0xa4506ceb), _b(0xbef9a3f7), _b(0xc67178f2)];
final _blockRc = [_b(0x428a2f98), _b(0x71374491), _b(0xb5c0fbcf), _b(0xe9b5dba5), _b(0x3956c25b), _b(0x59f111f1), _b(0x923f82a4), _b(0xab1c5ed5), _b(0xd807aa98), _b(0x12835b01), _b(0x243185be), _b(0x550c7dc3), _b(0x72be5d74), _b(0x80deb1fe), _b(0xc9dc06a7), _b(0xc19bf174), _b(0xe49b69c1), _b(0xefbe4786), _b(0xfc19dc6), _b(0x240ca1cc), _b(0x2de92c6f), _b(0x4a7484aa), _b(0x5cb0a9dc), _b(0x76f988da), _b(0x983e5152), _b(0xa831c66d), _b(0xb00327c8), _b(0xbf597fc7), _b(0xc6e00bf3), _b(0xd5a79147), _b(0x6ca6351), _b(0x14292967), _b(0x27b70a85), _b(0x2e1b2138), _b(0x4d2c6dfc), _b(0x53380d13), _b(0x650a7354), _b(0x766a0abb), _b(0x81c2c92e), _b(0x92722c85), _b(0xa2bfe8a1), _b(0xa81a664b), _b(0xc24b8b70), _b(0xc76c51a3), _b(0xd192e819), _b(0xd6990624), _b(0xf40e3585), _b(0x106aa070), _b(0x19a4c116), _b(0x1e376c08), _b(0x2748774c), _b(0x34b0bcb5), _b(0x391c0cb3), _b(0x4ed8aa4a), _b(0x5b9cca4f), _b(0x682e6ff3), _b(0x748f82ee), _b(0x78a5636f), _b(0x84c87814), _b(0x8cc70208), _b(0x90befffa), _b(0xa4506ceb), _b(0xbef9a3f7), _b(0xc67178f2)];
final _adj = _b(0xc9dc06a7), _sig0Adj = _b(0x59c0b80), _sig1Adj = _b(0xb92c0);
final _cs64 = [[_b(0xe82e91b1), _b(0xb32700d0)], [_b(0x44de24c6), _b(0x88dff51d)], [_b(0x3beb65bc), _b(0x29514038)], [_b(0xc89c5933), _b(0xb328cbdf)], [_b(0x8d1ec211), _b(0xd405b4d5)], [_b(0x314ef5d5), _b(0x26e55f3c)], [_b(0xe92491b1), _b(0x607801c6)], [_b(0xf0a5b9d5), _b(0x82b2c1fb)], [_b(0x6064cf3), _b(0xfa51a3da)], [_b(0xda79fa60), _b(0x207cc464)], [_b(0xbed20560), _b(0x3c3c74f3)], [_b(0x89f9c9f8), _b(0xd2d14b61)], [_b(0x35fa38c6), _b(0xbb04a2c1)], [_b(0xcb49e3c6), _b(0xc5626167)]];
final _cs64Factor = _b(0x82893933), _cs64Adj0 = _b(0xf2f90b1a), _cs64Adj1 = _b(0xb1a0000);

final _m = _b(0xFFFFFFFF);
final _r = BigInt.parse('100000001', radix: 16);

BigInt _rol16(BigInt v) {
  v &= _m;
  return ((v << 16) | (v >> 16)) & _m;
}

BigInt _sigma0(BigInt v) => ((v >> 7) ^ (v << 25) ^ (v >> 18) ^ (v << 14) ^ (v >> 3)) & _m;
BigInt _sigma1(BigInt v) => ((v >> 17) ^ (v << 15) ^ (v >> 19) ^ (v << 13) ^ (v >> 10)) & _m;
BigInt _bigS(BigInt x) => ((x * _r) >> 6) ^ ((x * _r) >> 11) ^ ((x * _r) >> 25);
BigInt _bigA(BigInt x) => ((x * _r) >> 2) ^ ((x * _r) >> 13) ^ ((x * _r) >> 22);

List<BigInt> _rounds(List<BigInt> state, List<BigInt> w, [int first = 0]) {
  var a = state[0], b = state[1], c = state[2], d = state[3], e = state[4], f = state[5], g = state[6], h = state[7];
  final k = first == 14 ? _blockRc : _rc;
  for (var i = first; i < 64; i++) {
    final t1 = h + _bigS(e) + (g ^ (e & (f ^ g))) + k[i] + w[i];
    final t2 = _bigA(a) + ((a & b) | (c & (a | b)));
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _m;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _m;
  }
  return [a, b, c, d, e, f, g, h];
}

void _expand(List<BigInt> w, [int first = 16]) {
  for (var i = first; i < 64; i++) {
    final x = w[i - 2], y = w[i - 15];
    final s1 = (x >> 17) ^ (x << 15) ^ (x >> 19) ^ (x << 13) ^ (x >> 10);
    final s0 = (y >> 7) ^ (y << 25) ^ (y >> 18) ^ (y << 14) ^ (y >> 3);
    w.add((s1 + w[i - 7] + s0 + w[i - 16]) & _m);
  }
}

BigInt _be(List<int> bytes) => bytes.fold(BigInt.zero, (acc, x) => (acc << 8) | _b(x));

List<BigInt> _init(List<int> d7) {
  final w = <BigInt>[...List.filled(14, BigInt.zero), _be(d7.sublist(0, 3)), _be(d7.sublist(3, 7))];
  for (var i = 16; i < 30; i++) {
    var v = _schedule[i - 16];
    if (i - 2 >= 14) v += i == 16 ? (_sigma1(w[i - 2]) ^ _sig1Adj) : _sigma1(w[i - 2]);
    if (i - 7 >= 14) v += w[i - 7];
    if (i - 15 >= 14) v += i == 29 ? (_sigma0(w[i - 15]) ^ _sig0Adj) : _sigma0(w[i - 15]);
    w.add(v & _m);
  }
  w.add((_sigma1(w[28]) + w[23] + _sigma0(w[15]) + w[14] + _adj - _rc[14]) & _m);
  _expand(w, 31);
  final r = _rounds(_state0, w, 14);
  return [for (var i = 0; i < 8; i++) (_initial[i] + r[i]) & _m];
}

List<BigInt> _sha(List<int> data) {
  final length = 57 + data.length;
  final pad = ((55 - length) % 64 + 64) % 64;
  final p = <int>[...data.sublist(7), 0x80, ...List.filled(pad, 0)];
  final bits = length * 8;
  for (var s = 56; s >= 0; s -= 8) {
    p.add((bits >> s) & 0xff);
  }
  var state = _init(data.sublist(0, 7));
  for (var off = 0; off < p.length; off += 64) {
    final w = [for (var j = 0; j < 16; j++) _be(p.sublist(off + 4 * j, off + 4 * j + 4))];
    _expand(w);
    final r = _rounds(state, w);
    state = [for (var i = 0; i < 8; i++) (state[i] + r[i]) & _m];
  }
  return state;
}

BigInt _swap(BigInt w) =>
    ((w & _b(0xff)) << 24) | (((w >> 8) & _b(0xff)) << 16) | (((w >> 16) & _b(0xff)) << 8) | (w >> 24);

List<BigInt> _cs64Digest(List<int> data, List<BigInt> digest) {
  final keyA = _swap(digest[0]) | BigInt.one, keyB = _swap(digest[1]) | BigInt.one;
  final factors = [(keyA * _cs64Factor) & _m, (keyB * _cs64Factor) & _m];
  final terms = [for (var i = 0; i < _cs64.length; i++) (_cs64[i][0] * factors[i % 2]) & _m];
  final offsets = [for (final c in _cs64) c[1]];
  final bytes = [0, ...data];
  while (bytes.length % 4 != 0) {
    bytes.add(0);
  }
  final words = [
    for (var i = 0; i < bytes.length; i += 4)
      _b(bytes[i]) | (_b(bytes[i + 1]) << 8) | (_b(bytes[i + 2]) << 16) | (_b(bytes[i + 3]) << 24)
  ];
  if (words.length.isOdd) words.add(BigInt.zero);
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    var term = word * (i.isEven ? keyA : keyB);
    var offset = _rol16(word) * (i.isEven ? _b(0xEF0569FB) : _b(0xC31713DB));
    if (i == 0) {
      term += _cs64Adj0 * factors[0];
      offset += _cs64Adj1;
    }
    terms.add(term & _m);
    offsets.add(offset & _m);
  }
  var swapAcc = BigInt.zero, swapLast = BigInt.zero, state = BigInt.zero, acc = BigInt.zero;
  for (var i = 0; i < terms.length; i += 2) {
    final x = terms[i], y = terms[i + 1];
    var t = _rol16((offsets[i] + x) & _m);
    var q = (t * _b(0x76F50F34)) & _m;
    swapAcc += (_rol16(q) * _b(0xC3EFEA97) + q) & _m;
    t = _rol16((offsets[i + 1] + y) & _m);
    q = (t * _b(0x1881CE3C)) & _m;
    swapLast = (_rol16(q) * _b(0x35BD1EC9) + q) & _m;
    swapAcc = (swapAcc + swapLast) & _m;
    state = (state * keyA + x) & _m;
    state = (_rol16(state) * _b(0xCF98B111)) & _m;
    state = (_rol16(state) * _b(0x87085B9F)) & _m;
    state = (_rol16(state) * _b(0x12CEB96D)) & _m;
    state = (_rol16(state) * _b(0x257E1D83)) & _m;
    acc += state;
    t = (state * keyB + y) & _m;
    t = (_rol16(t) * _b(0xA27416F5)) & _m;
    t = (_rol16(t) * _b(0xD38396FF)) & _m;
    state = (_rol16((_rol16(t) * _b(0x7C932B89)) & _m) * _b(0xBFA49F69)) & _m;
    acc = (acc + state) & _m;
  }
  return [swapLast ^ state, swapAcc ^ acc];
}

String _hex8(BigInt w) => w.toRadixString(16).toUpperCase().padLeft(8, '0');

const _token = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
const _chromium = '143.0.3650.75';

/// The Sec-MS-GEC value for a moment in time (seconds since 1970).
String secMsGec(double unixSeconds) {
  var ticks = unixSeconds + 11644473600;
  ticks -= ticks % 300;
  ticks *= 1e9 / 100;
  final text = '${BigInt.from(ticks.round())}$_token';
  final data = ascii.encode(text);
  final digest = _sha(data);
  final cs = _cs64Digest(data, digest);
  return '${_hex8(_swap(cs[0]))}${_hex8(_swap(cs[1]))}-${digest.map(_hex8).join()}';
}

// ---------------- Speaking ----------------

String _rand(int bytes) {
  final r = Random.secure();
  return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String _stamp() {
  final d = DateTime.now().toUtc();
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]} ${months[d.month - 1]} ${two(d.day)} ${d.year} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)} GMT+0000 (Coordinated Universal Time)';
}

String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// How many seconds the phone's clock is behind the voice server. The token above is
/// made from the time, so a phone whose clock is off is refused until we learn the difference
/// (the same trick the edge-tts library uses).
double _clockSkew = 0;
bool _clockSynced = false;

Future<void> _syncClock() async {
  _clockSynced = true;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(Uri.parse(
        'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=$_token'));
    final res = await req.close().timeout(const Duration(seconds: 8));
    final date = res.headers.value('date');
    await res.drain<void>();
    if (date == null) return;
    final server = HttpDate.parse(date);
    _clockSkew = (server.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch) / 1000;
  } catch (_) {
    // Could not read the server's clock: keep going with the phone's.
  } finally {
    client.close(force: true);
  }
}

/// Returns MP3 audio of [text] spoken by [voice], or throws.
/// If the server refuses the connection (usually a phone clock that is off), it learns the
/// server's time once and tries again.
Future<Uint8List> edgeSpeak(String text, String voice, {String rate = '+0%', String pitch = '+0Hz'}) async {
  try {
    return await _edgeSpeak(text, voice, rate: rate, pitch: pitch);
  } on WebSocketException {
    if (_clockSynced) rethrow;
    await _syncClock();
    return _edgeSpeak(text, voice, rate: rate, pitch: pitch);
  }
}

Future<Uint8List> _edgeSpeak(String text, String voice, {required String rate, required String pitch}) async {
  const major = '143';
  final url = 'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1'
      '?TrustedClientToken=$_token&ConnectionId=${_rand(16)}'
      '&Sec-MS-GEC=${secMsGec(DateTime.now().millisecondsSinceEpoch / 1000 + _clockSkew)}&Sec-MS-GEC-Version=2-$_chromium';
  final ws = await WebSocket.connect(url, headers: {
    'Pragma': 'no-cache',
    'Cache-Control': 'no-cache',
    'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/$major.0.0.0 Safari/537.36 Edg/$major.0.0.0',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cookie': 'muid=${_rand(16).toUpperCase()};',
  }).timeout(const Duration(seconds: 10));
  final audio = BytesBuilder();
  final done = Completer<Uint8List>();
  ws.listen((msg) {
    if (msg is String) {
      if (msg.contains('Path:turn.end') && !done.isCompleted) done.complete(audio.takeBytes());
    } else if (msg is List<int>) {
      final headLen = (msg[0] << 8) | msg[1];
      if (utf8.decode(msg.sublist(2, 2 + headLen), allowMalformed: true).contains('Path:audio')) {
        audio.add(msg.sublist(2 + headLen));
      }
    }
  }, onError: (Object e) {
    if (!done.isCompleted) done.completeError(e);
  }, onDone: () {
    if (!done.isCompleted) done.completeError(StateError('closed early'));
  });
  ws.add('X-Timestamp:${_stamp()}\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n'
      '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},'
      '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n');
  ws.add('X-RequestId:${_rand(16)}\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:${_stamp()}Z\r\nPath:ssml\r\n\r\n'
      "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>"
      "<voice name='$voice'><prosody pitch='$pitch' rate='$rate' volume='+0%'>${_escape(text)}</prosody></voice></speak>");
  try {
    final bytes = await done.future.timeout(const Duration(seconds: 20));
    if (bytes.length < 1000) throw StateError('no audio');
    return bytes;
  } finally {
    unawaited(ws.close());
  }
}
