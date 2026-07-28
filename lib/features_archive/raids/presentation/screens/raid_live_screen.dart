/// Raid Live Screen — AsfaltoClub Battle Ride.
/// Monitor surface con mapa en vivo, ranking, speed, alerts TTS simulados.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';
import 'raid_stats_screen.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';

class RaidLiveScreen extends StatefulWidget {
  final String raidId;
  const RaidLiveScreen({super.key, required this.raidId});

  @override
  State<RaidLiveScreen> createState() => _RaidLiveScreenState();
}

class _RaidLiveScreenState extends State<RaidLiveScreen>
    with TickerProviderStateMixin {
  late AnimationController _alertController;
  late Animation<Offset> _alertSlide;
  Timer? _ttsTimer;

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _alertSlide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _alertController, curve: Curves.easeOutBack),
        );
  }

  @override
  void dispose() {
    _alertController.dispose();
    _ttsTimer?.cancel();
    super.dispose();
  }

  void _showAlert(String message) {
    _alertController.forward();
    _ttsTimer?.cancel();
    _ttsTimer = Timer(const Duration(seconds: 3), () {
      _alertController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        if (state is RaidActive) {
          // Trigger alert animation
          if (state.alertMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _showAlert(state.alertMessage!),
            );
          }
          return _buildLiveScreen(state);
        }
        if (state is RaidCompleted || state is RaidStatsLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RaidStatsScreen(raidId: widget.raidId),
              ),
            );
          });
        }
        if (state is RaidError) {
          return Scaffold(
            backgroundColor: AppColors.monitor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Error',
                    style: AppTypography.h2.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: AppColors.monitor,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildLiveScreen(RaidActive state) {
    return Scaffold(
      backgroundColor: AppColors.monitor,
      body: SafeArea(
        child: Stack(
          children: [
            // Full screen map (simulated)
            Positioned.fill(child: _buildMapBackground()),

            // Alert overlay
            if (state.alertMessage != null)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _alertSlide,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: (state.alertColor ?? AppColors.success)
                            .withAlpha(30),
                        borderRadius: AppRadius.mdCircular,
                        border: Border.all(
                          color: (state.alertColor ?? AppColors.success)
                              .withAlpha(120),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (state.alertColor ?? AppColors.success)
                                .withAlpha(60),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.alertMessage!.contains('Peligro')
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            color: state.alertColor ?? AppColors.success,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            state.alertMessage!.toUpperCase(),
                            style: AppTypography.button.copyWith(
                              color: state.alertColor ?? AppColors.success,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Anti-cheat warning bar
            if (state.antiCheatFlags > 0 || state.isFlagged)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: state.isFlagged
                          ? AppColors.error.withAlpha(40)
                          : AppColors.warning.withAlpha(30),
                      borderRadius: AppRadius.mdCircular,
                      border: Border.all(
                        color: (state.isFlagged
                                ? AppColors.error
                                : AppColors.warning)
                            .withAlpha(120),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.isFlagged
                              ? Icons.gpp_bad
                              : Icons.warning_amber_rounded,
                          color: state.isFlagged
                              ? AppColors.error
                              : AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          state.isFlagged
                              ? '🚫 RAID FLAGEADO — XP retenido'
                              : '⚠️ ${state.antiCheatFlags} flag(s) anti-cheat',
                          style: AppTypography.caption.copyWith(
                            color: state.isFlagged
                                ? AppColors.error
                                : AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top bar — speed, heading, distance, elapsed
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(state)),

            // Bottom stats
            Positioned(
              bottom: 100,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: _buildStatsCards(state),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(state),
            ),

            // SOS floating button
            Positioned(
              bottom: 70,
              right: AppSpacing.sm,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SafeModeScreen(raidId: int.tryParse(widget.raidId)),
                    ),
                  );
                },
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha(80),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('SOS', style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    )),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBackground() {
    return CustomPaint(
      painter: _RoadMapPainter(),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildTopBar(RaidActive state) {
    final elapsed = Duration(seconds: state.elapsedSeconds);
    final timeStr =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.monitor,
            AppColors.monitor.withAlpha(200),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Speed
          _buildMetric('${state.speed.round()}', 'KM/H', AppColors.primary),
          // Heading
          _buildMetric(
            'N ${state.elapsedSeconds % 360}°',
            'HEADING',
            AppColors.secondary,
          ),
          // Distance
          _buildMetric(
            '${state.distanceToDest.toStringAsFixed(1)}',
            'KM',
            AppColors.success,
          ),
          // Elapsed
          _buildMetric(timeStr, 'TIEMPO', AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.monoSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color.withAlpha(150),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(RaidActive state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "TÚ" card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.overlay,
            borderRadius: AppRadius.mdCircular,
            border: Border.all(color: AppColors.border.withAlpha(80)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                Icons.speed_outlined,
                '${state.speed.round()}',
                'ACTUAL',
                AppColors.primary,
              ),
              _statItem(
                Icons.route_outlined,
                '${state.distanceToDest.toStringAsFixed(1)}',
                'KM REC',
                AppColors.secondary,
              ),
              _statItem(
                Icons.flag_outlined,
                '${state.checkpointsPassed}',
                'CP',
                AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Ranking card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.overlay,
            borderRadius: AppRadius.mdCircular,
            border: Border.all(color: AppColors.border.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RANKING',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...List.generate(
                state.ranking.length > 5 ? 5 : state.ranking.length,
                (i) => _buildRankingRow(i, state.ranking[i]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: AppSpacing.iconSm),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.monoSmall.copyWith(color: color)),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildRankingRow(int index, Map<String, dynamic> participant) {
    Color medalColor;
    String medal;
    switch (index) {
      case 0:
        medalColor = AppColors.primary;
        medal = '1°';
      case 1:
        medalColor = AppColors.textSecondary;
        medal = '2°';
      case 2:
        medalColor = const Color(0xFFCD7F32);
        medal = '3°';
      default:
        medalColor = AppColors.textMuted;
        medal = '${index + 1}°';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: medalColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: medalColor.withAlpha(60)),
            ),
            child: Center(
              child: Text(
                medal,
                style: AppTypography.caption.copyWith(
                  color: medalColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              participant['user_id']?.toString().substring(0, 8) ?? 'Rider',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${participant['simulated_speed']?.toStringAsFixed(0) ?? '0'} km/h',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(RaidActive state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.monitor.withAlpha(240),
            AppColors.monitor,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Ping button
          _buildActionButton(
            icon: Icons.location_searching,
            label: 'PING',
            color: AppColors.primary,
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📍 Ping enviado a la ubicación'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          // Chat quick
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'CHAT',
            color: AppColors.secondary,
            onTap: () => _showQuickChat(context),
          ),
          // Abandonar
          _buildActionButton(
            icon: Icons.exit_to_app,
            label: 'ABANDONAR',
            color: AppColors.error,
            onTap: () => _confirmAbandon(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(60), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(30),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  void _showQuickChat(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.input,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: controller,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Mensaje rápido...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: AppColors.textMuted),
                      ),
                      onSubmitted: (_) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📨 Mensaje enviado al raid'),
                            backgroundColor: AppColors.secondary,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📨 Mensaje enviado al raid'),
                          backgroundColor: AppColors.secondary,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        title: Text(
          'ABANDONAR RAID',
          style: AppTypography.h3.copyWith(color: AppColors.error),
        ),
        content: Text(
          '¿Seguro que quieres abandonar el raid?',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCELAR',
              style: AppTypography.button.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final userId =
                  Supabase.instance.client.auth.currentUser?.id ?? '';
              context.read<RaidBloc>().add(
                CompleteRaid(
                  raidId: widget.raidId,
                  stats: {'did_not_finish': true, 'xp_earned': 0},
                ),
              );
              Navigator.pop(context);
            },
            child: Text(
              'ABANDONAR',
              style: AppTypography.button.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Road map painter — simulates a dark road map with route line
class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.monitor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0x0800D4FF)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Route line (simulated curvy road)
    final routePaint = Paint()
      ..color = const Color(0x30FF8C00)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.85)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.7,
        size.width * 0.5,
        size.height * 0.5,
        size.width * 0.7,
        size.height * 0.4,
      )
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.35,
        size.width * 0.85,
        size.height * 0.25,
        size.width * 0.9,
        size.height * 0.15,
      );
    canvas.drawPath(path, routePaint);

    // Start point
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.85),
      6,
      Paint()..color = AppColors.success,
    );

    // End point
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.15),
      6,
      Paint()..color = AppColors.primary,
    );

    // Participant dots (simulated)
    final dotPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.55),
      5,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.45),
      5,
      Paint()..color = AppColors.secondary.withAlpha(150),
    );
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.65),
      5,
      Paint()..color = AppColors.secondary.withAlpha(100),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
