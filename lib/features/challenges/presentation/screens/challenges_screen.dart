/// Challenges — "Desafíos del Asfalto" RPG-style.
/// Road timeline + fuel tank progress + confetti on completion.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/challenges_bloc.dart';
import '../bloc/challenges_event.dart';
import '../bloc/challenges_state.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with TickerProviderStateMixin {
  late AnimationController _pumpController;
  late Animation<double> _pumpAnim;
  bool _confettiShown = false;

  @override
  void initState() {
    super.initState();
    _pumpController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pumpAnim = CurvedAnimation(parent: _pumpController, curve: Curves.elasticInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChallengesBloc>().add(LoadChallenges());
    });
  }

  @override
  void dispose() {
    _pumpController.dispose();
    super.dispose();
  }

  void _triggerPump() {
    _pumpController.forward().then((_) => _pumpController.reverse());
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChallengesBloc, ChallengesState>(
      builder: (context, state) {
        if (state is ChallengesLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state is ChallengesLoaded) {
          // Trigger confetti once when all completed
          if (state.showConfetti && !_confettiShown) {
            _confettiShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _showConfetti());
          }
          return _buildScreen(state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildScreen(ChallengesLoaded state) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desafíos del Asfalto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fuel Tank Progress ──
              _buildFuelTank(state),
              const SizedBox(height: AppSpacing.lg),
              // ── Subtitle ──
              Text(
                'Completa los retos para llenar tu tanque\ny convertirte en Miembro Oficial.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              // ── Road Timeline ──
              ...state.challenges.asMap().entries.map((entry) =>
                _buildRoadStep(entry.value, entry.key, state.challenges.length)),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelTank(ChallengesLoaded state) {
    final pct = (state.progress * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppGradients.cardHighlight,
        borderRadius: AppRadius.lgCircular,
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(AppIcons.fuel, color: AppColors.primary, size: AppSpacing.iconLg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TANQUE DE GASOLINA', style: AppTypography.label.copyWith(color: AppColors.textMuted)),
            Text('$pct% · ${state.completedCount}/${state.totalCount} retos', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // Animated fuel bar
        AnimatedBuilder(
          animation: _pumpAnim,
          builder: (context, child) {
            final displayProgress = state.progress + (_pumpAnim.value * 0.02);
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(children: [
                Container(height: 20, decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(6),
                )),
                FractionallySizedBox(
                  widthFactor: displayProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.primary,
                        AppColors.primaryLight,
                        state.progress >= 1 ? AppColors.success : AppColors.primaryLight,
                      ]),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(40), blurRadius: 8)],
                    ),
                    child: Center(child: Text('$pct%', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800))),
                  ),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildRoadStep(ChallengeEntity challenge, int index, int total) {
    final isCompleted = challenge.status == ChallengeStatus.completed;
    final isAvailable = challenge.status == ChallengeStatus.available;
    final isLast = index == total - 1;
    final color = isCompleted ? AppColors.success : (isAvailable ? AppColors.primary : AppColors.textMuted);
    final label = isCompleted ? 'Completado' : (isAvailable ? 'Disponible' : 'Bloqueado');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Road line + milestone
          SizedBox(
            width: 48,
            child: Column(children: [
              // Milestone circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: isCompleted ? 32 : 28,
                height: isCompleted ? 32 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppColors.success : (isAvailable ? AppColors.card : AppColors.input),
                  border: Border.all(color: color, width: isCompleted ? 0 : 2.5),
                  boxShadow: isAvailable
                      ? [BoxShadow(color: AppColors.primary.withAlpha(50), blurRadius: 10, spreadRadius: 2)]
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.black, size: 16)
                    : Center(child: Text('${index + 1}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
              ),
              // Road connector line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isCompleted ? AppColors.success.withAlpha(120) : AppColors.border,
                          AppColors.border,
                        ],
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Challenge card
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.success.withAlpha(8) : AppColors.card,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: color.withAlpha(isCompleted ? 80 : 30), width: 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(challenge.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(challenge.title, style: AppTypography.body.copyWith(
                    color: isCompleted ? AppColors.success : AppColors.textPrimary,
                    fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                  ))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(challenge.description, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                // Action button for available challenges
                if (isAvailable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _triggerPump();
                        context.read<ChallengesBloc>().add(CompleteChallenge(challengeId: challenge.id));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
                        textStyle: AppTypography.buttonSmall,
                      ),
                      child: const Text('Completar reto'),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfetti() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => _ConfettiDialog(),
    );
  }
}

/// Simple confetti celebration dialog
class _ConfettiDialog extends StatefulWidget {
  @override
  State<_ConfettiDialog> createState() => _ConfettiDialogState();
}

class _ConfettiDialogState extends State<_ConfettiDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _particles = List.generate(30, (i) => _Particle(
    x: Random().nextDouble(),
    y: -0.2 - Random().nextDouble() * 0.3,
    speed: 0.3 + Random().nextDouble() * 0.5,
    drift: (Random().nextDouble() - 0.5) * 0.3,
    size: 6 + Random().nextDouble() * 8,
    color: [AppColors.primary, AppColors.secondary, AppColors.success, AppColors.info, Colors.white][i % 5],
    rotation: Random().nextDouble() * 6.28,
    rotSpeed: (Random().nextDouble() - 0.5) * 0.1,
  ));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(_particles, _controller.value),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: AppColors.secondary),
            const SizedBox(height: 16),
            const Text('¡FELICIDADES!', style: AppTypography.displayMedium),
            const SizedBox(height: 8),
            Text('Completaste todos los retos.\n¡Ya eres Miembro Oficial!',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                minimumSize: const Size(200, 48),
              ),
              child: const Text('¡A rodar!'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double x, y, speed, drift, size;
  final Color color;
  final double rotation, rotSpeed;
  _Particle({required this.x, required this.y, required this.speed, required this.drift, required this.size, required this.color, required this.rotation, required this.rotSpeed});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) * size.height;
      if (y < -20 || y > size.height + 20) continue;
      final x = (p.x + sin(progress * 10 + p.drift * 20) * p.drift) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotSpeed);
      final paint = Paint()..color = p.color.withAlpha((255 * (1 - progress * 0.3)).round());
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
