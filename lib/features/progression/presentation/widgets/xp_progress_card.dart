/// XpProgressCard — Reusable widget showing level, XP bar, streak, coins & shop.
/// Fetches data directly from Supabase (no BLoC needed for read-only display).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';

/// Calculated XP progression data
class XpData {
  final int level;
  final int totalXp;
  final int xpForCurrentLevel;
  final int xpForNextLevel;
  final int currentStreak;
  final int longestStreak;
  final int raidsCompleted;
  final int checkpointsCaptured;
  final double kmTraveled;
  final int coins;

  const XpData({
    required this.level,
    required this.totalXp,
    required this.xpForCurrentLevel,
    required this.xpForNextLevel,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.raidsCompleted = 0,
    this.checkpointsCaptured = 0,
    this.kmTraveled = 0.0,
    this.coins = 0,
  });

  double get progressFraction {
    final range = xpForNextLevel - xpForCurrentLevel;
    if (range <= 0) return 1.0;
    return ((totalXp - xpForCurrentLevel) / range).clamp(0.0, 1.0);
  }

  int get xpToNext => xpForNextLevel - totalXp;
}

/// Helper: level = floor(sqrt(total_xp / 100)) + 1
int xpToLevel(int totalXp) =>
    (totalXp <= 0) ? 1 : sqrt((totalXp ~/ 100).toDouble()).floor() + 1;

int xpForLevel(int level) => 100 * (level - 1) * (level - 1);
int xpForNextLevel(int level) => 100 * level * level;

/// Fetch XpData for a given user from Supabase.
Future<XpData> fetchXpData(String userId) async {
  final resp = await Supabase.instance.client
      .from('user_xp')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (resp == null) {
    return const XpData(level: 1, totalXp: 0, xpForCurrentLevel: 0, xpForNextLevel: 100);
  }

  final totalXp = (resp['total_xp'] as int?) ?? 0;
  final level = (resp['level'] as int?) ?? xpToLevel(totalXp);

  return XpData(
    level: level,
    totalXp: totalXp,
    xpForCurrentLevel: xpForLevel(level),
    xpForNextLevel: xpForNextLevel(level),
    currentStreak: (resp['current_streak'] as int?) ?? 0,
    longestStreak: (resp['longest_streak'] as int?) ?? 0,
    raidsCompleted: (resp['raids_completed'] as int?) ?? 0,
    checkpointsCaptured: (resp['checkpoints_captured'] as int?) ?? 0,
    kmTraveled: (resp['km_traveled'] as num?)?.toDouble() ?? 0.0,
    coins: (resp['coins'] as int?) ?? 0,
  );
}

class XpProgressCard extends StatelessWidget {
  final XpData data;
  final VoidCallback? onAchievementsTap;
  final VoidCallback? onLeaderboardTap;
  final VoidCallback? onShopTap;

  const XpProgressCard({
    super.key,
    required this.data,
    this.onAchievementsTap,
    this.onLeaderboardTap,
    this.onShopTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Column(
        children: [
          // Level + XP row
          Row(
            children: [
              _levelBadge(),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _xpInfo()),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // XP progress bar
          _xpBar(),
          const SizedBox(height: AppSpacing.sm),
          // Stats row
          _statsRow(),
          const SizedBox(height: AppSpacing.sm),
          // Coins + TIENDA button
          _coinsRow(),
          if (onAchievementsTap != null || onLeaderboardTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _actionsRow(),
          ],
        ],
      ),
    );
  }

  Widget _coinsRow() {
    return Row(
      children: [
        Icon(Icons.monetization_on, color: AppColors.primary, size: 20),
        const SizedBox(width: 4),
        Text('${data.coins}',
          style: AppTypography.h3.copyWith(color: AppColors.primary)),
        const Spacer(),
        _actionBtn(Icons.store_rounded, 'TIENDA', AppColors.primary, onShopTap),
      ],
    );
  }

  Widget _levelBadge() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(
          color: AppColors.primaryGlow,
          blurRadius: 12, spreadRadius: 2,
        )],
      ),
      child: Center(
        child: Text('${data.level}',
          style: AppTypography.h1.copyWith(
            color: AppColors.textOnAmber,
            fontSize: 28,
          ),
        ),
      ),
    );
  }

  Widget _xpInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NIVEL ${data.level}',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text('${data.totalXp} XP · ${data.xpToNext} XP al nivel ${data.level + 1}',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _xpBar() {
    final fraction = data.progressFraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.trackInactive,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(fraction * 100).round()}%',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statItem(AppIcons.milestone, '${data.raidsCompleted}', 'Raids'),
        _statItem(AppIcons.timer, '${data.checkpointsCaptured}', 'Checkpoints'),
        _statItem(AppIcons.route, '${data.kmTraveled.round()} km', 'Recorridos'),
        _statItem(Icons.local_fire_department, '${data.currentStreak}', 'Racha'),
      ],
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: AppSpacing.iconSm),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.body.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700,
          )),
          Text(label, style: AppTypography.caption.copyWith(
            color: AppColors.textMuted, fontSize: 10,
          )),
        ],
      ),
    );
  }

  Widget _actionsRow() {
    return Row(
      children: [
        if (onAchievementsTap != null)
          Expanded(
            child: TextButton.icon(
              onPressed: onAchievementsTap,
              icon: const Icon(AppIcons.trophy, size: 18),
              label: const Text('LOGROS'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        if (onLeaderboardTap != null)
          Expanded(
            child: TextButton.icon(
              onPressed: onLeaderboardTap,
              icon: const Icon(AppIcons.medal, size: 18),
              label: const Text('RANKING'),
              style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
            ),
          ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback? onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      style: TextButton.styleFrom(foregroundColor: color),
    );
  }
}
