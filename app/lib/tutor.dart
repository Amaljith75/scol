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
  _Item(this.step, {this.retry = false, this.style});
  final LessonStep step;
  final bool retry; // a question the tutor brought back because it was missed
  final String? style; // 'story' or 'picture': the other way it was just explained
}

/// Runs one lesson. The Director follows the written lesson and adapts with
/// simple rules (hint first, explain second, re-ask later). When the tutor
/// brain has written out the lesson in the tutor's own words ([setTeaching]),
/// the Director speaks that at each teaching step instead of reading the line;
/// questions, hints and explanations stay exactly as written.
class TutorDirector extends ChangeNotifier {
  TutorDirector({
    required this.lesson,
    required this.lang,
    this.tone = 'normal',
    required this.tutor,
    required this.recordFor,
    required this.day,
    this.phrases = const {},
    this.speaker,
    this.pickStyle,
    this.onStyleResult,
    bool waitForTeaching = false,
    Random? random,
  })  : _rnd = random ?? Random(),
        _hold = waitForTeaching {
    _queue = [for (final s in lesson.steps) _Item(s)];
    _total = _queue.length;
    _enter();
  }

  final Lesson lesson;
  String lang; // can change in the middle of a lesson
  final String tone;
  final TutorCharacter tutor;
  final ConceptRecord Function(String concept) recordFor;
  final int day;
  final Map<String, dynamic> phrases;
  final Speaker? speaker;

  /// Chooses which other way of explaining to try for this child.
  final String Function(List<String> available)? pickStyle;

  /// Told whether that other way worked (the child then got the question right).
  final void Function(String style, bool worked)? onStyleResult;
  final Random _rnd;
  final Set<String> _usedStyles = {};
  bool _styleReported = false;

  late List<_Item> _queue;
  late int _total;
  int _index = 0;

  /// What the brain wrote for each step of [lesson] (null for questions), or null: read the lines as written.
  List<String?>? _teaching;

  /// True while the first line is shown but not yet spoken, because the brain's words are on their way.
  bool _hold;

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

  /// The brain's words for [step], if it wrote any.
  String? _taught(LessonStep step) {
    final t = _teaching;
    if (t == null) return null;
    final i = lesson.steps.indexWhere((s) => identical(s, step));
    return i >= 0 && i < t.length ? t[i] : null;
  }

  /// True when what the tutor is saying now was written by the brain, not read from the lesson.
  bool get taughtByBrain => phase == Phase.talking && current != null && _taught(current!) != null;

  /// The lesson's own line for the current step, so it can be shown under the tutor's words.
  String get lessonLine => current == null ? '' : pick(current!.text, lang);

  /// The brain has written the lesson out in the tutor's own words (or null: it could not).
  /// Steps not reached yet use these words; if the tutor is still on a teaching step, it says it again this way.
  void setTeaching(List<String?>? perStep) {
    _teaching = perStep != null && perStep.length == lesson.steps.length ? perStep : null;
    final again = _hold || (phase == Phase.talking && _teaching != null);
    _hold = false;
    if (again) {
      _enter();
    } else {
      notifyListeners();
    }
  }

  /// The brain's words did not come in time: speak the first line as written.
  void stopWaiting() {
    if (!_hold) return;
    _hold = false;
    if (phase == Phase.talking || phase == Phase.asking || phase == Phase.thinkAsk) _enter();
  }
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
        ...?_teaching?.whereType<String>(),
        for (final s in lesson.steps) ...[pick(s.text, lang), pick(s.hint, lang), pick(s.explain, lang)],
        for (final a in lesson.alts.values) pick(a.text, lang),
        ..._praise,
        _oops,
        _ph('anotherWay'),
        _ph('lookAgain'),
        _ph('tryLater'),
        _ph('again'),
      ];

  List<String> get _praise => tone == 'strict' ? [_ph('praiseStrict')] : tutor.praiseList(lang);
  String get _oops => tone == 'strict' ? _ph('oopsStrict') : pick(tutor.oops, lang);

  /// The child switched language: say the current step again in the new language.
  void setLang(String l) {
    if (l == lang) return;
    lang = l;
    _teaching = null; // the brain's words were in the old language; the classroom asks for new ones
    if (phase == Phase.talking || phase == Phase.asking || phase == Phase.thinkAsk) {
      _enter();
    } else {
      notifyListeners();
    }
  }

  void _say(List<String> parts) {
    final said = parts.where((p) => p.isNotEmpty).toList();
    bubble = said.join(' ');
    if (!_hold) speaker?.say(said, lang, tutor);
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
    _styleReported = false;
    badge = const ['example', 'story', 'picture'].contains(step.label) ? tr(step.label, lang) : '';
    final text = pick(step.text, lang);
    if (!step.isAsk) {
      question = null;
      phase = Phase.talking;
      spot = visual == null ? Spot.center : (_index.isEven ? Spot.left : Spot.right);
      look = visual == null ? Look.child : Look.board;
      _say([_taught(step) ?? text]);
    } else {
      _hold = false; // a question is always asked at once, as written
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

  /// The tutor explains something extra (for example from the tutor brain) and stays on this step.
  void tutorSays(String text) {
    if (text.trim().isEmpty) return;
    mood = Mood.happy;
    look = Look.child;
    badge = '';
    _say([text]);
    notifyListeners();
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
    final style = _queue[_index].style;
    if (style != null && !_styleReported) {
      // Did explaining it the other way work? Remember that for this child.
      _styleReported = true;
      onStyleResult?.call(style, q.isCorrect(given) && _attempts == 0);
    }
    if (q.isCorrect(given)) {
      final clean = _attempts == 0 && !hintShown && !_queue[_index].retry;
      _finishQuestion(clean ? 'first' : 'help', millis);
      mood = Mood.happy;
      look = Look.child;
      final praise = _praise;
      final explain = pick(q.explain, lang);
      _say(clean || explain.isEmpty ? [praise[_rnd.nextInt(praise.length)]] : [praise.first, explain]);
    } else {
      _attempts++;
      wrongOptions.add(given);
      final note = q.mistakes[given];
      if (note != null) _mistakes.add(note);
      mood = Mood.caring;
      final oops = _oops;
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
        final left = lesson.alts.keys.where((k) => !_usedStyles.contains(k)).toList();
        if (!_queue[_index].retry && !already && left.isNotEmpty) {
          // Explain it another way (a story or a picture), then ask again straight away.
          final mode = pickStyle?.call(left) ?? left.first;
          final chosen = left.contains(mode) ? mode : left.first;
          _usedStyles.add(chosen);
          _queue.insertAll(_index + 1, [_Item(lesson.alts[chosen]!), _Item(q, retry: true, style: chosen)]);
          _total = _queue.length;
          _say([body, _ph('anotherWay')]);
        } else if (!_queue[_index].retry && !already) {
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
