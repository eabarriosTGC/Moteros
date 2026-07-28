/// Emergency Contact Screen — Configurar contacto de emergencia para SOS.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/services/sos_service.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _sosService = SosService(Supabase.instance.client);
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    setState(() => _loading = true);
    final contact = await _sosService.getEmergencyContact();
    if (contact != null && mounted) {
      _nameController.text = contact['emergency_contact_name'] as String? ?? '';
      _phoneController.text = contact['emergency_contact_phone'] as String? ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá nombre y teléfono'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await _sosService.saveEmergencyContact(name: name, phone: phone);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      setState(() => _saved = true);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Contacto de emergencia guardado'), backgroundColor: AppColors.success),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(AppIcons.shield, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('CONTACTO SOS', style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(15),
                        borderRadius: AppRadius.mdCircular,
                        border: Border.all(color: AppColors.error.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.error, size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Este contacto recibirá tu ubicación exacta cuando actives el SOS.',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Name field
                    _label('NOMBRE DEL CONTACTO'),
                    const SizedBox(height: AppSpacing.sm),
                    _input(
                      controller: _nameController,
                      hint: 'Ej: María García',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Phone field
                    _label('TELÉFONO'),
                    const SizedBox(height: AppSpacing.sm),
                    _input(
                      controller: _phoneController,
                      hint: 'Ej: +57 300 123 4567',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Recent SOS history
                    _label('HISTORIAL SOS'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRecentSos(),
                    const SizedBox(height: AppSpacing.xxl),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _saved ? AppColors.success : AppColors.primary,
                          foregroundColor: _saved ? Colors.black : AppColors.textOnAmber,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(
                                _saved ? '✓ GUARDADO' : 'GUARDAR CONTACTO',
                                style: AppTypography.button.copyWith(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String text) => Text(text, style: AppTypography.caption.copyWith(
    color: AppColors.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.w600,
  ));

  Widget _input({
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
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        ),
      ),
    );
  }

  Widget _buildRecentSos() {
    return FutureBuilder<List<SosEvent>>(
      future: _sosService.getRecentSosEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: Text('Sin emergencias registradas', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
          );
        }
        return Column(
          children: events.map((e) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(
                color: e.triggerType == 'manual' ? AppColors.error.withAlpha(40) : AppColors.warning.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  e.triggerType == 'manual' ? Icons.warning_amber_rounded : Icons.sensors,
                  color: e.triggerType == 'manual' ? AppColors.error : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.triggerType == 'manual' ? 'SOS Manual' : 'Detección',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      Text('${e.lat.toStringAsFixed(4)}, ${e.lng.toStringAsFixed(4)}',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text(
                  '${e.detectedAt.hour.toString().padLeft(2, '0')}:${e.detectedAt.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          )).toList(),
        );
      },
    );
  }
}
