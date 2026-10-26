import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/admin_model.dart';
import '../../core/models/event_host.dart';

/// The "Become an organizer" form. Besides the organization it asks for what an
/// admin needs to verify the person: their position, a phone number to call,
/// and optionally a website and up to 3 documents (school reference etc.).
/// Returns true when the request was sent.
class OrganizerApplicationScreen extends StatefulWidget {
  const OrganizerApplicationScreen({super.key});

  static const maxDocuments = 3;

  @override
  State<OrganizerApplicationScreen> createState() => _OrganizerApplicationScreenState();
}

class _OrganizerApplicationScreenState extends State<OrganizerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _org = TextEditingController();
  final _position = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _message = TextEditingController();
  final _documents = <ApplicationDocument>[];
  late String _role;
  bool _consent = false;
  bool _showConsentError = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final hasUniversity = context.read<AppState>().getTenantDomain().isNotEmpty;
    _role = hasUniversity ? 'organizer' : 'commercial_planner';
  }

  @override
  void dispose() {
    for (final c in [_org, _position, _phone, _website, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addDocument() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ApplicationDocument.extensions);
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.applyDocFailed)));
      return;
    }
    if (file == null) return;
    final size = await file.length();
    if (size != null && size > ApplicationDocument.maxBytes) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.applyDocTooBig)));
      return;
    }
    final doc = ApplicationDocument(file.name, await file.readAsBytes());
    if (doc.bytes.length > ApplicationDocument.maxBytes) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.applyDocTooBig)));
      return;
    }
    if (!const ['pdf', 'jpg', 'png'].contains(doc.extension)) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.applyDocWrongType)));
      return;
    }
    if (!mounted) return;
    setState(() => _documents.add(doc));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final valid = _formKey.currentState!.validate();
    setState(() => _showConsentError = !_consent);
    if (!valid || !_consent) return;

    setState(() => _sending = true);
    try {
      await appState.requestOrganizerAccess(OrganizerApplication(
        role: _role,
        organization: _org.text.trim(),
        position: _position.text.trim(),
        phone: EventContact.phone(_phone.text)!,
        website: EventContact.website(_website.text),
        message: _message.text.trim(),
        documents: List.of(_documents),
      ));
      navigator.pop(true);
    } catch (e) {
      final text = switch (e is PostgrestException ? e.message : '') {
        'no_university' => l10n.organizerErrNoUniversity,
        'request_pending' => l10n.organizerErrPending,
        'invalid_documents' => l10n.applyDocFailed,
        _ => e is StorageException ? l10n.applyDocFailed : l10n.organizerErrGeneric,
      };
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(text)));
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasUniversity = context.read<AppState>().getTenantDomain().isNotEmpty;

    Widget section(String title, [String? hint]) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary)),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(hint, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
            ],
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.organizerBecomeTitle)),
      body: Form(
        key: _formKey,
        // A Column (not a lazy ListView) so every field stays built and is validated on submit.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.applyIntro, style: TextStyle(color: theme.colorScheme.secondary)),
            section(l10n.applyTypeSection),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'organizer',
              groupValue: _role,
              onChanged: hasUniversity ? (v) => setState(() => _role = v!) : null,
              title: Text(l10n.organizerRoleUniversity),
              subtitle: hasUniversity ? null : Text(l10n.organizerErrNoUniversity, style: const TextStyle(fontSize: 11)),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'commercial_planner',
              groupValue: _role,
              onChanged: (v) => setState(() => _role = v!),
              title: Text(l10n.organizerRoleCommercial),
            ),
            section(l10n.applyAboutSection),
            TextFormField(
              controller: _org,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: '${l10n.organizerOrgName} *'),
              validator: (v) => (v ?? '').trim().length < 2 ? l10n.authErrNameRequired : null,
            ),
            TextFormField(
              controller: _position,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: '${l10n.applyPosition} *', hintText: l10n.applyPositionHint),
              validator: (v) => (v ?? '').trim().length < 2 ? l10n.applyPositionRequired : null,
            ),
            TextFormField(
              controller: _website,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.applyWebsite, hintText: 'www.example.org'),
              validator: (v) => EventContact.website(v ?? '') == '' ? l10n.formWebsiteError : null,
            ),
            section(l10n.applyContactSection, l10n.applyContactHint),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(labelText: '${l10n.applyPhone} *', hintText: '+49 40 1234567'),
              validator: (v) => switch (EventContact.phone(v ?? '')) {
                null => l10n.applyPhoneRequired,
                '' => l10n.formPhoneError,
                _ => null,
              },
            ),
            section(l10n.applyDocsSection, l10n.applyDocsHint),
            for (var i = 0; i < _documents.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(_documents[i].extension == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: theme.colorScheme.primary),
                  title: Text(_documents[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${(_documents[i].bytes.length / 1024).ceil()} KB'),
                  trailing: IconButton(
                    tooltip: l10n.applyDocRemove,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _sending ? null : () => setState(() => _documents.removeAt(i)),
                  ),
                ),
              ),
            if (_documents.length < OrganizerApplicationScreen.maxDocuments)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _addDocument,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(l10n.applyDocAdd),
                ),
              ),
            section(l10n.applyMessageSection),
            TextFormField(
              controller: _message,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(labelText: l10n.organizerMessage),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: _sending ? null : (v) => setState(() {
                _consent = v ?? false;
                if (_consent) _showConsentError = false;
              }),
              title: Text(l10n.applyConsent, style: const TextStyle(fontSize: 13)),
              subtitle: _showConsentError
                  ? Text(l10n.applyConsentRequired, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(l10n.organizerSubmit),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
