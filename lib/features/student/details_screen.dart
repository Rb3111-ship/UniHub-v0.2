import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/categories.dart';
import '../../../core/models/event_host.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/open_link.dart';
import '../../../core/widgets/event_image.dart';
import '../../../core/widgets/poster_viewer.dart';
import '../../../core/widgets/wallpaper.dart';
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
          Positioned.fill(
            child: Wallpaper(pattern: appState.selectedWallpaper, brand: appState.getActiveTenantColor()),
          ),
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
                      actions: [
                        if (event.imageUrl != null)
                          IconButton(
                            tooltip: l10n.posterShowFull,
                            icon: const Icon(Icons.open_in_full_rounded, color: Colors.white),
                            onPressed: () => showPoster(context, event.imageUrl!, 'event-image-${event.id}'),
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Tap the poster to see all of it (the header crops it).
                            GestureDetector(
                              onTap: event.imageUrl == null
                                  ? null
                                  : () => showPoster(context, event.imageUrl!, 'event-image-${event.id}'),
                              child: Hero(
                                tag: 'event-image-${event.id}',
                                child: EventImage(url: event.imageUrl, color: brandColor, iconSize: 72),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
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
                                                categoryLabel(l10n, c),
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
                          if (event.hasContact) _ContactCard(event: event, color: brandColor),
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

/// "Hosted by" with the organizer's organization, name and photo.
class _HostCard extends StatelessWidget {
  const _HostCard({required this.organizerId});

  final String organizerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appState = context.read<AppState>();
    return FutureBuilder<EventHost?>(
      future: appState.organizerFor(organizerId),
      initialData: appState.hostOf(organizerId),
      builder: (context, snap) {
        final host = snap.data;
        if (host == null || host.label.isEmpty) return const SizedBox.shrink();
        final showPerson = host.label != host.name && host.name.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary,
                foregroundImage: host.photoUrl == null ? null : NetworkImage(host.photoUrl!),
                child: Text(host.label.characters.first.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.detailsHostedBy,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                    Text(host.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (showPerson)
                      Text(host.name, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
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

/// The organizer's website, e-mail and phone as tappable links.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.event, required this.color});

  final Event event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Widget link(IconData icon, String label, String value, Uri uri) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => openLink(context, uri, value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                        Text(
                          value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded, size: 18, color: color),
                ],
              ),
            ),
          ),
        );

    final website = event.websiteUrl;
    final email = event.contactEmail;
    final phone = event.contactPhone;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
              child: Text(l10n.detailsContactTitle,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (website != null)
              link(Icons.language_rounded, l10n.contactWebsite, website.replaceFirst(RegExp(r'^https://'), ''),
                  Uri.parse(website)),
            if (email != null) link(Icons.mail_rounded, l10n.contactEmail, email, Uri(scheme: 'mailto', path: email)),
            if (phone != null)
              link(Icons.phone_rounded, l10n.contactPhone, phone,
                  Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''))),
          ],
        ),
      ),
    );
  }
}
