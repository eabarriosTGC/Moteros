/// Main navigation shell with custom bottom nav bar.
/// The center button is a motorcycle-start-button styled QR scanner FAB.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_icons.dart';
import '../widgets/scanner_fab.dart';

/// Tab index mapping
enum AppTab { dashboard, map, scanner, refugios, challenges, profile }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.dashboard,
    required this.mapScreen,
    required this.challengesScreen,
    required this.profileScreen,
    required this.refugiosScreen,
    this.initialTab = AppTab.dashboard,
  });

  final Widget dashboard;
  final Widget mapScreen;
  final Widget challengesScreen;
  final Widget profileScreen;
  final Widget refugiosScreen;
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
          widget.mapScreen,
          const SizedBox.shrink(), // Scanner placeholder (never shown)
          widget.refugiosScreen,
          widget.challengesScreen,
          widget.profileScreen,
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: AppSpacing.bottomNavHeight + 16, // extra for FAB overlap
      padding: EdgeInsets.only(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavItem(
            icon: AppIcons.dashboard,
            label: 'Tablero',
            isSelected: _currentTab == AppTab.dashboard,
            onTap: () => _onTabSelected(AppTab.dashboard),
          ),
          _NavItem(
            icon: AppIcons.map,
            label: 'Mapa',
            isSelected: _currentTab == AppTab.map,
            onTap: () => _onTabSelected(AppTab.map),
          ),
          // Center FAB spacer
          const SizedBox(width: AppSpacing.fabSize + 8),
          _NavItem(
            icon: AppIcons.shelter,
            label: 'Refugio',
            isSelected: _currentTab == AppTab.refugios,
            onTap: () => _onTabSelected(AppTab.refugios),
          ),
          _NavItem(
            icon: AppIcons.challenges,
            label: 'Retos',
            isSelected: _currentTab == AppTab.challenges,
            onTap: () => _onTabSelected(AppTab.challenges),
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
