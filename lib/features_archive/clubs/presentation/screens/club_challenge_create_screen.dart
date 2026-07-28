/// Club Challenge Create Screen — create challenges for club members.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/club_bloc.dart';
import '../bloc/club_event.dart';
import '../bloc/club_state.dart';

class ClubChallengeCreateScreen extends StatefulWidget {
  final int clubId;
  const ClubChallengeCreateScreen({super.key, required this.clubId});

  @override
  State<ClubChallengeCreateScreen> createState() => _ClubChallengeCreateScreenState();
}

class _ClubChallengeCreateScreenState extends State<ClubChallengeCreateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _rewardXpController = TextEditingController(text: '0');
  String _type = 'km';

  final _types = {
    'km': 'Kilómetros 🏍️',
    'puntos': 'Puntos ⭐',
    'lugares': 'Lugares 🗺️',
    'raids': 'Raids 🏁',
    'rutas': 'Rutas 🛣️',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _durationController.dispose();
    _rewardXpController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Ingresa un título para el reto');
      return;
    }
    final target = double.tryParse(_targetController.text);
    if (target == null || target <= 0) {
      _showError('Ingresa un valor objetivo válido');
      return;
    }
    final duration = int.tryParse(_durationController.text) ?? 30;
    final rewardXp = int.tryParse(_rewardXpController.text) ?? 0;

    context.read<ClubBloc>().add(CreateClubChallenge(
          clubId: widget.clubId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _type,
          targetValue: target,
          durationDays: duration,
          rewardXp: rewardXp,
        ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClubBloc, ClubState>(
      listener: (context, state) {
        if (state is ClubChallengesLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reto creado exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
        if (state is ClubError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: AppColors.error),
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
          title: const Text('Crear Reto', style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            BlocBuilder<ClubBloc, ClubState>(
              builder: (context, state) {
                final saving = state is ClubLoading;
                return TextButton(
                  onPressed: saving ? null : _submit,
                  child: saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Text('CREAR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
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
              _buildSectionLabel('TÍTULO DEL RETO'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _titleController,
                hint: 'Ej: Conquista 500 km este mes',
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              _buildSectionLabel('DESCRIPCIÓN (OPCIONAL)'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _descriptionController,
                hint: 'Describe el reto y sus reglas...',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),

              // Type selector
              _buildSectionLabel('TIPO DE RETO'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    items: _types.entries.map((e) {
                      return DropdownMenuItem(value: e.key, child: Text(e.value));
                    }).toList(),
                    onChanged: (v) => setState(() => _type = v ?? 'km'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Target value
              _buildSectionLabel('VALOR OBJETIVO'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _targetController,
                hint: 'Ej: 500',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Unidades basadas en el tipo seleccionado',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),

              // Duration
              _buildSectionLabel('DURACIÓN (DÍAS)'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _durationController,
                hint: '30',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),

              // Reward XP
              _buildSectionLabel('RECOMPENSA XP'),
              const SizedBox(height: AppSpacing.sm),
              _buildTextField(
                controller: _rewardXpController,
                hint: '0',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'XP que ganarán los miembros al completar el reto',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(8),
                  borderRadius: AppRadius.smCircular,
                  border: Border.all(color: AppColors.secondary.withAlpha(30)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.secondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tips para crear retos',
                            style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• Retos de KM: ideales para motivar rutas largas\n'
                            '• Retos de lugares: visitar X motoposadas\n'
                            '• Retos de raids: completar raids en equipo\n'
                            '• Define una dificultad progresiva (7, 14, 30 días)',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Create button
              SizedBox(
                width: double.infinity,
                child: BlocBuilder<ClubBloc, ClubState>(
                  builder: (context, state) {
                    final saving = state is ClubLoading;
                    return ElevatedButton(
                      onPressed: saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                        minimumSize: const Size(0, 52),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('CREAR RETO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    );
                  },
                ),
              ),
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
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
}
