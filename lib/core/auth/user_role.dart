import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../models/review_model.dart';
import '../services/event_repository.dart';

enum UserRole { student, planner }
enum PlannerType { universityAdmin, commercialPlanner }
enum WallpaperPattern { cyberAurora, frostedGeometry, minimalVelvet }
enum ProfileType { student, universityOrganizer, commercialPlanner }

class MockProfile {
  final String name;
  final String email;
  final String universityDomain;
  final ProfileType type;

  const MockProfile({
    required this.name,
    required this.email,
    required this.universityDomain,
    required this.type,
  });
}

class AppState extends ChangeNotifier {
  UserRole _currentRole = UserRole.student;
  Locale _currentLocale = const Locale('en');
  String _currentTenant = 'TUM'; // Munich Tech University (Example Tenant)
  PlannerType _currentPlannerType = PlannerType.universityAdmin;
  ThemeMode _themeMode = ThemeMode.system;
  WallpaperPattern _selectedWallpaper = WallpaperPattern.minimalVelvet;
  int _activeProfileIndex = 0;
  
  final List<MockProfile> mockProfiles = const [
    MockProfile(
      name: "Alex Smith",
      email: "alex.smith@tum.de",
      universityDomain: "tum.de",
      type: ProfileType.student,
    ),
    MockProfile(
      name: "Dr. Angela Miller",
      email: "angela.miller@tum.de",
      universityDomain: "tum.de",
      type: ProfileType.universityOrganizer,
    ),
    MockProfile(
      name: "Max Mustermann",
      email: "info@superevents.de",
      universityDomain: "public",
      type: ProfileType.commercialPlanner,
    ),
  ];
  
  final EventRepository _eventRepository = EventRepository();
  String _selectedCategory = 'All';

  // Ticket tracking state (mocked backend database)
  final List<String> _registeredEventIds = ['evt-3', 'evt-1'];
  
  // Reviews state (mocked database)
  final List<Review> _reviews = [
    Review(
      id: 'rev-1',
      eventId: 'evt-1',
      rating: 5.0,
      comment: 'Amazing coding environment and great mentors. Had a blast!',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isVerified: true,
    ),
    Review(
      id: 'rev-2',
      eventId: 'evt-4',
      rating: 4.0,
      comment: 'Great bands and food, but it was a bit crowded near the stage.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isVerified: false,
      claimedAttendance: true,
    ),
  ];
  final Map<String, String> _ticketIds = {
    'evt-3': 'TKT-934812',
    'evt-1': 'TKT-512903',
  };
  final Set<String> _scannedTicketIds = {};

  UserRole get currentRole => _currentRole;
  Locale get currentLocale => _currentLocale;
  String get currentTenant => _currentTenant;
  PlannerType get currentPlannerType => _currentPlannerType;
  
  List<Event> get events => _eventRepository.getEvents();
  String get selectedCategory => _selectedCategory;
  List<String> get registeredEventIds => _registeredEventIds;

  final Map<String, Map<String, String>> tenantDetails = {
    'TUM': {
      'en': 'Technical University of Munich',
      'de': 'Technische Universität München',
      'domain': 'tum.de',
    },
    'LMU': {
      'en': 'Ludwig Maximilian University',
      'de': 'Ludwig-Maximilians-Universität München',
      'domain': 'lmu.de',
    },
    'UHH': {
      'en': 'University of Hamburg',
      'de': 'Universität Hamburg',
      'domain': 'uni-hamburg.de',
    },
  };

  void toggleRole() {
    _currentRole = _currentRole == UserRole.student ? UserRole.planner : UserRole.student;
    notifyListeners();
  }

  void setRole(UserRole role) {
    if (_currentRole != role) {
      _currentRole = role;
      notifyListeners();
    }
  }

