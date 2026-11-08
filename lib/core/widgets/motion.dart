import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Small, calm animations used across the app. All of them respect the
/// system's "reduce motion" setting (MediaQuery.disableAnimations).

bool _reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Fades and slides its child in once, [index] steps after the first item, so
/// lists appear one card after another.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  // The delay is part of the animation (no timers), so nothing outlives the widget.
  late final int _delayMs = 45 * math.min(widget.index, 8);
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 380 + _delayMs))..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Interval(_delayMs / (380 + _delayMs), 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Shrinks its child a little while a finger is on it, like a real button.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !_reduceMotion(context) ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A short burst of confetti over the whole screen (about 1.5 seconds).
void showConfetti(BuildContext context) {
  if (_reduceMotion(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final scheme = Theme.of(context).colorScheme;
  final colors = [scheme.primary, const Color(0xFFFFC857), const Color(0xFF8B7CFF), const Color(0xFF34D1A6), const Color(0xFFFF6B4A)];
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(child: _Confetti(colors: colors, onDone: () => entry.remove())),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.colors, required this.onDone});

  final List<Color> colors;
  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();
  late final List<_Piece> _pieces = () {
    final r = math.Random();
    return List.generate(70, (i) {
      final angle = -math.pi / 2 + (r.nextDouble() - 0.5) * 1.6; // mostly upwards
      final speed = 0.9 + r.nextDouble() * 0.9;
      return _Piece(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed,
        spin: (r.nextDouble() - 0.5) * 14,
        size: 6 + r.nextDouble() * 6,
        color: widget.colors[i % widget.colors.length],
        round: r.nextBool(),
      );
    });
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
    );
  }
}

class _Piece {
  _Piece({required this.dx, required this.dy, required this.spin, required this.size, required this.color, required this.round});
  final double dx, dy, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final reach = size.height * 0.55;
    final gravity = size.height * 0.9;
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    for (final p in pieces) {
      final pos = origin + Offset(p.dx * reach * t, p.dy * reach * t + gravity * t * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Grey placeholder block that gently pulses while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 14});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.06 + 0.05 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like the feed: one big card and three rows.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row() => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const Skeleton(width: 84, height: 84, radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Skeleton(height: 16, width: 180, radius: 6),
                SizedBox(height: 8),
                Skeleton(height: 12, width: 140, radius: 6),
                SizedBox(height: 8),
                Skeleton(height: 20, width: 90, radius: 8),
              ]),
            ),
          ]),
        );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Skeleton(height: 290, radius: 26),
        const SizedBox(height: 28),
        const Skeleton(height: 20, width: 120, radius: 6),
        const SizedBox(height: 14),
        row(),
        row(),
        row(),
      ],
    );
  }
}
