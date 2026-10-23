import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../student/home_screen.dart';

/// Read-only event browsing for visitors who are not signed in (public events only).
/// Registering asks them to sign in first.
class GuestHome extends StatelessWidget {
  const GuestHome({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.appTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.guestBanner,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.languageLabel,
                      icon: const Icon(Icons.language_rounded),
                      onPressed: appState.toggleLocale,
                    ),
                    FilledButton(
                      onPressed: appState.leaveGuestMode,
                      child: Text(l10n.authSignIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(child: StudentHomeScreen()),
        ],
      ),
    );
  }
}
