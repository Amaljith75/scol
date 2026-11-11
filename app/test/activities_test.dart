import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scol/widgets/activities.dart';

Future<void> show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: Center(child: child))),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('abacus beads move when a rod is tapped', (tester) async {
    var values = [0, 0, 0];
    await show(tester, StatefulBuilder(builder: (context, setState) {
      return AbacusPad(values: values, onChanged: (v) => setState(() => values = v));
    }));
    final rods = find.byType(GestureDetector);
    expect(rods, findsNWidgets(3));
    await tester.tapAt(tester.getBottomLeft(rods.at(0)) + const Offset(36, -50)); // third slot from the bottom
    await tester.pump();
    expect(values[0], 3);
    await tester.tapAt(tester.getBottomLeft(rods.at(2)) + const Offset(36, -10));
    await tester.pump();
    expect(values, [3, 0, 1]);
  });

  testWidgets('the scale slides and snaps to whole centimetres', (tester) async {
    await show(tester, const ScaleBoard(length: 6, emoji: 'x'));
    await tester.drag(find.byType(CustomPaint).last, const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filling a shape with sticks reports that shape', (tester) async {
    String? built;
    await show(tester, StickBuilder(options: const ['triangle', 'rectangle'], disabled: const {}, onBuilt: (s) => built = s));
    final triangle = find.byType(DragTarget<int>).first;
    for (var i = 0; i < 3; i++) {
      await tester.tap(triangle);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(built, 'triangle');
  });
}
