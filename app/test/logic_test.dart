import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scol/brain.dart';
import 'package:scol/content.dart';
import 'package:scol/edge_voice.dart';
import 'package:scol/live.dart';
import 'package:scol/mastery.dart';
import 'package:scol/pcm_out.dart';
import 'package:scol/report.dart';
import 'package:scol/state.dart';
import 'package:scol/tutor.dart';
import 'package:scol/updates.dart';
import 'package:scol/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(b.tutors.map((t) => t.displayName('en')), ['Mio', 'Leo', 'Yuki', 'Ruby', 'Ollie']);
      // every tutor speaks both languages in an Edge voice
      expect(b.tutors.every((t) => t.voiceFor('ml').startsWith('ml-IN') && t.voiceFor('en').startsWith('en-IN')), true);
      expect(b.brain['url'], startsWith('https://'));
      expect('${b.brain}'.toLowerCase(), isNot(contains('sk-'))); // never a secret key in the app
      for (final t in b.tutors) {
        expect(pick(t.hello, 'ml'), isNotEmpty);
        expect(t.praiseList('ml').length, greaterThan(1));
      }
      expect(b.phrase('tryLater', 'ml'), isNotEmpty);
    });

    test('Class 3 EVS has four chapters, English medium, each lesson with a story and a picture', () {
      final b = loadBundle();
      final evs = b.subjectsFor('kerala-scert', 3).firstWhere((s) => s.key == 'evs');
      expect(evs.chapters.length, 4);
      expect(evs.palette, isNotEmpty);
      for (final l in evs.lessons) {
        expect(l.alts.keys.toSet(), {'story', 'picture'}, reason: l.id);
        expect(l.steps.where((s) => !s.isAsk).length, greaterThanOrEqualTo(4), reason: '${l.id} teaches first');
      }
    });

    test('lines the tutor speaks never describe button colours', () {
      final b = loadBundle();
      final words = RegExp(r'\b(green|violet|purple|blue|red) button', caseSensitive: false);
      for (final v in b.phrases.values) {
        expect(words.hasMatch('$v'), false, reason: '$v');
      }
    });

    test('live Edge voice token matches the edge-tts library', () {
      // Values made with edge_tts.drm.generate_sec_ms_gec_v2 (edge-tts 7.3.1).
      expect(secMsGec(1794540000.0),
          'C463238EAF8E9DEA-7E5486F8C93AC3A6444BA3A3BC403ED131B99C2118784821CFCDF91AFB94C484');
      expect(secMsGec(1794555555.5),
          'C446C4E2F1C42521-BD1C6052DC08A1775E0C0F177F94E7E014E2E64083F1A4B45C6C7D81EF95B6D8');
      expect(secMsGec(1700000000.0),
          '2CD23A2CA0B2595A-F3C846C370E05F9CC83ACC5F995C5F5D87A4D0F14CE8936A0F902E64099E38A2');
    });

    test('symbols are read out in words', () {
      expect(spokenText('3 × 4 = 12 🥭', 'en'), '3 times 4 equals 12');
      expect(spokenText('7 cm', 'en'), '7 centimetres');
    });

    test('long lines are spoken sentence by sentence so the voice starts quickly', () {
      final pieces = sentencePieces('Hello there. This is a long explanation about mangoes! Each basket has four. '
          'So three baskets have twelve mangoes. Can you see that? Now let us count them together one more time, slowly. '
          'Look at the first basket: one, two, three, four. The second basket also has four, so that makes eight. '
          'The third basket brings us to twelve. Well done for counting along with me, you are doing great today!');
      expect(pieces.length, greaterThan(1));
      expect(sentencePieces('Short one. Short two.'), ['Short one. Short two.']); // short lines stay whole
      expect(pieces.join(' '), contains('twelve mangoes'));
      expect(pieces.every((p) => p.length <= 240), true);
      expect(sentencePieces('Short.'), ['Short.']);
      expect(sentencePieces('നോക്കൂ! ഇതാ 3 കൊട്ടകൾ. ഓരോ കൊട്ടയിലും 4 മാങ്ങ വീതം.').join(' '), 'നോക്കൂ! ഇതാ 3 കൊട്ടകൾ. ഓരോ കൊട്ടയിലും 4 മാങ്ങ വീതം.');
    });

    test('mood changes the speed and pitch on top of the tutor', () {
      expect(shiftProsody('-6%', 8, '%'), '+2%');
      expect(shiftProsody('+4Hz', -14, 'Hz'), '-10Hz');
      expect(shiftProsody('+0Hz', 0, 'Hz'), '+0Hz');
    });

    test('language of a line is detected for the voice', () {
      expect(langOf('Look! Here are 3 baskets.'), 'en');
      expect(langOf('നോക്കൂ! 3 കൊട്ടകൾ.'), 'ml');
    });

    test('app update check reads the build number', () {
      expect(parseBuild('name: scol\nversion: 1.0.0+3\n'), 3);
      expect(parseBuild('nothing here'), isNull);
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
        greet: false,
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

    test('switching to Malayalam in the middle of a lesson says the same step in Malayalam', () {
      final d = make(mathsLessons(loadBundle()).first, {});
      d.next();
      final step = d.current;
      expect(langOf(d.bubble), 'en');
      d.setLang('ml');
      expect(identical(d.current, step), true);
      expect(langOf(d.bubble), 'ml');
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

    test('progress for the brain keeps the name on the phone', () {
      final b = loadBundle();
      final a = AppState()..childName = 'Anu';
      a.history[dayNumber()] = [600, 2];
      final facts = progressFacts(a, b, 'en');
      expect(facts, isNot(contains('Anu')));
      expect(facts, contains('{name}'));
      expect(facts, contains('2 levels'));
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

    test('the brain\'s words replace the read line at teaching steps, never at questions', () {
      final lesson = mathsLessons(loadBundle()).first;
      final d = make(lesson, {});
      final written = [for (final s in lesson.steps) s.isAsk ? null : Taught('Taught: ${pick(s.text, 'en')}', const [1, 2])];
      final firstLine = d.bubble;
      d.setTeaching(written);
      expect(d.taughtByBrain, true);
      expect(d.bubble, startsWith('Taught: '));
      expect(d.touches, [1, 2]); // and it floats to the pieces the brain named
      expect(d.lessonLine, firstLine); // the checked line stays available to show
      while (d.phase == Phase.talking) {
        expect(d.bubble, startsWith('Taught: '));
        d.next();
      }
      expect(d.touches, isEmpty); // never while a question is open
      expect(d.taughtByBrain, false);
      expect(d.bubble, pick(d.question!.text, 'en')); // questions are asked exactly as written
      // Switching language drops the brain's words (they were English) until new ones come.
      d.answer(d.question!.answer);
      d.next();
      d.setLang('ml');
      expect(d.taughtByBrain, false);
      // A list that does not fit the lesson is ignored.
      d.setTeaching([const Taught('x')]);
      expect(d.taughtByBrain, false);
    });

    test('without the brain, a teaching step with a picture visits every piece of it', () {
      final lesson = mathsLessons(loadBundle()).first;
      final d = make(lesson, {});
      expect(lesson.steps.first.visual, isNotNull);
      expect(d.touches, [-1]);
    });

    test('a different hello each time, with the child\'s name now and then', () {
      final b = loadBundle();
      final lesson = mathsLessons(b).first;
      final seen = <String>{};
      var named = 0;
      for (var i = 0; i < 30; i++) {
        final d = TutorDirector(
            lesson: lesson, lang: 'ml', tutor: b.tutors.first, phrases: b.phrases, childName: 'Anu',
            recordFor: (_) => ConceptRecord(), day: 1, random: Random(i));
        expect(d.intro, isNotEmpty);
        expect(langOf(d.intro), 'ml');
        expect(d.bubble, startsWith(d.intro));
        expect(d.bubble, endsWith(pick(lesson.steps.first.text, 'ml')));
        expect(d.intro, isNot(contains('{name}')));
        seen.add(d.intro);
        if (d.intro.contains('Anu')) named++;
      }
      expect(seen.length, greaterThan(3));
      expect(named, greaterThan(3));
      // The hello is said once: when the brain's words arrive and the first step is said again, no second hello.
      final once = TutorDirector(
          lesson: lesson, lang: 'en', tutor: b.tutors.first, phrases: b.phrases, childName: 'Anu', recordFor: (_) => ConceptRecord(), day: 1);
      expect(once.bubble, startsWith(once.intro));
      once.setTeaching([for (final s in lesson.steps) s.isAsk ? null : const Taught('Taught again, in my own words.')]);
      expect(once.bubble, 'Taught again, in my own words.');
      // No name known: only the hellos that need none.
      final quiet = TutorDirector(
          lesson: lesson, lang: 'en', tutor: b.tutors.first, phrases: b.phrases, recordFor: (_) => ConceptRecord(), day: 1);
      expect(quiet.intro, isNotEmpty);
      expect(quiet.allLines, contains(quiet.intro));
    });

    test('while waiting for the brain the first line is shown, then spoken as written if nothing comes', () {
      final b = loadBundle();
      final lesson = mathsLessons(b).first;
      final d = TutorDirector(
          lesson: lesson, lang: 'en', tutor: b.tutors.first, recordFor: (_) => ConceptRecord(), day: 1, waitForTeaching: true, greet: false);
      expect(d.bubble, pick(lesson.steps.first.text, 'en'));
      d.stopWaiting();
      expect(d.bubble, pick(lesson.steps.first.text, 'en'));
      d.setTeaching(null);
      expect(d.bubble, pick(lesson.steps.first.text, 'en'));
      expect(d.taughtByBrain, false);
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

  group('teaching from the brain', () {
    test('the request carries only lesson text, with the board and the answers the tutor must not give away', () {
      final b = loadBundle();
      final lesson = mathsLessons(b).first;
      final req = teachRequest(lesson, 'ml', b.tutors.first, 'calm');
      expect(req['mode'], 'teach');
      expect(req['lang'], 'ml');
      expect(req['tutor'], 'Mio');
      expect(req['tone'], 'calm');
      final steps = (req['steps'] as List).cast<Map>();
      expect(steps.length, lesson.steps.length);
      expect(steps.where((s) => s['t'] == 'say').length, lesson.steps.where((s) => !s.isAsk).length);
      expect(steps.any((s) => '${s['visual'] ?? ''}'.isNotEmpty), true);
      expect(steps.where((s) => s['t'] == 'ask').every((s) => '${s['answer']}'.isNotEmpty), true);
      expect('$req', isNot(contains('device')));
      expect(teachKey(lesson, 'ml', b.tutors.first, 'calm'), teachKey(lesson, 'ml', b.tutors.first, 'calm'));
      expect(teachKey(lesson, 'ml', b.tutors.first, 'calm'), isNot(teachKey(lesson, 'en', b.tutors.first, 'calm')));
    });

    test('written lines are lined up with the steps, and a wrong count is refused', () {
      final lesson = mathsLessons(loadBundle()).first;
      final says = lesson.steps.where((s) => !s.isAsk).length;
      final ok = alignTeaching(lesson, List.generate(says, (i) => {'say': 'line $i', 'touch': [1, '2', 0, 'x']}))!;
      expect(ok.length, lesson.steps.length);
      for (var i = 0; i < lesson.steps.length; i++) {
        expect(ok[i] == null, lesson.steps[i].isAsk);
      }
      expect(ok.whereType<Taught>().first.touch, [1, 2]); // only real item numbers are kept
      expect(alignTeaching(lesson, List.generate(says, (i) => 'line $i'))!.whereType<Taught>().first, const Taught('line 0'));
      expect(alignTeaching(lesson, List.generate(says + 1, (i) => 'line $i')), isNull);
      expect(alignTeaching(lesson, null), isNull);
    });

    test('a lesson is fetched once and then served from the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final b = loadBundle();
      final lesson = mathsLessons(b).first;
      final says = lesson.steps.where((s) => !s.isAsk).length;
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        final body = jsonDecode(req.body) as Map;
        expect(body['mode'], 'teach');
        expect('${body['device']}'.length, 24);
        expect(body.containsKey('question'), false);
        return http.Response(
            jsonEncode({'steps': List.generate(says, (i) => {'say': 'Taught $i', 'touch': [1]}), 'by': 'test'}), 200,
            headers: {'content-type': 'application/json'});
      });
      final first = await teachLesson(bundle: b, lesson: lesson, lang: 'en', tutor: b.tutors.first, client: client);
      expect(first, isNotNull);
      expect(first!.whereType<Taught>().first, const Taught('Taught 0', [1]));
      final second = await teachLesson(bundle: b, lesson: lesson, lang: 'en', tutor: b.tutors.first, client: client);
      expect(second, first);
      expect(calls, 1);
      // A server that is busy means: read the lesson as written.
      final busy = MockClient((_) async => http.Response('{"error":"all_busy"}', 503));
      expect(await teachLesson(bundle: b, lesson: lesson, lang: 'ml', tutor: b.tutors.first, client: busy), isNull);
    });
  });

  group('variety, timing and voices', () {
    test('a line with several wordings gives one of them, and not the same one twice in a row', () {
      final lines = {'en': ['A', 'B', 'C', 'D'], 'ml': ['അ', 'ആ']};
      final said = <String>[];
      for (var i = 0; i < 20; i++) {
        final w = pick(lines, 'en');
        expect(['A', 'B', 'C', 'D'], contains(w));
        said.add(w);
      }
      for (var i = 1; i < said.length; i++) {
        expect(said[i], isNot(said[i - 1]));
      }
      expect(said.toSet().length, 4);
      expect(pickAll(lines, 'ml'), ['അ', 'ആ']);
      expect(pick('just one', 'en'), 'just one');
      final b = loadBundle();
      expect(b.phrase('tryLater', 'en'), isNot(startsWith('[')));
      expect(pickAll(b.phrases['tryLater'], 'en').length, greaterThan(2));
      expect(b.tutors.every((t) => t.geminiVoice.isNotEmpty), true);
      expect(b.tutors.map((t) => t.geminiVoice).toSet().length, b.tutors.length); // every character sounds different
    });

    test('each board touch happens at its own word in the line', () {
      const t = Taught('Look, here is one basket, two baskets and three baskets.', [1, 2, 3], ['one', 'two', 'three']);
      final at = t.touchAt;
      expect(at.length, 3);
      expect(at[0] < at[1] && at[1] < at[2], true);
      expect(at[0], closeTo('Look, here is '.length / t.say.length, 0.001));
      final parsed = Taught.from({
        'say': 'One mango, two mangoes.',
        'touch': [
          {'item': 1, 'at': 'One'},
          {'item': 2, 'at': 'two'}
        ]
      })!;
      expect(parsed.touch, [1, 2]);
      expect(parsed.at, ['One', 'two']);
      expect(parsed.touchAt.first, 0);
    });

    test('the touch plan follows the brain and sits after the hello', () {
      final b = loadBundle();
      final lesson = mathsLessons(b).first;
      final d = TutorDirector(
          lesson: lesson, lang: 'en', tutor: b.tutors.first, phrases: b.phrases, childName: 'Anu', recordFor: (_) => ConceptRecord(), day: 1);
      d.setTeaching([
        for (final s in lesson.steps) s.isAsk ? null : const Taught('Here is one basket and here is two.', [1, 2], ['one', 'two'])
      ]);
      final plan = d.touchPlan;
      expect(plan.map((e) => e.key), [1, 2]);
      expect(plan.first.value < plan.last.value, true);
      expect(plan.last.value <= 1, true);
    });

    test('the mouth follows the loudness of the voice', () {
      // 1 second of 16-bit mono WAV at 8000 Hz: silent, then loud.
      const rate = 8000;
      final pcm = ByteData(rate * 2);
      for (var i = rate ~/ 2; i < rate; i++) {
        pcm.setInt16(i * 2, i.isEven ? 12000 : -12000, Endian.little);
      }
      final head = ByteData(44);
      void text(int o, String t) {
        for (var i = 0; i < t.length; i++) {
          head.setUint8(o + i, t.codeUnitAt(i));
        }
      }

      text(0, 'RIFF');
      head.setUint32(4, 36 + rate * 2, Endian.little);
      text(8, 'WAVEfmt ');
      head.setUint32(16, 16, Endian.little);
      head.setUint16(20, 1, Endian.little);
      head.setUint16(22, 1, Endian.little);
      head.setUint32(24, rate, Endian.little);
      head.setUint32(28, rate * 2, Endian.little);
      head.setUint16(32, 2, Endian.little);
      head.setUint16(34, 16, Endian.little);
      text(36, 'data');
      head.setUint32(40, rate * 2, Endian.little);
      final wav = Uint8List.fromList([...head.buffer.asUint8List(), ...pcm.buffer.asUint8List()]);
      final env = wavEnvelope(wav)!;
      expect(env.length, greaterThan(20));
      expect(env.first, lessThan(0.1)); // quiet: mouth closed
      expect(env.last, greaterThan(0.8)); // loud: mouth open
      expect(wavEnvelope(Uint8List.fromList(utf8.encode('not a wav file at all, just some text'))), isNull);
    });
  });

  group('clean sound and Gemini Live', () {
    Uint8List tone(int rate, int ms, int amp) {
      final d = ByteData(rate * ms ~/ 1000 * 2);
      for (var i = 0; i < d.lengthInBytes ~/ 2; i++) {
        d.setInt16(i * 2, (amp * sin(i / rate * 2 * pi * 220)).round(), Endian.little);
      }
      return d.buffer.asUint8List();
    }

    test('a line starts and ends softly, with the silence at its ends trimmed', () {
      const rate = 24000;
      final pcm = Uint8List.fromList([...Uint8List(rate), ...tone(rate, 500, 12000), ...Uint8List(rate)]); // 0.5 s silence each side
      final out = smoothPcm(pcm, rate);
      final d = ByteData.sublistView(out);
      final n = out.length ~/ 2;
      expect(n, lessThan(pcm.length ~/ 2)); // silence trimmed
      expect(n, greaterThan(rate * 500 ~/ 1000)); // the sound itself kept
      expect(d.getInt16(0, Endian.little).abs(), lessThan(200)); // no click at the start
      expect(d.getInt16((n - 1) * 2, Endian.little).abs(), lessThan(200)); // nor at the end
      expect(smoothPcm(Uint8List(rate * 2), rate), isEmpty); // all silence: nothing to play
    });

    test('the samples of a WAV file are found after its header', () {
      const rate = 24000;
      final pcm = tone(rate, 100, 8000);
      final head = ByteData(44);
      void text(int o, String t) {
        for (var i = 0; i < t.length; i++) {
          head.setUint8(o + i, t.codeUnitAt(i));
        }
      }

      text(0, 'RIFF');
      head.setUint32(4, 36 + pcm.length, Endian.little);
      text(8, 'WAVEfmt ');
      head.setUint32(16, 16, Endian.little);
      head.setUint16(20, 1, Endian.little);
      head.setUint16(22, 1, Endian.little);
      head.setUint32(24, rate, Endian.little);
      head.setUint32(28, rate * 2, Endian.little);
      head.setUint16(32, 2, Endian.little);
      head.setUint16(34, 16, Endian.little);
      text(36, 'data');
      head.setUint32(40, pcm.length, Endian.little);
      final w = wavPcm(Uint8List.fromList([...head.buffer.asUint8List(), ...pcm]))!;
      expect(w.rate, rate);
      expect(w.pcm, pcm);
      expect(wavPcm(Uint8List.fromList(List.filled(60, 7))), isNull);
    });

    test('a live talk starts with the character voice and the rules', () {
      final b = loadBundle();
      final mio = b.tutors.first;
      final setup = liveSetup('models/live', mio.geminiVoice, 'Be kind.')['setup'] as Map;
      expect(setup['model'], 'models/live');
      expect(((((setup['generationConfig'] as Map)['speechConfig'] as Map)['voiceConfig'] as Map)['prebuiltVoiceConfig']
          as Map)['voiceName'], 'Aoede');
      expect('${setup['systemInstruction']}', contains('Be kind.'));
      expect(b.tutors.map((t) => t.geminiVoice).toList(), ['Aoede', 'Puck', 'Kore', 'Zephyr', 'Charon']);
      expect(pcmLoudness(tone(16000, 100, 10000)), greaterThan(5000));
      expect(pcmLoudness(Uint8List(3200)), 0);
    });
      test('breaths are quiet, short and end in silence', () {
      final b = breathPcm(24000, seed: 3);
      final s = breathPcm(24000, sigh: true, seed: 3);
      expect(b.length ~/ 2, lessThan(24000 * 0.5));
      expect(s.length, greaterThan(b.length));
      final peak = pcmLoudness(s);
      expect(peak, greaterThan(50));
      expect(peak, lessThan(2500)); // far quieter than a voice
      final end = ByteData.sublistView(b).getInt16(b.length - 2, Endian.little);
      expect(end, 0);
      expect(breathPcm(24000, seed: 3), b); // same seed, same sound
    });

    test('live waits for the child to finish talking', () {
      final setup = liveSetup('m', 'Puck', 'rules')['setup'] as Map;
      final vad = (setup['realtimeInputConfig'] as Map)['automaticActivityDetection'] as Map;
      expect(vad['endOfSpeechSensitivity'], 'END_SENSITIVITY_LOW');
      expect(vad['silenceDurationMs'], greaterThanOrEqualTo(800));
    });
});
}
