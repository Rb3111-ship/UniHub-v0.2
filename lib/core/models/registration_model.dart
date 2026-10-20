import 'event_model.dart';

enum RegistrationStatus { registered, waitlisted, cancelled }

/// The signed-in user's registration for an event, with its ticket (if any).
class Registration {
  final String id;
  final Event event;
  final RegistrationStatus status;

  /// Secret value encoded in the QR code. Null while waitlisted.
  final String? ticketCode;
  final int? ticketNumber;
  final DateTime? checkedInAt;
  final bool ticketVoided;

  const Registration({
    required this.id,
    required this.event,
    required this.status,
    this.ticketCode,
    this.ticketNumber,
    this.checkedInAt,
    this.ticketVoided = false,
  });

  bool get isActive => status != RegistrationStatus.cancelled;
  bool get hasValidTicket =>
      status == RegistrationStatus.registered && ticketCode != null && !ticketVoided;
  bool get isCheckedIn => checkedInAt != null;

  /// Human-readable ticket id, e.g. TKT-000042.
  String get displayTicketId =>
      ticketNumber == null ? '' : 'TKT-${ticketNumber.toString().padLeft(6, '0')}';

  static RegistrationStatus parseStatus(String value) => switch (value) {
        'registered' => RegistrationStatus.registered,
        'waitlisted' => RegistrationStatus.waitlisted,
        _ => RegistrationStatus.cancelled,
      };
}

/// Result of a door scan, as returned by the `check_in_ticket` database function.
class CheckInResult {
  final bool ok;
  final String result; // granted | already_used | invalid | wrong_event | cancelled
  final String? attendeeName;
  final int? ticketNumber;

  const CheckInResult({
    required this.ok,
    required this.result,
    this.attendeeName,
    this.ticketNumber,
  });

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
        ok: json['ok'] as bool? ?? false,
        result: json['result'] as String? ?? 'invalid',
        attendeeName: json['attendee_name'] as String?,
        ticketNumber: json['ticket_number'] as int?,
      );

  String get ticketDisplayId =>
      ticketNumber == null ? '' : 'TKT-${ticketNumber.toString().padLeft(6, '0')}';
}
