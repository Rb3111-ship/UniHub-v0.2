import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  /// [client] null = offline mock mode (tests, demos): no sign-in, fake profiles.
  /// With a client, the signed-in user's profile drives role, tenant and name.
  AppState({SupabaseClient? client}) : _client = client {
    final c = client;
    if (c == null) {
      final mock = MockEventRepository();
      _eventRepository = mock;
      _events = mock.all;
    } else {
      _eventRepository = SupabaseEventRepository(c, _domainForSlug);
      // Real accounts start empty; registrations/tickets/reviews move to the
      // database in a later step.
      _registeredEventIds.clear();
      _ticketIds.clear();
      _reviews.clear();
      _session = c.auth.currentSession;
      _authSub = c.auth.onAuthStateChange.listen(_onAuthChange);
    }
  }

  final SupabaseClient? _client;
  late final EventRepository _eventRepository;
  List<Event> _events = [];
  bool _eventsLoading = false;
  bool _eventsError = false;
  String? _tenantId;

  String _domainForSlug(String slug) => tenantDetails[slug.toUpperCase()]?['domain'] ?? '';
  StreamSubscription<AuthState>? _authSub;
  Session? _session;
  MockProfile? _remoteProfile;
  bool _profileFailed = false;

  bool get usesBackend => _client != null;
  bool get isSignedIn => !usesBackend || _session != null;
  bool get profileReady => !usesBackend || _remoteProfile != null;
  bool get profileFailed => _profileFailed;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onAuthChange(AuthState data) {
    _session = data.session;
    final user = data.session?.user;
    if (user == null) {
      _remoteProfile = null;
      _profileFailed = false;
      _currentRole = UserRole.student;
      _currentTenant = '';
      _tenantId = null;
      _events = [];
      notifyListeners();
    } else if (data.event != AuthChangeEvent.tokenRefreshed) {
      loadProfile();
    }
  }

  /// Loads the signed-in user's profile + university from the database.
  Future<void> loadProfile() async {
    final c = _client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    _profileFailed = false;
    try {
      final row = await c
          .from('profiles')
          .select('display_name, role, tenant_id, tenants(slug)')
          .eq('id', user.id)
          .single();
      final slug = ((row['tenants'] as Map?)?['slug'] as String?)?.toUpperCase();
      final role = row['role'] as String;
      _tenantId = row['tenant_id'] as String?;
      final type = switch (role) {
        'student' => ProfileType.student,
        'commercial_planner' => ProfileType.commercialPlanner,
        _ => ProfileType.universityOrganizer, // organizer, tenant_admin, platform_admin
      };
      _currentRole = type == ProfileType.student ? UserRole.student : UserRole.planner;
      if (type != ProfileType.student) {
        _currentPlannerType = type == ProfileType.commercialPlanner
            ? PlannerType.commercialPlanner
            : PlannerType.universityAdmin;
      }
      _currentTenant = (slug != null && tenantDetails.containsKey(slug)) ? slug : '';
      _remoteProfile = MockProfile(
        name: (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? row['display_name'] as String
            : (user.email ?? ''),
        email: user.email ?? '',
        universityDomain: tenantDetails[_currentTenant]?['domain'] ?? 'public',
        type: type,
      );
    } catch (_) {
      _remoteProfile = null;
      _profileFailed = true;
    }
    notifyListeners();
    if (_remoteProfile != null) refreshEvents();
  }

  Future<void> signIn(String email, String password) async {
    await _client!.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Returns true if the user is signed in immediately, false if an e-mail code is needed.
  Future<bool> signUp(String email, String password, String displayName) async {
    final res = await _client!.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    return res.session != null;
  }

  Future<void> verifySignUpCode(String email, String code) async {
    await _client!.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.signup);
  }

  Future<void> resendSignUpCode(String email) async {
    await _client!.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> sendPasswordResetCode(String email) async {
    await _client!.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> resetPasswordWithCode(String email, String code, String newPassword) async {
    await _client!.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.recovery);
    await _client!.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  /// Email domain -> university display name, for the live hint on the sign-up form.
  String? universityForEmail(String email) {
    final at = email.indexOf('@');
    if (at < 0) return null;
    final domain = email.substring(at + 1).trim().toLowerCase();
    for (final entry in tenantDetails.entries) {
      final d = entry.value['domain']!;
      if (domain == d || domain.endsWith('.$d')) return entry.value[_currentLocale.languageCode];
    }
    return null;
  }

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
  
  List<Event> get events => List.unmodifiable(_events);
  bool get eventsLoading => _eventsLoading;
  bool get eventsError => _eventsError;

  /// Reloads the feed from the backend (pull-to-refresh, after sign-in).
  Future<void> refreshEvents() async {
    if (_eventsLoading) return;
    _eventsLoading = true;
    _eventsError = false;
    notifyListeners();
    try {
      _events = await _eventRepository.fetchUpcoming();
    } catch (_) {
      _eventsError = true;
    }
    _eventsLoading = false;
    notifyListeners();
  }
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

  /// Publishes an event. Throws (e.g. PostgrestException 42501) if not allowed.
  Future<void> addEvent(Event event) async {
    final tenantId = event.isUniversityOfficial ? _tenantId : null;
    if (event.isUniversityOfficial && usesBackend && tenantId == null) {
      throw const AuthException('No university linked to this account');
    }
    final created = await _eventRepository.create(event, tenantId: tenantId);
    _events = [..._events, created]..sort((a, b) => a.date.compareTo(b.date));
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
  MockProfile get activeProfile => _remoteProfile ?? mockProfiles[_activeProfileIndex];

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
