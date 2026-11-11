// The weekly report for parents, written in plain words in English or Malayalam.
// It is built on the phone from the child's own record; nothing is sent anywhere
// unless the parent presses Share.
import 'content.dart';
import 'mastery.dart';
import 'state.dart';

/// The report as short paragraphs (each one is also read aloud as one piece).
List<String> weeklyReport(AppState a, Bundle b, String lang) {
  final ml = lang == 'ml';
  final name = a.childName.isEmpty ? (ml ? 'കുട്ടി' : 'Your child') : a.childName;
  final w = a.week;
  final out = <String>[];

  out.add(ml ? '$name: ഈ ആഴ്ചയിലെ പഠന റിപ്പോർട്ട് (Scol)' : "$name's learning this week (Scol)");

  if (w[0] == 0) {
    out.add(ml
        ? 'ഈ ആഴ്ച $name Scol-ൽ പഠിച്ചിട്ടില്ല. ദിവസവും 10 മിനിറ്റ് മതി. ഒരുമിച്ച് ഒരു ലെവൽ ചെയ്തു തുടങ്ങാം.'
        : '$name has not used Scol this week. Ten minutes a day is enough. Try starting one level together.');
  } else {
    out.add(ml
        ? 'ഈ ആഴ്ച $name ${w[0]} ദിവസം പഠിച്ചു, ആകെ ഏകദേശം ${w[1]} മിനിറ്റ്. ${w[2]} ലെവലുകൾ പൂർത്തിയാക്കി. ഇതുവരെ ${a.stars} നക്ഷത്രങ്ങൾ നേടി.'
        : 'This week $name learned on ${w[0]} ${w[0] == 1 ? 'day' : 'days'}, about ${w[1]} minutes in all, '
            'and finished ${w[2]} ${w[2] == 1 ? 'level' : 'levels'}. Stars so far: ${a.stars}.');
  }

  final secure = <String>[], checking = <String>[], weak = <String>[];
  final repeated = <String>[];
  a.concepts.forEach((key, r) {
    final n = b.conceptName(key, lang);
    switch (r.status) {
      case Understanding.secure:
        secure.add(n);
      case Understanding.checking:
        checking.add(n);
      case Understanding.misconception:
        weak.add(n);
        final m = r.repeatedMistake;
        if (m != null) repeated.add(ml ? n : '$n ($m)');
      case Understanding.needsHelp:
        weak.add(n);
      case Understanding.notStarted:
        break;
    }
  });
  String list(List<String> xs) => xs.take(6).join(', ') + (xs.length > 6 ? (ml ? ' തുടങ്ങിയവ' : ' and more') : '');

  if (secure.isNotEmpty) {
    out.add(ml ? 'നന്നായി മനസ്സിലാക്കിയവ: ${list(secure)}.' : 'Understands well: ${list(secure)}.');
  }
  if (checking.isNotEmpty) {
    out.add(ml
        ? 'ശരിയായി വരുന്നുണ്ട്, കുറച്ചുകൂടി പരിശോധിക്കാനുണ്ട്: ${list(checking)}.'
        : 'Getting these right so far; Scol will check a few more times: ${list(checking)}.');
  }
  if (weak.isNotEmpty) {
    out.add(ml
        ? 'ഇനിയും പരിശീലനം വേണ്ടവ: ${list(weak)}. ഇവ Scol വീണ്ടും പഠിപ്പിക്കും.'
        : 'Still needs practice: ${list(weak)}. Scol will teach these again.');
  }
  if (repeated.isNotEmpty) {
    out.add(ml
        ? 'ഒരേ തെറ്റ് ആവർത്തിക്കുന്നത്: ${list(repeated)}. വീട്ടിൽ ചെറിയ സാധനങ്ങൾ വെച്ച് ഇത് ഒരുമിച്ച് ചെയ്തു നോക്കുന്നത് സഹായിക്കും.'
        : 'The same mistake keeps coming up in: ${list(repeated)}. Trying it together at home with small objects will help.');
  }
  if (secure.isEmpty && checking.isEmpty && weak.isEmpty) {
    out.add(ml
        ? 'എന്തെല്ലാം മനസ്സിലായി എന്ന് പറയാൻ ഇനിയും കുറച്ച് ലെവലുകൾ കൂടി വേണം.'
        : 'A few more levels are needed before Scol can say what has been understood.');
  }

  final style = a.bestStyle;
  if (style != null) {
    out.add(ml
        ? (style == 'story'
            ? '$name-ന് കഥകളിലൂടെ വിശദീകരിക്കുമ്പോഴാണ് കൂടുതൽ മനസ്സിലാകുന്നത്.'
            : '$name-ന് ചിത്രങ്ങളിലൂടെ വിശദീകരിക്കുമ്പോഴാണ് കൂടുതൽ മനസ്സിലാകുന്നത്.')
        : (style == 'story'
            ? '$name seems to understand best when an idea is told as a story.'
            : '$name seems to understand best when an idea is shown as a picture.'));
  }
  return out;
}
