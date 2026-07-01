import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/validation_bloc.dart';
import '../bloc/validation_event.dart';
import '../bloc/validation_state.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _picker = ImagePicker();
  String? _evidencePath;

  @override
  void dispose() {
    _evidencePath = null;
    super.dispose();
  }

  Future<void> _captureEvidence() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (file != null && mounted) {
      setState(() => _evidencePath = file.path);
    }
  }

  void _submitValidation(ReadyToValidate state) {
    context.read<ValidationBloc>().add(ValidateVisitSubmitted(
          latitude: state.latitude,
          longitude: state.longitude,
          evidenceUrl: _evidencePath,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ValidationBloc, ValidationState>(
      listener: (context, state) {
        if (state is QrCaptured) {
          _captureGps(state);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Validar Destino'),
            actions: [
              if (state is ReadyToValidate || state is ValidationError)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      context.read<ValidationBloc>().add(ResetValidation()),
                ),
            ],
          ),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(ValidationState state) {
    return switch (state) {
      ValidationInitial() => _buildScanner(),
      WaitingForGps() => _buildGpsWait(state),
      ReadyToValidate() => _buildConfirm(state),
      Validating() => _buildLoading(),
      VisitVerified() => _buildSuccess(state),
      ValidationError() => _buildError(state),
      QrCaptured() => const SizedBox.shrink(),
    };
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null &&
                barcode!.rawValue!.isNotEmpty &&
                context.read<ValidationBloc>().state is ValidationInitial) {
              context
                  .read<ValidationBloc>()
                  .add(QrCodeScanned(barcode.rawValue!));
            }
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.secondaryColor,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            'Apunta al QR del lugar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _captureGps(QrCaptured state) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          context
              .read<ValidationBloc>()
              .add(ResetValidation());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activa el GPS para continuar')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          context
              .read<ValidationBloc>()
              .add(ResetValidation());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicacion denegado')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        context.read<ValidationBloc>().add(GpsReady(
              qrToken: state.qrToken,
              latitude: position.latitude,
              longitude: position.longitude,
            ));
      }
    } catch (e) {
      if (mounted) {
        context.read<ValidationBloc>().add(ResetValidation());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al obtener ubicacion')),
        );
      }
    }
  }

  Widget _buildGpsWait(WaitingForGps state) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, size: 64, color: AppTheme.secondaryColor),
          SizedBox(height: 16),
          Text('QR detectado. Obteniendo ubicacion...',
              style: TextStyle(color: Colors.white70)),
          SizedBox(height: 24),
          CircularProgressIndicator(color: AppTheme.secondaryColor),
        ],
      ),
    );
  }

  Widget _buildConfirm(ReadyToValidate state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 80, color: AppTheme.secondaryColor),
          const SizedBox(height: 24),
          const Text('QR y ubicacion listos',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _infoRow(Icons.qr_code, 'QR Token',
              state.qrToken.length > 20
                  ? '${state.qrToken.substring(0, 20)}...'
                  : state.qrToken),
          const SizedBox(height: 8),
          _infoRow(Icons.location_on, 'Latitud',
              state.latitude.toStringAsFixed(6)),
          _infoRow(Icons.location_on, 'Longitud',
              state.longitude.toStringAsFixed(6)),
          if (_evidencePath != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.image, 'Evidencia', 'Foto capturada'),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _captureEvidence,
                  icon: Icon(
                    _evidencePath != null ? Icons.check_circle : Icons.camera_alt,
                  ),
                  label: Text(_evidencePath != null
                      ? 'Foto lista'
                      : 'Tomar evidencia'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitValidation(state),
                  icon: const Icon(Icons.verified),
                  label: const Text('Validar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13))),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.secondaryColor),
          SizedBox(height: 24),
          Text('Validando visita...',
              style: TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSuccess(VisitVerified state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            const Text('Visita verificada!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Lugar #${state.placeId}',
                style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ValidationBloc>().add(ResetValidation());
                _evidencePath = null;
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear otro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al mapa',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ValidationError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text('Validacion fallida',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ValidationBloc>().add(ResetValidation());
                _evidencePath = null;
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al mapa',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
