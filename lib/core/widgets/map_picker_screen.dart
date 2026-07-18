/// MapPickerScreen — full-screen map to pick a location by tapping.
/// Returns [lat, lng] via Navigator.pop.
/// Now with reverse geocoding and place search.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';
import '../services/geocoding_service.dart';
import '../services/offline_map_service.dart';

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
  String _address = '';
  bool _loadingAddress = false;

  // Search
  final _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(widget.initialLat, widget.initialLng);
    _getPosition();
    _reverseGeocode(_selected.latitude, _selected.longitude);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _reverseGeocode(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _loadingAddress = true);
    final addr = await GeocodingService.reverseGeocode(lat, lng);
    if (mounted) {
      setState(() {
        _address = addr;
        _loadingAddress = false;
      });
    }
  }

  void _onTap(TapPosition tapPos, LatLng latlng) {
    HapticFeedback.lightImpact();
    setState(() => _selected = latlng);
    _reverseGeocode(latlng.latitude, latlng.longitude);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await GeocodingService.searchPlaces(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  void _selectSearchResult(GeocodingResult result) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selected = LatLng(result.lat, result.lng);
      _address = result.displayName;
      _searchResults = [];
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context, [_selected.latitude, _selected.longitude],
            ),
            child: const Text(
              'CONFIRMAR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
            ),
            child: TextField(
              controller: _searchController,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar lugar...',
                hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _searchPlaces,
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty || _searching)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              color: AppColors.surface,
              child: _searching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary, size: 20,
                          ),
                          title: Text(
                            r.displayName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
            ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentPosition ?? _selected,
                    initialZoom: 15,
                    onTap: _onTap,
                  ),
                  children: [
                    TileLayer(
                      tileProvider: OfflineMapService.tileProvider(),
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
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
                    MarkerLayer(markers: [
                      Marker(
                        point: _selected,
                        width: 40, height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary, size: 40,
                        ),
                      ),
                    ]),
                  ],
                ),
                // Address banner
                Positioned(
                  left: AppSpacing.md, right: AppSpacing.md,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withAlpha(230),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _loadingAddress
                              ? Icons.hourglass_top
                              : Icons.location_on_outlined,
                          color: AppColors.primary, size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _loadingAddress ? 'Obteniendo dirección...' : _address,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
