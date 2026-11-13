// Home: the tutor greets the child and chooses what to learn next.
import 'dart:math';

import 'package:flutter/material.dart';

import '../content.dart';
import '../mastery.dart';
import '../reminders.dart';
import '../state.dart';
import '../strings.dart';
import '../tutor.dart';
import '../updates.dart';
import '../voice.dart';
import '../widgets/ask_sheet.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'classroom.dart';
import 'parent.dart';
import 'path.dart';

class _Plan {
  _Plan(this.subject, this.lesson, this.isRevision);
  final Subject subject;
  final Lesson lesson;
  final bool isRevision;
}

/// The tutor's choice for "what next": weak ideas first, then new lessons,
/// taking turns between subjects.
_Plan? _tutorPlan(List<Subject> subjects) {
  for (final s in subjects) {
    final r = appState.revisionLesson(s);
    if (r != null) return _Plan(s, r, true);
  }
  final open = subjects.where((s) => appState.nextLesson(s) != null).toList();
  if (open.isEmpty) return null;
  final s = open[appState.todayLessons % open.length];
  return _Plan(s, appState.nextLesson(s)!, false);
}

Future<void> openLesson(BuildContext context, Subject subject, Lesson lesson) async {
  final lang = appState.mainLang;
  if (appState.timeUp) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('timeUp', lang))));
    return;
  }
  appSpeaker?.stop();
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClassroomScreen(subject: subject, lesson: lesson)));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _greet(first: true);
      planReminders(appState, contentStore.bundle);
      checkForAppUpdate(context);
    });
    _seenVersion = contentStore.bundle.version;
    contentStore.addListener(_lessonsChanged);
  }

  String _seenVersion = '';

  /// Lessons were updated online while the app was open: say so.
  void _lessonsChanged() {
    final v = contentStore.bundle.version;
    if (v == _seenVersion || !mounted) return;
    _seenVersion = v;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 ${tr('newLessons', appState.mainLang)}')));
  }

  @override
  void dispose() {
    contentStore.removeListener(_lessonsChanged);
    super.dispose();
  }

  /// The tutor says hello and tells the child what to do next.
  void _greet({bool first = false}) {
    if (!mounted || !appState.voiceOn) return;
    final lang = appState.mainLang;
    final b = contentStore.bundle;
    final tutor = tutorById(appState.tutorId);
    final subjects = appState.mySubjects(b);
    final plan = _tutorPlan(subjects);
    final parts = <String>[if (first) pick(tutor.hello, lang)];
    if (appState.timeUp) {
      parts.add(b.phrase('timeUp', lang));
    } else if (plan == null) {
      parts.add(b.phrase(subjects.any((s) => s.lessons.isNotEmpty) ? 'allDone' : 'comingSoon', lang));
    } else {
      parts.addAll([
        b.phrase('nextUp', lang),
        plan.isRevision ? b.phrase('practice', lang) : pick(plan.lesson.title, lang),
        b.phrase('tapGo', lang),
      ]);
    }
    appSpeaker?.say(parts, lang, tutor);
  }

  // Redraw whenever progress or lessons change (stars, streak, next level).
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([appState, contentStore]),
        builder: (context, _) => _page(context),
      );

  Widget _page(BuildContext context) {
    final lang = appState.mainLang;
    final tutor = tutorById(appState.tutorId);
    final subjects = appState.mySubjects(contentStore.bundle);
    final plan = _tutorPlan(subjects);
    final hasLessons = subjects.any((s) => s.lessons.isNotEmpty);

    String message;
    if (appState.timeUp) {
      message = tr('timeUp', lang);
    } else if (plan == null) {
      message = tr(hasLessons ? 'allDone' : 'comingSoon', lang);
    } else {
      final title = plan.isRevision ? tr('practice', lang) : pick(plan.lesson.title, lang);
      message = '${tr('nextUp', lang)}: $title';
    }

    Widget tab(String emoji, String label, bool active, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  decoration: BoxDecoration(
                      color: active ? violetSoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
                Text(label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: active ? violet : const Color(0xFF8A84A6))),
              ]),
            ),
          ),
        );

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: cloud, width: 2))),
        child: SafeArea(
          top: false,
          child: Row(children: [
            tab('🏠', tr('home', lang), true, () {}),
            tab('🎙️', tr('ask', lang), false, () => openAskSheet(context, lessonTitle: plan == null ? '' : pick(plan.lesson.title, 'en'))),
            tab('🏆', tr('rewards', lang), false, () => _showRewards(context)),
            tab('👪', tr('parents', lang), false, () {
              appSpeaker?.stop();
              openParentZone(context);
            }),
          ]),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(
                  child: Text('${tr('hi', lang)}, ${appState.childName}! 👋',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink)),
                ),
                Pill('🔥', '${appState.liveStreak}'),
                const SizedBox(width: 8),
                Pill('⭐', '${appState.stars}'),
              ]),
              const SizedBox(height: 16),
              // The tutor's plan for right now.
              SoftCard(
                color: violetSoft,
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    tutorHero(TutorAvatar(
                        tutor: tutor, size: 104, mood: Mood.happy, float: true, gaze: plan == null ? Offset.zero : const Offset(0.7, 0.75))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tutor.displayName(lang),
                              style: TextStyle(fontWeight: FontWeight.w800, color: darker(Color(tutor.color), 0.2))),
                          const SizedBox(height: 4),
                          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                          if (plan != null && !appState.timeUp)
                            Text('${plan.subject.icon} ${pick(plan.subject.name, lang)}',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF6B6F80))),
                        ]),
                      ),
                    ),
                  ]),
                  if (plan != null && !appState.timeUp) ...[
                    const SizedBox(height: 14),
                    Chunky(
                      color: violet,
                      onTap: () async {
                        await openLesson(context, plan.subject, plan.lesson);
                        _greet();
                        planReminders(appState, contentStore.bundle);
                      },
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(tr('go', lang), style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              // Daily goal
              SoftCard(
                child: Row(children: [
                  const Text('🎯', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${tr('todayGoal', lang)}: ${min(appState.todayLessons, appState.dailyGoal)}/${appState.dailyGoal} ${tr('lessons', lang)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            value: min(1.0, appState.todayLessons / appState.dailyGoal),
                            minHeight: 14,
                            backgroundColor: cloud,
                            color: sun),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(tr('subjects', lang), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 10),
              for (final s in subjects) _SubjectCard(subject: s),
              if (subjects.isEmpty)
                SoftCard(child: Text(tr('comingSoon', lang), style: const TextStyle(fontSize: 17, color: ink))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final lang = appState.mainLang;
    final total = subject.lessons.length;
    final done = subject.lessons.where(appState.isDone).length;
    final color = Color(subject.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Chunky(
        color: color,
        padding: const EdgeInsets.all(14),
        onTap: () {
          appSpeaker?.stop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PathScreen(subject: subject)));
        },
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withAlpha(60), borderRadius: BorderRadius.circular(18)),
            child: Text(subject.icon, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pick(subject.name, lang), textAlign: TextAlign.left, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 6),
              if (total == 0)
                Text(tr('comingSoon', lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: done / total, minHeight: 10, backgroundColor: Colors.white.withAlpha(70), color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('$done / $total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 34),
        ]),
      ),
    );
  }
}

void _showRewards(BuildContext context) {
  final lessons = appState.lessonStars.length;
  final secure = appState.concepts.values.where((c) => c.status == Understanding.secure).length;
  final badges = <List<Object>>[
    ['🌱', 'First lesson', lessons >= 1],
    ['📚', '5 lessons', lessons >= 5],
    ['🔥', '3 days in a row', appState.bestStreak >= 3],
    ['🌟', '7 days in a row', appState.bestStreak >= 7],
    ['⭐', '10 stars', appState.stars >= 10],
    ['🧠', 'Really understood an idea', secure >= 1],
  ];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Pill('⭐', '${appState.stars}'),
            const SizedBox(width: 8),
            Pill('⚡', '${appState.xp} XP'),
            const SizedBox(width: 8),
            Pill('🔥', '${appState.bestStreak}'),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            for (final b in badges)
              Opacity(
                opacity: b[2] == true ? 1 : 0.35,
                child: SizedBox(
                  width: 100,
                  child: Column(children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle, border: Border.all(color: sun, width: 4)),
                      child: Text('${b[0]}', style: const TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(height: 6),
                    Text('${b[1]}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    ),
  );
}
