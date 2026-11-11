// The opening animation: colour pours up the screen like liquid, the Scol
// creature rises out of it, looks around, and the name appears.
import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/avatar.dart';
import '../widgets/ui.dart';

const brandTop = Color(0xFFFF9A3D);
const brandBottom = Color(0xFFFF5C7A);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(size: Size.infinite, painter: _SplashPainter(_c.value)),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.t);
  final double t;

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 1. liquid colour rising
    final rise = Curves.easeInOutCubic.transform(_seg(0.0, 0.5));
    final level = h * (1.08 - rise * 1.2);
    final amp = h * 0.035 * (1 - rise * 0.7);
    final wave = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 8; x += 8) {
      final y = level + amp * sin(x / w * 2 * pi * 1.4 + t * 9) + amp * 0.5 * sin(x / w * 2 * pi * 2.6 - t * 13);
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
        wave,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [brandTop, brandBottom])
              .createShader(Offset.zero & size));

    // 2. the creature bobs up out of the liquid
    final up = Curves.elasticOut.transform(_seg(0.32, 0.8));
    final r = min(w, h) * 0.2;
    final c = Offset(w / 2, h * 0.46 + (1 - up) * (h * 0.6));
    if (t > 0.3) {
      final body = creaturePath('blob', c, r, t * 2.2);
      canvas.drawPath(body, Paint()..color = const Color(0xFFFFF6E9));
      // eyes glance left, then right, then at you
      final lookX = t < 0.62 ? -1.0 : (t < 0.78 ? 1.0 : 0.0);
      final lookY = t < 0.78 ? -0.2 : 0.0;
      final blink = t > 0.83 && t < 0.87;
      const dark = Color(0xFF23243A);
      for (final side in [-1, 1]) {
        final e = Offset(c.dx + side * r * 0.34, c.dy - r * 0.08);
        if (blink) {
          canvas.drawLine(
              e.translate(-r * 0.16, 0),
              e.translate(r * 0.16, 0),
              Paint()
                ..color = dark
                ..strokeWidth = r * 0.07
                ..strokeCap = StrokeCap.round);
          continue;
        }
        final p = e + Offset(lookX, lookY) * r * 0.07;
        canvas.drawCircle(p, r * 0.2, Paint()..color = dark);
        canvas.drawCircle(p.translate(r * 0.06, -r * 0.07), r * 0.06, Paint()..color = Colors.white);
      }
      canvas.drawArc(
          Rect.fromCenter(center: c.translate(0, r * 0.28), width: r * 0.42, height: r * 0.26),
          0.1 * pi,
          0.8 * pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round
            ..color = dark);
    }

    // 3. the name
    final fade = _seg(0.7, 0.9);
    if (fade > 0) {
      final tp = TextPainter(
        text: TextSpan(
            text: 'scol',
            style: TextStyle(
                color: Colors.white.withAlpha((255 * fade).round()),
                fontSize: r * 0.72,
                fontWeight: FontWeight.w900,
                letterSpacing: r * 0.04)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.46 + r * 1.25 + (1 - fade) * 16));
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) => old.t != t;
}
