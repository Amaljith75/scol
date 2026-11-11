// First-run setup, done by a parent: child, board, class, language, subjects, tutor.
import 'package:flutter/material.dart';

import '../content.dart';
import '../state.dart';
import '../tutor.dart';
import '../voice.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  late final TextEditingController _name = TextEditingController(text: appState.childName);
  String boardId = appState.boardId;
  int classNumber = appState.classNumber;
  String lang = appState.lang;
  String tutorId = appState.tutorId;
  Set<String> subjects = appState.subjectKeys.toSet();

  static const _titles = [
    'Welcome to Scol',
    "What is your child's name?",
    'Which syllabus does your child follow?',
    'Which class?',
    'Which language should the tutor use?',
    'Which subjects is your child studying?',
    'Let your child pick a friend to learn with!',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<Subject> get _available => contentStore.bundle.subjectsFor(boardId, classNumber);

  bool get _canGoOn {
    switch (step) {
      case 1:
        return _name.text.trim().isNotEmpty;
      case 2:
        return boardId.isNotEmpty;
      case 5:
        return subjects.isNotEmpty || _available.isEmpty;
    }
    return true;
  }

  void _next() {
    if (step == 4) subjects = _available.map((s) => s.key).toSet();
    if (step < _titles.length - 1) {
      setState(() => step++);
      return;
    }
    appState
      ..childName = _name.text.trim()
      ..boardId = boardId
      ..classNumber = classNumber
      ..lang = lang
      ..tutorId = tutorId
      ..subjectKeys = subjects.toList()
      ..onboarded = true;
    appState.save();
  }

  Widget _option(String label, bool selected, VoidCallback onTap, {String? leading, String? sub}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Chunky(
          color: selected ? indigo : Colors.white,
          onTap: onTap,
          child: Row(children: [
            if (leading != null) Padding(padding: const EdgeInsets.only(right: 12), child: Text(leading, style: const TextStyle(fontSize: 28))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, textAlign: TextAlign.left, style: TextStyle(color: selected ? Colors.white : ink, fontSize: 18)),
                if (sub != null)
                  Text(sub,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                          color: selected ? Colors.white70 : const Color(0xFF6B6F80), fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
            if (selected) const Icon(Icons.check_circle, color: Colors.white),
          ]),
        ),
      );

  List<Widget> _body() {
    switch (step) {
      case 0:
        return const [
          Text(
            'Scol is a personal tutor for your child. The tutor explains each lesson, shows examples, asks questions, '
            'and checks whether your child has really understood.\n\n'
            'This setup is for a parent and takes about a minute.\n\n'
            "Your child's name and progress stay on this phone. Nothing is sent anywhere.",
            style: TextStyle(fontSize: 17, height: 1.45, color: ink),
          ),
        ];
      case 1:
        return [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 20,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'First name or nickname',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case 2:
        return [
          for (final b in contentStore.bundle.boards)
            _option(pick(b.name, 'en'), boardId == b.id, () => setState(() => boardId = b.id),
                leading: '🏫', sub: pick(b.name, 'ml') == pick(b.name, 'en') ? null : pick(b.name, 'ml')),
        ];
      case 3:
        return [
          for (final c in (contentStore.bundle.board(boardId)?.classes ?? const <SchoolClass>[]))
            _option('Class ${c.number}', classNumber == c.number, () => setState(() => classNumber = c.number),
                leading: '🎒'),
        ];
      case 4:
        return [
          _option('English', lang == 'en', () => setState(() => lang = 'en'), leading: 'Aa'),
          _option('മലയാളം', lang == 'ml', () => setState(() => lang = 'ml'), leading: 'അ'),
          _option('Both together', lang == 'both', () => setState(() => lang = 'both'),
              leading: '🔁', sub: 'English first, with Malayalam shown below'),
        ];
      case 5:
        if (_available.isEmpty) {
          return const [
            Text('Lessons for this class are being prepared. You can finish setup now and they will appear here when ready.',
                style: TextStyle(fontSize: 17, height: 1.4, color: ink)),
          ];
        }
        return [
          for (final s in _available)
            _option(pick(s.name, 'en'), subjects.contains(s.key), () {
              setState(() => subjects.contains(s.key) ? subjects.remove(s.key) : subjects.add(s.key));
            }, leading: s.icon, sub: s.lessons.isEmpty ? 'Lessons coming soon' : '${s.lessons.length} lessons ready'),
        ];
      default:
        return [
          for (final t in tutors)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Chunky(
                color: tutorId == t.id ? indigo : Colors.white,
                onTap: () {
                  setState(() => tutorId = t.id);
                  final l = lang == 'ml' ? 'ml' : 'en';
                  appSpeaker?.say([pick(t.hello, l)], l, t);
                },
                child: Row(children: [
                  TutorAvatar(tutor: t, size: 78, mood: tutorId == t.id ? Mood.happy : Mood.calm),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${pick(t.name, 'en')} · ${pick(t.name, 'ml')}',
                          style: TextStyle(fontSize: 20, color: tutorId == t.id ? Colors.white : ink)),
                      Text(pick(t.about, lang == 'ml' ? 'ml' : 'en'),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: tutorId == t.id ? Colors.white70 : const Color(0xFF6B6F80))),
                    ]),
                  ),
                ]),
              ),
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  if (step > 0)
                    IconButton(onPressed: () => setState(() => step--), icon: const Icon(Icons.arrow_back_rounded, size: 28)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: (step + 1) / _titles.length, minHeight: 12, backgroundColor: cloud, color: mint),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Text(_titles[step], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink)),
                const SizedBox(height: 18),
                Expanded(child: ListView(children: _body())),
                Chunky(color: mint, onTap: _canGoOn ? _next : null, child: Text(step == _titles.length - 1 ? 'Start learning' : 'Next')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
