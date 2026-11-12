import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../app/config/theme.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/categories.dart';
import '../../../core/widgets/ticket_stub.dart';
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
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

/// An event drawn as a ticket: category colour on the left edge, the details in
/// the middle and the date on a tear-off stub.
class EventStubCard extends StatelessWidget {
  const EventStubCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.secondary;
    final ink = dark ? theme.colorScheme.onSurface : AppTheme.ink;
    final category = event.categories.isEmpty ? null : event.categories.first;
    final host = appState.hostOf(event.organizerId);
    return TicketStub(
      edgeColor: categoryColor(category),
      onTap: () => openEvent(context, appState, event),
      stub: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${event.date.day}'.padLeft(2, '0'),
              style: monoStyle(size: 26, color: ink, weight: FontWeight.w700, spacing: 0).copyWith(height: 1)),
          const SizedBox(height: 3),
          Text(_month(event, locale), style: monoStyle(size: 10, color: ink, weight: FontWeight.w700, spacing: 1.6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (category != null)
                        Text(categoryLabel(l10n, category).toUpperCase(),
                            style: monoStyle(
                                size: 10, color: categoryColor(category, dark: dark), weight: FontWeight.w700, spacing: 0.8)),
                      OfficialBadge(event: event),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.2)),
                  const SizedBox(height: 4),
                  Text(eventWhenWhere(event, locale).toUpperCase(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(size: 10.5, color: muted, spacing: 0.3)),
                  if (host != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l10n.byOrganizer(host.label),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
                    ),
                  const SizedBox(height: 6),
                  EventStatusPill(event: event),
                ],
              ),
            ),
            FavoriteButton(event: event, color: muted),
          ],
        ),
      ),
    );
  }
}
