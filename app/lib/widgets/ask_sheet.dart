// The "Ask Mio" sheet: a live, two-way talk with the tutor. The child speaks, the
// tutor answers aloud and listens again, until the child taps End (or types instead).
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../brain.dart';
import '../content.dart';
import '../live.dart';
import '../report.dart';
import '../state.dart';
import '../strings.dart';
import '../tutor.dart';
import '../voice.dart';
import 'avatar.dart';
import 'ui.dart';

final SpeechToText _stt = SpeechToText();
bool _sttReady = false;

/// Opens the sheet. [lessonTitle] and [notes] tell the brain what is being taught.
Future<void> openAskSheet(BuildContext context, {String lessonTitle = '', String notes = ''}) async {
  final lang = appState.mainLang;
  if (!appState.askEnabled) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('askTitle', lang)),
        content: Text(tr('askOff', lang)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
    return;
  }
  appSpeaker?.stop();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _AskSheet(lessonTitle: lessonTitle, notes: notes),
  );
  appSpeaker?.stop();
}

class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.lessonTitle, required this.notes});
  final String lessonTitle;
  final String notes;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _text = TextEditingController();
  String _heard = '';
  String _answer = '';
  bool _listening = false;
  bool _thinking = false;
  bool _micMissing = false;
  bool _live = true; // keep listening after each answer, like a phone call, until End
  final List<List<String>> _chat = []; // [question, answer]

  /// A Gemini Live talk, when one can be had; otherwise the phone's speech recognition and the tutor brain.
  LiveTalk? _talk;
  bool _starting = true;

  String get lang => appState.mainLang;
  TutorCharacter get tutor => tutorById(appState.tutorId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLive());
  }

  /// Tries a Gemini Live talk first; if it cannot start, talks through speech recognition instead.
  Future<void> _startLive() async {
    appSpeaker?.stop();
    if (appState.voiceOn) {
      final talk = LiveTalk(
        server: contentStore.bundle.brain,
        tutor: tutor,
        lang: lang,
        tone: appState.tone,
        childName: appState.childName,
        lessonTitle: widget.lessonTitle,
        notes: widget.notes,
        progress: progressFacts(appState, contentStore.bundle, lang),
      );
      if (await talk.start()) {
        if (!mounted) {
          talk.dispose();
          return;
        }
        talk.addListener(_liveChanged);
        setState(() {
          _talk = talk;
          _starting = false;
        });
        return;
      }
      talk.dispose();
    }
    if (!mounted) return;
    setState(() => _starting = false);
    _listen();
  }

  void _liveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.dispose();
    appSpeaker?.speaking.removeListener(_spoken);
    if (_listening) _stt.stop();
    _talk?.removeListener(_liveChanged);
    _talk?.dispose();
    super.dispose();
  }

  /// The tutor finished speaking: in a live talk, listen for the child's next words
  /// (after a short pause, so the speaker has gone quiet before the microphone opens).
  void _spoken() {
    if (!mounted || appSpeaker?.speaking.value != false) return;
    appSpeaker?.speaking.removeListener(_spoken);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _live && !_listening && !_thinking && appSpeaker?.speaking.value != true) _listen();
    });
  }

  /// End the live talk: stop listening and speaking; typing still works.
  void _end() {
    appSpeaker?.speaking.removeListener(_spoken);
    appSpeaker?.stop();
    if (_listening) _stt.stop();
    _talk?.end();
    setState(() {
      _live = false;
      _listening = false;
    });
  }

  Future<void> _listen() async {
    if (_thinking) return;
    appSpeaker?.stop();
    try {
      if (!_sttReady) {
        _sttReady = await _stt.initialize(onError: (_) => _stopped(), onStatus: (s) {
          if (s == 'done' || s == 'notListening') _stopped();
        });
      }
    } catch (_) {
      _sttReady = false;
    }
    if (!_sttReady) {
      setState(() => _micMissing = true);
      return;
    }
    setState(() {
      _listening = true;
      _heard = '';
    });
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: lang == 'ml' ? 'ml_IN' : 'en_IN',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (r) {
        setState(() => _heard = r.recognizedWords);
        if (r.finalResult) _send(r.recognizedWords);
      },
    );
  }

  void _stopped() {
    if (mounted && _listening) setState(() => _listening = false);
  }

  Future<void> _send(String question) async {
    final q = question.trim();
    final talk = _talk;
    if (talk != null && talk.isLive) {
      // Typed words go into the live talk.
      if (q.isNotEmpty) talk.sendText(q);
      _text.clear();
      return;
    }
    if (q.length < 2 || _thinking) return;
    if (_listening) await _stt.stop();
    setState(() {
      _listening = false;
      _thinking = true;
      _answer = '';
      _text.clear();
    });
    final reply = await askBrain(
      bundle: contentStore.bundle,
      question: q,
      lang: lang,
      tutorName: tutor.displayName('en'),
      about: pick(tutor.about, 'en'),
      lessonTitle: widget.lessonTitle,
      notes: widget.notes,
      tone: appState.tone,
      childName: appState.childName,
      progress: progressFacts(appState, contentStore.bundle, lang),
      history: [for (final t in _chat) [t[0], t[1]]],
    );
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _answer = reply.text;
      _chat.add([q, reply.text]);
      _heard = '';
    });
    if (appState.voiceOn && appSpeaker != null) {
      // Speak, then (in a live talk) listen again as soon as the tutor has finished.
      appSpeaker!.speaking.removeListener(_spoken);
      appSpeaker!.speaking.addListener(_spoken);
      appSpeaker!.say([reply.text], lang, tutor);
    } else if (_live) {
      _listen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + inset),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: cloud, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 10),
        Row(children: [
          ValueListenableBuilder<bool>(
            valueListenable: _talk?.speaking ?? appSpeaker?.speaking ?? ValueNotifier(false),
            // Tap the tutor to stop it talking, so the child can speak.
            builder: (_, speaking, __) => GestureDetector(
              onTap: speaking ? () => _talk?.hush() : null,
              child: TutorAvatar(
                tutor: tutor,
                size: 76,
                talking: speaking,
                mouthLevel: _talk?.mouth ?? appSpeaker?.mouth,
                mood: _thinking ? Mood.caring : Mood.happy,
                gaze: _listening || (_talk?.isLive ?? false) ? Offset.zero : const Offset(0.6, 0.6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _starting
                  ? tr('liveConnecting', lang)
                  : _talk != null
                      ? (_talk!.isLive
                          ? (_talk!.speaking.value
                              ? tr('liveTalking', lang).replaceAll('{name}', tutor.displayName(lang))
                              : tr('askListening', lang))
                          : tr('liveEnded', lang))
                      : _thinking
                          ? tr('askThinking', lang)
                          : _listening
                              ? tr('askListening', lang)
                              : tr('askPrompt', lang).replaceAll('{name}', tutor.displayName(lang)),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
          // Live talk: a red End button, like a call. Tapping it stops listening and speaking.
          if (_live && (_talk == null || _talk!.isLive))
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: coral, shape: const StadiumBorder()),
                onPressed: _end,
                icon: const Icon(Icons.call_end_rounded, size: 20),
                label: Text(tr('endTalk', lang)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.32),
          child: ListView(shrinkWrap: true, reverse: true, children: [
            if (_talk != null)
              for (final line in _talk!.lines.reversed) _bubble(line.text.trim(), mine: line.fromChild)
            else ...[
              if (_heard.isNotEmpty) _bubble(_heard, mine: true, faint: true),
              for (final turn in _chat.reversed) ...[
                _bubble(turn[1], mine: false),
                _bubble(turn[0], mine: true),
              ],
            ],
          ]),
        ),
        if (_micMissing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr('askNoMic', lang), style: const TextStyle(color: Color(0xFF6B6F80))),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: tr('askType', lang),
                filled: true,
                fillColor: violetSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _talk != null
                ? () {
                    if (_text.text.trim().isNotEmpty) {
                      _send(_text.text);
                    } else if (!_talk!.isLive) {
                      // talk again: a fresh live talk
                      _talk!.removeListener(_liveChanged);
                      _talk!.dispose();
                      setState(() {
                        _talk = null;
                        _starting = true;
                        _live = true;
                      });
                      _startLive();
                    }
                  }
                : _listening
                ? () => _stt.stop()
                : (_text.text.trim().isNotEmpty
                    ? () => _send(_text.text)
                    : () {
                        appSpeaker?.stop(); // the child may interrupt the tutor
                        setState(() => _live = true);
                        _listen();
                      }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _listening ? coral : violet,
                shape: BoxShape.circle,
                boxShadow: [if (_listening) BoxShadow(color: coral.withAlpha(110), blurRadius: 18, spreadRadius: 4)],
              ),
              child: _thinking
                  ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 32),
            ),
          ),
        ]),
        if (_answer.isNotEmpty) const SizedBox(height: 2),
      ]),
    );
  }

  Widget _bubble(String text, {required bool mine, bool faint = false}) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: mine ? (faint ? violetSoft : violet) : const Color(0xFFF3F0FA),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(text,
              style: TextStyle(fontSize: 16, height: 1.35, color: mine && !faint ? Colors.white : ink, fontWeight: FontWeight.w600)),
        ),
      );
}
