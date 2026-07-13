/// Route Tracker — GPS route recording with live stats and polyline.
/// Usa Supabase directamente (sin ApiClient).
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';

// ── BLoC ──

sealed class TrackerState {}
final class TrackerIdle extends TrackerState {}
final class TrackerRecording extends TrackerState {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSec;
  final double avgSpeed;
  final double maxSpeed;

  TrackerRecording({
    required this.points,
    this.distanceKm = 0,
    this.durationSec = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
  });

  String get durationStr {
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }
}

final class TrackerSavedRoutes extends TrackerState {
  final List<Map<String, dynamic>> routes;
  TrackerSavedRoutes({required this.routes});
}

sealed class TrackerEvent {}
final class StartRecording extends TrackerEvent {}
final class StopRecording extends TrackerEvent {}
final class SaveRoute extends TrackerEvent { final String name; SaveRoute(this.name); }
final class LoadSavedRoutes extends TrackerEvent {}

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  StreamSubscription<Position>? _sub;
  List<LatLng> _points = [];
  DateTime? _startedAt;
  double _maxSpeed = 0;

  TrackerBloc() : super(TrackerIdle()) {
    on<StartRecording>(_start);
    on<StopRecording>(_stop);
    on<SaveRoute>(_save);
    on<LoadSavedRoutes>(_loadRoutes);
  }

  Future<void> _start(StartRecording event, Emitter<TrackerState> emit) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        emit(TrackerIdle());
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          emit(TrackerIdle());
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        emit(TrackerIdle());
        return;
      }

      _points = [];
      _maxSpeed = 0;
      _startedAt = DateTime.now();
      HapticFeedback.mediumImpact();

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _points.add(LatLng(pos.latitude, pos.longitude));

      emit(TrackerRecording(points: List.from(_points)));

      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!isClosed) {
          _points.add(LatLng(pos.latitude, pos.longitude));
          if (pos.speed > _maxSpeed) _maxSpeed = pos.speed;
          final dist = _calcDistance(_points);
          final dur = DateTime.now().difference(_startedAt!).inSeconds;
          final avg = dur > 0 ? (dist / dur * 3.6) : 0.0;
          emit(TrackerRecording(
            points: List.from(_points), distanceKm: dist,
            durationSec: dur, avgSpeed: avg, maxSpeed: _maxSpeed * 3.6,
          ));
        }
      });
    } catch (e) {
      emit(TrackerIdle());
    }
  }

  void _stop(StopRecording event, Emitter<TrackerState> emit) {
    _sub?.cancel();
    _sub = null;
    HapticFeedback.heavyImpact();
  }

  Future<void> _save(SaveRoute event, Emitter<TrackerState> emit) async {
    final state = this.state;
    if (state is! TrackerRecording) return;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    try {
      await Supabase.instance.client.from('saved_routes').insert({
        'user_id': userId,
        'name': event.name,
        'distance': (state.distanceKm * 1000).round(),
        'duration': state.durationSec,
        'avg_speed': state.avgSpeed,
        'max_speed': state.maxSpeed,
        'points_count': state.points.length,
        'polyline': state.points.map((p) => [p.latitude, p.longitude]).toList(),
        'start_lat': state.points.first.latitude,
        'start_lng': state.points.first.longitude,
        'end_lat': state.points.last.latitude,
        'end_lng': state.points.last.longitude,
        'started_at': _startedAt?.toUtc().toIso8601String(),
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      });
      emit(TrackerIdle());
      // Reload saved routes
      add(LoadSavedRoutes());
    } catch (_) {}
  }

  Future<void> _loadRoutes(LoadSavedRoutes event, Emitter<TrackerState> emit) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await Supabase.instance.client
          .from('saved_routes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      emit(TrackerSavedRoutes(
        routes: (resp as List).cast<Map<String, dynamic>>(),
      ));
    } catch (_) {}
  }

  double _calcDistance(List<LatLng> pts) {
    const distCalc = Distance();
    double total = 0;
    for (int i = 1; i < pts.length; i++) {
      total += distCalc(pts[i - 1], pts[i]);
    }
    return total / 1000;
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

// ── Screen ──

class RouteTrackerScreen extends StatefulWidget {
  const RouteTrackerScreen({super.key});

  @override
  State<RouteTrackerScreen> createState() => _RouteTrackerScreenState();
}

class _RouteTrackerScreenState extends State<RouteTrackerScreen> {
  final _nameController = TextEditingController();
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackerBloc>().add(LoadSavedRoutes());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        final isRecording = state is TrackerRecording;
        final isSaved = state is TrackerSavedRoutes;

        return Scaffold(
          backgroundColor: AppColors.monitor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              isRecording ? 'GRABANDO RUTA' : 'GRABAR RUTA',
              style: AppTypography.h2.copyWith(
                color: isRecording ? AppColors.success : AppColors.primary,
              ),
            ),
            centerTitle: true,
            actions: [
              if (isRecording)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: AppColors.error, size: 28),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    context.read<TrackerBloc>().add(StopRecording());
                  },
                  tooltip: 'DETENER',
                ),
              if (!isRecording)
                IconButton(
                  icon: Icon(
                    _currentPage == 0
                        ? Icons.route_outlined
                        : Icons.list_alt_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentPage = _currentPage == 0 ? 1 : 0;
                    });
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: isRecording
                ? _buildRecordingView(state as TrackerRecording)
                : _buildIdleView(isSaved ? state as TrackerSavedRoutes : null),
          ),
        );
      },
    );
  }

  // ── Idle view ──
  Widget _buildIdleView(TrackerSavedRoutes? savedRoutes) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          // Start button
          SizedBox(
            width: double.infinity,
            height: 180,
            child: ElevatedButton(
              onPressed: () =>
                  context.read<TrackerBloc>().add(StartRecording()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success.withAlpha(15),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular,
                  side: BorderSide(
                      color: AppColors.success.withAlpha(80)),
                ),
                elevation: 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withAlpha(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.successGlow,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(AppIcons.gps,
                        color: AppColors.success, size: 32),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('INICIAR RUTA',
                      style: AppTypography.h3
                          .copyWith(color: AppColors.success)),
                  const SizedBox(height: 4),
                  Text('GPS grabará tu recorrido en vivo',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted)),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Saved Routes (if available) ──
          if (savedRoutes != null && savedRoutes.routes.isNotEmpty) ...[
            Row(
              children: [
                Text('RUTAS GUARDADAS',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    )),
                const Spacer(),
                Text('${savedRoutes.routes.length}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...savedRoutes.routes.map((r) => _buildSavedRouteCard(r)),
          ],

          if (savedRoutes == null || savedRoutes.routes.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.route_outlined,
                      color: AppColors.textMuted, size: 48),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Sin rutas guardadas aún',
                      style: AppTypography.body.copyWith(
                          color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedRouteCard(Map<String, dynamic> route) {
    final name = route['name'] as String? ?? 'Ruta';
    final distance = ((route['distance'] as num?)?.toDouble() ?? 0) / 1000;
    final duration = route['duration'] as int? ?? 0;
    final avgSpeed = (route['avg_speed'] as num?)?.toDouble() ?? 0;
    final createdAt = route['created_at'] as String? ?? '';

    final durStr = duration > 3600
        ? '${duration ~/ 3600}h ${(duration % 3600) ~/ 60}m'
        : '${duration ~/ 60}m ${duration % 60}s';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.cardPaddingSm,
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: AppRadius.smCircular,
            ),
            child: const Icon(AppIcons.route,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${distance.toStringAsFixed(2)} km · $durStr · ${avgSpeed.toStringAsFixed(1)} km/h',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            createdAt.isNotEmpty
                ? _formatTime(DateTime.tryParse(createdAt))
                : '',
            style: AppTypography.caption
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Recording view ──
  Widget _buildRecordingView(TrackerRecording state) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            padding: AppSpacing.cardPaddingSm,
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(80),
              borderRadius: AppRadius.mdCircular,
              border: Border.all(
                  color: AppColors.success.withAlpha(50)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successGlow,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('GRABANDO',
                    style: AppTypography.button
                        .copyWith(color: AppColors.success)),
                const Spacer(),
                Text(state.durationStr,
                    style: AppTypography.monoSmall
                        .copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Stats grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard('DISTANCIA',
                    '${state.distanceKm.toStringAsFixed(2)} km',
                    Icons.straighten, AppColors.primary),
                _statCard('VEL. PROMEDIO',
                    '${state.avgSpeed.toStringAsFixed(1)} km/h',
                    Icons.speed, AppColors.info),
                _statCard('VEL. MÁXIMA',
                    '${state.maxSpeed.toStringAsFixed(1)} km/h',
                    AppIcons.gps, AppColors.warning),
                _statCard('PUNTOS GPS',
                    '${state.points.length}',
                    AppIcons.location, AppColors.textMuted),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Save section
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius:
                        BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Nombre de la ruta',
                      border: InputBorder.none,
                      hintStyle:
                          TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGlow,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.save,
                      color: Colors.black, size: 22),
                  onPressed: () {
                    final name = _nameController.text.trim();
                    context.read<TrackerBloc>().add(SaveRoute(
                      name.isEmpty
                          ? 'Ruta ${DateTime.now().day}/${DateTime.now().month}'
                          : name,
                    ));
                    Navigator.pop(context);
                  },
                  tooltip: 'GUARDAR',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // OSM export
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _exportToOsm(state),
              icon: const Icon(Icons.map, size: AppSpacing.iconSm),
              label: const Text('SUBIR TRAZA A OpenStreetMap'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smCircular),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: AppSpacing.cardPaddingSm,
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(80),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.monoSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }

  void _exportToOsm(TrackerRecording state) {
    final now = DateTime.now();
    final gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="AsfaltoClub" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Ruta AsfaltoClub ${now.day}/${now.month}/${now.year}</name>
    <desc>Ruta grabada con AsfaltoClub - ${state.distanceKm.toStringAsFixed(2)}km, ${state.durationStr}</desc>
    <time>${now.toUtc().toIso8601String()}</time>
  </metadata>
  <trk>
    <name>Ruta ${now.day}/${now.month}</name>
    <trkseg>
${state.points.map((p) => '      <trkpt lat="${p.latitude}" lon="${p.longitude}"></trkpt>').join('\n')}
    </trkseg>
  </trk>
</gpx>''';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppColors.textMuted.withAlpha(60), borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(height: AppSpacing.lg),
              const Icon(Icons.map, color: AppColors.success, size: 40),
              const SizedBox(height: AppSpacing.sm),
              Text('ENRIQUECER OpenStreetMap', style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text('Tu ruta ayuda a mejorar el mapa colombiano',
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Option 1: Upload to OSM
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: gpx));
                    launchUrl(
                      Uri.parse('https://www.openstreetmap.org/traces/new'),
                      mode: LaunchMode.externalApplication,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ GPX copiado. Subilo en openstreetmap.org')),
                    );
                  },
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  label: const Text('SUBIR TRAZA A OSM (GPX)', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Option 2: Copy GPX
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: gpx));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📋 GPX copiado al portapapeles')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text('COPIAR GPX', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Option 3: OSM Note
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _createOsmNote(state, ctx),
                  icon: const Icon(Icons.push_pin_outlined, size: 20),
                  label: const Text('REPORTAR RUTA FALTANTE (OSM Note)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createOsmNote(TrackerRecording state, BuildContext ctx) async {
    Navigator.pop(ctx);
    if (state.points.isEmpty) return;

    // Use center point of route for the note location
    final avgLat = state.points.map((p) => p.latitude).reduce((a, b) => a + b) / state.points.length;
    final avgLng = state.points.map((p) => p.longitude).reduce((a, b) => a + b) / state.points.length;
    final start = state.points.first;
    final end = state.points.last;

    final comment = Uri.encodeComponent(
      'Ruta de moto grabada con AsfaltoClub. '
      '${state.distanceKm.toStringAsFixed(1)}km, ${state.points.length} puntos GPS. '
      'Desde (${start.latitude.toStringAsFixed(4)}, ${start.longitude.toStringAsFixed(4)}) '
      'hasta (${end.latitude.toStringAsFixed(4)}, ${end.longitude.toStringAsFixed(4)}). '
      'Por favor revisar si esta vía existe en OSM. #AsfaltoClub #Colombia',
    );
    final url = Uri.parse(
      'https://www.openstreetmap.org/note/new?lat=$avgLat&lon=$avgLng&text=$comment',
    );

    HapticFeedback.mediumImpact();
    await launchUrl(url, mode: LaunchMode.externalApplication);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📍 OSM Note abierto — completá el reporte')),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
