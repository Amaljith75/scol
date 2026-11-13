// Curriculum content: everything the app teaches comes from one bundle file
// built from the content/ folder. No lesson text lives in the app code.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String rawBase = 'https://raw.githubusercontent.com/Amaljith75/scol/main/';
const String contentUrl = '${rawBase}app/assets/content/bundle.json';

/// Picks the right language from "text" or {"en": .., "ml": ..}.
String pick(dynamic text, String lang) {
  if (text is String) return text;
  if (text is Map && text.isNotEmpty) {
    final v = text[lang] ?? text['en'] ?? text.values.first;
    return v?.toString() ?? '';
  }
  return '';
}

/// A tutor character. Defined in content/_app/tutors.json.
class TutorCharacter {
  const TutorCharacter({
    required this.id,
    required this.name,
    required this.shape,
    required this.color,
    required this.voice,
    this.eyes = 'round',
    this.energy = 1.0,
    this.rate = '+0%',
    this.pitch = '+0Hz',
    this.about,
    this.hello,
    this.praise,
    this.oops,
    this.cheer,
  });
  final String id;
  final dynamic name;
  final String shape; // blob | spiky | cloud | flower | bean
  final int color;
  /// Ready-made voice per language, e.g. {'en': 'en-IN-…Neural'}; empty means the phone's own voice.
  final Map<String, String> voice;
  final String eyes; // round | wide | soft | curious | sleepy
  final double energy;
  final String rate; // speaking speed for the Edge voice, e.g. '-6%'
  final String pitch; // e.g. '+4Hz'
  final dynamic about;
  final dynamic hello;
  final dynamic praise;
  final dynamic oops;
  final dynamic cheer;

  String displayName(String lang) => pick(name, lang);

  String voiceFor(String lang) => voice[lang] ?? '';

  List<String> praiseList(String lang) {
    final p = praise;
    if (p is Map) {
      final l = p[lang] ?? p['en'];
      if (l is List && l.isNotEmpty) return l.map((e) => '$e').toList();
    }
    return const ['Well done!'];
  }

  factory TutorCharacter.fromJson(Map<String, dynamic> j) {
    final hex = (j['color'] as String? ?? '#FFB81F').replaceAll('#', '');
    return TutorCharacter(
      id: j['id'] as String? ?? 'tutor',
      name: j['name'],
      shape: j['shape'] as String? ?? 'blob',
      color: (int.tryParse(hex, radix: 16) ?? 0xFFB81F) | 0xFF000000,
      voice: switch (j['voice']) {
        Map v => v.map((k, x) => MapEntry('$k', '$x')),
        String v when v.isNotEmpty => {'en': v, 'ml': v},
        _ => const {},
      },
      eyes: j['eyes'] as String? ?? 'round',
      energy: (j['energy'] as num?)?.toDouble() ?? 1.0,
      rate: j['rate'] as String? ?? '+0%',
      pitch: j['pitch'] as String? ?? '+0Hz',
      about: j['about'],
      hello: j['hello'],
      praise: j['praise'],
      oops: j['oops'],
      cheer: j['cheer'],
    );
  }
}

const fallbackTutor = TutorCharacter(id: 'minnu', name: 'Mio', shape: 'blob', color: 0xFFFFB81F, voice: {});

class LessonStep {
  LessonStep({
    required this.type,
    required this.text,
    this.visual,
    this.form = '',
    this.options = const [],
    this.optionsMl = const [],
    this.answer = '',
    this.hint,
    this.explain,
    this.concept = '',
    this.level = 1,
    this.mistakes = const {},
    this.label = '',
  });

  final String type; // say | ask
  final dynamic text;
  final Map<String, dynamic>? visual;
  final String form; // choice | number | think | abacus | measure | build
  final List<String> options;
  final List<String> optionsMl;
  final String answer;
  final dynamic hint;
  final dynamic explain;
  final String concept;
  final int level;
  final Map<String, String> mistakes;
  final String label;

  bool get isAsk => type == 'ask';

  bool isCorrect(String given) => given.trim().toLowerCase() == answer.trim().toLowerCase();

