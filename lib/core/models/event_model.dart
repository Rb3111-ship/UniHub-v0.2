class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? _endDate;
  final String location;
  final String universityDomain; // e.g. "tum.de", "lmu.de"
  final bool isUniversityOfficial;
  final bool requiresQrCode;
  final bool allowReviews;
  final List<String> categories; // e.g. ["Music", "Tech", "Academic"]
  final String? imageUrl;
  final List<String>? galleryImages;
  final int? capacity; // null = unlimited
  final int priceCents;
  final String status; // draft | published | cancelled
  final String? imagePath; // path inside the event-images storage bucket
  final String? organizerId; // null in demo data

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.universityDomain,
    required this.isUniversityOfficial,
    required this.requiresQrCode,
    required this.allowReviews,
    required this.categories,
    this.imageUrl,
    this.galleryImages,
    DateTime? endDate,
    this.capacity,
    this.priceCents = 0,
    this.status = 'published',
    this.imagePath,
    this.organizerId,
  }) : _endDate = endDate;

  bool get isCancelled => status == 'cancelled';

  /// End of the event; defaults to two hours after the start.
  DateTime get endDate => _endDate ?? date.add(const Duration(hours: 2));

  /// Builds an event from a row of the `events` table.
  factory Event.fromRow(
    Map<String, dynamic> row, {
    required String universityDomain,
    String? imageUrl,
  }) {
    return Event(
      id: row['id'] as String,
      title: row['title'] as String,
      description: (row['description'] as String?) ?? '',
      date: DateTime.parse(row['starts_at'] as String).toLocal(),
      endDate: DateTime.parse(row['ends_at'] as String).toLocal(),
      location: row['location'] as String,
      universityDomain: universityDomain,
      isUniversityOfficial: row['tenant_id'] != null,
      requiresQrCode: row['requires_qr'] as bool,
      allowReviews: row['allow_reviews'] as bool,
      categories: List<String>.from(row['categories'] as List),
      imageUrl: imageUrl,
      capacity: row['capacity'] as int?,
      priceCents: (row['price_cents'] as int?) ?? 0,
      status: (row['status'] as String?) ?? 'published',
      imagePath: row['image_path'] as String?,
      organizerId: row['organizer_id'] as String?,
    );
  }

  String get category => categories.isNotEmpty ? categories.first : 'Other';

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    String? universityDomain,
    bool? isUniversityOfficial,
    bool? requiresQrCode,
    bool? allowReviews,
    List<String>? categories,
    String? imageUrl,
    List<String>? galleryImages,
    DateTime? endDate,
    int? capacity,
    int? priceCents,
    String? status,
    String? imagePath,
    String? organizerId,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      universityDomain: universityDomain ?? this.universityDomain,
      isUniversityOfficial: isUniversityOfficial ?? this.isUniversityOfficial,
      requiresQrCode: requiresQrCode ?? this.requiresQrCode,
      allowReviews: allowReviews ?? this.allowReviews,
      categories: categories ?? this.categories,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      endDate: endDate ?? _endDate,
      capacity: capacity ?? this.capacity,
      priceCents: priceCents ?? this.priceCents,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      organizerId: organizerId ?? this.organizerId,
    );
  }
}
