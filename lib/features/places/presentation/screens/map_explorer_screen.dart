import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/place_entity.dart';
import '../bloc/places_bloc.dart';
import '../bloc/places_event.dart';
import '../bloc/places_state.dart';

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      context.read<PlacesBloc>().add(LoadNearbyPlaces(
            latitude: position.latitude,
            longitude: position.longitude,
          ));
    } catch (_) {}
  }

  Marker _buildMarker(PlaceEntity place) {
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showPlaceDetails(place),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
          child: Icon(
            _iconForCategory(place.category),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'taller' => Icons.build,
      'restaurante' => Icons.restaurant,
      'hotel' || 'moto_posada' => Icons.hotel,
      'mirador' => Icons.photo_camera,
      'grua' => Icons.local_shipping,
      _ => Icons.place,
    };
  }

  void _showPlaceDetails(PlaceEntity place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForCategory(place.category),
                    color: AppTheme.secondaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (place.category.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  place.category.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (place.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(place.description,
                  style: const TextStyle(color: Colors.white70)),
            ],
            if (place.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${place.address!}, ${place.city ?? ''}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlacesBloc, PlacesState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Explorar Rutas'),
            actions: [
              IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: _getCurrentPosition,
              ),
            ],
          ),
          body: _currentPosition == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.secondaryColor,
                      ),
                      SizedBox(height: 16),
                      Text('Obteniendo ubicación...',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _currentPosition!,
                        initialZoom: 14,
                        minZoom: 6,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.moteros.moteros_app',
                        ),
                        if (state is PlacesLoaded)
                          MarkerClusterLayerWidget(
                            options: MarkerClusterLayerOptions(
                              maxClusterRadius: 45,
                              size: const Size(40, 40),
                              alignment: Alignment.center,
                              maxZoom: 15,
                              markers: state.places
                                  .map<Marker>(_buildMarker)
                                  .toList(),
                              builder: (context, markers) => Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${markers.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.blueAccent,
                                        blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
          floatingActionButton: state is PlacesLoading
              ? const FloatingActionButton(
                  onPressed: null,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : null,
        );
      },
    );
  }
}
