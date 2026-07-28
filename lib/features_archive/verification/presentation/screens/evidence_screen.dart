/// Evidence Screen — Take photos with GPS metadata to verify visits.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';

sealed class ScanState {}
final class ScanInitial extends ScanState {}
final class ScanCapturing extends ScanState {}
final class ScanVerifying extends ScanState { final String photoPath; final Position position; ScanVerifying(this.photoPath, this.position); }
final class ScanSuccess extends ScanState { final String message; final int points; final bool verified; ScanSuccess(this.message, this.points, this.verified); }
final class ScanError extends ScanState { final String error; ScanError(this.error); }

class ScanEvent {}
final class TakePhoto extends ScanEvent {}
final class ConfirmVisit extends ScanEvent { final int placeId; final String photoPath; final Position position; ConfirmVisit(this.placeId, this.photoPath, this.position); }

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ApiClient apiClient;
  ScanBloc(this.apiClient) : super(ScanInitial()) {
    on<TakePhoto>(_takePhoto);
    on<ConfirmVisit>(_confirm);
  }

  Future<void> _takePhoto(TakePhoto event, Emitter<ScanState> emit) async {
    emit(ScanCapturing());
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) { emit(ScanInitial()); return; }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      emit(ScanVerifying(photo.path, pos));
    } catch (e) {
      emit(ScanError('Error al capturar: $e'));
    }
  }

  Future<void> _confirm(ConfirmVisit event, Emitter<ScanState> emit) async {
    try {
      final response = await apiClient.post('/visits', data: {
        'place_id': event.placeId,
        'photo_url': event.photoPath,
        'latitude': event.position.latitude,
        'longitude': event.position.longitude,
        'accuracy_meters': event.position.accuracy,
      });
      final data = response.data as Map<String, dynamic>;
      HapticFeedback.heavyImpact();
      emit(ScanSuccess(
        data['message'] as String? ?? 'Visita registrada',
        data['points_awarded'] as int? ?? 0,
        data['verified'] as bool? ?? false,
      ));
    } catch (e) {
      emit(ScanError('Error al verificar: $e'));
    }
  }
}

class EvidenceScreen extends StatelessWidget {
  final List<Map<String, dynamic>> nearbyPlaces;

  const EvidenceScreen({super.key, required this.nearbyPlaces});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanBloc(context.read<ApiClient>()),
      child: _EvidenceBody(nearbyPlaces: nearbyPlaces),
    );
  }
}

class _EvidenceBody extends StatefulWidget {
  final List<Map<String, dynamic>> nearbyPlaces;
  const _EvidenceBody({required this.nearbyPlaces});

  @override
  State<_EvidenceBody> createState() => _EvidenceBodyState();
}

