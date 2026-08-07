/// Navegación principal de Moteros — barra flotante Velocity UI.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum AppTab { rodar, progreso, explorar }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.rodarScreen,
    required this.progresoScreen,
    required this.explorarScreen,
    this.initialTab = AppTab.rodar,
    this.onTabSelected,
  });

  final Widget rodarScreen;
  final Widget progresoScreen;
  final Widget explorarScreen;
  final AppTab initialTab;
  final ValueChanged<AppTab>? onTabSelected;

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
    if (_currentTab == tab) return;
    setState(() => _currentTab = tab);
    widget.onTabSelected?.call(tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentTab.index,
        children: [widget.rodarScreen, widget.progresoScreen, widget.explorarScreen],
      ),
      bottomNavigationBar: _VelocityNavigation(
        currentTab: _currentTab,
        onSelected: _onTabSelected,
      ),
    );
  }
}

class _VelocityNavigation extends StatelessWidget {
  const _VelocityNavigation({required this.currentTab, required this.onSelected});

  final AppTab currentTab;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, safeBottom + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 70,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.elevated.withAlpha(242),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.borderLight.withAlpha(180)),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12)),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _NavItem(tab: AppTab.rodar, icon: Icons.near_me_rounded, label: 'Rodar', selected: currentTab == AppTab.rodar, onTap: onSelected)),
                Expanded(child: _NavItem(tab: AppTab.progreso, icon: Icons.query_stats_rounded, label: 'Progreso', selected: currentTab == AppTab.progreso, onTap: onSelected)),
                Expanded(child: _NavItem(tab: AppTab.explorar, icon: Icons.travel_explore_rounded, label: 'Explorar', selected: currentTab == AppTab.explorar, onTap: onSelected)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.icon, required this.label, required this.selected, required this.onTap});

  final AppTab tab;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<AppTab> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: () => onTap(tab),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withAlpha(28) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary.withAlpha(80) : Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 240),
                child: Icon(icon, size: 23, color: selected ? AppColors.primaryLight : AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: AppTypography.caption.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 10.5,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
