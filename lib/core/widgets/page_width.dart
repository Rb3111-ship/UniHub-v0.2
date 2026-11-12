import 'package:flutter/material.dart';

/// Keeps a page readable on a PC: its content is centred and never wider than
/// [maxWidth], instead of stretching across the whole window. On a phone it
/// changes nothing.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