class _EvidenceBodyState extends State<_EvidenceBody> {
  int? _selectedPlace;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Registrar Visita')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(children: [
                // Instructions
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(15),
                    borderRadius: AppRadius.mdCircular,
                    border: Border.all(color: AppColors.info.withAlpha(40)),
                  ),
                  child: Row(children: [
                    const Icon(AppIcons.gps, color: AppColors.info, size: AppSpacing.iconMd),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(
                      'Toma una foto en el lugar para verificar tu visita. El GPS se capturará automáticamente.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    )),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Place selector
                const Text('¿A qué lugar llegaste?', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                ...widget.nearbyPlaces.map((p) => _placeTile(p)),

                const SizedBox(height: AppSpacing.lg),

                // Camera / Result
                if (state is ScanInitial || state is ScanCapturing)
                  _buildCameraButton(context, state)
                else if (state is ScanVerifying)
                  _buildPreview(context, state)
                else if (state is ScanSuccess)
                  _buildSuccess(state)
                else if (state is ScanError)
                  _buildError(state),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _placeTile(Map<String, dynamic> place) {
    final id = place['id'] as int;
    final selected = _selectedPlace == id;
    final category = place['category'] as String? ?? '';
    final color = _categoryColor(category);
    return GestureDetector(
      onTap: () => setState(() => _selectedPlace = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(15) : AppColors.card,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: selected ? color.withAlpha(80) : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? color : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place['name'] as String? ?? '', style: AppTypography.body),
            Text(place['city'] as String? ?? '', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          ])),
          if (selected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: Text('${(place['distance_km'] as num?)?.toStringAsFixed(1) ?? "?"} km',
                style: AppTypography.caption.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }

  Widget _buildCameraButton(BuildContext context, ScanState state) {
    final isLoading = state is ScanCapturing;
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: ElevatedButton(
        onPressed: (_selectedPlace == null || isLoading) ? null : () {
          context.read<ScanBloc>().add(TakePhoto());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdCircular,
            side: BorderSide(color: _selectedPlace != null ? AppColors.primary : AppColors.border),
          ),
        ),
        child: isLoading
          ? const CircularProgressIndicator()
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_selectedPlace != null ? AppIcons.camera : Icons.lock,
                color: _selectedPlace != null ? AppColors.primary : AppColors.textMuted,
                size: 48),
              const SizedBox(height: AppSpacing.sm),
              Text(_selectedPlace != null ? 'TOMAR FOTO' : 'SELECCIONA UN LUGAR PRIMERO',
                style: AppTypography.label.copyWith(
                  color: _selectedPlace != null ? AppColors.primary : AppColors.textMuted)),
            ]),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, ScanVerifying state) {
    return Column(children: [
      // Photo preview
      ClipRRect(
        borderRadius: AppRadius.mdCircular,
        child: Image.file(File(state.photoPath), height: 250, width: double.infinity, fit: BoxFit.cover),
      ),
      const SizedBox(height: AppSpacing.sm),
      // GPS info
      Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.input, borderRadius: AppRadius.mdCircular),
        child: Row(children: [
          const Icon(AppIcons.gps, color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GPS capturado', style: AppTypography.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
            Text('${state.position.latitude.toStringAsFixed(4)}, ${state.position.longitude.toStringAsFixed(4)}',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          ]),
        ]),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.read<ScanBloc>().add(ConfirmVisit(
            _selectedPlace!, state.photoPath, state.position)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          ),
          child: const Text('VERIFICAR VISITA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
      ),
    ]);
  }

  Widget _buildSuccess(ScanSuccess state) {
    return Column(children: [
      Icon(state.verified ? Icons.verified : Icons.warning_amber,
        size: 80, color: state.verified ? AppColors.success : AppColors.warning),
      const SizedBox(height: AppSpacing.md),
      Text(state.verified ? '✅ VISITA VERIFICADA' : '⚠️ VISITA REGISTRADA',
        style: AppTypography.h2.copyWith(color: state.verified ? AppColors.success : AppColors.warning)),
      const SizedBox(height: AppSpacing.sm),
      Text(state.message, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.md),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: state.verified ? AppColors.success.withAlpha(20) : AppColors.warning.withAlpha(20),
          borderRadius: AppRadius.mdCircular,
        ),
        child: Text('+${state.points} PUNTOS', style: AppTypography.h3.copyWith(
          color: state.verified ? AppColors.success : AppColors.warning)),
      ),
      const SizedBox(height: AppSpacing.lg),
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          minimumSize: const Size(200, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        ),
        child: const Text('VOLVER'),
      ),
    ]);
  }

  Widget _buildError(ScanError state) {
    return Column(children: [
      const Icon(Icons.error, size: 64, color: AppColors.error),
      const SizedBox(height: AppSpacing.md),
      Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
      const SizedBox(height: AppSpacing.sm),
      Text(state.error, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
    ]);
  }

  Color _categoryColor(String cat) => switch (cat) {
    'taller' => AppColors.primary,
    'restaurante' => AppColors.secondary,
    'hotel' || 'moto_posada' => AppColors.info,
    'mirador' => AppColors.success,
    _ => AppColors.textMuted,
  };
}
