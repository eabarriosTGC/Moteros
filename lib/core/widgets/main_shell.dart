/// Main navigation shell with custom bottom nav bar.
/// Redesigned: 4 tabs (Inicio, Raids, Comunidad, Perfil) + center FAB.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Tab index mapping
enum AppTab { dashboard, raid, scannerPlaceholder, community, profile }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.dashboard,
    required this.raidScreen,
    required this.profileScreen,
    required this.communityScreen,
    this.initialTab = AppTab.dashboard,
  });

  final Widget dashboard;
  final Widget raidScreen;
  final Widget profileScreen;
  final Widget communityScreen;
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
          widget.dashboard,                // 0: Inicio
          widget.raidScreen,               // 1: Raids
          const SizedBox.shrink(),         // 2: FAB placeholder (never shown)
          widget.communityScreen,          // 3: Comunidad
          widget.profileScreen,            // 4: Perfil
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      height: AppSpacing.bottomNavHeight + safeBottom + 8,
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: safeBottom + 4,
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
          // Tab 0: Inicio
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Inicio',
            isSelected: _currentTab == AppTab.dashboard,
            onTap: () => _onTabSelected(AppTab.dashboard),
          ),
          // Tab 1: Raids
          _NavItem(
            icon: Icons.flag_rounded,
            label: 'Raids',
            isSelected: _currentTab == AppTab.raid,
            onTap: () => _onTabSelected(AppTab.raid),
          ),
          // Tab 2: FAB placeholder (spacer)
          const SizedBox(width: AppSpacing.fabSize),
          // Tab 3: Comunidad
          _NavItem(
            icon: Icons.groups_rounded,
            label: 'Comunidad',
            isSelected: _currentTab == AppTab.community,
            onTap: () => _onTabSelected(AppTab.community),
          ),
          // Tab 4: Perfil
          _NavItem(
            icon: Icons.person_rounded,
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
