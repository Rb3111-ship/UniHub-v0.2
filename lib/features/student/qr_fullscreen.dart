import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    _brightness(true);
  }

  @override
  void dispose() {
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
