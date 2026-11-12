import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';

/// Enlarges the whole poster (not cropped) over a frosted view of the page
/// behind it. The poster grows out of the spot it was tapped; pinch to zoom,
/// tap beside it or press the cross to close.
void showPoster(BuildContext context, String imageUrl, String heroTag) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, animation, __) => _PosterViewer(imageUrl: imageUrl, heroTag: heroTag, animation: animation),
  ));
}

class _PosterViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final Animation<double> animation;
  const _PosterViewer({required this.imageUrl, required this.heroTag, required this.animation});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    void close() => Navigator.of(context).maybePop();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The page behind turns to frosted glass as the poster grows.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: eased,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18 * eased.value, sigmaY: 18 * eased.value),
                child: ColoredBox(
                  color: (dark ? Colors.black : const Color(0xFF10131F)).withOpacity(0.42 * eased.value),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: close,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.94, end: 1).animate(eased),
                        child: GestureDetector(
                          onTap: () {}, // taps on the poster itself do not close it
                          child: Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) => progress == null
                                    ? child
                                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FadeTransition(
                  opacity: eased,
                  child: IconButton.filled(
                    tooltip: l10n.posterClose,
                    style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: close,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
