// The classroom: the tutor runs the lesson, the child answers.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../content.dart';
import '../brain.dart';
import '../reminders.dart';
import '../state.dart';
import '../strings.dart';
import '../tutor.dart';
import '../voice.dart';
import '../widgets/activities.dart';
import '../widgets/ask_sheet.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import '../widgets/visuals.dart';

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key, required this.subject, required this.lesson});
  final Subject subject;
  final Lesson lesson;

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> with WidgetsBindingObserver {
  late final TutorDirector d;
  final Stopwatch _watch = Stopwatch()..start();
  String _typed = '';
  List<int> _beads = [0, 0, 0];
  LessonStep? _shownQuestion;
  bool _closed = false;
  Spot _lastSpot = Spot.left;
  Offset? _walkLook; // eyes lead the way while the tutor is moving
  Timer? _walkTimer;
  Timer? _peekTimer;
  bool _peek = false; // while teaching, glance from the board back to the child
  int _hop = 0; // the tutor hops each time the lesson moves on
  bool _explaining = false; // waiting for the tutor brain to explain more
  LessonStep? _lastStep;

  @override
  void initState() {
    super.initState();
    d = TutorDirector(
      lesson: widget.lesson,
      lang: appState.mainLang,
      tutor: tutorById(appState.tutorId),
      recordFor: appState.concept,
      day: dayNumber(),
      phrases: contentStore.bundle.phrases,
      pickStyle: appState.pickStyle,
      onStyleResult: appState.recordStyle,
      speaker: appState.voiceOn ? appSpeaker : null,
    );
    _lastSpot = d.spot;
    if (appState.voiceOn) appSpeaker?.prefetch(d.allLines, d.lang, d.tutor);
    _lastStep = d.current;
    d.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    _peekTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && d.look == Look.board && d.phase == Phase.talking) setState(() => _peek = !_peek);
    });
  }

  /// Where the tutor's eyes should point right now.
  Offset get _gaze {
    if (_walkLook != null) return _walkLook!;
    final towardCentre = switch (d.spot) { Spot.left => 0.55, Spot.center => 0.0, Spot.right => -0.55 };
    switch (d.look) {
      case Look.board:
        return _peek ? Offset.zero : Offset(towardCentre, -0.9);
      case Look.answers:
        return Offset(towardCentre * 0.8, 0.9);
      case Look.child:
        return Offset.zero;
    }
  }

  /// Leaving the app halfway through a level: the tutor calls the child back later.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && d.phase != Phase.finished) {
      appSpeaker?.stop();
      remindLeftLevel(appState, contentStore.bundle);
    } else if (state == AppLifecycleState.resumed) {
      cancelLeftLevel();
    }
  }

  /// What this lesson teaches, for the tutor brain when the child asks a question.
  String get _notes => [
        for (final s in widget.lesson.steps)
          if (!s.isAsk) pick(s.text, 'en')
      ].join(' ');

  void _onChange() {
    _peek = false;
    if (!identical(d.current, _lastStep)) {
      _lastStep = d.current;
      _hop++;
    }
    if (!identical(d.question, _shownQuestion)) {
      _shownQuestion = d.question;
      _beads = [0, 0, 0];
      _typed = '';
    }
    if (d.spot != _lastSpot) {
      final dir = d.spot.index > _lastSpot.index ? 1.0 : -1.0;
      _lastSpot = d.spot;
      _walkLook = Offset(dir, 0.1);
      _walkTimer?.cancel();
      _walkTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _walkLook = null);
      });
    }
    if (d.phase == Phase.finished && !_closed) {
      _closed = true;
      _logTime();
      final newDay = appState.finishLesson(widget.lesson.id, d.starsEarned, d.xpEarned);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => CelebrationScreen(stars: d.starsEarned, xp: d.xpEarned, newDay: newDay)));
      });
    }
  }

  void _logTime() {
    final secs = _watch.elapsed.inSeconds.clamp(0, 20 * 60).toInt();
    _watch
      ..stop()
      ..reset();
    appState.addLearningTime(secs);
  }

  @override
  void dispose() {
    if (!_closed) {
      _logTime();
      appState.save(); // keep what was learned even if the lesson was left early
    }
    WidgetsBinding.instance.removeObserver(this);
    cancelLeftLevel();
    _walkTimer?.cancel();
    _peekTimer?.cancel();
    d.removeListener(_onChange);
    d.dispose();
    super.dispose();
  }

  void _submitNumber() {
    if (_typed.isEmpty) return;
    final v = _typed;
    setState(() => _typed = '');
    d.answer(v);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final lang = d.lang;
        final step = d.current;
        final other = lang == 'ml' ? 'en' : 'ml';
        String second = '';
        if (appState.bilingual && step != null && step.text is Map && (step.text as Map).containsKey(other)) {
          second = '${(step.text as Map)[other]}';
        }
        return Scaffold(
          backgroundColor: Color.lerp(cream, Color(widget.subject.color), 0.07),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 30, color: ink)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: d.progress),
                            duration: const Duration(milliseconds: 400),
                            builder: (_, v, __) =>
                                LinearProgressIndicator(value: v, minHeight: 14, backgroundColor: cloud, color: mint),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: violet),
                        tooltip: tr('ask', lang),
                        onPressed: () => openAskSheet(context, lessonTitle: pick(widget.lesson.title, 'en'), notes: _notes),
                        icon: const Icon(Icons.mic_rounded, color: Colors.white),
                      ),
                    ]),
                    // The board: what the tutor is showing.
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(child: _board()),
                      ),
                    ),
                    // The tutor walks to wherever the action is.
                    SizedBox(
                      height: 92,
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutBack,
                        alignment: switch (d.spot) {
                          Spot.left => Alignment.centerLeft,
                          Spot.center => Alignment.center,
                          Spot.right => Alignment.centerRight,
                        },
                        child: ValueListenableBuilder<bool>(
                          valueListenable: d.speaker?.speaking ?? const AlwaysStoppedAnimation(false),
                          builder: (_, speaking, __) => TweenAnimationBuilder<double>(
                            key: ValueKey(_hop),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 550),
                            builder: (_, v, child) => Transform.translate(
                              offset: Offset(0, -sin(v * pi) * 22),
                              child: Transform.scale(scaleY: 1 - sin(v * pi * 2).abs() * 0.06, child: child),
                            ),
                            child: tutorHero(
                                TutorAvatar(tutor: d.tutor, size: 88, talking: speaking, mood: d.mood, gaze: _gaze)),
                          ),
                        ),
                      ),
                    ),
                    // Speech bubble
                    Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: d.mood == Mood.happy ? mint : (d.mood == Mood.caring ? sun : cloud), width: 3),
                      ),
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (d.badge.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(color: sun, borderRadius: BorderRadius.circular(10)),
                              child: Text(d.badge, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ink)),
                            ),
                          // Keep the question in view while the tutor gives a hint.
                          if (d.phase == Phase.asking && d.question != null && !d.bubble.endsWith(pick(d.question!.text, lang)))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(pick(d.question!.text, lang),
                                  style: const TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w800, color: indigo)),
                            ),
                          Text(d.bubble,
                              style: const TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: ink)),
                          if (second.isNotEmpty && (d.phase == Phase.talking || d.phase == Phase.asking || d.phase == Phase.thinkAsk))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(second, style: const TextStyle(fontSize: 15, height: 1.3, color: Color(0xFF6B6F80))),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _controls(lang),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The board: a picture the tutor shows, or something for the child to touch.
  Widget _board() {
    final q = d.question;
    if (q != null && d.phase == Phase.asking) {
      if (q.form == 'abacus') return AbacusPad(values: _beads, onChanged: (v) => setState(() => _beads = v));
      if (q.form == 'measure') {
        final args = (q.visual?['args'] as List?) ?? const [];
        return ScaleBoard(
          key: ObjectKey(q),
          length: int.tryParse('${args.isEmpty ? 5 : args.first}') ?? 5,
          emoji: args.length > 1 ? '${args[1]}' : '',
        );
      }
      if (q.form == 'build') {
        return StickBuilder(key: ObjectKey(q), options: q.options, disabled: d.wrongOptions, onBuilt: d.answer);
      }
    }
    var v = d.visual;
    if (q != null && d.phase == Phase.feedback) {
      // after a touch activity, show what the right answer looks like
      if (q.form == 'abacus') {
        final n = int.tryParse(q.answer) ?? 0;
        v = {'kind': 'place', 'args': [n ~/ 100, (n ~/ 10) % 10, n % 10]};
      } else if (q.form == 'build') {
        v = {'kind': 'shapes', 'args': [q.answer]};
      }
    }
    if (v == null) return Text(widget.subject.icon, style: const TextStyle(fontSize: 64));
    return SoftCard(key: ValueKey(v.toString()), child: VisualView(v));
  }

  /// "Explain more": the tutor brain explains the current step again, another way.
  Future<void> _explainMore() async {
    final step = d.current;
    if (step == null || _explaining) return;
    setState(() => _explaining = true);
    final lang = d.lang;
    final what = pick(step.text, lang);
    final reply = await askBrain(
      bundle: contentStore.bundle,
      question: lang == 'ml'
          ? 'ഇത് എനിക്ക് മനസ്സിലായില്ല. ഒരു ദിവസേനയുള്ള ഉദാഹരണത്തോടെ, മറ്റൊരു രീതിയിൽ ലളിതമായി പറഞ്ഞു തരാമോ? "$what"'
          : 'I did not understand this. Please explain it again in a different, simple way with an everyday example: "$what"',
      lang: lang,
      tutorName: d.tutor.displayName('en'),
      lessonTitle: pick(widget.lesson.title, 'en'),
      notes: _notes,
    );
    if (!mounted) return;
    setState(() => _explaining = false);
    d.tutorSays(reply.text);
  }

  Widget _tip(String key, String lang) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(tr(key, lang),
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B6F80), fontWeight: FontWeight.w600)),
      );

  Widget _controls(String lang) {
    final q = d.question;
    switch (d.phase) {
      case Phase.talking:
        return Row(children: [
          Expanded(
            child: Chunky(
              color: Colors.white,
              onTap: _explaining ? null : _explainMore,
              child: _explaining
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: violet))
                  : Text('🤔 ${tr('explainMore', lang)}', style: const TextStyle(color: ink, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Chunky(color: indigo, onTap: d.next, child: Text('${tr('next', lang)}  ▶'))),
        ]);
      case Phase.feedback:
        return Chunky(color: mint, onTap: d.next, child: Text(tr('continue', lang)));
      case Phase.thinkAsk:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('think', lang), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B6F80))),
          const SizedBox(height: 8),
          Chunky(color: indigo, onTap: d.revealThink, child: Text(tr('showAnswer', lang))),
        ]);
      case Phase.thinkReveal:
        return Row(children: [
          Expanded(child: Chunky(color: sun, onTap: () => d.rateThink(false), child: Text('🤔 ${tr('notYet', lang)}', style: const TextStyle(color: ink)))),
          const SizedBox(width: 12),
          Expanded(child: Chunky(color: mint, onTap: () => d.rateThink(true), child: Text('👍 ${tr('gotIt', lang)}'))),
        ]);
      case Phase.finished:
        return const SizedBox(height: 52);
      case Phase.asking:
        final hint = d.canHint
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Chunky(color: Colors.white, onTap: d.showHint, child: Text('💡 ${tr('hint', lang)}', style: const TextStyle(color: ink))),
              )
            : const SizedBox.shrink();
        if (q != null && q.form == 'build') {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _tip('dragSticks', lang),
            hint,
          ]);
        }
        if (q != null && q.form == 'abacus') {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _tip('moveBeads', lang),
            Chunky(
              color: mint,
              onTap: () => d.answer('${_beads[0] * 100 + _beads[1] * 10 + _beads[2]}'),
              child: Text('${tr('check', lang)} ✓'),
            ),
            hint,
          ]);
        }
        if (q != null && q.form == 'choice') {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chunky(
                  color: Colors.white,
                  onTap: d.wrongOptions.contains(q.options[i]) ? null : () => d.answer(q.options[i]),
                  child: Text(q.optionLabel(i, lang),
                      style: TextStyle(
                          fontSize: 20, color: d.wrongOptions.contains(q.options[i]) ? const Color(0xFF9A948A) : ink)),
                ),
              ),
            hint,
          ]);
        }
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (q != null && q.form == 'measure') _tip('slideScale', lang),
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: indigo, width: 3)),
            child: Text(_typed.isEmpty ? '?' : _typed,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _typed.isEmpty ? cloud : ink)),
          ),
          const SizedBox(height: 8),
          for (final row in const [
            ['1', '2', '3', '4', '5'],
            ['6', '7', '8', '9', '0'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Chunky(
                        color: Colors.white,
                        radius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        onTap: () => setState(() {
                          if (_typed.length < 4) _typed += k;
                        }),
                        child: Text(k, style: const TextStyle(fontSize: 22, color: ink)),
                      ),
                    ),
                  ),
              ]),
            ),
          Row(children: [
            Expanded(
              child: Chunky(
                color: Colors.white,
                onTap: _typed.isEmpty ? null : () => setState(() => _typed = _typed.substring(0, _typed.length - 1)),
                child: const Text('⌫', style: TextStyle(color: ink)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Chunky(color: mint, onTap: _typed.isEmpty ? null : _submitNumber, child: Text('${tr('check', lang)} ✓')),
            ),
          ]),
          hint,
        ]);
    }
  }
}

