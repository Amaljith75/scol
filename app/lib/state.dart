// The child's profile and progress. Stored only on this device.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'mastery.dart';

int dayNumber([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2020)).inDays;
}

class AppState extends ChangeNotifier {
  static const _key = 'scol_profile_v1';

  bool onboarded = false;
  String childName = '';
  String boardId = '';
  int classNumber = 3;
  String lang = 'en'; // en | ml | both
  String tutorId = 'minnu';
  bool voiceOn = true;
  int dailyLimitMin = 30;
  List<String> subjectKeys = [];

  int stars = 0;
  int xp = 0;
  int streak = 0;
  int bestStreak = 0;
  int learningDays = 0;
  int lastActiveDay = 0;
  int today = 0;
  int todaySeconds = 0;
  int todayLessons = 0;
  final Map<String, int> lessonStars = {}; // lesson id -> best stars (1-3)
  final Map<String, ConceptRecord> concepts = {};

  /// What each recent day held: day number -> [seconds learned, levels finished].
  final Map<int, List<int>> history = {};

  /// How often each other way of explaining worked: 'story' -> [worked, tried].
  final Map<String, List<int>> styleStats = {};

  /// Language used for speaking and for the main line of text.
  String get mainLang => lang == 'ml' ? 'ml' : 'en';
  bool get bilingual => lang == 'both';
  bool get timeUp => todaySeconds >= dailyLimitMin * 60;
  int get dailyGoal => 2;

