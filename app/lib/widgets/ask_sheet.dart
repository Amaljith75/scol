// The "Ask Mio" sheet: hold a conversation by voice, or type.
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../brain.dart';
import '../content.dart';
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
  final List<List<String>> _chat = []; // [question, answer]

  String get lang => appState.mainLang;
  TutorCharacter get tutor => tutorById(appState.tutorId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _text.dispose();
    if (_listening) _stt.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_thinking) return;
    appSpeaker?.stop();
    try {
      if (!_sttReady) _sttReady = await _stt.initialize(onError: (_) => _stopped(), onStatus: (s) {
        if (s == 'done' || s == 'notListening') _stopped();
      });
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
      localeId: lang == 'ml' ? 'ml_IN' : 'en_IN',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
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
      lessonTitle: widget.lessonTitle,
      notes: widget.notes,
    );
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _answer = reply.text;
      _chat.add([q, reply.text]);
      _heard = '';
    });
    if (appState.voiceOn) appSpeaker?.say([reply.text], lang, tutor);
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
            valueListenable: appSpeaker?.speaking ?? ValueNotifier(false),
            builder: (_, speaking, __) => TutorAvatar(
              tutor: tutor,
              size: 76,
              talking: speaking,
              mood: _thinking ? Mood.caring : Mood.happy,
              gaze: _listening ? Offset.zero : const Offset(0.6, 0.6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _thinking
                  ? tr('askThinking', lang)
                  : _listening
                      ? tr('askListening', lang)
                      : tr('askPrompt', lang).replaceAll('{name}', tutor.displayName(lang)),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.32),
          child: ListView(shrinkWrap: true, reverse: true, children: [
            if (_heard.isNotEmpty) _bubble(_heard, mine: true, faint: true),
            for (final turn in _chat.reversed) ...[
              _bubble(turn[1], mine: false),
              _bubble(turn[0], mine: true),
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
            onTap: _listening ? () => _stt.stop() : (_text.text.trim().isNotEmpty ? () => _send(_text.text) : _listen),
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
