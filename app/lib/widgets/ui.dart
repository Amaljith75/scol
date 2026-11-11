// Shared look and feel: colours, chunky buttons, cards.
import 'package:flutter/material.dart';

// Brand colours. Violet is Scol's own colour and is used for everything that
// belongs to the app itself: main buttons, the bar at the bottom, the tutor's
// card. Chapters and topics each get their own colour from [chapterColors].
const violet = Color(0xFF7B5CFA);
const violetDeep = Color(0xFF5B3FD6);
const violetSoft = Color(0xFFEDE7FF);
const cream = Color(0xFFF8F5FF); // page background: a very light lavender
const ink = Color(0xFF2A2350);
const indigo = violet; // older name, same brand colour
const coral = Color(0xFFFF6B5E);
const mint = Color(0xFF2BB673);
const sun = Color(0xFFFFC233);
const cloud = Color(0xFFE7E1F5);

/// One colour per chapter, repeating if a subject has more chapters.
const chapterColors = [
  Color(0xFFFF8A3D), // orange
  Color(0xFF2FA8F5), // sky
  Color(0xFF2BB673), // green
  Color(0xFFE5488B), // pink
  Color(0xFF19B5A5), // teal
  Color(0xFFF2A413), // amber
];

Color darker(Color c, [double amount = 0.18]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0).toDouble()).toColor();
}

/// A big, friendly button with a solid "3D" bottom edge. Large enough for small fingers.
class Chunky extends StatefulWidget {
  const Chunky({super.key, required this.child, required this.onTap, this.color = indigo, this.padding, this.radius = 20});
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets? padding;
  final double radius;

  @override
  State<Chunky> createState() => _ChunkyState();
}

class _ChunkyState extends State<Chunky> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : cloud;
    final lift = _down || !enabled ? 0.0 : 5.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.only(top: 5 - lift),
        padding: EdgeInsets.only(bottom: lift),
        decoration: BoxDecoration(color: darker(c), borderRadius: BorderRadius.circular(widget.radius)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(widget.radius)),
          child: DefaultTextStyle.merge(
            style: TextStyle(
                color: enabled ? Colors.white : const Color(0xFF9A948A), fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cloud, width: 2),
        ),
        child: child,
      );
}

/// Small pill such as "🔥 3" or "⭐ 12".
class Pill extends StatelessWidget {
  const Pill(this.emoji, this.text, {super.key});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: cloud, width: 2)),
        child: Text('$emoji $text', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
      );
}