  void _rollDay() {
    final d = dayNumber();
    if (today != d) {
      today = d;
      todaySeconds = 0;
      todayLessons = 0;
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) _fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      // Start fresh rather than crash on unreadable data.
    }
    _rollDay();
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_toJson()));
    } catch (_) {}
  }

  Future<void> eraseEverything() async {
    final fresh = AppState();
    _fromJson(fresh._toJson());
    lessonStars.clear();
    concepts.clear();
    history.clear();
    styleStats.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
    notifyListeners();
  }

  ConceptRecord concept(String key) => concepts.putIfAbsent(key, () => ConceptRecord());

  void addLearningTime(int seconds) {
    _rollDay();
    todaySeconds += seconds;
    (history[today] ??= [0, 0])[0] += seconds;
    history.removeWhere((d, _) => d < today - 40);
  }

  /// Which other way of explaining to try: one not tried yet, else the one that has worked most often.
  String pickStyle(List<String> available) {
    for (final s in available) {
      if ((styleStats[s]?[1] ?? 0) == 0) return s;
    }
    double rate(String s) => styleStats[s]![0] / styleStats[s]![1];
    return available.reduce((a, b) => rate(b) > rate(a) ? b : a);
  }

  void recordStyle(String style, bool worked) {
    final st = styleStats[style] ??= [0, 0];
    st[1]++;
    if (worked) st[0]++;
  }

  /// 'story' or 'picture' once there is enough evidence that one helps this child more; else null.
  String? get bestStyle {
    final tried = styleStats.values.fold<int>(0, (a, v) => a + v[1]);
    if (tried < 3 || styleStats.isEmpty) return null;
    String? best;
    var bestRate = 0.0;
    styleStats.forEach((k, v) {
      final r = v[1] == 0 ? 0.0 : v[0] / v[1];
      if (r > bestRate) {
        bestRate = r;
        best = k;
      }
    });
    return best;
  }

  /// Totals for the last 7 days: [days learned, minutes, levels].
  List<int> get week {
    final t = dayNumber();
    var days = 0, secs = 0, levels = 0;
    history.forEach((d, v) {
      if (d > t - 7 && d <= t && (v[0] > 0 || v[1] > 0)) {
        days++;
        secs += v[0];
        levels += v[1];
      }
    });
    return [days, (secs / 60).ceil(), levels];
  }

  /// Called when a lesson is finished. Returns true if this is a new streak day.
  bool finishLesson(String lessonId, int earnedStars, int earnedXp) {
    _rollDay();
    final before = lessonStars[lessonId] ?? 0;
    if (earnedStars > before) {
      stars += earnedStars - before;
      lessonStars[lessonId] = earnedStars;
    }
    xp += earnedXp;
    todayLessons++;
    (history[today] ??= [0, 0])[1]++;
    var newDay = false;
    if (lastActiveDay != today) {
      newDay = true;
      learningDays++;
      // A missed day never takes anything away: the streak simply starts again.
      streak = (lastActiveDay == today - 1) ? streak + 1 : 1;
      if (streak > bestStreak) bestStreak = streak;
      lastActiveDay = today;
    }
    save();
    return newDay;
  }

  /// The streak shown to the child (0 if they have not learned today or yesterday).
  int get liveStreak => (lastActiveDay >= dayNumber() - 1) ? streak : 0;

  // ---- What should we learn next? ----

  List<Subject> mySubjects(Bundle b) {
    final all = b.subjectsFor(boardId, classNumber);
    if (subjectKeys.isEmpty) return all;
    return all.where((s) => subjectKeys.contains(s.key)).toList();
  }

  bool isDone(Lesson l) => lessonStars.containsKey(l.id);

  Lesson? nextLesson(Subject s) {
    for (final l in s.lessons) {
      if (!isDone(l)) return l;
    }
    return null;
  }

  /// Concepts in this subject that should come back for revision.
  List<String> weakConcepts(Subject s) {
    final keys = <String>{};
    for (final l in s.lessons) {
      for (final st in l.steps) {
        if (st.isAsk && concepts[st.concept]?.needsRevision(dayNumber()) == true) keys.add(st.concept);
      }
    }
    return keys.toList();
  }

  /// A short practice lesson built from questions on weak concepts.
  Lesson? revisionLesson(Subject s) {
    final weak = weakConcepts(s).toSet();
    if (weak.isEmpty) return null;
    final qs = [
      for (final l in s.lessons.where(isDone))
        for (final st in l.steps)
          if (st.isAsk && weak.contains(st.concept)) st
    ];
    if (qs.isEmpty) return null;
    qs.shuffle();
    return Lesson(
      id: '${s.id}/revision',
      title: const {'en': 'Practice time', 'ml': 'പരിശീലന സമയം'},
      steps: [
        LessonStep(type: 'say', text: const {
          'en': 'Some of these were tricky last time. Let us try them again, slowly.',
          'ml': 'കഴിഞ്ഞ തവണ ഇവയിൽ ചിലത് അല്പം പ്രയാസമായിരുന്നു. നമുക്ക് പതുക്കെ ഒന്നുകൂടി നോക്കാം.',
        }),
        ...qs.take(5),
      ],
    );
  }

  Map<String, dynamic> _toJson() => {
        'onboarded': onboarded,
        'childName': childName,
        'boardId': boardId,
        'classNumber': classNumber,
        'lang': lang,
        'tutorId': tutorId,
        'voiceOn': voiceOn,
        'dailyLimitMin': dailyLimitMin,
        'subjectKeys': subjectKeys,
        'stars': stars,
        'xp': xp,
        'streak': streak,
        'bestStreak': bestStreak,
        'learningDays': learningDays,
        'lastActiveDay': lastActiveDay,
        'today': today,
        'todaySeconds': todaySeconds,
        'todayLessons': todayLessons,
        'lessonStars': lessonStars,
        'concepts': concepts.map((k, v) => MapEntry(k, v.toJson())),
        'history': history.map((k, v) => MapEntry('$k', v)),
        'styleStats': styleStats,
      };

  void _fromJson(Map<String, dynamic> j) {
    onboarded = j['onboarded'] == true;
    childName = j['childName'] as String? ?? '';
    boardId = j['boardId'] as String? ?? '';
    classNumber = (j['classNumber'] as num?)?.toInt() ?? 3;
    lang = j['lang'] as String? ?? 'en';
    tutorId = j['tutorId'] as String? ?? 'minnu';
    voiceOn = j['voiceOn'] != false;
    dailyLimitMin = (j['dailyLimitMin'] as num?)?.toInt() ?? 30;
    subjectKeys = ((j['subjectKeys'] as List?) ?? const []).map((e) => '$e').toList();
    stars = (j['stars'] as num?)?.toInt() ?? 0;
    xp = (j['xp'] as num?)?.toInt() ?? 0;
    streak = (j['streak'] as num?)?.toInt() ?? 0;
    bestStreak = (j['bestStreak'] as num?)?.toInt() ?? 0;
    learningDays = (j['learningDays'] as num?)?.toInt() ?? 0;
    lastActiveDay = (j['lastActiveDay'] as num?)?.toInt() ?? 0;
    today = (j['today'] as num?)?.toInt() ?? 0;
    todaySeconds = (j['todaySeconds'] as num?)?.toInt() ?? 0;
    todayLessons = (j['todayLessons'] as num?)?.toInt() ?? 0;
    lessonStars.clear();
    ((j['lessonStars'] as Map?) ?? const {}).forEach((k, v) => lessonStars['$k'] = (v as num).toInt());
    history.clear();
    ((j['history'] as Map?) ?? const {}).forEach((k, v) {
      final d = int.tryParse('$k');
      if (d != null && v is List && v.length == 2) history[d] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
    });
    styleStats.clear();
    ((j['styleStats'] as Map?) ?? const {}).forEach((k, v) {
      if (v is List && v.length == 2) styleStats['$k'] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
    });
    concepts.clear();
    ((j['concepts'] as Map?) ?? const {}).forEach(
        (k, v) => concepts['$k'] = ConceptRecord.fromJson((v as Map).cast<String, dynamic>()));
  }
}

// One shared copy of each for the whole app.
final AppState appState = AppState();
final ContentStore contentStore = ContentStore();

List<TutorCharacter> get tutors => contentStore.bundle.tutors;
TutorCharacter tutorById(String id) => contentStore.bundle.tutor(id);
