// Things the child does with their fingers: move abacus beads, slide a scale
// under an object, and drag sticks to build a shape.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'ui.dart';
import 'visuals.dart';

// ---------------- Abacus ----------------

class AbacusPad extends StatelessWidget {
  const AbacusPad({super.key, required this.values, required this.onChanged});
  final List<int> values; // [hundreds, tens, ones]
  final ValueChanged<List<int>> onChanged;

  static const _labels = ['100', '10', '1'];
  static const _colors = [coral, violet, mint];
  static const _rodH = 190.0;
  static const _slot = _rodH / 9.5;

  void _set(int rod, double dy, {bool tap = false}) {
    var n = ((_rodH - dy) / _slot).ceil().clamp(0, 9).toInt();
    if (tap && n == values[rod]) n--; // tapping the top bead takes it off
    if (n != values[rod]) {
      final next = List<int>.of(values);
      next[rod] = n;
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _set(r, d.localPosition.dy, tap: true),
                onVerticalDragUpdate: (d) => _set(r, d.localPosition.dy),
                child: SizedBox(
                  width: 72,
                  height: _rodH,
                  child: Stack(alignment: Alignment.bottomCenter, children: [
                    Container(width: 7, height: _rodH, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4))),
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      for (var b = 0; b < values[r]; b++)
                        Container(
                          width: 54,
                          height: _slot - 3,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: _colors[r],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: darker(_colors[r]), width: 2),
                          ),
                        ),
                    ]),
                  ]),
                ),
              ),
              Container(width: 84, height: 7, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Text(_labels[r], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _colors[r])),
            ]),
          ),
      ]),
    );
  }
}

// ---------------- Sliding scale ----------------

class ScaleBoard extends StatefulWidget {
  const ScaleBoard({super.key, required this.length, this.emoji = ''});
  final int length; // how long the object is, in cm
  final String emoji;

  static const startAt = 2; // the object begins this many cm from the left

  @override
  State<ScaleBoard> createState() => _ScaleBoardState();
}

class _ScaleBoardState extends State<ScaleBoard> {
  double _shift = 0; // how far the scale has been slid, in cm

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 320.0;
        final unit = w / 13;
        const rulerCm = 14;
        return SizedBox(
          width: w,
          height: 118,
          child: ClipRect(
            child: Stack(children: [
              // the object, lying a little way from the left edge
              Positioned(
                left: unit * (ScaleBoard.startAt + 0.5),
                top: 6,
                child: Container(
                  width: unit * widget.length,
                  height: 34,
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(color: coral, borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              // the scale: drag it sideways
              AnimatedPositioned(
                duration: const Duration(milliseconds: 90),
                left: unit * _shift,
                top: 46,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _shift = (_shift + d.delta.dx / unit).clamp(-1.0, 6.0).toDouble()),
                  onHorizontalDragEnd: (_) => setState(() => _shift = _shift.roundToDouble()),
                  child: Column(children: [
                    CustomPaint(size: Size(unit * (rulerCm + 1), 50), painter: RulerPainter(rulerCm)),
                    const Text('↔', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: violet)),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

// ---------------- Building shapes with sticks ----------------

const _sides = {'triangle': 3, 'rectangle': 4, 'square': 4};

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.shape, this.placed, this.off);
  final String shape;
  final int placed;
  final bool off;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const m = 10.0;
    final pts = shape == 'triangle'
        ? [Offset(w / 2, m), Offset(w - m, h - m), Offset(m, h - m)]
        : [Offset(m, m), Offset(w - m, m), Offset(w - m, h - m), Offset(m, h - m)];
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      if (i < placed) {
        canvas.drawLine(
            a,
            b,
            Paint()
              ..color = const Color(0xFFB07A3B)
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round);
      } else {
        // an empty side, drawn as a dotted line
        final len = (b - a).distance;
        final dir = (b - a) / len;
        final p = Paint()
          ..color = off ? cloud : const Color(0xFFB9AEE0)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        for (var d = 0.0; d < len; d += 14) {
          canvas.drawLine(a + dir * d, a + dir * min(d + 7, len), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) => old.placed != placed || old.off != off || old.shape != shape;
}

class StickBuilder extends StatefulWidget {
  const StickBuilder({super.key, required this.options, required this.disabled, required this.onBuilt});
  final List<String> options; // shapes on offer, e.g. [triangle, rectangle]
  final Set<String> disabled; // shapes already tried and wrong
  final ValueChanged<String> onBuilt;

  @override
  State<StickBuilder> createState() => _StickBuilderState();
}

class _StickBuilderState extends State<StickBuilder> {
  final Map<String, int> _placed = {};
  Timer? _done;

  void _add(String shape) {
    if (widget.disabled.contains(shape) || _done != null) return;
    final need = _sides[shape] ?? 4;
    final now = (_placed[shape] ?? 0) + 1;
    if (now > need) return;
    setState(() => _placed[shape] = now);
    if (now == need) {
      _done = Timer(const Duration(milliseconds: 450), () {
        _done = null;
        if (!mounted) return;
        widget.onBuilt(shape);
        setState(() => _placed[shape] = 0); // if it was the wrong shape, the sticks go back
      });
    }
  }

  @override
  void dispose() {
    _done?.cancel();
    super.dispose();
  }

  Widget _stick({double angle = 0}) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 10,
          height: 52,
          decoration: BoxDecoration(color: const Color(0xFFB07A3B), borderRadius: BorderRadius.circular(5)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final used = _placed.values.fold<int>(0, (a, b) => a + b);
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final shape in widget.options)
            DragTarget<int>(
              onAcceptWithDetails: (_) => _add(shape),
              builder: (context, incoming, _) => GestureDetector(
                onTap: () => _add(shape),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: incoming.isNotEmpty ? violetSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CustomPaint(
                    size: Size(shape == 'rectangle' ? 128 : 96, 96),
                    painter: _OutlinePainter(shape, _placed[shape] ?? 0, widget.disabled.contains(shape)),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: i < 6 - used.clamp(0, 6)
                    ? Draggable<int>(
                        data: i,
                        feedback: _stick(angle: 0.5),
                        childWhenDragging: Opacity(opacity: 0.25, child: _stick()),
                        child: _stick(angle: (i % 3 - 1) * 0.18),
                      )
                    : const SizedBox(width: 10, height: 52),
              ),
          ]),
        ),
      ]),
    );
  }
}
