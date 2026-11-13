/// A person in the signed-in organizer's team (or someone they invited).
class TeamMember {
  final String id; // the team row, used for changing and removing
  final String name;
  final String email;
  final bool canScan;
  final bool canEdit;
  final bool isActive; // false: invited, not accepted yet

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.canScan,
    required this.canEdit,
    required this.isActive,
  });

  factory TeamMember.fromRow(Map<String, dynamic> row) => TeamMember(
        id: row['id'] as String,
        name: (row['name'] as String?) ?? '',
        email: (row['email'] as String?) ?? '',
        canScan: (row['can_scan'] as bool?) ?? false,
        canEdit: (row['can_edit'] as bool?) ?? false,
        isActive: row['status'] == 'active',
      );
}

/// A team the signed-in user helps (or was invited to).
class TeamMembership {
  final String id;
  final String organizerId;
  final String organizerName;
  final bool canScan;
  final bool canEdit;
  final bool isActive; // false: an invitation waiting for an answer
  /// False while the team is paused (the organizer or this account is
  /// suspended, or this account is no longer at the organizer's university).
  final bool usable;
  final String? organizerTenant;
  final String organizerRole;

  const TeamMembership({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    required this.canScan,
    required this.canEdit,
    required this.isActive,
    required this.usable,
    required this.organizerTenant,
    required this.organizerRole,
  });

  factory TeamMembership.fromRow(Map<String, dynamic> row) => TeamMembership(
        id: row['id'] as String,
        organizerId: row['organizer_id'] as String,
        organizerName: (row['organizer_name'] as String?) ?? '',
        canScan: (row['can_scan'] as bool?) ?? false,
        canEdit: (row['can_edit'] as bool?) ?? false,
        isActive: row['status'] == 'active',
        usable: (row['usable'] as bool?) ?? false,
        organizerTenant: row['organizer_tenant'] as String?,
        organizerRole: (row['organizer_role'] as String?) ?? 'organizer',
      );

  /// Events made for this organizer are campus events of their university
  /// (commercial planners publish public events instead).
  bool get isCampus => organizerTenant != null && organizerRole != 'commercial_planner';
}
