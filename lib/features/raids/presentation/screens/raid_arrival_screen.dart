library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/raid_conquest_repository.dart';
import '../scanner_lifecycle.dart';

class RaidArrivalScreen extends StatefulWidget {
  const RaidArrivalScreen({
    super.key,
    required this.raid,
    this.repository,
    this.positionResolver,
  });

  final Map<String, dynamic> raid;

  /// Seam de testabilidad: repository fake.
  final RaidConquestRepository? repository;

  /// Seam de testabilidad: sustituye permiso GPS + getCurrentPosition.
  final Future<Position?> Function()? positionResolver;

  @override
  State<RaidArrivalScreen> createState() => _RaidArrivalScreenState();
}

class _RaidArrivalScreenState extends State<RaidArrivalScreen>
    with WidgetsBindingObserver {
  late final RaidConquestRepository _repository =
      widget.repository ?? RaidConquestRepository();

  late final MobileScannerController _scanner = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final ScannerLifecycle _lifecycle = ScannerLifecycle(
    requestCameraPermission: () async {
      final status = await Permission.camera.request();
      return status.isGranted;
    },
    startCamera: () => _scanner.start(),
    stopCamera: () => _scanner.stop(),
  );

  bool _processing = false;
  bool _uploadingPhoto = false;
  Map<String, dynamic>? _arrival;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // La cámara arranca después del primer frame y solo si mounted: la app
    // administra el ciclo de vida (autoStart: false).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lifecycle.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle.onLifecycleChanged(state);
  }

  Future<Position?> _resolvePosition() async {
    final resolver = widget.positionResolver;
    if (resolver != null) return resolver();
    if (!await _ensureLocationPermission()) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
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

  /// Punto de entrada del escáner. Separado de [MobileScanner.onDetect] para
  /// poder testear el flujo sin cámara real.
  @visibleForTesting
  Future<void> handleDetectedBarcode(String? raw) async {
    if (_processing || _arrival != null) return;
    // Tokens ajenos se ignoran: no se toca red ni kilometraje.
    if (!isValidArrivalToken(raw)) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    await _lifecycle.pauseForVerification();

    try {
      final position = await _resolvePosition();
      if (position == null) {
        await _lifecycle.resume();
        return;
      }
      final arrival = await _repository.verifyArrival(
        raidId: (widget.raid['id'] as num).toInt(),
        qrToken: raw!,
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
      await _lifecycle.resume();
    }
  }

  Future<void> _startScanner() async {
    setState(() => _error = null);
    await _lifecycle.retry();
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
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
          _buildScannerArea(),
          if (_lifecycle.phase == ScannerPhase.ready) ...[
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
          ],
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

  /// Área de cámara según la fase del ciclo de vida. Nunca se muestra el
  /// error nativo de CameraX: cada fase tiene su vista de recuperación.
  Widget _buildScannerArea() {
    switch (_lifecycle.phase) {
      case ScannerPhase.permissionDenied:
        return _ScannerMessageView(
          icon: Icons.no_photography_outlined,
          title: 'Necesitamos la cámara',
          message:
              'Concede el permiso de cámara para escanear el código de llegada del destino.',
          onRetry: _startScanner,
          onOpenSettings: _openAppSettings,
        );
      case ScannerPhase.unavailable:
      case ScannerPhase.error:
        return _ScannerMessageView(
          icon: Icons.videocam_off_outlined,
          title: 'No pudimos iniciar la cámara',
          message:
              'Verifica que ninguna otra app esté usando la cámara e inténtalo de nuevo.',
          onRetry: _startScanner,
          onOpenSettings: _openAppSettings,
        );
      case ScannerPhase.initializing:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case ScannerPhase.ready:
        return MobileScanner(
          controller: _scanner,
          onDetect: (capture) =>
              handleDetectedBarcode(capture.barcodes.firstOrNull?.rawValue),
          errorBuilder: (context, error) => _ScannerMessageView(
            icon: Icons.videocam_off_outlined,
            title: 'No pudimos iniciar la cámara',
            message:
                'Verifica que ninguna otra app esté usando la cámara e inténtalo de nuevo.',
            onRetry: _startScanner,
            onOpenSettings: _openAppSettings,
          ),
          placeholderBuilder: (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
    }
  }

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

/// Vista de recuperación del escáner: mensaje claro + REINTENTAR +
/// ABRIR AJUSTES (para denegación permanente).
class _ScannerMessageView extends StatelessWidget {
  const _ScannerMessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(title,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(message,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('REINTENTAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('ABRIR AJUSTES'),
          ),
        ],
      ),
    );
  }
}
