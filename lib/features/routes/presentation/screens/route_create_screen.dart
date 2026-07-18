/// Route Create Screen — waypoint editor with motoposada suggestions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/map_picker_screen.dart';
import '../../../../core/services/geocoding_service.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';

class RouteCreateScreen extends StatefulWidget {
  const RouteCreateScreen({super.key});

  @override
  State<RouteCreateScreen> createState() => _RouteCreateScreenState();
}

class _RouteCreateScreenState extends State<RouteCreateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _difficulty = 'medio';
  bool _isPublic = true;

  // Waypoints
  final List<Map<String, dynamic>> _waypoints = [];
  double? _pickedLat;
  double? _pickedLng;
  String _pickedAddress = '';
  final _wpNameController = TextEditingController();
  final _wpDurationController = TextEditingController();
  String _stopType = 'parada';

  // Search
  final _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _wpNameController.dispose();
    _wpDurationController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _pickedLat ?? 4.60971,
          initialLng: _pickedLng ?? -74.08175,
        ),
      ),
    );
    if (result != null && result.length == 2 && mounted) {
      setState(() {
        _pickedLat = result[0];
        _pickedLng = result[1];
        _pickedAddress = '';
      });
      // Resolve address
      final addr = await GeocodingService.reverseGeocode(result[0], result[1]);
      if (mounted) setState(() => _pickedAddress = addr);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await GeocodingService.searchPlaces(query);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  void _selectSearchResult(GeocodingResult result) {
    HapticFeedback.mediumImpact();
    setState(() {
      _pickedLat = result.lat;
      _pickedLng = result.lng;
      _pickedAddress = result.displayName;
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _addWaypoint() {
    final lat = _pickedLat;
    final lng = _pickedLng;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un punto en el mapa primero')),
      );
      return;
    }
    setState(() {
      _waypoints.add({
        'lat': lat,
        'lng': lng,
        'name': _wpNameController.text.trim().isEmpty ? null : _wpNameController.text.trim(),
        'stop_type': _stopType,
        'duration_min': int.tryParse(_wpDurationController.text),
      });
      _pickedLat = null;
      _pickedLng = null;
    });
    _wpNameController.clear();
    _wpDurationController.clear();
  }

  void _removeWaypoint(int index) {
    setState(() => _waypoints.removeAt(index));
  }

  void _reorderWaypoint(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final wp = _waypoints.removeAt(oldIndex);
      _waypoints.insert(newIndex, wp);
    });
  }

  void _suggestMotoposadas() {
    if (_waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un waypoint primero')),
      );
      return;
    }
    context.read<RouteBloc>().add(SuggestMotoposadasEvent(
          waypoints: _waypoints,
          maxDistanceKm: 20,
        ));
  }

  void _saveRoute() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un título para la ruta')),
      );
      return;
    }
    if (_waypoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 2 waypoints')),
      );
      return;
    }
    context.read<RouteBloc>().add(CreateRouteEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          waypoints: _waypoints,
          difficulty: _difficulty,
          isPublic: _isPublic,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RouteBloc, RouteState>(
      listener: (context, state) {
        if (state is RouteCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ruta creada exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, state.route);
        }
        if (state is RouteError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Crear Ruta', style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            BlocBuilder<RouteBloc, RouteState>(
              builder: (context, state) {
                final saving = state is RouteLoading;
                return TextButton(
                  onPressed: saving ? null : _saveRoute,
                  child: saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Text('GUARDAR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              _buildSectionLabel('TÍTULO'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _titleController,
                hint: 'Ej: Ruta al Cañón del Chicamocha',
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              _buildSectionLabel('DESCRIPCIÓN'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _descriptionController,
                hint: 'Describe la ruta...',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),

              // Difficulty selector
              _buildSectionLabel('DIFICULTAD'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: ['facil', 'medio', 'dificil', 'experto'].map((d) {
                  final selected = _difficulty == d;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _difficulty = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: selected ? AppColors.primaryLight : AppColors.border,
                          ),
                        ),
                        child: Text(
                          d[0].toUpperCase() + d.substring(1),
                          style: AppTypography.label.copyWith(
                            color: selected ? AppColors.textOnAmber : AppColors.textSecondary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Public toggle
              Row(
                children: [
                  const Text('Ruta pública', style: TextStyle(color: AppColors.textPrimary)),
                  const Spacer(),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Waypoints section
              Row(
                children: [
                  _buildSectionLabel('WAYPOINTS (${_waypoints.length})'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _suggestMotoposadas,
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Sugerir motoposadas',
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Motoposada suggestions listener
              BlocBuilder<RouteBloc, RouteState>(
                builder: (context, state) {
                  if (state is MotoposadasSuggested) {
                    final suggestions = state.suggestions;
                    if (suggestions.isNotEmpty) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(10),
                          borderRadius: AppRadius.smCircular,
                          border: Border.all(color: AppColors.primary.withAlpha(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${suggestions.length} motoposadas sugeridas',
                              style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...suggestions.take(5).map((s) {
                              final sMap = s as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _waypoints.add({
                                        'lat': sMap['lat'],
                                        'lng': sMap['lng'],
                                        'name': sMap['name'] as String? ?? 'Motoposada',
                                        'stop_type': 'moto_posada',
                                        'duration_min': 30,
                                      });
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add_circle_outline, size: 14, color: AppColors.success),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(sMap['name'] as String? ?? 'Motoposada',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Waypoint list
              if (_waypoints.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _waypoints.length,
                  onReorder: _reorderWaypoint,
                  itemBuilder: (_, i) {
                    final wp = _waypoints[i];
                    final isMotoposada = wp['stop_type'] == 'moto_posada';
                    return Container(
                      key: ValueKey('wp_$i'),
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.smCircular,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isMotoposada ? AppColors.primary.withAlpha(25) : AppColors.input,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: isMotoposada
                                  ? const Icon(Icons.home_rounded, size: 14, color: AppColors.primary)
                                  : Text('${i + 1}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(wp['name'] as String? ?? 'Punto ${i + 1}',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                                ),
                                Text('${wp['lat']}, ${wp['lng']}',
                                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                            onPressed: () => _removeWaypoint(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: AppSpacing.md),

              // Add waypoint form
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mdCircular,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AGREGAR PUNTO', style: AppTypography.caption.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
                    const SizedBox(height: AppSpacing.sm),
                    // Map picker button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openMapPicker(),
                        icon: const Icon(Icons.map_outlined, size: AppSpacing.iconSm),
                        label: Text(
                          _pickedLat != null
                              ? '📍 ${_pickedAddress.isNotEmpty ? _pickedAddress : "${_pickedLat!.toStringAsFixed(6)}, ${_pickedLng!.toStringAsFixed(6)}"}'
                              : '📍 Seleccionar en mapa',
                          style: AppTypography.body.copyWith(
                            color: _pickedLat != null ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.input,
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: _pickedLat != null ? AppColors.primary : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Place search
                    TextField(
                      controller: _searchController,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar lugar por nombre...',
                        hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.input,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: AppSpacing.sm,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (_, i) {
                            final r = _searchResults[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined,
                                color: AppColors.primary, size: 18),
                              title: Text(r.displayName,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSearchResult(r),
                            );
                          },
                        ),
                      ),
                    ],
                    if (_pickedLat != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _pickedLat = null;
                          _pickedLng = null;
                        }),
                        icon: const Icon(Icons.close, size: 14, color: AppColors.error),
                        label: Text('Quitar punto',
                          style: AppTypography.caption.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _buildSmallField(
                      controller: _wpNameController,
                      hint: 'Nombre (opcional)',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallField(
                            controller: _wpDurationController,
                            hint: 'Duración (min)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.input,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _stopType,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                items: const [
                                  DropdownMenuItem(value: 'parada', child: Text('Parada')),
                                  DropdownMenuItem(value: 'moto_posada', child: Text('🏠 Motoposada')),
                                  DropdownMenuItem(value: 'mirador', child: Text('🗺️ Mirador')),
                                  DropdownMenuItem(value: 'comida', child: Text('🍽️ Comida')),
                                ],
                                onChanged: (v) => setState(() => _stopType = v ?? 'parada'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addWaypoint,
                        icon: const Icon(Icons.add_rounded, size: AppSpacing.iconSm),
                        label: const Text('AGREGAR PUNTO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnAmber,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Save button
              SizedBox(
                width: double.infinity,
                child: BlocBuilder<RouteBloc, RouteState>(
                  builder: (context, state) {
                    final saving = state is RouteLoading;
                    return ElevatedButton(
                      onPressed: saving ? null : _saveRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                        minimumSize: const Size(0, 52),
                        disabledBackgroundColor: AppColors.textDisabled,
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('GUARDAR RUTA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.input,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdCircular,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdCircular,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdCircular,
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),
    );
  }

  Widget _buildSmallField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.input,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smCircular,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smCircular,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smCircular,
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        isDense: true,
      ),
    );
  }
}
