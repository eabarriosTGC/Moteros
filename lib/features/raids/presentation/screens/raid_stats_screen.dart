/// Raid Stats Screen — AsfaltoClub Battle Ride.
/// Pantalla de resultados con XP animado, ranking final y mapa de calor.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';

class RaidStatsScreen extends StatefulWidget {
  final String raidId;
  const RaidStatsScreen({super.key, required this.raidId});

  @override
  State<RaidStatsScreen> createState() => _RaidStatsScreenState();
}

class _RaidStatsScreenState extends State<RaidStatsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _xpController;
  late Animation<double> _xpAnimation;
  bool _xpAnimated = false;

  @override
  void initState() {
    super.initState();
    _xpController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _xpAnimation = CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RaidBloc>().add(LoadRaidStats(raidId: widget.raidId));
    });
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        if (state is RaidLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is RaidStatsLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_xpAnimated) {
              _xpController.forward();
              _xpAnimated = true;
              HapticFeedback.mediumImpact();
            }
          });
          return _buildStatsScreen(state);
        }
        if (state is RaidError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(state.message, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: Text('Cargando...', style: TextStyle(color: AppColors.textMuted))),
        );
      },
    );
  }

  Widget _buildStatsScreen(RaidStatsLoaded state) {
    final displayXp = (_xpAnimation.value * state.earnedXp).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // RAID COMPLETADO header
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGlow,
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events, color: AppColors.success, size: 40),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('RAID COMPLETADO',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                state.raid['description'] ?? 'Raid',
                style: AppTypography.h3.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // XP earned with animation
              AnimatedBuilder(
                animation: _xpAnimation,
                builder: (context, child) => Column(
                  children: [
                    Text('+$displayXp',
                      style: AppTypography.monoLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('XP GANADOS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Stats grid
              _buildStatsGrid(state),
              const SizedBox(height: AppSpacing.xl),

              // Final ranking
              _buildFinalRanking(state),
              const SizedBox(height: AppSpacing.xl),

              // Heat map (simulated)
              _buildHeatMap(),
              const SizedBox(height: AppSpacing.xl),

              // Action buttons
              _buildActions(state),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(RaidStatsLoaded state) {
    final stats = state.stats;
    final totalKm = (stats['total_km'] as num?)?.toDouble() ?? 42.0;
    final totalTime = (stats['total_time'] as int?) ?? 3600;
    final avgSpeed = (stats['avg_speed'] as num?)?.toDouble() ?? 42.0;
    final checkpoints = (stats['checkpoints'] as int?) ?? 5;

    final hours = totalTime ~/ 3600;
    final minutes = (totalTime % 3600) ~/ 60;
    final timeStr = '${hours}h ${minutes.toString().padLeft(2, '0')}m';

    return Row(
      children: [
        Expanded(child: _statTile('${totalKm.toStringAsFixed(1)}', 'KM TOTALES', Icons.route_outlined, AppColors.primary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statTile(timeStr, 'TIEMPO', Icons.timer_outlined, AppColors.secondary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statTile('$checkpoints', 'CHECKPOINTS', Icons.flag_outlined, AppColors.success)),
      ],
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) {
    return Container(
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
          Text(value,
            style: AppTypography.h2.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          Text(label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRanking(RaidStatsLoaded state) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POSICIONES FINALES',
            style: AppTypography.label.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            state.finalRanking.length > 5 ? 5 : state.finalRanking.length,
            (i) => _buildFinalRankingRow(i, state.finalRanking[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRankingRow(int index, Map<String, dynamic> participant) {
    Color medalColor;
    String medal;
    double medalSize;

    switch (index) {
      case 0:
        medalColor = AppColors.primary;
        medal = '🥇';
        medalSize = 28;
      case 1:
        medalColor = AppColors.textSecondary;
        medal = '🥈';
        medalSize = 24;
      case 2:
        medalColor = const Color(0xFFCD7F32);
        medal = '🥉';
        medalSize = 24;
      default:
        medalColor = AppColors.textMuted;
        medal = '${index + 1}';
        medalSize = 20;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(medal,
              style: TextStyle(fontSize: medalSize),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              participant['user_id']?.toString().substring(0, 8) ?? 'Rider',
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Text(
            '${participant['xp_earned'] ?? 100} XP',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMap() {
    return Container(
      width: double.infinity,
      height: 120,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAPA DE CALOR',
            style: AppTypography.label.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _HeatMapPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(RaidStatsLoaded state) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📸 Captura compartida'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              icon: const Icon(Icons.share_outlined, size: AppSpacing.iconSm),
              label: Text('COMPARTIR', style: AppTypography.button),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                elevation: 0,
              ),
              child: Text('VOLVER', style: AppTypography.button),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simulated heat map painter
class _HeatMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.1, size.height * 0.8),
      Offset(size.width * 0.25, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.3),
      Offset(size.width * 0.55, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.25),
      Offset(size.width * 0.85, size.height * 0.5),
      Offset(size.width * 0.95, size.height * 0.7),
    ];

    // Draw heat circles
    for (final point in points) {
      final gradient = RadialGradient(
        colors: [
          AppColors.primary.withAlpha(60),
          AppColors.primary.withAlpha(10),
          Colors.transparent,
        ],
      );
      final rect = Rect.fromCircle(center: point, radius: 25);
      canvas.drawCircle(
        point, 25,
        Paint()..shader = gradient.createShader(rect),
      );
    }

    // Draw route line
    final routePaint = Paint()
      ..color = AppColors.primary.withAlpha(100)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
