/// Dashboard — "Tablero de Instrumentos" mejorado.
/// Velocímetro animado, modo Big Buttons, hápticos y datos reales.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';
import '../../../validation/presentation/screens/qr_scanner_screen.dart';
import '../../../alerts/presentation/screens/radar_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../../../raids/presentation/bloc/raid_bloc.dart';
import '../../../raids/presentation/bloc/raid_event.dart';
import '../../../raids/presentation/bloc/raid_state.dart';
import '../../../raids/presentation/screens/create_raid_screen.dart';
import '../../../raids/presentation/screens/raid_list_screen.dart';
import '../../../raids/presentation/screens/raid_lobby_screen.dart';
import '../../../raids/presentation/screens/raid_live_screen.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _kmController;
  late Animation<double> _kmAnimation;
  bool _kmAnimated = false;

  @override
  void initState() {
    super.initState();
    _kmController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _kmAnimation = CurvedAnimation(
      parent: _kmController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardBloc>().add(LoadDashboard(userId: 1));
      context.read<RaidBloc>().add(const LoadRaids());
    });
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  void _animateKm() {
    if (!_kmAnimated) {
      _kmController.forward();
      _kmAnimated = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _tap() => HapticFeedback.lightImpact();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is DashboardError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.error, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Error al cargar', style: AppTypography.h2),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is DashboardLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _animateKm());
          return _buildDashboard(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardLoaded state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AsfaltoClub'),
        actions: [
          IconButton(
            icon: Icon(
              state.isBigButtons ? Icons.touch_app : Icons.touch_app_outlined,
              color: state.isBigButtons ? AppColors.primary : null,
            ),
            onPressed: () {
              _tap();
              context.read<DashboardBloc>().add(ToggleBigButtons());
            },
            tooltip: 'Modo Big Buttons',
          ),
          IconButton(
            icon: const Icon(AppIcons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSpeedometer(state),
              const SizedBox(height: AppSpacing.lg),
              state.isBigButtons
                  ? _buildBigStats(state)
                  : _buildStatsRow(state),
              const SizedBox(height: AppSpacing.lg),
              _sectionHeader('ACCIONES RÁPIDAS'),
              const SizedBox(height: AppSpacing.sm),
              state.isBigButtons
                  ? _buildBigActions(context)
                  : _buildActionsRow(context),
              const SizedBox(height: AppSpacing.lg),
              _sectionHeader('RADAR DE ALERTAS'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _tap();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RadarScreen()),
                      );
                    },
                    child: Text(
                      'VER TODAS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...state.alerts.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildAlertCard(a),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _sectionHeader('RAIDS'),
              const SizedBox(height: AppSpacing.sm),
              _buildRaidSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedometer(DashboardLoaded state) {
    final displayKm = (_kmAnimation.value * state.totalKm).round();
    return AnimatedBuilder(
      animation: _kmAnimation,
      builder: (context, child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: AppGradients.cardHighlight,
          borderRadius: AppRadius.lgCircular,
          border: Border.all(color: AppColors.primary.withAlpha(30), width: 1),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(60),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(20),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(30),
                      width: 1,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$displayKm',
                      style: AppTypography.monoLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'KM',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'KILÓMETROS DE CONQUISTA',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${state.placesVisited} lugares · ${state.challengesCompleted} retos',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(DashboardLoaded state) => Row(
    children: [
      Expanded(
        child: _statTile(
          '${state.placesVisited}',
          'Lugares',
          AppIcons.location,
          AppColors.primary,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _statTile(
          '${state.challengesCompleted}',
          'Retos',
          AppIcons.medal,
          AppColors.secondary,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _statTile(
          _membershipLabel(state),
          'Membresía',
          AppIcons.fuel,
          _membershipColor(state),
        ),
      ),
    ],
  );

  Widget _buildBigStats(DashboardLoaded state) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _bigStatTile(
              '${state.placesVisited}',
              'Lugares\nVisitados',
              AppIcons.location,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _bigStatTile(
              '${state.challengesCompleted}',
              'Retos\nCompletados',
              AppIcons.medal,
              AppColors.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _bigStatTile(
              _membershipLabel(state),
              'Estado\nMembresía',
              AppIcons.fuel,
              _membershipColor(state),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _bigStatTile(
              '${state.membershipDaysLeft}',
              'Días\nRestantes',
              AppIcons.timer,
              AppColors.info,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _statTile(String value, String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSpacing.iconMd),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTypography.h2.copyWith(color: color)),
            Text(
              label,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );

  Widget _bigStatTile(String value, String label, IconData icon, Color color) =>
      GestureDetector(
        onTap: _tap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdCircular,
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: AppTypography.h1.copyWith(color: color)),
                    Text(
                      label,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildActionsRow(BuildContext context) => Row(
    children: [
      Expanded(
        child: _actionBtn(
          context,
          AppIcons.qrScan,
          'Scan',
          AppColors.primary,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _actionBtn(context, AppIcons.sos, 'Auxilio', AppColors.error),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _actionBtn(context, AppIcons.navigate, 'Ruta', AppColors.info),
      ),
    ],
  );

  Widget _buildBigActions(BuildContext context) => Column(
    children: [
      _bigActionBtn(
        context,
        AppIcons.qrScan,
        'Scan QR',
        'Registra tu visita',
        AppColors.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      _bigActionBtn(
        context,
        AppIcons.sos,
        'Auxilio Mecánico',
        'SOS - Ayuda en carretera',
        AppColors.error,
      ),
      const SizedBox(height: AppSpacing.sm),
      _bigActionBtn(
        context,
        AppIcons.navigate,
        'Navegar',
        'Abrir mapa de ruta',
        AppColors.info,
      ),
    ],
  );

  Widget _actionBtn(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) => ElevatedButton.icon(
    onPressed: () {
      _tap();
      if (label == 'Scan') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
        );
      } else if (label == 'Auxilio') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SafeModeScreen()),
        );
      } else if (label == 'Ruta') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RouteTrackerScreen()),
        );
      }
    },
    icon: Icon(icon, size: AppSpacing.iconSm),
    label: Text(label, style: AppTypography.buttonSmall),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: color,
      side: BorderSide(color: color.withAlpha(60)),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
      minimumSize: const Size(0, 64),
    ),
  );

  Widget _bigActionBtn(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () {
        _tap();
        if (title.startsWith('Scan')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          );
        } else if (title.startsWith('Auxilio')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SafeModeScreen()),
          );
        } else if (title.startsWith('Navegar')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RouteTrackerScreen()),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(60)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3.copyWith(color: color)),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(AppIcons.chevronRight, color: AppColors.textMuted),
        ],
      ),
    ),
  );

  Widget _buildAlertCard(AlertItem alert) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.mdCircular,
      border: Border.all(color: alert.color.withAlpha(30)),
    ),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 40,
          decoration: BoxDecoration(
            color: alert.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(alert.icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.message,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                alert.timeAgo,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(String text) => Text(
    text,
    style: AppTypography.label.copyWith(
      color: AppColors.textMuted,
      letterSpacing: 1.5,
    ),
  );

  String _membershipLabel(DashboardLoaded s) {
    switch (s.membershipPlan) {
      case 'member':
        return 'Miembro';
      case 'premium':
        return 'Premium';
      case 'admin':
        return 'Admin';
      default:
        return 'Aspirante';
    }
  }

  Color _membershipColor(DashboardLoaded s) {
    switch (s.membershipPlan) {
      case 'member':
        return AppColors.primary;
      case 'premium':
        return AppColors.secondary;
      default:
        return AppColors.textMuted;
    }
  }

  /// ── Raids section (reads from RaidBloc) ──

  Widget _buildRaidSection() {
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        if (state is RaidsLoaded) {
          final activeRaids = state.raids
              .where((r) => r['status'] == 'lobby' || r['status'] == 'active')
              .take(3)
              .toList();
          if (activeRaids.isEmpty) {
            return _buildNoRaidsCard();
          }
          return Column(
            children: [
              ...activeRaids.map((r) => _buildDashboardRaidCard(r)),
              const SizedBox(height: AppSpacing.sm),
              _buildRaidActions(),
            ],
          );
        }
        return _buildRaidActions();
      },
    );
  }

  Widget _buildDashboardRaidCard(Map<String, dynamic> raid) {
    final title = raid['title'] ?? 'Raid';
    final gameMode = raid['game_mode'] ?? 'Free Ride';
    final status = raid['status'] ?? 'lobby';
    final raidId = raid['id']?.toString() ?? '';
    final participants = (raid['raid_participants'] as List?)?.length ?? 0;
    final isActive = status == 'active';

    return GestureDetector(
      onTap: () {
        if (raidId.isEmpty) return;
        _tap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isActive
                ? RaidLiveScreen(raidId: raidId)
                : RaidLobbyScreen(raidId: raidId),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(
            color: isActive
                ? AppColors.secondary.withAlpha(40)
                : AppColors.primary.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            // Pulse dot for active
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? AppColors.success : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isActive ? AppColors.success : AppColors.primary)
                        .withAlpha(80),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$gameMode · $participants participante${participants != 1 ? 's' : ''}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.secondary.withAlpha(20)
                    : AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isActive ? 'EN VIVO' : 'LOBBY',
                style: AppTypography.caption.copyWith(
                  color: isActive ? AppColors.secondary : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRaidsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.raid,
            size: 32,
            color: AppColors.textMuted.withAlpha(80),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sin raids activos',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRaidActions(),
        ],
      ),
    );
  }

  Widget _buildRaidActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _tap();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRaidScreen()),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'CREAR RAID',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _tap();
              // Navigate to raid tab — access the parent MainShell
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaidListScreen()),
              );
            },
            icon: const Icon(Icons.list, size: 18),
            label: const Text(
              'VER TODOS',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
      ],
    );
  }
}
