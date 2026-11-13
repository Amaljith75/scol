// The tutor creatures, drawn in code so they are fully our own artwork.
// Their bodies wobble like jelly and their eyes are alive: they follow where
// the tutor is going, look at the board while teaching, look at the child
// while talking, and glance at wherever the child touches the screen.
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../content.dart';
import '../tutor.dart';

/// The outline of each creature: how far the edge is from the centre at angle [a].
double creatureRadius(String shape, double a, double t) {
  final wobble = 0.035 * sin(3 * a + t * 2 * pi) + 0.025 * sin(2 * a - t * 4 * pi);
  switch (shape) {
    case 'spiky':
      return 0.70 + 0.30 * pow(cos(4 * a + 0.4).abs(), 2.2).toDouble() + wobble * 0.6;
    case 'cloud':
      return 0.80 + 0.17 * sin(3 * a + 0.5).abs() + wobble * 0.5;
    case 'flower':
      return 0.70 + 0.28 * cos(2.5 * a).abs() + wobble * 0.5;
    case 'bean':
      // wider than tall
      final squash = 1 / sqrt(cos(a) * cos(a) + (sin(a) / 0.76) * (sin(a) / 0.76));
      return squash * 0.96 + wobble;
    default:
      return 0.86 + 0.07 * sin(3 * a + 1.0) + 0.05 * sin(2 * a + 2.0) + wobble * 1.6;
  }
}

Path creaturePath(String shape, Offset c, double r, double t) {
  final path = Path();
  const n = 96;
  for (var i = 0; i <= n; i++) {
    final a = i / n * 2 * pi;
    final rr = r * creatureRadius(shape, a, t);
    final p = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// The tutor flies between screens: from the home card to the level path and
/// into the classroom, along a curved path, with a little spin on the way.
Widget tutorHero(Widget child) => Hero(
      tag: 'tutor',
      createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
      flightShuttleBuilder: (context, animation, direction, from, to) => AnimatedBuilder(
        animation: animation,
        child: (direction == HeroFlightDirection.push ? to : from).widget,
        builder: (_, c) => Transform.rotate(angle: sin(animation.value * pi) * 0.35, child: c),
      ),
      child: child,
    );

class TutorAvatar extends StatefulWidget {
  const TutorAvatar({
    super.key,
    required this.tutor,
    this.size = 96,
    this.talking = false,
    this.mood = Mood.calm,
    this.gaze = Offset.zero,
    this.float = false,
  });
  final TutorCharacter tutor;
  final double size;
  final bool talking;
  final Mood mood;

  /// Where to look: (-1,-1) is up-left, (1,1) is down-right, (0,0) is at the child.
  final Offset gaze;

  /// Drift gently from side to side, as if floating in the air.
  final bool float;

  @override
  State<TutorAvatar> createState() => _TutorAvatarState();
}

class _TutorAvatarState extends State<TutorAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  final Random _rnd = Random();
  Offset _eyes = Offset.zero; // where the pupils are now
  Offset? _glance; // a short look at something that just happened
  int _glanceUntil = 0;
  Offset _wander = Offset.zero;
  int _nextWander = 0;
  int _nextBlink = 0;
  int _blinkUntil = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void didUpdateWidget(covariant TutorAvatar old) {
    super.didUpdateWidget(old);
    if (old.gaze != widget.gaze) _glance = null; // a new instruction wins over a glance
  }

  void _onPointer(PointerEvent e) {
    if (e is! PointerDownEvent || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final centre = box.localToGlobal(box.size.center(Offset.zero));
    final d = e.position - centre;
    if (d.distance < widget.size * 0.4) return;
    _glance = d / max(d.distance, 1.0);
    _glanceUntil = DateTime.now().millisecondsSinceEpoch + 900;
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_glance != null && now > _glanceUntil) _glance = null;
    if (now > _nextWander) {
      // tiny eye movements so the creature never looks frozen
      _wander = Offset(_rnd.nextDouble() - 0.5, _rnd.nextDouble() - 0.5) * 0.35;
      _nextWander = now + 900 + _rnd.nextInt(2200);
    }
    if (now > _nextBlink) {
      _blinkUntil = now + 130;
      _nextBlink = now + 1800 + _rnd.nextInt(3500);
    }
    var target = _glance ?? widget.gaze;
    if (target.distance > 1) target = target / target.distance;
    target += _wander * (target == Offset.zero ? 1.0 : 0.3);
    _eyes += (target - _eyes) * 0.16;
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final e = widget.tutor.energy;
        final hop = widget.mood == Mood.happy ? 0.10 : 0.035;
        final bob = -(sin(t * 2 * pi * (e > 1.4 ? 2 : 1)).abs()) * widget.size * hop * e.clamp(0.6, 1.6).toDouble();
        final now = DateTime.now().millisecondsSinceEpoch;
        return Transform.translate(
          offset: Offset(widget.float ? sin(t * 2 * pi) * widget.size * 0.06 : 0, bob + widget.size * 0.04),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _CreaturePainter(
              tutor: widget.tutor,
              t: t,
              eyes: _eyes,
              blink: now < _blinkUntil,
              mouthOpen: widget.talking && ((t * 14).floor().isEven),
              mood: widget.mood,
            ),
          ),
        );
      },
    );
  }
}

