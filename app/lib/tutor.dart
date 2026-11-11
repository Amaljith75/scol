// The Director lets the tutor run a lesson: talk, move, show pictures, ask,
// check, and teach again. The screens only draw what the Director decides.
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'content.dart';
import 'mastery.dart';
import 'strings.dart';
import 'voice.dart';

enum Phase { talking, asking, feedback, thinkAsk, thinkReveal, finished }

enum Spot { left, center, right }

enum Mood { calm, happy, caring }

/// Where the tutor's eyes should rest.
enum Look { child, board, answers }

class _Item {
  _Item(this.step, {this.retry = false});
  final LessonStep step;
  final bool retry; // a question the tutor brought back because it was missed
}

/// Runs one lesson. Today the Director follows the written lesson and adapts
/// with simple rules; a live AI model can later drive the very same controls
/// (say / show / ask / move / look) without changing the screens.
class TutorDirector extends ChangeNotifier {
  TutorDirector({
    required this.lesson,
    required this.lang,
    required this.tutor,
    required this.recordFor,
    required this.day,
    this.phrases = const {},
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
  final Map<String, dynamic> phrases;
  final Speaker? speaker;
  final Random _rnd;

  late List<_Item> _queue;
  late int _total;
  int _index = 0;

  // What the screen should show right now.
  Phase phase = Phase.talking;
  Spot spot = Spot.left;
  Mood mood = Mood.calm;
  Look look = Look.child;
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

  String _ph(String key) {
    final p = pick(phrases[key], lang);
    return p.isNotEmpty ? p : tr(key, lang);
  }

  /// Every line this lesson might speak, so the sound can be fetched early.
  List<String> get allLines => [
        for (final s in lesson.steps) ...[pick(s.text, lang), pick(s.hint, lang), pick(s.explain, lang)],
        ...tutor.praiseList(lang),
        pick(tutor.oops, lang),
        _ph('lookAgain'),
        _ph('tryLater'),
        _ph('again'),
      ];

  void _say(List<String> parts) {
    final said = parts.where((p) => p.isNotEmpty).toList();
    bubble = said.join(' ');
    speaker?.say(said, lang, tutor);
  }

  void _enter() {
    if (_index >= _queue.length) {
      phase = Phase.finished;
      question = null;
      mood = Mood.happy;
      spot = Spot.center;
      look = Look.child;
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
      look = visual == null ? Look.child : Look.board;
      _say([text]);
    } else {
      question = step;
      phase = step.form == 'think' ? Phase.thinkAsk : Phase.asking;
      spot = Spot.right;
      look = Look.answers;
      _askedAt = DateTime.now();
      _say(item.retry ? [_ph('again'), text] : [text]);
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
    look = Look.board;
    _say([pick(question!.hint, lang)]);
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
      look = Look.child;
      final praise = tutor.praiseList(lang);
      final explain = pick(q.explain, lang);
      _say(clean || explain.isEmpty ? [praise[_rnd.nextInt(praise.length)]] : [praise.first, explain]);
    } else {
      _attempts++;
      wrongOptions.add(given);
      final note = q.mistakes[given];
      if (note != null) _mistakes.add(note);
      mood = Mood.caring;
      final oops = pick(tutor.oops, lang);
      if (_attempts == 1) {
        // First miss: never give the answer away. Give a hint and let them retry.
        final hint = pick(q.hint, lang);
        hintShown = true;
        look = Look.board;
        _say([oops, hint.isEmpty ? _ph('lookAgain') : hint]);
      } else {
        // Second miss: explain kindly, then bring the question back later.
        _finishQuestion('failed', millis);
        look = Look.child;
        final explain = pick(q.explain, lang);
        final shown = q.options.contains(q.answer) ? q.optionLabel(q.options.indexOf(q.answer), lang) : q.answer;
        final body = explain.isEmpty ? '${tr('answerIs', lang)} $shown.' : explain;
        final already = _queue.skip(_index + 1).any((i) => i.retry && identical(i.step, q));
        if (!_queue[_index].retry && !already) {
          _queue.add(_Item(q, retry: true));
          _total = _queue.length;
          _say([body, _ph('tryLater')]);
        } else {
          _say([body]);
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
    look = Look.child;
    _say([question!.answer]);
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
