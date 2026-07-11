/// Create Clan Screen — AsfaltoClub Battle Ride.
/// Formulario para crear un nuevo clan.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/clan_bloc.dart';
import '../bloc/clan_event.dart';
import '../bloc/clan_state.dart';

class CreateClanScreen extends StatefulWidget {
  const CreateClanScreen({super.key});

  @override
  State<CreateClanScreen> createState() => _CreateClanScreenState();
}

class _CreateClanScreenState extends State<CreateClanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;
  String? _logoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClanBloc, ClanState>(
      listener: (context, state) {
        if (state is ClanCreated) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 ¡Clan creado con éxito!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, state.clan);
        }
        if (state is ClanError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
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
          title: Text('CREAR CLAN', style: AppTypography.h2.copyWith(color: AppColors.primary)),
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
                  const SizedBox(height: AppSpacing.lg),

                  // Logo picker
                  Center(child: _buildLogoPicker()),
                  const SizedBox(height: AppSpacing.xl),

                  // Clan name
                  _sectionLabel('NOMBRE DEL CLAN'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInput(
                    controller: _nameController,
                    hint: 'Ej: Águilas del Asfalto',
                    icon: Icons.badge_outlined,
                    maxLength: 30,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Tag
                  _sectionLabel('TAG'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInput(
                    controller: _tagController,
                    hint: 'Ej: AGUILAS',
                    icon: Icons.tag,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Public/Private
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

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Placeholder — in production, use image_picker
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleccionar logo (image_picker)'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          color: AppColors.input,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
              color: AppColors.textMuted, size: 28,
            ),
            const SizedBox(height: 4),
            Text('LOGO',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
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
          counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 10),
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
              _isPublic ? 'PÚBLICO — Cualquiera puede unirse' : 'PRIVADO — Solo por invitación',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
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
            : Text('CREAR CLAN', style: AppTypography.button.copyWith(color: AppColors.textOnAmber)),
      ),
    );
  }

  void _onCreate() {
    final name = _nameController.text.trim();
    final tag = _tagController.text.trim().toUpperCase();

    if (name.isEmpty || tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (tag.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El tag debe tener al menos 2 caracteres'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    context.read<ClanBloc>().add(CreateClan(
      name: name,
      tag: tag,
      isPublic: _isPublic,
      logoUrl: _logoUrl,
    ));
  }
}
