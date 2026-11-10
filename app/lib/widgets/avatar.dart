// The tutor characters, drawn in code so they are fully our own artwork.
import 'dart:math';

import 'package:flutter/material.dart';

import '../tutor.dart';

class TutorAvatar extends StatefulWidget {
  const TutorAvatar({super.key, required this.tutor, this.size = 96, this.talking = false, this.mood = Mood.calm});
  final TutorCharacter tutor;
  final double size;
  final bool talking;
  final Mood mood;

  @override
  State<TutorAvatar> createState() => _TutorAvatarState();
}

class _TutorAvatarState extends State<TutorAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final bob = sin(t * 2 * pi) * widget.size * (widget.mood == Mood.happy ? 0.09 : 0.04);
        return Transform.translate(
          offset: Offset(0, bob),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _TutorPainter(
              id: widget.tutor.id,
              color: Color(widget.tutor.color),
              blink: t > 0.92,
              mouthOpen: widget.talking && ((t * 12).floor().isEven),
              happy: widget.mood == Mood.happy,
            ),
          ),
        );
      },
    );
  }
}

class _TutorPainter extends CustomPainter {
  _TutorPainter({required this.id, required this.color, required this.blink, required this.mouthOpen, required this.happy});
  final String id;
  final Color color;
  final bool blink;
  final bool mouthOpen;
  final bool happy;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fill = Paint()..style = PaintingStyle.fill;
    final dark = const Color(0xFF2B2D42);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..color = dark;

    if (id == 'tiko') {
      // Antenna
      canvas.drawLine(Offset(s * 0.5, s * 0.2), Offset(s * 0.5, s * 0.08), line);
      canvas.drawCircle(Offset(s * 0.5, s * 0.07), s * 0.05, fill..color = const Color(0xFFFF6B5E));
      // Ears
      fill.color = const Color(0xFF0E8C80);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.04, s * 0.42, s * 0.1, s * 0.22), Radius.circular(s * 0.04)), fill);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.86, s * 0.42, s * 0.1, s * 0.22), Radius.circular(s * 0.04)), fill);
      // Head and face plate
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.12, s * 0.2, s * 0.76, s * 0.68), Radius.circular(s * 0.2)),
          fill..color = color);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.21, s * 0.31, s * 0.58, s * 0.46), Radius.circular(s * 0.14)),
          fill..color = const Color(0xFFE6FFFB));
    } else {
      // Wings
      fill.color = const Color(0xCCBFE8FF);
      canvas.drawOval(Rect.fromLTWH(s * 0.02, s * 0.22, s * 0.36, s * 0.3), fill);
      canvas.drawOval(Rect.fromLTWH(s * 0.62, s * 0.22, s * 0.36, s * 0.3), fill);
      // Glowing tail
      canvas.drawCircle(Offset(s * 0.5, s * 0.82), s * 0.17, fill..color = const Color(0x55FFE066));
      canvas.drawCircle(Offset(s * 0.5, s * 0.82), s * 0.11, fill..color = const Color(0xFFFFE066));
      // Antennae
      canvas.drawLine(Offset(s * 0.4, s * 0.22), Offset(s * 0.33, s * 0.08), line);
      canvas.drawLine(Offset(s * 0.6, s * 0.22), Offset(s * 0.67, s * 0.08), line);
      canvas.drawCircle(Offset(s * 0.33, s * 0.07), s * 0.035, fill..color = dark);
      canvas.drawCircle(Offset(s * 0.67, s * 0.07), s * 0.035, fill..color = dark);
      // Body
      canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.32, fill..color = color);
      canvas.drawCircle(Offset(s * 0.33, s * 0.6), s * 0.05, fill..color = const Color(0x55FF6B5E));
      canvas.drawCircle(Offset(s * 0.67, s * 0.6), s * 0.05, fill..color = const Color(0x55FF6B5E));
    }

    // Eyes
    final eyeY = s * 0.47;
    for (final x in [s * 0.38, s * 0.62]) {
      if (blink) {
        canvas.drawLine(Offset(x - s * 0.05, eyeY), Offset(x + s * 0.05, eyeY), line);
      } else {
        canvas.drawCircle(Offset(x, eyeY), s * 0.075, fill..color = Colors.white);
        canvas.drawCircle(Offset(x, eyeY), s * 0.045, fill..color = dark);
        canvas.drawCircle(Offset(x + s * 0.015, eyeY - s * 0.02), s * 0.015, fill..color = Colors.white);
      }
    }
    // Mouth
    final mouth = Offset(s * 0.5, s * 0.62);
    if (mouthOpen) {
      canvas.drawOval(Rect.fromCenter(center: mouth, width: s * 0.12, height: s * 0.1), fill..color = dark);
    } else {
      final w = happy ? s * 0.22 : s * 0.15;
      canvas.drawArc(Rect.fromCenter(center: mouth.translate(0, -s * 0.03), width: w, height: s * 0.12), 0.15 * pi,
          0.7 * pi, false, line);
    }
  }

  @override
  bool shouldRepaint(covariant _TutorPainter old) =>
      old.blink != blink || old.mouthOpen != mouthOpen || old.happy != happy || old.id != id || old.color != color;
}
