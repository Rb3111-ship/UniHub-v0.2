import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import '../../../core/widgets/event_image.dart';
import 'register_action.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandColor = appState.getUniversityColor(event.universityDomain);
    final locale = Localizations.localeOf(context).toString();

    // Only verified reviews count towards the rating shown to students.
    final rating = appState.ratingFor(event.id);
    final averageRating = rating?.average ?? 0.0;

    final gallery = event.galleryImages ?? const <String>[];
    final dateStr = '${DateFormat.yMMMEd(locale).format(event.date)}, '
        '${DateFormat.Hm(locale).format(event.date)} - ${DateFormat.Hm(locale).format(event.endDate)}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (appState.currentRole == UserRole.student)
            Positioned.fill(child: _buildBackgroundOverlay(context, appState)),
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 280.0,
                      pinned: true,
                      backgroundColor: isDark ? const Color(0xFF1E1E22) : brandColor,
                      iconTheme: const IconThemeData(color: Colors.white),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'event-image-${event.id}',
                              child: EventImage(url: event.imageUrl, color: brandColor, iconSize: 72),
                            ),
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
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Text(
                                event.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: event.isCancelled ? TextDecoration.lineThrough : null,
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
                                      ? l10n.badgeOfficial(event.universityDomain.toUpperCase())
                                      : l10n.badgePublic,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: event.isUniversityOfficial ? brandColor : theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: event.categories
                                        .map((c) => Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainer,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                c,
                                                style: TextStyle(
                                                    fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event.isCancelled) ...[
                            const SizedBox(height: 12),
                            _notice(context, Icons.event_busy_rounded, l10n.detailsCancelledBody, Colors.red),
                          ] else if (event.endDate.isBefore(DateTime.now())) ...[
                            const SizedBox(height: 12),
                            _notice(context, Icons.history_rounded, l10n.detailsEndedBody, Colors.grey),
                          ],
                          const SizedBox(height: 20),
                          _buildGlassmorphicCard(
                            context,
                            child: Column(
                              children: [
                                _buildDetailRow(context, Icons.calendar_month_rounded, l10n.detailsDateTime, dateStr),
                                const Divider(height: 20, thickness: 0.5),
                                _buildDetailRow(context, Icons.location_on_rounded, l10n.detailsLocation, event.location),
                                const Divider(height: 20, thickness: 0.5),
                                _buildDetailRow(
                                  context,
                                  Icons.groups_rounded,
                                  '',
                                  event.capacity == null ? l10n.detailsUnlimited : l10n.detailsCapacity(event.capacity!),
                                  hideLabel: true,
                                ),
                                const Divider(height: 20, thickness: 0.5),
                                _buildDetailRow(
                                  context,
                                  Icons.star_rounded,
                                  l10n.detailsEventRating,
                                  rating == null
                                      ? l10n.detailsNoRatings
                                      : "${averageRating.toStringAsFixed(1)} / 5.0 (${l10n.detailsReviewCount(rating.count)})",
                                  customTrailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: starIdx < averageRating.round() ? Colors.amber.shade700 : Colors.grey.shade400,
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (event.organizerId != null) _HostCard(organizerId: event.organizerId!),
                          const SizedBox(height: 24),
                          if (event.description.trim().isNotEmpty) ...[
                            Text(l10n.detailsAbout,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(event.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
                            const SizedBox(height: 24),
                          ],
                          // Only real pictures of this event; no stock photos.
                          if (gallery.isNotEmpty) ...[
                            Text(l10n.detailsGallery,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 130,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: gallery.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, idx) => ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(width: 180, child: EventImage(url: gallery[idx], color: brandColor)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStickyBottomBar(context, appState, brandColor, l10n),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
      ]),
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
    bool hideLabel = false,
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
              if (!hideLabel) ...[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (customTrailing != null) customTrailing,
      ],
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, AppState appState, Color brandColor, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRegistered = appState.isRegistered(event.id);
    final waitlisted = appState.isWaitlisted(event.id);
    final closed = event.isCancelled || event.endDate.isBefore(DateTime.now());
    final locale = Localizations.localeOf(context).toString();

    final String headline;
    final String subline;
    if (isRegistered) {
      headline = waitlisted ? l10n.detailsWaitlistedLabel : l10n.detailsTicketReserved;
      subline = waitlisted ? l10n.detailsWaitlistBody : l10n.detailsSeeTickets;
    } else {
      headline = event.priceCents > 0
          ? NumberFormat.simpleCurrency(locale: locale, name: 'EUR').format(event.priceCents / 100)
          : l10n.detailsFree;
      subline = event.requiresQrCode ? l10n.detailsQrRequired : l10n.detailsOpenAdmission;
    }
    final ctaText = closed && !isRegistered
        ? l10n.ctaUnavailable
        : isRegistered
            ? (waitlisted ? l10n.ctaWaitlisted : l10n.ctaRegistered)
            : (event.requiresQrCode ? l10n.ctaRegister : l10n.ctaRsvp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
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
                    headline,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isRegistered ? Colors.green : brandColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subline, style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: isRegistered || closed ? null : () => registerWithFeedback(context, appState, event),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRegistered || closed ? theme.colorScheme.surfaceContainer : brandColor,
                foregroundColor: isRegistered || closed ? theme.colorScheme.onSurfaceVariant : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(ctaText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Hosted by" with the organizer's name and photo.
class _HostCard extends StatelessWidget {
  const _HostCard({required this.organizerId});

  final String organizerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return FutureBuilder<({String name, String? photoUrl})?>(
      future: context.read<AppState>().organizerFor(organizerId),
      builder: (context, snap) {
        final host = snap.data;
        if (host == null || host.name.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary,
                foregroundImage: host.photoUrl == null ? null : NetworkImage(host.photoUrl!),
                child: Text(host.name.characters.first.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.detailsHostedBy,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                    Text(host.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
