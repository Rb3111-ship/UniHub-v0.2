import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/widgets/empty_state.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../app/config/theme.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/categories.dart';
import '../../../core/models/registration_model.dart';
import '../../../core/services/registration_repository.dart' show pastTicketsKept;
import '../../../core/widgets/ticket_stub.dart';
import 'attendance_confirm_card.dart';
import 'qr_fullscreen.dart';
import 'register_action.dart';
import 'review_screen.dart';

class StudentTicketsScreen extends StatelessWidget {
  const StudentTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    final registeredEvents = appState.registeredEvents;
    // Events that are over move to a folded "Past events" section at the bottom.
    final now = DateTime.now();
    final upcoming = registeredEvents.where((e) => !e.endDate.isBefore(now)).toList();
    // Past tickets are kept for 90 days, so the list does not grow forever.
    final oldest = now.subtract(pastTicketsKept);
    final past = registeredEvents.where((e) => e.endDate.isBefore(now) && e.endDate.isAfter(oldest)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (upcoming.isEmpty && past.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.studentTicketsTitle),
        actions: [
          IconButton(
            tooltip: localizations.ticketsRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: appState.refreshRegistrations,
          ),
        ],
        ),
        body: Center(
          child: EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: localizations.ticketsEmptyTitle,
            body: localizations.ticketsEmptyBody,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.studentTicketsTitle),
        actions: [
          IconButton(
            tooltip: localizations.ticketsRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: appState.refreshRegistrations,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.refreshRegistrations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            if (upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.confirmation_number_outlined,
                  title: localizations.ticketsNoUpcoming,
                  body: localizations.ticketsEmptyBody,
                ),
              ),
            // Tickets keep a ticket's width: one per row on a phone, two or three
            // side by side on a PC instead of one stretched across the window.
            LayoutBuilder(
              builder: (context, box) {
                const gap = 20.0;
                final columns = (box.maxWidth / 440).floor().clamp(1, 3);
                final width = ((box.maxWidth - gap * (columns - 1)) / columns).clamp(0, 460).toDouble();
                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final e in upcoming) SizedBox(width: width, child: _buildUpcoming(context, e, appState)),
                  ],
                );
              },
            ),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Theme(
                // No divider lines around the expandable section.
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('pastTickets'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(localizations.ticketsPastSection(past.length),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(localizations.ticketsPastHint,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                      ),
                    ),
                    for (final e in past)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildPastCard(context, e, appState),
                      ),
                  ],
                ),
              ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcoming(BuildContext context, Event event, AppState appState) {
    final localizations = AppLocalizations.of(context)!;
    final ticketId = appState.getTicketId(event.id);
    final ticket = _buildTicket(context, event, ticketId, appState);
    final reg = appState.registrationFor(event.id);
    if (reg == null || !(reg.needsConfirmation || (reg.isConfirmed && event.date.isAfter(DateTime.now())))) {
      return ticket;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reg.needsConfirmation)
          AttendanceConfirmCard(registration: reg)
        else
          Chip(
            avatar: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
            label: Text(localizations.confirmedBadge),
            visualDensity: VisualDensity.compact,
          ),
        const SizedBox(height: 8),
        ticket,
      ],
    );
  }

  /// Small card for an event that is over: what happened, and the review button.
  Widget _buildPastCard(BuildContext context, Event event, AppState appState) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scanned = appState.isTicketScanned(appState.getTicketId(event.id));
    final waitlisted = appState.isWaitlisted(event.id);
    final (status, statusColor) = event.isCancelled
        ? (l10n.eventStatusCancelled, theme.colorScheme.error)
        : waitlisted
            ? (l10n.ticketsWaitlistBadge, Colors.orange.shade800)
            : scanned
                ? (l10n.ticketCheckedInBadge, Colors.green.shade700)
                : (l10n.ticketEndedBadge, theme.colorScheme.secondary);
    final reviewed = appState.hasReviewed(event.id);
    final canReview = event.allowReviews && !event.isCancelled && !waitlisted && !reviewed && (!event.requiresQrCode || scanned);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(DateFormat.yMMMd(locale).format(event.date),
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                  const SizedBox(height: 6),
                  Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ],
              ),
            ),
            if (canReview)
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StudentReviewScreen(event: event)),
                ),
                icon: const Icon(Icons.star_rate_rounded, size: 18),
                label: Text(l10n.buttonLeaveReview),
              )
            else if (reviewed)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: l10n.reviewAlreadySubmitted,
                  child: Icon(Icons.star_rounded, color: Colors.amber.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicket(
    BuildContext context,
    Event event,
    String ticketId,
    AppState appState,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (event.isCancelled) return _buildCancelledCard(context, event);
    if (appState.registrationFor(event.id)?.status == RegistrationStatus.waitlisted) {
      return _buildWaitlistCard(context, event, appState);
    }
    final isScanned = appState.isTicketScanned(ticketId);

    final qrPayload = appState.qrPayload(event.id);


    final locale = Localizations.localeOf(context).toString();
    final dateStr = '${DateFormat.yMMMd(locale).format(event.date)}, ${DateFormat.Hm(locale).format(event.date)}';
    final ended = event.endDate.isBefore(DateTime.now());

    final isDark = theme.brightness == Brightness.dark;
    // Ticket header: navy by day, deep violet at night.
    final headerColor = isDark ? const Color(0xFF1B1530) : AppTheme.ink;
    final headerSoft = isDark ? AppTheme.darkMuted : const Color(0xFFB9C0E6);
    final category = event.categories.isEmpty ? null : event.categories.first;
    final headerAccent = isDark ? AppTheme.neon : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x1412141C), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Upper part: coloured header with the event
            Container(
              width: double.infinity,
              color: headerColor,
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -50,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppTheme.violet.withOpacity(0.35) : Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isScanned ? Colors.green : (isDark ? AppTheme.neon : Colors.white),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isScanned
                              ? localizations.ticketCheckedInBadge
                              : (ended ? localizations.ticketEndedBadge : localizations.ticketConfirmedBadge),
                          style: TextStyle(
                            fontFamily: AppTheme.monoFamily,
                            color: isScanned ? Colors.white : (isDark ? AppTheme.darkBackground : AppTheme.ink),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        [if (category != null) categoryLabel(localizations, category), localizations.ticketAdmitOne]
                            .join(' · ')
                            .toUpperCase(),
                        style: monoStyle(size: 10, color: headerSoft, spacing: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.title,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _headerCol(localizations.ticketLabelDate, dateStr, headerSoft, headerAccent),
                          const SizedBox(width: 20),
                          _headerCol(localizations.ticketLabelLocation, event.location, headerSoft, headerAccent),
                        ],
                      ),
                    ],
                  ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoCol(context, localizations.ticketLabelEntry,
                          event.requiresQrCode ? localizations.ticketEntryQr : localizations.ticketEntryOpen),
                      const SizedBox(width: 24),
                      _buildInfoCol(context, localizations.ticketLabelId, ticketId),
                    ],
                  ),
                  if (!isScanned && !ended)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => cancelWithConfirmation(context, appState, event),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text(localizations.ticketCancel),
                        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      ),
                    ),
                  // Debug builds only: lets a single-device tester paste the code into the scanner.
                  if (kDebugMode && appState.usesBackend && appState.registrationFor(event.id)?.ticketCode != null)
                    SelectableText(
                      'debug code: ${appState.registrationFor(event.id)!.ticketCode}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                ],
              ),
            ),

            // Perforated Line Separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  SizedBox(
                    height: 20,
                    width: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Flex(
                          direction: Axis.horizontal,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            (constraints.constrainWidth() / 10).floor(),
                            (_) => SizedBox(
                              width: 5,
                              height: 1.5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: 20,
                    width: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Part (QR Code section)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // QR code generator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: isScanned || !appState.hasValidTicketFor(event.id)
                            ? null
                            : () => QrFullscreenPage.open(context, payload: qrPayload, title: event.title, ticketId: ticketId),
                        child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Opacity(
                          opacity: isScanned ? 0.15 : 1.0,
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 170.0,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black87,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      ),
                      if (isScanned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                localizations.ticketCheckedInBadge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isScanned ? localizations.ticketScannedOk : localizations.ticketShowAtEntrance,
                    style: TextStyle(
                      fontSize: 13,
                      color: isScanned ? Colors.green : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!isScanned && appState.hasValidTicketFor(event.id))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.brightness_high_rounded, size: 15, color: theme.colorScheme.secondary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(localizations.ticketTapToEnlarge,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                          ),
                        ],
                      ),
                    ),
                  if (event.allowReviews) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: ((event.requiresQrCode && !isScanned) ||
                              appState.hasReviewed(event.id) ||
                              (appState.usesBackend && event.date.isAfter(DateTime.now())))
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentReviewScreen(event: event),
                                ),
                              );
                            },
                      icon: const Icon(Icons.star_rate_rounded),
                      label: Text(appState.hasReviewed(event.id)
                          ? localizations.reviewAlreadySubmitted
                          : localizations.buttonLeaveReview),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: theme.colorScheme.surfaceContainer,
                        disabledForegroundColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.38),
                      ),
                    ),
                    if (appState.usesBackend && event.date.isAfter(DateTime.now())) ...[
                      const SizedBox(height: 6),
                      Text(
                        localizations.reviewOpensAtStart,
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (event.requiresQrCode && !isScanned) ...[
                      const SizedBox(height: 6),
                      Text(
                        localizations.reviewRestrictedMsg,
                        style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _headerCol(String label, String value, Color labelColor, Color valueColor) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: monoStyle(size: 9.5, color: labelColor, spacing: 1.2)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildCancelledCard(BuildContext context, Event event) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(localizations.eventStatusCancelled,
                  style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(event.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.lineThrough)),
            const SizedBox(height: 6),
            Text(localizations.ticketEventCancelled, style: TextStyle(color: theme.colorScheme.secondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitlistCard(BuildContext context, Event event, AppState appState) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                localizations.ticketsWaitlistBadge,
                style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(localizations.ticketsWaitlistNote, style: TextStyle(color: theme.colorScheme.secondary)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => cancelWithConfirmation(context, appState, event),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(localizations.ticketCancel),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: monoStyle(size: 9.5, color: Theme.of(context).colorScheme.secondary, spacing: 1.2),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.monoFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
