/// Main navigation shell with custom bottom nav bar.
/// Redesigned: 3 tabs (Rodar, Progreso, Explorar) for the minimalista redesign.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Tab index mapping
enum AppTab { rodar, progreso, explorar }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.rodarScreen,
    required this.progresoScreen,
    required this.explorarScreen,
    this.initialTab = AppTab.rodar,
  });

  final Widget rodarScreen;
  final Widget progresoScreen;
  final Widget explorarScreen;
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
          widget.rodarScreen,    // 0: Rodar
          widget.progresoScreen, // 1: Progreso
          widget.explorarScreen, // 2: Explorar
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
          // Tab 0: Rodar
          _NavItem(
            icon: Icons.explore_rounded,
            label: 'Rodar',
            isSelected: _currentTab == AppTab.rodar,
            onTap: () => _onTabSelected(AppTab.rodar),
          ),
          // Tab 1: Progreso
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Progreso',
            isSelected: _currentTab == AppTab.progreso,
            onTap: () => _onTabSelected(AppTab.progreso),
          ),
          // Tab 2: Explorar
          _NavItem(
            icon: Icons.compass_calibration_rounded,
            label: 'Explorar',
            isSelected: _currentTab == AppTab.explorar,
            onTap: () => _onTabSelected(AppTab.explorar),
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
        width: 72,
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
