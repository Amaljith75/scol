// Pictures the tutor can put on the board. Each one is described in a lesson
// file with a single line such as "visual: groups 3 4 🥭". Pieces pop in one
// after another so the picture builds up in front of the child.
import 'dart:math';

import 'package:flutter/material.dart';

import '../content.dart';
import 'ui.dart';

const _palette = [coral, indigo, mint, sun, Color(0xFFE5488B)];

/// Makes its child pop in, a little later for each next piece.
class Pop extends StatelessWidget {
  const Pop(this.index, {super.key, required this.child, this.gap = 60});
  final int index;
  final Widget child;
  final int gap;

  @override
  Widget build(BuildContext context) {
    final total = 380 + gap * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(gap * index / total, 1, curve: Curves.easeOutBack),
      builder: (_, v, c) => Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: v, child: c)),
      child: child,
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.name, this.color);
  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final edge = Paint()
      ..color = darker(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final path = Path();
    switch (name) {
      case 'circle':
        path.addOval(Rect.fromLTWH(3, 3, w - 6, h - 6));
      case 'triangle':
        path
          ..moveTo(w / 2, 4)
          ..lineTo(w - 4, h - 4)
          ..lineTo(4, h - 4)
          ..close();
      default:
        path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3, 3, w - 6, h - 6), const Radius.circular(4)));
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, edge);
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) => old.name != name || old.color != color;
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.maxCm);
  final int maxCm;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / (maxCm + 1);
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFFE9A8));
    final line = Paint()
      ..color = ink
      ..strokeWidth = 2;
    for (var i = 0; i <= maxCm; i++) {
      final x = unit * (i + 0.5);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.42), line);
      if (i < maxCm) {
        canvas.drawLine(Offset(x + unit / 2, 0), Offset(x + unit / 2, size.height * 0.22), line..strokeWidth = 1);
        line.strokeWidth = 2;
      }
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: TextStyle(color: ink, fontSize: min(13.0, unit * 0.62), fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height * 0.48));
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => old.maxCm != maxCm;
}

class _SplitLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = indigo
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 2, 2), Offset(size.width * 0.22, size.height - 2), p);
    canvas.drawLine(Offset(size.width / 2, 2), Offset(size.width * 0.78, size.height - 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Widget _chip(String text, {Color color = Colors.white, Color border = cloud, Color textColor = ink, double size = 22}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 3)),
      child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: textColor)),
    );

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
        final size = groups * each > 24 ? 18.0 : 28.0;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var g = 0; g < groups; g++)
              Pop(
                g,
                gap: 140,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  constraints: BoxConstraints(maxWidth: size * (each > 6 ? 6.2 : 3.6) + 16),
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
              ),
          ],
        );
      case 'count':
        final emoji = args.length > 1 ? args[1] : '●';
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [for (var i = 0; i < n(0); i++) Pop(i, child: Text(emoji, style: const TextStyle(fontSize: 30)))],
        );
      case 'array':
        final rows = n(0), cols = n(1);
        final emoji = args.length > 2 ? args[2] : '●';
        final size = cols > 5 ? 24.0 : 30.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows; r++)
              Pop(
                r,
                gap: 160,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < cols; c++)
                      Padding(padding: const EdgeInsets.all(2), child: Text(emoji, style: TextStyle(fontSize: size)))
                  ],
                ),
              ),
          ],
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
                for (var i = 0; i < ticks.length; i++)
                  Pop(
                    i,
                    child: Container(
                      width: 28,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ticks[i] == mark ? coral : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${ticks[i]}',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: ticks[i] == mark ? Colors.white : ink)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(height: 6, decoration: BoxDecoration(color: indigo, borderRadius: BorderRadius.circular(3))),
          ],
        );
      case 'shapes':
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < args.length; i++)
              Pop(
                i,
                gap: 120,
                child: CustomPaint(
                  size: Size(args[i] == 'rectangle' ? 84 : 58, 58),
                  painter: _ShapePainter(args[i], _palette[i % _palette.length]),
                ),
              ),
          ],
        );
      case 'sticks':
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < n(0); i++)
              Pop(
                i,
                child: Transform.rotate(
                  angle: (i % 3 - 1) * 0.22,
                  child: Container(
                    width: 8,
                    height: 46,
                    decoration: BoxDecoration(color: const Color(0xFFB07A3B), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
          ],
        );
      case 'place':
        const labels = ['100', '10', '1'];
        const colors = [coral, indigo, mint];
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var p = 0; p < 3; p++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 44,
                    height: 150,
                    child: Stack(alignment: Alignment.bottomCenter, children: [
                      Container(width: 6, height: 150, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(3))),
                      Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        for (var b = 0; b < n(p); b++)
                          Pop(
                            p * 3 + (n(p) - b),
                            gap: 70,
                            child: Container(
                              width: 34,
                              height: 14,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(color: colors[p], borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                  Container(width: 56, height: 6, color: ink),
                  const SizedBox(height: 4),
                  Text(labels[p], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colors[p])),
                ]),
              ),
          ],
        );
      case 'notes':
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < args.length; i++)
              Pop(
                i,
                gap: 110,
                child: _chip('₹${args[i]}',
                    color: n(i) >= 100 ? const Color(0xFFD9F2E3) : (n(i) >= 10 ? const Color(0xFFFFE3D1) : const Color(0xFFFFF1B8)),
                    border: n(i) >= 100 ? mint : (n(i) >= 10 ? coral : sun),
                    size: 20),
              ),
          ],
        );
      case 'ruler':
        final len = n(0);
        final maxCm = max(10, len + 2);
        final emoji = args.length > 1 ? args[1] : '';
        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth.isFinite ? box.maxWidth : 320.0;
          final unit = w / (maxCm + 1);
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (emoji.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: unit * 0.5, bottom: 6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Container(
                    width: max(unit * len * v, 12.0),
                    height: 30,
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(color: _palette[len % _palette.length], borderRadius: BorderRadius.circular(8)),
                    child: v > 0.9 ? Text(emoji, style: const TextStyle(fontSize: 20)) : null,
                  ),
                ),
              ),
            CustomPaint(size: Size(w, 46), painter: _RulerPainter(maxCm)),
          ]);
        });
      case 'pattern':
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < args.length; i++)
              Pop(
                i,
                gap: 130,
                child: args[i] == '?'
                    ? _chip('?', color: const Color(0xFFFFF1B8), border: sun, textColor: coral)
                    : _chip(args[i], size: args[i].length > 3 ? 18 : 22),
              ),
          ],
        );
      case 'split':
        Widget part(String t, int i) => Pop(i,
            gap: 300,
            child: t == '?'
                ? _chip('?', color: const Color(0xFFFFF1B8), border: sun, textColor: coral, size: 26)
                : _chip(t, border: indigo, size: 26));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          part(args[0], 0),
          CustomPaint(size: const Size(150, 34), painter: _SplitLines()),
          Row(mainAxisSize: MainAxisSize.min, children: [part(args[1], 1), const SizedBox(width: 26), part(args[2], 2)]),
        ]);
      case 'steps':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < args.length; i++)
              Pop(
                i,
                gap: 650,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(args[i],
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: i == args.length - 1 && args.length > 1 ? coral : indigo)),
                  ),
                ),
              ),
          ],
        );
      case 'text':
        return Pop(0,
            child: FittedBox(
              child: Text(args.join(' '), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: indigo)),
            ));
      case 'emoji':
        return Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
          for (var i = 0; i < args.length; i++) Pop(i, gap: 200, child: Text(args[i], style: const TextStyle(fontSize: 64)))
        ]);
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
