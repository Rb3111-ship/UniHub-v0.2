import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/core/auth/user_role.dart';
import 'package:uni_events_app/core/widgets/wallpaper.dart';
import 'package:uni_events_app/features/student/details_screen.dart';
import 'package:uni_events_app/main.dart';

/// Runs the real app against a tiny fake Supabase server on this machine,
/// signed in as an admin, to catch screens that hang or stop updating.
const _uid = '11111111-1111-1111-1111-111111111111';

String _b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

String _sessionJson() {
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  final jwt = '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${_b64({'sub': _uid, 'role': 'authenticated', 'exp': exp, 'email': 'admin@haw-hamburg.de'})}.sig';
  return jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': 'refresh',
    'user': {
      'id': _uid,
      'aud': 'authenticated',
      'email': 'admin@haw-hamburg.de',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

final _publicEvent = {
  'id': '22222222-2222-2222-2222-222222222222',
  'title': 'Open Air Concert',
  'description': 'Music in the park',
  'starts_at': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
  'ends_at': DateTime.now().add(const Duration(days: 3, hours: 2)).toUtc().toIso8601String(),
  'location': 'City Park',
  'tenant_id': null,
  'requires_qr': true,
  'allow_reviews': true,
  'categories': ['Music', 'Yoga'],
  'capacity': 100,
  'price_cents': 0,
  'status': 'published',
  'image_path': null,
  'organizer_id': _uid,
  'tenants': null,
  'contact_email': 'club@example.org',
  'contact_phone': null,
  'website_url': 'https://club.example.org',
};

class _FakeBackend {
  late HttpServer server;
  final requests = <String>[];
  final bodies = <String, String>{}; // last request body per path
  String role = 'platform_admin';
  bool askConfirm = false; // the student has a seat they were asked to confirm
  bool pastTicket = false; // the student also has a ticket for an event that is over

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      requests.add('${req.method} $path');
      bodies[path] = await utf8.decoder.bind(req).join();
      final res = req.response..headers.contentType = ContentType.json;
      Object body = [];
      if (path.endsWith('/profiles') && req.method == 'GET') {
        final row = {
          'display_name': 'Test Admin',
          'role': role,
          'tenant_id': 't-haw',
          'locale': 'en',
          'avatar_path': null,
          'organizer_verified': true,
          'tenants': {'slug': 'haw'},
        };
        final single = (req.headers.value('accept') ?? '').contains('vnd.pgrst.object');
        body = single ? row : [row];
      } else if (path.endsWith('/events') && req.method == 'GET') {
        body = [_publicEvent];
      } else if (path.endsWith('/notifications') && req.method == 'GET') {
        body = [
          {
            'id': 2,
            'kind': 'reminder',
            'event_id': '22222222-2222-2222-2222-222222222222',
            'event_title': 'Open Air Concert',
            'created_at': '2026-10-29T08:00:00Z',
            'read_at': null,
            'events': {'starts_at': _publicEvent['starts_at']},
          },
          {
            'id': 1,
            'kind': 'request_approved',
            'event_id': null,
            'event_title': null,
            'created_at': '2026-10-28T08:00:00Z',
            'read_at': '2026-10-28T09:00:00Z',
            'events': null,
          },
        ];
      } else if (path.endsWith('/registrations') && req.method == 'GET' && (askConfirm || pastTicket)) {
        body = [
          if (askConfirm)
            {
              'id': '66666666-6666-6666-6666-666666666666',
              'status': 'registered',
              'confirm_asked_at': DateTime.now().toUtc().toIso8601String(),
              'confirmed_at': null,
              'events': _publicEvent,
              'tickets': {'code': 'abc', 'ticket_number': 7, 'checked_in_at': null, 'voided_at': null},
            },
          if (pastTicket)
            {
              'id': '77777777-7777-7777-7777-777777777777',
              'status': 'registered',
              'confirm_asked_at': null,
              'confirmed_at': null,
              'events': {
                ..._publicEvent,
                'id': '88888888-8888-8888-8888-888888888888',
                'title': 'Last Week Lecture',
                'requires_qr': false,
                'starts_at': DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String(),
                'ends_at': DateTime.now().subtract(const Duration(days: 7, hours: -2)).toUtc().toIso8601String(),
              },
              'tickets': {'code': 'def', 'ticket_number': 8, 'checked_in_at': null, 'voided_at': null},
            },
        ];
      } else if (path.endsWith('/rpc/confirm_attendance')) {
        body = DateTime.now().toUtc().toIso8601String();
      } else if (path.endsWith('/event_stats') && req.method == 'GET') {
        body = [
          {
            'event_id': '22222222-2222-2222-2222-222222222222',
            'title': 'Open Air Concert',
            'capacity': 100,
            'registered': 40,
            'waitlisted': 3,
            'checked_in': 31,
            'starts_at': '2026-10-01T18:00:00Z',
            'ends_at': '2026-10-01T20:00:00Z',
            'status': 'published',
            'avg_rating': 4.5,
            'review_count': 2,
            'confirmed': 35,
            'cancelled': 4,
            'released': 1,
            'requires_qr': true,
            'release_unconfirmed': true,
          },
        ];
      } else if (path.endsWith('/rpc/event_insights')) {
        body = {
          'signups': [
            {'day': '2026-09-20', 'count': 25},
            {'day': '2026-09-23', 'count': 15},
          ],
          'stars': [0, 0, 0, 1, 1],
          'stars_verified': 2,
          'asked': 38,
          'declined': 3,
        };
      } else if (path.endsWith('/rpc/admin_list_users')) {
        body = [
          {
            'id': '99999999-9999-9999-9999-999999999999',
            'display_name': 'Troll Account',
            'email': 'troll@example.com',
            'role': 'organizer',
            'tenant_id': null,
            'organizer_verified': true,
            'created_at': '2026-11-01T10:00:00Z',
            'email_confirmed': true,
            'event_count': 2,
          },
        ];
      } else if (path.endsWith('/functions/v1/remove-user')) {
        body = {'events': 2, 'files': 3, 'files_ok': true};
      } else if (path.endsWith('/rpc/admin_list_blocked_emails')) {
        body = [
          {'email': 'spammer@example.com', 'created_at': '2026-11-05T10:00:00Z', 'blocked_by_name': 'Test Admin'},
        ];
      } else if (path.endsWith('/rpc/admin_unblock_email')) {
        body = true;
      } else if (path.endsWith('/event_reports') && req.method == 'GET') {
        body = [
          {
            'id': '44444444-4444-4444-4444-444444444444',
            'event_id': '22222222-2222-2222-2222-222222222222',
            'reporter_id': '55555555-5555-5555-5555-555555555555',
            'reason': 'spam',
            'details': 'Only advertising',
            'status': 'open',
            'created_at': '2026-10-27T10:00:00Z',
            'events': {'title': 'Open Air Concert', 'starts_at': '2026-11-01T18:00:00Z', 'status': 'published'},
          },
        ];
      } else if (path.endsWith('/organizer_profiles')) {
        final host = {
          'id': _uid,
          'display_name': 'Test Admin',
          'avatar_path': null,
          'organization_name': 'Campus Club',
        };
        final single = (req.headers.value('accept') ?? '').contains('vnd.pgrst.object');
        body = single ? host : [host];
      } else if (path.endsWith('/auth/v1/signup')) {
        // "Confirm email" is on: a user but no session, so the app asks for the code.
        body = {
          'id': '33333333-3333-3333-3333-333333333333',
          'aud': 'authenticated',
          'email': 'new@example.org',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        };
      } else if (path.startsWith('/auth/v1/logout')) {
        res.statusCode = 204;
        await res.close();
        return;
      }
      res.write(jsonEncode(body));
      await res.close();
    });
  }

  String get url => 'http://127.0.0.1:${server.port}';
}