class _CreaturePainter extends CustomPainter {
  _CreaturePainter({
    required this.tutor,
    required this.t,
    required this.eyes,
    required this.blink,
    required this.mouthOpen,
    required this.mood,
  });
  final TutorCharacter tutor;
  final double t;
  final Offset eyes;
  final bool blink;
  final bool mouthOpen;
  final Mood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final body = Color(tutor.color);
    const dark = Color(0xFF23243A);
    final fill = Paint()..style = PaintingStyle.fill;

    // soft shadow on the floor
    canvas.drawOval(Rect.fromCenter(center: Offset(s / 2, s * 0.97), width: s * 0.5, height: s * 0.06),
        fill..color = const Color(0x22000000));
    // body
    final path = creaturePath(tutor.shape, c, s * 0.46, t);
    canvas.drawPath(path, fill..color = body);
    // a lighter patch, like light falling on jelly
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(Offset(s * 0.34, s * 0.26), s * 0.24, fill..color = const Color(0x33FFFFFF));
    canvas.restore();

    // eyes
    final style = tutor.eyes;
    final eyeR = s * (style == 'wide' ? 0.125 : (style == 'soft' ? 0.085 : 0.105));
    final gap = s * (tutor.shape == 'bean' ? 0.17 : 0.14);
    final eyeY = s * 0.46;
    final lookShift = Offset(eyes.dx * s * 0.03, eyes.dy * s * 0.025); // the whole face leans a little
    for (final side in [-1, 1]) {
      var r = eyeR;
      if (style == 'curious' && side == 1) r = eyeR * 1.22;
      final centre = Offset(s / 2 + side * gap, eyeY) + lookShift;
      if (blink) {
        canvas.drawLine(
            centre.translate(-r * 0.8, 0),
            centre.translate(r * 0.8, 0),
            Paint()
              ..color = dark
              ..strokeWidth = s * 0.03
              ..strokeCap = StrokeCap.round);
        continue;
      }
      canvas.drawCircle(centre, r, fill..color = Colors.white);
      final pupilR = r * 0.58;
      final pupil = centre + Offset(eyes.dx, eyes.dy) * (r - pupilR) * 0.95;
      canvas.drawCircle(pupil, pupilR, fill..color = dark);
      canvas.drawCircle(pupil.translate(pupilR * 0.3, -pupilR * 0.35), pupilR * 0.3, fill..color = Colors.white);
      if (style == 'sleepy') {
        // a heavy eyelid
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(centre.dx - r * 1.2, centre.dy - r * 1.2, centre.dx + r * 1.2, centre.dy - r * 0.15));
        canvas.drawCircle(centre, r * 1.06, fill..color = body);
        canvas.restore();
        canvas.drawLine(
            centre.translate(-r * 1.0, -r * 0.15),
            centre.translate(r * 1.0, -r * 0.15),
            Paint()
              ..color = dark
              ..strokeWidth = s * 0.02
              ..strokeCap = StrokeCap.round);
      }
    }

    // mouth
    final mouth = Offset(s / 2, s * 0.64) + lookShift;
    if (mouthOpen) {
      canvas.drawOval(Rect.fromCenter(center: mouth, width: s * 0.11, height: s * 0.09), fill..color = dark);
    } else {
      final w = mood == Mood.happy ? s * 0.2 : s * 0.13;
      canvas.drawArc(
          Rect.fromCenter(center: mouth.translate(0, -s * 0.035), width: w, height: s * 0.11),
          0.12 * pi,
          0.76 * pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.03
            ..strokeCap = StrokeCap.round
            ..color = dark);
    }
  }

  @override
  bool shouldRepaint(covariant _CreaturePainter old) => true;
}
