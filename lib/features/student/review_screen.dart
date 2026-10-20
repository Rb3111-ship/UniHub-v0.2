import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/review_model.dart';

class StudentReviewScreen extends StatefulWidget {
  final Event event;

  const StudentReviewScreen({super.key, required this.event});

  @override
  State<StudentReviewScreen> createState() => _StudentReviewScreenState();
}

class _StudentReviewScreenState extends State<StudentReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _claimedAttendance = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final brandColor = appState.getActiveTenantColor();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.reviewTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Details Card Header
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, color: brandColor, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.event.location,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Rating Section
              Text(
                localizations.reviewRating,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1.0;
                  final isSelected = starVal <= _rating;
                  return IconButton(
                    iconSize: 44,
                    icon: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? Colors.amber.shade700 : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = starVal;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Comment Section
              Text(
                localizations.reviewComment,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: localizations.reviewCommentHint,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please write a comment";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Conditional Checkbox for QR Code disabled
              if (!widget.event.requiresQrCode) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _claimedAttendance,
                  onChanged: (val) {
                    setState(() {
                      _claimedAttendance = val ?? false;
                    });
                  },
                  activeColor: brandColor,
                  title: Text(
                    localizations.reviewAttendanceClaim,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizations.reviewWarningDisclaimer,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final isVerified = widget.event.requiresQrCode;
                    final review = Review(
                      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
                      eventId: widget.event.id,
                      rating: _rating,
                      comment: _commentController.text.trim(),
                      timestamp: DateTime.now(),
                      isVerified: isVerified,
                      claimedAttendance: isVerified ? true : _claimedAttendance,
                    );

                    appState.addReview(review);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text(localizations.reviewSuccessMsg),
                      ),
                    );

                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  localizations.buttonSubmitReview,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
