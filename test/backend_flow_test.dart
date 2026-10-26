import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/core/auth/user_role.dart';
import 'package:uni_events_app/core/widgets/wallpaper.dart';
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
    await tester.dragUntilVisible(find.text('Other'), find.byType(ListView).first, const Offset(-200, 0));
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
