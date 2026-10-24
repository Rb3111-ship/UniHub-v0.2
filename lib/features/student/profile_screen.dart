import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/utils/image_type.dart';
import '../../../core/widgets/language_picker.dart';
import '../../../core/widgets/wallpaper.dart';
import 'account_section.dart';
import 'privacy_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studentProfileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 24),
          if (appState.usesBackend) ...[
            const AccountSection(),
            const SizedBox(height: 12),
          ],

          _sectionTitle(context, l10n.prefSection),
          const SizedBox(height: 8),
          _settingCard(
            context,
            icon: Icons.language_rounded,
            title: l10n.languageLabel,
            subtitle: languageName(appState.currentLocale),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLanguagePicker(context, appState),
          ),
          const SizedBox(height: 12),
          _universityCard(context, appState, l10n),
          const SizedBox(height: 24),

          _sectionTitle(context, l10n.prefThemeMode),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SegmentedButton<ThemeMode>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: appState.getActiveTenantColor(),
                  selectedForegroundColor: Colors.white,
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
            ),
          ),
          const SizedBox(height: 24),

          // Folded away by default so the profile page stays calm.
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(Icons.wallpaper_rounded, color: theme.colorScheme.primary),
              title: Text(l10n.prefWallpaper, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: Text(wallpaperName(l10n, appState.selectedWallpaper),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(l10n.wallpaperHint, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                ),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: [
                    for (final pattern in wallpaperChoices) _wallpaperCard(context, appState, pattern, wallpaperName(l10n, pattern)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (appState.usesBackend) ...[
            _sectionTitle(context, l10n.accountSectionTitle),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.security_rounded, color: theme.colorScheme.primary),
                title: Text(l10n.privacyTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.privacySubtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: appState.signOut,
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.authSignOut),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            const DeleteAccountButton(),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _universityCard(BuildContext context, AppState appState, AppLocalizations l10n) {
    if (!appState.usesBackend) {
      // Demo mode only: pick a university to preview its branding.
      return _settingCard(
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
    return _settingCard(
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
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _settingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
      ),
    );
  }

  Widget _wallpaperCard(BuildContext context, AppState appState, WallpaperPattern pattern, String label) {
    final isSelected = appState.selectedWallpaper == pattern;
    final theme = Theme.of(context);
    final brandColor = appState.getActiveTenantColor();

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => appState.setWallpaper(pattern),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? brandColor : theme.colorScheme.outlineVariant.withOpacity(0.6),
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSelected ? 11 : 13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Wallpaper(pattern: pattern, brand: brandColor, scale: 0.5),
                      if (isSelected)
                        Center(child: Icon(Icons.check_circle_rounded, color: brandColor, size: 24)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? brandColor : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
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

    final avatar = CircleAvatar(
      radius: 36,
      backgroundColor: color,
      foregroundImage: photo == null ? null : NetworkImage(photo),
      child: Text(_initials(profile.name),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.surface,
                          child: Icon(Icons.photo_camera_rounded, size: 14, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              avatar,
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  Text(profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_roleLabel(appState, l10n),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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
