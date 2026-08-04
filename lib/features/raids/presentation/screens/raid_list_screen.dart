/// Raid List Screen — AsfaltoClub Battle Ride.
/// Tab entry point showing all available raids grouped by status.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';
import '../widgets/raid_join_sheet.dart';
import 'create_raid_screen.dart';
import 'raid_stats_screen.dart';

class RaidListScreen extends StatefulWidget {
  const RaidListScreen({super.key});

  @override
  State<RaidListScreen> createState() => _RaidListScreenState();
}

class _RaidListScreenState extends State<RaidListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RaidBloc>().add(const LoadRaids());
    });
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
            Icon(AppIcons.raid, color: AppColors.primary, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'RAIDS',
              style: AppTypography.h2.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<RaidBloc>().add(const LoadRaids());
            },
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: BlocBuilder<RaidBloc, RaidState>(
        builder: (context, state) {
          if (state is RaidLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is RaidsLoaded) {
            return _buildRaidsList(state.raids);
          }
          if (state is RaidError) {
            return _buildError(state.message);
          }
          // Don't interfere with detail screens (RaidLobby, RaidActive, etc.)
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRaidScreen()),
          ).then((_) => context.read<RaidBloc>().add(const LoadRaids()));
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnAmber,
        icon: const Icon(Icons.add),
        label: const Text(
          'CREAR RAID',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildRaidsList(List<Map<String, dynamic>> raids) {
    if (raids.isEmpty) {
      return _buildEmptyState();
    }

    final lobbyRaids = raids.where((r) => r['status'] == 'lobby').toList();
    final activeRaids = raids.where((r) => r['status'] == 'active').toList();
    final completedRaids = raids
        .where((r) => r['status'] == 'completed')
        .toList();
    final otherRaids = raids
        .where((r) => !['lobby', 'active', 'completed'].contains(r['status']))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<RaidBloc>().add(const LoadRaids());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          100,
        ),
        children: [
          if (activeRaids.isNotEmpty) ...[
            _sectionHeader('EN VIVO', AppColors.secondary),
            const SizedBox(height: AppSpacing.sm),
            ...activeRaids.map((r) => _buildRaidCard(r, 'active')),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (lobbyRaids.isNotEmpty) ...[
            _sectionHeader('LOBBY', AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            ...lobbyRaids.map((r) => _buildRaidCard(r, 'lobby')),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (completedRaids.isNotEmpty) ...[
            _sectionHeader('COMPLETADOS', AppColors.success),
            const SizedBox(height: AppSpacing.sm),
            ...completedRaids
                .take(5)
                .map((r) => _buildRaidCard(r, 'completed')),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (otherRaids.isNotEmpty) ...[
            _sectionHeader('OTROS', AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            ...otherRaids.map((r) => _buildRaidCard(r, 'other')),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.raid,
              size: 80,
              color: AppColors.textMuted.withAlpha(60),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'SIN RAIDS AÚN',
              style: AppTypography.h2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Crea tu primera raid y conquista la ruta con tu clan',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRaidScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'CREAR PRIMER RAID',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular,
                ),
              ),
            ),
          ],
        ),
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
            Icon(AppIcons.error, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'ERROR AL CARGAR',
              style: AppTypography.h2.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.read<RaidBloc>().add(const LoadRaids()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular,
                ),
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.label.copyWith(
              color: color,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaidCard(Map<String, dynamic> raid, String category) {
    final title = raid['description'] ?? 'Raid sin nombre';
    final gameMode = raid['mode'] ?? 'Free Ride';
    final dateTime = raid['scheduled_at'];
    final participantCount = (raid['raid_participants'] as List?)?.length ?? 0;
    final isPublic = raid['is_public'] as bool? ?? true;
    final raidId = raid['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _openRaid(raidId, category),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: _statusColor(category).withAlpha(30)),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 3,
              height: 48,
              decoration: BoxDecoration(
                color: _statusColor(category),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor(category).withAlpha(15),
                borderRadius: AppRadius.mdCircular,
              ),
              child: Icon(
                category == 'active'
                    ? Icons.play_circle_outline
                    : category == 'completed'
                    ? AppIcons.completed
                    : AppIcons.raid,
                color: _statusColor(category),
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _infoChip(gameMode.toUpperCase(), AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      _infoChip(_formatDate(dateTime), AppColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
            // Participant count + public/private
            Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$participantCount',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Icon(
                  isPublic ? Icons.public : Icons.lock,
                  size: 14,
                  color: isPublic ? AppColors.success : AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(String category) {
    switch (category) {
      case 'active':
        return AppColors.secondary;
      case 'lobby':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  void _openRaid(String raidId, String category) {
    if (raidId.isEmpty) return;
    HapticFeedback.lightImpact();

    // Completed raids have stats; lobby/active open the join sheet (F-M8)
    if (category == 'completed') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RaidStatsScreen(raidId: raidId)),
      ).then((_) => context.read<RaidBloc>().add(const LoadRaids()));
      return;
    }
    final state = context.read<RaidBloc>().state;
    if (state is! RaidsLoaded) return;
    for (final r in state.raids) {
      if (r['id'].toString() == raidId) {
        showRaidJoinSheet(context, r);
        return;
      }
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString().substring(0, 10);
    }
  }
}
