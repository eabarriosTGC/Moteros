/// Main navigation shell with custom bottom nav bar.
/// Extended for F-30 (routes), F-34 (mileage), F-35 (leaderboard).
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_icons.dart';
import '../widgets/scanner_fab.dart';

/// Tab index mapping
enum AppTab { dashboard, raid, scanner, refugios, clan, profile, routes, mileage }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.dashboard,
    required this.raidScreen,
    required this.profileScreen,
    required this.refugiosScreen,
    required this.clanScreen,
    this.routeScreen,
    this.mileageScreen,
    this.leaderboardScreen,
    this.initialTab = AppTab.dashboard,
  });

  final Widget dashboard;
  final Widget raidScreen;
  final Widget profileScreen;
  final Widget refugiosScreen;
  final Widget clanScreen;
  final Widget? routeScreen;
  final Widget? mileageScreen;
  final Widget? leaderboardScreen;
  final AppTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late AppTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  void _onTabSelected(AppTab tab) {
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentTab.index,
        children: [
          widget.dashboard,
          widget.raidScreen,
          const SizedBox.shrink(), // Scanner placeholder (never shown)
          widget.refugiosScreen,
          widget.clanScreen,
          widget.profileScreen,
          widget.routeScreen ?? const SizedBox.shrink(),
          widget.mileageScreen ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = <Widget>[
      _NavItem(
        icon: AppIcons.dashboard,
        label: 'Tablero',
        isSelected: _currentTab == AppTab.dashboard,
        onTap: () => _onTabSelected(AppTab.dashboard),
      ),
      _NavItem(
        icon: AppIcons.raid,
        label: 'Raid',
        isSelected: _currentTab == AppTab.raid,
        onTap: () => _onTabSelected(AppTab.raid),
      ),
      // FAB sits here (center)
      const SizedBox(width: AppSpacing.fabSize),
      _NavItem(
        icon: AppIcons.clan,
        label: 'Club',
        isSelected: _currentTab == AppTab.clan,
        onTap: () => _onTabSelected(AppTab.clan),
      ),
      if (widget.routeScreen != null)
        _NavItem(
          icon: Icons.route_outlined,
          label: 'Rutas',
          isSelected: _currentTab == AppTab.routes,
          onTap: () => _onTabSelected(AppTab.routes),
        ),
      if (widget.mileageScreen != null)
        _NavItem(
          icon: Icons.speed_outlined,
          label: 'KM',
          isSelected: _currentTab == AppTab.mileage,
          onTap: () => _onTabSelected(AppTab.mileage),
        ),
      _NavItem(
        icon: AppIcons.profile,
        label: 'Perfil',
        isSelected: _currentTab == AppTab.profile,
        onTap: () => _onTabSelected(AppTab.profile),
      ),
    ];

    return Container(
      height: AppSpacing.bottomNavHeight +
          MediaQuery.of(context).padding.bottom +
          8,
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
