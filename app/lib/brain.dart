// "Ask Mio": the child asks a question by voice (or typing) and the tutor
// brain on our server answers. The app only knows the server's public address;
// the AI key and the choice of AI model live on the server.
import 'dart:convert';
import 'dart:math';

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
