// A live spoken talk with the tutor through Gemini Live, in the character's
// own voice. The phone gets a one-use pass from the Scol server (the Gemini key
// never leaves the server), connects to Gemini Live with it, sends the
// microphone, and plays the tutor's voice as it arrives. The two take turns: the
// microphone is not sent while the tutor speaks, so the tutor never hears itself
// from the speaker (which made it answer itself and repeat). End stops everything.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'brain.dart' show deviceId;
import 'content.dart';
import 'pcm_out.dart';
import 'voice.dart' show pcmEnvelope;

enum LiveState { idle, connecting, live, ended, failed }

class LiveLine {
  LiveLine(this.fromChild, this.text);
  final bool fromChild;
  String text;
}

/// The setup message Gemini Live expects first: model, the character's voice, and the rules.
Map<String, dynamic> liveSetup(String model, String voice, String instructions) => {
      'setup': {
        'model': model,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voice}
            }
          },
        },
        // Wait for the child to really finish: children pause while they think.
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'startOfSpeechSensitivity': 'START_SENSITIVITY_LOW',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_LOW',
            'prefixPaddingMs': 200,
            'silenceDurationMs': 900,
          }
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        'systemInstruction': {
          'parts': [
            {'text': instructions}
          ]
        },
      }
    };

/// Loudness of 16-bit sound, 0 to 32767.
double pcmLoudness(Uint8List pcm) {
  final d = ByteData.sublistView(pcm);
  var sum = 0.0;
  final n = pcm.length ~/ 2;
  for (var i = 0; i < n; i++) {
    final v = d.getInt16(i * 2, Endian.little).toDouble();
    sum += v * v;
  }
  return n == 0 ? 0 : sqrt(sum / n);
}

class LiveTalk extends ChangeNotifier {
  LiveTalk({
    required this.server,
    required this.tutor,
    required this.lang,
    this.tone = 'normal',
    this.childName = '',
    this.lessonTitle = '',
    this.notes = '',
    this.progress = '',
  });

  final Map<String, dynamic> server;
  final TutorCharacter tutor;
  final String lang;
  final String tone;
  final String childName;
  final String lessonTitle;
  final String notes;
  final String progress;

  LiveState state = LiveState.idle;
  String problem = '';
  final List<LiveLine> lines = [];

  /// How open the tutor's mouth is, 0 to 1, following the voice as it plays.
  final ValueNotifier<double> mouth = ValueNotifier(0);

  /// True while the tutor's voice is playing.
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  WebSocket? _ws;
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _mic;
  Completer<bool>? _ready;
  Future<void> _out = Future.value(); // keeps the tutor's sound in order
  bool _playing = false;
  DateTime _micOpensAt = DateTime(0); // the microphone waits a moment after the tutor stops
  final List<double> _envelope = []; // loudness of the tutor's voice since it started, every 40 ms
  Timer? _ticker;
  static const _rate = 24000;

  bool get isLive => state == LiveState.live;

  void _set(LiveState s, [String why = '']) {
    state = s;
    if (why.isNotEmpty) problem = why;
    notifyListeners();
  }

  String _instructions(String rules) => [
        rules,
        if (childName.trim().isNotEmpty) "The child's first name is ${childName.trim()}.",
        if (lessonTitle.isNotEmpty) 'The child is on the lesson "$lessonTitle". What the lesson says:\n$notes',
        if (progress.isNotEmpty) 'How the child is doing lately (for you only; mention it when it helps or when asked):\n$progress',
      ].join('\n');

