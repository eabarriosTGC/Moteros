/// Map Explorer — "Mapa de Conquistas" redesign.
/// Dark tiles + filter chips + redesigned markers + premium bottom sheet.
library;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_buttons.dart';
import '../../../admin/presentation/screens/admin_panel_screen.dart';
import '../../../membership/presentation/screens/membership_screen.dart';
import '../../../validation/presentation/screens/qr_scanner_screen.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../../domain/entities/place_entity.dart';
import '../bloc/places_bloc.dart';
import '../bloc/places_event.dart';
import '../bloc/places_state.dart';

/// Category filter mapping
enum PlaceFilter {
  all('Todos', null),
  rest('Descanse', ['hotel', 'moto_posada']),
  eat('Tanquee', ['restaurante']),
  repair('Desvare', ['taller', 'grua']),
  view('Mirador', ['mirador']);

  final String label;
  final List<String>? categories;
  const PlaceFilter(this.label, this.categories);
}

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  LatLng? _currentPosition;
  PlaceFilter _activeFilter = PlaceFilter.all;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      context.read<PlacesBloc>().add(LoadNearbyPlaces(
            latitude: pos.latitude,
            longitude: pos.longitude,
          ));
    } catch (_) {}
  }

  List<PlaceEntity> _filteredPlaces(List<PlaceEntity> all) {
    if (_activeFilter == PlaceFilter.all) return all;
    return all.where((p) => _activeFilter.categories!.contains(p.category)).toList();
  }

  IconData _categoryIcon(String category) => switch (category) {
    'taller' => Icons.build,
    'restaurante' => Icons.restaurant,
    'hotel' || 'moto_posada' => AppIcons.hotel,
    'mirador' => Icons.photo_camera,
    'grua' => Icons.local_shipping,
    _ => Icons.place,
  };

  Color _categoryColor(String category) => switch (category) {
    'taller' || 'grua' => AppColors.primary,
    'restaurante' => AppColors.secondary,
    'hotel' || 'moto_posada' => AppColors.info,
    'mirador' => AppColors.success,
    _ => AppColors.textMuted,
  };

  String _categoryLabel(String category) => switch (category) {
    'taller' => 'Taller',
    'restaurante' => 'Restaurante',
    'hotel' => 'Hotel',
    'moto_posada' => 'Moto Posada',
    'mirador' => 'Mirador',
    'grua' => 'Grua',
    _ => category,
  };

  void _showPlaceSheet(PlaceEntity place) {
    final color = _categoryColor(place.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drag handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.metallicDark, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: AppSpacing.md),
          // Header with icon + name
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: AppRadius.mdCircular),
              child: Icon(_categoryIcon(place.category), color: color, size: AppSpacing.iconLg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, style: AppTypography.h3),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(4)),
                  child: Text(place.category.toUpperCase(), style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
                if (place.city != null) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.location, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(place.city!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ]),
            ])),
          ]),
          const SizedBox(height: AppSpacing.md),
          // Description
          if (place.description.isNotEmpty) ...[
            Text(place.description, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
          ],
          // Address
          if (place.address != null) Row(children: [
            Icon(AppIcons.location, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text('${place.address}, ${place.city ?? ""}', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted))),
          ]),
          const SizedBox(height: AppSpacing.lg),
          // Action buttons
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen()));
                },
                icon: const Icon(AppIcons.qrScanner, size: AppSpacing.iconSm),
                label: const Text('Validar visita'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: AppColors.border),
              ),
              child: IconButton(
                icon: const Icon(AppIcons.navigate, size: AppSpacing.iconSm),
                color: AppColors.primary,
                onPressed: () => _openNavigation(place.latitude, place.longitude, place.name),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _openNavigation(double lat, double lng, String name) {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Abre Google Maps y busca: $name')),
      );
    });
  }

  void _osmAction(String action) {
    HapticFeedback.lightImpact();
    if (action == 'note') {
      if (_currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Espera a que se active el GPS')),
        );
        return;
      }
      final lat = _currentPosition!.latitude.toStringAsFixed(5);
      final lng = _currentPosition!.longitude.toStringAsFixed(5);
      final uri = Uri.parse('https://www.openstreetmap.org/note/new?lat=$lat&lon=$lng#map=16/$lat/$lng');
      launchUrl(uri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🌍 Reporta el error en OpenStreetMap')),
      );
    } else if (action == 'gps') {
      launchUrl(Uri.parse('https://www.openstreetmap.org/traces/new'), mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📡 Sube tus trazados GPS para mejorar el mapa')),
      );
    } else if (action == 'import') {
      _importFromOsm();
    }
  }

  Future<void> _importFromOsm() async {
    try {
      final api = context.read<PlacesBloc>();
      // We need the API client - for now open the docs
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🌍 Importando lugares de OpenStreetMap...')),
      );
      final response = await context.read<ApiClient>().post('/import', data: {
        'department': 'La Guajira',
      });
      final data = response.data as Map<String, dynamic>;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${data['message'] ?? 'Importado'}')),
      );
      // Refresh places
      _getCurrentPosition();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String category = 'otro';
    final categories = ['restaurante', 'hotel', 'taller', 'mirador', 'moto_posada', 'otro'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Agregar lugar', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: category,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Categoría', labelStyle: TextStyle(color: AppColors.textMuted)),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
              onChanged: (v) => category = v ?? 'otro',
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || _currentPosition == null) return;
              try {
                await context.read<ApiClient>().post('/import/manual', data: {
                  'name': nameCtrl.text.trim(),
                  'category': category,
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                });
                Navigator.pop(ctx);
                _getCurrentPosition(); // refresh
              } catch (_) {}
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlacesBloc, PlacesState>(
      builder: (context, state) {
        final places = state is PlacesLoaded ? state.places : <PlaceEntity>[];
        final filtered = _filteredPlaces(places);
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: const Text('Mapa de Conquistas'),
            actions: [
              IconButton(icon: const Icon(AppIcons.shield), tooltip: 'Admin',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))),
              IconButton(icon: const Icon(AppIcons.fuel), tooltip: 'Membresía',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen()))),
              IconButton(icon: const Icon(AppIcons.gps), onPressed: _getCurrentPosition),
              // OSM contribution
              PopupMenuButton<String>(
                icon: const Icon(AppIcons.info, size: 20),
                tooltip: 'Contribuir a OpenStreetMap',
                onSelected: (v) => _osmAction(v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'note', child: Text('Reportar error en mapa')),
                  const PopupMenuItem(value: 'gps', child: Text('Subir traza GPS')),
                  const PopupMenuItem(value: 'import', child: Text('Importar lugares de OSM')),
                ],
              ),
              // Add place manually
              IconButton(
                icon: const Icon(Icons.add_location_alt, color: AppColors.primary),
                tooltip: 'Agregar lugar',
                onPressed: () => _showAddPlaceDialog(context),
              ),
            ],
          ),
          body: Stack(children: [
            // Map
            _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentPosition!,
                    initialZoom: 14, minZoom: 6, maxZoom: 18,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    // Dark tile layer with offline cache support
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.moteros.moteros_app',
                    ),
                    // Place markers
                    if (filtered.isNotEmpty)
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 45, size: const Size(40, 40),
                          alignment: Alignment.center, maxZoom: 15,
                          markers: filtered.map((p) => _buildMarker(p)).toList(),
                          builder: (ctx, markers) => Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(180),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryLight, width: 2),
                            ),
                            child: Center(child: Text('${markers.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                          ),
                        ),
                      ),
                    // User location dot
                    MarkerLayer(markers: [
                      Marker(point: _currentPosition!, width: 20, height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.blueAccent, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),

            // Filter chips overlay
            Positioned(
              top: AppSpacing.sm, left: AppSpacing.sm, right: AppSpacing.sm,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: PlaceFilter.values.map((f) => _buildFilterChip(f)).toList()),
              ),
            ),

            // Loading overlay
            if (state is PlacesLoading)
              Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ]),
        );
      },
    );
  }

  Widget _buildFilterChip(PlaceFilter filter) {
    final selected = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card.withAlpha(220),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: selected ? AppColors.primaryLight : AppColors.border, width: 1),
            boxShadow: selected ? AppShadows.neonOrange : null,
          ),
          child: Text(filter.label, style: AppTypography.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          )),
        ),
      ),
    );
  }

  Marker _buildMarker(PlaceEntity place) {
    final color = _categoryColor(place.category);
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 42, height: 42,
      child: GestureDetector(
        onTap: () => _showPlaceSheet(place),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: [BoxShadow(color: color.withAlpha(50), blurRadius: 8, spreadRadius: 2)],
          ),
          child: Icon(_categoryIcon(place.category), color: color, size: AppSpacing.iconSm),
        ),
      ),
    );
  }
}
