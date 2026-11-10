import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scol/content.dart';
import 'package:scol/mastery.dart';
import 'package:scol/tutor.dart';

Bundle loadBundle() => Bundle.parse(File('assets/content/bundle.json').readAsStringSync());

Lesson firstLesson(Bundle b, String board) => b.subjectsFor(board, 3).firstWhere((s) => s.key == 'maths').lessons.first;

void main() {
  group('understanding check', () {
    test('one right answer is not "secure"', () {
      final r = ConceptRecord()..record(form: 'choice', outcome: 'first', day: 1);
      expect(r.status, Understanding.checking);
    });

    test('three right answers in one question style is still not secure', () {
      final r = ConceptRecord();
      for (var i = 0; i < 3; i++) {
        r.record(form: 'choice', outcome: 'first', day: 1);
      }
      expect(r.status, Understanding.checking);
    });

    test('right several times in two styles is secure', () {
      final r = ConceptRecord()
        ..record(form: 'choice', outcome: 'first', day: 1)
        ..record(form: 'number', outcome: 'first', day: 1)
        ..record(form: 'number', outcome: 'first', day: 1);
      expect(r.status, Understanding.secure);
      expect(r.needsRevision(3), false);
      expect(r.needsRevision(9), true); // comes back after a week
    });

    test('instant taps are treated as possible guesses', () {
      final r = ConceptRecord();
      for (var i = 0; i < 4; i++) {
        r.record(form: 'choice', outcome: 'first', day: 1, millis: 300);
      }
      expect(r.firstTry, 0);
      expect(r.status, isNot(Understanding.secure));
    });

    test('the same mistake twice is flagged as a misconception', () {
      final r = ConceptRecord()
        ..record(form: 'choice', outcome: 'help', day: 1, mistakeNotes: ['added'])
        ..record(form: 'number', outcome: 'failed', day: 1, mistakeNotes: ['added']);
      expect(r.status, Understanding.misconception);
      expect(r.repeatedMistake, 'added');
    });

    test('records survive saving and loading', () {
      final r = ConceptRecord()
        ..record(form: 'choice', outcome: 'first', day: 4)
        ..record(form: 'number', outcome: 'failed', day: 5, mistakeNotes: ['x']);
      final back = ConceptRecord.fromJson(r.toJson());
      expect(back.toJson(), r.toJson());
    });
  });

  group('content', () {
    test('bundle has both boards and every question can be answered', () {
      final b = loadBundle();
      expect(b.boards.map((x) => x.id), containsAll(['kerala-scert', 'cbse']));
      for (final board in b.boards) {
        for (final c in board.classes) {
          for (final s in c.subjects) {
            for (final l in s.lessons) {
              for (final st in l.steps.where((x) => x.isAsk)) {
                expect(st.answer, isNotEmpty, reason: l.id);
                expect(st.concept, isNotEmpty, reason: l.id);
                if (st.form == 'choice') expect(st.options, contains(st.answer), reason: l.id);
              }
            }
          }
        }
      }
    });
  });

  group('tutor director', () {
    TutorDirector make(Lesson l, Map<String, ConceptRecord> recs) => TutorDirector(
          lesson: l,
          lang: 'en',
          tutor: tutors.first,
          recordFor: (k) => recs.putIfAbsent(k, () => ConceptRecord()),
          day: 10,
          random: Random(1),
        );

    void answerAll(TutorDirector d, {bool wrongFirst = false}) {
      var guard = 0;
      final missed = <LessonStep>{};
      while (d.phase != Phase.finished && guard++ < 200) {
        switch (d.phase) {
          case Phase.talking:
          case Phase.feedback:
            d.next();
          case Phase.asking:
            final q = d.question!;
            if (wrongFirst && missed.add(q)) {
              d.answer('999999');
              d.answer('999998');
            } else {
              d.answer(q.answer);
            }
          case Phase.thinkAsk:
            d.revealThink();
          case Phase.thinkReveal:
            d.rateThink(true);
          case Phase.finished:
            break;
        }
      }
      expect(d.phase, Phase.finished);
    }

    test('all correct gives three stars', () {
      final recs = <String, ConceptRecord>{};
      final d = make(firstLesson(loadBundle(), 'kerala-scert'), recs);
      answerAll(d);
      expect(d.starsEarned, 3);
      expect(d.firstTryRight, d.questions);
      expect(recs.values.first.firstTry, greaterThan(0));
    });

    test('a wrong answer gets a hint first, never the answer', () {
      final d = make(firstLesson(loadBundle(), 'kerala-scert'), {});
      while (d.phase != Phase.asking) {
        d.next();
      }
      final q = d.question!;
      d.answer('7');
      expect(d.phase, Phase.asking); // still the child's turn
      expect(d.bubble.contains(q.answer), false);
      expect(d.wrongOptions, contains('7'));
    });

    test('missed questions come back later in the lesson', () {
      final recs = <String, ConceptRecord>{};
      final lesson = firstLesson(loadBundle(), 'kerala-scert');
      final asks = lesson.steps.where((s) => s.isAsk).length;
      final d = make(lesson, recs);
      answerAll(d, wrongFirst: true);
      expect(d.questions, asks * 2); // each missed once, then asked again
      expect(d.starsEarned, 1);
      expect(recs.values.first.failed, greaterThan(0));
    });

    test('lessons made from plain notes play through', () {
      final b = loadBundle();
      for (final l in b.subjectsFor('cbse', 3).firstWhere((s) => s.key == 'maths').lessons) {
        answerAll(make(l, {}));
      }
    });
  });
}
