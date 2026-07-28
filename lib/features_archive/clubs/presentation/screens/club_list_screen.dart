/// Club List Screen — AsfaltoClub Clubs module.
/// Lista de todos los clubs disponibles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/club_bloc.dart';
import '../bloc/club_event.dart';
import '../bloc/club_state.dart';
import 'club_screen.dart';
import 'create_club_screen.dart';

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClubBloc>().add(LoadClubs());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClubBloc, ClubState>(
      builder: (context, state) {
        if (state is ClubLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is ClubsLoaded) {
          return _buildList(state.clubs);
        }
        if (state is ClubError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error al cargar clubs',
                    style: AppTypography.h2.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(state.message,
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => context.read<ClubBloc>().add(LoadClubs()),
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
        // Don't interfere with detail screens (ClubLoaded, etc.)
        return const SizedBox.shrink();
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text('CLUBS', style: AppTypography.h2.copyWith(color: AppColors.primary)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClubScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> clubs) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: clubs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, color: AppColors.textMuted.withAlpha(80), size: 64),
                  const SizedBox(height: AppSpacing.md),
                  Text('No hay clubs aún',
                    style: AppTypography.h2.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('¡Crea el primer club!',
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: AppSpacing.screenPadding,
              itemCount: clubs.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final club = clubs[index];
                final tag = (club['tag'] as String? ?? '???').toUpperCase();
                final name = club['name'] as String? ?? 'SIN NOMBRE';
                final memberCount = (club['club_members'] as List?)?.length ?? 0;
                final isPublic = club['is_public'] == true;

                return _ClubCard(
                  name: name,
                  tag: tag,
                  memberCount: memberCount,
                  isPublic: isPublic,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClubScreen(clubId: club['id'] as int),
                      ),
                    ).then((_) => context.read<ClubBloc>().add(LoadClubs()));
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClubScreen()),
          ).then((_) => context.read<ClubBloc>().add(LoadClubs()));
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnAmber,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final String name;
  final String tag;
  final int memberCount;
  final bool isPublic;
  final VoidCallback onTap;

  const _ClubCard({
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
