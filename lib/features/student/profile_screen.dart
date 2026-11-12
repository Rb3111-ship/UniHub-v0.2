import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../app/config/theme.dart';
import '../../../core/widgets/ticket_stub.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/utils/image_type.dart';
import '../../../core/widgets/language_picker.dart';
import 'account_section.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    final signedIn = appState.usesBackend;

    Widget group(String title, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, title),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, row) in rows.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 56),
                    row,
                  ],
                ],
              ),
            ),
          ],
        );

    // The settings, grouped the way phone and web settings pages usually are.
    final settings = <Widget>[
      if (signedIn) ...[
        _sectionTitle(context, l10n.accountSectionTitle),
        const SizedBox(height: 8),
        const AccountSection(),
        const SizedBox(height: 24),
        _sectionTitle(context, l10n.notifSettingsTitle),
        const SizedBox(height: 8),
        const NotificationSettingsCard(),
        const SizedBox(height: 24),
      ],
      group(l10n.prefSection, [
        _settingRow(
          context,
          icon: Icons.language_rounded,
          title: l10n.languageLabel,
          subtitle: languageName(appState.currentLocale),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLanguagePicker(context, appState),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.contrast_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Text(l10n.prefThemeMode, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.brightness == Brightness.dark ? theme.colorScheme.primary : AppTheme.ink,
                  selectedForegroundColor: theme.brightness == Brightness.dark ? theme.colorScheme.onPrimary : Colors.white,
                ),
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.themeSystem),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.themeLight),
                    icon: const Icon(Icons.light_mode_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.themeDark),
                    icon: const Icon(Icons.dark_mode_rounded, size: 16),
                  ),
                ],
                selected: {appState.themeMode},
                onSelectionChanged: (s) => appState.setThemeMode(s.first),
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        _universityCard(context, appState, l10n),
      ]),
      if (signedIn) ...[
        const SizedBox(height: 24),
        group(l10n.privacyTitle, [
          _settingRow(
            context,
            icon: Icons.security_rounded,
            title: l10n.privacyTitle,
            subtitle: l10n.privacySubtitle,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
        ]),
      ],
    ];

    // Leaving: sign out, and (quieter) delete the account.
    final leave = <Widget>[
      if (signedIn) ...[
        OutlinedButton.icon(
          onPressed: appState.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(l10n.authSignOut),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            backgroundColor: theme.cardTheme.color,
            side: BorderSide(color: theme.colorScheme.error.withOpacity(0.4)),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 8),
        const DeleteAccountButton(),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studentProfileTitle)),
      body: LayoutBuilder(
        builder: (context, box) {
          // PC: the member pass stays on the left, the settings scroll on the right.
          if (box.maxWidth >= 900) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 340,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 12, 24),
                        children: [const _ProfileHeader(), const SizedBox(height: 16), ...leave],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 40),
                        children: settings,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ProfileHeader(),
                      const SizedBox(height: 24),
                      ...settings,
                      const SizedBox(height: 32),
                      ...leave,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _universityCard(BuildContext context, AppState appState, AppLocalizations l10n) {
    if (!appState.usesBackend) {
      // Demo mode only: pick a university to preview its branding.
      return _settingRow(
        context,
        icon: Icons.school_rounded,
        title: l10n.universityLabel,
        subtitle: appState.getTenantDisplayName(),
        trailing: DropdownButton<String>(
          value: appState.currentTenant,
          underline: const SizedBox(),
          items: [
            for (final t in appState.tenantDetails.keys) DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (t) {
            if (t != null) appState.setTenant(t);
          },
        ),
      );
    }
    // Real accounts: the university comes from the verified e-mail domain and cannot
    // be picked (otherwise anyone could see another university's events).
    final hasUniversity = appState.currentTenant.isNotEmpty;
    return _settingRow(
      context,
      icon: Icons.school_rounded,
      title: hasUniversity ? appState.getTenantDisplayName() : l10n.universityLabel,
      subtitle: hasUniversity ? l10n.universityFromEmail : l10n.universityNone,
      trailing: Icon(hasUniversity ? Icons.verified_rounded : Icons.public_rounded,
          color: hasUniversity ? Colors.green : Colors.grey),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(title.toUpperCase(),
          style: monoStyle(size: 11, color: Theme.of(context).colorScheme.secondary, weight: FontWeight.w700, spacing: 1.4)),
    );
  }

  Widget _settingRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Name, e-mail, role and (for organizers and admins) the profile photo.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  String _roleLabel(AppState appState, AppLocalizations l10n) {
    if (!appState.usesBackend) {
      return switch (appState.activeProfile.type) {
        ProfileType.student => l10n.roleStudent,
        ProfileType.universityOrganizer => l10n.roleOrganizer,
        ProfileType.commercialPlanner => l10n.roleCommercial,
      };
    }
    return switch (appState.dbRole) {
      'organizer' => l10n.roleOrganizer,
      'commercial_planner' => l10n.roleCommercial,
      'tenant_admin' => l10n.roleTenantAdmin,
      'platform_admin' => l10n.rolePlatformAdmin,
      _ => l10n.roleStudent,
    };
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _photoMenu(BuildContext context, AppState appState, AppLocalizations l10n) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l10n.avatarChange),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            if (appState.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text(l10n.avatarRemove),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'remove') {
        await appState.removeAvatar();
        messenger.showSnackBar(SnackBar(content: Text(l10n.avatarRemoved)));
        return;
      }
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final type = sniffImageType(bytes);
      if (type == null || bytes.length > 2 * 1024 * 1024) {
        messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.avatarFailed)));
        return;
      }
      await appState.uploadAvatar(bytes, type.mime, type.ext);
      messenger.showSnackBar(SnackBar(content: Text(l10n.avatarUpdated)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.avatarFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final profile = appState.activeProfile;
    final color = appState.getActiveTenantColor();
    final photo = appState.avatarUrl;

    final dark = theme.brightness == Brightness.dark;
    const soft = Color(0xFFB9C0E6);
    final hasUniversity = appState.getTenantDisplayName().isNotEmpty;

    final avatar = CircleAvatar(
      radius: 34,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 31,
        backgroundColor: color,
        foregroundImage: photo == null ? null : NetworkImage(photo),
        child: Text(_initials(profile.name),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );

    Widget fact(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: monoStyle(size: 9.5, color: soft, spacing: 1.2)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        );

    return Material(
      color: dark ? const Color(0xFF1B1530) : AppTheme.ink,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                if (appState.canHaveAvatar)
                  Tooltip(
                    message: l10n.avatarChange,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _photoMenu(context, appState, l10n),
                      child: Stack(
                        children: [
                          avatar,
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.photo_camera_rounded, size: 14, color: AppTheme.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  avatar,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                      const SizedBox(height: 2),
                      Text(profile.email,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(size: 11, color: soft, spacing: 0.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const DashedRule(color: Color(0x55FFFFFF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                fact(l10n.profileRoleLabel, _roleLabel(appState, l10n)),
                if (hasUniversity) ...[
                  const SizedBox(width: 12),
                  fact(l10n.universityLabel, appState.getTenantDisplayName()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
