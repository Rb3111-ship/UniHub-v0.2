import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';

class PlannerScannerScreen extends StatefulWidget {
  const PlannerScannerScreen({super.key});

  @override
  State<PlannerScannerScreen> createState() => _PlannerScannerScreenState();
}

class _PlannerScannerScreenState extends State<PlannerScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleQrCode(String rawValue, AppState appState) {
    if (!_isScanning) return;
    
    setState(() {
      _isScanning = false;
    });

    try {
      final Map<String, dynamic> data = jsonDecode(rawValue);
      final ticketId = data['ticketId'] as String?;
      final userName = data['userName'] as String? ?? 'Alex Smith';
      
      if (ticketId != null) {
        final success = appState.validateAndScanTicket(ticketId);
        _showScanResultBottomSheet(context, success, userName, ticketId);
      } else {
        _showScanResultBottomSheet(context, false, 'Unknown Guest', 'Invalid Ticket Payload');
      }
    } catch (e) {
      _showScanResultBottomSheet(context, false, 'Unknown Guest', 'Invalid QR Format');
    }
  }

  void _triggerMockScan(AppState appState) {
    if (!_isScanning) return;

    final registeredIds = appState.registeredEventIds;
    String mockTicketId = 'TKT-000000-000';
    String mockEventId = 'evt-unknown';
    
    String? unscannedEventId;
    for (final id in registeredIds) {
      final tId = appState.getTicketId(id);
      if (!appState.isTicketScanned(tId)) {
        unscannedEventId = id;
        break;
      }
    }

    if (unscannedEventId != null) {
      mockEventId = unscannedEventId;
      mockTicketId = appState.getTicketId(mockEventId);
    } else if (registeredIds.isNotEmpty) {
      mockEventId = registeredIds.first;
      mockTicketId = appState.getTicketId(mockEventId);
    }
    
    final mockPayload = '{"ticketId": "$mockTicketId", "eventId": "$mockEventId", "userId": "student-1", "userName": "Alex Smith"}';
    _handleQrCode(mockPayload, appState);
  }

  void _showScanResultBottomSheet(
    BuildContext context,
    bool success,
    String userName,
    String ticketId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Status Icon Circle
              CircleAvatar(
                radius: 40,
                backgroundColor: (success ? Colors.green : Colors.red).withOpacity(0.12),
                child: Icon(
                  success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: success ? Colors.green : Colors.red,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title Status
              Text(
                success ? "Access Granted" : "Access Denied",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: success ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              
              // Message
              Text(
                success 
                    ? "Welcome, $userName! Attendance has been registered." 
                    : "Invalid or Already Scanned Ticket.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              
              // Details divider
              const Divider(),
              const SizedBox(height: 12),
              
              // Ticket details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Ticket ID:", style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
                  Text(ticketId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Action Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isScanning = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.plannerScannerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () {
              _scannerController.toggleTorch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Live camera viewfinder
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _handleQrCode(barcode.rawValue!, appState);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error, child) {
                    // Fallback visual design if camera fails/permissions not set
                    return Container(
                      color: const Color(0xFF1A1C23),
                      width: double.infinity,
                      height: double.infinity,
                      child: const Center(
                        child: Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white24,
                          size: 64,
                        ),
                      ),
                    );
                  },
                ),

                // Scanning Area Frame Overlay
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isScanning ? Colors.white : Colors.green, 
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),

                // Animated Laser Line Overlay
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Positioned(
                        top: 100 + (190 * _animation.value),
                        child: Container(
                          width: 240,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Mock Scan Trigger Button
                Positioned(
                  bottom: 20,
                  child: ElevatedButton.icon(
                    onPressed: () => _triggerMockScan(appState),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text("Mock Scan Ticket"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isScanning ? Icons.camera_alt_rounded : Icons.pause_circle_filled_rounded,
                    color: theme.colorScheme.secondary.withOpacity(0.6),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isScanning 
                        ? "Point the camera at a ticket QR code or click 'Mock Scan Ticket'" 
                        : "Processing ticket...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
