/// ConquestPhotoButton — W4 (M-CPU-1/2) control de fotos post-viaje.
///
/// Reemplaza el placeholder 'Fotos — próximamente' del summary: pick
/// (image_picker) → upload al bucket `conquest-photos` → insert en
/// `conquest_photos` vía `insertConquestPhoto` (primera invocación real).
///
/// Raid-linked (raidId != null): upload + insert INMEDIATO con
/// `source: 'raid'`, `sourceId: raidId` (M-CPU-2).
///
/// Standalone: upload inmediato + la fila se ENCOLA hasta que
/// `TrackerSaveSucceeded` entregue `savedRouteId` (insert con
/// `source: 'route'`, `sourceId: savedRouteId`). Si `TrackerSaveFailed` →
/// SnackBar "Guarda la ruta para adjuntar las fotos" y la cola NO se vacía
/// (reintento posible). RESIDUAL DOCUMENTADO: el archivo ya subido queda
/// huérfano en storage si el viaje nunca se guarda — aceptado (design §4.1).
/// La fila NUNCA se inserta con `source_id` null.
///
/// Extraído como widget aislado (patrón `WaypointHudButton`/`PostTripSaveFeedback`)
/// para testear el flujo sin FlutterMap (el stream de tiles cuelga el harness
/// bajo FakeAsync — precedente del repo). Picker/uploader/inserter son seams
/// inyectables (patrón typedef `whatsapp_launcher`).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../showcase/data/repositories/conquest_photo_repository.dart';
import '../screens/route_tracker_screen.dart'; // TrackerBloc/TrackerState

/// Picker seam: abre la galería y devuelve el archivo elegido (null si el
/// usuario cancela). I/O de plataforma → inyectable en tests.
typedef PhotoPickerFn = Future<XFile?> Function();

class ConquestPhotoButton extends StatefulWidget {
  const ConquestPhotoButton({
    super.key,
    required this.userId,
    this.raidId,
    this.uploader,
    this.inserter,
    this.pickImage,
  });

  /// Owner de la foto (deriva de `auth.currentUser.id` en el caller). El
  /// prefijo del path de storage lo exige (cp_insert_own, migración 029).
  final String userId;

  /// Raid del viaje cuando es raid-linked (M-RTR-1). Null → standalone.
  final int? raidId;

  /// Upload seam (storage + getPublicUrl). Default: [uploadConquestPhoto].
  final ConquestPhotoUploader? uploader;

  /// Insert seam (insertConquestPhoto). Default: [insertConquestPhotoRow].
  final ConquestPhotoInserter? inserter;

  /// Picker seam. Default: galería con maxWidth/Height 1920, calidad 85
  /// (patrón mileage_manual_entry).
  final PhotoPickerFn? pickImage;

  @override
  State<ConquestPhotoButton> createState() => _ConquestPhotoButtonState();
}

class _ConquestPhotoButtonState extends State<ConquestPhotoButton> {
  /// Cola local standalone: fotos subidas pero sin fila todavía (esperan
  /// `savedRouteId` de TrackerSaveSucceeded). Residual documentado: si el
  /// save falla y el usuario descarta, el objeto en storage queda huérfano.
  final List<({String photoUrl, String? caption})> _pendingInserts = [];
  bool _uploading = false;

  ConquestPhotoUploader get _uploader =>
      widget.uploader ?? uploadConquestPhoto;

  ConquestPhotoInserter get _inserter =>
      widget.inserter ?? insertConquestPhotoRow;

  PhotoPickerFn get _picker => widget.pickImage ?? _pickFromGallery;

  static Future<XFile?> _pickFromGallery() {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  }

  Future<void> _addPhoto() async {
    HapticFeedback.lightImpact();
    if (_uploading) return;
    final XFile? picked;
    try {
      picked = await _picker();
    } catch (_) {
      return; // picker falló/canceló — sin feedback
    }
    if (picked == null) return; // cancelado

    setState(() => _uploading = true);
    try {
      final photoUrl =
          await _uploader(File(picked.path), userId: widget.userId);
      final raidId = widget.raidId;
      if (raidId != null) {
        // Raid-linked: insert inmediato (source 'raid', sourceId raidId).
        final src = resolveConquestPhotoSource(raidId: raidId);
        await _inserter(
          userId: widget.userId,
          source: src.source,
          sourceId: src.sourceId,
          photoUrl: photoUrl,
        );
      } else {
        // Standalone: upload inmediato, fila encolada hasta savedRouteId.
        _pendingInserts.add((photoUrl: photoUrl, caption: null));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto añadida'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo añadir la foto: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Flush de la cola standalone con el savedRouteId entregado por el save.
  /// La fila se inserta SOLO si el sourceId resuelto es no-null (nunca
  /// `source_id` null — M-CPU-2). En error, el item vuelve a la cola.
  Future<void> _flushPending(String savedRouteId) async {
    if (_pendingInserts.isEmpty) return;
    final pending = List.of(_pendingInserts);
    _pendingInserts.clear();
    for (final p in pending) {
      try {
        final src = resolveConquestPhotoSource(savedRouteId: savedRouteId);
        await _inserter(
          userId: widget.userId,
          source: src.source,
          sourceId: src.sourceId,
          photoUrl: p.photoUrl,
          caption: p.caption,
        );
      } catch (e) {
        _pendingInserts.add(p);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo adjuntar la foto: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackerBloc, TrackerState>(
      listenWhen: (_, state) =>
          state is TrackerSaveSucceeded || state is TrackerSaveFailed,
      listener: (context, state) {
        if (state is TrackerSaveSucceeded) {
          _flushPending(state.savedRouteId);
        } else if (state is TrackerSaveFailed && _pendingInserts.isNotEmpty) {
          // La cola NO se vacía (reintento posible); el archivo subido queda
          // huérfano en storage si el usuario descarta — residual documentado.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guarda la ruta para adjuntar las fotos'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: OutlinedButton.icon(
        onPressed: _addPhoto,
        icon: const Icon(Icons.photo_camera_outlined, size: 18),
        label: const Text(
          'AÑADIR FOTOS',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.secondary),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
