/// Map Explorer — "Mapa de Conquistas" redesign.
/// Dark tiles + filter chips + redesigned markers + premium bottom sheet.
library;
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
import '../../../../core/services/offline_map_service.dart';
import '../../../admin/presentation/screens/admin_panel_screen.dart';
import '../../../membership/presentation/screens/membership_screen.dart';
import '../../../validation/presentation/screens/qr_scanner_screen.dart';
import '../../../refugios/presentation/screens/create_motoposada_screen.dart';
import '../../../refugios/presentation/screens/my_motoposada_screen.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';
import '../../domain/entities/place_entity.dart';
import '../bloc/places_bloc.dart';
import '../bloc/places_event.dart';
import '../bloc/places_state.dart';

/// Category filter mapping — extended with place type boolean filters
enum PlaceFilter {
  all('Todos', null),
  workshop('Taller 🔧', 'workshop'),
  hospital('Hospital 🏥', 'hospital'),
  gasStation('Gasolinera ⛽', 'gas_station'),
  tourist('Turístico 🗺️', 'tourist_spot'),
  motoposada('Motoposada 🏠', 'moto_posada');

  final String label;
  final String? typeKey;
  const PlaceFilter(this.label, this.typeKey);

  /// Check if a PlaceEntity matches this filter
  bool matches(PlaceEntity place) {
    if (this == PlaceFilter.all) return true;
    return switch (typeKey) {
      'workshop' => place.isWorkshop,
      'hospital' => place.isHospital,
      'gas_station' => place.isGasStation,
      'tourist_spot' => place.isTouristSpot,
      'moto_posada' => place.isMotoposada,
      _ => false,
    };
  }
}

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  LatLng? _currentPosition;
  LatLng? _selectedPosition;
  PlaceFilter _activeFilter = PlaceFilter.all;
  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(4.5709, -74.2973); // Bogotá, Colombia

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Activa el GPS para ver tu ubicación en el mapa'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Sin permiso de ubicación — no podemos mostrarte en el mapa'),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📍 Permiso de ubicación denegado permanentemente. Actívalo en Ajustes'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      context.read<PlacesBloc>().add(LoadNearbyPlaces(
            latitude: pos.latitude,
            longitude: pos.longitude,
          ));
    } catch (e) {
      if (!mounted) return;
      // Fallback: try last known position
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          final ll = LatLng(lastPos.latitude, lastPos.longitude);
          setState(() => _currentPosition = ll);
          _mapController.move(ll, 15);
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ No se pudo obtener ubicación: $e')),
      );
    }
  }

  List<PlaceEntity> _filteredPlaces(List<PlaceEntity> all) {
    return all.where((p) => _activeFilter.matches(p)).toList();
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
      return false;
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPosition != null
                          ? '📍 ${_selectedPosition!.latitude.toStringAsFixed(4)}, ${_selectedPosition!.longitude.toStringAsFixed(4)}'
                          : 'Toca el mapa para elegir ubicación',
                      style: TextStyle(
                        color: _selectedPosition != null ? AppColors.textPrimary : AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_selectedPosition != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedPosition = null),
                      child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                    ),
                ],
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || _selectedPosition == null) return;
              try {
                await context.read<ApiClient>().post('/import/manual', data: {
                  'name': nameCtrl.text.trim(),
                  'category': category,
                  'latitude': _selectedPosition!.latitude,
                  'longitude': _selectedPosition!.longitude,
                });
                Navigator.pop(ctx);
                _selectedPosition = null;
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
            // Map — always rendered, even without GPS
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition ?? _defaultCenter,
                initialZoom: 14, minZoom: 6, maxZoom: 18,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                onTap: (_, latLng) => setState(() => _selectedPosition = latLng),
              ),
                  children: [
                    // Dark tile layer with offline cache support
                    TileLayer(
                      tileProvider: OfflineMapService.tileProvider(),
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
                    // User location dot (only when GPS available)
                    if (_currentPosition != null)
                      MarkerLayer(markers: [
                        Marker(point: _currentPosition!, width: 22, height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.secondary, shape: BoxShape.circle,
                            border: Border.all(color: AppColors.textPrimary, width: 3),
                            boxShadow: AppShadows.cyanGlow,
                          ),
                        ),
                      ),
                    ]),
                    // Selected place marker (tapped location)
                    if (_selectedPosition != null)
                      MarkerLayer(markers: [
                        Marker(point: _selectedPosition!, width: 36, height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withAlpha(150), blurRadius: 12, spreadRadius: 2),
                              ],
                            ),
                            child: const Icon(Icons.add_location, color: Colors.white, size: 20),
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
              Container(color: AppColors.overlay, child: const Center(child: CircularProgressIndicator())),

            // ── Refugios Action Bar ──
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: AppSpacing.md, right: AppSpacing.md,
                  top: AppSpacing.sm,
                  bottom: MediaQuery.of(context).padding.bottom + 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(220),
                  border: Border(top: BorderSide(color: AppColors.border.withAlpha(60))),
                ),
                child: Row(children: [
                  // SOS button
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeModeScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.red.withAlpha(60), blurRadius: 8, spreadRadius: 1)],
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.warning, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Ofrecer motoposada
                  _barBtn(Icons.home_outlined, 'OFRECER', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMotoposadaScreen()))),
                  _barBtn(Icons.list_alt, 'MIS PUB.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyMotoposadaScreen()))),
                ]),
              ),
            ),
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
            boxShadow: selected ? AppShadows.amberGlow : null,
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

  Widget _barBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: AppColors.primary.withAlpha(10),
          ),
        ),
      ),
    );
  }
}
