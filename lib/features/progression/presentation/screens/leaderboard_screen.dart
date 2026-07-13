/// Leaderboard Screen — full redesigned leaderboard with filter tabs, period picker, and table.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/leaderboard_bloc.dart';
import '../bloc/leaderboard_event.dart';
import '../bloc/leaderboard_state.dart';
import 'premio_anual_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _period = 'monthly';

  final _scopes = [
    ('nacional', 'Nacional 🇨🇴'),
    ('club', 'Por club 🏁'),
    ('departamento', 'Por departamento 📍'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _scopes.length, vsync: this);
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

  void _loadLeaderboard() {
    final scope = _scopes[_tabController.index].$1;
    context.read<LeaderboardBloc>().add(LoadLeaderboard(
          period: _period,
          scope: scope,
        ));
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
        actions: [
          // Premio Anual button
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremioAnualScreen()),
            ),
            icon: const Icon(Icons.emoji_events, color: AppColors.primary, size: 18),
            label: Text('Premio Anual',
              style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Scope tabs
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.secondary,
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: AppTypography.label,
                tabs: _scopes.map((s) => Tab(text: s.$2)).toList(),
              ),
              // Period picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    _periodChip('monthly', 'Este mes'),
                    const SizedBox(width: AppSpacing.sm),
                    _periodChip('yearly', 'Este año'),
                    const SizedBox(width: AppSpacing.sm),
                    _periodChip('all_time', 'Histórico'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          if (state is LeaderboardLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
          }
          if (state is LeaderboardLoaded) {
            return _buildLeaderboard(state);
          }
          if (state is LeaderboardError) {
            return _buildError(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () {
        setState(() => _period = value);
        _loadLeaderboard();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? AppColors.secondaryLight : AppColors.border,
          ),
        ),
        child: Text(label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.textOnAmber : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(LeaderboardLoaded state) {
    final entries = state.entries;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.medal, size: 64, color: AppColors.textMuted.withAlpha(60)),
            const SizedBox(height: AppSpacing.md),
            Text('Sin datos aún', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text('Sé el primero en aparecer en el ranking',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadLeaderboard(),
      color: AppColors.secondary,
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 32, child: Text('#', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: Text('MOTERO', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(child: Text('CLUB', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(child: Text('KM', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.right)),
                Expanded(child: Text('PTS', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Table rows
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
              itemCount: entries.length,
              itemBuilder: (_, i) => _buildEntryRow(entries[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(Map<String, dynamic> entry, int index) {
    final rank = (entry['rank'] as int?) ?? index + 1;
    final username = entry['username'] as String? ?? entry['user_id']?.toString().substring(0, 8) ?? 'Anónimo';
    final clubTag = entry['club_tag'] as String?;
    final puntos = (entry['puntos'] as num?)?.toDouble() ?? 0;
    final km = (entry['km'] as num?)?.toDouble() ?? 0;
    final avatarUrl = entry['avatar_url'] as String?;
    final isMe = entry['user_id'] == Supabase.instance.client.auth.currentUser?.id;

    // Top 3 styling
    Color? rankColor;
    String? rankEmoji;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700);
        rankEmoji = '🥇';
      case 2:
        rankColor = const Color(0xFFC0C0C0);
        rankEmoji = '🥈';
      case 3:
        rankColor = const Color(0xFFCD7F32);
        rankEmoji = '🥉';
      default:
        rankColor = null;
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withAlpha(8)
            : rankColor != null
                ? rankColor.withAlpha(8)
                : AppColors.surface,
        borderRadius: AppRadius.smCircular,
        border: Border.all(
          color: isMe
              ? AppColors.primary.withAlpha(40)
              : rankColor != null
                  ? rankColor.withAlpha(40)
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: rankEmoji != null
                ? Text(rankEmoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Avatar
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: rankColor?.withAlpha(80) ?? AppColors.border),
            ),
            child: avatarUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(avatarUrl, fit: BoxFit.cover),
                  )
                : Icon(Icons.person_outline, size: 18,
                    color: rankColor ?? AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Name
          Expanded(
            flex: 2,
            child: Text(username,
              style: AppTypography.bodySmall.copyWith(
                color: isMe ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          // Club tag
          Expanded(
            child: clubTag != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('[${clubTag.toUpperCase()}]',
                      style: AppTypography.caption.copyWith(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // KM
          SizedBox(
            width: 48,
            child: Text('${km.toStringAsFixed(0)}',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Puntos
          SizedBox(
            width: 40,
            child: Text('${puntos.toStringAsFixed(0)}',
              style: AppTypography.caption.copyWith(
                color: isMe ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
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
            Text(message, style: AppTypography.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
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
}
