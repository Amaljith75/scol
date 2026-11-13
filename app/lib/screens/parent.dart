// Parent zone: a plain-words report of what the child understands, plus controls.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../content.dart';
import '../mastery.dart';
import '../reminders.dart';
import '../report.dart';
import '../state.dart';
import '../voice.dart';
import '../widgets/ui.dart';

/// A small sum keeps young children out of the parent area.
Future<void> openParentZone(BuildContext context) async {
  final r = Random();
  final a = 3 + r.nextInt(7), b = 3 + r.nextInt(7);
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('For parents'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('To continue, what is $a × $b?', style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 12),
        TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim() == '${a * b}'), child: const Text('Open')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentScreen()));
  }
}

String studyTimeLabel(int minute) {
  final h = minute ~/ 60, m = minute % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

String _statusWords(ConceptRecord r) {
  switch (r.status) {
    case Understanding.secure:
      return 'Understands this well. Answered correctly several times, in different kinds of questions.';
    case Understanding.checking:
      return 'Getting it right so far. Scol will check a few more times before counting it as learned.';
    case Understanding.misconception:
      return 'Keeps making the same mistake: ${r.repeatedMistake}. Scol will teach this again in a different way.';
    case Understanding.needsHelp:
      return 'Still finds this hard. Scol will bring it back for practice.';
    case Understanding.notStarted:
      return 'Not started yet.';
  }
}

const _statusColor = {
  Understanding.secure: mint,
  Understanding.checking: sun,
  Understanding.misconception: coral,
  Understanding.needsHelp: coral,
  Understanding.notStarted: cloud,
};

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late String _reportLang = appState.lang == 'ml' ? 'ml' : 'en';
  bool _reading = false;

  @override
  void dispose() {
    appSpeaker?.stop();
    super.dispose();
  }

  Future<void> _listen(List<String> report) async {
    if (_reading) {
      appSpeaker?.stop();
      setState(() => _reading = false);
      return;
    }
    setState(() => _reading = true);
    await appSpeaker?.say(report, _reportLang, tutorById(appState.tutorId));
    if (mounted) setState(() => _reading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final bundle = contentStore.bundle;
        final subjects = appState.mySubjects(bundle);
        final hasSamples = subjects.any((s) => s.chapters.any((c) => !c.verified && c.lessons.isNotEmpty));
        Widget h(String t) => Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 10),
              child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
            );
        Widget chips<T>(List<T> values, T current, String Function(T) label, void Function(T) onPick) => Wrap(
              spacing: 8,
              children: [
                for (final v in values)
                  ChoiceChip(
                    label: Text(label(v)),
                    selected: v == current,
                    onSelected: (_) {
                      onPick(v);
                      appState.save();
                    },
                  ),
              ],
            );

        return Scaffold(
          appBar: AppBar(title: Text("${appState.childName}'s learning"), backgroundColor: cream),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
                h('Weekly report'),
                Wrap(spacing: 8, children: [
                  for (final l in const ['en', 'ml'])
                    ChoiceChip(
                      label: Text(l == 'en' ? 'English' : 'മലയാളം'),
                      selected: _reportLang == l,
                      onSelected: (_) {
                        appSpeaker?.stop();
                        setState(() {
                          _reportLang = l;
                          _reading = false;
                        });
                      },
                    ),
                ]),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final report = weeklyReport(appState, bundle, _reportLang);
                  return SoftCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(report.first, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink)),
                      for (final para in report.skip(1))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(para, style: const TextStyle(fontSize: 15, height: 1.4, color: ink)),
                        ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: violet),
                            onPressed: () => Share.share(report.join('\n\n')),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _listen(report),
                            icon: Icon(_reading ? Icons.stop_rounded : Icons.volume_up_rounded),
                            label: Text(_reading ? 'Stop' : 'Listen'),
                          ),
                        ),
                      ]),
                    ]),
                  );
                }),
                h('Today and so far'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Pill('⏱️', '${(appState.todaySeconds / 60).ceil()} min today'),
                  Pill('📚', '${appState.lessonStars.length} lessons done'),
                  Pill('📅', '${appState.learningDays} learning days'),
                  Pill('🔥', 'best streak ${appState.bestStreak}'),
                ]),
                h('What ${appState.childName} understands'),
                const Text(
                  'Scol does not treat one right answer as "learned". It looks at several answers, in more than one '
                  'question style, and at mistakes that repeat.',
                  style: TextStyle(color: Color(0xFF6B6F80), height: 1.4),
                ),
                const SizedBox(height: 10),
                for (final s in subjects) ..._subjectReport(bundle, s),
                if (appState.concepts.isEmpty)
                  const SoftCard(child: Text('Nothing yet. This fills in after the first lesson.')),
                if (hasSamples)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: SoftCard(
                      color: Color(0xFFFFF1D6),
                      child: Text('Note: some lessons shown now are samples and have not yet been checked against the school textbook.'),
                    ),
                  ),
                h('Settings'),
                const Text('Tutor language', style: TextStyle(fontWeight: FontWeight.w700)),
                chips<String>(['en', 'ml', 'both'], appState.lang,
                    (v) => {'en': 'English', 'ml': 'മലയാളം', 'both': 'Both'}[v]!, (v) => appState.lang = v),
                const SizedBox(height: 10),
                const Text('Tutor', style: TextStyle(fontWeight: FontWeight.w700)),
                chips<String>([for (final t in tutors) t.id], appState.tutorId, (v) => tutorById(v).displayName('en'),
                    (v) => appState.tutorId = v),
                const SizedBox(height: 10),
                const Text('Daily learning time limit', style: TextStyle(fontWeight: FontWeight.w700)),
                chips<int>([15, 30, 45, 60], appState.dailyLimitMin, (v) => '$v min', (v) => appState.dailyLimitMin = v),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tutor speaks aloud'),
                  subtitle: const Text('Mio has a ready-made natural voice. The other tutors, and live answers, use the phone\'s own voice.'),
                  value: appState.voiceOn,
                  onChanged: (v) {
                    appState.voiceOn = v;
                    appState.save();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Let my child ask the tutor questions'),
                  subtitle: const Text('Your child can speak or type a question about the lesson. The words of the question and the lesson '
                      'topic are sent to an AI service (Kimi, by Moonshot AI) to get an answer. Your child\'s name and progress '
                      'are never sent. Speech is turned into words by the phone\'s own speech service. Off unless you turn it on.'),
                  value: appState.askEnabled,
                  onChanged: (v) {
                    appState.askEnabled = v;
                    appState.save();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily study reminders'),
                  subtitle: Text('At ${studyTimeLabel(appState.studyMinute)} every day, and a friendly call back if a level is left halfway.'),
                  value: appState.remindersOn,
                  onChanged: (v) async {
                    appState.remindersOn = v;
                    await appState.save();
                    if (v) await askReminderPermission();
                    await planReminders(appState, bundle);
                  },
                ),
                if (appState.remindersOn)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text('Study time: ${studyTimeLabel(appState.studyMinute)}'),
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: appState.studyMinute ~/ 60, minute: appState.studyMinute % 60));
                        if (t == null) return;
                        appState.studyMinute = t.hour * 60 + t.minute;
                        await appState.save();
                        await planReminders(appState, bundle);
                      },
                    ),
                  ),
                h('Account'),
                OutlinedButton(
                  onPressed: () {
                    appState.onboarded = false;
                    appState.save();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text('Change syllabus, class or subjects'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: coral),
                  onPressed: () async {
                    final sure = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete everything?'),
                        content: const Text("This removes your child's name, progress and settings from this phone. It cannot be undone."),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (sure == true) {
                      await appState.eraseEverything();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  child: const Text("Delete all of my child's data"),
                ),
                const SizedBox(height: 16),
                Text('Lessons version ${bundle.version}', style: const TextStyle(color: Color(0xFF9A948A), fontSize: 12)),
              ]),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _subjectReport(Bundle bundle, Subject s) {
    final keys = <String>[];
    for (final l in s.lessons) {
      for (final st in l.steps) {
        if (st.isAsk && appState.concepts.containsKey(st.concept) && !keys.contains(st.concept)) keys.add(st.concept);
      }
    }
    if (keys.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text('${s.icon} ${pick(s.name, 'en')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4, right: 10),
                decoration: BoxDecoration(color: _statusColor[appState.concepts[k]!.status], shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bundle.conceptName(k, 'en'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                  const SizedBox(height: 2),
                  Text(_statusWords(appState.concepts[k]!), style: const TextStyle(height: 1.35, color: ink)),
                ]),
              ),
            ]),
          ),
        ),
    ];
  }
}
