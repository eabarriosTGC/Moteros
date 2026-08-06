/// Rodar Screen — Map-first redesign for the core riding experience.
/// Features: interactive map with motoposada POIs, animated KM counter,
/// próximos raids, recent rides, and a prominent Rodar FAB.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../widgets/blue_dot_marker.dart';
import '../widgets/recenter_button.dart';
import '../widgets/place_search_bar.dart';
import '../widgets/search_results_list.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_state.dart';
import '../../../raids/presentation/bloc/raid_bloc.dart';
import '../../../raids/presentation/bloc/raid_event.dart';
import '../../../raids/presentation/bloc/raid_state.dart';
import '../../../raids/presentation/screens/create_raid_screen.dart';
import '../../../raids/presentation/screens/raid_list_screen.dart';
import '../../../raids/presentation/widgets/raid_join_sheet.dart';
import '../../../raids/presentation/widgets/raid_marker.dart';
import '../../../refugios/presentation/bloc/motoposadas_bloc.dart';
import '../../../refugios/presentation/bloc/motoposadas_event.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';
import '../../../refugios/presentation/widgets/tourist_poi_marker.dart';
import '../../../refugios/presentation/widgets/casa_motero_marker.dart';
import '../../../refugios/presentation/widgets/casa_motero_card.dart';
import '../../../../core/services/navigation_handler.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

class RodarScreen extends StatefulWidget {
  const RodarScreen({super.key});

  @override
  State<RodarScreen> createState() => _RodarScreenState();
}

