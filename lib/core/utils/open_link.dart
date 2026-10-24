import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an e-mail, phone or https link in the matching app. If no app can open
/// it, the text is copied instead so the user can still use it.
Future<void> openLink(BuildContext context, Uri uri, String copyText) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  // Only these schemes are ever opened (the database only stores https links).
  if (!const {'https', 'mailto', 'tel'}.contains(uri.scheme)) return;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    await Clipboard.setData(ClipboardData(text: copyText));
    messenger.showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
  }
}
