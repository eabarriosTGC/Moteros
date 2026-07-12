/// Achievements Screen — 17 logros RPG con estado desbloqueado/bloqueado.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';

class AchievementModel {
  final int id;
  final String name;
  final String icon;
  final String description;
  final int xpReward;
  final String category;
  final bool unlocked;
  final DateTime? earnedAt;

  const AchievementModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.xpReward,
    required this.category,
    this.unlocked = false,
    this.earnedAt,
  });

  bool get locked => !unlocked;
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<AchievementModel> _achievements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() { _loading = false; _error = 'No autenticado'; });
        return;
      }

      // Fetch all achievements + user's unlocked ones separately
      final allResp = await Supabase.instance.client
          .from('achievements')
          .select()
          .order('sort_order');

      final userAchResp = await Supabase.instance.client
          .from('user_achievements')
          .select('achievement_id, earned_at')
          .eq('user_id', userId);

      final earnedSet = <int>{};
      final earnedDates = <int, DateTime>{};
      for (final row in (userAchResp as List)) {
        final aid = row['achievement_id'] as int;
        earnedSet.add(aid);
        earnedDates[aid] = DateTime.parse(row['earned_at'] as String);
      }

      final achievements = (allResp as List).map((row) {
        final id = row['id'] as int;
        return AchievementModel(
          id: id,
          name: row['name'] as String,
          icon: row['icon'] as String? ?? '🏆',
          description: row['description'] as String? ?? '',
          xpReward: (row['xp_reward'] as int?) ?? 0,
          category: row['category'] as String? ?? 'general',
          unlocked: earnedSet.contains(id),
          earnedAt: earnedDates[id],
        );
      }).toList();

      setState(() { _achievements = achievements; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(AppIcons.trophy, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('LOGROS', style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
            onPressed: _loadAchievements,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildGrid(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.error, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error al cargar', style: AppTypography.h2.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTypography.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadAchievements,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final unlocked = _achievements.where((a) => a.unlocked).length;
    return RefreshIndicator(
      onRefresh: _loadAchievements,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Summary header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: AppColors.primary.withAlpha(30)),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.trophy, color: AppColors.primary, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Text('$unlocked/${_achievements.length}', style: AppTypography.h2.copyWith(color: AppColors.primary)),
                  const SizedBox(width: AppSpacing.sm),
                  Text('logros desbloqueados', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          // Categories
          ..._buildCategorySection('🏍️', 'RAIDS', _achievements.where((a) => a.category == 'raids').toList()),
          ..._buildCategorySection('⚔️', 'CLANES', _achievements.where((a) => a.category == 'clans').toList()),
          ..._buildCategorySection('📍', 'CHECKPOINTS', _achievements.where((a) => a.category == 'checkpoints').toList()),
          ..._buildCategorySection('🌟', 'GENERAL', _achievements.where((a) => a.category == 'general').toList()),
          ..._buildCategorySection('👥', 'SOCIAL', _achievements.where((a) => a.category == 'social').toList()),
          ..._buildCategorySection('💎', 'MEMBRESÍA', _achievements.where((a) => a.category == 'membership').toList()),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySection(String emoji, String title, List<AchievementModel> items) {
    if (items.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              Text('$emoji ', style: const TextStyle(fontSize: 16)),
              Text(title, style: AppTypography.label.copyWith(
                color: AppColors.textMuted, letterSpacing: 1.5,
              )),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => _achievementCard(items[i]),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Widget _achievementCard(AchievementModel ach) {
    final unlocked = ach.unlocked;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.surface : AppColors.surface.withAlpha(120),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: unlocked
              ? AppColors.primary.withAlpha(50)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Stack(
            children: [
              Text(ach.icon, style: const TextStyle(fontSize: 32)),
              if (!unlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withAlpha(140),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(ach.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(ach.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: unlocked ? AppColors.textSecondary : AppColors.textDisabled,
              fontSize: 10,
            ),
          ),
          if (unlocked) ...[
            const SizedBox(height: 4),
            Text('+${ach.xpReward} XP',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
