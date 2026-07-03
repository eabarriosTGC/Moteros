/// Route Tracker — GPS route recording with live stats and polyline.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import '../../../../core/network/api_client.dart';
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

sealed class TrackerEvent {}
final class StartRecording extends TrackerEvent {}
final class StopRecording extends TrackerEvent {}
final class SaveRoute extends TrackerEvent { final String name; SaveRoute(this.name); }

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  final ApiClient apiClient;
  StreamSubscription<Position>? _sub;
  List<LatLng> _points = [];
  DateTime? _startedAt;
  double _maxSpeed = 0;

  TrackerBloc(this.apiClient) : super(TrackerIdle()) {
    on<StartRecording>(_start);
    on<StopRecording>(_stop);
    on<SaveRoute>(_save);
  }

  Future<void> _start(StartRecording event, Emitter<TrackerState> emit) async {
    _points = [];
    _maxSpeed = 0;
    _startedAt = DateTime.now();
    HapticFeedback.mediumImpact();

    final pos = await Geolocator.getCurrentPosition();
    _points.add(LatLng(pos.latitude, pos.longitude));

    emit(TrackerRecording(points: List.from(_points)));

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // update every 10m
      ),
    ).listen((pos) {
      if (!isClosed) {
        _points.add(LatLng(pos.latitude, pos.longitude));
        if (pos.speed > _maxSpeed) _maxSpeed = pos.speed;
        final dist = _calcDistance(_points);
        final dur = DateTime.now().difference(_startedAt!).inSeconds;
        final avg = dur > 0 ? (dist / dur * 3.6) : 0.0; // km/h
        emit(TrackerRecording(
          points: List.from(_points), distanceKm: dist,
          durationSec: dur, avgSpeed: avg, maxSpeed: _maxSpeed * 3.6,
        ));
      }
    });
  }

  void _stop(StopRecording event, Emitter<TrackerState> emit) {
    _sub?.cancel();
    _sub = null;
    HapticFeedback.heavyImpact();
  }

  Future<void> _save(SaveRoute event, Emitter<TrackerState> emit) async {
    final state = this.state;
    if (state is! TrackerRecording) return;
    try {
      await apiClient.post('/routes', data: {
        'name': event.name,
        'distance': state.distanceKm * 1000,
        'duration': state.durationSec,
        'avgSpeed': state.avgSpeed,
        'maxSpeed': state.maxSpeed,
        'points': state.points.length,
        'polyline': state.points.map((p) => [p.latitude, p.longitude]).toList(),
        'startLat': state.points.first.latitude,
        'startLng': state.points.first.longitude,
        'endLat': state.points.last.latitude,
        'endLng': state.points.last.longitude,
        'startedAt': _startedAt?.toUtc().toIso8601String(),
        'endedAt': DateTime.now().toUtc().toIso8601String(),
      });
      emit(TrackerIdle());
    } catch (_) {}
  }

  double _calcDistance(List<LatLng> pts) {
    const distCalc = Distance();
    double total = 0;
    for (int i = 1; i < pts.length; i++) {
      total += distCalc(pts[i - 1], pts[i]); // returns meters
    }
    return total / 1000; // km
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        final isRecording = state is TrackerRecording;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Grabar Ruta'),
            actions: [
              if (isRecording)
                TextButton.icon(
                  onPressed: () => context.read<TrackerBloc>().add(StopRecording()),
                  icon: const Icon(Icons.stop, color: AppColors.error),
                  label: const Text('Detener', style: TextStyle(color: AppColors.error)),
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(children: [
                // Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: isRecording
                      ? const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)])
                      : AppGradients.cardHighlight,
                    borderRadius: AppRadius.mdCircular,
                  ),
                  child: Row(children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRecording ? Colors.white : AppColors.textMuted,
                        boxShadow: isRecording ? [BoxShadow(color: Colors.white.withAlpha(80), blurRadius: 8)] : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(isRecording ? 'GRABANDO' : 'LISTO',
                      style: AppTypography.button.copyWith(color: Colors.white)),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Stats
                if (isRecording) ...[
                  _statRow('DISTANCIA', '${state.distanceKm.toStringAsFixed(2)} km', AppColors.primary),
                  const SizedBox(height: AppSpacing.sm),
                  _statRow('DURACIÓN', state.durationStr, AppColors.info),
                  const SizedBox(height: AppSpacing.sm),
                  _statRow('VEL. PROMEDIO', '${state.avgSpeed.toStringAsFixed(1)} km/h', AppColors.success),
                  const SizedBox(height: AppSpacing.sm),
                  _statRow('VEL. MÁXIMA', '${state.maxSpeed.toStringAsFixed(1)} km/h', AppColors.warning),
                  const SizedBox(height: AppSpacing.sm),
                  _statRow('PUNTOS', '${state.points.length}', AppColors.textMuted),
                  const SizedBox(height: AppSpacing.lg),

                  // Save
                  Row(children: [
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Nombre de la ruta',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () {
                        final name = _nameController.text.trim();
                        context.read<TrackerBloc>().add(SaveRoute(name.isEmpty ? 'Ruta ${DateTime.now().day}/${DateTime.now().month}' : name));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                        minimumSize: const Size(80, 48),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ]),
                ] else ...[
                  // Start button
                  SizedBox(
                    width: double.infinity, height: 160,
                    child: ElevatedButton(
                      onPressed: () => context.read<TrackerBloc>().add(StartRecording()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success.withAlpha(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdCircular,
                          side: BorderSide(color: AppColors.success.withAlpha(80)),
                        ),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(AppIcons.gps, color: AppColors.success, size: 48),
                        const SizedBox(height: AppSpacing.sm),
                        Text('INICIAR GRABACIÓN', style: AppTypography.h3.copyWith(color: AppColors.success)),
                        const SizedBox(height: 4),
                        Text('Se registrará tu ruta con GPS en vivo',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.mdCircular),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTypography.label.copyWith(color: AppColors.textMuted)),
        Text(value, style: AppTypography.body.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
