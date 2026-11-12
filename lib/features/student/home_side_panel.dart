import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../app/config/theme.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/categories.dart';
import '../../../core/models/event_model.dart';
import '../../../core/widgets/ticket_stub.dart';
import 'event_cards.dart';
import 'qr_fullscreen.dart';

/// Right-hand column of the home screen on wide windows: the next ticket with
/// its QR code, and the events the user saved.
class HomeSidePanel extends StatelessWidget {
  const HomeSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.secondary;
    final now = DateTime.now();

    final upcoming = appState.registeredEvents
        .where((e) => !e.endDate.isBefore(now) && !e.isCancelled && !appState.isWaitlisted(e.id))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final next = upcoming.isEmpty ? null : upcoming.first;
    final saved = appState.events.where((e) => appState.isFavorite(e.id)).take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StubSectionHeader(l10n.homeNextTicket),
          const SizedBox(height: 12),
          if (next == null)
            Text(l10n.homeNoTicketYet, style: TextStyle(fontSize: 13, color: muted))
          else
            _NextTicket(event: next),
          const SizedBox(height: 24),
          StubSectionHeader(l10n.homeSavedTitle),
          const SizedBox(height: 12),
          if (saved.isEmpty)
            Text(l10n.homeSavedNone, style: TextStyle(fontSize: 13, color: muted))
          else
            for (final e in saved) ...[_SavedTile(event: e), const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

class _NextTicket extends StatelessWidget {
  const _NextTicket({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).toString();
    final muted = theme.colorScheme.secondary;
    final category = event.categories.isEmpty ? null : event.categories.first;
    final ticketId = appState.getTicketId(event.id);
    final scanned = appState.isTicketScanned(ticketId);
    final hasQr = appState.hasValidTicketFor(event.id) && !scanned;
    final payload = appState.qrPayload(event.id);

    Widget info(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: monoStyle(size: 9, color: muted, spacing: 1.2)),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Material(
      color: theme.cardTheme.color ?? Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: dark ? const BorderSide(color: AppTheme.darkBorder) : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => openEvent(context, appState, event),
            child: Container(
              color: dark ? const Color(0xFF1B1530) : AppTheme.ink,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [if (category != null) categoryLabel(l10n, category), l10n.ticketAdmitOne].join(' · ').toUpperCase(),
                    style: monoStyle(size: 9.5, color: const Color(0xFFB9C0E6), spacing: 1.0),
                  ),
                  const SizedBox(height: 3),
                  Text(event.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info(l10n.ticketLabelDate,
                    '${DateFormat.MMMEd(locale).format(event.date)}, ${DateFormat.Hm(locale).format(event.date)}'),
                const SizedBox(width: 10),
                info(l10n.ticketLabelLocation, event.location),
              ],
            ),
          ),
          DashedRule(color: theme.scaffoldBackgroundColor),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (hasQr)
                  InkWell(
                    onTap: () => QrFullscreenPage.open(context, payload: payload, title: event.title, ticketId: ticketId),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      child: QrImageView(data: payload, version: QrVersions.auto, size: 124),
                    ),
                  )
                else
                  Text(scanned ? l10n.ticketCheckedInBadge : l10n.ticketEntryOpen,
                      style: monoStyle(size: 11, color: muted, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${l10n.ticketLabelId} $ticketId', style: monoStyle(size: 11, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Material(
      color: theme.cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEvent(context, appState, event),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2)),
              const SizedBox(height: 2),
              Text('${DateFormat.MMMEd(locale).format(event.date)} · ${event.location}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 10, color: theme.colorScheme.secondary, spacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