/// Unmounts the app and lets pending network timeouts expire inside the fake clock.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

Future<void> _settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late _FakeBackend backend;
  late SupabaseClient client;

  setUp(() async {
    HttpOverrides.global = null; // the test binding blocks real sockets by default
    backend = _FakeBackend();
    await backend.start();
    client = SupabaseClient(
      backend.url,
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false, authFlowType: AuthFlowType.implicit),
    );
  });

  tearDown(() async {
    await backend.server.close(force: true);
  });

  Future<AppState> launchSignedIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Restored sign-in (like re-opening the app), before the UI exists.
    await tester.runAsync(() => client.auth.recoverSession(_sessionJson()));
    late AppState state;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => state = AppState(client: client),
      child: const UniEventsApp(),
    ));
    await _settle(tester);
    return state;
  }

  testWidgets('restored session loads the profile and shows the organizer shell', (tester) async {
    await launchSignedIn(tester);
    expect(find.text('Test Admin'), findsWidgets);
    expect(find.byIcon(Icons.dashboard_customize_rounded), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('dashboard and admin tabs finish loading', (tester) async {
    final state = await launchSignedIn(tester);
    expect(state.dashboardLoading, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await _settle(tester);
    expect(state.adminLoading, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _finish(tester);
  });

  testWidgets('language and theme switches take effect', (tester) async {
    final state = await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await _settle(tester, rounds: 3);

    // The language is picked from a list, so more languages can be added later.
    await tester.scrollUntilVisible(find.text('Language'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Language'));
    await _settle(tester, rounds: 3);
    expect(find.text('English'), findsWidgets);
    await tester.tap(find.text('Deutsch'));
    await _settle(tester, rounds: 3);
    expect(state.currentLocale.languageCode, 'de');
    expect(find.text('Erstellen'), findsOneWidget); // short German tab label
    expect(Localizations.localeOf(tester.element(find.byType(Scaffold).first)).languageCode, 'de');

    await tester.scrollUntilVisible(find.byIcon(Icons.dark_mode_rounded), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await _settle(tester, rounds: 3);
    expect(state.themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
    await _finish(tester);
  });

  testWidgets('notification bell: unread count, list, mark all read, open the event', (tester) async {
    final state = await launchSignedIn(tester);
    expect(state.unreadNotificationCount, 1);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await _settle(tester, rounds: 4);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.textContaining('Open Air Concert starts on'), findsOneWidget);
    expect(find.text('Application approved'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark all as read'));
    await _settle(tester, rounds: 3);
    expect(state.unreadNotificationCount, 0);
    expect(backend.requests, contains('PATCH /rest/v1/notifications'));
    expect(backend.bodies['/rest/v1/notifications'], contains('read_at'));

    await tester.tap(find.text('Reminder'));
    await _settle(tester, rounds: 4);
    expect(find.byType(EventDetailsScreen), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('a student asked "still coming?" confirms on the tickets tab', (tester) async {
    backend.role = 'student';
    backend.askConfirm = true;
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
    await _settle(tester, rounds: 4);
    expect(find.text('Are you still coming?'), findsOneWidget);
    expect(find.textContaining('may go to people on the waitlist'), findsNothing); // organizer did not opt in
    await tester.tap(find.text("Yes, I'm coming"));
    await _settle(tester, rounds: 10); // confirm, then reload the tickets
    expect(backend.requests, contains('POST /rest/v1/rpc/confirm_attendance'));
    expect(find.text('Thanks! Your seat is confirmed.'), findsOneWidget);
    expect(backend.bodies['/rest/v1/rpc/confirm_attendance'], contains('22222222-2222-2222-2222-222222222222'));
    await _finish(tester);
  });

  testWidgets('tickets for events that are over move to a folded "Past events" section', (tester) async {
    backend.role = 'student';
    backend.askConfirm = true;
    backend.pastTicket = true;
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
    await _settle(tester, rounds: 4);
    expect(find.text('Are you still coming?'), findsOneWidget); // the upcoming ticket stays on top
    expect(find.text('Last Week Lecture'), findsNothing); // folded away
    await tester.scrollUntilVisible(find.text('Past events (1)'), 300, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300)); // clear of the bottom bar
    await _settle(tester, rounds: 2);
    await tester.tap(find.text('Past events (1)'));
    await _settle(tester, rounds: 6);
    await tester.scrollUntilVisible(find.text('Last Week Lecture'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Last Week Lecture'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Leave Review'), findsOneWidget); // open event, so no scan needed to review
    await _finish(tester);
  });

  testWidgets('notifications can be swiped away or all deleted', (tester) async {
    final state = await launchSignedIn(tester);
    await tester.tap(find.byTooltip('Notifications'));
    await _settle(tester, rounds: 4);
    expect(state.notifications.length, 2);

    await tester.drag(find.text('Application approved'), const Offset(-600, 0));
    await _settle(tester, rounds: 12); // slide out, then the row closes up
    expect(find.text('Application approved'), findsNothing);
    expect(state.notifications.length, 1);
    expect(backend.requests, contains('DELETE /rest/v1/notifications'));

    await tester.tap(find.byTooltip('Delete all'));
    await _settle(tester, rounds: 3);
    expect(find.text('Delete all notifications?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete all'));
    await _settle(tester, rounds: 4);
    expect(state.notifications, isEmpty);
    expect(find.text('Reminder'), findsNothing);
    await _finish(tester);
  });

  testWidgets('organizer dashboard graphs and the event statistics page', (tester) async {
    await launchSignedIn(tester);
    expect(find.text('Registered, confirmed and came'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Average stars per event'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('4.5'), findsOneWidget);
    await tester.tap(find.text('Open Air Concert').first);
    await _settle(tester, rounds: 4);
    expect(find.text('Event statistics'), findsOneWidget);
    expect(find.text('40/100'), findsOneWidget);
    expect(find.text('23%'), findsOneWidget); // 9 of 40 seat holders did not come
    expect(find.textContaining('38 asked'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('4.5 average from 2 ratings'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Sign-ups per day'), findsOneWidget);
    expect(backend.requests, contains('POST /rest/v1/rpc/event_insights'));
    await _finish(tester);
  });

  testWidgets('notification settings are saved to the profile', (tester) async {
    final state = await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await _settle(tester, rounds: 3);
    await tester.scrollUntilVisible(find.text('Event reminders'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining("aren't available on this device"), findsOneWidget); // no Firebase in tests
    await tester.tap(find.text('Event reminders'));
    await _settle(tester, rounds: 3);
    expect(state.notifyReminders, isFalse);
    expect(backend.requests, contains('PATCH /rest/v1/profiles'));
    expect(jsonDecode(backend.bodies['/rest/v1/profiles']!), {'notify_reminders': false});
    await _finish(tester);
  });

  testWidgets('organizer can switch to student view and back', (tester) async {
    final state = await launchSignedIn(tester);
    await tester.tap(find.text('Test Admin').first);
    await _settle(tester, rounds: 3);
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded).last);
    await _settle(tester, rounds: 3);
    expect(state.currentRole, UserRole.student);
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('signing out shows only the public feed with a sign-in button', (tester) async {
    final state = await launchSignedIn(tester);
    // Not awaited: part of the sign-out runs on the test's fake clock, which _settle advances.
    state.signOut();
    await _settle(tester);
    expect(state.isSignedIn, isFalse);
    expect(state.isGuest, isTrue);
    expect(find.text('Alex Smith'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing); // no Tickets / Profile tabs
    expect(find.text('Sign in / Sign up'), findsOneWidget);
    expect(find.text('Open Air Concert'), findsOneWidget);

    // Opening an event asks the visitor to sign in instead.
    await tester.tap(find.text('Open Air Concert'));
    await _settle(tester, rounds: 3);
    expect(find.text('Sign in to see this event'), findsOneWidget);
    await tester.tap(find.text('Sign in / Sign up').last);
    await _settle(tester, rounds: 3);
    expect(find.text('Back to events'), findsOneWidget); // the sign-in screen
    await _finish(tester);
  });

  testWidgets('admin profile: photo button, 3-field password dialog, privacy page, wallpaper', (tester) async {
    final state = await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await _settle(tester, rounds: 3);
    expect(state.canHaveAvatar, isTrue);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(find.text('Push Notifications'), findsNothing); // removed until it really works

    await tester.tap(find.text('Change password'));
    await _settle(tester, rounds: 3);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('Repeat new password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password-1');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await tester.tap(find.text('Save'));
    await _settle(tester, rounds: 3);
    expect(find.text('The new passwords do not match.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester, rounds: 3);

    // The wallpaper choices are folded away until the card is opened.
    expect(find.text('Grid'), findsNothing);
    await tester.dragUntilVisible(find.text('Wallpaper Overlay'), find.byType(ListView).first, const Offset(0, -250));
    await _settle(tester, rounds: 10);
    await tester.tap(find.text('Wallpaper Overlay'));
    await _settle(tester, rounds: 4);
    await tester.dragUntilVisible(find.text('Grid'), find.byType(ListView).first, const Offset(0, -250));
    await _settle(tester, rounds: 10);
    await tester.tap(find.text('Grid'));
    await _settle(tester, rounds: 2);
    expect(state.selectedWallpaper, WallpaperPattern.frostedGeometry);
    // The organizer view paints the wallpaper too (not only the student feed).
    expect(state.currentRole, UserRole.planner);
    expect(
        find.byWidgetPredicate(
            (w) => w is Wallpaper && w.pattern == WallpaperPattern.frostedGeometry && w.scale == 1),
        findsOneWidget);
    for (final name in ['Dots', 'Waves', 'Sunset', 'Aurora', 'Ocean', 'Bubbles']) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.dragUntilVisible(find.text('Privacy & data'), find.byType(ListView).first, const Offset(0, -250));
    await _settle(tester, rounds: 10); // let the list stop moving; a tap on a moving list only stops it
    await tester.tap(find.text('Privacy & data'));
    await _settle(tester, rounds: 12);
    await tester.dragUntilVisible(find.text('Copy my data'), find.byType(ListView).last, const Offset(0, -250));
    expect(find.text('Copy my data'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('picking Other lets the organizer type a category', (tester) async {
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await _settle(tester, rounds: 3);
    expect(find.text('Your own category (optional)'), findsNothing);
    await tester.dragUntilVisible(find.text('Other'), find.byType(SingleChildScrollView).first, const Offset(0, -200));
    await _settle(tester, rounds: 6);
    await tester.tap(find.text('Other'));
    await _settle(tester, rounds: 3);
    final field = find.widgetWithText(TextFormField, 'Your own category (optional)');
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Yoga');
    await _settle(tester, rounds: 2);
    expect(find.byIcon(Icons.label_rounded), findsWidgets); // the live preview uses the custom category
    await _finish(tester);
  });

  testWidgets('sign-up code screen asks only for the code', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(client: client),
      child: const UniEventsApp(),
    ));
    await _settle(tester);
    await tester.tap(find.text('Sign in / Sign up'));
    await _settle(tester, rounds: 3);
    await tester.tap(find.text('New here? Create an account'));
    await _settle(tester, rounds: 3);
    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'New Person');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'new@example.org');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'long-password');
    await tester.tap(find.text('Create account').last);
    await _settle(tester, rounds: 8);
    expect(find.text("Check your email"), findsOneWidget);
    expect(find.textContaining('new@example.org'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsNothing); // no locked e-mail box
    expect(find.widgetWithText(TextFormField, 'Code from your email'), findsOneWidget);
    expect(find.text('Wrong email? Start again'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('student feed: organizer, search, Other list, contact links', (tester) async {
    backend.role = 'student';
    final state = await launchSignedIn(tester);
    await tester.tap(find.text('Public Events'));
    await _settle(tester, rounds: 6);
    expect(find.text('by Campus Club'), findsOneWidget);
    // This user organizes the event, so there is no Register button for it.
    expect(find.text('Your event'), findsOneWidget);
    expect(find.text('Register'), findsNothing);

    // Search by organizer, then something that matches nothing.
    await tester.tap(find.byIcon(Icons.search_rounded));
    await _settle(tester, rounds: 3);
    await tester.enterText(find.byType(TextField).first, 'campus');
    await _settle(tester, rounds: 3);
    expect(find.text('Open Air Concert'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await _settle(tester, rounds: 3);
    expect(find.text('Open Air Concert'), findsNothing);
    expect(find.text('No events match your search.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await _settle(tester, rounds: 3);

    // "Other" opens the list of custom categories.
    await tester.dragUntilVisible(find.text('Other'), find.byKey(const Key('categoryChips')), const Offset(-200, 0));
    await _settle(tester, rounds: 4);
    await tester.tap(find.text('Other'));
    await _settle(tester, rounds: 4);
    expect(find.text('More categories'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Yoga'));
    await _settle(tester, rounds: 4);
    expect(state.selectedCategory, 'Yoga');
    expect(find.text('Other: Yoga'), findsOneWidget);
    expect(find.text('Open Air Concert'), findsOneWidget);

    // Event page: host and contact links.
    await tester.tap(find.text('Open Air Concert'));
    await _settle(tester, rounds: 8);
    await tester.dragUntilVisible(find.text('Contact & links'), find.byType(CustomScrollView), const Offset(0, -250));
    await _settle(tester, rounds: 3);
    expect(find.text('Campus Club'), findsOneWidget);
    expect(find.text('club.example.org'), findsOneWidget);
    expect(find.text('club@example.org'), findsOneWidget);
    expect(find.text('YOUR EVENT'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('saving an event, the saved filter, calendar button', (tester) async {
    backend.role = 'student';
    final state = await launchSignedIn(tester);
    await tester.tap(find.text('Public Events'));
    await _settle(tester, rounds: 6);

    // Saved filter with nothing saved yet.
    await tester.tap(find.byTooltip('Show saved events'));
    await _settle(tester, rounds: 3);
    expect(find.text('Open Air Concert'), findsNothing);
    expect(find.textContaining('No saved events'), findsOneWidget);
    await tester.tap(find.byTooltip('Show all events'));
    await _settle(tester, rounds: 3);

    // The heart on the card saves it (sent to the server) and the filter then finds it.
    await tester.tap(find.byTooltip('Save event'));
    await _settle(tester, rounds: 4);
    expect(state.isFavorite('22222222-2222-2222-2222-222222222222'), isTrue);
    expect(backend.requests, contains('POST /rest/v1/favorites'));
    await tester.tap(find.byTooltip('Show saved events'));
    await _settle(tester, rounds: 3);
    expect(find.text('Open Air Concert'), findsOneWidget);

    // Event page: calendar button; no report menu on your own event.
    await tester.tap(find.text('Open Air Concert'));
    await _settle(tester, rounds: 8);
    expect(find.text('Add to calendar'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.byTooltip('Remove from saved'), findsWidgets); // page + the card underneath
    await _finish(tester);
  });

  testWidgets('admin sees reports and can remove the event', (tester) async {
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await _settle(tester);
    await tester.tap(find.text('Reports (1)'));
    await _settle(tester, rounds: 12); // let the tab finish sliding in
    expect(find.text('Spam or advertising'), findsOneWidget);
    expect(find.text('Only advertising'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove event'));
    await _settle(tester, rounds: 3);
    expect(find.textContaining('will be cancelled for everyone'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Advertising');
    await tester.tap(find.widgetWithText(FilledButton, 'Remove event').last);
    await _settle(tester, rounds: 6);
    final body = backend.bodies['/rest/v1/rpc/resolve_report'] ?? '';
    expect(body, contains('"p_remove":true'));
    expect(body, contains('"p_note":"Advertising"'));
    await _settle(tester, rounds: 6); // removing reloads the feed; let it finish
    await _finish(tester);
  });

  testWidgets('admin removes a user and blocks the address', (tester) async {
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await _settle(tester);
    await tester.tap(find.text('Users'));
    await _settle(tester, rounds: 12);
    expect(find.text('Troll Account'), findsOneWidget);
    await tester.tap(find.byTooltip('Change role'));
    await _settle(tester, rounds: 10); // let the menu finish opening
    await tester.ensureVisible(find.text('Remove user'));
    await tester.tap(find.text('Remove user'));
    await _settle(tester, rounds: 10); // menu closes, then the dialog opens
    expect(find.text('Remove Troll Account?'), findsOneWidget);
    expect(find.textContaining('Their 2 events are deleted too'), findsOneWidget);
    await tester.tap(find.text('Block this email address from signing up again'));
    await _settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove user'));
    await _settle(tester, rounds: 14);
    final body = backend.bodies['/functions/v1/remove-user'] ?? '';
    expect(body, contains('"user_id":"99999999-9999-9999-9999-999999999999"'));
    expect(body, contains('"block":true'));
    expect(find.text('Troll Account was removed'), findsOneWidget);
    await _settle(tester, rounds: 6);
    await _finish(tester);
  });

  testWidgets('admin sees blocked addresses and unblocks one', (tester) async {
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await _settle(tester);
    await tester.tap(find.text('Users'));
    await _settle(tester, rounds: 12);
    await tester.tap(find.text('Blocked addresses'));
    await _settle(tester, rounds: 8);
    expect(find.text('spammer@example.com'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Unblock'));
    await _settle(tester, rounds: 6);
    expect(find.text('spammer@example.com will be able to sign up again.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
    await _settle(tester, rounds: 6);
    expect(backend.bodies['/rest/v1/rpc/admin_unblock_email'], contains('spammer@example.com'));
    expect(find.text('No blocked addresses'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('organizer application needs position, phone and consent', (tester) async {
    backend.role = 'student';
    await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await _settle(tester, rounds: 3);
    final open = find.widgetWithText(FilledButton, 'Become an organizer');
    await tester.dragUntilVisible(open, find.byType(ListView).first, const Offset(0, -250));
    await _settle(tester, rounds: 10);
    await tester.tap(open);
    await _settle(tester, rounds: 4);
    expect(find.text('Your position *'), findsOneWidget);

    final form = find.byType(SingleChildScrollView).last;
    final send = find.text('Send request');
    await tester.dragUntilVisible(send, form, const Offset(0, -250));
    await _settle(tester, rounds: 3);
    await tester.tap(send);
    await _settle(tester, rounds: 3);
    expect(find.text('Please confirm this to send the request.'), findsOneWidget);
    expect(find.text('Please enter your position.'), findsOneWidget);
    expect(find.text('Please enter a phone number.'), findsOneWidget);
    expect(backend.requests.any((r) => r.contains('request_organizer_access')), isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, 'Organization or club name *'), 'HAW Film Club');
    await tester.enterText(find.widgetWithText(TextFormField, 'Your position *'), 'Chair');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone number *'), 'call me');
    await tester.dragUntilVisible(send, form, const Offset(0, -250));
    await _settle(tester, rounds: 10); // a tap on a moving list only stops it
    await tester.tap(find.byType(CheckboxListTile));
    await _settle(tester, rounds: 2);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(send);
    await _settle(tester, rounds: 3);
    expect(backend.requests.any((r) => r.contains('request_organizer_access')), isFalse); // bad phone

    await tester.enterText(find.widgetWithText(TextFormField, 'Phone number *'), '+49 40 1234567');
    await tester.dragUntilVisible(send, form, const Offset(0, -250));
    await _settle(tester, rounds: 3);
    await tester.tap(send);
    await _settle(tester, rounds: 8);
    final body = backend.bodies['/rest/v1/rpc/request_organizer_access'] ?? '';
    expect(body, contains('"p_phone":"+49 40 1234567"'));
    expect(body, contains('"p_position":"Chair"'));
    await _settle(tester, rounds: 6);
    expect(find.text('Request sent. An admin will review it.'), findsWidgets);
    await _finish(tester);
  });

  testWidgets('a student sees no photo button', (tester) async {
    backend.role = 'student';
    final state = await launchSignedIn(tester);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await _settle(tester, rounds: 3);
    expect(state.canHaveAvatar, isFalse);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    await _finish(tester);
  });
}
