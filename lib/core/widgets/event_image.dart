import 'package:flutter/material.dart';

/// An event poster, or a built-in placeholder when the event has none (or it fails
/// to load). No third-party image hosts are contacted.
class EventImage extends StatelessWidget {
  const EventImage({super.key, required this.url, required this.color, this.iconSize = 40, this.seed = ''});

  final String? url;
  final Color color;
  final double iconSize;

  /// Varies the placeholder shapes per event (usually the event id).
  final String seed;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Shapes(color: color, seed: seed.hashCode);
    final u = url;
    if (u == null || u.isEmpty) return placeholder;
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
    );
  }
}

/// Calm abstract artwork: a tinted ground with two circles and a tilted square.
class _Shapes extends StatelessWidget {
  const _Shapes({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ground = Color.lerp(color, dark ? const Color(0xFF14141C) : Colors.white, dark ? 0.72 : 0.80)!;
    final mid = Color.lerp(color, Colors.white, dark ? 0.25 : 0.45)!;
    final flip = seed.isEven;
    final shift = (seed.abs() % 5) / 10; // 0.0 .. 0.4
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
      final h = c.maxHeight.isFinite ? c.maxHeight : 200.0;
      final big = h * 1.1;
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: ground)),
            Positioned(
              left: flip ? null : -big * 0.25,
              right: flip ? -big * 0.25 : null,
              top: -big * (0.25 + shift / 2),
              child: _circle(big, mid),
            ),
            Positioned(
              left: flip ? w * (0.35 + shift / 2) : null,
              right: flip ? null : w * (0.30 + shift / 2),
              top: h * 0.28,
              child: _circle(h * 0.48, color),
            ),
            Positioned(
              left: flip ? w * 0.10 : null,
              right: flip ? null : w * 0.12,
              top: h * (0.12 + shift),
              child: Transform.rotate(
                angle: 0.25,
                child: Container(
                  width: h * 0.22,
                  height: h * 0.22,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFFC8F04A) : const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(h * 0.05),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _circle(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
