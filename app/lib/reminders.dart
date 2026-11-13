// Study reminders, like a friendly tutor knocking on the door:
//  * every day at the study time the parent chose (skipped once today's goal is done),
//  * a streak nudge two hours later if nothing was learned that day,
//  * "come back" calls if the app has not been opened for a couple of days,
//  * a call back soon after a child leaves a level halfway.
// All are planned on the phone each time the app opens; nothing is sent anywhere.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'content.dart';
import 'state.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

const _channel = AndroidNotificationDetails('study', 'Study reminders',
    channelDescription: 'Reminders to learn with your tutor', importance: Importance.high, priority: Priority.high);
const _details = NotificationDetails(android: _channel);

// ids: 100-106 daily, 200-206 streak, 300-301 miss you, 400 left mid-level
const _leftId = 400;

Future<void> initReminders() async {
  if (kIsWeb || _ready) return;
  try {
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  } catch (_) {}
}

/// Asks Android for permission to show notifications (Android 13 and later).
Future<void> askReminderPermission() async {
  if (!_ready) return;
  try {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (_) {}
}

Future<void> _at(int id, DateTime when, String title, String body) async {
  if (when.isBefore(DateTime.now().add(const Duration(minutes: 1)))) return;
  await _plugin.zonedSchedule(id, title, body, tz.TZDateTime.from(when, tz.UTC), _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
}

/// The lines for one reminder. Kept short and kind: no guilt, no pressure.
List<String> reminderLines(String kind, String tutor, String child, int streak, String lang, Random r) {
  final ml = lang == 'ml';
  final who = child.isEmpty ? (ml ? 'കൂട്ടുകാരാ' : 'friend') : child;
  final pools = <String, List<List<String>>>{
    'daily': ml
        ? [
            ['$tutor കാത്തിരിക്കുന്നു 📚', 'ഹായ് $who! പഠിക്കാനുള്ള സമയമായി. ഇന്നത്തെ ലെവൽ നമുക്ക് ഒരുമിച്ച് ചെയ്യാം.'],
            ['ക്ലാസ് സമയം! ✨', '$tutor നിനക്കായി ഒരു പുതിയ ലെവൽ ഒരുക്കിയിട്ടുണ്ട്, $who.'],
            ['ഒരു ചെറിയ പാഠം? 🌟', '5 മിനിറ്റ് മതി, $who. $tutor റെഡിയാണ്!'],
          ]
        : [
            ['$tutor is waiting for you 📚', 'Hi $who! It is study time. Shall we do today\'s level together?'],
            ['Class time! ✨', '$tutor has a new level ready for you, $who.'],
            ['Just 5 minutes? 🌟', 'A quick level with $tutor, $who. Ready when you are!'],
          ],
    'streak': ml
        ? [
            ['നിന്റെ $streak ദിവസത്തെ 🔥', 'ഇന്ന് ഒരു ലെവൽ ചെയ്താൽ തീ കെടാതെ നിൽക്കും, $who!'],
            ['🔥 തീ കാത്തുസൂക്ഷിക്കാം!', '$tutor പറയുന്നു: ഒരു ചെറിയ ലെവൽ മതി!'],
          ]
        : [
            ['Keep your 🔥 $streak-day streak!', 'One small level today keeps the fire going, $who!'],
            ['Your streak misses you 🔥', '$tutor says: just one quick level tonight?'],
          ],
    'miss': ml
        ? [
            ['$tutor-ന് നിന്നെ മിസ് ചെയ്യുന്നു 🥺', 'തിരിച്ചു വാ, $who! ഒരു രസകരമായ ലെവൽ കാത്തിരിക്കുന്നു.'],
            ['ഹലോ? ആരെങ്കിലും ഉണ്ടോ? 👀', '$tutor ഇവിടെ ചുറ്റിത്തിരിയുന്നു, നിന്നെയും കാത്ത്.'],
          ]
        : [
            ['$tutor misses you 🥺', 'Come back, $who! A fun level is waiting.'],
            ['Hello? Anyone there? 👀', '$tutor is floating around the app, waiting for you.'],
            ['Psst, $who! 🤫', '$tutor found something amazing to show you. Come and see!'],
          ],
    'left': ml
        ? [
            ['ലെവൽ പകുതിയായി! ⏸️', '$tutor നിന്നെ കാത്തിരിക്കുന്നു. ബാക്കി പൂർത്തിയാക്കാമോ?'],
          ]
        : [
            ['You were halfway there! ⏸️', '$tutor is waiting to finish the level with you.'],
            ['Come back! 🏃', '$tutor saved your place. Just a few more questions!'],
          ],
  };
  final pool = pools[kind]!;
  return pool[r.nextInt(pool.length)];
}

/// Plans the next week of reminders from scratch.
Future<void> planReminders(AppState a, Bundle b) async {
  if (!_ready) return;
  try {
    for (final id in [for (var i = 0; i < 7; i++) ...[100 + i, 200 + i], 300, 301]) {
      await _plugin.cancel(id);
    }
    if (!a.remindersOn || !a.onboarded) return;
    final r = Random();
    final tutor = b.tutor(a.tutorId).displayName(a.mainLang);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 0; d < 7; d++) {
      final day = today.add(Duration(days: d));
      final at = day.add(Duration(minutes: a.studyMinute));
      if (!(d == 0 && a.goalDoneToday)) {
        final l = reminderLines('daily', tutor, a.childName, a.streak, a.mainLang, r);
        await _at(100 + d, at, l[0], l[1]);
      }
      if (!(d == 0 && a.learnedToday) && a.streak > 0) {
        final l = reminderLines('streak', tutor, a.childName, d == 0 ? a.liveStreak : a.streak, a.mainLang, r);
        await _at(200 + d, at.add(const Duration(hours: 2)), l[0], l[1]);
      }
    }
    for (final (i, days) in [(0, 2), (1, 4)]) {
      final l = reminderLines('miss', tutor, a.childName, a.streak, a.mainLang, r);
      final when = today.add(Duration(days: days, hours: 15, minutes: r.nextInt(150)));
      await _at(300 + i, when, l[0], l[1]);
    }
  } catch (_) {}
}

/// The child left a level halfway: call them back in a few minutes.
Future<void> remindLeftLevel(AppState a, Bundle b) async {
  if (!_ready || !a.remindersOn) return;
  try {
    final l = reminderLines('left', b.tutor(a.tutorId).displayName(a.mainLang), a.childName, a.streak, a.mainLang, Random());
    await _at(_leftId, DateTime.now().add(const Duration(minutes: 5, seconds: 30)), l[0], l[1]);
  } catch (_) {}
}

Future<void> cancelLeftLevel() async {
  if (!_ready) return;
  try {
    await _plugin.cancel(_leftId);
  } catch (_) {}
}
