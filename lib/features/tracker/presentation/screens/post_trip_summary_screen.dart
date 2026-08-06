/// Post-Trip Summary Screen — appears after tracker stops.
/// Shows animated stats card, mini-map of the trace, and action buttons
/// for saving, adding photos, or discarding the trip.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';
import '../widgets/conquest_photo_button.dart';
import 'route_tracker_screen.dart'; // for TrackerBloc, TrackerRecording, SaveRoute

/// Holds the result of a completed ride for display on the summary screen.
class PostTripResult {
  final double distanceKm;
  final int durationSec;
  final List<LatLng> points;
  final double avgSpeed;
  final double maxSpeed;

  /// Stops marked during the trip (M-RTR-2/3): rendered between start and
  /// end on the mini-map. Empty for standalone trips without waypoints.
  final List<LatLng> waypoints;

  /// Raid this trip is linked to, when started from a raid (M-RTR-1).
  final int? raidId;

  const PostTripResult({
    required this.distanceKm,
    required this.durationSec,
    required this.points,
    required this.avgSpeed,
    required this.maxSpeed,
    this.waypoints = const [],
    this.raidId,
  });

  String get durationStr {
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }
}

class PostTripSummaryScreen extends StatefulWidget {
  const PostTripSummaryScreen({
    super.key,
    required this.result,
    this.tileProvider,
    this.userId = '',
  });

  final PostTripResult result;

  /// Injectable TileProvider for widget tests (FakeTileProvider). Null in
  /// prod → FlutterMap usa su provider por defecto (red/FMTC).
  final TileProvider? tileProvider;

  /// Owner de las fotos de conquista (W4 — M-CPU-1/2). Deriva de
  /// `auth.currentUser.id` en el caller (route_tracker_screen).
  final String userId;

  @override
  State<PostTripSummaryScreen> createState() => _PostTripSummaryScreenState();
}

class _PostTripSummaryScreenState extends State<PostTripSummaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _kmController;
  late Animation<double> _kmAnimation;
  late AnimationController _xpController;
  late Animation<double> _xpAnimation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _kmController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _kmAnimation = CurvedAnimation(
      parent: _kmController,
      curve: Curves.easeOutCubic,
    );
    _xpController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _xpAnimation = CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kmController.forward();
      Future.delayed(const Duration(milliseconds: 400), () {
        _xpController.forward();
      });
      _fitMapToRoute();
    });
  }

  @override
  void dispose() {
    _kmController.dispose();
    _xpController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fitMapToRoute() {
    if (widget.result.points.length < 2) return;
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;
    for (final p in widget.result.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  int get _xpGained {
    // Flat formula: 10 XP base + 2 XP per km + 5 XP bonus if avg > 40 km/h
    final base = 10;
    final perKm = (widget.result.distanceKm * 2).round();
    final speedBonus = widget.result.avgSpeed > 40 ? 5 : 0;
    return base + perKm + speedBonus;
  }

  @override
  Widget build(BuildContext context) {
    return PostTripSaveFeedback(
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'RESUMEN DEL VIAJE',
          style: AppTypography.h2,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats Card ──
              _buildStatsCard(),
              const SizedBox(height: AppSpacing.lg),

              // ── Mini Map ──
              _buildMiniMap(),
              const SizedBox(height: AppSpacing.lg),

              // ── Action Row ──
              _buildActionRow(),
            ],
          ),
        ),
      ),
    ),
  );
  }

  // ── Stats Card ──

  Widget _buildStatsCard() {
    final r = widget.result;
    final displayKm = (_kmAnimation.value * r.distanceKm);
    final displayXp = (_xpAnimation.value * _xpGained).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.cardHighlight,
        borderRadius: AppRadius.lgCircular,
        border: Border.all(color: AppColors.primary.withAlpha(30), width: 1),
      ),
      child: Column(
        children: [
          // Distance
          AnimatedBuilder(
            animation: _kmAnimation,
            builder: (context, child) => Text(
              displayKm.toStringAsFixed(1),
              style: AppTypography.monoLarge.copyWith(
                color: AppColors.primary,
                fontSize: 48,
              ),
            ),
          ),
          const Text(
            'KM RECORRIDOS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stats grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('DURACIÓN', r.durationStr),
              _statItem('VEL MEDIA', '${r.avgSpeed.toStringAsFixed(0)} km/h'),
              _statItem('MÁX', '${r.maxSpeed.toStringAsFixed(0)} km/h'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // XP gained
          AnimatedBuilder(
            animation: _xpAnimation,
            builder: (context, child) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withAlpha(40)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '+$displayXp XP',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.secondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Mini Map ──

  Widget _buildMiniMap() {
    final r = widget.result;
    final hasPoints = r.points.length >= 2;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgCircular,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: hasPoints
              ? r.points.first
              : const LatLng(4.5709, -74.2973),
          initialZoom: 14,
          minZoom: 3,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.moteros.moteros_app',
            tileProvider: widget.tileProvider,
          ),
          if (hasPoints)
            PolylineLayer(polylines: [
              Polyline(
                points: r.points,
                color: AppColors.primary.withAlpha(220),
                strokeWidth: 4,
              ),
            ]),
          // Trace completo en orden: start → paradas (M-RTR-3) → end.
          // Un solo MarkerLayer para que el orden de árbol sea el del trace.
          if (hasPoints)
            MarkerLayer(markers: buildTraceMarkers(r.points, r.waypoints)),
        ],
      ),
    );
  }

  // ── Action Row ──

  Widget _buildActionRow() {
    return Column(
      children: [
        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showSaveDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('GUARDAR RUTA', style: AppTypography.button),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Secondary row
        Row(
          children: [
            Expanded(
              // W4 — M-CPU-1/2: flujo real de fotos (pick → upload → insert).
              // Raid-linked inserta inmediato; standalone encola hasta
              // TrackerSaveSucceeded (ver conquest_photo_button.dart).
              child: ConquestPhotoButton(
                userId: widget.userId,
                raidId: widget.result.raidId,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text(
                  'DESCARTAR',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSaveDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Guardar ruta', style: AppTypography.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nombre de la ruta',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: AppTypography.buttonSmall),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                context
                    .read<TrackerBloc>()
                    .add(SaveRoute(name));
                Navigator.pop(context); // Go back from summary
              }
            },
            child: const Text('GUARDAR', style: AppTypography.buttonSmall),
          ),
        ],
      ),
    );
  }
}

/// M-RTR-3 — markers del trace en orden: start → paradas → end.
/// Pura y unit-testable (las screens con FlutterMap no se widget-testean:
/// el stream de tiles cuelga bajo FakeAsync — precedente del repo).
List<Marker> buildTraceMarkers(List<LatLng> points, List<LatLng> waypoints) {
  return [
    Marker(
      point: points.first,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    ),
    for (final stop in waypoints)
      Marker(
        point: stop,
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    Marker(
      point: points.last,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.error,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    ),
  ];
}

/// M-RTR-6 — el resultado del save surface SIEMPRE (nunca catch vacío).
/// Extraído como widget propio para testear el feedback sin el mapa.
class PostTripSaveFeedback extends StatelessWidget {
  const PostTripSaveFeedback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackerBloc, TrackerState>(
      listener: (context, state) {
        if (state is TrackerSaveSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ruta guardada'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is TrackerSaveFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: child,
    );
  }
}
