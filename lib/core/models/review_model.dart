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
}
