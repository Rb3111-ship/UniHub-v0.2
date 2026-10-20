import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import 'details_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    // Categories list matching translations
    final categories = [
      {'key': 'All', 'label': localizations.categoryAll, 'icon': Icons.grid_view_rounded},
      {'key': 'Music', 'label': localizations.categoryMusic, 'icon': Icons.music_note_rounded},
      {'key': 'Tech', 'label': localizations.categoryTech, 'icon': Icons.code_rounded},
      {'key': 'Sports', 'label': localizations.categorySports, 'icon': Icons.sports_soccer_rounded},
      {'key': 'Arts', 'label': localizations.categoryArts, 'icon': Icons.palette_rounded},
    ];

    // Filter events by selected category (checking if it matches any of the categories array)
    final allEvents = appState.events;
    final filteredEvents = allEvents.where((e) {
      if (appState.selectedCategory == 'All') return true;
      return e.categories.contains(appState.selectedCategory);
    }).toList();

    // Split events by official status
    final campusEvents = filteredEvents.where((e) => e.isUniversityOfficial).toList();
    final publicEvents = filteredEvents.where((e) => !e.isUniversityOfficial).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.getTenantDisplayName(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appState.getActiveTenantColor(),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                localizations.studentHomeTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: Column(
              children: [
                // Category Selector Row
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = appState.selectedCategory == cat['key'];
                      final activeColor = appState.getActiveTenantColor();

                      return ChoiceChip(
                        showCheckmark: false,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : activeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(cat['label'] as String),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: activeColor,
                        labelStyle: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : theme.colorScheme.onSurface.withOpacity(0.85),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            appState.setSelectedCategory(cat['key'] as String);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Main Feeds TabBar
                TabBar(
                  indicatorColor: appState.getActiveTenantColor(),
                  labelColor: appState.getActiveTenantColor(),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.school_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(localizations.tabCampusHub),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.public_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(localizations.tabPublicEvents),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // Premium background overlays (only active for student role)
            if (appState.currentRole == UserRole.student)
              Positioned.fill(
                child: _buildWallpaperBackground(context, appState),
              ),
            // The responsive grid of rich-media cards
            Positioned.fill(
              child: TabBarView(
                children: [
                  // Feed 1: Campus Hub (University Official)
                  _buildEventGrid(context, campusEvents, true, appState),
                  // Feed 2: Public Events (Commercial/Public)
                  _buildEventGrid(context, publicEvents, false, appState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperBackground(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pattern = appState.selectedWallpaper;

    if (pattern == WallpaperPattern.cyberAurora) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0C0714), const Color(0xFF1D0E38), const Color(0xFF0A1C38)]
                : [const Color(0xFFF2EAFF), const Color(0xFFEBF2FF), const Color(0xFFFFF0F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    } else if (pattern == WallpaperPattern.frostedGeometry) {
      return Container(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFFAF9FC),
        child: CustomPaint(
          painter: _HomeGridPainter(
            color: theme.colorScheme.onSurface.withOpacity(0.08),
            drawDiagonal: true,
          ),
        ),
      );
    } else {
      // minimalVelvet (clean matte dark/light canvas)
      return Container(
        color: isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F7),
      );
    }
  }

  Widget _buildEventGrid(
    BuildContext context,
    List<Event> events,
    bool isOfficialFeed,
    AppState appState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (appState.eventsLoading && appState.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (appState.eventsError && appState.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.eventsLoadFailed),
            const SizedBox(height: 12),
            FilledButton(onPressed: appState.refreshEvents, child: Text(l10n.authRetry)),
          ],
        ),
      );
    }
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: appState.refreshEvents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    "No events found in this category.",
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive grid layout column configurations
    final crossAxisCount = screenWidth >= 1100 ? 3 : (screenWidth >= 700 ? 2 : 1);

    return RefreshIndicator(
      onRefresh: appState.refreshEvents,
      child: GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth >= 500 ? 1.25 : 1.35,
      ),
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventTile(context, event, isOfficialFeed, appState);
      },
    ));
  }

  Widget _buildEventTile(
    BuildContext context,
    Event event,
    bool isOfficialFeed,
    AppState appState,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Dynamic brand color
    final universityColor = appState.getUniversityColor(event.universityDomain);
    final isMatchingDomain = event.universityDomain == appState.getTenantDomain();

    final dateBadgeMonth = _getMonthAbbreviation(event.date);
    final dateBadgeDay = event.date.day.toString();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withOpacity(isDark ? 0.65 : 0.85) ?? 
               (isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.85)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOfficialFeed
              ? (isMatchingDomain ? universityColor : universityColor.withOpacity(0.4))
              : theme.colorScheme.onSurface.withOpacity(0.08),
          width: isOfficialFeed && isMatchingDomain ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster banner & floating date badge
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'event-image-${event.id}',
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            child: Image.network(
                              event.imageUrl ?? 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800',
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) {
                                return Container(
                                  color: universityColor.withOpacity(0.1),
                                  child: Icon(Icons.image_not_supported_rounded, color: universityColor),
                                );
                              },
                            ),
                          ),
                        ),
                        // Shadow overlay for banner details
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Floating Date Badge (Top-Left)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dateBadgeMonth,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: universityColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      dateBadgeDay,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.onSurface,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Card Details & CTAs (snug layout, zero empty space)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge & Categories Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOfficialFeed 
                                    ? universityColor.withOpacity(0.12) 
                                    : theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOfficialFeed 
                                    ? event.universityDomain.toUpperCase() 
                                    : "PUBLIC",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isOfficialFeed ? universityColor : theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            // List of categories (max 2 visual tags on tile)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: event.categories.take(2).map((cat) => Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          fontSize: 8, 
                                          fontWeight: FontWeight.bold, 
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Title & CTA button in the same line (very compact)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildCtaButton(context, event, universityColor, theme, appState),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCtaButton(
    BuildContext context,
    Event event,
    Color brandColor,
    ThemeData theme,
    AppState appState,
  ) {
    final isRegistered = appState.isRegistered(event.id);
    final ctaText = isRegistered 
        ? "Registered" 
        : (event.requiresQrCode ? "Register" : "RSVP");

    return ElevatedButton(
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
        backgroundColor: isRegistered
            ? theme.colorScheme.surfaceContainer
            : brandColor,
        foregroundColor: isRegistered ? theme.colorScheme.onSurfaceVariant : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        ctaText, 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getMonthAbbreviation(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[date.month - 1];
  }
}

class _HomeGridPainter extends CustomPainter {
  final Color color;
  final bool drawDiagonal;
  _HomeGridPainter({required this.color, this.drawDiagonal = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const step = 40.0;

    // Draw horizontal and vertical lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Diagonal lines for premium frosted grid
    if (drawDiagonal) {
      final diagPaint = Paint()
        ..color = color.withOpacity(color.opacity * 0.5)
        ..strokeWidth = 0.5;
      for (double x = -size.height; x < size.width; x += step * 2) {
        canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), diagPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
