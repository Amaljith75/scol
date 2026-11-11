import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scol/content.dart';
import 'package:scol/widgets/ui.dart';
import 'package:scol/widgets/visuals.dart';

void main() {
  testWidgets('every picture in every lesson fits on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final b = Bundle.parse(File('assets/content/bundle.json').readAsStringSync());
    final seen = <String>{};
    final problems = <String>[];
    for (final board in b.boards) {
      for (final c in board.classes) {
        for (final s in c.subjects) {
          for (final l in s.lessons) {
            for (final st in l.steps) {
              final v = st.visual;
              if (v == null || v['kind'] == 'image' || !seen.add('$v')) continue;
              await tester.pumpWidget(MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SingleChildScrollView(child: SoftCard(key: ValueKey('$v'), child: VisualView(v))),
                    ),
                  ),
                ),
              ));
              await tester.pump(const Duration(seconds: 6));
              final e = tester.takeException();
              if (e != null) problems.add('${l.id}: $v -> $e');
            }
          }
        }
      }
    }
    expect(problems, isEmpty);
    expect(seen.length, greaterThan(40));
  });
}
