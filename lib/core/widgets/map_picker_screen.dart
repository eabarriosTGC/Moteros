/// MapPickerScreen — full-screen map to pick a location by tapping.
/// Returns [lat, lng] via Navigator.pop.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapPickerScreen({
    super.key,
    this.initialLat = 4.60971,
    this.initialLng = -74.08175,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selected;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(widget.initialLat, widget.initialLng);
    _getPosition();
  }

  Future<void> _getPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _selected = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  void _onTap(TapPosition tapPos, LatLng latlng) {
    setState(() => _selected = latlng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, [_selected.latitude, _selected.longitude]),
            child: const Text('CONFIRMAR', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _currentPosition ?? _selected,
              initialZoom: 15,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // User dot
              if (_currentPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _currentPosition!,
                    width: 20, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ]),
              // Selected marker
              MarkerLayer(markers: [
                Marker(
                  point: _selected,
                  width: 40, height: 40,
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 40),
                ),
              ]),
            ],
          ),
          // Crosshair hint at bottom
          Positioned(
            left: 0, right: 0, bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(220),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
