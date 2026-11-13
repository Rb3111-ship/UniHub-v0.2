import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../models/event_host.dart';
import '../models/event_model.dart';
import '../models/review_model.dart';
import '../models/admin_model.dart';
import '../models/notification_model.dart';
import '../services/community_repository.dart';
import '../services/notification_repository.dart';
import '../services/push_service.dart';
import '../models/dashboard_model.dart';
import '../models/registration_model.dart';
import '../models/team_model.dart';
import '../services/account_repository.dart';
import '../services/event_repository.dart';
import '../services/insights_repository.dart';
import '../services/registration_repository.dart';

enum UserRole { student, planner }
enum PlannerType { universityAdmin, commercialPlanner }
/// Saved by name on the device, so existing names must not be renamed.
/// cyberAurora = "Sunset", frostedGeometry = "Grid", minimalVelvet = "None".
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
  /// [push] is only passed by the real app; tests and demos run without Firebase.
  AppState({SupabaseClient? client, PushService? push}) : _client = client, _push = push {
    final c = client;
    if (c == null) {
      final mock = MockEventRepository();
      _eventRepository = mock;
      _events = mock.all;
    } else {
      _eventRepository = SupabaseEventRepository(c, _domainForSlug);
      _registrationRepository = RegistrationRepository(c, _domainForSlug);
      _insightsRepository = InsightsRepository(c);
      _accountRepository = AccountRepository(c);
      _communityRepository = CommunityRepository(c);
      _notificationRepository = NotificationRepository(c);
      // A message arriving while the app is open is also a new inbox entry.
      _pushSub = push?.messages.listen((_) => refreshNotifications());
      // Real accounts start empty; registrations/tickets/reviews move to the
      // database in a later step.
      _registeredEventIds.clear();
      _ticketIds.clear();
      _reviews.clear();
      _session = c.auth.currentSession;
      _authSub = c.auth.onAuthStateChange.listen(_onAuthChange);
      // A sign-in restored at app start may be reported as a token refresh (or not
      // at all), so load the profile here instead of waiting for an auth event.
      if (_session != null) {
        loadProfile();
      } else {
        refreshEvents(); // signed-out visitors see the public feed
      }
    }
    _loadLookPreferences();
  }

  final SupabaseClient? _client;
  late final EventRepository _eventRepository;
  RegistrationRepository? _registrationRepository;
  InsightsRepository? _insightsRepository;
  AccountRepository? _accountRepository;
  CommunityRepository? _communityRepository;
  NotificationRepository? _notificationRepository;
  final PushService? _push;
  StreamSubscription<PushMessage>? _pushSub;
  List<AppNotification> _notifications = [];
  bool _notifyReminders = true;
  bool _notifyUpdates = true;
  PushStatus _pushStatus = PushStatus.unavailable;
  Set<String> _favoriteIds = {};
  List<EventReport> _reports = [];
  String _dbRole = 'student';
  OrganizerRequest? _myRequest;
  List<OrganizerRequest> _requests = [];
  List<AdminUser> _adminUsers = [];
  bool _adminLoading = false;
  bool _adminError = false;
  Map<String, EventRating> _ratings = {};
  Set<String> _myReviewedEventIds = {};
  final Set<String> _locallyReviewed = {}; // mock mode only
  DashboardData _dashboard = const DashboardData();
  List<({Review review, String eventTitle})> _feedback = [];
  List<Event> _managedEvents = [];
  bool _dashboardLoading = false;
  bool _dashboardError = false;
  List<Registration> _registrations = [];
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

  /// False once the account that started a request has signed out or changed,
  /// so a slow answer for the previous account is never shown to the next one.
  bool _stillSignedInAs(String? uid) => uid != null && uid == currentUserId;

  /// Id of the signed-in user (null in demo mode or when signed out).
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Organizers cannot register for their own events (the database refuses it too).
  bool isOwnEvent(Event event) => event.organizerId != null && event.organizerId == currentUserId;

  // Signed-out visitors see the public events feed (guest mode) until they choose
  // to sign in; the sign-in screen can send them back to the feed.
  bool _guest = true;
  bool get isGuest => usesBackend && _session == null && _guest;

  void enterGuestMode() {
    if (!usesBackend) return;
    _guest = true;
    notifyListeners();
    refreshEvents();
  }

  /// Shows the sign-in / sign-up screen.
  void leaveGuestMode() {
    _guest = false;
    notifyListeners();
  }
  bool get isSignedIn => !usesBackend || _session != null;
  bool get profileReady => !usesBackend || _remoteProfile != null;
  bool get profileFailed => _profileFailed;

  @override
  void dispose() {
    _authSub?.cancel();
    _pushSub?.cancel();
    super.dispose();
  }

  String? _profileUserId;
  Future<void>? _profileLoad;

  void _onAuthChange(AuthState data) {
    _session = data.session;
    final user = data.session?.user;
    if (user == null) {
      _profileUserId = null;
      _remoteProfile = null;
      _profileFailed = false;
      _guest = true; // back to the public feed
      _avatarPath = null;
      _organizerVerified = false;
      _suspended = false;
      _teamMembers = [];
      _teamMemberships = [];
      _emailCheckedAt = null;
      _emailCheckExempt = false;
      _emailCheckLapsed = false;
      _currentRole = UserRole.student;
      _currentTenant = '';
      _tenantId = null;
      _dbRole = 'student';
      _myRequest = null;
      _requests = [];
      _adminUsers = [];
      _favoriteIds = {};
      _reports = [];
      _notifications = [];
      _notifyReminders = true;
      _notifyUpdates = true;
      _events = [];
      _registrations = [];
      _ratings = {};
      _myReviewedEventIds = {};
      _dashboard = const DashboardData();
      _feedback = [];
      _managedEvents = [];
      notifyListeners();
      refreshEvents();
    } else if (_remoteProfile == null || _profileUserId != user.id || data.event == AuthChangeEvent.userUpdated) {
      // New sign-in, restored session or a different account. Plain token
      // refreshes for the same user need no reload.
      loadProfile();
    }
  }

  /// Loads the signed-in user's profile + university from the database.
  /// Concurrent calls share one request.
  Future<void> loadProfile() => _profileLoad ??= _loadProfile().whenComplete(() => _profileLoad = null);

  Future<void> _loadProfile() async {
    final c = _client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    if (_profileUserId != user.id) _remoteProfile = null; // never show the previous account
    _profileFailed = false;
    try {
      final row = await c
          .from('profiles')
          .select('display_name, role, tenant_id, locale, avatar_path, organizer_verified, suspended_at, '
              'email_checked_at, email_check_exempt, email_check_lapsed_at, '
              'notify_reminders, notify_updates, tenants(slug)')
          .eq('id', user.id)
          .single();
      final slug = ((row['tenants'] as Map?)?['slug'] as String?)?.toUpperCase();
      final firstLoad = _remoteProfile == null;
      final role = row['role'] as String;
      // Approved as an organizer while the app was open: switch to the organizer tools.
      final becameOrganizer = !firstLoad && _dbRole == 'student' && role != 'student';
      _dbRole = role;
      _tenantId = row['tenant_id'] as String?;
      _avatarPath = row['avatar_path'] as String?;
      _organizerVerified = row['organizer_verified'] as bool? ?? false;
      _suspended = row['suspended_at'] != null;
      final checked = row['email_checked_at'] as String?;
      _emailCheckedAt = checked == null ? null : DateTime.parse(checked).toLocal();
      _emailCheckExempt = row['email_check_exempt'] as bool? ?? false;
      _emailCheckLapsed = row['email_check_lapsed_at'] != null;
      _notifyReminders = row['notify_reminders'] as bool? ?? true;
      _notifyUpdates = row['notify_updates'] as bool? ?? true;
      final savedLocale = row['locale'] as String?;
      if (firstLoad && AppLocalizations.supportedLocales.any((l) => l.languageCode == savedLocale)) {
        _currentLocale = Locale(savedLocale!);
      }
      final type = switch (role) {
        'student' => ProfileType.student,
        'commercial_planner' => ProfileType.commercialPlanner,
        _ => ProfileType.universityOrganizer, // organizer, tenant_admin, platform_admin
      };
      // Organizers start in organizer view but may switch to student view; keep their choice on reloads.
      if (type == ProfileType.student) {
        _currentRole = UserRole.student;
      } else if (firstLoad || becameOrganizer) {
        _currentRole = UserRole.planner;
        if (becameOrganizer) _loginNotice = 'became_organizer';
      }
      if (type != ProfileType.student) {
        _currentPlannerType = type == ProfileType.commercialPlanner
            ? PlannerType.commercialPlanner
            : PlannerType.universityAdmin;
      }
      _currentTenant = (slug != null && tenantDetails.containsKey(slug)) ? slug : '';
      _profileUserId = user.id;
      _remoteProfile = MockProfile(
        name: (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? row['display_name'] as String
            : (user.email ?? ''),
        email: user.email ?? '',
        universityDomain: tenantDetails[_currentTenant]?['domain'] ?? 'public',
        type: type,
      );
    } catch (_) {
      // A failed reload must not kick a signed-in user back to the loading screen.
      if (_remoteProfile == null) _profileFailed = true;
    }
    notifyListeners();
    if (_remoteProfile != null) {
      refreshEvents();
      refreshRegistrations();
      refreshMyReviews();
      refreshFavorites();
      refreshNotifications();
      if (_pushStartedFor != user.id) _startPush(); // once per sign-in
      if (_dbRole != 'student') refreshDashboard();
      if (_dbRole == 'student') refreshMyRequest();
      refreshTeams();
      if (isAdmin) {
        refreshRequests();
        refreshReports();
      }
    }
  }

  // ---- notifications ---------------------------------------------------------

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;
  bool get notifyReminders => _notifyReminders;
  bool get notifyUpdates => _notifyUpdates;
  PushStatus get pushStatus => _pushStatus;

  /// Push messages received while the app is open, or tapped in the phone's list.
  Stream<PushMessage> get pushMessages => _push?.messages ?? const Stream.empty();

  String? _pushStartedFor;

  Future<void> _startPush() async {
    final push = _push;
    final repo = _notificationRepository;
    if (push == null || repo == null) return;
    _pushStartedFor = currentUserId;
    _pushStatus = await push.start((token) => repo.registerDevice(token, PushService.platformName));
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    final repo = _notificationRepository;
    if (repo == null || _session == null) return;
    final uid = currentUserId;
    try {
      final list = await repo.fetch().timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _notifications = list;
      notifyListeners();
      // A suspension or reinstatement arrived while the app was open: reload the profile.
      for (final n in list) {
        if (n.kind == 'account_suspended' || n.kind == 'account_reinstated') {
          if ((n.kind == 'account_suspended') != _suspended) loadProfile();
          break; // the list is newest first
        }
      }
    } catch (_) {
      // Shown again on the next refresh.
    }
  }

  Future<void> markNotificationsRead([List<int>? ids]) async {
    final targets = ids ?? [for (final n in _notifications) if (!n.isRead) n.id];
    if (targets.isEmpty) return;
    _notifications = [for (final n in _notifications) targets.contains(n.id) ? n.markedRead() : n];
    notifyListeners();
    try {
      await _notificationRepository?.markRead(targets);
    } catch (_) {
      // Only the read marker is lost; the next refresh shows the server's state.
    }
  }

  /// Removes notifications from the list at once; they come back if the server refuses.
  Future<bool> deleteNotifications([List<int>? ids]) async {
    final targets = ids ?? [for (final n in _notifications) n.id];
    if (targets.isEmpty) return true;
    final before = _notifications;
    _notifications = [for (final n in _notifications) if (!targets.contains(n.id)) n];
    notifyListeners();
    try {
      await _notificationRepository?.delete(targets).timeout(_requestTimeout);
      return true;
    } catch (_) {
      _notifications = before;
      notifyListeners();
      return false;
    }
  }

  /// Turns reminders or event updates on/off. Flips back if the server refuses.
  Future<void> setNotificationSettings({bool? reminders, bool? updates}) async {
    final before = (_notifyReminders, _notifyUpdates);
    _notifyReminders = reminders ?? _notifyReminders;
    _notifyUpdates = updates ?? _notifyUpdates;
    notifyListeners();
    try {
      await _notificationRepository?.saveSettings(reminders: reminders, updates: updates);
    } catch (_) {
      _notifyReminders = before.$1;
      _notifyUpdates = before.$2;
      notifyListeners();
      rethrow;
    }
  }

  /// The event a notification points to: from the feed or tickets if loaded,
  /// otherwise from the server (null if it is no longer visible).
  Future<Event?> eventById(String id) async {
    for (final e in [..._events, ...registeredEvents, ..._managedEvents]) {
      if (e.id == id) return e;
    }
    try {
      return await _eventRepository.fetchById(id).timeout(_requestTimeout);
    } catch (_) {
      return null;
    }
  }

  // ---- favourites ----------------------------------------------------------

  bool isFavorite(String eventId) => _favoriteIds.contains(eventId);
  int get favoriteCount => _favoriteIds.length;

  Future<void> refreshFavorites() async {
    final repo = _communityRepository;
    if (repo == null) return;
    final uid = currentUserId;
    try {
      final ids = await repo.fetchFavoriteIds().timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _favoriteIds = ids;
      notifyListeners();
    } catch (_) {
      // Shown again on the next refresh.
    }
  }

  /// Saves or un-saves an event. The heart changes at once and flips back if
  /// the server refuses.
  Future<void> toggleFavorite(String eventId) async {
    final saved = !_favoriteIds.contains(eventId);
    saved ? _favoriteIds.add(eventId) : _favoriteIds.remove(eventId);
    notifyListeners();
    final repo = _communityRepository;
    if (repo == null) return; // demo mode: kept on this device only
    try {
      saved ? await repo.addFavorite(eventId) : await repo.removeFavorite(eventId);
    } catch (_) {
      saved ? _favoriteIds.remove(eventId) : _favoriteIds.add(eventId);
      notifyListeners();
      rethrow;
    }
  }

  // ---- reports ---------------------------------------------------------------

  Future<void> reportEvent(String eventId, String reason, String details) =>
      _communityRepository!.reportEvent(eventId, reason, details);

  List<EventReport> get eventReports => List.unmodifiable(_reports);
  int get openReportCount => _reports.where((r) => r.isOpen).length;

  Future<void> refreshReports() async {
    final repo = _communityRepository;
    if (repo == null || !isAdmin) return;
    try {
      // An admin's own reports are visible to them as the reporter; only show
      // the ones they may act on.
      final me = currentUserId;
      final reports = await repo.fetchReports().timeout(_requestTimeout);
      if (!_stillSignedInAs(me)) return;
      _reports = reports.where((r) => r.reporterId != me || isPlatformAdmin).toList();
      notifyListeners();
    } catch (_) {
      _adminError = true;
      notifyListeners();
    }
  }

  Future<void> resolveReport(String id, bool remove, String? note) async {
    await _communityRepository!.resolveReport(id, remove, note);
    await refreshReports();
    if (remove) refreshEvents();
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
    // The code was right, so the person is signed in from here on.
    try {
      await _client!.auth.updateUser(UserAttributes(password: newPassword));
      _loginNotice = 'password_changed';
    } on AuthApiException catch (e) {
      // Typing the old password again is not an error for the user: it simply stays.
      if (e.code != 'same_password') {
        _loginNotice = 'password_not_changed';
        notifyListeners();
        return;
      }
      _loginNotice = 'password_same';
    }
    notifyListeners();
  }

  // ---- teams -----------------------------------------------------------------
  // An organizer's helpers: who may scan and who may create and edit events.
  // The server decides every time; these lists are only for showing.

  List<TeamMember> _teamMembers = [];
  List<TeamMembership> _teamMemberships = [];

  /// The signed-in organizer's own team (invited and accepted).
  List<TeamMember> get teamMembers => List.unmodifiable(_teamMembers);

  /// Teams this account helps, and invitations waiting for an answer.
  List<TeamMembership> get teamMemberships => List.unmodifiable(_teamMemberships);

  int get teamInvitationCount => _teamMemberships.where((m) => !m.isActive).length;

  /// Approved organizers and admins can have a team.
  bool get canHaveTeam => usesBackend && _dbRole != 'student' && _organizerVerified && !_suspended;

  Future<void> refreshTeams() async {
    final c = _client;
    final uid = currentUserId;
    if (c == null || uid == null) return;
    try {
      final results = await Future.wait([
        c.rpc('team_my_memberships'),
        if (canHaveTeam) c.rpc('team_my_members'),
      ]).timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _teamMemberships = [for (final r in results[0] as List) TeamMembership.fromRow(r as Map<String, dynamic>)];
      _teamMembers = results.length > 1
          ? [for (final r in results[1] as List) TeamMember.fromRow(r as Map<String, dynamic>)]
          : [];
      notifyListeners();
    } catch (_) {
      // Shown again on the next refresh.
    }
  }

  /// Invites the account with [email]. The server answers the same whether or
  /// not such an account exists, so the invite box reveals nothing.
  Future<void> inviteTeammate(String email, {required bool canScan, required bool canEdit}) async {
    await _client!.rpc('team_invite', params: {'p_email': email, 'p_can_scan': canScan, 'p_can_edit': canEdit})
        .timeout(_requestTimeout);
    await refreshTeams();
  }

  Future<void> answerTeamInvite(String id, bool accept) async {
    await _client!.rpc('team_respond', params: {'p_id': id, 'p_accept': accept}).timeout(_requestTimeout);
    await refreshTeams();
  }

  Future<void> setTeamPermissions(String id, {required bool canScan, required bool canEdit}) async {
    await _client!.rpc('team_set_permissions', params: {'p_id': id, 'p_can_scan': canScan, 'p_can_edit': canEdit})
        .timeout(_requestTimeout);
    await refreshTeams();
  }

  /// The organizer removes a teammate (or withdraws an invitation), or a teammate leaves.
  Future<void> removeFromTeam(String id) async {
    await _client!.rpc('team_remove', params: {'p_id': id}).timeout(_requestTimeout);
    await refreshTeams();
  }

  /// Tells the server this event's edit form is open and returns the names of
  /// other people who have it open too. [done]: the form was closed.
  Future<List<String>> eventEditing(String eventId, {bool done = false}) async {
    final c = _client;
    if (c == null) return const [];
    final names = await c.rpc('event_editing', params: {'p_event': eventId, 'p_done': done}).timeout(_requestTimeout);
    return [for (final n in (names as List?) ?? const []) '$n'];
  }

  /// An event of the same organizer with the same title on the same day, if
  /// there is one (to warn before publishing it twice). Null if none, or if
  /// the list cannot be loaded.
  Future<Event?> findSimilarEvent(String title, DateTime start, {String? organizerId}) async {
    if (!usesBackend) return null;
    String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    try {
      final list = organizerId == null ? await loadManagedEvents() : await loadEventsOf(organizerId);
      for (final e in list) {
        if (!e.isCancelled &&
            norm(e.title) == norm(title) &&
            e.date.year == start.year &&
            e.date.month == start.month &&
            e.date.day == start.day) {
          return e;
        }
      }
    } catch (_) {}
    return null;
  }

  /// All events of an organizer whose team this account is in.
  Future<List<Event>> loadEventsOf(String organizerId) =>
      _registrationRepository!.fetchManagedEvents(organizerId: organizerId).timeout(_requestTimeout);

  // ---- live updates ---------------------------------------------------------
  // The app asks the server every 20 seconds (and when it comes back to the
  // front), so changes made elsewhere show up without reloading.

  static const _liveEvery = Duration(seconds: 20);
  Timer? _liveTimer;
  int _liveTick = 0;
  bool _liveBusy = false;

  void startLiveUpdates() => _liveTimer ??= Timer.periodic(_liveEvery, (_) => refreshLive());

  void stopLiveUpdates() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  /// [everything]: also the event feed and the organizer numbers (otherwise
  /// those are fetched on every third round only).
  Future<void> refreshLive({bool everything = false}) async {
    if (_client == null || _session == null || _remoteProfile == null || _liveBusy) return;
    _liveBusy = true;
    _liveTick++;
    final slow = everything || _liveTick % 3 == 0;
    try {
      await Future.wait([
        refreshRegistrations(),
        refreshNotifications(),
        _pollProfile(),
        if (isAdmin) _pollAdminLists(),
        if (slow) _refreshEventsQuietly(),
        if (slow && _dbRole != 'student') refreshDashboard(),
        if (slow) refreshTeams(),
        if (_dbRole == 'student') refreshMyRequest(),
      ]);
    } catch (_) {
      // The next round tries again.
    } finally {
      _liveBusy = false;
    }
  }

  /// Role, university or suspension changed on the server: reload the profile.
  Future<void> _pollProfile() async {
    final c = _client;
    final uid = currentUserId;
    if (c == null || uid == null) return;
    try {
      final row = await c
          .from('profiles')
          .select('role, tenant_id, organizer_verified, suspended_at, email_checked_at, email_check_exempt, email_check_lapsed_at')
          .eq('id', uid)
          .single()
          .timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      final checked = row['email_checked_at'] as String?;
      final changed = row['role'] != _dbRole ||
          row['tenant_id'] != _tenantId ||
          (row['organizer_verified'] as bool? ?? false) != _organizerVerified ||
          (row['suspended_at'] != null) != _suspended ||
          (row['email_check_exempt'] as bool? ?? false) != _emailCheckExempt ||
          (row['email_check_lapsed_at'] != null) != _emailCheckLapsed ||
          (checked == null ? null : DateTime.parse(checked).toLocal()) != _emailCheckedAt;
      if (changed) await loadProfile();
    } catch (_) {
      // Not critical; the next round asks again.
    }
  }

  /// Requests and reports for admins, without the loading spinner.
  Future<void> _pollAdminLists() async {
    final account = _accountRepository;
    final uid = currentUserId;
    if (account == null) return;
    try {
      final requests = await account.fetchRequests().timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _requests = requests;
      notifyListeners();
    } catch (_) {}
    await refreshReports();
  }

  /// The event feed without the loading skeleton.
  Future<void> _refreshEventsQuietly() async {
    if (_eventsLoading) return;
    final account = _session?.user.id;
    try {
      final events = await _eventRepository.fetchUpcoming().timeout(_requestTimeout);
      if (account == _session?.user.id && !_eventsLoading) {
        _events = events;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// "You are checked in": set when a refresh shows a ticket that was just scanned.
  String? _checkInNotice;
  String? takeCheckInNotice() {
    final n = _checkInNotice;
    _checkInNotice = null;
    return n;
  }

  /// A one-time message for right after signing in (shown by the main screen).
  String? _loginNotice;
  String? takeLoginNotice() {
    final n = _loginNotice;
    _loginNotice = null;
    return n;
  }

  Future<void> signOut() async {
    final repo = _notificationRepository;
    if (repo != null) await _push?.stop(repo.unregisterDevice);
    _pushStartedFor = null;
    await _client?.auth.signOut();
  }

  // ---- account & profile ---------------------------------------------------

  /// Raw role from the database: student, organizer, commercial_planner, tenant_admin, platform_admin.
  String get dbRole => _dbRole;
  bool get isAdmin => _dbRole == 'tenant_admin' || _dbRole == 'platform_admin';
  bool get isPlatformAdmin => _dbRole == 'platform_admin';

  /// Organizers/admins can also look at the app as a student.
  bool get canSwitchView => usesBackend && _dbRole != 'student';

  Future<void> updateDisplayName(String name) async {
    await _accountRepository!.updateDisplayName(name);
    await loadProfile();
  }

  /// Throws WrongPasswordException if [currentPassword] is wrong.
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _accountRepository!.changePassword(currentPassword, newPassword);

  // Profile photo: organizers (once approved) and admins only; the database enforces it too.
  String? _avatarPath;
  bool _organizerVerified = false;

  /// An admin paused this account while looking into reports. The server
  /// refuses sign-ups, reviews, reports and publishing until it is lifted.
  bool _suspended = false;
  bool get isSuspended => _suspended;

  /// Only accounts that belong to a university can register for events
  /// (the server enforces it; this is for explaining it on the button).
  bool get needsUniversityToRegister => usesBackend && !isGuest && _tenantId == null;

  /// Organizers get a different suspension text than plain users.
  bool get isOrganizerAccount => _dbRole == 'organizer' || _dbRole == 'commercial_planner';

  // Yearly check that the university address still works (the server decides;
  // this only tells the app when to ask).
  static const emailCheckEvery = Duration(days: 365);
  DateTime? _emailCheckedAt;
  bool _emailCheckExempt = false;
  bool _emailCheckLapsed = false;

  String get accountEmail => _client?.auth.currentUser?.email ?? '';

  /// The year is over and the person should confirm their address now.
  bool get emailCheckDue =>
      _tenantId != null &&
      !_emailCheckExempt &&
      _dbRole != 'platform_admin' &&
      _emailCheckedAt != null &&
      DateTime.now().isAfter(_emailCheckedAt!.add(emailCheckEvery));

  /// The check was missed, so the account no longer belongs to its university.
  bool get emailCheckLapsed => _emailCheckLapsed && _tenantId == null;

  /// Sends a code to the account's own address.
  Future<void> sendEmailCheckCode() =>
      _client!.auth.signInWithOtp(email: accountEmail, shouldCreateUser: false).timeout(_requestTimeout);

  /// Signs in again with the e-mailed code (the proof), then tells the server.
  Future<void> confirmEmailCheck(String code) async {
    await _client!.auth.verifyOTP(email: accountEmail, token: code.trim(), type: OtpType.email).timeout(_requestTimeout);
    await _client!.rpc('confirm_university_email').timeout(_requestTimeout);
    await loadProfile();
    refreshEvents();
  }

  bool get canHaveAvatar =>
      usesBackend &&
      (isAdmin || ((_dbRole == 'organizer' || _dbRole == 'commercial_planner') && _organizerVerified));

  String? get avatarUrl {
    final path = _avatarPath;
    final repo = _accountRepository;
    if (path == null || repo == null || !canHaveAvatar) return null;
    return repo.avatarUrl(path);
  }

  Future<void> uploadAvatar(Uint8List bytes, String contentType, String extension) async {
    _avatarPath = await _accountRepository!.uploadAvatar(bytes, contentType, extension, _avatarPath);
    _organizers.remove(currentUserId); // event pages show the new photo
    _hosts.remove(currentUserId);
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    final path = _avatarPath;
    if (path == null) return;
    await _accountRepository!.removeAvatar(path);
    _avatarPath = null;
    _organizers.remove(currentUserId);
    _hosts.remove(currentUserId);
    notifyListeners();
  }

  // Organizer name, organization and photo shown in the feed and on event pages
  // (cached per organizer; loaded for the whole feed in one request).
  final Map<String, Future<EventHost?>> _organizers = {};
  final Map<String, EventHost> _hosts = {};

  /// The organizer of an event if already loaded (null while loading or unknown).
  EventHost? hostOf(String? organizerId) => organizerId == null ? null : _hosts[organizerId];

  // Taken seats per event, for "12 seats left" labels on the feed.
  final Map<String, int> _seatsTaken = {};

  /// Free seats of [event], or null when it is unlimited or not known yet.
  int? seatsLeft(Event event) {
    final capacity = event.capacity;
    final taken = _seatsTaken[event.id];
    if (capacity == null || taken == null) return null;
    return (capacity - taken).clamp(0, capacity);
  }

  Future<void> _loadSeatCounts(List<Event> events) async {
    final c = _client;
    if (c == null) return;
    final ids = [for (final e in events) if (e.capacity != null) e.id];
    if (ids.isEmpty) return;
    try {
      final rows = await c.rpc('event_seat_counts', params: {'p_event_ids': ids}).timeout(_requestTimeout);
      for (final row in rows as List) {
        _seatsTaken[row['event_id'] as String] = row['registered'] as int;
      }
      notifyListeners();
    } catch (_) {
      // Labels are optional extras; the feed works without them.
    }
  }

  EventHost _hostFromRow(SupabaseClient c, Map<String, dynamic> row) {
    final path = row['avatar_path'] as String?;
    return EventHost(
      name: (row['display_name'] as String?) ?? '',
      organization: row['organization_name'] as String?,
      photoUrl: path == null ? null : c.storage.from('avatars').getPublicUrl(path),
    );
  }

  Future<EventHost?> organizerFor(String organizerId) {
    final c = _client;
    if (c == null) return Future.value(null);
    final known = _hosts[organizerId];
    if (known != null) return Future.value(known);
    return _organizers[organizerId] ??= () async {
      try {
        final row = await c
            .from('organizer_profiles')
            .select('id, display_name, avatar_path, organization_name')
            .eq('id', organizerId)
            .maybeSingle()
            .timeout(_requestTimeout);
        if (row == null) return null;
        return _hosts[organizerId] = _hostFromRow(c, row);
      } catch (_) {
        _organizers.remove(organizerId); // try again next time
        return null;
      }
    }();
  }

  /// Loads the organizers of [events] that are not cached yet, in one request.
  Future<void> _loadHosts(List<Event> events) async {
    final c = _client;
    if (c == null) return;
    final missing = {
      for (final e in events)
        if (e.organizerId != null && !_hosts.containsKey(e.organizerId)) e.organizerId!,
    }.toList();
    if (missing.isEmpty) return;
    try {
      final rows = await c
          .from('organizer_profiles')
          .select('id, display_name, avatar_path, organization_name')
          .inFilter('id', missing)
          .timeout(_requestTimeout);
      for (final row in rows) {
        _hosts[row['id'] as String] = _hostFromRow(c, row);
      }
      notifyListeners();
    } catch (_) {
      // Names are optional extras; the feed works without them.
    }
  }

  /// A JSON copy of everything stored about the signed-in user.
  Future<String> exportMyData() => _accountRepository!.exportMyData();

  /// Deletes the account and all its data, then signs out.
  Future<void> deleteAccount() async {
    await _accountRepository!.deleteMyAccount();
    try {
      await signOut();
    } catch (_) {
      // The login is already gone on the server; the local session is cleared by the next event.
    }
  }

  void _persistLocale() {
    final repo = _accountRepository;
    if (repo == null || _session == null) return;
    repo.saveLocale(_currentLocale.languageCode).catchError((_) {});
  }

  // ---- organizer requests --------------------------------------------------

  OrganizerRequest? get myRequest => _myRequest;

  Future<void> refreshMyRequest() async {
    final repo = _accountRepository;
    if (repo == null) return;
    final uid = currentUserId;
    try {
      final request = await repo.fetchMyLatestRequest().timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _myRequest = request;
      notifyListeners();
    } catch (_) {
      // Shown again on the next refresh.
    }
  }

  Future<void> requestOrganizerAccess(OrganizerApplication application) async {
    await _accountRepository!.requestOrganizerAccess(application);
    await refreshMyRequest();
  }

  /// Short-lived link to an applicant's document (admins only; checked by the database).
  Future<String> organizerDocumentUrl(String path) => _accountRepository!.documentUrl(path);

  // ---- admin ---------------------------------------------------------------

  List<OrganizerRequest> get organizerRequests => List.unmodifiable(_requests);
  List<AdminUser> get adminUsers => List.unmodifiable(_adminUsers);
  int get pendingRequestCount => _requests.where((r) => r.isPending).length;
  bool get adminLoading => _adminLoading;
  bool get adminError => _adminError;

  Future<void> refreshRequests() async {
    final repo = _accountRepository;
    if (repo == null || !isAdmin) return;
    _adminLoading = true;
    _adminError = false;
    notifyListeners();
    final uid = currentUserId;
    try {
      final requests = await repo.fetchRequests().timeout(_requestTimeout);
      if (_stillSignedInAs(uid)) _requests = requests;
    } catch (_) {
      _adminError = true;
    } finally {
      _adminLoading = false;
      notifyListeners();
    }
  }

  /// Network calls give up after this long so a dropped connection never leaves a spinner forever.
  static const _requestTimeout = Duration(seconds: 20);

  Future<void> reviewRequest(String id, bool approve, String? note, {bool exempt = false}) async {
    final repo = _accountRepository!;
    await repo.reviewRequest(id, approve, note, exempt: exempt);
    // The documents were only needed for the decision, so they are deleted now.
    final docs = [for (final r in _requests) if (r.id == id) ...r.documents];
    try {
      await repo.removeDocuments(docs);
    } catch (_) {
      // Not critical: the applicant's next request or account deletion clears them.
    }
    await refreshRequests();
    refreshUsers('');
  }

  Future<void> refreshUsers(String search) async {
    final repo = _accountRepository;
    if (repo == null || !isAdmin) return;
    final uid = currentUserId;
    try {
      final users = await repo.listUsers(search).timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _adminUsers = users;
      notifyListeners();
    } catch (_) {
      _adminError = true;
      notifyListeners();
    }
  }

  Future<void> setUserRole(String userId, String role, bool verified, String search) async {
    await _accountRepository!.setRole(userId, role, verified);
    await refreshUsers(search);
  }

  /// Admin: switches the yearly e-mail check off or on for an organizer.
  Future<void> setUserEmailCheckExempt(String userId, bool exempt, String search) async {
    await _accountRepository!.setEmailCheckExempt(userId, exempt);
    await refreshUsers(search);
  }

  /// Admin: pauses an account (reason required) or lifts the pause. Nothing is deleted.
  Future<void> setUserSuspended(String userId, bool suspend, String? note, String search) async {
    await _accountRepository!.setSuspended(userId, suspend, note);
    await refreshUsers(search);
    await refreshReports();
    refreshEvents();
  }

  /// Admin: deletes a user's account and events, optionally blocking the address.
  Future<void> removeUser(String userId, {required bool block, required String search}) async {
    await _accountRepository!.deleteUser(userId, block: block);
    _adminUsers = [for (final u in _adminUsers) if (u.id != userId) u];
    notifyListeners();
    await refreshUsers(search);
    refreshEvents();
  }

  Future<List<BlockedEmail>> loadBlockedEmails() => _accountRepository!.listBlockedEmails();

  /// Removed events and users with the reports about them, newest first.
  Future<List<ModerationCase>> loadCaseFiles() => _communityRepository!.fetchCases().timeout(_requestTimeout);

  Future<void> unblockEmail(String email) => _accountRepository!.unblockEmail(email);

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
    if (_eventsLoading) {
      _eventsReloadPending = true; // e.g. signed out while a reload was running
      return;
    }
    _eventsLoading = true;
    _eventsError = false;
    notifyListeners();
    final account = _session?.user.id;
    try {
      final events = await _eventRepository.fetchUpcoming().timeout(_requestTimeout);
      // Never show one account's feed (with its university events) to the next one.
      if (account == _session?.user.id) _events = events;
    } catch (_) {
      _eventsError = true;
    } finally {
      _eventsLoading = false;
      notifyListeners();
    }
    if (_eventsReloadPending || account != _session?.user.id) {
      _eventsReloadPending = false;
      return refreshEvents();
    }
    refreshRatings();
    _loadHosts(_events);
    _loadSeatCounts(_events);
  }

  bool _eventsReloadPending = false;
  String get selectedCategory => _selectedCategory;
  List<String> get registeredEventIds => usesBackend
      ? _registrations.map((r) => r.event.id).toList()
      : _registeredEventIds;

  /// Events the user is registered or waitlisted for (includes events that already
  /// ended, which the public feed no longer lists).
  List<Event> get registeredEvents => usesBackend
      ? _registrations.map((r) => r.event).toList()
      : events.where((e) => _registeredEventIds.contains(e.id)).toList();

  Registration? registrationFor(String eventId) {
    for (final r in _registrations) {
      if (r.event.id == eventId) return r;
    }
    return null;
  }

  bool isWaitlisted(String eventId) =>
      registrationFor(eventId)?.status == RegistrationStatus.waitlisted;

  /// Whether there is a usable QR ticket to show (demo mode always has one).
  bool hasValidTicketFor(String eventId) => !usesBackend || (registrationFor(eventId)?.hasValidTicket ?? false);

  /// Seats the user was asked to confirm and has not answered for yet.
  List<Registration> get pendingConfirmations =>
      _registrations.where((r) => r.needsConfirmation).toList();

  /// "Yes, I'm still coming." Throws PostgrestException on refusal.
  Future<void> confirmAttendance(String eventId) async {
    final repo = _registrationRepository;
    if (repo == null) return;
    await repo.confirm(eventId);
    await refreshRegistrations();
  }

  Future<void> refreshRegistrations() async {
    final repo = _registrationRepository;
    if (repo == null) return;
    final uid = currentUserId;
    try {
      final registrations = await repo.fetchMine().timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      // Scanned at the door since the last look: tell the person.
      final notScanned = {for (final r in _registrations) if (!r.isCheckedIn) r.id};
      for (final r in registrations) {
        if (r.isCheckedIn && notScanned.contains(r.id)) _checkInNotice = r.event.title;
      }
      _registrations = registrations;
      notifyListeners();
    } catch (_) {
      // Keep showing the last known list; pull-to-refresh retries.
    }
  }

  /// Events the signed-in planner organizes (for choosing what to scan).
  Future<List<Event>> loadManagedEvents() async {
    final repo = _registrationRepository;
    if (repo == null) return events;
    return repo.fetchManagedEvents();
  }

  /// Validates a scanned QR value for [eventId] on the server.
  Future<CheckInResult> checkInTicket(String code, String eventId) async {
    final repo = _registrationRepository!;
    final result = await repo.checkIn(code, eventId);
    refreshDashboard(); // door numbers and scan log changed
    return result;
  }

  /// What the ticket QR code encodes.
  String qrPayload(String eventId) {
    if (usesBackend) return 'unihub:1:${registrationFor(eventId)?.ticketCode ?? ''}';
    final ticketId = _ticketIds[eventId] ?? '';
    return '{"ticketId": "$ticketId", "eventId": "$eventId", "userId": "student-1", "userName": "${activeProfile.name}"}';
  }

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
    'HAW': {
      'en': 'Hamburg University of Applied Sciences',
      'de': 'Hochschule für Angewandte Wissenschaften Hamburg',
      'domain': 'haw-hamburg.de',
    },
  };

  void toggleRole() {
    _currentRole = _currentRole == UserRole.student ? UserRole.planner : UserRole.student;
    notifyListeners();
  }

  void setRole(UserRole role) {
    if (usesBackend && role == UserRole.planner && _dbRole == 'student') return;
    if (_currentRole != role) {
      _currentRole = role;
      notifyListeners();
    }
  }

  void setLocale(Locale locale) {
    if (_currentLocale != locale) {
      _currentLocale = locale;
      notifyListeners();
      _persistLocale();
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
    final names = tenantDetails[_currentTenant];
    return names?[language] ?? names?['en'] ?? _currentTenant;
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
  /// [team]: set when a teammate publishes the event for that organizer.
  Future<void> addEvent(Event event, {TeamMembership? team}) async {
    final tenantId = team != null
        ? (team.isCampus ? team.organizerTenant : null)
        : (event.isUniversityOfficial ? _tenantId : null);
    if (team == null && event.isUniversityOfficial && usesBackend && tenantId == null) {
      throw const AuthException('No university linked to this account');
    }
    final created = await _eventRepository.create(event, tenantId: tenantId, organizerId: team?.organizerId);
    _events = [..._events, created]..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    refreshDashboard();
  }

  void setPlannerType(PlannerType type) {
    if (_currentPlannerType != type) {
      _currentPlannerType = type;
      notifyListeners();
    }
  }

  bool isRegistered(String eventId) {
    if (usesBackend) return registrationFor(eventId)?.isActive ?? false;
    return _registeredEventIds.contains(eventId);
  }

  /// Registers for an event. With a backend the server enforces capacity and may
  /// place the user on the waitlist. Throws PostgrestException on refusal.
  Future<RegistrationStatus> registerForEvent(String eventId) async {
    final repo = _registrationRepository;
    if (repo != null) {
      final status = await repo.register(eventId);
      await refreshRegistrations();
      _loadSeatCounts(_events);
      return status;
    }
    _registerLocally(eventId);
    return RegistrationStatus.registered;
  }

  Future<void> cancelRegistration(String eventId) async {
    final repo = _registrationRepository;
    if (repo != null) {
      await repo.cancel(eventId);
      await refreshRegistrations();
      _loadSeatCounts(_events);
      return;
    }
    _registeredEventIds.remove(eventId);
    _ticketIds.remove(eventId);
    notifyListeners();
  }

  void _registerLocally(String eventId) {
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
    if (usesBackend) return registrationFor(eventId)?.displayTicketId ?? '';
    return _ticketIds[eventId] ?? '';
  }

  bool isTicketScanned(String ticketId) {
    if (usesBackend) {
      return _registrations.any((r) => r.displayTicketId == ticketId && r.isCheckedIn);
    }
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
    if (key.contains('haw')) {
      return const Color(0xFF0072BC); // HAW Hamburg Blue (checked before 'hamburg')
    } else if (key.contains('tum')) {
      return const Color(0xFF0065BD); // TUM Tech Blue
    } else if (key.contains('lmu')) {
      return const Color(0xFF0F9D58); // LMU Emerald Green
    } else if (key.contains('hamburg') || key.contains('uhh') || key.contains('uni-hamburg.de')) {
      return const Color(0xFFE2001A); // Hamburg Crimson Red
    }
    return const Color(0xFF1F2A6B); // no university: the app's own navy
  }

  Color getActiveTenantColor() {
    return getUniversityColor(_currentTenant);
  }

  List<Review> get reviews => _reviews;

  // ---- ratings & reviews ---------------------------------------------------

  /// Verified average rating for an event, or null if nobody has rated it yet.
  EventRating? ratingFor(String eventId) {
    if (usesBackend) return _ratings[eventId];
    final verified = _reviews.where((r) => r.eventId == eventId && r.isVerified).toList();
    if (verified.isEmpty) return null;
    final avg = verified.map((r) => r.rating).reduce((a, b) => a + b) / verified.length;
    return EventRating(avg, verified.length);
  }

  bool hasReviewed(String eventId) =>
      usesBackend ? _myReviewedEventIds.contains(eventId) : _locallyReviewed.contains(eventId);

  Future<void> refreshRatings() async {
    final repo = _insightsRepository;
    if (repo == null) return;
    try {
      _ratings = await repo.fetchRatings();
      notifyListeners();
    } catch (_) {
      // Ratings are optional decoration; keep the last known values.
    }
  }

  Future<void> refreshMyReviews() async {
    final repo = _insightsRepository;
    if (repo == null) return;
    final uid = currentUserId;
    try {
      final ids = await repo.fetchMyReviewedEventIds().timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      _myReviewedEventIds = ids;
      notifyListeners();
    } catch (_) {
      // Retried on the next refresh.
    }
  }

  /// Sends a review. With a backend the server decides whether it is verified
  /// and refuses early, duplicate or unticketed reviews (throws PostgrestException).
  Future<void> submitReview(Event event, int rating, String comment, bool claimedAttendance) async {
    final repo = _insightsRepository;
    if (repo != null) {
      await repo.submitReview(
        eventId: event.id,
        rating: rating,
        comment: comment,
        claimedAttendance: claimedAttendance,
      );
      _myReviewedEventIds = {..._myReviewedEventIds, event.id};
      notifyListeners();
      refreshRatings();
      return;
    }
    const verified = true; // every accepted review counts (see submit_review on the server)
    _reviews.add(Review(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      eventId: event.id,
      rating: rating.toDouble(),
      comment: comment,
      timestamp: DateTime.now(),
      isVerified: verified,
      claimedAttendance: event.requiresQrCode || claimedAttendance,
    ));
    _locallyReviewed.add(event.id);
    notifyListeners();
  }

  // ---- planner dashboard ---------------------------------------------------

  DashboardData get dashboard => _dashboard;

  /// Events the signed-in organizer owns (any status), for editing and cancelling.
  List<Event> get managedEvents => usesBackend ? List.unmodifiable(_managedEvents) : events;

  Event? managedEventById(String id) {
    for (final e in managedEvents) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// [folder]: the organizer's id when a teammate uploads a poster for them.
  Future<String> uploadEventImage(Uint8List bytes, String contentType, String extension, {String? folder}) =>
      _eventRepository.uploadImage(bytes, contentType, extension, folder: folder);

  /// Deletes a poster that is no longer used (after it was replaced). Best effort:
  /// a leftover file is invisible and removed with the organizer's account.
  /// Deletes one of the organizer's own draft or cancelled events for good.
  /// Returns false if the server did not allow it.
  Future<bool> deleteEvent(String id) async {
    final image = managedEventById(id)?.imagePath;
    // The server only deletes what the rules allow; nothing deleted means refused.
    final rows = await _client!.from('events').delete().eq('id', id).select('id').timeout(_requestTimeout);
    if (rows.isEmpty) return false;
    if (image != null) deleteEventImage(image);
    _managedEvents = [for (final e in _managedEvents) if (e.id != id) e];
    notifyListeners();
    await refreshDashboard();
    refreshEvents();
    return true;
  }

  Future<void> deleteEventImage(String path) async {
    try {
      await _client?.storage.from('event-images').remove([path]);
    } catch (_) {}
  }

  /// Saves edits. Throws PostgrestException if not allowed.
  Future<void> updateEvent(Event event) async {
    final saved = await _eventRepository.update(event);
    _events = [for (final e in _events) e.id == saved.id ? saved : e]
      ..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    refreshDashboard();
  }

  /// Publishes a cancelled (or draft) event again with the edited details.
  /// The server ends the old sign-ups when a cancelled event is reopened.
  /// If a step fails the event stays a draft and this can simply be repeated.
  Future<void> republishEvent(Event event) async {
    final c = _client!;
    if (event.isCancelled) {
      final rows = await c.from('events').update({'status': 'draft'}).eq('id', event.id).select('id').timeout(_requestTimeout);
      if (rows.isEmpty) throw const PostgrestException(message: 'not_allowed', code: '42501');
    }
    // The step above already changed the event, so its stamp is no longer the one that was opened.
    await _eventRepository.update(event, checkUnchanged: !event.isCancelled);
    final rows =
        await c.from('events').update({'status': 'published'}).eq('id', event.id).select('id').timeout(_requestTimeout);
    if (rows.isEmpty) throw const PostgrestException(message: 'not_allowed', code: '42501');
    await Future.wait([refreshEvents(), refreshDashboard()]);
  }

  /// One page of the reviews of an event the organizer manages, newest first.
  Future<List<Review>> loadEventReviews(String eventId, {int offset = 0, int pageSize = 20}) async {
    final rows = await _client!
        .from('reviews')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1)
        .timeout(_requestTimeout);
    return [for (final r in rows) Review.fromRow(r)];
  }

  /// Cancels an event. Ticket holders keep seeing it as cancelled. The organizer
  /// can later publish it again or delete it.
  Future<void> cancelEvent(String eventId) async {
    await _eventRepository.cancel(eventId);
    _events = _events.where((e) => e.id != eventId).toList();
    notifyListeners();
    refreshDashboard();
  }
  /// Statistics page of one managed event. Throws on network or permission errors.
  Future<EventInsights> loadEventInsights(String eventId) async {
    final repo = _insightsRepository;
    if (repo == null) return const EventInsights();
    return repo.fetchEventInsights(eventId).timeout(_requestTimeout);
  }

  List<({Review review, String eventTitle})> get feedback => _feedback;
  bool get dashboardLoading => _dashboardLoading;
  bool get dashboardError => _dashboardError;

  Future<void> refreshDashboard() async {
    final repo = _insightsRepository;
    if (repo == null || _dashboardLoading) return;
    _dashboardLoading = true;
    _dashboardError = false;
    notifyListeners();
    final uid = currentUserId;
    try {
      final results = await Future.wait([
        repo.fetchStats(),
        repo.fetchRecentScans(),
        repo.fetchFeedback(),
        _registrationRepository?.fetchManagedEvents() ?? Future.value(<Event>[]),
      ]).timeout(_requestTimeout);
      if (!_stillSignedInAs(uid)) return;
      final stats = results[0] as List<EventStat>;
      final managedIds = stats.map((s) => s.eventId).toSet();
      _dashboard = DashboardData(stats: stats, scans: results[1] as List<ScanEntry>);
      _managedEvents = results[3] as List<Event>;
      // Reviews of events the planner does not manage are not feedback for them.
      _feedback = (results[2] as List<({Review review, String eventTitle})>)
          .where((f) => managedIds.contains(f.review.eventId))
          .toList();
    } catch (_) {
      _dashboardError = true;
    } finally {
      _dashboardLoading = false;
      notifyListeners();
    }
  }

  /// Admins only: removes one review (for example an abusive one).
  Future<void> deleteReview(String reviewId) async {
    await _insightsRepository!.deleteReview(reviewId).timeout(_requestTimeout);
    _feedback = _feedback.where((f) => f.review.id != reviewId).toList();
    notifyListeners();
    refreshDashboard(); // star averages and counts changed
  }

  List<Review> getReviewsForEvent(String eventId) {
    return _reviews.where((r) => r.eventId == eventId).toList();
  }

  void addReview(Review review) {
    _reviews.add(review);
    notifyListeners();
  }

  bool hasAttended(String eventId) {
    if (usesBackend) return registrationFor(eventId)?.isCheckedIn ?? false;
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
      _saveLookPreference('theme', mode.name);
    }
  }

  // The theme is per device (stored locally), not part of the account.
  Future<void> _loadLookPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('look.theme');
      var changed = false;
      for (final m in ThemeMode.values) {
        if (m.name == theme && m != _themeMode) {
          _themeMode = m;
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {
      // No local storage available (tests): keep the defaults.
    }
  }

  Future<void> _saveLookPreference(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('look.$key', value);
    } catch (_) {
      // Not saved; the choice still applies until the app closes.
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
