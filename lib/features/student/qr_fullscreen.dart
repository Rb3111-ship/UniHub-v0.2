import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// The ticket's QR code as large as the screen allows, with the screen at full
/// brightness so door scanners read it at once. Brightness goes back to normal
/// when the page closes.
class QrFullscreenPage extends StatefulWidget {
  const QrFullscreenPage({super.key, required this.payload, required this.title, required this.ticketId});

  final String payload;
  final String title;
  final String ticketId;

  static Future<void> open(BuildContext context, {required String payload, required String title, required String ticketId}) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QrFullscreenPage(payload: payload, title: title, ticketId: ticketId),
    ));
  }

  @override
  State<QrFullscreenPage> createState() => _QrFullscreenPageState();
}

class _QrFullscreenPageState extends State<QrFullscreenPage> {
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    _brightness(true);
    // While the code is on screen, ask every few seconds whether it was scanned.
    final appState = context.read<AppState>();
    _watch = Timer.periodic(const Duration(seconds: 3), (_) => appState.refreshRegistrations());
  }

  @override
  void dispose() {
    _watch?.cancel();
    _brightness(false);
    super.dispose();
  }

  Future<void> _brightness(bool max) async {
    if (kIsWeb) return; // browsers cannot change screen brightness
    try {
      if (max) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {
      // Not supported on this device; the big code still helps.
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = (size.shortestSide * 0.78).clamp(180.0, 420.0);
    final l10n = AppLocalizations.of(context)!;
    if (context.watch<AppState>().isTicketScanned(widget.ticketId)) {
      _watch?.cancel();
      return Scaffold(
        backgroundColor: const Color(0xFF137A50),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 120),
                  const SizedBox(height: 16),
                  Text(l10n.qrCheckedInTitle,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(widget.title,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF137A50)),
                    onPressed: () => Navigator.pop(context),
                    child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF12141C),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF12141C))),
            ),
            const SizedBox(height: 24),
            QrImageView(
              data: widget.payload,
              version: QrVersions.auto,
              size: side,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            ),
            const SizedBox(height: 16),
            Text(widget.ticketId,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFF12141C))),
          ],
        ),
      ),
    );
  }
}
