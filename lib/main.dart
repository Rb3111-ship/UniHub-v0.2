import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import 'app/config/theme.dart';
import 'core/auth/user_role.dart';
import 'features/shell/presentation/shell_screen.dart';

void main() {
  // Ensure Flutter engine bindings are initialized prior to loading dependencies
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const UniEventsApp(),
    ),
  );
}

class UniEventsApp extends StatelessWidget {
  const UniEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'UNIHUB',
      debugShowCheckedModeBanner: false,
      
      // Theme Settings
      theme: AppTheme.getLightTheme(appState.getActiveTenantColor()),
      darkTheme: AppTheme.getDarkTheme(appState.getActiveTenantColor()),
      themeMode: appState.themeMode,

      // Localization Configuration
      locale: appState.currentLocale,
      supportedLocales: const [
        Locale('en'), // English
        Locale('de'), // German
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Home Screen Wrapper (Shell Layout)
      home: const ShellScreen(),
    );
  }
}
