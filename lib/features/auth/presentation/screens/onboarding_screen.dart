/// OnboardingScreen — mandatory profile completion for new users.
/// Shown once after registration. Must complete to access the app.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  final String? inviteCode;
  final String? clubName;
  const OnboardingScreen({super.key, this.inviteCode, this.clubName});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _bikeCtrl = TextEditingController();
  bool _acceptedTerms = false;
  bool _saving = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _bikeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) return;
    setState(() => _saving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Update users table with profile data
      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        'phone': _phoneCtrl.text.trim(),
        'emergency_contact_name': _emergencyNameCtrl.text.trim(),
        'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
        'bike_model': _bikeCtrl.text.trim(),
      });

      // Mark onboarding complete in user_metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'onboarding_complete': true,
            'phone': _phoneCtrl.text.trim(),
            'bike_model': _bikeCtrl.text.trim(),
          },
        ),
      );

      // If came from invite code, auto-join to club
      if (widget.inviteCode != null) {
        try {
          await Supabase.instance.client.rpc('join_club_by_code', params: {
            'p_code': widget.inviteCode!.toUpperCase().trim(),
          });
        } catch (_) {
          // Non-fatal: club join is bonus
        }
      }

      if (!mounted) return;
      // Return true to signal completion — app.dart will detect it
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Completá tu perfil'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: AppShadows.amberGlow,
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('BIENVENIDO A ASFALTOCLUB',
                      style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    if (widget.clubName != null) ...[
                      const SizedBox(height: 4),
                      Text('Invitado por: ${widget.clubName}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text('Completá estos datos para arrancar',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Emergency contact name
                TextFormField(
                  controller: _emergencyNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contacto de emergencia (nombre)',
                    prefixIcon: Icon(Icons.emergency, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Emergency contact phone
                TextFormField(
                  controller: _emergencyPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contacto de emergencia (teléfono)',
                    prefixIcon: Icon(Icons.phone_in_talk, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Bike model
                TextFormField(
                  controller: _bikeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tu moto (marca y modelo)',
                    hintText: 'Ej: Yamaha MT-07',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                    prefixIcon: Icon(Icons.motorcycle, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                ),
                const SizedBox(height: 24),

                // Terms checkbox
                GestureDetector(
                  onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _acceptedTerms ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _acceptedTerms ? AppColors.primary : AppColors.border),
                      ),
                      child: _acceptedTerms
                          ? const Icon(Icons.check, color: Colors.black, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Acepto los términos y condiciones de AsfaltoClub',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: (_saving || !_acceptedTerms) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnAmber,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('COMENZAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
