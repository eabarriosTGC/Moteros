/// Leaderboard Screen — top riders by XP, con clan tag.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../widgets/xp_progress_card.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String? username;
  final int level;
  final int totalXp;
  final int raidsCompleted;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    this.username,
    required this.level,
    required this.totalXp,
    this.raidsCompleted = 0,
  });
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadLeaderboard();
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Leaderboard: top 50 by total_xp with user info
      final isWeekly = _tabController.index == 1;
      final resp = await Supabase.instance.client
          .from(isWeekly ? 'leaderboard_snapshots' : 'user_xp')
          .select(isWeekly
              ? 'user_id, metric_value, rank'
              : '*, users!inner(username)')
          .order(isWeekly ? 'rank' : 'total_xp', ascending: true)
          .limit(50);

      List<LeaderboardEntry> entries;
      if (isWeekly) {
        entries = (resp as List).map((row) => LeaderboardEntry(
          rank: (row['rank'] as int?) ?? 0,
          userId: row['user_id'] as String,
          totalXp: (row['metric_value'] as int?) ?? 0,
          level: 0,
        )).toList();
      } else {
        entries = (resp as List).asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          final totalXp = (row['total_xp'] as int?) ?? 0;
          final userMap = row['users'] as Map<String, dynamic>?;
          return LeaderboardEntry(
            rank: idx + 1,
            userId: row['user_id'] as String,
            username: userMap?['username'] as String?,
            level: (row['level'] as int?) ?? xpToLevel(totalXp),
            totalXp: totalXp,
            raidsCompleted: (row['raids_completed'] as int?) ?? 0,
          );
        }).toList();
      }

      setState(() { _entries = entries; _loading = false; });
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
            const Icon(AppIcons.medal, color: AppColors.secondary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('RANKING', style: AppTypography.h2.copyWith(color: AppColors.secondary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'GENERAL'),
            Tab(text: 'SEMANAL'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : _error != null ? _buildError() : _buildList(),
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
              onPressed: _loadLeaderboard,
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

  Widget _buildList() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.medal, size: 64, color: AppColors.textMuted.withAlpha(60)),
            const SizedBox(height: AppSpacing.md),
            Text('Sin datos aún', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppColors.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _entries.length,
        itemBuilder: (_, i) => _buildEntry(_entries[i]),
      ),
    );
  }

  Widget _buildEntry(LeaderboardEntry entry) {
    final isMe = entry.userId == Supabase.instance.client.auth.currentUser?.id;
    Color rankColor;
    IconData? rankIcon;
    switch (entry.rank) {
      case 1: rankColor = const Color(0xFFFFD700); rankIcon = AppIcons.medal;
      case 2: rankColor = const Color(0xFFC0C0C0); rankIcon = AppIcons.medal;
      case 3: rankColor = const Color(0xFFCD7F32); rankIcon = AppIcons.medal;
      default: rankColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withAlpha(10) : AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: isMe ? AppColors.primary.withAlpha(40) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 22)
                : Text('${entry.rank}',
                    textAlign: TextAlign.center,
                    style: AppTypography.h3.copyWith(color: rankColor)),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary.withAlpha(25) : AppColors.input,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: rankColor.withAlpha(60)),
            ),
            child: Icon(Icons.person_outline, color: rankColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Name + level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username ?? entry.userId.substring(0, 8),
                  style: AppTypography.body.copyWith(
                    color: isMe ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.level > 0)
                  Text('Nv. ${entry.level} · ${entry.raidsCompleted} raids',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          // XP
          Text('${entry.totalXp} XP',
            style: AppTypography.h3.copyWith(
              color: isMe ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
