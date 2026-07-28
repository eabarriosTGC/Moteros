/// Create Club Screen — AsfaltoClub Clubs module.
/// Formulario para crear un nuevo club.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/club_bloc.dart';
import '../bloc/club_event.dart';
import '../bloc/club_state.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;
  bool _requiresApproval = false;
  String? _logoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClubBloc, ClubState>(
      listener: (context, state) {
        if (state is ClubCreated) {
          HapticFeedback.mediumImpact();
          final club = state.club;
          final code = club['join_code'] as String? ?? '---';
          final reqApproval = club['requires_approval'] == true;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              title: Text('🎉 Club creado!',
                style: AppTypography.h2.copyWith(color: AppColors.success),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.input,
                      borderRadius: AppRadius.mdCircular,
                      border: Border.all(color: AppColors.primary.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.vpn_key, color: AppColors.primary, size: AppSpacing.iconSm),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Código de acceso: $code',
                          style: AppTypography.monoSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Compartí este código con los miembros que quieras invitar',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (reqApproval) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(15),
                        borderRadius: AppRadius.smCircular,
                        border: Border.all(color: AppColors.warning.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'El club requiere aprobación del admin antes de estar activo',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context, club); // pop screen
                  },
                  child: Text('OK',
                    style: AppTypography.button.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }
        if (state is ClubError) {
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
          title: Text('CREAR CLUB', style: AppTypography.h2.copyWith(color: AppColors.primary)),
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

                  // Club name
                  _sectionLabel('NOMBRE DEL CLUB'),
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

                  // Visibility
                  _sectionLabel('VISIBILIDAD'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildVisibilityToggle(),
                  const SizedBox(height: AppSpacing.lg),

                  // Admin approval toggle
                  _sectionLabel('CONTROL DE ACCESO'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildApprovalToggle(),
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
            activeThumbColor: AppColors.primary,
            inactiveTrackColor: AppColors.trackInactive,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalToggle() {
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
            _requiresApproval ? Icons.admin_panel_settings : Icons.person_add_alt_1_outlined,
            color: _requiresApproval ? AppColors.warning : AppColors.textMuted,
            size: AppSpacing.iconSm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requiere aprobación del admin',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  _requiresApproval ? 'Los miembros nuevos necesitan aprobación' : 'Entrada libre',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _requiresApproval,
            onChanged: (v) => setState(() => _requiresApproval = v),
            activeThumbColor: AppColors.warning,
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
            : Text('CREAR CLUB', style: AppTypography.button.copyWith(color: AppColors.textOnAmber)),
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

    context.read<ClubBloc>().add(CreateClub(
      name: name,
      tag: tag,
      isPublic: _isPublic,
      logoUrl: _logoUrl,
      requiresApproval: _requiresApproval,
    ));
  }
}
