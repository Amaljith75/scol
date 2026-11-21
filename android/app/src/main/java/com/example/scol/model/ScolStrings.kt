package com.example.scol.model

// Direct port of app/lib/strings.dart (SCOL Build 8)
private val stringsMap: Map<String, Pair<String, String>> = mapOf(
    "hi" to ("Hi" to "ഹായ്"),
    "go" to ("Let's go!" to "തുടങ്ങാം!"),
    "next" to ("Next" to "അടുത്തത്"),
    "start" to ("START" to "തുടങ്ങൂ"),
    "hint" to ("Hint" to "സൂചന"),
    "check" to ("Check" to "നോക്കാം"),
    "showAnswer" to ("Show answer" to "ഉത്തരം കാണിക്കൂ"),
    "gotIt" to ("I got it" to "എനിക്ക് കിട്ടി"),
    "notYet" to ("Not yet" to "ഇനിയും വേണം"),
    "continue" to ("Continue" to "തുടരൂ"),
    "done" to ("Done" to "കഴിഞ്ഞു"),
    "back" to ("Back" to "പിന്നോട്ട്"),
    "subjects" to ("My subjects" to "എന്റെ വിഷയങ്ങൾ"),
    "todayGoal" to ("Today's goal" to "ഇന്നത്തെ ലക്ഷ്യം"),
    "lessons" to ("lessons" to "പാഠങ്ങൾ"),
    "comingSoon" to ("Lessons are on the way!" to "പാഠങ്ങൾ ഉടൻ വരും!"),
    "practice" to ("Practice time" to "പരിശീലന സമയം"),
    "nextUp" to ("Next for you" to "അടുത്തത്"),
    "allDone" to ("You finished everything here. Amazing!" to "ഇവിടെയുള്ളതെല്ലാം നീ പൂർത്തിയാക്കി. അടിപൊളി!"),
    "timeUp" to (
        "That is enough learning for today. See you tomorrow!" to
            "ഇന്നത്തേക്ക് ഇത്രയും മതി. നാളെ കാണാം!"
    ),
    "lessonDone" to ("Level complete!" to "ലെവൽ പൂർത്തിയായി!"),
    "level" to ("Level" to "ലെവൽ"),
    "stars" to ("stars" to "നക്ഷത്രങ്ങൾ"),
    "dayStreak" to ("day streak" to "ദിവസം തുടർച്ചയായി"),
    "parents" to ("Parents" to "രക്ഷിതാക്കൾ"),
    "rewards" to ("Rewards" to "സമ്മാനങ്ങൾ"),
    "answerIs" to ("The answer is" to "ഉത്തരം"),
    "lookAgain" to ("Look at it once more, slowly." to "പതുക്കെ ഒന്നുകൂടി നോക്കൂ."),
    "tryLater" to ("We will try this one again in a little while." to "ഇത് നമുക്ക് കുറച്ചു കഴിഞ്ഞ് ഒന്നുകൂടി നോക്കാം."),
    "again" to ("Remember this one? Let us try again." to "ഇത് ഓർമ്മയുണ്ടോ? ഒന്നുകൂടി നോക്കാം."),
    "think" to ("Think about it, then tap Show answer." to "ആലോചിച്ചിട്ട് 'ഉത്തരം കാണിക്കൂ' അമർത്തൂ."),
    "example" to ("Example" to "ഉദാഹരണം"),
    "story" to ("A little story" to "ഒരു കൊച്ചു കഥ"),
    "picture" to ("Look at it this way" to "ഇങ്ങനെ നോക്കൂ"),
    "home" to ("Home" to "ഹോം"),
    "dragSticks" to ("Drag a stick onto a shape" to "ഒരു ഈർക്കിൽ രൂപത്തിലേക്ക് വലിച്ചിടൂ"),
    "moveBeads" to ("Tap or drag on a rod to move beads" to "മണികൾ നീക്കാൻ കമ്പിയിൽ തൊടുകയോ വലിക്കുകയോ ചെയ്യൂ"),
    "askTitle" to ("Ask a question" to "ഒരു ചോദ്യം ചോദിക്കൂ"),
    "askOff" to (
        "Ask a grown-up to turn on \"Ask questions\" in the Parents section first." to
            "ആദ്യം രക്ഷിതാക്കളുടെ ഭാഗത്ത് \"ചോദ്യങ്ങൾ ചോദിക്കാം\" ഓണാക്കാൻ മുതിർന്നവരോട് പറയൂ."
    ),
    "askPrompt" to ("Ask {name} anything about this lesson!" to "ഈ പാഠത്തെക്കുറിച്ച് {name}-നോട് എന്തും ചോദിക്കൂ!"),
    "askListening" to ("I am listening..." to "ഞാൻ കേൾക്കുന്നു..."),
    "askThinking" to ("Let me think..." to "ഞാൻ ആലോചിക്കട്ടെ..."),
    "askType" to ("Or type your question" to "അല്ലെങ്കിൽ ചോദ്യം ടൈപ്പ് ചെയ്യൂ"),
    "askNoMic" to (
        "Speaking is not available on this phone. You can type instead." to
            "ഈ ഫോണിൽ സംസാരിച്ച് ചോദിക്കാൻ പറ്റില്ല. ടൈപ്പ് ചെയ്യാം."
    ),
    "ask" to ("Ask" to "ചോദിക്കൂ"),
    "endTalk" to ("End" to "നിർത്തൂ"),
    "listenTutor" to ("Listen" to "കേൾക്കൂ"),
    "myProgress" to ("How am I doing?" to "ഞാൻ എങ്ങനെയുണ്ട്?"),
    "explainMore" to ("Explain more" to "വിശദമാക്കൂ"),
    "newLessons" to ("New lessons have arrived!" to "പുതിയ പാഠങ്ങൾ എത്തി!"),
    "slideScale" to ("Drag the scale left or right" to "സ്കെയിൽ ഇടത്തോട്ടോ വലത്തോട്ടോ വലിക്കൂ"),
    "locked" to ("Finish the lesson before this one first." to "ഇതിന് മുമ്പുള്ള പാഠം ആദ്യം പൂർത്തിയാക്കൂ."),
    "liveTutor" to ("Live" to "ലൈവ്"),
    "liveWatchingBoard" to ("Live · Watching your lesson board" to "ലൈവ് · ബോർഡ് കാണുന്നുണ്ട്"),
    "liveWatchingCamera" to ("Live · Watching camera" to "ലൈവ് · ക്യാമറ കാണുന്നുണ്ട്"),
    "liveConnecting" to ("Connecting live tutor..." to "കണക്റ്റ് ചെയ്യുന്നു..."),
    "liveNeedKey" to ("API key needed in Secrets" to "Secrets-ൽ API കീ ചേർക്കൂ"),
    "liveReady" to ("Ready to tutor live" to "തയ്യാറാണ്"),
    "liveKeyHint" to (
        "Add GEMINI_API_KEY in the AI Studio Secrets panel to start Gemini Live voice & vision tutoring." to
            "ജെമിനി ലൈവ് വോയ്‌സ് & വിഷൻ ഉപയോഗിക്കാൻ AI Studio Secrets-ൽ GEMINI_API_KEY ചേർക്കൂ."
    ),
    "boardVision" to ("Board" to "ബോർഡ്"),
    "cameraVision" to ("Camera" to "ക്യാമറ"),
    "lessonOnlyBadge" to ("Lesson-only tutor" to "പാഠഭാഗം മാത്രം"),
    "explainSee" to ("Explain what you see" to "കാണുന്നത് വിവരിക്കൂ"),
    "askLessonType" to ("Ask about this lesson..." to "ഈ പാഠത്തെക്കുറിച്ച് ചോദിക്കൂ...")
)

fun tr(key: String, lang: String): String {
    val pair = stringsMap[key] ?: return key
    return if (lang == "ml") pair.second else pair.first
}
