import '../models/event_model.dart';

class EventRepository {
  final List<Event> _events = [
    Event(
      id: 'evt-1',
      title: 'TUM Hackathon 2026',
      description: 'Collaborate with fellow students to build innovative solutions for smart city challenges. Food and drinks provided!',
      date: DateTime.now().add(const Duration(days: 4)),
      location: 'Interdisciplinary Research Center, Garching',
      universityDomain: 'tum.de',
      isUniversityOfficial: true,
      requiresQrCode: true,
      allowReviews: true,
      categories: const ['Tech', 'Academic'],
      imageUrl: 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800',
    ),
    Event(
      id: 'evt-2',
      title: 'LMU Summer Theater Festival',
      description: 'Experience an outdoor theatrical performance of William Shakespeare\'s "A Midsummer Night\'s Dream" by LMU drama students.',
      date: DateTime.now().add(const Duration(days: 12)),
      location: 'LMU Main Campus Courtyard',
      universityDomain: 'lmu.de',
      isUniversityOfficial: true,
      requiresQrCode: false,
      allowReviews: true,
      categories: const ['Arts', 'Music'],
      imageUrl: 'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?w=800',
    ),
    Event(
      id: 'evt-3',
      title: 'Spring Campus Concert',
      description: 'Join us for an evening of live music, food stalls, and community under the stars. Free entry for all students.',
      date: DateTime.now().add(const Duration(days: 2)),
      location: 'TUM Main Campus Lawn',
      universityDomain: 'tum.de',
      isUniversityOfficial: true,
      requiresQrCode: true,
      allowReviews: false,
      categories: const ['Music', 'Other'],
      imageUrl: 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800',
    ),
    Event(
      id: 'evt-4',
      title: 'Isar Summer Music Festival',
      description: 'A weekend public music festival along the banks of the Isar River featuring local artists, indie bands, and food trucks.',
      date: DateTime.now().add(const Duration(days: 6)),
      location: 'Flaucher Grounds, Isar',
      universityDomain: '',
      isUniversityOfficial: false,
      requiresQrCode: false,
      allowReviews: true,
      categories: const ['Music', 'Other'],
      imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800',
    ),
    Event(
      id: 'evt-5',
      title: 'Munich Marathon Student Training',
      description: 'Get ready for the Munich Marathon with a guided group run! Open to all fitness levels. Meet near the English Garden entrance.',
      date: DateTime.now().add(const Duration(days: 8)),
      location: 'English Garden Entrance',
      universityDomain: '',
      isUniversityOfficial: false,
      requiresQrCode: false,
      allowReviews: false,
      categories: const ['Sports', 'Other'],
      imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=800',
    ),
  ];

  List<Event> getEvents() {
    // Sort events by date: closest event first
    _events.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(_events);
  }

  void addEvent(Event event) {
    _events.add(event);
  }
}
