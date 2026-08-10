library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/raid_conquest_repository.dart';

class RaidArrivalScreen extends StatefulWidget {
  final Map<String, dynamic> raid;

  const RaidArrivalScreen({super.key, required this.raid});

  @override
  State<RaidArrivalScreen> createState() => _RaidArrivalScreenState();
}

class _RaidArrivalScreenState extends State<RaidArrivalScreen> {
  final _repository = RaidConquestRepository();
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false;
  bool _uploadingPhoto = false;
  Map<String, dynamic>? _arrival;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Activa el GPS para verificar tu llegada.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _error = 'La ubicación es necesaria para comprobar que llegaste al destino.');
      return false;
    }
    return true;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _arrival != null) return;
    final token = capture.barcodes.firstOrNull?.rawValue;
    if (token == null || !token.startsWith('asfaltoclub:arrival:v1:')) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    await _scanner.stop();

    try {
      if (!await _ensureLocationPermission()) {
        await _resumeScanner();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final arrival = await _repository.verifyArrival(
        raidId: (widget.raid['id'] as num).toInt(),
        qrToken: token,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _arrival = arrival;
        _processing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = RaidConquestRepository.friendlyError(error);
        _processing = false;
      });
      await _resumeScanner();
    }
  }

  Future<void> _resumeScanner() async {
    if (!mounted || _arrival != null) return;
    setState(() => _processing = false);
    await _scanner.start();
  }

  Future<void> _takeConquestPhoto() async {
    if (_arrival == null || _uploadingPhoto) return;
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1920,
    );
    if (photo == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      await _repository.attachPhoto(
        arrivalId: _arrival!['arrival_id'].toString(),
        bytes: await photo.readAsBytes(),
        caption: 'Fotoconquista · ${_arrival!['place_name']}',
      );
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoconquista guardada'), backgroundColor: AppColors.success),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RaidConquestRepository.friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('VERIFICAR LLEGADA'),
        backgroundColor: Colors.transparent,
      ),
      body: _arrival == null ? _scannerBody() : _successBody(),
    );
  }

  Widget _scannerBody() => Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          Container(color: Colors.black.withAlpha(45)),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: AppRadius.mdCircular,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processing) ...[
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Comprobando QR, GPS y horario…'),
                  ] else ...[
                    const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 32),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Escanea uno de los códigos instalados en el destino',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ],
      );

  Widget _successBody() {
    final km = (_arrival!['verified_km'] as num).toDouble();
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 96, color: AppColors.success),
            const SizedBox(height: AppSpacing.lg),
            Text('RUTA CONQUISTADA', style: AppTypography.h2.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _arrival!['place_name'].toString(),
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('${km.toStringAsFixed(1)} KM', style: AppTypography.monoLarge.copyWith(color: AppColors.primary)),
            const Text('kilómetros de ruta verificados', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploadingPhoto ? null : _takeConquestPhoto,
                icon: _uploadingPhoto
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: const Text('TOMAR FOTOCONQUISTA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAmber,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('AHORA NO'),
            ),
          ],
        ),
      ),
    );
  }
}
