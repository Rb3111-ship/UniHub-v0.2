import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../app/config/theme.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/categories.dart';
import '../../../core/models/event_host.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/add_to_calendar.dart';
import '../../../core/utils/open_link.dart';
import '../../../core/widgets/ticket_stub.dart';
import '../../../core/widgets/event_image.dart';
import '../../../core/widgets/poster_viewer.dart';
import 'attendance_confirm_card.dart';
import 'community_actions.dart';
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

    final category = event.categories.isEmpty ? null : event.categories.first;

    // Kicker and title, like the top of a ticket.
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category != null)
          Text(categoryLabel(l10n, category).toUpperCase(),
              style: monoStyle(
                  size: 11, color: categoryColor(category, dark: isDark), weight: FontWeight.w700, spacing: 1.2)),
        const SizedBox(height: 4),
        // The save heart sits right beside the title it belongs to.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                event.title,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  decoration: event.isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (appState.usesBackend && !appState.isGuest)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Material(
                  color: theme.cardTheme.color,
                  shape: const CircleBorder(),
                  elevation: isDark ? 0 : 1,
                  child: FavoriteButton(event: event, color: theme.colorScheme.onSurface),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );

    final info = <Widget>[
      if (appState.registrationFor(event.id)?.needsConfirmation ?? false) ...[
        AttendanceConfirmCard(registration: appState.registrationFor(event.id)!),
        const SizedBox(height: 16),
      ],
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: event.isUniversityOfficial
                  ? brandColor.withOpacity(isDark ? 0.25 : 0.12)
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              event.isUniversityOfficial
                  ? l10n.badgeOfficial(event.universityDomain.toUpperCase())
                  : l10n.badgePublic,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: event.isUniversityOfficial
                    ? (isDark ? Color.lerp(brandColor, Colors.white, 0.55) : brandColor)
                    : theme.colorScheme.onSurface,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            categoryLabel(l10n, c),
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      if (event.isModerated) ...[
        const SizedBox(height: 12),
        _notice(
            context,
            Icons.gpp_bad_outlined,
            (event.moderationNote ?? '').isEmpty
                ? l10n.detailsModeratedBody
                : '${l10n.detailsModeratedBody} ${event.moderationNote}',
            Colors.red),
      ] else if (event.isCancelled) ...[
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
      if (event.capacity != null && appState.seatsLeft(event) != null && !event.isCancelled)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _SeatBar(event: event, left: appState.seatsLeft(event)!),
        ),
      if (!event.isCancelled && event.endDate.isAfter(DateTime.now()))
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            onPressed: () => addToCalendar(context, event),
            icon: const Icon(Icons.event_available_rounded),
            label: Text(l10n.addToCalendar),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary,
              backgroundColor: theme.cardTheme.color,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      if (event.organizerId != null) _HostCard(organizerId: event.organizerId!),
      if (event.hasContact) _ContactCard(event: event, color: brandColor),
      const SizedBox(height: 24),
      if (event.description.trim().isNotEmpty) ...[
        StubSectionHeader(l10n.detailsAbout),
        const SizedBox(height: 8),
        Text(event.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
        const SizedBox(height: 24),
      ],
      // Only real pictures of this event; no stock photos.
      if (gallery.isNotEmpty) ...[
        StubSectionHeader(l10n.detailsGallery),
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
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1B1530) : AppTheme.ink,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Reporting: not for your own events, and only while the event is live.
          if (appState.usesBackend && !appState.isGuest && !appState.isOwnEvent(event) && !event.isCancelled)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (_) => reportEventDialog(context, appState, event),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    const Icon(Icons.flag_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.reportTitle),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // The poster is always shown whole, never cropped. On a phone it sits
            // above the details; on a PC it stays on the left while the details scroll.
            child: LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth < 900) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              heading,
                              _Poster(event: event, color: brandColor, maxHeight: (box.maxHeight * 0.62).clamp(220, 560)),
                              const SizedBox(height: 16),
                              ...info,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: (box.maxWidth * 0.42).clamp(340, 540),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 8, 24),
                            child: _Poster(event: event, color: brandColor, maxHeight: box.maxHeight - 48),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
                            children: [heading, ...info],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildStickyBottomBar(context, appState, brandColor, l10n),
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

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: theme.colorScheme.outlineVariant) : null,
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0F12141C), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: child,
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
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainer : theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideLabel) ...[
                Text(label.toUpperCase(), style: monoStyle(size: 10, color: theme.colorScheme.secondary, spacing: 1.2)),
                const SizedBox(height: 2),
              ],
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
    final own = appState.isOwnEvent(event);
    final locale = Localizations.localeOf(context).toString();

    final String headline;
    final String subline;
    if (own) {
      headline = l10n.ownEventHeadline;
      subline = l10n.ownEventBody;
    } else if (isRegistered) {
      headline = waitlisted ? l10n.detailsWaitlistedLabel : l10n.detailsTicketReserved;
      subline = waitlisted ? l10n.detailsWaitlistBody : l10n.detailsSeeTickets;
    } else {
      headline = event.priceCents > 0
          ? NumberFormat.simpleCurrency(locale: locale, name: 'EUR').format(event.priceCents / 100)
          : l10n.detailsFree;
      subline = event.requiresQrCode ? l10n.detailsQrRequired : l10n.detailsOpenAdmission;
    }
    final ctaText = own
        ? l10n.ctaOwnEvent
        : closed && !isRegistered
        ? l10n.ctaUnavailable
        : isRegistered
            ? (waitlisted ? l10n.ctaWaitlisted : l10n.ctaRegistered)
            : l10n.ctaRegister;

    final enabled = !(own || isRegistered || closed);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121219) : Colors.white,
        border: isDark ? Border(top: BorderSide(color: theme.colorScheme.outlineVariant)) : null,
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x1412141C), blurRadius: 14, offset: Offset(0, -3))],
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isRegistered ? (isDark ? AppTheme.neon : AppTheme.okText) : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subline, maxLines: 2, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: enabled ? () => registerWithFeedback(context, appState, event) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? theme.colorScheme.primary : theme.colorScheme.surfaceContainer,
                foregroundColor: enabled ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                disabledBackgroundColor: theme.colorScheme.surfaceContainer,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                minimumSize: const Size(140, 54),
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Row(
                  key: ValueKey(ctaText),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRegistered && !waitlisted && !own) ...[
                      const Icon(Icons.check_circle_rounded, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Text(ctaText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "88 of 100 seats taken · 12 left" with a bar.
class _SeatBar extends StatelessWidget {
  const _SeatBar({required this.event, required this.left});

  final Event event;
  final int left;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final capacity = event.capacity!;
    final taken = capacity - left;
    final share = capacity == 0 ? 0.0 : taken / capacity;
    final urgent = left <= (capacity * 0.2).ceil().clamp(3, 25);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: theme.colorScheme.outlineVariant) : null,
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0F12141C), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.seatsTaken(taken, capacity), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(
                left == 0 ? l10n.seatsFull : l10n.seatsLeft(left),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: urgent ? (isDark ? AppTheme.urgentTextDark : AppTheme.urgentText) : theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.12),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(14),
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

/// The event poster, shown whole (never cropped) inside a dark frame. Tap it to
/// zoom. Events without a poster get the small built-in artwork instead.
class _Poster extends StatelessWidget {
  const _Poster({required this.event, required this.color, required this.maxHeight});

  final Event event;
  final Color color;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl;
    final tag = 'event-image-${event.id}';
    if (url == null || url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: maxHeight.clamp(0, 180).toDouble(),
          child: Hero(tag: tag, child: EventImage(url: null, color: color, seed: event.id, iconSize: 72)),
        ),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.posterShowFull,
      child: GestureDetector(
        onTap: () => showPoster(context, url, tag),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ColoredBox(
            color: const Color(0xFF10131F),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Hero(
                tag: tag,
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                  errorBuilder: (_, __, ___) =>
                      SizedBox(height: 180, child: EventImage(url: null, color: color, seed: event.id, iconSize: 72)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
