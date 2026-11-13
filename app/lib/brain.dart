// The tutor brain on our server: it teaches each lesson in the tutor's own
// words, and ("Ask Mio") answers a question the child asks by voice or typing.
// The app only knows the server's public address; the AI key and the choice of
// AI model live on the server.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';

class BrainAnswer {
  BrainAnswer(this.text, {this.ok = true});
  final String text;
  final bool ok;
}

/// A random id for this phone, so the server can limit questions per phone.
/// It says nothing about who the child is.
Future<String> deviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id == null) {
    final r = Random.secure();
    id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
    await prefs.setString('device_id', id);
  }
  return id;
}

const _sorry = {
  'offline': [
    'I need the internet to answer questions. Let us try again when we are online.',
    'ചോദ്യങ്ങൾക്ക് ഉത്തരം പറയാൻ എനിക്ക് ഇന്റർനെറ്റ് വേണം. ഓൺലൈനാകുമ്പോൾ വീണ്ടും ചോദിക്കൂ.'
  ],
  'limit': [
    'We asked lots of questions today! Let us ask more tomorrow.',
    'ഇന്ന് നമ്മൾ ഒരുപാട് ചോദ്യങ്ങൾ ചോദിച്ചു! ബാക്കി നാളെ ചോദിക്കാം.'
  ],
  'error': [
    'Hmm, I could not think of an answer just now. Can you ask your teacher, or try again?',
    'ഇപ്പോൾ ഉത്തരം കിട്ടിയില്ല. ടീച്ചറോട് ചോദിക്കാമോ, അല്ലെങ്കിൽ വീണ്ടും ശ്രമിക്കൂ?'
  ],
};

String sorry(String kind, String lang) => _sorry[kind]![lang == 'ml' ? 1 : 0];

