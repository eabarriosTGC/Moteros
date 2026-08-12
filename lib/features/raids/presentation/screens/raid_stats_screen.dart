/// Raid Stats Screen — AsfaltoClub Battle Ride.
/// Refactored to load directly from Supabase (simplified raid bloc doesn't include LoadRaidStats).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';

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

  Map<String, dynamic>? _raid;
  Map<String, dynamic>? _myResult;
  List<Map<String, dynamic>> _finalRanking = [];
  int _earnedXp = 0;
  bool _isLoading = true;
  String? _error;

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    try {
      final client = Supabase.instance.client;

      final results = await Future.wait([
        client.from('raids').select().eq('id', int.tryParse(widget.raidId) ?? -1).single(),
        client.from('raid_results').select().eq('raid_id', int.tryParse(widget.raidId) ?? -1).order('finish_time', ascending: true),
      ]);

      final raid = results[0] as Map<String, dynamic>;
      final resultsList = (results[1] as List).cast<Map<String, dynamic>>();

      final sorted = List<Map<String, dynamic>>.from(resultsList);
      sorted.sort((a, b) => ((a['position'] as int?) ?? 999)
          .compareTo((b['position'] as int?) ?? 999));

      final xp = resultsList.fold<int>(0, (sum, r) => sum + ((r['xp_earned'] as int?) ?? 0));

      if (mounted) {
        setState(() {
          _raid = raid;
          _myResult = resultsList.isNotEmpty ? resultsList.first : <String, dynamic>{};
          _finalRanking = sorted;
          _earnedXp = xp;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
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
              Text(_error!, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }
    if (!_xpAnimated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _xpController.forward();
          _xpAnimated = true;
          HapticFeedback.mediumImpact();
        }
      });
    }
    return _buildStatsScreen();
  }

  Widget _buildStatsScreen() {
    final displayXp = (_xpAnimation.value * _earnedXp).round();

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
                _raid?['description'] ?? 'Raid',
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
              _buildStatsGrid(),
              const SizedBox(height: AppSpacing.xl),

              // Final ranking
              _buildFinalRanking(),
              const SizedBox(height: AppSpacing.xl),

              // Action buttons
              _buildActions(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final totalKm = (_myResult?['total_km'] as num?)?.toDouble() ?? 42.0;
    final totalTime = (_myResult?['total_time'] as int?) ?? 3600;
    final checkpoints = (_myResult?['checkpoints'] as int?) ?? 5;

    final hours = totalTime ~/ 3600;
    final minutes = (totalTime % 3600) ~/ 60;
    final timeStr = '${hours}h ${minutes.toString().padLeft(2, '0')}m';

    return Row(
      children: [
        Expanded(child: _statTile(totalKm.toStringAsFixed(1), 'KM TOTALES', Icons.route_outlined, AppColors.primary)),
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
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
            style: AppTypography.monoSmall.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          Text(label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRanking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RANKING FINAL',
          style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._finalRanking.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.smCircular,
              border: Border.all(color: idx < 3 ? AppColors.primary.withAlpha(30) : AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: idx == 0 ? AppColors.primary : idx == 1 ? AppColors.secondary : idx == 2 ? AppColors.success : AppColors.input,
                  ),
                  child: Center(
                    child: Text('${idx + 1}',
                      style: AppTypography.caption.copyWith(
                        color: idx < 3 ? AppColors.textOnAmber : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Participante ${idx + 1}',
                    style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                Text('${row['finish_time'] as int? ?? 0}s',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('VOLVER'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAmber,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        ),
      ),
    );
  }
}
