import 'package:flutter/material.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../auth/user_role.dart';

/// Each language is shown in its own language, so people can find theirs.
/// Adding a language: add lib/l10n/app_xx.arb, run `flutter gen-l10n`, add its
/// name here, and allow the code in the profiles.locale check in the database.
const _languageNames = {
  'en': 'English',
  'de': 'Deutsch',
};

String languageName(Locale locale) => _languageNames[locale.languageCode] ?? locale.languageCode.toUpperCase();

/// Bottom sheet listing every language the app is translated into.
Future<void> showLanguagePicker(BuildContext context, AppState appState) {
  final l10n = AppLocalizations.of(context)!;
  final current = appState.currentLocale.languageCode;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.languageLabel, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final locale in AppLocalizations.supportedLocales)
              ListTile(
                leading: Icon(
                  locale.languageCode == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: locale.languageCode == current ? Theme.of(ctx).colorScheme.primary : null,
                ),
                title: Text(languageName(locale)),
                onTap: () {
                  Navigator.pop(ctx);
                  appState.setLocale(Locale(locale.languageCode));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
