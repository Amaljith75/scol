// Every word on the app's own buttons and labels, in English and Malayalam.
// (Lesson text is not here: it comes from the content/ folder.)
const Map<String, List<String>> _s = {
  'hi': ['Hi', 'ഹായ്'],
  'go': ["Let's go!", 'തുടങ്ങാം!'],
  'next': ['Next', 'അടുത്തത്'],
  'start': ['START', 'തുടങ്ങൂ'],
  'hint': ['Hint', 'സൂചന'],
  'check': ['Check', 'നോക്കാം'],
  'showAnswer': ['Show answer', 'ഉത്തരം കാണിക്കൂ'],
  'gotIt': ['I got it', 'എനിക്ക് കിട്ടി'],
  'notYet': ['Not yet', 'ഇനിയും വേണം'],
  'continue': ['Continue', 'തുടരൂ'],
  'done': ['Done', 'കഴിഞ്ഞു'],
  'back': ['Back', 'പിന്നോട്ട്'],
  'subjects': ['My subjects', 'എന്റെ വിഷയങ്ങൾ'],
  'todayGoal': ["Today's goal", 'ഇന്നത്തെ ലക്ഷ്യം'],
  'lessons': ['lessons', 'പാഠങ്ങൾ'],
  'comingSoon': ['Lessons are on the way!', 'പാഠങ്ങൾ ഉടൻ വരും!'],
  'practice': ['Practice time', 'പരിശീലന സമയം'],
  'nextUp': ['Next for you', 'അടുത്തത്'],
  'allDone': ['You finished everything here. Amazing!', 'ഇവിടെയുള്ളതെല്ലാം നീ പൂർത്തിയാക്കി. അടിപൊളി!'],
  'timeUp': [
    'That is enough learning for today. See you tomorrow!',
    'ഇന്നത്തേക്ക് ഇത്രയും മതി. നാളെ കാണാം!'
  ],
  'lessonDone': ['Lesson complete!', 'പാഠം പൂർത്തിയായി!'],
  'stars': ['stars', 'നക്ഷത്രങ്ങൾ'],
  'dayStreak': ['day streak', 'ദിവസം തുടർച്ചയായി'],
  'parents': ['Parents', 'രക്ഷിതാക്കൾ'],
  'rewards': ['Rewards', 'സമ്മാനങ്ങൾ'],
  'answerIs': ['The answer is', 'ഉത്തരം'],
  'lookAgain': ['Look at it once more, slowly.', 'പതുക്കെ ഒന്നുകൂടി നോക്കൂ.'],
  'tryLater': ['We will try this one again in a little while.', 'ഇത് നമുക്ക് കുറച്ചു കഴിഞ്ഞ് ഒന്നുകൂടി നോക്കാം.'],
  'again': ['Remember this one? Let us try again.', 'ഇത് ഓർമ്മയുണ്ടോ? ഒന്നുകൂടി നോക്കാം.'],
  'think': ['Think about it, then tap the button.', 'ആലോചിച്ചിട്ട് ബട്ടൺ അമർത്തൂ.'],
  'example': ['Example', 'ഉദാഹരണം'],
  'locked': ['Finish the lesson before this one first.', 'ഇതിന് മുമ്പുള്ള പാഠം ആദ്യം പൂർത്തിയാക്കൂ.'],
};

String tr(String key, String lang) {
  final v = _s[key];
  if (v == null) return key;
  return lang == 'ml' ? v[1] : v[0];
}
