/// OnboardingScreen — mandatory profile completion for new users.
/// Shown once after registration. Must complete to access the app.
///
/// OP-R4: only full_name, bike_model and city are required; phone and
/// emergency contact are optional (no 'Requerido' validators). Submit goes
/// through ProfileRepository (shared persistence path with profile edit);
/// the `onboarding_complete` metadata boolean is no longer written
/// (ADR-001 — the gate reads real field presence).
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../auth/data/repositories/profile_repository.dart';

class OnboardingScreen extends StatefulWidget {
  final String? inviteCode;
  final String? clubName;

  /// Injectable for tests; defaults to the app-wide Supabase client.
  final SupabaseClient? client;

  /// Injectable for tests; defaults to a repo over [client].
  final ProfileRepository? repository;

  const OnboardingScreen({
    super.key,
    this.inviteCode,
    this.clubName,
    this.client,
    this.repository,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _bikeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _acceptedTerms = false;
  bool _saving = false;

  SupabaseClient get _client => widget.client ?? Supabase.instance.client;
  ProfileRepository get _repository =>
      widget.repository ?? ProfileRepository(client: _client);

  @override
  void initState() {
    super.initState();
    // Prefill full_name from auth metadata (Google/email OAuth display name).
    final metaName = _client.auth.currentUser?.userMetadata?['full_name']
            as String? ??
        '';
    _nameCtrl.text = metaName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _bikeCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) return;
    setState(() => _saving = true);

    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Shared persistence path (onboarding + edit). The repo upserts the
      // users row and mirrors full_name to metadata — onboarding_complete is
      // NOT written (ADR-001).
      await _repository.saveProfile(
        userId: user.id,
        fullName: _nameCtrl.text,
        bikeModel: _bikeCtrl.text,
        city: _cityCtrl.text,
        phone: _phoneCtrl.text,
        emergencyName: _emergencyNameCtrl.text,
        emergencyPhone: _emergencyPhoneCtrl.text,
      );

      // If came from invite code, auto-join to club
      if (widget.inviteCode != null) {
        try {
          await _client.rpc('join_club_by_code', params: {
            'p_code': widget.inviteCode!.toUpperCase().trim(),
          });
        } catch (_) {
          // Non-fatal: club join is bonus
        }
      }

      if (!mounted) return;
      // Return true to signal completion — app.dart re-queries the users row
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

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

                // Full name (REQUIRED — OP-R4)
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),

                // Bike model (REQUIRED — OP-R4)
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
                  validator: _required,
                ),
                const SizedBox(height: 16),

                // City (REQUIRED — OP-R4)
                TextFormField(
                  controller: _cityCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    hintText: 'Ej: Medellín',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                    prefixIcon: Icon(Icons.location_city, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),

                // Phone (OPTIONAL — OP-R4)
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    prefixIcon: Icon(Icons.phone, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                ),
                const SizedBox(height: 16),

                // Emergency contact name (OPTIONAL — OP-R4)
                TextFormField(
                  controller: _emergencyNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contacto de emergencia (nombre, opcional)',
                    prefixIcon: Icon(Icons.emergency, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.input,
                  ),
                ),
                const SizedBox(height: 16),

                // Emergency contact phone (OPTIONAL — OP-R4)
                TextFormField(
                  controller: _emergencyPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contacto de emergencia (teléfono, opcional)',
                    prefixIcon: Icon(Icons.phone_in_talk, color: AppColors.textMuted),
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