class _RodarScreenState extends State<RodarScreen>
    with TickerProviderStateMixin {
  late AnimationController _kmController;
  late Animation<double> _kmAnimation;
  bool _kmAnimated = false;
  final MapController _mapController = MapController();

  // ── Position tracking for blue dot + recenter ──
  LatLng? _currentPosition;
  double _currentHeading = 0;

  // ── Search state ──
  LatLng? _searchResultMarker;

  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973); // Bogotá

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
      context.read<MotoposadasBloc>().add(const LoadMotoposadas());
      _checkPendingTrip();
    });

    // Start passive position stream for blue dot (map only, no tracking).
    LocationTrackingService.instance.passivePositionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        if (pos.heading.isFinite && pos.heading >= 0) {
          _currentHeading = pos.heading;
        }
      });
    });
  }

  /// Check if there's a trip checkpoint from a prior session (process kill).
  Future<void> _checkPendingTrip() async {
    final hasPending = await LocationTrackingService.hasPendingTrip();
    if (!hasPending || !mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.route_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'Viaje pendiente',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: const Text(
          'Tenías un viaje en curso que quedó sin guardar. '
          '¿Quieres continuarlo o descartarlo?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text(
              'DESCARTAR',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
            ),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'discard') {
      await LocationTrackingService.instance.clearCheckpoint();
    } else if (action == 'continue') {
      context.read<TrackerBloc>().add(ResumeFromCheckpoint());
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RouteTrackerScreen()),
      );
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    _mapController.dispose();
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
    final isDark = context.watch<ThemeCubit>().state == ThemeMode.dark;
    return BlocListener<SearchBloc, SearchState>(
      listener: (context, state) {
        if (state is PlaceSelected) {
          final loc = LatLng(state.result.lat, state.result.lng);
          setState(() => _searchResultMarker = loc);
          _mapController.move(loc, 15);
          HapticFeedback.lightImpact();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.monitor : AppColors.lightMonitor,
        body: Stack(
          children: [
            // ── Base map layer ──
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 5,
                minZoom: 3,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.moteros.moteros_app',
                ),
                // Motoposada POI markers
                BlocBuilder<MotoposadasBloc, MotoposadasState>(
                  builder: (context, state) {
                    if (state is! MotoposadasLoaded) {
                      return const SizedBox.shrink();
                    }
                    return MarkerLayer(
                      markers: state.motoposadas
                          .where((m) => m.isActive)
                          .map(
                            (m) => Marker(
                              point: LatLng(m.lat, m.lng),
                              width: 120,
                              height: 60,
                              child: GestureDetector(
                                onTap: () => m.isCasaMotero
                                    ? showCasaMoteroCard(context, m)
                                    : _showMotoposadaCard(context, m),
                                child: switch (markerKindFor(m)) {
                                  MarkerKind.tourist => TouristPoiMarker(
                                    title: m.title,
                                  ),
                                  MarkerKind.casaMotero => CasaMoteroMarker(
                                    title: m.title,
                                  ),
                                  MarkerKind.standard => _buildMotoposadaMarker(
                                    m,
                                  ),
                                },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                // Raid markers — public upcoming/active rides (F-M8)
                BlocBuilder<RaidBloc, RaidState>(
                  builder: (context, state) {
                    if (state is! RaidsLoaded) {
                      return const SizedBox.shrink();
                    }
                    final markers = state.raids
                        .where(
                          (r) =>
                              (r['status'] == 'lobby' ||
                                  r['status'] == 'planned' ||
                                  r['status'] == 'active') &&
                              r['origin_lat'] != null &&
                              r['origin_lng'] != null,
                        )
                        .map((r) {
                          final isActive = r['status'] == 'active';
                          return Marker(
                            point: LatLng(
                              (r['origin_lat'] as num).toDouble(),
                              (r['origin_lng'] as num).toDouble(),
                            ),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => showRaidJoinSheet(context, r),
                              child: RaidMarker(isActive: isActive),
                            ),
                          );
                        })
                        .toList();
                    if (markers.isEmpty) return const SizedBox.shrink();
                    return MarkerLayer(markers: markers);
                  },
                ),
                // Blue dot — user's current location with heading
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 32,
                        height: 32,
                        child: BlueDotMarker(
                          position: _currentPosition!,
                          heading: _currentHeading,
                        ),
                      ),
                    ],
                  ),
                // Search result marker (cyan, temporary)
                if (_searchResultMarker != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _searchResultMarker!,
                        width: 28,
                        height: 28,
                        child: _buildSearchResultMarker(),
                      ),
                    ],
                  ),
              ],
            ),

            // ── Top overlay: KM counter card ──
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _animateKm(),
                  );
                  return Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    right: 12,
                    child: _buildKmOverlay(state),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // ── Recenter button (above Rodar FAB) ──
            if (_currentPosition != null)
              Positioned(
                bottom: 100,
                right: 16,
                child: RecenterButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _mapController.move(
                      _currentPosition!,
                      _mapController.camera.zoom,
                    );
                  },
                ),
              ),

            // ── Search bar + results ──
            // Positioned below the KM overlay: the KM card lives at
            // padding.top + 8 and is ~52px tall; a fixed top:72 overlapped it
            // on notched devices (P0-2). Search bar top now derives from the
            // real status-bar inset.
            Builder(
              builder: (context) {
                final statusBarTop =
                    MediaQuery.of(context).padding.top + 8;
                return Positioned(
                  top: statusBarTop + 60,
                  left: 12,
                  right: 12,
                  child: const PlaceSearchBar(),
                );
              },
            ),
            Builder(
              builder: (context) {
                final statusBarTop =
                    MediaQuery.of(context).padding.top + 8;
                return Positioned(
                  top: statusBarTop + 108,
                  left: 12,
                  right: 12,
                  child: const SearchResultsList(),
                );
              },
            ),

            // ── Rodar FAB ──
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.large(
                  onPressed: () {
                    _tap();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RouteTrackerScreen(),
                      ),
                    );
                  },
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 8,
                  child: const Icon(Icons.fiber_manual_record, size: 48),
                ),
              ),
            ),

            // ── Bottom sheet: raids + recent rides ──
            DraggableScrollableSheet(
              initialChildSize: 0.30,
              minChildSize: 0.12,
              maxChildSize: 0.50,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.overlay,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Stats subtitle
                      BlocBuilder<DashboardBloc, DashboardState>(
                        builder: (context, state) {
                          if (state is! DashboardLoaded) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              '${state.placesVisited} lugares · ${state.challengesCompleted} retos',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                      // Section header
                      _sectionHeader('PRÓXIMOS RAIDS'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildRaidSection(),
                      const SizedBox(height: AppSpacing.sm),
                      // Recent rides placeholder
                      _sectionHeader('VIAJES RECIENTES'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildRecentRidesPlaceholder(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Search result marker (cyan dot + pin) ──

  Widget _buildSearchResultMarker() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withAlpha(40),
        border: Border.all(color: AppColors.secondary, width: 2.5),
      ),
      child: const Icon(Icons.push_pin, color: AppColors.secondary, size: 14),
    );
  }

  // ── KM counter overlay ──

  Widget _buildKmOverlay(DashboardLoaded state) {
    final displayKm = (_kmAnimation.value * state.totalKm).round();
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: AppRadius.lgCircular,
        border: Border.all(color: AppColors.primary.withAlpha(40), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _kmAnimation,
            builder: (context, child) => Text(
              '$displayKm',
              style: AppTypography.monoLarge.copyWith(
                color: AppColors.primary,
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'KM',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Motoposada POI marker ──

  Widget _buildMotoposadaMarker(dynamic motoposada) {
    final typeLabel = motoposada.typeLabel as String? ?? 'Casa';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(220),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Text(
            motoposada.title.length > 15
                ? '${motoposada.title.substring(0, 15)}…'
                : motoposada.title as String,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Icon
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withAlpha(30),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Icon(
            typeLabel == 'Casa' ? Icons.home_rounded : Icons.garage_rounded,
            color: AppColors.primary,
            size: 14,
          ),
        ),
      ],
    );
  }

  // ── Raid section ──

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
              ...activeRaids.map((r) => _buildRaidCard(r)),
              const SizedBox(height: AppSpacing.sm),
              _buildRaidActions(),
            ],
          );
        }
        return _buildRaidActions();
      },
    );
  }

  Widget _buildRaidCard(Map<String, dynamic> raid) {
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
        showRaidJoinSheet(context, raid);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(180),
          borderRadius: AppRadius.mdCircular,
          border: Border.all(
            color: isActive
                ? AppColors.secondary.withAlpha(40)
                : AppColors.primary.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
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
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$gameMode · $participants participante${participants != 1 ? 's' : ''}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  fontSize: 9,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(180),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 24,
            color: AppColors.textMuted.withAlpha(80),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sin raids activos',
            style: AppTypography.body.copyWith(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
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
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'CREAR',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(0, 36),
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
            icon: const Icon(Icons.list, size: 16),
            label: const Text(
              'VER TODOS',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(0, 36),
            ),
          ),
        ),
      ],
    );
  }

  // ── Recent rides placeholder ──

  Widget _buildRecentRidesPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(180),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.route_outlined,
            size: 28,
            color: AppColors.textMuted.withAlpha(80),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tus viajes recientes aparecerán aquí',
            style: AppTypography.body.copyWith(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Motoposada POI card — single bottom sheet with nav buttons ──

  void _showMotoposadaCard(BuildContext context, MotoposadaModel mp) {
    _tap();
    // Pre-resolve available apps for the card
    Future.delayed(Duration.zero, () async {
      final wazeOk = await NavigationHandler.canLaunchWaze();
      final mapsOk = await NavigationHandler.canLaunchGoogleMaps();
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ── Header row: icon + name + type ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: AppRadius.mdCircular,
                      ),
                      child: Icon(
                        _motoposadaIcon(mp.typeLabel),
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mp.title,
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              mp.typeLabel,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // ── Description ──
                if (mp.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    mp.description,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // ── Divider ──
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                // ── Label ──
                Text(
                  'NAVEGAR CON',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // ── Nav buttons ──
                _buildNavRow(ctx, mp, wazeOk, mapsOk),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Icon mapping based on motoposada type.
  IconData _motoposadaIcon(String type) {
    switch (type.toLowerCase()) {
      case 'hospedaje':
      case 'casa':
      case 'hostal':
        return Icons.bed_rounded;
      case 'taller':
      case 'mecánico':
        return Icons.build_rounded;
      case 'combustible':
      case 'gasolina':
      case 'estación':
        return Icons.local_gas_station_rounded;
      case 'restaurante':
      case 'comida':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  /// Build navigation buttons row — single button if only one app available,
  /// two side-by-side if both are available.
  Widget _buildNavRow(
    BuildContext ctx,
    MotoposadaModel mp,
    bool wazeOk,
    bool mapsOk,
  ) {
    if (!wazeOk && !mapsOk) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(10),
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.error.withAlpha(30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.error, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Instala Waze o Google Maps para navegar hasta aquí',
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }

    // Both available → side-by-side
    if (wazeOk && mapsOk) {
      return Row(
        children: [
          Expanded(
            child: _navButton(
              ctx,
              mp,
              icon: Icons.navigation_rounded,
              label: 'Waze',
              color: const Color(0xFF33CCFF),
              onTap: () => NavigationHandler.launchWaze(mp.lat, mp.lng),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _navButton(
              ctx,
              mp,
              icon: Icons.map_outlined,
              label: 'Google Maps',
              color: const Color(0xFF34A853),
              onTap: () => NavigationHandler.launchGoogleMaps(mp.lat, mp.lng),
            ),
          ),
        ],
      );
    }

    // Only one available → full width
    final isWaze = wazeOk;
    return _navButton(
      ctx,
      mp,
      icon: isWaze ? Icons.navigation_rounded : Icons.map_outlined,
      label: isWaze ? 'Abrir en Waze' : 'Abrir en Google Maps',
      color: isWaze ? const Color(0xFF33CCFF) : const Color(0xFF34A853),
      onTap: () => isWaze
          ? NavigationHandler.launchWaze(mp.lat, mp.lng)
          : NavigationHandler.launchGoogleMaps(mp.lat, mp.lng),
    );
  }

  Widget _navButton(
    BuildContext ctx,
    MotoposadaModel mp, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(ctx);
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(15),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(50), width: 1.2),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.button.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
