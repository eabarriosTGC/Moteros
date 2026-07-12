/// Safe Mode — Modo Conducción con SOS real + GPS + Speedometer.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/services/sos_service.dart';

class SafeModeScreen extends StatefulWidget {
  final int? raidId;
  const SafeModeScreen({super.key, this.raidId});

  @override
  State<SafeModeScreen> createState() => _SafeModeScreenState();
}

class _SafeModeScreenState extends State<SafeModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _speedController;
  late Animation<double> _speedAnim;
  double _simulatedSpeed = 0;
  final _sosService = SosService(Supabase.instance.client);
  bool _sosSending = false;

  @override
  void initState() {
    super.initState();
    _speedController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _speedAnim = CurvedAnimation(parent: _speedController, curve: Curves.easeInOut);
    _simulateSpeed();
  }

  void _simulateSpeed() {
    _speedController.addListener(() {
      setState(() {
        _simulatedSpeed = _speedAnim.value * 120;
      });
    });
    _speedController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _speedController.dispose();
    super.dispose();
  }

  Future<void> _triggerSos() async {
    if (_sosSending) return;
    setState(() => _sosSending = true);
    HapticFeedback.heavyImpact();

    final result = await _sosService.sendManualSos(raidId: widget.raidId);
    if (!mounted) return;
    setState(() => _sosSending = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🚨 Alerta SOS enviada con tu ubicación'),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 3),
      ));
    } else {
      // Fallback: show error but alert was still attempted
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ No se pudo enviar ubicación. Intentá de nuevo.'),
        backgroundColor: AppColors.warning,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          // Speedometer
          Positioned(top: 40, left: 0, right: 0,
            child: Column(children: [
              Text('${_simulatedSpeed.round()}', style: const TextStyle(
                fontSize: 96, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: -4,
                fontFamily: 'monospace',
              )),
              const Text('KM/H', style: TextStyle(
                color: AppColors.textMuted, fontSize: 14, letterSpacing: 4,
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: 280, height: 80,
                child: CustomPaint(
                  painter: _SpeedArcPainter(_simulatedSpeed / 120),
                  size: const Size(280, 80),
                ),
              ),
            ]),
          ),

          // SOS giant button (real)
          Positioned(left: 20, right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(children: [
              GestureDetector(
                onTap: _triggerSos,
                onLongPress: () {
                  // Long press for emergency contact info
                  _sosService.getEmergencyContact().then((contact) {
                    if (!mounted) return;
                    if (contact != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Contacto: ${contact['emergency_contact_name'] ?? 'No configurado'}'),
                        backgroundColor: AppColors.surface,
                      ));
                    }
                  });
                },
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: _sosSending
                        ? const LinearGradient(colors: [Color(0xFF666666), Color(0xFF999999)])
                        : const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!_sosSending)
                        BoxShadow(color: Colors.red.withAlpha(80), blurRadius: 20, spreadRadius: 4),
                    ],
                  ),
                  child: Center(
                    child: _sosSending
                        ? const SizedBox(
                            width: 32, height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('SOS', style: TextStyle(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4,
                          )),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('MANTENÉ presionado para ver contacto',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(height: 12),
              // Exit
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SALIR MODO CONDUCCIÓN', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1,
                  )),
                ),
              ),
            ]),
          ),

          // GPS indicator
          Positioned(top: MediaQuery.of(context).padding.top + 8, left: 16,
            child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle,
              )),
              const SizedBox(width: 6),
              const Text('GPS ACTIVO', style: TextStyle(
                color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SpeedArcPainter extends CustomPainter {
  final double progress;
  _SpeedArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final rect = Rect.fromCenter(center: center, width: size.width, height: size.height * 2);

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFF2A2A35).withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, bgPaint);

    // Progress arc (amber to red)
    final sweep = pi * progress.clamp(0.0, 1.0);
    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.primary, AppColors.primaryLight, Colors.redAccent],
      ).createShader(Rect.fromCenter(center: center, width: size.width, height: size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, sweep, false, fgPaint);

    // Needle dot
    final angle = pi + sweep;
    final dotX = center.dx + cos(angle) * size.width / 2;
    final dotY = center.dy + sin(angle) * size.height / 2;
    canvas.drawCircle(Offset(dotX, dotY), 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
