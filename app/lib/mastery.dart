// How Scol decides whether a child really understands something.
// One right answer is never enough: we look at several answers, in more than
// one question style, and at the kind of mistakes that repeat.

enum Understanding { notStarted, needsHelp, misconception, checking, secure }

class ConceptRecord {
  int firstTry = 0; // right at the first attempt, without a hint
  int withHelp = 0; // right after a hint or a second try
  int failed = 0; // needed the answer explained
  int quick = 0; // right, but answered so fast it may be a guess
  int thinkYes = 0; // child said "I got it" on an open question
  int thinkNo = 0;
  int lastDay = 0;
  final Set<String> forms = {}; // question styles answered right at first try
  final Map<String, int> mistakes = {}; // mistake description -> times seen
  final List<int> recent = []; // last results: 1 = first-try right, 0 = not

  int get total => firstTry + withHelp + failed + quick;

  /// [outcome]: 'first' | 'help' | 'failed'. [millis] = time to answer.
  void record({
    required String form,
    required String outcome,
    required int day,
    int millis = 5000,
    List<String> mistakeNotes = const [],
  }) {
    lastDay = day;
    for (final m in mistakeNotes) {
      mistakes[m] = (mistakes[m] ?? 0) + 1;
    }
    if (form == 'think') {
      outcome == 'first' ? thinkYes++ : thinkNo++;
      return;
    }
    if (outcome == 'first' && form == 'choice' && millis < 1000) {
      quick++; // too fast to have read the question: do not count as proof
      return;
    }
    if (outcome == 'first') {
      firstTry++;
      forms.add(form);
    } else if (outcome == 'help') {
      withHelp++;
    } else {
      failed++;
    }
    recent.add(outcome == 'first' ? 1 : 0);
    if (recent.length > 6) recent.removeAt(0);
  }

  String? get repeatedMistake {
    String? best;
    var count = 1;
    mistakes.forEach((k, v) {
      if (v > count) {
        best = k;
        count = v;
      }
    });
    return best;
  }

  Understanding get status {
    if (total == 0 && thinkYes + thinkNo == 0) return Understanding.notStarted;
    final last3 = recent.length >= 3 ? recent.sublist(recent.length - 3) : recent;
    final last3Right = last3.length == 3 && last3.every((r) => r == 1);
    if (firstTry >= 3 && forms.length >= 2 && last3Right) return Understanding.secure;
    final last2Right = recent.length >= 2 && recent[recent.length - 1] == 1 && recent[recent.length - 2] == 1;
    if (repeatedMistake != null && !last2Right) return Understanding.misconception;
    if (recent.isNotEmpty && recent.last == 1) return Understanding.checking;
    if (recent.isEmpty && thinkYes > thinkNo) return Understanding.checking;
    return Understanding.needsHelp;
  }

  /// Should the tutor bring this back for revision today?
  bool needsRevision(int today) {
    final s = status;
    if (s == Understanding.needsHelp || s == Understanding.misconception) return true;
    return s == Understanding.secure && today - lastDay >= 7;
  }

  Map<String, dynamic> toJson() => {
        'f': firstTry,
        'h': withHelp,
        'x': failed,
        'q': quick,
        'ty': thinkYes,
        'tn': thinkNo,
        'd': lastDay,
        'forms': forms.toList(),
        'm': mistakes,
        'r': recent,
      };

  static ConceptRecord fromJson(Map<String, dynamic> j) {
    final r = ConceptRecord()
      ..firstTry = (j['f'] as num?)?.toInt() ?? 0
      ..withHelp = (j['h'] as num?)?.toInt() ?? 0
      ..failed = (j['x'] as num?)?.toInt() ?? 0
      ..quick = (j['q'] as num?)?.toInt() ?? 0
      ..thinkYes = (j['ty'] as num?)?.toInt() ?? 0
      ..thinkNo = (j['tn'] as num?)?.toInt() ?? 0
      ..lastDay = (j['d'] as num?)?.toInt() ?? 0;
    r.forms.addAll(((j['forms'] as List?) ?? const []).map((e) => '$e'));
    ((j['m'] as Map?) ?? const {}).forEach((k, v) => r.mistakes['$k'] = (v as num).toInt());
    r.recent.addAll(((j['r'] as List?) ?? const []).map((e) => (e as num).toInt()));
    return r;
  }
}
