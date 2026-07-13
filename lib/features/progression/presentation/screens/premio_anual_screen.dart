/// Premio Anual Screen — 5 categories with trophy icons and top 3 lists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/leaderboard_bloc.dart';
import '../bloc/leaderboard_event.dart';
import '../bloc/leaderboard_state.dart';

class PremioAnualScreen extends StatefulWidget {
  const PremioAnualScreen({super.key});

  @override
  State<PremioAnualScreen> createState() => _PremioAnualScreenState();
}

class _PremioAnualScreenState extends State<PremioAnualScreen> {
  int _selectedYear = DateTime.now().year;
  final List<int> _years = [2024, 2025, 2026];

  // Hardcoded categories for premio anual
  static const _categories = [
    ('Más KM', '🏍️', 'km'),
    ('Más lugares visitados', '🗺️', 'lugares'),
    ('Mejor presidente', '👑', 'presidente'),
    ('Más retos', '🏆', 'retos'),
    ('Mejor rookie', '🌟', 'rookie'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<LeaderboardBloc>().add(const LoadPremioAnualCandidates());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            const Text('Premio Anual', style: TextStyle(color: AppColors.textPrimary)),
            const Spacer(),
            // Year selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) => setState(() => _selectedYear = v ?? 2026),
                ),
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          final candidates = state is LeaderboardLoaded ? state.premioCandidates : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('PREMIO ANUAL $_selectedYear',
                        style: AppTypography.h1.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Celebrando a los mejores moteros del año',
                        style: AppTypography.body.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Category cards
                ..._categories.map((cat) => _buildCategoryCard(
                      cat.$1,
                      cat.$2,
                      cat.$3,
                      candidates,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    String icon,
    String key,
    List<Map<String, dynamic>>? candidates,
  ) {
    // Filter candidates for this category
    final top3 = candidates
            ?.where((c) => (c['category'] as String? ?? '') == key)
            .take(3)
            .toList() ??
        [];

    final trophyEmojis = ['🥇', '🥈', '🥉'];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Top 3 list
          if (top3.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text('Sin candidatos aún',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ] else ...[
            ...top3.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final name = c['username'] as String? ??
                  (c['user_id'] as String?)?.substring(0, 8) ??
                  'Anónimo';
              final value = c['metric_value'] as num? ?? 0;
              final userId = c['user_id'] as String?;
              final isMe = userId == Supabase.instance.client.auth.currentUser?.id;

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary.withAlpha(8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isMe ? AppColors.primary.withAlpha(30) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(trophyEmojis[i], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(name,
                        style: AppTypography.bodySmall.copyWith(
                          color: isMe ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text('${value.toStringAsFixed(0)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
