/// Create Raid Screen — AsfaltoClub Battle Ride.
/// Formulario para crear un nuevo raid con selección de modo, fecha, origen/destino.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/map_picker_screen.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';
import 'raid_lobby_screen.dart';

class CreateRaidScreen extends StatefulWidget {
  const CreateRaidScreen({super.key});

  @override
  State<CreateRaidScreen> createState() => _CreateRaidScreenState();
}

class _CreateRaidScreenState extends State<CreateRaidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  late DateTime _selectedDate;
  String _selectedMode = 'Aventura';
  bool _isPublic = true;
  bool _isLoading = false;

  // Origin coordinates
  double? _originLat;
  double? _originLng;
  String _originLabel = '';

  // Destination coordinates
  double? _destLat;
  double? _destLng;
  String _destLabel = '';

  final _gameModes = [
    'Aventura',
    'Velocidad',
    'Precisión',
    'Supervivencia',
    'Exploración',
  ];

  /// Game mode metadata for info bottom sheet
  static const _modeInfo = {
    'Aventura': {
      'icon': Icons.landscape,
      'desc':
          'Todos contra el camino. Gana quien más puntos acumule en checkpoints. Cooperativo y competitivo.',
    },
    'Velocidad': {
      'icon': Icons.speed,
      'desc':
          'Llega primero a la meta. Puro sprint, el más rápido gana.',
    },
    'Precisión': {
      'icon': Icons.track_changes,
      'desc':
          'El que más cerca pase por los puntos de control sin desviarse. Puntería y navegación.',
    },
    'Supervivencia': {
      'icon': Icons.shield,
      'desc':
          'El último en pie. Pierde el que llegue último a cada checkpoint.',
    },
    'Exploración': {
      'icon': Icons.explore,
      'desc':
          'Descubre la mayor cantidad de lugares en el mapa. Sin ruta fija.',
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showModeInfo(String mode) {
    final info = _modeInfo[mode]!;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.metallicDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Mode header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: AppRadius.mdCircular,
                  ),
                  child: Icon(
                    info['icon'] as IconData,
                    color: AppColors.primary,
                    size: AppSpacing.iconLg,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.toUpperCase(),
                        style: AppTypography.h3.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MODO DE JUEGO',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Description card
            Container(
              width: double.infinity,
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: AppSpacing.iconSm,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      info['desc'] as String,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapPicker({
    required double? initialLat,
    required double? initialLng,
    required String title,
    required void Function(double lat, double lng) onPicked,
  }) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: initialLat ?? 4.60971,
          initialLng: initialLng ?? -74.08175,
        ),
      ),
    );
    if (result != null && result.length == 2 && mounted) {
      onPicked(result[0], result[1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RaidBloc, RaidState>(
      listener: (context, state) {
        if (state is RaidLobby) {
          HapticFeedback.mediumImpact();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RaidLobbyScreen(
                raidId: '${state.raid['id']}',
                initialRaid: state.raid,
                initialParticipants: [],
               ),
            ),
          );
        }
        if (state is RaidError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isLoading = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'NUEVO RAID',
            style: AppTypography.h2.copyWith(color: AppColors.primary),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  _sectionLabel('NOMBRE DEL RAID'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInput(
                    controller: _titleController,
                    hint: 'Ej: Conquista al Ángel',
                    icon: Icons.flag_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Origin — Map picker button
                  _sectionLabel('ORIGEN'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildLocationPicker(
                    label: _originLabel.isNotEmpty
                        ? _originLabel
                        : '📍 Seleccionar en mapa',
                    hasValue: _originLat != null,
                    onTap: () => _openMapPicker(
                      initialLat: _originLat,
                      initialLng: _originLng,
                      title: 'Seleccionar origen',
                      onPicked: (lat, lng) {
                        setState(() {
                          _originLat = lat;
                          _originLng = lng;
                          _originLabel =
                              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
                        });
                      },
                    ),
                    onClear: _originLat != null
                        ? () => setState(() {
                              _originLat = null;
                              _originLng = null;
                              _originLabel = '';
                            })
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Destination — Map picker button
                  _sectionLabel('DESTINO'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildLocationPicker(
                    label: _destLabel.isNotEmpty
                        ? _destLabel
                        : '📍 Seleccionar en mapa',
                    hasValue: _destLat != null,
                    onTap: () => _openMapPicker(
                      initialLat: _destLat,
                      initialLng: _destLng,
                      title: 'Seleccionar destino',
                      onPicked: (lat, lng) {
                        setState(() {
                          _destLat = lat;
                          _destLng = lng;
                          _destLabel =
                              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
                        });
                      },
                    ),
                    onClear: _destLat != null
                        ? () => setState(() {
                              _destLat = null;
                              _destLng = null;
                              _destLabel = '';
                            })
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Game Mode
                  _sectionLabel('MODO DE JUEGO'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildModeSelector(),
                  const SizedBox(height: AppSpacing.lg),

                  // Date & Time
                  _sectionLabel('FECHA Y HORA'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDatePicker(),
                  const SizedBox(height: AppSpacing.lg),

                  // Public / Private
                  _sectionLabel('VISIBILIDAD'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildVisibilityToggle(),
                  const SizedBox(height: AppSpacing.xxl),

                  // Create button
                  _buildCreateButton(),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
          prefixIcon: Icon(
            icon,
            color: AppColors.textMuted,
            size: AppSpacing.iconSm,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPicker({
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: hasValue ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.mdCircular,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasValue
                            ? Icons.location_on
                            : Icons.map_outlined,
                        color: hasValue
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: AppSpacing.iconSm,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.body.copyWith(
                            color: hasValue
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontFamily: hasValue ? 'SpaceGrotesk' : 'DMSans',
                            fontWeight:
                                hasValue ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textMuted,
              padding: const EdgeInsets.all(AppSpacing.sm),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _gameModes.map((mode) {
        final isSelected = _selectedMode == mode;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(20)
                      : AppColors.input,
                  borderRadius: AppRadius.mdCircular,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryGlow,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  mode.toUpperCase(),
                  style: AppTypography.buttonSmall.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Info button
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showModeInfo(mode),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 14,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedDate),
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          ),
        );
        if (time == null) return;
        setState(() {
          _selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
              size: AppSpacing.iconSm,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                '${_selectedDate.year}  '
                '${_selectedDate.hour.toString().padLeft(2, '0')}:'
                '${_selectedDate.minute.toString().padLeft(2, '0')}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.edit_calendar_outlined,
              color: AppColors.textMuted,
              size: AppSpacing.iconSm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _isPublic ? Icons.public_outlined : Icons.lock_outlined,
            color: _isPublic ? AppColors.success : AppColors.textMuted,
            size: AppSpacing.iconSm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _isPublic ? 'PÚBLICO' : 'PRIVADO',
              style: AppTypography.body.copyWith(
                color: _isPublic ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            activeColor: AppColors.primary,
            inactiveTrackColor: AppColors.trackInactive,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onCreate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAmber,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          elevation: 0,
          shadowColor: AppColors.primaryGlow,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                'CREAR RAID',
                style: AppTypography.button.copyWith(
                  color: AppColors.textOnAmber,
                ),
              ),
      ),
    );
  }

  void _onCreate() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un nombre para el raid'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_originLat == null || _originLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el origen en el mapa'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_destLat == null || _destLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el destino en el mapa'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    context.read<RaidBloc>().add(
      CreateRaid(
        title: _titleController.text.trim(),
        origin: '$_originLat, $_originLng',
        originLat: _originLat!,
        originLng: _originLng!,
        destination: '$_destLat, $_destLng',
        destLat: _destLat!,
        destLng: _destLng!,
        gameMode: _selectedMode,
        dateTime: _selectedDate,
        isPublic: _isPublic,
      ),
    );
  }
}
