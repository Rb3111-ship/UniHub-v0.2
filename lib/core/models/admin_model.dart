import 'dart:typed_data';

/// A user's request to become an organizer / commercial planner.
class OrganizerRequest {
  final String id;
  final String userId;
  final String displayName;
  final String email;
  final String requestedRole; // organizer | commercial_planner
  final String organizationName;
  final String message;
  final String status; // pending | approved | rejected
  final String? reviewNote;
  final DateTime createdAt;
  // Verification details (requests from before v0.2.5 may not have them).
  final String? position;
  final String? phone;
  final String? website;
  final List<String> documents; // paths in the private organizer-docs bucket

  const OrganizerRequest({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.requestedRole,
    required this.organizationName,
    required this.message,
    required this.status,
    required this.reviewNote,
    required this.createdAt,
    this.position,
    this.phone,
    this.website,
    this.documents = const [],
  });

  factory OrganizerRequest.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    return OrganizerRequest(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      displayName: profile is Map ? (profile['display_name'] as String? ?? '') : '',
      email: (row['email'] as String?) ?? '',
      requestedRole: row['requested_role'] as String,
      organizationName: row['organization_name'] as String,
      message: (row['message'] as String?) ?? '',
      status: row['status'] as String,
      reviewNote: row['review_note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      position: row['applicant_position'] as String?,
      phone: row['phone'] as String?,
      website: row['website_url'] as String?,
      documents: [for (final d in (row['documents'] as List?) ?? const []) d as String],
    );
  }

  bool get isPending => status == 'pending';
  bool get isCommercial => requestedRole == 'commercial_planner';
}

/// A file the applicant attached as proof (school reference, club registration...).
class ApplicationDocument {
  static const maxBytes = 5 * 1024 * 1024;
  static const extensions = ['pdf', 'jpg', 'jpeg', 'png'];

  final String name;
  final Uint8List bytes;

  const ApplicationDocument(this.name, this.bytes);

  /// pdf, jpg or png (the only names the storage accepts).
  String get extension {
    final e = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return e == 'jpeg' ? 'jpg' : e;
  }

  String get contentType => switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };
}

/// Everything a student sends when asking to become an organizer.
class OrganizerApplication {
  final String role; // organizer | commercial_planner
  final String organization;
  final String position;
  final String phone;
  final String? website;
  final String message;
  final List<ApplicationDocument> documents;

  const OrganizerApplication({
    required this.role,
    required this.organization,
    required this.position,
    required this.phone,
    this.website,
    this.message = '',
    this.documents = const [],
  });
}

/// A row of the admin user list.
class AdminUser {
  final String id;
  final String displayName;
  final String email;
  final String role;
  final String? tenantId;
  final bool organizerVerified;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.organizerVerified,
    required this.createdAt,
  });

  factory AdminUser.fromRow(Map<String, dynamic> row) => AdminUser(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?) ?? '',
        email: (row['email'] as String?) ?? '',
        role: row['role'] as String,
        tenantId: row['tenant_id'] as String?,
        organizerVerified: (row['organizer_verified'] as bool?) ?? false,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
}

/// A student's report about an event, as seen by admins.
class EventReport {
  static const reasons = ['spam', 'inappropriate', 'misleading', 'scam', 'other'];

  final String id;
  final String eventId;
  final String reporterId;
  final String eventTitle;
  final DateTime? eventStart;
  final String eventStatus;
  final String reason;
  final String details;
  final String status; // open | dismissed | removed
  final DateTime createdAt;

  const EventReport({
    required this.id,
    required this.eventId,
    required this.reporterId,
    required this.eventTitle,
    required this.eventStart,
    required this.eventStatus,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  factory EventReport.fromRow(Map<String, dynamic> row) {
    final event = row['events'] as Map?;
    final start = event?['starts_at'] as String?;
    return EventReport(
      id: row['id'] as String,
      eventId: row['event_id'] as String,
      reporterId: row['reporter_id'] as String,
      eventTitle: (event?['title'] as String?) ?? '',
      eventStart: start == null ? null : DateTime.parse(start).toLocal(),
      eventStatus: (event?['status'] as String?) ?? '',
      reason: row['reason'] as String,
      details: (row['details'] as String?) ?? '',
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  bool get isOpen => status == 'open';
}
