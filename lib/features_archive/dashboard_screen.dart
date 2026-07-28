/// Dashboard — redesigned with animated km counter, 2×2+ action grid & recent raids.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../../../places/presentation/screens/map_explorer_screen.dart';
import '../../../membership/presentation/screens/membership_screen.dart';
import '../../../economy/presentation/screens/shop_screen.dart';
import '../../../economy/presentation/widgets/coins_badge.dart';
import '../../../economy/presentation/bloc/shop_bloc.dart';
import '../../../economy/presentation/bloc/shop_event.dart';
import '../../../economy/presentation/bloc/shop_state.dart';
import '../../../battle_pass/presentation/screens/battle_pass_screen.dart';
import '../../../showcase/presentation/screens/showcase_profile_screen.dart';
import '../../../raids/presentation/bloc/raid_bloc.dart';
import '../../../raids/presentation/bloc/raid_event.dart';
import '../../../raids/presentation/bloc/raid_state.dart';
import '../../../raids/presentation/screens/create_raid_screen.dart';
import '../../../raids/presentation/screens/raid_list_screen.dart';
import '../../../raids/presentation/screens/raid_lobby_screen.dart';
import '../../../raids/presentation/screens/raid_live_screen.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _kmController;
  late Animation<double> _kmAnimation;
  bool _kmAnimated = false;

  @override
  void initState() {
    super.initState();
    _kmController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _kmAnimation = CurvedAnimation(
      parent: _kmController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardBloc>().add(LoadDashboard(userId: 1));
      context.read<RaidBloc>().add(const LoadRaids());
      context.read<ShopBloc>().add(const LoadShop());
    });
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  void _animateKm() {
    if (!_kmAnimated) {
      _kmController.forward();
      _kmAnimated = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _tap() => HapticFeedback.lightImpact();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is DashboardError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Error al cargar', style: AppTypography.h2),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is DashboardLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _animateKm());
          return _buildDashboard(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardLoaded state) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              // ── Animated km counter + coins badge ──
              _buildKmHeader(state),
              const SizedBox(height: AppSpacing.xl),
              // ── 3-row Action grid ──
              _buildActionGrid(context),
              const SizedBox(height: AppSpacing.xl),
              // ── Próximos raids ──
              _sectionHeader('PRÓXIMOS RAIDS'),
              const SizedBox(height: AppSpacing.sm),
              _buildRaidSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ── KM counter with stats subtitle ──

  Widget _buildKmHeader(DashboardLoaded state) {
    final displayKm = (_kmAnimation.value * state.totalKm).round();
    return Column(
      children: [
        Stack(
          children: [
            AnimatedBuilder(
              animation: _kmAnimation,
              builder: (context, child) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                  horizontal: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: AppGradients.cardHighlight,
                  borderRadius: AppRadius.lgCircular,
                  border: Border.all(color: AppColors.primary.withAlpha(30), width: 1),
                ),
                child: Column(
                  children: [
                    // Large animated km number
                    Text(
                      '$displayKm',
                      style: AppTypography.monoLarge.copyWith(
                        color: AppColors.primary,
                        fontSize: 56,
                      ),
                    ),
                    Text(
                      'KM',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Coins badge top-right of the km card
            Positioned(
              top: 12,
              right: 12,
              child: BlocBuilder<ShopBloc, ShopState>(
                builder: (context, shopState) {
                  final coins = shopState is ShopLoaded ? shopState.coins : 0;
                  return CoinsBadge(coins: coins);
                },
              ),
            ),
            // Quick profile link (avatar circle) top-left
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  _tap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShowcaseProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Subtitle with stats
        Text(
          '${state.placesVisited} lugares · ${state.challengesCompleted} retos',
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ── 3-row Action grid ──

  Widget _buildActionGrid(BuildContext context) {
    return Column(
      children: [
        // Row 1: MAPA, RUTA
        Row(
          children: [
            Expanded(child: _actionCard(
              context,
              icon: Icons.map_rounded,
              label: 'MAPA',
              subtitle: 'Explorar mapa',
              color: AppColors.primary,
              screen: const MapExplorerScreen(),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _actionCard(
              context,
              icon: Icons.route_rounded,
              label: 'RUTA',
              subtitle: 'Tracker GPS',
              color: AppColors.success,
              screen: const RouteTrackerScreen(),
            )),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Row 2: AUXILIO, TIENDA
        Row(
          children: [
            Expanded(child: _actionCard(
              context,
              icon: Icons.warning_rounded,
              label: 'AUXILIO',
              subtitle: 'SOS carretera',
              color: AppColors.error,
              screen: const SafeModeScreen(),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _actionCard(
              context,
              icon: Icons.store_rounded,
              label: 'TIENDA',
              subtitle: 'Cosméticos',
              color: AppColors.info,
              screen: const ShopScreen(),
            )),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Row 3: PASE, MEMBRESÍA
        Row(
          children: [
            Expanded(child: _actionCard(
              context,
              icon: Icons.card_membership_rounded,
              label: 'PASE',
              subtitle: 'Battle Pass',
              color: AppColors.secondary,
              screen: const BattlePassScreen(),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _actionCard(
              context,
              icon: AppIcons.fuel,
              label: 'MEMBRESÍA',
              subtitle: 'Ver plan',
              color: AppColors.primary,
              screen: const MembershipScreen(),
            )),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Widget screen,
  }) =>
      ElevatedButton(
        onPressed: () {
          _tap();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(60)),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdCircular,
          ),
          minimumSize: const Size(0, 100),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.h3.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );

  // ── Raid section (recent / next raids) ──

  Widget _buildRaidSection() {
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        if (state is RaidsLoaded) {
          final activeRaids = state.raids
              .where((r) => r['status'] == 'lobby' || r['status'] == 'active')
              .take(3)
              .toList();
          if (activeRaids.isEmpty) {
            return _buildNoRaidsCard();
          }
          return Column(
            children: [
              ...activeRaids.map((r) => _buildDashboardRaidCard(r)),
              const SizedBox(height: AppSpacing.sm),
              _buildRaidActions(),
            ],
          );
        }
        return _buildRaidActions();
      },
    );
  }

  Widget _buildDashboardRaidCard(Map<String, dynamic> raid) {
    final title = raid['description'] ?? 'Raid';
    final gameMode = raid['mode'] ?? 'Free Ride';
    final status = raid['status'] ?? 'lobby';
    final raidId = raid['id']?.toString() ?? '';
    final participants = (raid['raid_participants'] as List?)?.length ?? 0;
    final isActive = status == 'active';

    return GestureDetector(
      onTap: () {
        if (raidId.isEmpty) return;
        _tap();
        if (isActive) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => RaidLiveScreen(raidId: raidId),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => RaidLobbyScreen(raidId: raidId),
          ));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(
            color: isActive
                ? AppColors.secondary.withAlpha(40)
                : AppColors.primary.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            // Pulse dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? AppColors.success : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isActive ? AppColors.success : AppColors.primary)
                        .withAlpha(80),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
                  Text(
                    '$gameMode · $participants participante${participants != 1 ? 's' : ''}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.secondary.withAlpha(20)
                    : AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isActive ? 'EN VIVO' : 'LOBBY',
                style: AppTypography.caption.copyWith(
                  color: isActive ? AppColors.secondary : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRaidsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 32,
            color: AppColors.textMuted.withAlpha(80),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sin raids activos',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRaidActions(),
        ],
      ),
    );
  }

  Widget _buildRaidActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _tap();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRaidScreen()),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'CREAR RAID',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _tap();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaidListScreen()),
              );
            },
            icon: const Icon(Icons.list, size: 18),
            label: const Text(
              'VER TODOS',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) => Text(
    text,
    style: AppTypography.label.copyWith(
      color: AppColors.textMuted,
      letterSpacing: 1.5,
    ),
  );
}
