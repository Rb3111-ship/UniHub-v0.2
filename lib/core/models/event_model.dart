class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String universityDomain; // e.g. "tum.de", "lmu.de"
  final bool isUniversityOfficial;
  final bool requiresQrCode;
  final bool allowReviews;
  final List<String> categories; // e.g. ["Music", "Tech", "Academic"]
  final String? imageUrl;
  final List<String>? galleryImages;

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
  });

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
    );
  }
}
