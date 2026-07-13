/// Mileage Manual Entry Screen — camera + GPS + form with anti-fraud validation.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/mileage_bloc.dart';
import '../bloc/mileage_event.dart';
import '../bloc/mileage_state.dart';

class MileageManualEntryScreen extends StatefulWidget {
  const MileageManualEntryScreen({super.key});

  @override
  State<MileageManualEntryScreen> createState() => _MileageManualEntryScreenState();
}

class _MileageManualEntryScreenState extends State<MileageManualEntryScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  String? _photoPath;
  double? _photoLat;
  double? _photoLng;
  bool _capturingLocation = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() => _photoPath = photo.path);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _captureGps() async {
    setState(() => _capturingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showError('Activa el GPS para capturar ubicación');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _showError('Permiso de ubicación requerido');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _photoLat = pos.latitude;
        _photoLng = pos.longitude;
        _capturingLocation = false;
      });
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Ubicación capturada'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() => _capturingLocation = false);
      _showError('Error GPS: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _submit() {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showError('Ingresa un valor KM válido (positivo)');
      return;
    }
    if (amount > 1000) {
      _showError('Máximo 1000 KM por entrada (anti-fraude)');
      return;
    }
    if (_photoPath == null) {
      _showError('Toma una foto del odómetro');
      return;
    }

    context.read<MileageBloc>().add(SubmitManualEntry(
          amountKm: amount,
          odometerPhotoUrl: _photoPath!,
          photoLat: _photoLat,
          photoLng: _photoLng,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MileageBloc, MileageState>(
      listener: (context, state) {
        if (state is ManualEntrySubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ KM registrado — Pendiente de verificación'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
        if (state is MileageError) {
          _showError(state.message);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Registrar KM', style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            BlocBuilder<MileageBloc, MileageState>(
              builder: (context, state) {
                final saving = state is MileageLoading;
                return TextButton(
                  onPressed: saving ? null : _submit,
                  child: saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Text('ENVIAR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo section
              Text('FOTO DEL ODÓMETRO', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.mdCircular,
                    border: Border.all(
                      color: _photoPath != null ? AppColors.success : AppColors.border,
                      width: _photoPath != null ? 2 : 1,
                    ),
                  ),
                  child: _photoPath != null
                      ? ClipRRect(
                          borderRadius: AppRadius.mdCircular,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(_photoPath!), fit: BoxFit.cover),
                              Positioned(
                                top: AppSpacing.sm,
                                right: AppSpacing.sm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withAlpha(200),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('FOTO TOMADA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.textMuted.withAlpha(80)),
                            const SizedBox(height: AppSpacing.sm),
                            const Text('Tocar para tomar foto del odómetro',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // GPS section
              Text('UBICACIÓN GPS', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mdCircular,
                  border: Border.all(color: _photoLat != null ? AppColors.secondary : AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _photoLat != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _photoLat != null ? AppColors.secondary : AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _photoLat != null
                          ? Text('${_photoLat!.toStringAsFixed(5)}, ${_photoLng!.toStringAsFixed(5)}',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                            )
                          : const Text('Captura tu ubicación actual',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                    ),
                    TextButton.icon(
                      onPressed: _capturingLocation ? null : _captureGps,
                      icon: _capturingLocation
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: const Text('GPS', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount field
              Text('KILÓMETROS', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0.0',
                  hintStyle: TextStyle(color: AppColors.textMuted.withAlpha(60), fontSize: 32),
                  suffixText: 'KM',
                  suffixStyle: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: AppColors.input,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdCircular,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdCircular,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdCircular,
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Máx. 1000 KM por entrada. 1 entrada/día, 3/semana.',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),

              // Notes
              Text('NOTAS (OPCIONAL)', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ej: Ruta Bogotá - Medellín',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.input,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdCircular,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdCircular,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdCircular,
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Validation info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(10),
                  borderRadius: AppRadius.smCircular,
                  border: Border.all(color: AppColors.warning.withAlpha(40)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Validación anti-fraude',
                            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tu entrada será verificada por un administrador. '
                            'El KM debe estar entre 1 y 1000. Máximo 1 entrada por día, 3 por semana.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
