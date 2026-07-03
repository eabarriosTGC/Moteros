/// Dashboard — "Tablero de Instrumentos" mejorado.
/// Velocímetro animado, modo Big Buttons, hápticos y datos reales.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';
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
    _kmAnimation = CurvedAnimation(parent: _kmController, curve: Curves.easeOutCubic);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardBloc>().add(LoadDashboard(userId: 1));
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
                  Text(state.message, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeModeScreen())),
            tooltip: 'Modo Conducción',
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
              state.isBigButtons ? _buildBigStats(state) : _buildStatsRow(state),
              const SizedBox(height: AppSpacing.lg),
              _sectionHeader('ACCIONES RÁPIDAS'),
              const SizedBox(height: AppSpacing.sm),
              state.isBigButtons ? _buildBigActions(context) : _buildActionsRow(context),
              const SizedBox(height: AppSpacing.lg),
              _sectionHeader('RADAR DE ALERTAS'),
              const SizedBox(height: AppSpacing.sm),
              ...state.alerts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildAlertCard(a),
              )),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
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
                Container(width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withAlpha(60), width: 3),
                    boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(20), blurRadius: 25, spreadRadius: 5)],
                  ),
                ),
                Container(width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withAlpha(30), width: 1),
                  ),
                ),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$displayKm', style: AppTypography.monoLarge.copyWith(color: AppColors.primary)),
                  const Text('KM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('KILÓMETROS DE CONQUISTA', style: AppTypography.caption.copyWith(color: AppColors.textMuted, letterSpacing: 2)),
            const SizedBox(height: AppSpacing.xs),
            Text('${state.placesVisited} lugares · ${state.challengesCompleted} retos', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(DashboardLoaded state) => Row(children: [
    Expanded(child: _statTile('${state.placesVisited}', 'Lugares', AppIcons.location, AppColors.primary)),
    const SizedBox(width: AppSpacing.sm),
    Expanded(child: _statTile('${state.challengesCompleted}', 'Retos', AppIcons.medal, AppColors.secondary)),
    const SizedBox(width: AppSpacing.sm),
    Expanded(child: _statTile(_membershipLabel(state), 'Membresía', AppIcons.fuel, _membershipColor(state))),
  ]);

  Widget _buildBigStats(DashboardLoaded state) => Column(children: [
    Row(children: [
      Expanded(child: _bigStatTile('${state.placesVisited}', 'Lugares\nVisitados', AppIcons.location, AppColors.primary)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _bigStatTile('${state.challengesCompleted}', 'Retos\nCompletados', AppIcons.medal, AppColors.secondary)),
    ]),
    const SizedBox(height: AppSpacing.sm),
    Row(children: [
      Expanded(child: _bigStatTile(_membershipLabel(state), 'Estado\nMembresía', AppIcons.fuel, _membershipColor(state))),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _bigStatTile('${state.membershipDaysLeft}', 'Días\nRestantes', AppIcons.timer, AppColors.info)),
    ]),
  ]);

  Widget _statTile(String value, String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.mdCircular, border: Border.all(color: color.withAlpha(40))),
    child: Column(children: [
      Icon(icon, color: color, size: AppSpacing.iconMd),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTypography.h2.copyWith(color: color)),
      Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
    ]),
  );

  Widget _bigStatTile(String value, String label, IconData icon, Color color) => GestureDetector(
    onTap: _tap,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.mdCircular, border: Border.all(color: color.withAlpha(40))),
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppTypography.h1.copyWith(color: color)),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
        ])),
      ]),
    ),
  );

  Widget _buildActionsRow(BuildContext context) => Row(children: [
    Expanded(child: _actionBtn(context, AppIcons.qrScan, 'Escanear', AppColors.primary)),
    const SizedBox(width: AppSpacing.sm),
    Expanded(child: _actionBtn(context, AppIcons.sos, 'Auxilio', AppColors.error)),
    const SizedBox(width: AppSpacing.sm),
    Expanded(child: _actionBtn(context, AppIcons.navigate, 'Ruta', AppColors.info)),
  ]);

  Widget _buildBigActions(BuildContext context) => Column(children: [
    _bigActionBtn(context, AppIcons.qrScan, 'Escanear QR', 'Registra tu visita', AppColors.primary),
    const SizedBox(height: AppSpacing.sm),
    _bigActionBtn(context, AppIcons.sos, 'Auxilio Mecánico', 'SOS - Ayuda en carretera', AppColors.error),
    const SizedBox(height: AppSpacing.sm),
    _bigActionBtn(context, AppIcons.navigate, 'Navegar', 'Abrir mapa de ruta', AppColors.info),
  ]);

  Widget _actionBtn(BuildContext context, IconData icon, String label, Color color) => ElevatedButton.icon(
    onPressed: () { _tap(); },
    icon: Icon(icon, size: AppSpacing.iconSm),
    label: Text(label, style: AppTypography.buttonSmall),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.card, foregroundColor: color,
      side: BorderSide(color: color.withAlpha(60)),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
      minimumSize: const Size(0, 64),
    ),
  );

  Widget _bigActionBtn(BuildContext context, IconData icon, String title, String subtitle, Color color) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () { _tap(); },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.card, foregroundColor: color,
        side: BorderSide(color: color.withAlpha(60)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      ),
      child: Row(children: [
        Icon(icon, size: 32),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTypography.h3.copyWith(color: color)),
          Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
        ])),
        const Icon(AppIcons.chevronRight, color: AppColors.textMuted),
      ]),
    ),
  );

  Widget _buildAlertCard(AlertItem alert) => Container(
    width: double.infinity, padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: AppRadius.mdCircular,
      border: Border.all(color: alert.color.withAlpha(30)),
    ),
    child: Row(children: [
      Container(width: 3, height: 40,
        decoration: BoxDecoration(color: alert.color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(alert.icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(alert.message, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
        Text(alert.timeAgo, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
      ])),
    ]),
  );

  Widget _sectionHeader(String text) => Text(text, style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5));

  String _membershipLabel(DashboardLoaded s) {
    switch (s.membershipPlan) {
      case 'member': return 'Miembro';
      case 'premium': return 'Premium';
      case 'admin': return 'Admin';
      default: return 'Aspirante';
    }
  }

  Color _membershipColor(DashboardLoaded s) {
    switch (s.membershipPlan) {
      case 'member': return AppColors.primary;
      case 'premium': return AppColors.secondary;
      default: return AppColors.textMuted;
    }
  }
}
