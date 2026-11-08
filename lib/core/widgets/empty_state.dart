import 'package:flutter/material.dart';

/// Friendly empty screen: a small drawn scene (soft circles, a tilted square and
/// the subject's icon on a disc), a title and an optional line of help.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 10,
                  top: 6,
                  child: _blob(130, accent.withValues(alpha: dark ? 0.16 : 0.10)),
                ),
                Positioned(
                  right: 8,
                  bottom: 4,
                  child: _blob(70, (dark ? const Color(0xFF8B7CFF) : const Color(0xFFFFC857)).withValues(alpha: dark ? 0.35 : 0.55)),
                ),
                Positioned(
                  right: 30,
                  top: 10,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFFC8F04A) : const Color(0xFF3F51E0).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? Colors.white,
                    shape: BoxShape.circle,
                    border: dark ? Border.all(color: theme.colorScheme.outlineVariant) : null,
                    boxShadow: dark ? null : const [BoxShadow(color: Color(0x1A12141C), blurRadius: 18, offset: Offset(0, 6))],
                  ),
                  child: Icon(icon, size: 38, color: accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.colorScheme.secondary, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
