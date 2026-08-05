/// ProfileEditScreen — editable profile fields (OP-R3).
///
/// Three required fields (full_name, bike_model, city) + optional phone and
/// emergency contact, prefilled from the `users` row via
/// `ProfileRepository.fetchProfile`. Save goes through the shared
/// `ProfileRepository.saveProfile` (same persistence path as onboarding).
/// No cédula / identity-document field anywhere (OP-R2).
///
/// The shell gate is NOT re-run after save — the next app start re-queries
/// the users row and shows updated values (spec OP-R3).
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../auth/data/repositories/profile_repository.dart';

class ProfileEditScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the app-wide Supabase client.
  final SupabaseClient? client;

  /// Injectable for tests; defaults to a repo over [client].
  final ProfileRepository? repository;

  const ProfileEditScreen({super.key, this.client, this.repository});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bikeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  SupabaseClient get _client => widget.client ?? Supabase.instance.client;
  ProfileRepository get _repository =>
      widget.repository ?? ProfileRepository(client: _client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      final row = await _repository.fetchProfile(user.id);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = row?['full_name'] as String? ?? '';
        _bikeCtrl.text = row?['bike_model'] as String? ?? '';
        _cityCtrl.text = row?['city'] as String? ?? '';
        _phoneCtrl.text = row?['phone'] as String? ?? '';
        _emergencyNameCtrl.text =
            row?['emergency_contact_name'] as String? ?? '';
        _emergencyPhoneCtrl.text =
            row?['emergency_contact_phone'] as String? ?? '';
        _loading = false;
      });
    } catch (_) {
      // Row missing (pre-trigger account) → render empty form; save will
      // upsert the row (users_insert_own covers it).
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bikeCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _repository.saveProfile(
        userId: user.id,
        fullName: _nameCtrl.text,
        bikeModel: _bikeCtrl.text,
        city: _cityCtrl.text,
        phone: _phoneCtrl.text,
        emergencyName: _emergencyNameCtrl.text,
        emergencyPhone: _emergencyPhoneCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
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
        title: const Text('Editar perfil'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full name (REQUIRED)
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(
                            Icons.person,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.input,
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Bike model (REQUIRED)
                      TextFormField(
                        controller: _bikeCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Tu moto (marca y modelo)',
                          hintText: 'Ej: Yamaha MT-07',
                          hintStyle: TextStyle(color: AppColors.textDisabled),
                          prefixIcon: Icon(
                            Icons.motorcycle,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.input,
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // City (REQUIRED)
                      TextFormField(
                        controller: _cityCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          hintText: 'Ej: Medellín',
                          hintStyle: TextStyle(color: AppColors.textDisabled),
                          prefixIcon: Icon(
                            Icons.location_city,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.input,
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Phone (OPTIONAL)
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Teléfono (opcional)',
                          prefixIcon: Icon(
                            Icons.phone,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.input,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Emergency contact name (OPTIONAL)
                      TextFormField(
                        controller: _emergencyNameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText:
                              'Contacto de emergencia (nombre, opcional)',
                          prefixIcon: Icon(
                            Icons.emergency,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.input,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Emergency contact phone (OPTIONAL)
                      TextFormField(
                        controller: _emergencyPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText:
                              'Contacto de emergencia (teléfono, opcional)',
                          prefixIcon: Icon(
                            Icons.phone_in_talk,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.input,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      SizedBox(
                        width: double.infinity,
                        height: AppSpacing.buttonHeight,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnAmber,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mdCircular,
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'GUARDAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
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
