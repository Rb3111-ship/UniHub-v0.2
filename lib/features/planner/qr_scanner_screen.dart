import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/registration_model.dart';

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
  List<Event> _managedEvents = [];
  Event? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    final appState = context.read<AppState>();
    if (appState.usesBackend) _loadManagedEvents(appState);
  }

  Future<void> _loadManagedEvents(AppState appState) async {
    try {
      final events = await appState.loadManagedEvents();
      if (!mounted) return;
      // Prefer events that are happening soon: upcoming first, then recent ones.
      final now = DateTime.now();
      events.sort((a, b) {
        final aLive = a.endDate.isAfter(now) ? 0 : 1;
        final bLive = b.endDate.isAfter(now) ? 0 : 1;
        return aLive != bLive ? aLive - bLive : a.date.compareTo(b.date);
      });
      setState(() {
        _managedEvents = events;
        _selectedEvent = events.isEmpty ? null : events.first;
      });
    } catch (_) {
      // The picker stays empty; the planner can reopen the tab to retry.
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBackendScan(String rawValue, AppState appState) async {
    final event = _selectedEvent;
    if (event == null) {
      _showScanResultBottomSheet(context, false, '', '',
          message: 'Choose the event you are scanning for first.');
      return;
    }
    const prefix = 'unihub:1:';
    if (!rawValue.startsWith(prefix)) {
      _showScanResultBottomSheet(context, false, '', 'Not a UniHub ticket',
          message: 'This is not a UniHub ticket.');
      return;
    }
    try {
      final CheckInResult r = await appState.checkInTicket(rawValue.substring(prefix.length), event.id);
      if (!mounted) return;
      final message = switch (r.result) {
        'granted' => 'Welcome, ${r.attendeeName ?? 'guest'}! Attendance has been registered.',
        'already_used' => '${r.attendeeName ?? 'This guest'} was already checked in.',
        'wrong_event' => 'This ticket is for a different event.',
        'cancelled' => 'This ticket was cancelled.',
        _ => 'Invalid ticket.',
      };
      _showScanResultBottomSheet(context, r.ok, r.attendeeName ?? '', r.ticketDisplayId, message: message);
    } catch (e) {
      if (!mounted) return;
      final denied = e is PostgrestException && e.code == '42501';
      _showScanResultBottomSheet(context, false, '', '',
          message: denied
              ? 'You are not allowed to scan tickets for this event.'
              : 'Could not reach the server. Check your connection and scan again.');
    }
  }

  Future<void> _enterCodeManually(AppState appState) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter ticket code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Paste the code from the ticket'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Check in')),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    _handleQrCode(code.startsWith('unihub:1:') ? code : 'unihub:1:$code', appState);
  }

  void _handleQrCode(String rawValue, AppState appState) {
    if (!_isScanning) return;

    setState(() {
      _isScanning = false;
    });

    if (appState.usesBackend) {
      _handleBackendScan(rawValue, appState);
      return;
    }

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
    String ticketId, {
    String? message,
  }) {
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
                message ?? (success ? "Welcome, $userName! Attendance has been registered." : "Invalid or Already Scanned Ticket."),
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
              if (ticketId.isNotEmpty)
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

  Widget _buildEventPicker(ThemeData theme) {
    if (_managedEvents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: theme.colorScheme.surfaceContainer,
        child: Text(
          'You have no events yet. Create one to start checking in guests.',
          style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.surfaceContainer,
      child: DropdownButton<String>(
        isExpanded: true,
        underline: const SizedBox(),
        value: _selectedEvent?.id,
        items: _managedEvents
            .map((e) => DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.title}  -  ${e.date.day}.${e.date.month}.', overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (id) => setState(() {
          _selectedEvent = _managedEvents.firstWhere((e) => e.id == id);
        }),
      ),
    );
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
          if (appState.usesBackend)
            IconButton(
              tooltip: 'Enter code manually',
              icon: const Icon(Icons.keyboard_rounded),
              onPressed: () => _enterCodeManually(appState),
            ),
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
          if (appState.usesBackend) _buildEventPicker(theme),
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

                // Mock Scan Trigger Button (demo mode only)
                if (!appState.usesBackend)
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
