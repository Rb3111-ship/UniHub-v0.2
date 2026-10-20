import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import 'review_screen.dart';

class StudentTicketsScreen extends StatelessWidget {
  const StudentTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    final registeredIds = appState.registeredEventIds;
    final allEvents = appState.events;
    
    // Filter events registered by student
    final registeredEvents = allEvents.where((e) => registeredIds.contains(e.id)).toList();

    if (registeredEvents.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.studentTicketsTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 80,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No Active Tickets",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Go to the Home tab and register for events to generate your entrance QR tickets automatically.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.studentTicketsTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: registeredEvents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final event = registeredEvents[index];
          final ticketId = appState.getTicketId(event.id);
          return _buildTicket(context, event, ticketId, appState);
        },
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
    final isScanned = appState.isTicketScanned(ticketId);
    
    // Dynamic color matching event's tenant
    final brandColor = appState.getUniversityColor(event.universityDomain);
    final qrPayload = '{"ticketId": "$ticketId", "eventId": "${event.id}", "userId": "student-1", "userName": "Alex Smith"}';

    // Mock seating information determined deterministically by ticket ID
    final seatSection = String.fromCharCode(65 + (ticketId.hashCode % 4)); // A, B, C, D
    final seatRow = (ticketId.hashCode % 10) + 1;
    final seatNumber = (ticketId.hashCode % 20) + 1;
    final seatInfo = "SEC-$seatSection / ROW-$seatRow / SEAT-$seatNumber";

    final dateStr = "${event.date.day}.${event.date.month}.${event.date.year} @ ${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}";

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isScanned 
              ? Colors.green.withOpacity(0.5) 
              : (event.isUniversityOfficial ? brandColor.withOpacity(0.6) : theme.colorScheme.outlineVariant.withOpacity(0.5)),
          width: event.isUniversityOfficial ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Upper Part (Event Details)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isScanned ? Colors.green : brandColor).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isScanned ? "CHECKED IN" : "CONFIRMED",
                          style: TextStyle(
                            color: isScanned ? Colors.green : brandColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.confirmation_number_outlined, 
                        color: isScanned ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoCol(context, "DATE", dateStr),
                      const SizedBox(width: 24),
                      _buildInfoCol(context, "LOCATION", event.location),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoCol(context, "SEATING", seatInfo),
                      const SizedBox(width: 24),
                      _buildInfoCol(context, "TICKET ID", ticketId),
                    ],
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
                      Container(
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
                            size: 130.0,
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "CHECKED IN",
                                style: TextStyle(
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
                    isScanned ? "Ticket scanned successfully" : "Scan QR code at event entrance",
                    style: TextStyle(
                      fontSize: 12,
                      color: isScanned ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event.allowReviews) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: (event.requiresQrCode && !isScanned)
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
                      label: Text(localizations.buttonLeaveReview),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isScanned ? Colors.green : brandColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: theme.colorScheme.surfaceContainer,
                        disabledForegroundColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.38),
                      ),
                    ),
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

  Widget _buildInfoCol(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
