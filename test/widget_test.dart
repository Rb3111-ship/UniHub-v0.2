import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/core/auth/user_role.dart';
import 'package:uni_events_app/main.dart';

void main() {
  testWidgets('App launches and shows the student shell', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const UniEventsApp(),
      ),
    );
    await tester.pump();

    // Header branding icon (the Campus Hub tab uses the same icon, so match >= 1).
    expect(find.byIcon(Icons.school_rounded), findsWidgets);
    // Student navigation is shown by default.
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
  });
}
