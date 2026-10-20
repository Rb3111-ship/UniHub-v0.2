import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandColor = appState.getUniversityColor(event.universityDomain);

    // Get mock organizer reviews ratings
    final reviews = appState.getReviewsForEvent(event.id);
    final averageRating = reviews.isEmpty
        ? 4.5
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    final gallery = _getGalleryImages(event);
    final dateStr = "${event.date.day}.${event.date.month}.${event.date.year} @ ${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background layout theme (e.g. Cyber Aurora or grid) if active
          if (appState.currentRole == UserRole.student)
            Positioned.fill(
              child: _buildBackgroundOverlay(context, appState),
            ),
          // Content
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Visual banner Header with Hero
                    SliverAppBar(
                      expandedHeight: 280.0,
                      floating: false,
                      pinned: true,
                      backgroundColor: isDark ? const Color(0xFF1E1E22) : brandColor,
                      iconTheme: const IconThemeData(color: Colors.white),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'event-image-${event.id}',
                              child: Image.network(
                                event.imageUrl ?? 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800',
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Shading Gradient
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.4),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            // Overlaid title over the bottom of the image banner
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Text(
                                event.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // University and Categories Badge Section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: event.isUniversityOfficial
                                      ? brandColor.withOpacity(0.15)
                                      : theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  event.isUniversityOfficial
                                      ? "${event.universityDomain.toUpperCase()} OFFICIAL"
                                      : "PUBLIC EVENT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: event.isUniversityOfficial ? brandColor : theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Multi-category tag chips list
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: event.categories.map((c) => Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        c,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Seating / Organizer Rating & Basic metrics details
                          _buildGlassmorphicCard(
                            context,
                            child: Column(
                              children: [
                                _buildDetailRow(context, Icons.calendar_month_rounded, "Date & Time", dateStr),
                                const Divider(height: 20, thickness: 0.5),
                                _buildDetailRow(context, Icons.location_on_rounded, "Location", event.location),
                                const Divider(height: 20, thickness: 0.5),
                                _buildDetailRow(
                                  context,
                                  Icons.star_rounded,
                                  "Organizer Rating",
                                  "${averageRating.toStringAsFixed(1)} / 5.0 (${reviews.length} reviews)",
                                  customTrailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: starIdx < averageRating.floor() ? Colors.amber.shade700 : Colors.grey.shade400,
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Full Detailed Description
                          Text(
                            "About Event",
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event.description,
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 24),

                          // Horizontal Carousel Gallery (2-3 additional images)
                          Text(
                            "Event Gallery",
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 130,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: gallery.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    gallery[idx],
                                    width: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 180,
                                      color: brandColor.withOpacity(0.1),
                                      child: Icon(Icons.image_not_supported_rounded, color: brandColor),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),

              // Sticky Bottom Registration Bar
              _buildStickyBottomBar(context, appState, brandColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOverlay(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pattern = appState.selectedWallpaper;

    if (pattern == WallpaperPattern.cyberAurora) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF07040C), const Color(0xFF140726), const Color(0xFF051126)]
                : [const Color(0xFFF7F2FF), const Color(0xFFF0F5FF), const Color(0xFFFFF5FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    } else if (pattern == WallpaperPattern.frostedGeometry) {
      return Container(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFFAF9FC),
        child: CustomPaint(
          painter: _DetailsGridPainter(color: theme.colorScheme.onSurface.withOpacity(0.04)),
        ),
      );
    } else {
      return Container(color: isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F7));
    }
  }

  Widget _buildGlassmorphicCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: theme.cardTheme.color?.withOpacity(isDark ? 0.65 : 0.85) ??
                   (isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.85)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Widget? customTrailing,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (customTrailing != null) customTrailing,
      ],
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, AppState appState, Color brandColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRegistered = appState.isRegistered(event.id);
    final ctaText = isRegistered
        ? "You are Registered"
        : (event.requiresQrCode ? "Confirm Registration" : "RSVP to Event");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRegistered ? "TICKET RESERVED" : "FREE ADMISSION",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isRegistered ? Colors.green : brandColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRegistered 
                        ? "Check 'My Tickets' for entrance QR code" 
                        : (event.requiresQrCode ? "QR Code Ticket Required" : "Open admission, RSVP below"),
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: isRegistered
                  ? null
                  : () {
                      appState.registerForEvent(event.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          content: Text("Successfully registered for ${event.title}!"),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isRegistered ? theme.colorScheme.surfaceContainer : brandColor,
                foregroundColor: isRegistered ? theme.colorScheme.onSurfaceVariant : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                ctaText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getGalleryImages(Event event) {
    if (event.galleryImages != null && event.galleryImages!.isNotEmpty) {
      return event.galleryImages!;
    }
    // Categories-based high-res gallery images
    final firstCat = event.category.toLowerCase();
    if (firstCat.contains('tech')) {
      return [
        'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=600',
        'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?w=600',
        'https://images.unsplash.com/photo-1531297484001-80022131f5a1?w=600',
      ];
    } else if (firstCat.contains('music')) {
      return [
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600',
        'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=600',
      ];
    } else if (firstCat.contains('arts')) {
      return [
        'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=600',
        'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?w=600',
        'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600',
      ];
    } else if (firstCat.contains('sports')) {
      return [
        'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=600',
        'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?w=600',
        'https://images.unsplash.com/photo-1502086223501-7ea6ecd79368?w=600',
      ];
    }
    return [
      'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600',
      'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=600',
      'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=600',
    ];
  }
}

class _DetailsGridPainter extends CustomPainter {
  final Color color;
  _DetailsGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const step = 45.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
