/// Map Picker Screen — Seleccionar ubicación en mapa OSM.
/// Lets users pick a location by tapping/dragging the map. Returns lat/lng.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/design_tokens.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String title;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.title = 'Seleccionar ubicación',
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973); // Bogotá

  final MapController _mapController = MapController();
  LatLng _center = _defaultCenter;
  LatLng? _currentPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() => _isLoadingLocation = false);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLoadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final position = LatLng(pos.latitude, pos.longitude);
      if (widget.initialLatitude == null || widget.initialLongitude == null) {
        _center = position;
        _mapController.move(position, 15);
      }
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          setState(() {
            _currentPosition = LatLng(lastPos.latitude, lastPos.longitude);
            _isLoadingLocation = false;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _confirmLocation() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, {
      'latitude': _center.latitude,
      'longitude': _center.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppTypography.h2.copyWith(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Map area
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    minZoom: 6,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd ||
                          event is MapEventFlingAnimationEnd) {
                        setState(() => _center = event.camera.center);
                      }
                    },
                  ),
                  children: [
                    // Dark tile layer (same as map_explorer_screen)
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.moteros.moteros_app',
                    ),
                    // User location dot (when GPS available)
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition!,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.textPrimary,
                                  width: 2,
                                ),
                                boxShadow: AppShadows.cyanGlow,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Centered pin icon — stays in the middle regardless of pan
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pin shaft
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withAlpha(180),
                              AppColors.primary.withAlpha(60),
                            ],
                          ),
                        ),
                      ),
                      // Pin head
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryLight,
                              AppColors.primary,
                            ],
                          ),
                          boxShadow: AppShadows.amberGlow,
                          border: Border.all(
                            color: Colors.white.withAlpha(80),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                // Loading indicator
                if (_isLoadingLocation)
                  Container(
                    color: AppColors.overlay,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Coordinates display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gps_fixed,
                  color: AppColors.primary,
                  size: AppSpacing.iconSm,
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UBICACIÓN SELECCIONADA',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _confirmLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAmber,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdCircular,
                  ),
                  elevation: 0,
                  shadowColor: AppColors.primaryGlow,
                ),
                child: Text(
                  'CONFIRMAR UBICACIÓN',
                  style: AppTypography.button.copyWith(
                    color: AppColors.textOnAmber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
