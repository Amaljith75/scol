// The learning path: every lesson of a subject as a stepping stone.
import 'dart:math';

import 'package:flutter/material.dart';

import '../content.dart';
import '../state.dart';
import '../strings.dart';
import '../tutor.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';
import 'home.dart' show openLesson;

class PathScreen extends StatelessWidget {
  const PathScreen({super.key, required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final lang = appState.mainLang;
        final tutor = tutorById(appState.tutorId);
        final current = appState.nextLesson(subject);
        final revision = appState.revisionLesson(subject);
        var i = 0;
        final items = <Widget>[];
        if (revision != null) {
          items.add(Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Chunky(
              color: coral,
              onTap: () => openLesson(context, subject, revision),
              child: Text('💪 ${tr('practice', lang)}'),
            ),
          ));
        }
        var ci = -1;
        for (final ch in subject.chapters) {
          ci++;
          final chColor = chapterColors[ci % chapterColors.length];
          items.add(Container(
            margin: const EdgeInsets.only(bottom: 18, top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: chColor, borderRadius: BorderRadius.circular(18)),
            child: Text(pick(ch.title, lang),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ));
          for (final l in ch.lessons) {
            final done = appState.isDone(l);
            final isCurrent = identical(l, current);
            final stars = appState.lessonStars[l.id] ?? 0;
            final x = sin(i * 1.1) * 0.55;
            i++;
            final level = i;
            items.add(Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Align(
                alignment: Alignment(x, 0),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isCurrent && x > 0) TutorAvatar(tutor: tutor, size: 64, mood: Mood.happy, gaze: const Offset(0.9, 0.1)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 92,
                      child: Chunky(
                        radius: 46,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        color: done ? chColor : (isCurrent ? violet : cloud),
                        onTap: () {
                          if (done || isCurrent) {
                            openLesson(context, subject, l);
                          } else {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(tr('locked', lang))));
                          }
                        },
                        child: Text(
                          done ? '★' * stars + '☆' * (3 - stars) : (isCurrent ? tr('start', lang) : '🔒'),
                          style: TextStyle(fontSize: done ? 20 : (isCurrent ? 15 : 24), color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 150,
                      child: Text('${tr('level', lang)} $level\n${pick(l.title, lang)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: done || isCurrent ? ink : const Color(0xFF9A948A))),
                    ),
                  ]),
                  if (isCurrent && x <= 0) TutorAvatar(tutor: tutor, size: 64, mood: Mood.happy, gaze: const Offset(-0.9, 0.1)),
                ]),
              ),
            ));
          }
        }
        final empty = subject.lessons.isEmpty;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    child: Row(children: [
                      IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 30, color: ink)),
                      Text('${subject.icon} ${pick(subject.name, lang)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)),
                      const Spacer(),
                      Pill('⭐', '${appState.stars}'),
                    ]),
                  ),
                  Expanded(
                    child: empty
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            TutorAvatar(tutor: tutor, size: 140),
                            const SizedBox(height: 16),
                            Text(tr('comingSoon', lang),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
                          ])
                        : ListView(padding: const EdgeInsets.all(16), children: items),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
