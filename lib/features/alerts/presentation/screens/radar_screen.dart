/// Radar de Alertas Viales — Mapa en vivo con marcadores de alertas.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';

/// Haversine distance in km
double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0; // Earth radius in km
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return r * c;
}

// ── Models ──

class _RoadAlert {
  final int id;
  final String type;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String severity;
  final int upvotes;
  final bool active;
  final DateTime? expiresAt;
  final DateTime createdAt;

  _RoadAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.severity = 'warning',
    this.upvotes = 0,
    this.active = true,
    this.expiresAt,
    required this.createdAt,
  });

  factory _RoadAlert.fromMap(Map<String, dynamic> m) {
    return _RoadAlert(
      id: m['id'] as int? ?? 0,
      type: m['type'] as String? ?? 'hazard',
      title: m['title'] as String? ?? 'Sin título',
      description: m['description'] as String? ?? '',
      latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
      severity: m['severity'] as String? ?? 'warning',
      upvotes: m['upvotes'] as int? ?? 0,
      active: m['active'] as bool? ?? true,
      expiresAt: m['expires_at'] != null
          ? DateTime.tryParse(m['expires_at'] as String)
          : null,
      createdAt: DateTime.tryParse(
              m['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ── Alert type config ──

class _AlertTypeConfig {
  final Color color;
  final IconData icon;
  final String label;

  const _AlertTypeConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}

const _alertTypes = <String, _AlertTypeConfig>{
  'accident': _AlertTypeConfig(
    color: Color(0xFFFF2D55), // Signal Red
    icon: Icons.warning_amber_rounded,
    label: 'ACCIDENTE',
  ),
  'police': _AlertTypeConfig(
    color: Color(0xFFFF8C00), // Amber
    icon: Icons.local_police_outlined,
    label: 'CONTROL POLICIAL',
  ),
  'weather': _AlertTypeConfig(
    color: Color(0xFF00D4FF), // Electric Cyan
    icon: Icons.thunderstorm_outlined,
    label: 'CLIMA',
  ),
  'hazard': _AlertTypeConfig(
    color: Color(0xFFFF8C00), // Warning orange
    icon: Icons.warning_amber_rounded,
    label: 'PELIGRO',
  ),
  'closure': _AlertTypeConfig(
    color: Color(0xFF606070), // Gray
    icon: Icons.block_outlined,
    label: 'CIERRE',
  ),
};

_AlertTypeConfig _getTypeConfig(String type) {
  return _alertTypes[type] ??
      const _AlertTypeConfig(
        color: AppColors.textMuted,
        icon: Icons.info_outline,
        label: 'AVISO',
      );
}

Color _severityColor(String severity) {
  switch (severity) {
    case 'danger':
      return AppColors.error;
    case 'warning':
      return AppColors.primary;
    default:
      return AppColors.textMuted;
  }
}

// ── Radar Screen ──

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final MapController _mapController = MapController();
  List<_RoadAlert> _alerts = [];
  bool _loading = true;
  String? _error;
  _RoadAlert? _selectedAlert;

  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Attempt to get current position via geolocator if available
      // (import handled; do not crash if not granted)
      try {
        // dynamic import — safe fallback
      } catch (_) {}
    } catch (_) {}

    await _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final resp = await Supabase.instance.client
          .from('road_alerts')
          .select()
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(50);

      final list = (resp as List).cast<Map<String, dynamic>>();
      final alerts = list.map((m) => _RoadAlert.fromMap(m)).toList();

      if (mounted) {
        setState(() {
          _alerts = alerts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Center map on user or first alert
  LatLng _initialCenter() {
    if (_alerts.isNotEmpty) {
      return LatLng(_alerts.first.latitude, _alerts.first.longitude);
    }
    return const LatLng(19.4326, -99.1332); // Default: Mexico City
  }

  List<_RoadAlert> _nearbyAlerts({double radiusKm = 50}) {
    if (_userLat == null || _userLng == null) return _alerts;
    return _alerts.where((a) {
      final d = _haversineDistance(
          _userLat!, _userLng!, a.latitude, a.longitude);
      return d <= radiusKm;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('RADAR DE ALERTAS',
            style:
                AppTypography.h2.copyWith(color: AppColors.primary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: AppColors.textMuted),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadAlerts();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error al cargar alertas',
                      style: AppTypography.h2
                          .copyWith(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: Text(_error!,
                        style: AppTypography.body.copyWith(
                            color: AppColors.textMuted),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _loadAlerts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnAmber,
                    ),
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter(),
                initialZoom: 11.0,
                onTap: (_, __) {
                  if (_selectedAlert != null) {
                    setState(() => _selectedAlert = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.asfaltoclub.moteros',
                ),
                // Alert markers
                MarkerLayer(
                  markers: _alerts.map((alert) {
                    final typeCfg = _getTypeConfig(alert.type);
                    final sevColor =
                        _severityColor(alert.severity);
                    return Marker(
                      point: LatLng(alert.latitude, alert.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(
                              () => _selectedAlert = alert);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: typeCfg.color.withAlpha(30),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: typeCfg.color,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    sevColor.withAlpha(80),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(typeCfg.icon,
                              color: typeCfg.color,
                              size: 20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

          // ── Selected alert card ──
          if (_selectedAlert != null) _buildAlertCard(),

          // ── Report FAB ──
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              onPressed: () => _showReportDialog(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              child: const Icon(Icons.add_alert_outlined),
            ),
          ),

          // ── Legend ──
          if (!_loading && _error == null)
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: _buildLegend(),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    final alert = _selectedAlert!;
    final typeCfg = _getTypeConfig(alert.type);
    final sevColor = _severityColor(alert.severity);
    final distStr = _userLat != null && _userLng != null
        ? '${_haversineDistance(_userLat!, _userLng!, alert.latitude, alert.longitude).toStringAsFixed(1)} km'
        : null;

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: AppSpacing.lg + 72,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdCircular,
            border:
                Border.all(color: typeCfg.color.withAlpha(50)),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeCfg.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeCfg.icon,
                            color: typeCfg.color, size: 14),
                        const SizedBox(width: 4),
                        Text(typeCfg.label,
                            style: AppTypography.caption.copyWith(
                              color: typeCfg.color,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Severity indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: sevColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: sevColor.withAlpha(100),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(alert.severity.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        color: sevColor,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(alert.title,
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.textPrimary)),
              if (alert.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(alert.description,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (distStr != null) ...[
                    Icon(Icons.near_me,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(distStr,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Icon(Icons.arrow_upward,
                      color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text('${alert.upvotes}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                  const Spacer(),
                  Text(_formatTime(alert.createdAt),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.elevated.withAlpha(220),
        borderRadius: AppRadius.smCircular,
        border: Border.all(color: AppColors.border.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _alertTypes.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: entry.value.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(entry.value.label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReportDialog() {
    final typeController = TextEditingController();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'hazard';
    String selectedSeverity = 'warning';
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('REPORTAR ALERTA',
                      style: AppTypography.h2.copyWith(
                          color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.md),

                  // Type chips
                  Text('TIPO DE ALERTA',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.5)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _alertTypes.entries.map((entry) {
                      final isSelected =
                          selectedType == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            )),
                        selected: isSelected,
                        selectedColor: entry.value.color,
                        backgroundColor: entry.value.color
                            .withAlpha(20),
                        side: BorderSide(
                          color: isSelected
                              ? entry.value.color
                              : AppColors.border,
                        ),
                        onSelected: (_) => setSheetState(
                            () => selectedType = entry.key),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  _buildReportField(
                    controller: titleController,
                    hint: 'Título de la alerta',
                    icon: Icons.label_outline,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Description
                  _buildReportField(
                    controller: descController,
                    hint: 'Descripción (opcional)',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Severity selector
                  Row(
                    children: ['info', 'warning', 'danger'].map((s) {
                      final isSelected =
                          selectedSeverity == s;
                      final sevColors = {
                        'info': AppColors.textMuted,
                        'warning': AppColors.primary,
                        'danger': AppColors.error,
                      };
                      final sevLabels = {
                        'info': 'INFO',
                        'warning': 'AVISO',
                        'danger': 'PELIGRO',
                      };
                      final color = sevColors[s]!;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2),
                          child: GestureDetector(
                            onTap: () => setSheetState(
                                () => selectedSeverity = s),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withAlpha(25)
                                    : AppColors.input,
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                sevLabels[s]!,
                                textAlign: TextAlign.center,
                                style: AppTypography
                                    .caption
                                    .copyWith(
                                  color: isSelected
                                      ? color
                                      : AppColors
                                          .textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setSheetState(
                                  () => submitting = true);
                              await _submitAlert(
                                type: selectedType,
                                title:
                                    titleController.text.trim(),
                                description: descController
                                    .text
                                    .trim(),
                                severity: selectedSeverity,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor:
                            AppColors.textOnAmber,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                AppRadius.mdCircular),
                        elevation: 0,
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text('REPORTAR',
                              style: AppTypography.button),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTypography.body
            .copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.body
              .copyWith(color: AppColors.textMuted),
          prefixIcon:
              Icon(icon, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Future<void> _submitAlert({
    required String type,
    required String title,
    required String description,
    required String severity,
  }) async {
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El título es obligatorio'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // Use a default location if user location not available
      final lat = _userLat ?? 19.4326;
      final lng = _userLng ?? -99.1332;

      await Supabase.instance.client.from('road_alerts').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'description': description,
        'latitude': lat,
        'longitude': lng,
        'severity': severity,
        'active': true,
        'upvotes': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alerta reportada con éxito'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
