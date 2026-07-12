/// Main navigation shell with custom bottom nav bar.
/// The center button is a motorcycle-start-button styled QR scanner FAB.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_icons.dart';
import '../widgets/scanner_fab.dart';

/// Tab index mapping
enum AppTab { dashboard, raid, scanner, refugios, clan, profile }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.dashboard,
    required this.raidScreen,
    required this.profileScreen,
    required this.refugiosScreen,
    required this.clanScreen,
    this.initialTab = AppTab.dashboard,
  });

  final Widget dashboard;
  final Widget raidScreen;
  final Widget profileScreen;
  final Widget refugiosScreen;
  final Widget clanScreen;
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
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // 4 nav items + center FAB (Refugio moved to Profile menu)
    return Container(
      height: AppSpacing.bottomNavHeight + 16,
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
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
            label: 'Clan',
            isSelected: _currentTab == AppTab.clan,
            onTap: () => _onTabSelected(AppTab.clan),
          ),
          _NavItem(
            icon: AppIcons.profile,
            label: 'Perfil',
            isSelected: _currentTab == AppTab.profile,
            onTap: () => _onTabSelected(AppTab.profile),
          ),
        ],
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
