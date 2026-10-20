import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../shell/presentation/shell_screen.dart';
import 'auth_screen.dart';

/// Chooses between sign-in, profile loading and the main app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.isSignedIn) return const AuthScreen();
    if (!appState.profileReady) return const _ProfileLoading();
    return const ShellScreen();
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    return Scaffold(
      body: Center(
        child: appState.profileFailed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.authProfileLoadFailed),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: appState.loadProfile, child: Text(l10n.authRetry)),
                  TextButton(onPressed: appState.signOut, child: Text(l10n.authSignOut)),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
