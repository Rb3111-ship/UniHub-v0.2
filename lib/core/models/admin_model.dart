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
  final bool emailConfirmed;
  final int eventCount; // events this person organizes
  final DateTime? suspendedAt; // set while an admin is looking into reports
  final bool emailCheckExempt; // permanent organization address: no yearly e-mail check

  const AdminUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.organizerVerified,
    required this.createdAt,
    this.emailConfirmed = true,
    this.eventCount = 0,
    this.suspendedAt,
    this.emailCheckExempt = false,
  });

  factory AdminUser.fromRow(Map<String, dynamic> row) => AdminUser(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?) ?? '',
        email: (row['email'] as String?) ?? '',
        role: row['role'] as String,
        tenantId: row['tenant_id'] as String?,
        organizerVerified: (row['organizer_verified'] as bool?) ?? false,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        emailConfirmed: (row['email_confirmed'] as bool?) ?? true,
        eventCount: (row['event_count'] as num?)?.toInt() ?? 0,
        suspendedAt: row['suspended_at'] == null ? null : DateTime.parse(row['suspended_at'] as String).toLocal(),
        emailCheckExempt: (row['email_check_exempt'] as bool?) ?? false,
      );

  bool get isAdmin => role == 'platform_admin' || role == 'tenant_admin';
  bool get isSuspended => suspendedAt != null;
}

/// An address an admin blocked from signing up.
class BlockedEmail {
  final String email;
  final DateTime blockedAt;
  final String? blockedBy; // admin's name; null if that admin no longer exists

  const BlockedEmail({required this.email, required this.blockedAt, this.blockedBy});

  factory BlockedEmail.fromRow(Map<String, dynamic> row) => BlockedEmail(
        email: row['email'] as String,
        blockedAt: DateTime.parse(row['created_at'] as String).toLocal(),
        blockedBy: row['blocked_by_name'] as String?,
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
  final String? organizerId; // who runs the reported event
  final String organizerName;
  final bool organizerSuspended;
  final String reason;
  final String details;
  final String status; // open | dismissed | removed
  final DateTime createdAt;

  const EventReport({
    required this.id,
    required this.eventId,
    required this.reporterId,
    this.organizerId,
    this.organizerName = '',
    this.organizerSuspended = false,
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
    final organizer = event?['profiles'];
    return EventReport(
      organizerId: event?['organizer_id'] as String?,
      organizerName: organizer is Map ? (organizer['display_name'] as String? ?? '') : '',
      organizerSuspended: organizer is Map && organizer['suspended_at'] != null,
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

/// One report inside a case file. Who reported is never stored.
class CaseEvidence {
  final String eventTitle;
  final String reason;
  final String details;
  final DateTime reportedAt;

  const CaseEvidence({required this.eventTitle, required this.reason, required this.details, required this.reportedAt});

  factory CaseEvidence.fromJson(Map<String, dynamic> j) => CaseEvidence(
        eventTitle: (j['event_title'] as String?) ?? '',
        reason: (j['reason'] as String?) ?? 'other',
        details: (j['details'] as String?) ?? '',
        reportedAt: DateTime.parse(j['reported_at'] as String).toLocal(),
      );
}

/// The lasting record of a suspension, a reinstatement, a removed event or a
/// removed user, with the reports about them as evidence.
class ModerationCase {
  final String id;
  final DateTime createdAt;
  final String action; // event_removed | user_removed | user_suspended | user_reinstated
  final String subjectName;
  final String subjectEmail;
  final String? eventTitle;
  final String? note;
  final bool emailBlocked;
  final String decidedBy;
  final List<CaseEvidence> evidence;

  const ModerationCase({
    required this.id,
    required this.createdAt,
    required this.action,
    required this.subjectName,
    required this.subjectEmail,
    required this.eventTitle,
    required this.note,
    required this.emailBlocked,
    required this.decidedBy,
    required this.evidence,
  });

  factory ModerationCase.fromRow(Map<String, dynamic> row) => ModerationCase(
        id: row['id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        action: row['action'] as String,
        subjectName: (row['subject_name'] as String?) ?? '',
        subjectEmail: (row['subject_email'] as String?) ?? '',
        eventTitle: row['event_title'] as String?,
        note: row['note'] as String?,
        emailBlocked: (row['email_blocked'] as bool?) ?? false,
        decidedBy: (row['decided_by_name'] as String?) ?? '',
        evidence: [
          for (final e in (row['evidence'] as List?) ?? const []) CaseEvidence.fromJson(e as Map<String, dynamic>),
        ],
      );

  bool get isAboutEvent => action == 'event_removed';
}
