// Pictures the tutor can put on the board. Each one is described in a lesson
// file with a single line such as "visual: groups 3 4 🥭".
import 'package:flutter/material.dart';

import '../content.dart';
import 'ui.dart';

class VisualView extends StatelessWidget {
  const VisualView(this.visual, {super.key});
  final Map<String, dynamic> visual;

  @override
  Widget build(BuildContext context) {
    final kind = visual['kind'] as String? ?? '';
    final args = ((visual['args'] as List?) ?? const []).map((e) => '$e').toList();
    int n(int i) => i < args.length ? (int.tryParse(args[i]) ?? 0) : 0;
    switch (kind) {
      case 'groups':
        final groups = n(0), each = n(1);
        final emoji = args.length > 2 ? args[2] : '●';
        final size = groups * each > 24 ? 20.0 : 28.0;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var g = 0; g < groups; g++)
              Container(
                padding: const EdgeInsets.all(8),
                constraints: BoxConstraints(maxWidth: size * 3.6 + 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1D6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: sun, width: 3),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [for (var i = 0; i < each; i++) Text(emoji, style: TextStyle(fontSize: size))],
                ),
              ),
          ],
        );
      case 'count':
        final emoji = args.length > 1 ? args[1] : '●';
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [for (var i = 0; i < n(0); i++) Text(emoji, style: const TextStyle(fontSize: 30))],
        );
      case 'numberline':
        final from = n(0), to = n(1);
        final mark = args.length > 2 ? n(2) : null;
        final span = (to - from).abs();
        final step = span <= 10 ? 1 : (span / 10).ceil();
        final ticks = [for (var v = from; v <= to; v += step) v];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final t in ticks)
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t == mark ? coral : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$t',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: t == mark ? Colors.white : ink)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(height: 6, decoration: BoxDecoration(color: indigo, borderRadius: BorderRadius.circular(3))),
          ],
        );
      case 'text':
        return FittedBox(
          child: Text(args.join(' '),
              style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: indigo)),
        );
      case 'emoji':
        return FittedBox(child: Text(args.join(' '), style: const TextStyle(fontSize: 72)));
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            '$rawBase${args.isEmpty ? '' : args.first}',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('🖼️', style: TextStyle(fontSize: 64)),
          ),
        );
    }
    return const SizedBox.shrink();
  }
}
