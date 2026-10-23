import 'package:flutter/material.dart';

/// An event poster, or a built-in placeholder when the event has none (or it fails
/// to load). No third-party image hosts are contacted.
class EventImage extends StatelessWidget {
  const EventImage({super.key, required this.url, required this.color, this.iconSize = 40});

  final String? url;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.85), color.withOpacity(0.45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(Icons.event_rounded, size: iconSize, color: Colors.white.withOpacity(0.85))),
    );
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
