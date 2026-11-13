// Tells the parent when a newer Scol app is ready on GitHub. (New lessons and
// voices arrive by themselves; only changes to the app itself need this.)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content.dart';

/// The newest build number on GitHub, read from app/pubspec.yaml ("version: 1.0.0+3").
int? parseBuild(String pubspec) {
  final m = RegExp(r'^version:\s*([\d.]+)\+(\d+)', multiLine: true).firstMatch(pubspec);
  return m == null ? null : int.tryParse(m.group(2)!);
}

String? _versionName(String pubspec) =>
    RegExp(r'^version:\s*([\d.]+)\+', multiLine: true).firstMatch(pubspec)?.group(1);

bool _asked = false;

Future<void> checkForAppUpdate(BuildContext context) async {
  if (kIsWeb || _asked) return;
  _asked = true;
  try {
    final info = await PackageInfo.fromPlatform();
    final mine = int.tryParse(info.buildNumber) ?? 0;
    final res = await http.get(Uri.parse('${rawBase}app/pubspec.yaml')).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return;
    final newest = parseBuild(res.body);
    final name = _versionName(res.body);
    if (newest == null || name == null || newest <= mine) return;
    final major = name.split('.').first;
    final apk = 'https://github.com/Amaljith75/scol/releases/download/v$name-build$newest/scol-v$major-build$newest.apk';
    // Only offer it once the new app has actually been built and published.
    final head = await http.head(Uri.parse(apk)).timeout(const Duration(seconds: 8));
    if (head.statusCode >= 400 || !context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A new Scol is ready'),
        content: Text('Version $major, build $newest is available. Download it now? '
            'Your child\'s progress stays on this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Update')),
        ],
      ),
    );
    if (go == true) await launchUrl(Uri.parse(apk), mode: LaunchMode.externalApplication);
  } catch (_) {
    // No internet or GitHub unreachable: try again next time.
  }
}
