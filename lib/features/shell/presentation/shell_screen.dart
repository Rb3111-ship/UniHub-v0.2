import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../student/home_screen.dart';
import '../../student/tickets_screen.dart';
import '../../student/profile_screen.dart';
import '../../planner/dashboard_screen.dart';
import '../../planner/create_event_screen.dart';
import '../../planner/qr_scanner_screen.dart';
import '../../admin/admin_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  // Track indexes for both student and planner view modes separately
  int _studentIndex = 0;
  int _plannerIndex = 0;

  final List<Widget> _studentScreens = const [
    StudentHomeScreen(),
    StudentTicketsScreen(),
    StudentProfileScreen(),
  ];

  /// Organizer tabs. The scanner is only built while its tab is open, so the camera
  /// is never running in the background. Admins get one more tab.
  List<Widget> _plannerScreens(int activeIndex, bool isAdmin) => [
        const PlannerDashboardScreen(),
        const PlannerCreateEventScreen(),
        activeIndex == 2 ? const PlannerScannerScreen() : const SizedBox.shrink(),
        const StudentProfileScreen(),
        if (isAdmin) const AdminScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final localizations = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 600;

    final isStudent = appState.currentRole == UserRole.student;
    final isAdmin = appState.usesBackend && appState.isAdmin;
    final plannerTabCount = isAdmin ? 5 : 4;
    final activeIndex = isStudent ? _studentIndex : _plannerIndex.clamp(0, plannerTabCount - 1);
    final activeScreens = isStudent ? _studentScreens : _plannerScreens(activeIndex, isAdmin);

    // Create Navigation destination lists based on active role
    final destinations = _getNavDestinations(localizations, isStudent, isAdmin);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Logo / Branding
                  Icon(
                    Icons.school_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.appTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _buildProfileSwitcher(context, appState),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          // Left Hand Navigation Rail for larger screens (Tablets/Desktops)
          if (isDesktop)
            NavigationRail(
              selectedIndex: activeIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  if (isStudent) {
                    _studentIndex = idx;
                  } else {
                    _plannerIndex = idx;
                  }
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),

          // Main Screen view
          Expanded(
            child: IndexedStack(
              index: activeIndex,
              children: activeScreens,
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar for Mobile screens
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: activeIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  if (isStudent) {
                    _studentIndex = idx;
                  } else {
                    _plannerIndex = idx;
                  }
                });
              },
              destinations: destinations
                  .map((d) => NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ))
                  .toList(),
            )
          : null,
    );
  }

  Widget _buildProfileSwitcher(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final active = appState.activeProfile;

    if (appState.usesBackend) {
      return PopupMenuButton<String>(
        onSelected: (choice) {
          if (choice == 'switch') {
            appState.setRole(appState.currentRole == UserRole.student ? UserRole.planner : UserRole.student);
          } else {
            appState.signOut();
          }
        },
        itemBuilder: (context) => [
          if (appState.canSwitchView)
            PopupMenuItem<String>(
              value: 'switch',
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 18),
                const SizedBox(width: 12),
                Text(appState.currentRole == UserRole.student
                    ? AppLocalizations.of(context)!.profileSwitchToOrganizer
                    : AppLocalizations.of(context)!.profileSwitchToStudent),
              ]),
            ),
          PopupMenuItem<String>(
            value: 'signout',
            child: Row(children: [
              const Icon(Icons.logout_rounded, size: 18),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.authSignOut),
            ]),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: appState.getActiveTenantColor(),
                child: const Icon(Icons.person_rounded, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(active.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, size: 18),
            ],
          ),
        ),
      );
    }

    IconData profileIcon = Icons.person_rounded;
    if (active.type == ProfileType.universityOrganizer) {
      profileIcon = Icons.school_rounded;
    } else if (active.type == ProfileType.commercialPlanner) {
      profileIcon = Icons.business_center_rounded;
    }

    return PopupMenuButton<int>(
      initialValue: appState.activeProfileIndex,
      onSelected: (idx) {
        appState.setActiveProfileIndex(idx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: appState.getActiveTenantColor(),
              child: Icon(profileIcon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              active.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(appState.mockProfiles.length, (index) {
          final profile = appState.mockProfiles[index];
          IconData itemIcon = Icons.person_rounded;
          String typeName = "Student";
          if (profile.type == ProfileType.universityOrganizer) {
            itemIcon = Icons.school_rounded;
            typeName = "University Event Organizer";
          } else if (profile.type == ProfileType.commercialPlanner) {
            itemIcon = Icons.business_center_rounded;
            typeName = "Commercial Planner";
          }

          final isSelected = index == appState.activeProfileIndex;

          return PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(
                  itemIcon,
                  color: isSelected ? appState.getUniversityColor(profile.universityDomain) : theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      typeName,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(Icons.check_rounded, color: appState.getUniversityColor(profile.universityDomain), size: 16),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  // Helper descriptor matching navigation styles
  List<_NavigationDestinationItem> _getNavDestinations(
    AppLocalizations localizations,
    bool isStudent,
    bool isAdmin,
  ) {
    if (isStudent) {
      return [
        _NavigationDestinationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: localizations.tabHome,
        ),
        _NavigationDestinationItem(
          icon: Icons.confirmation_number_outlined,
          selectedIcon: Icons.confirmation_number_rounded,
          label: localizations.tabTickets,
        ),
        _NavigationDestinationItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: localizations.tabProfile,
        ),
      ];
    } else {
      return [
        _NavigationDestinationItem(
          icon: Icons.dashboard_customize_outlined,
          selectedIcon: Icons.dashboard_customize_rounded,
          label: localizations.tabDashboard,
        ),
        _NavigationDestinationItem(
          icon: Icons.add_circle_outline_rounded,
          selectedIcon: Icons.add_circle_rounded,
          label: localizations.tabCreateEvent,
        ),
        _NavigationDestinationItem(
          icon: Icons.qr_code_scanner_outlined,
          selectedIcon: Icons.qr_code_scanner_rounded,
          label: localizations.tabScanner,
        ),
        _NavigationDestinationItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: localizations.tabProfile,
        ),
        if (isAdmin)
          _NavigationDestinationItem(
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings_rounded,
            label: localizations.tabAdmin,
          ),
      ];
    }
  }
}

class _NavigationDestinationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  _NavigationDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
