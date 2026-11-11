import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scol/content.dart';
import 'package:scol/mastery.dart';
import 'package:scol/report.dart';
import 'package:scol/state.dart';
import 'package:scol/tutor.dart';
import 'package:scol/voice.dart';

Bundle loadBundle() => Bundle.parse(File('assets/content/bundle.json').readAsStringSync());

List<Lesson> mathsLessons(Bundle b) => b.subjectsFor('kerala-scert', 3).firstWhere((s) => s.key == 'maths').lessons;

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
    test('Class 3 maths has six chapters and every question can be answered', () {
      final b = loadBundle();
      expect(b.boards.map((x) => x.id), containsAll(['kerala-scert', 'cbse']));
      final maths = b.subjectsFor('kerala-scert', 3).firstWhere((s) => s.key == 'maths');
      expect(maths.chapters.length, 6);
      for (final l in maths.lessons) {
        expect(l.steps, isNotEmpty, reason: l.id);
        for (final st in l.steps) {
          expect(pick(st.text, 'en'), isNotEmpty, reason: l.id);
          expect((st.text as Map).containsKey('ml'), true, reason: l.id);
          if (!st.isAsk) continue;
          expect(st.answer, isNotEmpty, reason: l.id);
          expect(st.concept, isNotEmpty, reason: l.id);
          if (st.form == 'choice') expect(st.options, contains(st.answer), reason: l.id);
        }
      }
    });

    test('five tutors, each with a voice and their own lines', () {
      final b = loadBundle();
      expect(b.tutors.length, 5);
      expect(b.tutors.map((t) => t.voice).toSet().length, 5);
      for (final t in b.tutors) {
        expect(pick(t.hello, 'ml'), isNotEmpty);
        expect(t.praiseList('ml').length, greaterThan(1));
      }
      expect(b.phrase('tryLater', 'ml'), isNotEmpty);
    });

    test('voice file names match the voice builder', () {
      // Same value as: python3 -c "import tools.build_voice as v; print(v.clip_id('Sulafat','en','Hello'))"
      expect(clipId('Sulafat', 'en', 'Hello'), '5d85783ae8f173727aab');
    });
  });

  group('tutor director', () {
    TutorDirector make(Lesson l, Map<String, ConceptRecord> recs, {String lang = 'en'}) {
      final b = loadBundle();
      return TutorDirector(
        lesson: l,
        lang: lang,
        tutor: b.tutors.first,
        phrases: b.phrases,
        recordFor: (k) => recs.putIfAbsent(k, () => ConceptRecord()),
        day: 10,
        random: Random(1),
      );
    }

    void answerAll(TutorDirector d, {bool wrongFirst = false}) {
      var guard = 0;
      final missed = <LessonStep>{};
      while (d.phase != Phase.finished && guard++ < 300) {
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

    test('every lesson plays through in English and Malayalam', () {
      for (final l in mathsLessons(loadBundle())) {
        for (final lang in ['en', 'ml']) {
          final d = make(l, {}, lang: lang);
          expect(d.bubble, isNotEmpty, reason: l.id);
          answerAll(d);
          expect(d.starsEarned, 3, reason: l.id);
        }
      }
    });

    test('a wrong answer gets a hint first, never the answer', () {
      final d = make(mathsLessons(loadBundle()).last, {});
      while (d.phase != Phase.asking) {
        d.next();
      }
      final q = d.question!;
      d.answer('7');
      expect(d.phase, Phase.asking); // still the child's turn
      expect(d.bubble.contains(q.answer), false);
      expect(d.look, Look.board); // the tutor looks back at the picture
    });

    test('missed questions come back later in the lesson', () {
      final recs = <String, ConceptRecord>{};
      final lesson = mathsLessons(loadBundle()).first;
      final asks = lesson.steps.where((s) => s.isAsk).length;
      final d = make(lesson, recs);
      answerAll(d, wrongFirst: true);
      expect(d.questions, asks * 2); // each missed once, then asked again
      expect(d.firstTryRight, 0);
      expect(d.starsEarned, 1);
      expect(recs.values.first.failed, greaterThan(0));
    });

    test('after a repeated mistake the tutor explains another way and remembers if it worked', () {
      final b = loadBundle();
      final lesson = mathsLessons(b).first;
      final results = <String, bool>{};
      final d = TutorDirector(
        lesson: lesson,
        lang: 'en',
        tutor: b.tutors.first,
        phrases: b.phrases,
        recordFor: (_) => ConceptRecord(),
        day: 1,
        pickStyle: (available) => available.contains('story') ? 'story' : available.first,
        onStyleResult: (style, worked) => results[style] = worked,
      );
      while (d.phase != Phase.asking) {
        d.next();
      }
      final q = d.question!;
      d.answer('nonsense');
      d.answer('nonsense again');
      expect(d.phase, Phase.feedback);
      d.next(); // the tutor now tells the story
      expect(d.phase, Phase.talking);
      expect(d.badge, 'A little story');
      expect(d.bubble, pick(lesson.alts['story']!.text, 'en'));
      d.next(); // and asks the same question again
      expect(identical(d.question, q), true);
      d.answer(q.answer);
      expect(results, {'story': true});
    });

    test('the app learns which way of explaining suits the child', () {
      final a = AppState();
      expect(a.pickStyle(['story', 'picture']), 'story'); // nothing tried yet
      a.recordStyle('story', false);
      expect(a.pickStyle(['story', 'picture']), 'picture'); // try the other one
      a.recordStyle('picture', true);
      a.recordStyle('picture', true);
      expect(a.pickStyle(['story', 'picture']), 'picture');
      expect(a.bestStyle, 'picture');
    });

    test('weekly report reads sensibly in English and Malayalam', () {
      final b = loadBundle();
      final a = AppState()
        ..childName = 'Anu'
        ..stars = 7;
      a.history[dayNumber()] = [600, 2];
      a.history[dayNumber() - 1] = [300, 1];
      a.history[dayNumber() - 20] = [900, 5]; // too old to count
      final key = b.concepts.keys.first;
      a.concept(key)
        ..record(form: 'choice', outcome: 'help', day: 1, mistakeNotes: ['added'])
        ..record(form: 'number', outcome: 'failed', day: 1, mistakeNotes: ['added']);
      expect(a.week, [2, 15, 3]);
      final en = weeklyReport(a, b, 'en').join(' ');
      expect(en, contains('Anu'));
      expect(en, contains('2 days'));
      expect(en, contains('3 levels'));
      expect(en, contains('added'));
      final ml = weeklyReport(a, b, 'ml').join(' ');
      expect(ml, contains('Anu'));
      expect(ml, contains(b.conceptName(key, 'ml')));
      expect(weeklyReport(AppState(), b, 'en').length, greaterThan(1)); // works with no data too
    });

    test('the tutor looks at the board while teaching and at the answers while asking', () {
      final d = make(mathsLessons(loadBundle()).first, {});
      expect(d.look, Look.board);
      while (d.phase != Phase.asking) {
        d.next();
      }
      expect(d.look, Look.answers);
    });
  });
}
