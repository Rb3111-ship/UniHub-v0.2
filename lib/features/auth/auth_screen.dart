import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';

enum _Mode { signIn, signUp, verify, forgot, reset }

/// Sign in / sign up / e-mail code verification / password reset.
/// Codes (not links) are used so the same flow works on Android, iOS and the web.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _go(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _info = null;
      _code.clear();
    });
    _formKey.currentState?.reset();
  }

  String _message(Object e, AppLocalizations l10n) {
    if (e is AuthApiException) {
      switch (e.code) {
        case 'invalid_credentials':
          return l10n.authErrBadCredentials;
        case 'email_not_confirmed':
          return l10n.authErrEmailNotConfirmed;
        case 'otp_expired':
        case 'invalid_otp':
          return l10n.authErrCodeInvalid;
        case 'weak_password':
          return l10n.authErrPasswordShort;
      }
      return l10n.authErrGeneric;
    }
    if (e is AuthRetryableFetchException || e.toString().contains('SocketException')) {
      return l10n.authErrNetwork;
    }
    return l10n.authErrGeneric;
  }

  Future<void> _run(Future<void> Function() action, AppLocalizations l10n) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit(AppState appState, AppLocalizations l10n) {
    switch (_mode) {
      case _Mode.signIn:
        _run(() => appState.signIn(_email.text, _password.text), l10n);
      case _Mode.signUp:
        _run(() async {
          final signedIn = await appState.signUp(_email.text, _password.text, _name.text);
          if (!signedIn && mounted) _go(_Mode.verify);
        }, l10n);
      case _Mode.verify:
        _run(() => appState.verifySignUpCode(_email.text, _code.text), l10n);
      case _Mode.forgot:
        _run(() async {
          await appState.sendPasswordResetCode(_email.text);
          if (mounted) _go(_Mode.reset);
        }, l10n);
      case _Mode.reset:
        _run(() => appState.resetPasswordWithCode(_email.text, _code.text, _password.text), l10n);
    }
  }

  String _submitLabel(AppLocalizations l10n) => switch (_mode) {
        _Mode.signIn => l10n.authSignIn,
        _Mode.signUp => l10n.authSignUp,
        _Mode.verify => l10n.authVerify,
        _Mode.forgot => l10n.authSendCode,
        _Mode.reset => l10n.authResetSubmit,
      };

  String? _validateEmail(String? v, AppLocalizations l10n) {
    final value = v?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value) ? null : l10n.authErrInvalidEmail;
  }

  Widget _passwordField(AppLocalizations l10n, String label, {bool isNew = false}) {
    return TextFormField(
      controller: _password,
      obscureText: _hidePassword,
      autofillHints: [isNew ? AutofillHints.newPassword : AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
          onPressed: () => setState(() => _hidePassword = !_hidePassword),
        ),
      ),
      // Existing passwords are only checked for emptiness; new ones must be 8+ chars.
      validator: (v) => (v ?? '').length >= (isNew ? 8 : 1) ? null : l10n.authErrPasswordShort,
    );
  }

  List<Widget> _fields(AppLocalizations l10n, AppState appState) {
    const gap = SizedBox(height: 12);
    final emailField = TextFormField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      readOnly: _mode == _Mode.verify || _mode == _Mode.reset,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: l10n.authEmail, border: const OutlineInputBorder()),
      validator: (v) => _validateEmail(v, l10n),
    );
    final codeField = TextFormField(
      controller: _code,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      decoration: InputDecoration(labelText: l10n.authCode, border: const OutlineInputBorder()),
      validator: (v) => (v ?? '').trim().isEmpty ? l10n.authErrCodeRequired : null,
    );

    switch (_mode) {
      case _Mode.signIn:
        return [emailField, gap, _passwordField(l10n, l10n.authPassword)];
      case _Mode.signUp:
        final uni = appState.universityForEmail(_email.text);
        return [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(labelText: l10n.authDisplayName, border: const OutlineInputBorder()),
            validator: (v) => (v ?? '').trim().isEmpty ? l10n.authErrNameRequired : null,
          ),
          gap,
          emailField,
          if (_email.text.contains('@'))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                uni != null ? l10n.authUniDetected(uni) : l10n.authPublicAccount,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          gap,
          _passwordField(l10n, l10n.authPassword, isNew: true),
        ];
      case _Mode.verify:
        return [Text(l10n.authVerifyBody(_email.text.trim())), gap, emailField, gap, codeField];
      case _Mode.forgot:
        return [Text(l10n.authResetBody), gap, emailField];
      case _Mode.reset:
        return [emailField, gap, codeField, gap, _passwordField(l10n, l10n.authNewPassword, isNew: true)];
    }
  }

  List<Widget> _links(AppLocalizations l10n, AppState appState) {
    Widget link(String text, VoidCallback onTap) =>
        TextButton(onPressed: _busy ? null : onTap, child: Text(text));
    switch (_mode) {
      case _Mode.signIn:
        return [
          link(l10n.authForgotPassword, () => _go(_Mode.forgot)),
          link(l10n.authNoAccount, () => _go(_Mode.signUp)),
          link(l10n.authBackToEvents, appState.enterGuestMode),
        ];
      case _Mode.signUp:
        return [
          link(l10n.authHaveAccount, () => _go(_Mode.signIn)),
          link(l10n.authBackToEvents, appState.enterGuestMode),
        ];
      case _Mode.verify:
        return [
          link(l10n.authResend, () async {
            try {
              await appState.resendSignUpCode(_email.text);
              if (mounted) setState(() => _info = l10n.authResent);
            } catch (e) {
              if (mounted) setState(() => _error = _message(e, l10n));
            }
          }),
          link(l10n.authBackToSignIn, () => _go(_Mode.signIn)),
        ];
      case _Mode.forgot:
      case _Mode.reset:
        return [link(l10n.authBackToSignIn, () => _go(_Mode.signIn))];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    final title = switch (_mode) {
      _Mode.signIn => l10n.authSignIn,
      _Mode.signUp => l10n.authSignUp,
      _Mode.verify => l10n.authVerifyTitle,
      _Mode.forgot || _Mode.reset => l10n.authResetTitle,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.school_rounded, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      l10n.authWelcome,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.authTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                    const SizedBox(height: 28),
                    Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ..._fields(l10n, appState),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!, style: TextStyle(color: theme.colorScheme.primary)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : () => _submit(appState, l10n),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_submitLabel(l10n)),
                    ),
                    const SizedBox(height: 8),
                    ..._links(l10n, appState),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
