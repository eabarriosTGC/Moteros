/// Create Raid Screen — AsfaltoClub Battle Ride.
/// Formulario para crear un nuevo raid con selección de modo, fecha, origen/destino.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';

class CreateRaidScreen extends StatefulWidget {
  const CreateRaidScreen({super.key});

  @override
  State<CreateRaidScreen> createState() => _CreateRaidScreenState();
}

class _CreateRaidScreenState extends State<CreateRaidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _originController = TextEditingController(text: '4.60971, -74.08175');
  final _destController = TextEditingController(text: '4.69127, -74.04583');
  late DateTime _selectedDate;
  String _selectedMode = 'Free Ride';
  bool _isPublic = true;
  bool _isLoading = false;

  final _gameModes = [
    'Free Ride',
    'Rally',
    'Ruta Gótica',
    'Convoy',
    'Sobrevivencia',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RaidBloc, RaidState>(
      listener: (context, state) {
        if (state is RaidLobby) {
          HapticFeedback.mediumImpact();
          Navigator.pushReplacementNamed(context, '/raid/lobby',
            arguments: state.raid['id'],
          );
        }
        if (state is RaidError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
          setState(() => _isLoading = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('NUEVO RAID', style: AppTypography.h2.copyWith(color: AppColors.primary)),
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

                  // Origin
                  _sectionLabel('ORIGEN'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInput(
                    controller: _originController,
                    hint: 'Latitud, Longitud',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Destination
                  _sectionLabel('DESTINO'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInput(
                    controller: _destController,
                    hint: 'Latitud, Longitud',
                    icon: Icons.flag_outlined,
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
    return Text(text,
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
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: AppSpacing.iconSm),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _gameModes.map((mode) {
        final isSelected = _selectedMode == mode;
        return GestureDetector(
          onTap: () => setState(() => _selectedMode = mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withAlpha(20) : AppColors.input,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Text(mode.toUpperCase(),
              style: AppTypography.buttonSmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
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
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          ),
        );
        if (time == null) return;
        setState(() {
          _selectedDate = DateTime(
            date.year, date.month, date.day, time.hour, time.minute,
          );
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: AppSpacing.iconSm),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                '${_selectedDate.year}  '
                '${_selectedDate.hour.toString().padLeft(2, '0')}:'
                '${_selectedDate.minute.toString().padLeft(2, '0')}',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
            ),
            Icon(Icons.edit_calendar_outlined, color: AppColors.textMuted, size: AppSpacing.iconSm),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text('CREAR RAID', style: AppTypography.button.copyWith(color: AppColors.textOnAmber)),
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

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    // Parse coordinates
    final originParts = _originController.text.split(',').map((s) => double.tryParse(s.trim())).toList();
    final destParts = _destController.text.split(',').map((s) => double.tryParse(s.trim())).toList();

    context.read<RaidBloc>().add(CreateRaid(
      title: _titleController.text.trim(),
      origin: _originController.text.trim(),
      originLat: originParts.length >= 2 && originParts[0] != null ? originParts[0]! : 4.60971,
      originLng: originParts.length >= 2 && originParts[1] != null ? originParts[1]! : -74.08175,
      destination: _destController.text.trim(),
      destLat: destParts.length >= 2 && destParts[0] != null ? destParts[0]! : 4.69127,
      destLng: destParts.length >= 2 && destParts[1] != null ? destParts[1]! : -74.04583,
      gameMode: _selectedMode,
      dateTime: _selectedDate,
      isPublic: _isPublic,
    ));
  }
}
