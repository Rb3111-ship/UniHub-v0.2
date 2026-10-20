import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.studentProfileTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User profile card
          _buildUserProfileCard(context),
          const SizedBox(height: 24),

          _buildSectionTitle(context, "Preferences"),
          const SizedBox(height: 8),

          // Localization toggle
          _buildSettingCard(
            context,
            icon: Icons.language_rounded,
            title: localizations.languageLabel,
            subtitle: appState.currentLocale.languageCode == 'en'
                ? localizations.languageEnglish
                : localizations.languageGerman,
            trailing: Switch(
              value: appState.currentLocale.languageCode == 'de',
              onChanged: (isGerman) {
                appState.setLocale(isGerman ? const Locale('de') : const Locale('en'));
              },
            ),
          ),
          const SizedBox(height: 12),

          // Tenant selector
          _buildSettingCard(
            context,
            icon: Icons.school_rounded,
            title: "Active Tenant (University)",
            subtitle: appState.getTenantDisplayName(),
            trailing: DropdownButton<String>(
              value: appState.currentTenant,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: const [
                DropdownMenuItem(value: 'TUM', child: Text('TUM')),
                DropdownMenuItem(value: 'LMU', child: Text('LMU')),
                DropdownMenuItem(value: 'UHH', child: Text('UHH')),
              ],
              onChanged: (newTenant) {
                if (newTenant != null) {
                  appState.setTenant(newTenant);
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Customization: Theme Mode
          _buildSectionTitle(context, localizations.prefThemeMode),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(Icons.brightness_medium_rounded, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<ThemeMode>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: appState.getActiveTenantColor(),
                          selectedForegroundColor: Colors.white,
                        ),
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(localizations.themeSystem),
                            icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(localizations.themeLight),
                            icon: const Icon(Icons.light_mode_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(localizations.themeDark),
                            icon: const Icon(Icons.dark_mode_rounded, size: 16),
                          ),
                        ],
                        selected: {appState.themeMode},
                        onSelectionChanged: (newSelection) {
                          appState.setThemeMode(newSelection.first);
                        },
                        showSelectedIcon: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Customization: Wallpaper
          _buildSectionTitle(context, localizations.prefWallpaper),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildWallpaperCard(
                context,
                appState,
                WallpaperPattern.minimalVelvet,
                "Minimal Velvet",
                Icons.lens_blur_rounded,
                appState.getActiveTenantColor(),
              ),
              const SizedBox(width: 12),
              _buildWallpaperCard(
                context,
                appState,
                WallpaperPattern.frostedGeometry,
                "Frosted Geometry",
                Icons.grid_on_rounded,
                appState.getActiveTenantColor(),
              ),
              const SizedBox(width: 12),
              _buildWallpaperCard(
                context,
                appState,
                WallpaperPattern.cyberAurora,
                "Cyber Aurora",
                Icons.waves_rounded,
                appState.getActiveTenantColor(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildSectionTitle(context, "Account"),
          const SizedBox(height: 8),

          _buildSettingCard(
            context,
            icon: Icons.notifications_active_outlined,
            title: "Push Notifications",
            subtitle: "Receive reminders for upcoming events",
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
          const SizedBox(height: 12),

          _buildSettingCard(
            context,
            icon: Icons.security_rounded,
            title: "Privacy & Data",
            subtitle: "Manage your shared calendar preferences",
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 32),

          // Sign out / reset simulation button
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Firebase Authentication: Signed out mock user")),
              );
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text("Sign Out"),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
              minimumSize: const Size(double.infinity, 50),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();
    final profile = appState.activeProfile;
    final initials = _getInitials(profile.name);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: appState.getActiveTenantColor().withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: appState.getActiveTenantColor().withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: appState.getActiveTenantColor(),
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    profile.email,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: appState.getActiveTenantColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      profile.type == ProfileType.student
                          ? "Student Member"
                          : (profile.type == ProfileType.universityOrganizer
                              ? "University Event Organizer"
                              : "Commercial Planner"),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: appState.getActiveTenantColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return "${parts[0].isNotEmpty ? parts[0][0] : ''}${parts[1].isNotEmpty ? parts[1][0] : ''}".toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : "US";
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
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

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperCard(
    BuildContext context,
    AppState appState,
    WallpaperPattern pattern,
    String label,
    IconData icon,
    Color brandColor,
  ) {
    final isSelected = appState.selectedWallpaper == pattern;
    final theme = Theme.of(context);

    Widget backgroundPreview;
    if (pattern == WallpaperPattern.cyberAurora) {
      backgroundPreview = Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF120C1F), Color(0xFF3B1E6C), Color(0xFF1E3B6C), Color(0xFF0C141F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    } else if (pattern == WallpaperPattern.frostedGeometry) {
      backgroundPreview = Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          painter: GridPainter(color: theme.colorScheme.onSurface.withOpacity(0.15)),
        ),
      );
    } else {
      backgroundPreview = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121214), // matte dark
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => appState.setWallpaper(pattern),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? brandColor : theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned.fill(child: backgroundPreview),
                Container(
                  color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.05),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? (pattern == WallpaperPattern.cyberAurora ? Colors.white : brandColor)
                            : theme.colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (pattern == WallpaperPattern.cyberAurora ? Colors.white : theme.colorScheme.onSurface)
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
