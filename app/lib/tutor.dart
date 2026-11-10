// The tutor: who they are, how they speak, and the Director that lets the
// tutor run a lesson (talk, move, show pictures, ask, check, re-teach).
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'content.dart';
import 'mastery.dart';
import 'strings.dart';

class TutorCharacter {
  const TutorCharacter(this.id, this.name, this.nameMl, this.color, this.about, this.aboutMl, this.praise,
      this.praiseMl, this.oops, this.oopsMl);
  final String id;
  final String name;
  final String nameMl;
  final int color;
  final String about;
  final String aboutMl;
  final List<String> praise;
  final List<String> praiseMl;
  final String oops;
  final String oopsMl;

  String displayName(String lang) => lang == 'ml' ? nameMl : name;
}

const tutors = <TutorCharacter>[
  TutorCharacter(
    'minnu', 'Minnu', 'മിന്നു', 0xFFFFB81F,
    'A gentle firefly who loves stories', 'കഥകൾ ഇഷ്ടപ്പെടുന്ന ഒരു മിന്നാമിനുങ്ങ്',
    ['Lovely! ✨', 'You shine! 🌟', 'Beautifully done!'],
    ['വളരെ നന്നായി! ✨', 'നീ തിളങ്ങുന്നു! 🌟', 'അടിപൊളി!'],
    'Not yet, and that is okay.', 'സാരമില്ല, ഒന്നുകൂടി നോക്കാം.',
  ),
  TutorCharacter(
    'tiko', 'Tiko', 'ടിക്കോ', 0xFF19B5A5,
    'A playful robot who loves puzzles', 'കളികൾ ഇഷ്ടപ്പെടുന്ന ഒരു റോബോട്ട്',
    ['Beep boop, correct! 🤖', 'High five! 🙌', 'Zap! You got it! ⚡'],
    ['ബീപ് ബൂപ്, ശരിയാണ്! 🤖', 'സൂപ്പർ! 🙌', 'കലക്കി! ⚡'],
    'Oops! Let us work it out together.', 'അയ്യോ! നമുക്ക് ഒരുമിച്ച് കണ്ടുപിടിക്കാം.',
  ),
];

TutorCharacter tutorById(String id) => tutors.firstWhere((t) => t.id == id, orElse: () => tutors.first);

// ---------------- Voice ----------------

/// The device voice, set up once when the app starts.
Speaker? appSpeaker;

abstract class Speaker {
  Future<void> say(String text, String lang);
  void stop();
}

class TtsSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  static final _noise = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2190}-\u{21FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]',
      unicode: true);

  @override
  Future<void> say(String text, String lang) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(lang == 'ml' ? 'ml-IN' : 'en-IN');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.15);
      await _tts.speak(text.replaceAll(_noise, ' ').replaceAll('×', lang == 'ml' ? ' ഗുണം ' : ' times '));
    } catch (_) {
      // No voice on this device: the lesson still works with text.
    }
  }

  @override
  void stop() {
    _tts.stop().catchError((_) {});
  }
}

// ---------------- Director ----------------

enum Phase { talking, asking, feedback, thinkAsk, thinkReveal, finished }

enum Spot { left, center, right }

enum Mood { calm, happy, caring }

class _Item {
  _Item(this.step, {this.retry = false});
  final LessonStep step;
  final bool retry; // a question the tutor brought back because it was missed
}

/// Runs one lesson. The screen only draws what the Director says and passes
/// the child's taps back in. Today the Director follows the written lesson and
/// adapts with simple rules; a live AI model can later drive the very same
/// controls (say / show / ask / move) without changing the screens.
class TutorDirector extends ChangeNotifier {
  TutorDirector({
    required this.lesson,
    required this.lang,
    required this.tutor,
    required this.recordFor,
    required this.day,
    this.speaker,
    Random? random,
  }) : _rnd = random ?? Random() {
    _queue = [for (final s in lesson.steps) _Item(s)];
    _total = _queue.length;
    _enter();
  }

  final Lesson lesson;
  final String lang;
  final TutorCharacter tutor;
  final ConceptRecord Function(String concept) recordFor;
  final int day;
  final Speaker? speaker;
  final Random _rnd;

  late List<_Item> _queue;
  late int _total;
  int _index = 0;

  // What the screen should show right now.
  Phase phase = Phase.talking;
  Spot spot = Spot.left;
  Mood mood = Mood.calm;
  String bubble = '';
  String badge = '';
  Map<String, dynamic>? visual;
  LessonStep? question;
  final Set<String> wrongOptions = {};
  bool hintShown = false;

  // Score for this lesson.
  int questions = 0;
  int firstTryRight = 0;
  int _attempts = 0;
  final List<String> _mistakes = [];
  DateTime _askedAt = DateTime.now();

  LessonStep? get current => _index < _queue.length ? _queue[_index].step : null;

