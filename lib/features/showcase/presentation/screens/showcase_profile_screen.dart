/// ShowcaseProfileScreen — pantalla principal tipo Steam con perfil épico completo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../progression/presentation/widgets/xp_progress_card.dart';
import '../../../progression/presentation/screens/achievements_screen.dart';
import '../../../progression/presentation/screens/leaderboard_screen.dart';
import '../bloc/showcase_bloc.dart';
import '../bloc/showcase_event.dart';
import '../bloc/showcase_state.dart';
import '../widgets/showcase_header.dart';
import '../widgets/patches_vitrine.dart';
import '../widgets/conquests_section.dart';
import '../widgets/photo_album.dart';
import '../widgets/achievements_grid.dart';
import '../widgets/lifetime_stats.dart';

class ShowcaseProfileScreen extends StatefulWidget {
  /// Optional userId — if null, loads the current authenticated user.
  final String? userId;

  const ShowcaseProfileScreen({super.key, this.userId});

  @override
  State<ShowcaseProfileScreen> createState() => _ShowcaseProfileScreenState();
}

class _ShowcaseProfileScreenState extends State<ShowcaseProfileScreen> {
  String _displayName = '';
  String _email = '';
  String _avatarUrl = '';
  String _membershipTier = '';

  @override
  void initState() {
    super.initState();
    _loadUserMetadata();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShowcaseBloc>().add(LoadShowcase(userId: widget.userId));
    });
  }

  void _loadUserMetadata() {
    if (widget.userId != null) {
      // For other user profiles, we'd need to fetch their metadata.
      // Simplified: just use current user display for now.
      _displayName = 'Motero';
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _email = user.email ?? '';
    _avatarUrl = user.userMetadata?['avatar_url'] as String? ?? '';
    final metaName = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String?;
    if (metaName != null && metaName.isNotEmpty) {
      _displayName = metaName;
    } else {
      _displayName = _email.split('@').first
          .split('.')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    _membershipTier = user.userMetadata?['membership_tier'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<ShowcaseBloc, ShowcaseState>(
        builder: (context, state) {
          if (state is ShowcaseLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ShowcaseError) {
            return _buildError(state.message);
          }
          if (state is ShowcaseLoaded) return _buildScreen(state);
          return const Center(
            child: Text('Inicializando...',
                style: TextStyle(color: AppColors.textMuted)),
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.error,
                  color: AppColors.error, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
              const SizedBox(height: AppSpacing.sm),
              Text(message,
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => context
                    .read<ShowcaseBloc>()
                    .add(const RefreshShowcase()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAmber,
                ),
                child: const Text('REINTENTAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(ShowcaseLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ShowcaseBloc>().add(const RefreshShowcase());
      },
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // ── Header (non-sliver, part of the scroll content via SliverToBoxAdapter) ──
          SliverToBoxAdapter(
            child: ShowcaseHeader(
              showcase: state.showcase,
              xpData: state.xpData,
              frames: state.frames,
              titles: state.titles,
              banners: state.banners,
              displayName: _displayName,
              avatarUrl: _avatarUrl,
              membershipTier: _membershipTier,
              isOwnProfile: state.isOwnProfile,
              onEditTap: () => _showEditSheet(context, state),
            ),
          ),

          // ── Followers/Following Row ──
          SliverToBoxAdapter(
            child: _buildFollowRow(state),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.md)),

          // ── XP Progress Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: XpProgressCard(
                data: state.xpData,
                onAchievementsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AchievementsScreen()),
                ),
                onLeaderboardTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LeaderboardScreen()),
                ),
                ),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.lg)),

          // ── Patches Vitrine ──
          SliverToBoxAdapter(
            child: PatchesVitrine(
              showcase: state.showcase,
              allPatches: state.patches,
              editMode: state.patchesEditMode,
              isOwnProfile: state.isOwnProfile,
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.lg)),

          // ── Conquests Section (legendary badges) ──
          SliverToBoxAdapter(
            child: ConquestsSection(achievements: state.achievements),
          ),
          if (state.achievements.any(
              (a) => a.unlocked && (a.category == 'raids' || a.category == 'checkpoints')))
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.lg)),

          // ── Lifetime Stats ──
          SliverToBoxAdapter(
            child: LifetimeStats(xpData: state.xpData),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.lg)),

          // ── Achievements Grid ──
          SliverToBoxAdapter(
            child: AchievementsGrid(
              achievements: state.achievements,
              onViewAllTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AchievementsScreen()),
              ),
            ),
          ),
          if (state.achievements.isNotEmpty)
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.lg)),

          // ── Photo Album ──
          SliverToBoxAdapter(
            child: PhotoAlbum(photos: state.conquestPhotos),
          ),
          if (state.conquestPhotos.isNotEmpty)
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.lg)),

          // ── Bottom spacing ──
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  Widget _buildFollowRow(ShowcaseLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stat('${state.followers}', 'Seguidores'),
          Container(
              width: 1, height: 32, color: AppColors.border),
          _stat('${state.following}', 'Seguidos'),
        ],
      ),
    );
  }

  Widget _stat(String count, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Text(count,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, ShowcaseLoaded state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('EDITAR SHOWCASE',
                  style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),

              // Banner
              _editOption(
                ctx,
                icon: Icons.image,
                label: 'Cambiar Banner',
                onTap: () => _pickBanner(ctx, state),
              ),
              const Divider(color: AppColors.border),

              // Title
              _editOption(
                ctx,
                icon: AppIcons.badge,
                label: 'Cambiar Título',
                onTap: () => _pickTitle(ctx, state),
              ),
              const Divider(color: AppColors.border),

              // Frame
              _editOption(
                ctx,
                icon: AppIcons.star,
                label: 'Cambiar Marco de Avatar',
                onTap: () => _pickFrame(ctx, state),
              ),
              const Divider(color: AppColors.border),

              // Background color
              _editOption(
                ctx,
                icon: Icons.colorize,
                label: 'Color de Fondo',
                onTap: () => _pickBgColor(ctx),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editOption(BuildContext ctx,
      {required IconData icon, required String label, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 24),
      title: Text(label,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
      trailing: const Icon(AppIcons.chevronRight,
          color: AppColors.textMuted, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _pickBanner(BuildContext ctx, ShowcaseLoaded state) {
    Navigator.pop(ctx);
    if (state.banners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes banners disponibles')),
      );
      return;
    }
    _showItemPicker(
      context,
      title: 'Seleccionar Banner',
      items: state.banners,
      onSelected: (item) {
        context.read<ShowcaseBloc>().add(EquipBanner(item.itemId));
      },
    );
  }

  void _pickTitle(BuildContext ctx, ShowcaseLoaded state) {
    Navigator.pop(ctx);
    if (state.titles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes títulos disponibles')),
      );
      return;
    }
    _showItemPicker(
      context,
      title: 'Seleccionar Título',
      items: state.titles,
      onSelected: (item) {
        context.read<ShowcaseBloc>().add(EquipTitle(item.itemId));
      },
    );
  }

  void _pickFrame(BuildContext ctx, ShowcaseLoaded state) {
    Navigator.pop(ctx);
    if (state.frames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes marcos disponibles')),
      );
      return;
    }
    _showItemPicker(
      context,
      title: 'Seleccionar Marco',
      items: state.frames,
      onSelected: (item) {
        context.read<ShowcaseBloc>().add(EquipFrame(item.itemId));
      },
    );
  }

  void _pickBgColor(BuildContext ctx) {
    Navigator.pop(ctx);
    final colors = [
      '#0A0A0F', // default asfalto
      '#1A0A0A', // asfalto rojizo
      '#0A1A0A', // asfalto verdoso
      '#0A0A1A', // asfalto azulado
      '#1A1A0A', // asfalto ámbar
      '#1A0A1A', // asfalto púrpura
      '#0A1A1A', // asfalto cian
    ];
    final colorNames = [
      'Asfalto noche',
      'Asfalto óxido',
      'Asfalto bosque',
      'Asfalto hielo',
      'Asfalto ámbar',
      'Asfalto neón',
      'Asfalto cian',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('COLOR DE FONDO',
                  style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(colors.length, (i) {
                  final hex = colors[i].replaceFirst('#', '');
                  final c = Color(int.parse('FF$hex', radix: 16));
                  return GestureDetector(
                    onTap: () {
                      context.read<ShowcaseBloc>().add(ChangeBgColor(colors[i]));
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: AppRadius.mdCircular,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.colorize,
                              color: Colors.white, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            colorNames[i],
                            style: AppTypography.caption.copyWith(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemPicker(
    BuildContext context, {
    required String title,
    required List<OwnedItem> items,
    required void Function(OwnedItem item) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title.toUpperCase(),
                  style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.border),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return ListTile(
                      leading: Text(item.icon, style: const TextStyle(fontSize: 28)),
                      title: Text(item.name,
                          style: AppTypography.body
                              .copyWith(color: AppColors.textPrimary)),
                      subtitle: item.description.isNotEmpty
                          ? Text(item.description,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted))
                          : null,
                      trailing: item.equipped
                          ? const Icon(Icons.check, color: AppColors.success)
                          : null,
                      onTap: () {
                        onSelected(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
