import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../auth/user_role.dart';

/// The order in which wallpapers are offered in the profile.
const wallpaperChoices = [
  WallpaperPattern.minimalVelvet,
  WallpaperPattern.frostedGeometry,
  WallpaperPattern.dots,
  WallpaperPattern.waves,
  WallpaperPattern.cyberAurora,
  WallpaperPattern.aurora,
  WallpaperPattern.ocean,
  WallpaperPattern.bubbles,
];

String wallpaperName(AppLocalizations l10n, WallpaperPattern pattern) => switch (pattern) {
      WallpaperPattern.minimalVelvet => l10n.wallpaperNone,
      WallpaperPattern.frostedGeometry => l10n.wallpaperGrid,
      WallpaperPattern.dots => l10n.wallpaperDots,
      WallpaperPattern.waves => l10n.wallpaperWaves,
      WallpaperPattern.cyberAurora => l10n.wallpaperSunset,
      WallpaperPattern.aurora => l10n.wallpaperAurora,
      WallpaperPattern.ocean => l10n.wallpaperOcean,
      WallpaperPattern.bubbles => l10n.wallpaperBubbles,
    };

/// Paints [child] on top of the wallpaper the user picked. Screens inside get a
/// transparent background so the wallpaper shows through; pushed pages are not
/// affected.
class WallpaperArea extends StatelessWidget {
  final Widget child;
  const WallpaperArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Wallpaper(pattern: appState.selectedWallpaper, brand: appState.getActiveTenantColor()),
        Theme(
          data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: child,
        ),
      ],
    );
  }
}

/// One wallpaper. [scale] shrinks the pattern for the small previews.
class Wallpaper extends StatelessWidget {
  final WallpaperPattern pattern;
  final Color brand;
  final double scale;

  const Wallpaper({super.key, required this.pattern, required this.brand, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = dark ? const Color(0xFF121214) : const Color(0xFFF5F5F7);
    final ink = theme.colorScheme.onSurface;

    Widget gradient(List<Color> colors) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        );

    Widget painted(CustomPainter painter) => ColoredBox(
          color: base,
          child: CustomPaint(painter: painter, child: const SizedBox.expand()),
        );

    return switch (pattern) {
      WallpaperPattern.minimalVelvet => ColoredBox(color: base),
      WallpaperPattern.frostedGeometry => painted(_GridPainter(ink.withOpacity(dark ? 0.08 : 0.07), scale)),
      WallpaperPattern.dots => painted(_DotsPainter(brand.withOpacity(dark ? 0.35 : 0.22), scale)),
      WallpaperPattern.waves => painted(_WavesPainter(brand.withOpacity(dark ? 0.22 : 0.14), scale)),
      WallpaperPattern.cyberAurora => gradient(dark
          ? const [Color(0xFF2A1023), Color(0xFF3B1530), Color(0xFF1A1033)]
          : const [Color(0xFFFFEEDD), Color(0xFFFFE0EA), Color(0xFFF1E6FF)]),
      WallpaperPattern.aurora => ColoredBox(
          color: dark ? const Color(0xFF0B1020) : const Color(0xFFF4F7FB),
          child: CustomPaint(painter: _GlowPainter(dark), child: const SizedBox.expand()),
        ),
      WallpaperPattern.ocean => gradient(dark
          ? const [Color(0xFF04202C), Color(0xFF0B2545), Color(0xFF13315C)]
          : const [Color(0xFFE0F7FA), Color(0xFFE3F2FD), Color(0xFFEDE7F6)]),
      WallpaperPattern.bubbles => painted(_BubblesPainter(brand, dark, scale)),
    };
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  final double scale;
  _GridPainter(this.color, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    final step = 40.0 * scale;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color || old.scale != scale;
}

class _DotsPainter extends CustomPainter {
  final Color color;
  final double scale;
  _DotsPainter(this.color, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final step = 22.0 * scale;
    var row = 0;
    for (double y = step / 2; y < size.height; y += step, row++) {
      // Every other row is shifted for a staggered pattern.
      final shift = row.isOdd ? step / 2 : 0.0;
      for (double x = step / 2 + shift; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.8 * scale.clamp(0.6, 1.0), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color || old.scale != scale;
}

class _WavesPainter extends CustomPainter {
  final Color color;
  final double scale;
  _WavesPainter(this.color, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final gap = 34.0 * scale;
    final amplitude = 8.0 * scale;
    final length = 120.0 * scale;
    for (double y = 0; y < size.height + gap; y += gap) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 4) {
        path.lineTo(x, y + math.sin(x / length * 2 * math.pi) * amplitude);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => old.color != color || old.scale != scale;
}

/// Soft coloured glows, like northern lights.
class _GlowPainter extends CustomPainter {
  final bool dark;
  _GlowPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final glows = [
      (const Offset(0.15, 0.1), const Color(0xFF2DD4BF)),
      (const Offset(0.85, 0.3), const Color(0xFF8B5CF6)),
      (const Offset(0.3, 0.75), const Color(0xFF22C55E)),
      (const Offset(0.9, 0.95), const Color(0xFF3B82F6)),
    ];
    final radius = size.shortestSide * 0.7;
    for (final (pos, color) in glows) {
      final center = Offset(pos.dx * size.width, pos.dy * size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(dark ? 0.28 : 0.20), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.dark != dark;
}

class _BubblesPainter extends CustomPainter {
  final Color brand;
  final bool dark;
  final double scale;
  _BubblesPainter(this.brand, this.dark, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed seed: the bubbles stay in the same place on every repaint.
    final random = math.Random(7);
    final fill = Paint()..color = brand.withOpacity(dark ? 0.10 : 0.07);
    final ring = Paint()
      ..color = brand.withOpacity(dark ? 0.25 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final count = (size.width * size.height / (9000 * scale * scale)).clamp(6, 120).round();
    for (var i = 0; i < count; i++) {
      final center = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final r = (6 + random.nextDouble() * 34) * scale;
      canvas.drawCircle(center, r, fill);
      canvas.drawCircle(center, r, ring);
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.brand != brand || old.dark != dark || old.scale != scale;
}