  /// What to show on the button for option [i] in the given language.
  String optionLabel(int i, String lang) =>
      (lang == 'ml' && optionsMl.length == options.length) ? optionsMl[i] : options[i];

  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
        type: j['t'] as String? ?? 'say',
        text: j['text'],
        visual: (j['visual'] as Map?)?.cast<String, dynamic>(),
        form: j['form'] as String? ?? '',
        options: ((j['options'] as List?) ?? const []).map((e) => '$e').toList(),
        optionsMl: ((j['optionsMl'] as List?) ?? const []).map((e) => '$e').toList(),
        answer: '${j['answer'] ?? ''}',
        hint: j['hint'],
        explain: j['explain'],
        concept: j['concept'] as String? ?? '',
        level: (j['level'] as num?)?.toInt() ?? 1,
        mistakes: ((j['mistakes'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
        label: j['label'] as String? ?? '',
      );
}

class Lesson {
  Lesson({required this.id, required this.title, required this.steps, this.objective, this.minutes = 5, this.alts = const {}});
  final String id;
  final dynamic title;
  final dynamic objective;
  final int minutes;
  final List<LessonStep> steps;

  /// Other ways to explain this lesson's idea: 'story' and/or 'picture'.
  final Map<String, LessonStep> alts;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: j['title'],
        objective: j['objective'],
        minutes: (j['minutes'] as num?)?.toInt() ?? 5,
        alts: ((j['alts'] as Map?) ?? const {}).map((k, v) => MapEntry(
            '$k', LessonStep.fromJson({...(v as Map).cast<String, dynamic>(), 't': 'say', 'label': '$k'}))),
        steps: ((j['steps'] as List?) ?? const [])
            .map((e) => LessonStep.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class Chapter {
  Chapter({required this.id, required this.title, required this.verified, required this.lessons});
  final String id;
  final dynamic title;
  final bool verified;
  final List<Lesson> lessons;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'] as String,
        title: j['title'],
        verified: j['verified'] == true,
        lessons: ((j['lessons'] as List?) ?? const [])
            .map((e) => Lesson.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class Subject {
  Subject(
      {required this.id,
      required this.key,
      required this.name,
      required this.icon,
      required this.color,
      required this.chapters,
      this.palette = const []});
  final String id;
  final String key;
  final dynamic name;
  final String icon;
  final int color;
  final List<Chapter> chapters;

  /// One colour per chapter (repeats if there are more chapters).
  final List<int> palette;

  List<Lesson> get lessons => [for (final c in chapters) ...c.lessons];

  factory Subject.fromJson(Map<String, dynamic> j) {
    final hex = (j['color'] as String? ?? '#5B6CFF').replaceAll('#', '');
    return Subject(
      id: j['id'] as String,
      key: j['key'] as String? ?? '',
      name: j['name'],
      icon: j['icon'] as String? ?? '📘',
      color: (int.tryParse(hex, radix: 16) ?? 0x5B6CFF) | 0xFF000000,
      palette: ((j['palette'] as List?) ?? const [])
          .map((e) => (int.tryParse('$e'.replaceAll('#', ''), radix: 16) ?? 0x5B6CFF) | 0xFF000000)
          .toList(),
      chapters: ((j['chapters'] as List?) ?? const [])
          .map((e) => Chapter.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class SchoolClass {
  SchoolClass({required this.number, required this.subjects});
  final int number;
  final List<Subject> subjects;
}

class Board {
  Board({required this.id, required this.name, required this.classes});
  final String id;
  final dynamic name;
  final List<SchoolClass> classes;
}

class Bundle {
  Bundle({required this.version, required this.built, required this.boards, required this.concepts,
      this.tutors = const [fallbackTutor], this.phrases = const {}, this.brain = const {}});
  final String version;
  final int built;
  final List<Board> boards;
  final Map<String, dynamic> concepts;
  final List<TutorCharacter> tutors;
  final Map<String, dynamic> phrases;

  /// Where the live tutor brain is: {'url': ..., 'public_key': ...}. Never a secret key.
  final Map<String, dynamic> brain;

  /// A line the tutor says, e.g. phrase('tryLater', 'ml').
  String phrase(String key, String lang) => pick(phrases[key], lang);

  TutorCharacter tutor(String id) => tutors.firstWhere((t) => t.id == id, orElse: () => tutors.first);

  factory Bundle.empty() => Bundle(version: '', built: 0, boards: const [], concepts: const {});

  factory Bundle.parse(String source) {
    final j = (jsonDecode(source) as Map).cast<String, dynamic>();
    final ts = ((j['tutors'] as List?) ?? const [])
        .map((e) => TutorCharacter.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return Bundle(
      tutors: ts.isEmpty ? const [fallbackTutor] : ts,
      phrases: ((j['phrases'] as Map?) ?? const {}).cast<String, dynamic>(),
      brain: ((j['brain'] as Map?) ?? const {}).cast<String, dynamic>(),
      version: j['version'] as String? ?? '',
      built: (j['built'] as num?)?.toInt() ?? 0,
      concepts: ((j['concepts'] as Map?) ?? const {}).cast<String, dynamic>(),
      boards: ((j['boards'] as List?) ?? const []).map((b) {
        final bj = (b as Map).cast<String, dynamic>();
        return Board(
          id: bj['id'] as String,
          name: bj['name'],
          classes: ((bj['classes'] as List?) ?? const []).map((c) {
            final cj = (c as Map).cast<String, dynamic>();
            return SchoolClass(
              number: (cj['number'] as num).toInt(),
              subjects: ((cj['subjects'] as List?) ?? const [])
                  .map((s) => Subject.fromJson((s as Map).cast<String, dynamic>()))
                  .toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Board? board(String id) {
    for (final b in boards) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Subject> subjectsFor(String boardId, int classNumber) {
    final b = board(boardId);
    if (b == null) return const [];
    for (final c in b.classes) {
      if (c.number == classNumber) return c.subjects;
    }
    return const [];
  }

  String conceptName(String key, String lang) {
    final n = pick(concepts[key], lang);
    return n.isNotEmpty ? n : key.split('#').last.replaceAll('-', ' ');
  }
}

/// Loads the lessons shipped inside the app, then quietly looks for a newer
/// copy online so new chapters appear without reinstalling.
class ContentStore extends ChangeNotifier {
  Bundle bundle = Bundle.empty();
  static const _cacheKey = 'content_cache_v1';

  Future<void> load() async {
    bundle = Bundle.parse(await rootBundle.loadString('assets/content/bundle.json'));
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final c = Bundle.parse(cached);
        if (c.built > bundle.built) bundle = c;
      }
    } catch (_) {
      // A broken cache must never stop the app from opening.
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final res = await http.get(Uri.parse(contentUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final body = utf8.decode(res.bodyBytes);
      final fresh = Bundle.parse(body);
      if (fresh.built > bundle.built && fresh.boards.isNotEmpty) {
        bundle = fresh;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, body);
        notifyListeners();
      }
    } catch (_) {
      // Offline is fine: keep using the lessons we already have.
    }
  }
}
