import 'package:flutter/material.dart';
import '../../app/config/theme.dart';

/// Pieces of the "ticket stub" look: every event is drawn like the ticket you
/// get for it, with a tear-off date stub on the right.

/// One colour per category, shown as the ticket's left edge and its small label.
Color categoryColor(String? category, {bool dark = false}) {
  final base = switch (category) {
    'Music' => const Color(0xFFD6336C),
    'Tech' => const Color(0xFFE0312C),
    'Sports' => const Color(0xFF12925E),
    'Arts' => const Color(0xFFD98A00),
    'Academic' => const Color(0xFF2B5BFF),
    _ => const Color(0xFF6B5BD6),
  };
  // Lighter on dark cards so small text stays readable.
  return dark ? Color.lerp(base, Colors.white, 0.35)! : base;
}

/// Typewriter-style text for labels, times and ticket numbers.
TextStyle monoStyle({double size = 11, Color? color, FontWeight weight = FontWeight.w400, double spacing = 0.6}) =>
    TextStyle(fontFamily: AppTheme.monoFamily, fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing, height: 1.3);

/// A card shaped like a ticket: [child] on the left, a tear-off [stub] on the
/// right, two punched notches where they meet and a coloured left edge.
class TicketStub extends StatelessWidget {
  const TicketStub({
    super.key,
    required this.child,
    required this.stub,
    required this.edgeColor,
    this.stubWidth = 76,
    this.onTap,
  });

  final Widget child;
  final Widget stub;
  final Color edgeColor;
  final double stubWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return PhysicalShape(
      clipper: _StubClipper(stubWidth: stubWidth),
      clipBehavior: Clip.antiAlias,
      color: theme.cardTheme.color ?? Colors.white,
      elevation: dark ? 0 : 1.5,
      shadowColor: const Color(0x3312141C),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(color: edgeColor, child: const SizedBox(width: 6)),
                Expanded(child: child),
                CustomPaint(
                  size: const Size(2, double.infinity),
                  painter: _DashedLinePainter(theme.scaffoldBackgroundColor, vertical: true),
                ),
                SizedBox(width: stubWidth - 1, child: stub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StubClipper extends CustomClipper<Path> {
  const _StubClipper({required this.stubWidth});

  final double stubWidth;
  static const double _radius = 12;
  static const double _notch = 8;

  @override
  Path getClip(Size size) {
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius)));
    final x = size.width - stubWidth;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: _notch))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: _notch));
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  bool shouldReclip(_StubClipper oldClipper) => oldClipper.stubWidth != stubWidth;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color, {this.vertical = false});

  final Color color;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 5.0, gap = 4.0;
    final length = vertical ? size.height : size.width;
    // Stay clear of the punched notches at both ends.
    for (double p = vertical ? 12 : 0; p < length - (vertical ? 12 : 0); p += dash + gap) {
      final end = (p + dash).clamp(0, length).toDouble();
      canvas.drawLine(
        vertical ? Offset(size.width / 2, p) : Offset(p, size.height / 2),
        vertical ? Offset(size.width / 2, end) : Offset(end, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

/// A dashed horizontal rule, like a tear line.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(double.infinity, 2),
        painter: _DashedLinePainter(color ?? Theme.of(context).colorScheme.outlineVariant),
      );
}

/// Small capital heading with a tear line under it, e.g. "NOVEMBER 2026".
class StubSectionHeader extends StatelessWidget {
  const StubSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text.toUpperCase(), style: monoStyle(size: 11, color: muted, weight: FontWeight.w700, spacing: 1.6)),
        const SizedBox(height: 6),
        const DashedRule(),
      ],
    );
  }
}
