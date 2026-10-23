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
    );
  }

  bool get isPending => status == 'pending';
  bool get isCommercial => requestedRole == 'commercial_planner';
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
