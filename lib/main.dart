import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import 'app/config/env.dart';
import 'app/config/theme.dart';
import 'core/auth/user_role.dart';
import 'features/auth/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw something immediately; the backend is connected afterwards so a slow or
  // failing start-up shows a message instead of a frozen launch screen.
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseKey,
      ).timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return ChangeNotifierProvider(
        create: (_) => AppState(client: Supabase.instance.client),
        child: const UniEventsApp(),
      );
    }
    // Shown before translations are loaded, so pick the language from the phone.
    final german = WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'de';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1E40AF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('UniHub',
                    style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                if (_error == null)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  Text(
                      german
                          ? 'UniHub konnte nicht starten. Prüfe deine Internetverbindung und versuche es erneut.'
                          : 'UniHub could not start. Check your internet connection and try again.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  Text('$_error',
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E40AF)),
                    onPressed: _start,
                    child: Text(german ? 'Erneut versuchen' : 'Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      home: const AuthGate(),
    );
  }
}