class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({super.key, required this.stars, required this.xp, required this.newDay});
  final int stars;
  final int xp;
  final bool newDay;

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen> {
  int get stars => widget.stars;
  int get xp => widget.xp;
  bool get newDay => widget.newDay;

  @override
  void initState() {
    super.initState();
    if (appState.voiceOn) {
      final t = tutorById(appState.tutorId);
      appSpeaker?.say([pick(t.cheer, appState.mainLang)], appState.mainLang, t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = appState.mainLang;
    final tutor = tutorById(appState.tutorId);
    return Scaffold(
      backgroundColor: violetSoft,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: tutorHero(TutorAvatar(tutor: tutor, size: 160, mood: Mood.happy))),
                const SizedBox(height: 16),
                Text(tr('lessonDone', lang),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 3; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 500 + i * 300),
                      curve: Curves.elasticOut,
                      builder: (_, v, __) => Transform.scale(
                        scale: v,
                        child: Text(i < stars ? '⭐' : '☆',
                            style: TextStyle(fontSize: 56, color: i < stars ? null : const Color(0xFFC9A94A))),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Pill('⚡', '+$xp XP'),
                  if (newDay) ...[const SizedBox(width: 8), Pill('🔥', '${appState.streak} ${tr('dayStreak', lang)}')],
                ]),
                const SizedBox(height: 32),
                Chunky(color: mint, onTap: () => Navigator.of(context).pop(), child: Text(tr('continue', lang))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