  /// Connects and starts listening. False if a live talk cannot be had now (no internet, no pass, no microphone).
  Future<bool> start() async {
    if (state == LiveState.connecting || state == LiveState.live) return true;
    _set(LiveState.connecting);
    try {
      final url = '${server['url'] ?? ''}';
      if (url.isEmpty) throw StateError('no server');
      final res = await http
          .post(Uri.parse(url),
              headers: {'content-type': 'application/json', 'apikey': '${server['public_key'] ?? ''}'},
              body: jsonEncode({
                'mode': 'live',
                'device': await deviceId(),
                'lang': lang,
                'tutor': tutor.displayName('en'),
                'about': pick(tutor.about, 'en'),
                'tone': tone,
              }))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 429) throw StateError('limit');
      if (res.statusCode != 200) throw StateError('no pass (${res.statusCode})');
      final pass = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
      final token = '${pass['token'] ?? ''}';
      if (token.isEmpty) throw StateError('no pass');
      if (!await _rec.hasPermission()) throw StateError('microphone');

      _ws = await WebSocket.connect('${pass['url']}?access_token=${Uri.encodeQueryComponent(token)}')
          .timeout(const Duration(seconds: 12));
      _ready = Completer<bool>();
      _ws!.listen(_onMessage, onDone: _onClosed, onError: (_) => _onClosed(), cancelOnError: true);
      final voice = tutor.geminiVoice.isEmpty ? 'Aoede' : tutor.geminiVoice;
      _ws!.add(jsonEncode(liveSetup('${pass['model']}', voice, _instructions('${pass['rules'] ?? ''}'))));
      if (!await _ready!.future.timeout(const Duration(seconds: 12), onTimeout: () => false)) {
        throw StateError('Gemini Live did not answer');
      }

      final stream = await _rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceCommunication),
      ));
      _mic = stream.listen(_sendMic);
      _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
      _set(LiveState.live);
      // The tutor speaks first.
      sendText(lang == 'ml'
          ? 'ഒരു സാധാരണ ടീച്ചറെപ്പോലെ ശാന്തമായി, ഒരു ചെറിയ വാക്യത്തിൽ കുട്ടിയെ അഭിവാദ്യം ചെയ്ത്, ഈ പാഠത്തെക്കുറിച്ച് എന്താണ് അറിയേണ്ടത് എന്ന് ചോദിക്കൂ. മലയാളത്തിൽ മാത്രം സംസാരിക്കൂ.'
          : 'Greet the child the way a calm, kind teacher would, in one short natural sentence (no big excitement), and ask what they would like to know about this lesson.',
          show: false);
      return true;
    } catch (e) {
      await _shutdown();
      _set(LiveState.failed, '$e');
      return false;
    }
  }

  void _sendMic(Uint8List chunk) {
    final ws = _ws;
    if (ws == null || state != LiveState.live) return;
    // Turn-taking: nothing goes out while the tutor talks or just after (its echo would come back).
    if (_playing || DateTime.now().isBefore(_micOpensAt)) return;
    ws.add(jsonEncode({
      'realtimeInput': {
        'mediaChunks': [
          {'mimeType': 'audio/pcm;rate=16000', 'data': base64Encode(chunk)}
        ]
      }
    }));
  }

  /// Sends typed words (or an instruction) as the child's turn.
  void sendText(String text, {bool show = true}) {
    final clean = text.trim();
    final ws = _ws;
    if (ws == null || clean.isEmpty) return;
    ws.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': clean}
            ]
          }
        ],
        'turnComplete': true,
      }
    }));
    if (show) {
      lines.add(LiveLine(true, clean));
      notifyListeners();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final msg = (jsonDecode(text) as Map).cast<String, dynamic>();
      if (msg.containsKey('setupComplete')) {
        if (_ready != null && !_ready!.isCompleted) _ready!.complete(true);
        return;
      }
      final content = (msg['serverContent'] as Map?)?.cast<String, dynamic>();
      if (content == null) return;
      if (content['interrupted'] == true) _interrupt();
      final heard = (content['inputTranscription'] as Map?)?['text'];
      if (heard is String && heard.trim().isNotEmpty) _appendLine(true, heard);
      final said = (content['outputTranscription'] as Map?)?['text'];
      if (said is String && said.trim().isNotEmpty) _appendLine(false, said);
      final parts = ((content['modelTurn'] as Map?)?['parts'] as List?) ?? const [];
      for (final p in parts) {
        final inline = (p as Map)['inlineData'] as Map?;
        if (inline == null) continue;
        final mime = '${inline['mimeType'] ?? ''}';
        final data = '${inline['data'] ?? ''}';
        if (mime.startsWith('audio/pcm') && data.isNotEmpty) _play(base64Decode(data));
      }
      if (content['turnComplete'] == true) {
        _closeLines();
        _out = _out.then((_) => PcmOut.instance.finish()); // the tutor's turn ends once its sound has played
      }
    } catch (_) {
      // one odd message must not end the talk
    }
  }

  bool _lineOpen = false;

  void _appendLine(bool fromChild, String chunk) {
    if (lines.isNotEmpty && _lineOpen && lines.last.fromChild == fromChild) {
      lines.last.text += chunk;
    } else {
      lines.add(LiveLine(fromChild, chunk.trimLeft()));
      _lineOpen = true;
    }
    notifyListeners();
  }

  void _closeLines() {
    _lineOpen = false;
  }

  void _play(Uint8List pcm) {
    _out = _out.then((_) async {
      final out = PcmOut.instance;
      if (!_playing) {
        _playing = true;
        speaking.value = true;
        _envelope.clear();
        await out.begin(_rate, open: true);
        unawaited(() async {
          await out.drained();
          // the tutor's turn has played to the end
          if (_playing) {
            _playing = false;
            _micOpensAt = DateTime.now().add(const Duration(milliseconds: 700));
            speaking.value = false;
            mouth.value = 0;
          }
        }());
      }
      _envelope.addAll(pcmEnvelope(pcm, _rate));
      out.add(pcm);
    });
  }

  void _tick() {
    if (!_playing || _envelope.isEmpty) {
      if (mouth.value != 0) mouth.value = 0;
      return;
    }
    final i = PcmOut.instance.framesPlayed * 1000 ~/ _rate ~/ 40;
    mouth.value = i < _envelope.length ? _envelope[i] : 0;
  }

  void _interrupt() {
    _out = _out.then((_) async {
      await PcmOut.instance.stop();
      _playing = false;
      _micOpensAt = DateTime.now().add(const Duration(milliseconds: 400));
      speaking.value = false;
      mouth.value = 0;
    });
  }

  /// The child tapped to stop the tutor: quiet now, and the microphone opens.
  void hush() {
    if (_playing) _interrupt();
  }

  void _onClosed() {
    if (_ready != null && !_ready!.isCompleted) _ready!.complete(false);
    if (state == LiveState.live || state == LiveState.connecting) {
      unawaited(_shutdown());
      _set(LiveState.ended);
    }
  }

  Future<void> _shutdown() async {
    _ticker?.cancel();
    _ticker = null;
    await _mic?.cancel();
    _mic = null;
    try {
      await _rec.stop();
    } catch (_) {}
    final ws = _ws;
    _ws = null;
    try {
      await ws?.close();
    } catch (_) {}
    _playing = false;
    speaking.value = false;
    mouth.value = 0;
    try {
      await PcmOut.instance.stop();
    } catch (_) {}
  }

  /// Ends the talk: microphone off, tutor quiet, connection closed.
  Future<void> end() async {
    await _shutdown();
    _set(LiveState.ended);
  }

  @override
  void dispose() {
    unawaited(_shutdown());
    unawaited(_rec.dispose());
    super.dispose();
  }
}
