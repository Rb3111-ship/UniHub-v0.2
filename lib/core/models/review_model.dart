class Review {
  final String id;
  final String eventId;
  final double rating;
  final String comment;
  final DateTime timestamp;
  final bool isVerified;
  final bool claimedAttendance;

  const Review({
    required this.id,
    required this.eventId,
    required this.rating,
    required this.comment,
    required this.timestamp,
    required this.isVerified,
    this.claimedAttendance = false,
  });

  /// Builds a review from a row of the `reviews` table.
  factory Review.fromRow(Map<String, dynamic> row) => Review(
        id: row['id'] as String,
        eventId: row['event_id'] as String,
        rating: (row['rating'] as num).toDouble(),
        comment: row['comment'] as String,
        timestamp: DateTime.parse(row['created_at'] as String).toLocal(),
        isVerified: row['is_verified'] as bool,
        claimedAttendance: (row['claimed_attendance'] as bool?) ?? false,
      );
}
