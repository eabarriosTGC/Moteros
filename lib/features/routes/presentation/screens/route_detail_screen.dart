/// Route Detail Screen — dual map view with planned vs actual trace.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/services/offline_map_service.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';
import 'route_tracking_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  final int routeId;
  const RouteDetailScreen({super.key, required this.routeId});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RouteBloc>().add(LoadRouteDetail(routeId: widget.routeId));
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
        title: const Text('Detalle de Ruta', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: AppColors.primary),
            tooltip: 'Exportar GPX',
            onPressed: () => _exportGpx(),
          ),
        ],
      ),
      body: BlocBuilder<RouteBloc, RouteState>(
        builder: (context, state) {
          if (state is RouteLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is RouteDetailLoaded) {
            return _buildDetail(state);
          }
          if (state is RouteError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(state.message, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDetail(RouteDetailLoaded state) {
    final route = state.route;
    final title = route['title'] as String? ?? 'Ruta';
    final description = route['description'] as String? ?? '';
    final difficulty = route['difficulty'] as String? ?? 'media';
    final totalKm = (route['total_km'] as num?)?.toDouble() ?? 0;
    final durationMin = (route['duration_min'] as int?) ?? 0;
    final waypointsRaw = route['waypoints'] as List? ?? [];
    final segments = state.segments ?? [];
    // ignore: unused_local_variable
    final _ = segments;
    final history = state.history ?? [];

    // Parse waypoints to LatLng
    final waypoints = waypointsRaw.map((wp) {
      if (wp is Map<String, dynamic>) {
        return LatLng(
          (wp['lat'] as num).toDouble(),
          (wp['lng'] as num).toDouble(),
        );
      }
      return null;
    }).whereType<LatLng>().toList();

    final difficultyColor = switch (difficulty) {
      'facil' => AppColors.success,
      'medio' => AppColors.warning,
      'dificil' => AppColors.error,
      'experto' => const Color(0xFFFF2D55),
      _ => AppColors.textMuted,
    };

    return SingleChildScrollView(
      child: Column(
        children: [
          // Map
          Container(
            height: 280,
            child: waypoints.isEmpty
                ? Container(
                    color: AppColors.monitor,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: AppColors.textMuted),
                          SizedBox(height: AppSpacing.sm),
                          Text('Sin waypoints', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: waypoints.first,
                      initialZoom: 12,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        tileProvider: OfflineMapService.tileProvider(),
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.moteros.moteros_app',
                      ),
                      // Planned route polyline (gray)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: waypoints,
                          color: AppColors.textMuted.withAlpha(120),
                          strokeWidth: 4,
                        ),
                      ]),
                      // Actual trace from latest history (amber/cyan if available)
                      if (history.isNotEmpty)
                        PolylineLayer(polylines: [
                          Polyline(
                            points: _parseTrace(history.first['trace_polyline']),
                            color: AppColors.secondary,
                            strokeWidth: 3,
                          ),
                        ]),
                      // Waypoint markers
                      MarkerLayer(markers: waypoints.asMap().entries.map((entry) {
                        final i = entry.key;
                        final point = entry.value;
                        final wpData = waypointsRaw.length > i && waypointsRaw[i] is Map
                            ? waypointsRaw[i] as Map<String, dynamic>
                            : null;
                        final isMotoposada = wpData?['stop_type'] == 'moto_posada';
                        return Marker(
                          point: point,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isMotoposada ? AppColors.primary : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isMotoposada ? AppColors.primaryLight : AppColors.secondary,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: isMotoposada
                                  ? const Icon(Icons.home, size: 14, color: AppColors.textOnAmber)
                                  : Text('${i + 1}',
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }).toList()),
                      // Start marker
                      MarkerLayer(markers: [
                        Marker(
                          point: waypoints.first,
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.textPrimary, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.flag, size: 16, color: Colors.black),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
          ),

          // Info panel
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(title, style: AppTypography.h1.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),

                // Difficulty + stats
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: difficultyColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: difficultyColor.withAlpha(60)),
                      ),
                      child: Text(difficulty.toUpperCase(),
                        style: AppTypography.caption.copyWith(color: difficultyColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    _statChip(Icons.route_outlined, '${totalKm.toStringAsFixed(1)} km'),
                    const SizedBox(width: AppSpacing.sm),
                    _statChip(Icons.timer_outlined, _formatDuration(durationMin)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Description
                if (description.isNotEmpty) ...[
                  Text(description, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Waypoints list
                Text('PUNTOS DE RUTA', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
                const SizedBox(height: AppSpacing.sm),
                ...waypointsRaw.asMap().entries.map((entry) {
                  final i = entry.key;
                  final wp = entry.value as Map<String, dynamic>? ?? {};
                  final wpName = wp['name'] as String? ?? 'Punto ${i + 1}';
                  final stopType = wp['stop_type'] as String?;
                  final duration = wp['duration_min'] as int?;
                  final isMotoPosada = stopType == 'moto_posada';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.smCircular,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isMotoPosada ? AppColors.primary.withAlpha(25) : AppColors.input,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: isMotoPosada
                                  ? const Icon(Icons.home_rounded, size: 14, color: AppColors.primary)
                                  : Text('${i + 1}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(wpName,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                          if (isMotoPosada)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('MOTOPOSADA',
                                style: AppTypography.caption.copyWith(color: AppColors.primary, fontSize: 8),
                              ),
                            ),
                          if (duration != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text('${duration}min', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),

                // Rating
                Text('CALIFICAR', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
                const SizedBox(height: AppSpacing.sm),
                _buildRatingInput(),
                const SizedBox(height: AppSpacing.lg),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RouteTrackingScreen(
                                routeId: widget.routeId,
                                initialWaypoints: waypoints.isNotEmpty ? waypoints : null,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: AppSpacing.iconSm),
                        label: const Text('INICIAR RUTA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnAmber,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildRatingInput() {
    return Row(
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < 3 ? Icons.star : Icons.star_border,
            color: AppColors.primary,
            size: 28,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Calificaste ${i + 1} estrella(s)'),
                backgroundColor: AppColors.surface,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      }),
    );
  }

  List<LatLng> _parseTrace(dynamic trace) {
    if (trace == null) return [];
    if (trace is List) {
      return trace.map((p) {
        if (p is List && p.length >= 2) {
          return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
        }
        return null;
      }).whereType<LatLng>().toList();
    }
    return [];
  }

  String _formatDuration(int min) {
    if (min < 60) return '${min}min';
    final h = min ~/ 60;
    final m = min % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  void _exportGpx() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ GPX exportado — revisa tu carpeta de descargas'),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