  double get progress => _total == 0 ? 1 : (_index / _total).clamp(0.0, 1.0).toDouble();
  bool get canHint => phase == Phase.asking && !hintShown && pick(question?.hint, lang).isNotEmpty;

  int get starsEarned {
    if (questions == 0) return 3;
    final share = firstTryRight / questions;
    return share >= 0.99 ? 3 : (share >= 0.6 ? 2 : 1);
  }

  int get xpEarned => 10 + 5 * firstTryRight;

  void _say(String text) {
    bubble = text;
    speaker?.say(text, lang);
  }

  void _enter() {
    if (_index >= _queue.length) {
      phase = Phase.finished;
      question = null;
      mood = Mood.happy;
      spot = Spot.center;
      speaker?.stop();
      notifyListeners();
      return;
    }
    final item = _queue[_index];
    final step = item.step;
    visual = step.visual;
    wrongOptions.clear();
    hintShown = false;
    _attempts = 0;
    _mistakes.clear();
    mood = Mood.calm;
    badge = step.label == 'example' ? tr('example', lang) : '';
    final text = pick(step.text, lang);
    if (!step.isAsk) {
      question = null;
      phase = Phase.talking;
      spot = visual == null ? Spot.center : (_index.isEven ? Spot.left : Spot.right);
      _say(text);
    } else {
      question = step;
      phase = step.form == 'think' ? Phase.thinkAsk : Phase.asking;
      spot = Spot.right;
      _askedAt = DateTime.now();
      _say(item.retry ? '${tr('again', lang)} $text' : text);
    }
    notifyListeners();
  }

  /// The child tapped Next / Continue.
  void next() {
    if (phase == Phase.talking || phase == Phase.feedback) {
      _index++;
      _enter();
    }
  }

  void showHint() {
    if (!canHint) return;
    hintShown = true;
    mood = Mood.caring;
    _say(pick(question!.hint, lang));
    notifyListeners();
  }

  /// The child gave an answer to a choice or number question.
  void answer(String given) {
    final q = question;
    if (q == null || phase != Phase.asking) return;
    final millis = DateTime.now().difference(_askedAt).inMilliseconds;
    if (q.isCorrect(given)) {
      final clean = _attempts == 0 && !hintShown && !_queue[_index].retry;
      _finishQuestion(clean ? 'first' : 'help', millis);
      mood = Mood.happy;
      final praise = (lang == 'ml' ? tutor.praiseMl : tutor.praise);
      final explain = pick(q.explain, lang);
      _say(clean || explain.isEmpty ? praise[_rnd.nextInt(praise.length)] : '${praise.first} $explain');
    } else {
      _attempts++;
      wrongOptions.add(given);
      final note = q.mistakes[given];
      if (note != null) _mistakes.add(note);
      mood = Mood.caring;
      final oops = lang == 'ml' ? tutor.oopsMl : tutor.oops;
      if (_attempts == 1) {
        // First miss: never give the answer away. Give a hint and let them retry.
        final hint = pick(q.hint, lang);
        hintShown = true;
        _say('$oops ${hint.isEmpty ? tr('lookAgain', lang) : hint}');
      } else {
        // Second miss: explain kindly, then bring the question back later.
        _finishQuestion('failed', millis);
        final explain = pick(q.explain, lang);
        final shown = q.options.contains(q.answer)
            ? q.optionLabel(q.options.indexOf(q.answer), lang)
            : q.answer;
        final body = explain.isEmpty ? '${tr('answerIs', lang)} $shown.' : explain;
        final already = _queue.skip(_index + 1).any((i) => i.retry && identical(i.step, q));
        if (!_queue[_index].retry && !already) {
          _queue.add(_Item(q, retry: true));
          _total = _queue.length;
          _say('$body ${tr('tryLater', lang)}');
        } else {
          _say(body);
        }
      }
    }
    notifyListeners();
  }

  void _finishQuestion(String outcome, int millis) {
    final q = question!;
    questions++;
    if (outcome == 'first') firstTryRight++;
    recordFor(q.concept).record(
      form: q.form,
      outcome: outcome,
      day: day,
      millis: millis,
      mistakeNotes: List.of(_mistakes),
    );
    phase = Phase.feedback;
  }

  /// Open "think" question: show the answer, then the child says how it went.
  void revealThink() {
    if (phase != Phase.thinkAsk) return;
    phase = Phase.thinkReveal;
    _say(question!.answer);
    notifyListeners();
  }

  void rateThink(bool gotIt) {
    if (phase != Phase.thinkReveal) return;
    recordFor(question!.concept).record(form: 'think', outcome: gotIt ? 'first' : 'failed', day: day);
    _index++;
    _enter();
  }

  @override
  void dispose() {
    speaker?.stop();
    super.dispose();
  }
}
