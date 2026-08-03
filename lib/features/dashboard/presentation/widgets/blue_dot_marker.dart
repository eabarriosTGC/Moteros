/// Blue dot marker for the Rodar map — shows user's current location
/// with a heading indicator arrow.
///
/// Visual: Google Maps-style blue dot (8dp radius) with white border (2dp)
/// and an outer glow. A small triangle rotates with the device heading.
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BlueDotMarker extends StatelessWidget {
  final LatLng position;
  final double heading;

  static const _blue = Color(0xFF4285F4);
  static const _blueLight = Color(0xFF6BA3F7);
  static const _radius = 8.0;

  const BlueDotMarker({
    super.key,
    required this.position,
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Outer glow ring ──
          Container(
            width: _radius * 4,
            height: _radius * 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue.withAlpha(50),
            ),
          ),
          // ── Blue dot with white border ──
          Container(
            width: _radius * 2,
            height: _radius * 2,
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blueLight, _blue],
              ),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _blue.withAlpha(80),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // ── Heading indicator (triangle arrow) ──
          Transform.rotate(
            angle: heading * (3.14159 / 180),
            child: CustomPaint(
              size: const Size(16, 16),
              painter: _HeadingArrowPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a small white pointing arrow for the heading indicator.
class _HeadingArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2, -1) // tip (points up = 0°)
      ..lineTo(size.width / 2 - 3, size.height / 2 + 1)
      ..lineTo(size.width / 2 + 3, size.height / 2 + 1)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