  void toggleLocale() {
    _currentLocale = _currentLocale.languageCode == 'en' ? const Locale('de') : const Locale('en');
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_currentLocale != locale) {
      _currentLocale = locale;
      notifyListeners();
    }
  }

  void setTenant(String tenant) {
    if (tenantDetails.containsKey(tenant) && _currentTenant != tenant) {
      _currentTenant = tenant;
      notifyListeners();
    }
  }

  String getTenantDisplayName() {
    final language = _currentLocale.languageCode;
    return tenantDetails[_currentTenant]?[language] ?? _currentTenant;
  }

  String getTenantDomain() {
    return tenantDetails[_currentTenant]?['domain'] ?? '';
  }

  void setSelectedCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void addEvent(Event event) {
    _eventRepository.addEvent(event);
    notifyListeners();
  }

  void setPlannerType(PlannerType type) {
    if (_currentPlannerType != type) {
      _currentPlannerType = type;
      notifyListeners();
    }
  }

  bool isRegistered(String eventId) {
    return _registeredEventIds.contains(eventId);
  }

  void registerForEvent(String eventId) {
    if (!_registeredEventIds.contains(eventId)) {
      _registeredEventIds.add(eventId);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final shortTs = timestamp.substring(timestamp.length - 6);
      final hash = (eventId.hashCode.abs() % 1000).toString().padLeft(3, '0');
      _ticketIds[eventId] = 'TKT-$shortTs-$hash';
      notifyListeners();
    }
  }

  String getTicketId(String eventId) {
    return _ticketIds[eventId] ?? '';
  }

  bool isTicketScanned(String ticketId) {
    return _scannedTicketIds.contains(ticketId);
  }

  bool validateAndScanTicket(String ticketId) {
    final validTicket = _ticketIds.containsValue(ticketId);
    if (!validTicket) {
      return false;
    }
    if (_scannedTicketIds.contains(ticketId)) {
      return false;
    }
    _scannedTicketIds.add(ticketId);
    notifyListeners();
    return true;
  }

  // Dynamic university theme color mapping
  Color getUniversityColor(String domainOrTenant) {
    final key = domainOrTenant.toLowerCase();
    if (key.contains('tum')) {
      return const Color(0xFF0065BD); // TUM Tech Blue
    } else if (key.contains('lmu')) {
      return const Color(0xFF0F9D58); // LMU Emerald Green
    } else if (key.contains('hamburg') || key.contains('uhh') || key.contains('uni-hamburg.de')) {
      return const Color(0xFFE2001A); // Hamburg Crimson Red
    }
    return const Color(0xFF6B7280); // Default Slate
  }

  Color getActiveTenantColor() {
    return getUniversityColor(_currentTenant);
  }

  List<Review> get reviews => _reviews;

  List<Review> getReviewsForEvent(String eventId) {
    return _reviews.where((r) => r.eventId == eventId).toList();
  }

  void addReview(Review review) {
    _reviews.add(review);
    notifyListeners();
  }

  bool hasAttended(String eventId) {
    final ticketId = _ticketIds[eventId];
    if (ticketId == null || ticketId.isEmpty) return false;
    return _scannedTicketIds.contains(ticketId);
  }

  int get totalRsvps => 320 + _ticketIds.length;
  int get totalCheckIns => 240 + _scannedTicketIds.length;
  double get attendanceRate => totalRsvps == 0 ? 0.0 : (totalCheckIns / totalRsvps) * 100;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  WallpaperPattern get selectedWallpaper =>
      _currentRole == UserRole.planner ? WallpaperPattern.minimalVelvet : _selectedWallpaper;

  void setWallpaper(WallpaperPattern pattern) {
    if (_selectedWallpaper != pattern) {
      _selectedWallpaper = pattern;
      notifyListeners();
    }
  }

  int get activeProfileIndex => _activeProfileIndex;
  MockProfile get activeProfile => mockProfiles[_activeProfileIndex];

  void setActiveProfileIndex(int index) {
    if (index >= 0 && index < mockProfiles.length && _activeProfileIndex != index) {
      _activeProfileIndex = index;
      final profile = mockProfiles[index];
      
      // Synchronize traditional role fields
      if (profile.type == ProfileType.student) {
        _currentRole = UserRole.student;
      } else {
        _currentRole = UserRole.planner;
        _currentPlannerType = profile.type == ProfileType.universityOrganizer
            ? PlannerType.universityAdmin
            : PlannerType.commercialPlanner;
      }
      
      // Auto-set tenant if university domain matches
      if (profile.universityDomain != 'public' && profile.universityDomain.isNotEmpty) {
        if (profile.universityDomain.contains('tum')) {
          _currentTenant = 'TUM';
        } else if (profile.universityDomain.contains('lmu')) {
          _currentTenant = 'LMU';
        } else if (profile.universityDomain.contains('hamburg') || profile.universityDomain.contains('uni-hamburg')) {
          _currentTenant = 'UHH';
        }
      }
      
      notifyListeners();
    }
  }
}
