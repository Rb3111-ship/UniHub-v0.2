import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/event_model.dart';

class PlannerCreateEventScreen extends StatefulWidget {
  /// When [editing] is set the screen edits that event instead of creating a new one.
  const PlannerCreateEventScreen({super.key, this.editing});

  final Event? editing;

  @override
  State<PlannerCreateEventScreen> createState() => _PlannerCreateEventScreenState();
}

class _PlannerCreateEventScreenState extends State<PlannerCreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  final List<String> _selectedCategories = ['Sports'];
  double _capacity = 100;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  
  bool _requiresQr = true;
  bool _allowReviews = true;
  bool _unlimited = false;
  bool _busy = false;

  // Poster image: a freshly picked file (uploaded on save) or the one already stored.
  Uint8List? _pickedBytes;
  String? _pickedMime;
  String? _pickedExt;
  String? _imagePath;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titleController.text = e.title;
      _descController.text = e.description;
      _locationController.text = e.location;
      _selectedCategories
        ..clear()
        ..addAll(e.categories);
      _selectedDate = e.date;
      _requiresQr = e.requiresQrCode;
      _allowReviews = e.allowReviews;
      _unlimited = e.capacity == null;
      _capacity = (e.capacity ?? 100).clamp(1, 1000).toDouble();
      _imagePath = e.imagePath;
      _existingImageUrl = e.imageUrl;
    }
    // Add text controllers listeners to trigger rebuilds for the live preview card
    _titleController.addListener(() => setState(() {}));
    _descController.addListener(() => setState(() {}));
    _locationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Works out the image type from the file's first bytes (never trusts the file name).
  ({String mime, String ext})? _sniffImage(Uint8List b) {
    if (b.length > 12 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return (mime: 'image/png', ext: 'png');
    }
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return (mime: 'image/jpeg', ext: 'jpg');
    }
    if (b.length > 12 && String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return (mime: 'image/webp', ext: 'webp');
    }
    return null;
  }

  Future<void> _pickImage(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final type = _sniffImage(bytes);
    if (type == null) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.eventImageBadType)));
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.eventImageTooBig)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedMime = type.mime;
      _pickedExt = type.ext;
    });
  }

  /// Uploads the picked image. Returns its storage path, or null if nothing was picked
  /// or the upload failed (a message is shown in that case).
  Future<String?> _uploadPickedImage(AppState appState, AppLocalizations l10n) async {
    final bytes = _pickedBytes;
    if (bytes == null) return null;
    try {
      return await appState.uploadEventImage(bytes, _pickedMime!, _pickedExt!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(l10n.eventImageUploadFailed)),
        );
      }
      return null;
    }
  }

  Future<void> _saveEdit(AppState appState, AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    final original = widget.editing!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      var imagePath = _imagePath;
      if (_pickedBytes != null) {
        imagePath = await _uploadPickedImage(appState, l10n);
        if (imagePath == null) return; // upload failed, message already shown
      }
      final updated = Event(
        id: original.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        date: _selectedDate,
        endDate: _selectedDate.add(original.endDate.difference(original.date)),
        location: _locationController.text.trim(),
        universityDomain: original.universityDomain,
        isUniversityOfficial: original.isUniversityOfficial,
        requiresQrCode: _requiresQr,
        allowReviews: _allowReviews,
        categories: List.from(_selectedCategories),
        capacity: _unlimited ? null : _capacity.round(),
        priceCents: original.priceCents,
        status: original.status,
        imageUrl: original.imageUrl,
        imagePath: imagePath,
      );
      await appState.updateEvent(updated);
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(l10n.eventSaved)));
      navigator.pop();
    } catch (e) {
      final denied = e is PostgrestException && e.code == '42501';
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text(denied ? l10n.eventPublishNotAllowed : l10n.eventPublishFailed),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelEvent(AppState appState, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.eventCancelConfirmTitle),
        content: Text(l10n.eventCancelConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.ticketCancelNo)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.eventCancelYes),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await appState.cancelEvent(widget.editing!.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventCancelledMsg)));
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.eventCancelFailed)));
    }
  }

  Widget _buildImagePicker(AppLocalizations l10n, ThemeData theme, Color color) {
    final hasImage = _pickedBytes != null || _existingImageUrl != null;
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_pickedBytes != null)
            Image.memory(_pickedBytes!, fit: BoxFit.cover)
          else if (_existingImageUrl != null)
            Image.network(_existingImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
          else
            Center(child: Icon(Icons.image_outlined, size: 48, color: theme.colorScheme.outline)),
          Positioned(
            right: 8,
            bottom: 8,
            child: FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _pickImage(l10n),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: Text(hasImage ? l10n.eventChangeImage : l10n.eventAddImage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String key, String label, AppLocalizations localizations) {
    final isSelected = _selectedCategories.contains(key);
    final appState = context.read<AppState>();
    final activeColor = appState.getActiveTenantColor();

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            if (_selectedCategories.length < 3) {
              _selectedCategories.add(key);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("You can select up to 3 categories only."),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (_selectedCategories.length > 1) {
              _selectedCategories.remove(key);
            }
          }
        });
      },
      selectedColor: activeColor.withOpacity(0.2),
      checkmarkColor: activeColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final isOfficial = appState.currentPlannerType == PlannerType.universityAdmin;
    
    // Check screen width for side-by-side responsive split
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    Widget formWidget = Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Event Parameters",
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              
              // Event Title
              _buildSectionHeader(localizations.formFieldTitle),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: "e.g. TUM Hackathon 2026",
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (val) => val == null || val.trim().length < 3 ? "Please enter a title (at least 3 characters)" : null,
              ),
              const SizedBox(height: 16),
              _buildImagePicker(localizations, theme, appState.getActiveTenantColor()),
              const SizedBox(height: 16),

              // Category Selector (Chips list)
              _buildSectionHeader("Event Categories (Select up to 3)"),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildCategoryChip("Music", localizations.categoryMusic, localizations),
                  _buildCategoryChip("Tech", localizations.categoryTech, localizations),
                  _buildCategoryChip("Sports", localizations.categorySports, localizations),
                  _buildCategoryChip("Arts", localizations.categoryArts, localizations),
                  _buildCategoryChip("Academic", "Academic", localizations),
                  _buildCategoryChip("Other", "Other", localizations),
                ],
              ),
              const SizedBox(height: 16),

              // Location
              _buildSectionHeader(localizations.formFieldLocation),
              const SizedBox(height: 6),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: "e.g. Main Hall, Building B",
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                validator: (val) => val == null || val.trim().length < 2 ? "Please enter a location" : null,
              ),
              const SizedBox(height: 16),

              // Date Selector
              _buildSectionHeader("Date & Time"),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: _selectedDate.isBefore(DateTime.now()) ? _selectedDate : DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && context.mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDate),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: appState.getActiveTenantColor()),
                      const SizedBox(width: 12),
                      Text(
                        "${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}  -  ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Text("Change Date/Time", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sliders & Toggles section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(localizations.formFieldCapacity),
                  Text(
                    _unlimited ? '\u221e' : _capacity.round().toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: appState.getActiveTenantColor(),
                    ),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text("No attendee limit", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                value: _unlimited,
                onChanged: (val) => setState(() => _unlimited = val),
              ),
              Slider(
                value: _capacity,
                min: 1,
                max: 1000,
                label: _capacity.round().toString(),
                activeColor: appState.getActiveTenantColor(),
                onChanged: _unlimited ? null : (val) => setState(() => _capacity = val),
              ),
              const SizedBox(height: 8),

              // Inferred Official Status Banner
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isOfficial 
                      ? appState.getActiveTenantColor().withOpacity(0.12)
                      : theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOfficial 
                        ? appState.getActiveTenantColor().withOpacity(0.3)
                        : theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOfficial ? Icons.verified_user_rounded : Icons.public_rounded,
                      color: isOfficial ? appState.getActiveTenantColor() : theme.colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOfficial ? "University Event Organizer Event" : "Commercial Planner Event",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isOfficial ? appState.getActiveTenantColor() : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOfficial 
                                ? "Automatically inferred as official event under ${appState.getTenantDomain()}"
                                : "Inferred as public / commercial event",
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Switch for requiresQrCode
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeColor: appState.getActiveTenantColor(),
                title: Text(
                  localizations.fieldRequireQr,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                value: _requiresQr,
                onChanged: (val) => setState(() => _requiresQr = val),
              ),

              // Switch for allowReviews
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeColor: appState.getActiveTenantColor(),
                title: Text(
                  localizations.fieldAllowReviews,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                value: _allowReviews,
                onChanged: (val) => setState(() => _allowReviews = val),
              ),
              const SizedBox(height: 16),

              // Description
              _buildSectionHeader(localizations.formFieldDescription),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Enter event schedules, speakers, rules, etc.",
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 24),

              // Publish Button
              ElevatedButton(
                onPressed: _busy ? null : () async {
                  if (widget.editing != null) {
                    await _saveEdit(appState, localizations);
                    return;
                  }
                  if (_formKey.currentState!.validate()) {
                    final imagePath = await _uploadPickedImage(appState, localizations);
                    if (!context.mounted) return;
                    if (_pickedBytes != null && imagePath == null) return; // upload failed, message shown
                    final newEvent = Event(
                      id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
                      title: _titleController.text,
                      description: _descController.text.isNotEmpty 
                          ? _descController.text 
                          : "No description provided.",
                      date: _selectedDate,
                      location: _locationController.text,
                      universityDomain: isOfficial ? appState.getTenantDomain() : '',
                      isUniversityOfficial: isOfficial,
                      requiresQrCode: _requiresQr,
                      allowReviews: _allowReviews,
                      categories: List.from(_selectedCategories),
                      capacity: _unlimited ? null : _capacity.round(),
                      endDate: _selectedDate.add(const Duration(hours: 2)),
                      imagePath: imagePath,
                    );
                    
                    try {
                      await appState.addEvent(newEvent);
                    } catch (e) {
                      if (!context.mounted) return;
                      final denied = e is PostgrestException && e.code == '42501';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(denied
                              ? localizations.eventPublishNotAllowed
                              : localizations.eventPublishFailed),
                        ),
                      );
                      return;
                    }
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text("Event published successfully to '${isOfficial ? localizations.tabCampusHub : localizations.tabPublicEvents}'!"),
                      ),
                    );
                    
                    // Reset Form
                    _formKey.currentState!.reset();
                    _titleController.clear();
                    _descController.clear();
                    _locationController.clear();
                    setState(() {
                      _requiresQr = true;
                      _allowReviews = true;
                      _selectedCategories.clear();
                      _selectedCategories.add('Sports');
                      _capacity = 100;
                      _unlimited = false;
                      _pickedBytes = null;
                      _selectedDate = DateTime.now().add(const Duration(days: 7));
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appState.getActiveTenantColor(),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.editing != null ? localizations.eventSaveChanges : localizations.buttonPublish,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.editing != null && !widget.editing!.isCancelled) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _cancelEvent(appState, localizations),
                  icon: const Icon(Icons.event_busy_rounded),
                  label: Text(localizations.eventCancelEvent),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    Widget previewWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.visibility_rounded, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              localizations.headerLivePreview,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Live preview of student-facing card
        _buildPreviewCard(context, appState, localizations),
      ],
    );

    return Scaffold(
      appBar: widget.editing != null ? AppBar(title: Text(localizations.eventEditTitle)) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: formWidget),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: previewWidget),
                ],
              )
            : Column(
                children: [
                  formWidget,
                  const SizedBox(height: 24),
                  previewWidget,
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    final theme = Theme.of(context);
    final universityColor = appState.getActiveTenantColor();
    final isOfficial = appState.currentPlannerType == PlannerType.universityAdmin;
    
    // Determine dynamic title / category icon / labels
    final previewTitle = _titleController.text.isNotEmpty ? _titleController.text : "Upcoming Event Title";
    final previewLocation = _locationController.text.isNotEmpty ? _locationController.text : "Campus Location / Room";
    final previewDesc = _descController.text.isNotEmpty ? _descController.text : "Type in the description input field to see details rendered instantly on this card preview.";
    
    final firstCat = _selectedCategories.isNotEmpty ? _selectedCategories.first : 'Other';
    IconData categoryIcon = Icons.event_rounded;
    if (firstCat == 'Music') categoryIcon = Icons.music_note_rounded;
    if (firstCat == 'Tech') categoryIcon = Icons.code_rounded;
    if (firstCat == 'Sports') categoryIcon = Icons.sports_soccer_rounded;
    if (firstCat == 'Arts') categoryIcon = Icons.palette_rounded;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOfficial 
              ? universityColor 
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: isOfficial ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Bar (Official status styling)
            if (isOfficial)
              Container(
                height: 6,
                color: universityColor,
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Icon Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isOfficial ? universityColor : theme.colorScheme.primary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon,
                          color: isOfficial ? universityColor : theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              previewTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Official/Public Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOfficial
                                        ? universityColor.withOpacity(0.12)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOfficial
                                        ? "${appState.getTenantDomain().toUpperCase()} ${localizations.officialBadge}"
                                        : localizations.publicBadge,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isOfficial ? universityColor : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // QR code scanner badge
                                if (_requiresQr)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.tertiary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.qr_code_2_rounded, size: 10, color: theme.colorScheme.tertiary),
                                        const SizedBox(width: 2),
                                        Text(
                                          "QR IN",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date & Location Details
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        "${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year} @ ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: theme.colorScheme.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          previewLocation,
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    previewDesc,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  // Footer Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (_allowReviews)
                            Row(
                              children: [
                                Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                const Text("Reviews Enabled", style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text("Details"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOfficial ? universityColor : theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Register"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
