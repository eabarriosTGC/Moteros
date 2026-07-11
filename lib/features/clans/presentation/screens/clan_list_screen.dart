/// Clan List Screen — AsfaltoClub Battle Ride.
/// Lista de todos los clanes disponibles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/clan_bloc.dart';
import '../bloc/clan_event.dart';
import '../bloc/clan_state.dart';
import 'clan_screen.dart';
import 'create_clan_screen.dart';

class ClanListScreen extends StatefulWidget {
  const ClanListScreen({super.key});

  @override
  State<ClanListScreen> createState() => _ClanListScreenState();
}

class _ClanListScreenState extends State<ClanListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClanBloc>().add(LoadClans());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClanBloc, ClanState>(
      builder: (context, state) {
        if (state is ClanLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is ClansLoaded) {
          return _buildList(state.clans);
        }
        if (state is ClanError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error al cargar clanes',
                    style: AppTypography.h2.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(state.message,
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => context.read<ClanBloc>().add(LoadClans()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnAmber,
                    ),
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          );
        }
        // ClanInitial — trigger load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<ClanBloc>().add(LoadClans());
        });
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: Text('Cargando...', style: TextStyle(color: AppColors.textMuted))),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text('CLANES', style: AppTypography.h2.copyWith(color: AppColors.primary)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClanScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> clans) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: clans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, color: AppColors.textMuted.withAlpha(80), size: 64),
                  const SizedBox(height: AppSpacing.md),
                  Text('No hay clanes aún',
                    style: AppTypography.h2.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('¡Crea el primer clan!',
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: AppSpacing.screenPadding,
              itemCount: clans.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final clan = clans[index];
                final tag = (clan['tag'] as String? ?? '???').toUpperCase();
                final name = clan['name'] as String? ?? 'SIN NOMBRE';
                final memberCount = (clan['clan_members'] as List?)?.length ?? 0;
                final isPublic = clan['is_public'] == true;

                return _ClanCard(
                  name: name,
                  tag: tag,
                  memberCount: memberCount,
                  isPublic: isPublic,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClanScreen(clanId: clan['id'] as String),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClanScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnAmber,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ClanCard extends StatelessWidget {
  final String name;
  final String tag;
  final int memberCount;
  final bool isPublic;
  final VoidCallback onTap;

  const _ClanCard({
    required this.name,
    required this.tag,
    required this.memberCount,
    required this.isPublic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.primary.withAlpha(60), width: 1.5),
              ),
              child: Center(
                child: Text(tag.substring(0, tag.length > 2 ? 2 : tag.length),
                  style: AppTypography.monoSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$memberCount miembros',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        isPublic ? Icons.public_outlined : Icons.lock_outlined,
                        size: 14, color: isPublic ? AppColors.success : AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tag badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: AppRadius.smCircular,
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Text('[$tag]',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
