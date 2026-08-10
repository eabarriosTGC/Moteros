library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/services/routing_service.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/map_picker_screen.dart';
import '../../data/raid_conquest_repository.dart';

class CreateRaidScreen extends StatefulWidget {
  const CreateRaidScreen({super.key});

  @override
  State<CreateRaidScreen> createState() => _CreateRaidScreenState();
}

class _CreateRaidScreenState extends State<CreateRaidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _repository = RaidConquestRepository();

  List<Map<String, dynamic>> _clubs = const [];
  int? _clubId;
  String _raidType = 'permanent';
  double? _originLat;
  double? _originLng;
  double? _destLat;
  double? _destLng;
  String _originName = '';
  String _destinationName = '';
  DateTime _startsAt = DateTime.now().add(const Duration(days: 1));
  DateTime _endsAt = DateTime.now().add(const Duration(days: 1, hours: 8));
  RouteResult? _route;
  bool _loadingClubs = true;
  bool _calculating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    try {
      final clubs = await _repository.presidentClubs();
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _clubId = clubs.isEmpty ? null : (clubs.first['club_id'] as num).toInt();
        _loadingClubs = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingClubs = false);
      _showError(RaidConquestRepository.friendlyError(error));
    }
  }

  Future<void> _pickLocation({required bool origin}) async {
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: origin ? (_originLat ?? 4.60971) : (_destLat ?? 4.60971),
          initialLng: origin ? (_originLng ?? -74.08175) : (_destLng ?? -74.08175),
        ),
      ),
    );
    if (!mounted || result == null || result.length != 2) return;
    final label = await GeocodingService.reverseGeocode(result[0], result[1]);
    if (!mounted) return;
    setState(() {
      if (origin) {
        _originLat = result[0];
        _originLng = result[1];
        _originName = label;
      } else {
        _destLat = result[0];
        _destLng = result[1];
        _destinationName = label;
      }
      _route = null;
    });
    if (_originLat != null && _destLat != null) await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    setState(() => _calculating = true);
    final route = await RoutingService.getRoute(
      originLat: _originLat!,
      originLng: _originLng!,
      destLat: _destLat!,
      destLng: _destLng!,
      instructions: false,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _calculating = false;
    });
  }

  Future<void> _pickDateTime({required bool start}) async {
    final current = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted || time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = value;
        if (_endsAt.isBefore(value)) _endsAt = value.add(const Duration(hours: 8));
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clubId == null) {
      _showError('Debes ser presidente de un club para publicar raids.');
      return;
    }
    if (_originLat == null || _destLat == null) {
      _showError('Selecciona el origen y el destino.');
      return;
    }
    // El servicio vial mejora la ficha, pero no debe bloquear una publicación.
    // RoutingService siempre entrega una estimación geodésica de respaldo.
    final route = _route ?? RouteResult(
      polyline: const [],
      distanceKm: RoutingService.distanceKm(
        _originLat!,
        _originLng!,
        _destLat!,
        _destLng!,
      ),
      durationMin: 0,
      isFallback: true,
    );
    if (_raidType == 'scheduled' && !_endsAt.isAfter(_startsAt)) {
      _showError('La hora final debe ser posterior al inicio.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.createRaid(
        clubId: _clubId!,
        title: _title.text,
        description: _description.text,
        raidType: _raidType,
        originName: _originName,
        originLat: _originLat!,
        originLng: _originLng!,
        destinationName: _destinationName,
        destLat: _destLat!,
        destLng: _destLng!,
        distanceKm: route.distanceKm,
        durationMinutes: route.durationMin.round(),
        routePolyline: route.polyline
            .map((point) => <double>[point.latitude, point.longitude])
            .toList(),
        startsAt: _raidType == 'scheduled' ? _startsAt : null,
        endsAt: _raidType == 'scheduled' ? _endsAt : null,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(RaidConquestRepository.friendlyError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String _clubName(Map<String, dynamic> row) {
    final club = row['clubs'];
    return club is Map ? (club['name']?.toString() ?? 'Club') : 'Club';
  }

  String _dateLabel(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} · '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('NUEVO RAID', style: AppTypography.h2.copyWith(color: AppColors.primary)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loadingClubs
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    if (_clubs.isEmpty) _presidentRequiredCard(),
                    _label('TIPO DE RAID'),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'permanent',
                          icon: Icon(Icons.all_inclusive),
                          label: Text('Permanente'),
                        ),
                        ButtonSegment(
                          value: 'scheduled',
                          icon: Icon(Icons.event),
                          label: Text('Con fecha'),
                        ),
                      ],
                      selected: {_raidType},
                      onSelectionChanged: (value) => setState(() => _raidType = value.first),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _label('CLUB ORGANIZADOR'),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<int>(
                      initialValue: _clubId,
                      dropdownColor: AppColors.surface,
                      items: _clubs
                          .map((row) => DropdownMenuItem<int>(
                                value: (row['club_id'] as num).toInt(),
                                child: Text(_clubName(row)),
                              ))
                          .toList(),
                      onChanged: _clubs.isEmpty ? null : (value) => setState(() => _clubId = value),
                      decoration: _decoration(Icons.groups_outlined, 'Selecciona tu club'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _label('NOMBRE'),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _title,
                      maxLength: 120,
                      decoration: _decoration(Icons.flag_outlined, 'Ej: Ruta al Cabo de la Vela'),
                      validator: (value) => value == null || value.trim().length < 4
                          ? 'Escribe un nombre de al menos 4 caracteres'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: _decoration(Icons.notes, 'Descripción y recomendaciones'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _locationTile(
                      icon: Icons.trip_origin,
                      title: 'Punto A · Origen',
                      value: _originName,
                      onTap: () => _pickLocation(origin: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _locationTile(
                      icon: Icons.location_on,
                      title: 'Punto B · Destino conquistable',
                      value: _destinationName,
                      onTap: () => _pickLocation(origin: false),
                    ),
                    if (_calculating) ...[
                      const SizedBox(height: AppSpacing.md),
                      const LinearProgressIndicator(color: AppColors.primary),
                    ],
                    if (_route != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _routeCard(_route!),
                    ],
                    if (_raidType == 'scheduled') ...[
                      const SizedBox(height: AppSpacing.lg),
                      _label('VENTANA DEL EVENTO'),
                      const SizedBox(height: AppSpacing.sm),
                      _dateTile('Inicio', _startsAt, () => _pickDateTime(start: true)),
                      const SizedBox(height: AppSpacing.sm),
                      _dateTile('Fin de verificación', _endsAt, () => _pickDateTime(start: false)),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton.icon(
                      onPressed: _saving || _clubs.isEmpty ? null : _submit,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.publish),
                      label: Text(_saving ? 'PUBLICANDO…' : 'PUBLICAR RAID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _presidentRequiredCard() => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          border: Border.all(color: AppColors.primary),
          borderRadius: AppRadius.mdCircular,
        ),
        child: const Text(
          'Solo los presidentes de clubes pueden publicar raids. Tu cuenta no tiene un club presidido.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );

  Widget _locationTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) => ListTile(
        onTap: onTap,
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: AppRadius.mdCircular,
        ),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        subtitle: Text(
          value.isEmpty ? 'Seleccionar en el mapa' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      );

  Widget _routeCard(RouteResult route) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(18),
          borderRadius: AppRadius.mdCircular,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric(
                  Icons.route,
                  '${route.distanceKm.toStringAsFixed(1)} km',
                  route.isFallback ? 'Distancia estimada' : 'Ruta vial',
                ),
                if (!route.isFallback)
                  _metric(Icons.schedule, '${route.durationMin.round()} min', 'Estimado'),
              ],
            ),
            if (route.isFallback) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'La ruta vial no está disponible. Puedes publicar ahora; '
                'la distancia se muestra como aproximada.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      );

  Widget _metric(IconData icon, String value, String label) => Column(
        children: [
          Icon(icon, color: AppColors.primary),
          Text(value, style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
        ],
      );

  Widget _dateTile(String title, DateTime value, VoidCallback onTap) => ListTile(
        onTap: onTap,
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        leading: const Icon(Icons.event, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(_dateLabel(value)),
      );

  InputDecoration _decoration(IconData icon, String hint) => InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary),
        hintText: hint,
        filled: true,
        fillColor: AppColors.input,
        border: OutlineInputBorder(borderRadius: AppRadius.mdCircular),
      );

  Widget _label(String text) => Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );
}