/// Asks the tutor brain. [notes] is what the lesson on screen is teaching,
/// so the answer stays about the lesson. Never sends the child's name.
Future<BrainAnswer> askBrain({
  required Bundle bundle,
  required String question,
  required String lang,
  required String tutorName,
  required String lessonTitle,
  required String notes,
  String tone = 'normal',
  http.Client? client,
}) async {
  final url = '${bundle.brain['url'] ?? ''}';
  if (url.isEmpty) return BrainAnswer(sorry('error', lang), ok: false);
  try {
    final res = await (client ?? http.Client())
        .post(
          Uri.parse(url),
          headers: {'content-type': 'application/json', 'apikey': '${bundle.brain['public_key'] ?? ''}'},
          body: jsonEncode({
            'question': question,
            'lang': lang,
            'tutor': tutorName,
            'lesson': lessonTitle,
            'notes': notes,
            'tone': tone,
            'device': await deviceId(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 429) return BrainAnswer(sorry('limit', lang), ok: false);
    if (res.statusCode != 200) return BrainAnswer(sorry('error', lang), ok: false);
    final answer = '${(jsonDecode(utf8.decode(res.bodyBytes)) as Map)['answer'] ?? ''}'.trim();
    return answer.isEmpty ? BrainAnswer(sorry('error', lang), ok: false) : BrainAnswer(answer);
  } catch (_) {
    return BrainAnswer(sorry('offline', lang), ok: false);
  }
}

// ---------------- Teaching a whole lesson ----------------

/// A teaching step as the brain sees it: the written line plus what is on the board.
Map<String, dynamic> _teachStep(LessonStep s, String lang) {
  final v = s.visual;
  return {
    't': s.isAsk ? 'ask' : 'say',
    'text': pick(s.text, lang),
    if (v != null) 'visual': '${v['kind']} ${((v['args'] as List?) ?? const []).join(' ')}'.trim(),
    if (s.label.isNotEmpty) 'label': s.label,
    if (s.isAsk) 'form': s.form,
    if (s.isAsk) 'answer': s.answer,
    if (s.isAsk && s.options.isNotEmpty) 'options': s.options,
  };
}

/// What is sent to the brain so it can teach [lesson] in [lang]. Only lesson text, never anything about the child.
Map<String, dynamic> teachRequest(Lesson lesson, String lang, TutorCharacter tutor, String tone) => {
      'mode': 'teach',
      'lang': lang,
      'tutor': tutor.displayName('en'),
      'about': pick(tutor.about, 'en'),
      'tone': tone,
      'lesson': pick(lesson.title, 'en'),
      'objective': pick(lesson.objective, 'en'),
      'steps': [for (final s in lesson.steps) _teachStep(s, lang)],
    };

/// One teaching step as the brain wrote it: what the tutor says, and which numbered
/// items on the board it floats to and touches while saying it (1-based, in order).
class Taught {
  const Taught(this.say, [this.touch = const []]);
  final String say;
  final List<int> touch;

  static Taught? from(dynamic v) {
    if (v is String) return v.trim().isEmpty ? null : Taught(v.trim());
    if (v is Map) {
      final say = '${v['say'] ?? v['text'] ?? ''}'.trim();
      if (say.isEmpty) return null;
      final touch = [
        for (final x in (v['touch'] as List?) ?? const [])
          if (x is num && x >= 1) x.toInt() else if (int.tryParse('$x') != null && int.parse('$x') >= 1) int.parse('$x')
      ];
      return Taught(say, touch.take(8).toList());
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'say': say, 'touch': touch};

  @override
  bool operator ==(Object other) => other is Taught && other.say == say && '${other.touch}' == '$touch';

  @override
  int get hashCode => Object.hash(say, '$touch');
}

/// Lines the brain wrote, lined up with [lesson.steps]: a [Taught] for each "say" step, null for questions.
/// Returns null (use the written lines) if the list does not fit the lesson.
List<Taught?>? alignTeaching(Lesson lesson, List<dynamic>? written) {
  if (written == null) return null;
  final says = lesson.steps.where((s) => !s.isAsk).length;
  if (written.length != says) return null;
  var i = 0;
  final out = <Taught?>[];
  for (final s in lesson.steps) {
    if (s.isAsk) {
      out.add(null);
    } else {
      final t = Taught.from(written[i++]);
      if (t == null) return null;
      out.add(t);
    }
  }
  return out;
}

/// The same lesson, language, tutor and mood always give the same key, so a lesson is written once.
String teachKey(Lesson lesson, String lang, TutorCharacter tutor, String tone) =>
    sha1.convert(utf8.encode(jsonEncode(teachRequest(lesson, lang, tutor, tone)))).toString().substring(0, 24);

const _teachCacheKey = 'teach_cache_v2';
const _teachCacheMax = 80;

Future<List<Taught?>?> _teachFromCache(String key, Lesson lesson) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_teachCacheKey);
    if (raw == null) return null;
    final all = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return alignTeaching(lesson, all[key] as List?);
  } catch (_) {
    return null;
  }
}

Future<void> _teachToCache(String key, List<dynamic> written) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_teachCacheKey);
    final all = raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map).cast<String, dynamic>();
    all.remove(key);
    all[key] = written;
    while (all.length > _teachCacheMax) {
      all.remove(all.keys.first); // the oldest
    }
    await prefs.setString(_teachCacheKey, jsonEncode(all));
  } catch (_) {}
}

/// Asks the tutor brain to teach [lesson]: what the tutor says at every "say"
/// step, in its own words, in [lang], as [tutor] in the parent's chosen [tone],
/// and what it touches on the board meanwhile.
/// Kept on the phone, so a lesson is fetched once and then works offline.
/// Returns null when the brain cannot help; the lesson's own lines are used then.
Future<List<Taught?>?> teachLesson({
  required Bundle bundle,
  required Lesson lesson,
  required String lang,
  required TutorCharacter tutor,
  String tone = 'normal',
  http.Client? client,
}) async {
  if (lesson.steps.every((s) => s.isAsk)) return null;
  final key = teachKey(lesson, lang, tutor, tone);
  final cached = await _teachFromCache(key, lesson);
  if (cached != null) return cached;
  final url = '${bundle.brain['url'] ?? ''}';
  if (url.isEmpty) return null;
  try {
    final res = await (client ?? http.Client())
        .post(
          Uri.parse(url),
          headers: {'content-type': 'application/json', 'apikey': '${bundle.brain['public_key'] ?? ''}'},
          body: jsonEncode({...teachRequest(lesson, lang, tutor, tone), 'device': await deviceId()}),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) return null;
    final written = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['steps'] as List?;
    final aligned = alignTeaching(lesson, written);
    if (aligned != null) await _teachToCache(key, written!);
    return aligned;
  } catch (_) {
    return null;
  }
}
