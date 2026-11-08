import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../app/config/theme.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import '../../../core/widgets/event_image.dart';
import 'community_actions.dart';
import 'register_action.dart';
import 'details_screen.dart';

/// Opens the event page (or asks visitors to sign in first).
void openEvent(BuildContext context, AppState appState, Event event) {
  if (appState.isGuest) {
    final l10n = AppLocalizations.of(context)!;
    askGuestToSignIn(context, appState, l10n.guestOpenTitle, l10n.guestOpenBody);
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)));
}

String _month(Event e, String locale) => DateFormat.MMM(locale).format(e.date).replaceAll('.', '').toUpperCase();

/// "Sat, 18:00 · Stadtpark"
String eventWhenWhere(Event e, String locale) => '${DateFormat('EEE, HH:mm', locale).format(e.date)} · ${e.location}';

/// White tile with month and day, e.g. NOV / 14.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.event, this.size = 54, this.tinted = false});

  final Event event;
  final double size;
  final bool tinted; // soft university tint instead of the card colour

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).toString();
    final uni = context.read<AppState>().getUniversityColor(event.universityDomain);
    final bg = tinted
        ? (dark ? theme.colorScheme.surfaceContainer : Color.lerp(uni, Colors.white, 0.88)!)
        : theme.cardTheme.color ?? Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _month(event, locale),
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: dark ? AppTheme.neon : AppTheme.urgentText,
            ),
          ),
          Text(
            '${event.date.day}',
            style: TextStyle(fontSize: size * 0.37, fontWeight: FontWeight.w800, height: 1.05),
          ),
        ],
      ),
    );
  }
}

/// The one short label a card shows: your event, registered, waitlisted, full,
/// or "12 seats left" when it is filling up.
class EventStatusPill extends StatelessWidget {
  const EventStatusPill({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    String? text;
    Color fg = scheme.onSurface;
    Color bg = scheme.surfaceContainer;
    IconData? icon;
    final left = appState.seatsLeft(event);
    if (appState.isOwnEvent(event)) {
      text = l10n.ctaOwnEvent;
    } else if (appState.isWaitlisted(event.id)) {
      text = l10n.ctaWaitlisted;
      icon = Icons.hourglass_top_rounded;
    } else if (appState.isRegistered(event.id)) {
      text = l10n.ctaRegistered;
      icon = Icons.check_circle_rounded;
      fg = dark ? AppTheme.neon : AppTheme.okText;
      bg = dark ? const Color(0xFF26301A) : AppTheme.okTint;
    } else if (left != null && left == 0) {
      text = l10n.seatsFull;
      fg = dark ? AppTheme.urgentTextDark : AppTheme.urgentText;
      bg = dark ? const Color(0xFF3A1F22) : AppTheme.urgentTint;
    } else if (left != null && event.capacity != null && left <= (event.capacity! * 0.2).ceil().clamp(3, 25)) {
      text = l10n.seatsLeft(left);
      fg = dark ? AppTheme.urgentTextDark : AppTheme.urgentText;
      bg = dark ? const Color(0xFF3A1F22) : AppTheme.urgentTint;
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// University badge for official events, e.g. HAW-HAMBURG.DE in the university colour.
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    if (!event.isUniversityOfficial) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final uni = context.read<AppState>().getUniversityColor(event.universityDomain);
    final fg = dark ? Color.lerp(uni, Colors.white, 0.55)! : uni;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 13, color: fg),
        const SizedBox(width: 3),
        Text(event.universityDomain.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: fg)),
      ],
    );
  }
}

/// Big card at the top of the feed: poster, date badge, title and status.
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final uni = appState.getUniversityColor(event.universityDomain);
    final host = appState.hostOf(event.organizerId);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: theme.brightness == Brightness.dark ? const BorderSide(color: AppTheme.darkBorder) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => openEvent(context, appState, event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 190,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'event-image-${event.id}',
                    child: EventImage(url: event.imageUrl, color: uni, seed: event.id),
                  ),
                  Positioned(top: 14, left: 14, child: DateBadge(event: event)),
                  Positioned(top: 10, right: 10, child: FavoriteButton(event: event, onImage: true)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OfficialBadge(event: event),
                  if (event.isUniversityOfficial) const SizedBox(height: 4),
                  Text(event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text(eventWhenWhere(event, locale),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: host == null
                            ? const SizedBox.shrink()
                            : Text(l10n.byOrganizer(host.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.secondary)),
                      ),
                      EventStatusPill(event: event),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact list row: poster thumbnail with date, title, time and place, status.
class EventRowCard extends StatelessWidget {
  const EventRowCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final uni = appState.getUniversityColor(event.universityDomain);
    final host = appState.hostOf(event.organizerId);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEvent(context, appState, event),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Hero(
                        tag: 'event-image-${event.id}',
                        child: EventImage(url: event.imageUrl, color: uni, seed: event.id, iconSize: 24),
                      ),
                    ),
                    Positioned(left: 6, top: 6, child: DateBadge(event: event, size: 38)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OfficialBadge(event: event),
                    Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
                    const SizedBox(height: 3),
                    Text(eventWhenWhere(event, locale),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                    if (host != null)
                      Text(l10n.byOrganizer(host.label),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                    const SizedBox(height: 6),
                    EventStatusPill(event: event),
                  ],
                ),
              ),
              FavoriteButton(event: event, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
