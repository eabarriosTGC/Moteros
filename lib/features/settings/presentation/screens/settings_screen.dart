/// Settings Screen — Configuración de la app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../profile/presentation/screens/profile_edit_screen.dart';
import '../../../clubs/presentation/screens/clubs_screen.dart';
import 'offline_maps_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Account
  String _email = '';
  String _displayName = '';

  // Notifications
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _raidAlerts = true;

  // Driving
  bool _safeMode = false;
  int _gpsInterval = 10; // seconds

  // Privacy
  bool _profilePublic = true;
  bool _showLocationRaids = true;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = Supabase.instance.client.auth.currentUser;

      setState(() {
        _email = user?.email ?? 'Sin email';
        _displayName = user?.userMetadata?['display_name'] as String? ??
            user?.userMetadata?['username'] as String? ??
            'Usuario';

        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled =
            prefs.getBool('vibration_enabled') ?? true;
        _raidAlerts = prefs.getBool('raid_alerts') ?? true;
        _safeMode = prefs.getBool('safe_mode') ?? false;
        _gpsInterval = prefs.getInt('gps_interval') ?? 10;
        _profilePublic = prefs.getBool('profile_public') ?? true;
        _showLocationRaids =
            prefs.getBool('show_location_raids') ?? true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('CONFIGURACIÓN',
            style:
                AppTypography.h2.copyWith(color: AppColors.primary)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNotificationsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDrivingSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPrivacySection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAppearanceSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAboutSection(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Section Builder ──

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title,
          style: AppTypography.label.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final idx = entry.key;
          final child = entry.value;
          final isLast = idx == children.length - 1;
          return Column(
            children: [
              child,
              if (!isLast)
                const Divider(
                  height: 1,
                  color: AppColors.border,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    Color iconColor = AppColors.textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
        children: [
          Icon(icon,
              color: iconColor, size: AppSpacing.iconSm),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ),
      ),
    );
  }

  Widget _amberToggle(bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 48,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withAlpha(60),
        inactiveTrackColor: AppColors.trackInactive,
      ),
    );
  }

  // ── Account Section ──

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('CUENTA'),
        _sectionCard([
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Icon(Icons.person,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      Text(_email,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showChangePasswordDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('CAMBIAR',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ],
            ),
          ),
          _settingRow(
            icon: Icons.badge_outlined,
            title: 'Nombre',
            subtitle: _displayName,
            trailing: Icon(Icons.edit_outlined,
                color: AppColors.textMuted, size: 18),
          ),
          // W1 (M-PN-2): acciones re-homedas desde ProfileScreen — la
          // acción de editar sobrevive al cierre del entry point.
          _settingRow(
            icon: Icons.badge_outlined,
            title: 'Editar perfil',
            trailing: const Icon(AppIcons.chevronRight,
                color: AppColors.textMuted, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
          ),
          _settingRow(
            icon: Icons.groups_outlined,
            title: 'Clanes',
            subtitle: 'Solicitudes, miembros y verificación',
            trailing: const Icon(AppIcons.chevronRight,
                color: AppColors.textMuted, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClubsScreen()),
            ),
          ),
          _settingRow(
            icon: Icons.logout,
            iconColor: AppColors.error,
            title: 'Cerrar sesión',
            trailing: const Icon(AppIcons.chevronRight,
                color: AppColors.textMuted, size: 20),
            onTap: () => context.read<AuthBloc>().add(LogoutRequested()),
          ),
        ]),
      ],
    );
  }

  // ── Notifications Section ──

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('NOTIFICACIONES'),
        _sectionCard([
          _settingRow(
            icon: Icons.volume_up_outlined,
            title: 'Sonidos',
            trailing: _amberToggle(_soundEnabled, (v) {
              setState(() => _soundEnabled = v);
              _saveToggle('sound_enabled', v);
            }),
          ),
          _settingRow(
            icon: Icons.vibration_outlined,
            title: 'Vibración',
            trailing: _amberToggle(_vibrationEnabled, (v) {
              setState(() => _vibrationEnabled = v);
              _saveToggle('vibration_enabled', v);
            }),
          ),
          _settingRow(
            icon: Icons.campaign_outlined,
            title: 'Alertas de Raid',
            subtitle: 'Recibir notificaciones de raids cercanos',
            trailing: _amberToggle(_raidAlerts, (v) {
              setState(() => _raidAlerts = v);
              _saveToggle('raid_alerts', v);
            }),
          ),
        ]),
      ],
    );
  }

  // ── Driving Section ──

  Widget _buildDrivingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('CONDUCCIÓN'),
        _sectionCard([
          _settingRow(
            icon: Icons.shield_outlined,
            title: 'Modo Conducción (Safe Mode)',
            subtitle: 'Interfaz simplificada mientras conduces',
            trailing: _amberToggle(_safeMode, (v) {
              setState(() => _safeMode = v);
              _saveToggle('safe_mode', v);
            }),
          ),
          _settingRow(
            icon: Icons.gps_fixed,
            title: 'Intervalo GPS',
            subtitle: '${_gpsInterval}s entre actualizaciones',
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _gpsInterval,
                  dropdownColor: AppColors.surface,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                  items: [5, 10, 15, 30, 60].map((sec) {
                    return DropdownMenuItem(
                      value: sec,
                      child: Text('${sec}s'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _gpsInterval = v);
                      _saveInt('gps_interval', v);
                    }
                  },
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Contacto de Emergencia')),
                  body: const Center(child: Text('Contacto de emergencia no disponible en esta versión')),
                ),
              ),
            ),
            child: _settingRow(
              icon: Icons.warning_amber_rounded,
              title: 'Contacto de Emergencia',
              subtitle: 'Configurar contacto SOS',
              trailing: const Icon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Privacy Section ──

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('PRIVACIDAD'),
        _sectionCard([
          _settingRow(
            icon: Icons.visibility_outlined,
            title: 'Perfil público',
            subtitle: 'Otros usuarios pueden ver tu perfil',
            trailing: _amberToggle(_profilePublic, (v) {
              setState(() => _profilePublic = v);
              _saveToggle('profile_public', v);
            }),
          ),
          _settingRow(
            icon: Icons.location_on_outlined,
            title: 'Mostrar ubicación en raids',
            trailing: _amberToggle(_showLocationRaids, (v) {
              setState(() => _showLocationRaids = v);
              _saveToggle('show_location_raids', v);
            }),
          ),
        ]),
      ],
    );
  }

  // ── Appearance Section ──

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('APARIENCIA'),
        _sectionCard([
          _settingRow(
            icon: Icons.brightness_6_outlined,
            title: 'Tema claro',
            subtitle: 'Modo claro de alto contraste para luz solar',
            trailing: BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, state) => _amberToggle(
                state == ThemeMode.light,
                (v) => context.read<ThemeCubit>().toggle(),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── About Section ──

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('ACERCA DE'),
        _sectionCard([
          _settingRow(
            icon: Icons.map_outlined,
            title: 'Mapas Offline',
            trailing: Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OfflineMapsScreen(),
              ),
            ),
          ),
          _settingRow(
            icon: Icons.info_outline,
            title: 'Versión',
            trailing: Text('1.0.0',
                style: AppTypography.body.copyWith(
                    color: AppColors.textMuted)),
          ),
          _settingRow(
            icon: Icons.code_outlined,
            title: 'Créditos',
            trailing: Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ),
        ]),
      ],
    );
  }

  // ── Change Password Dialog ──

  void _showChangePasswordDialog() {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    bool changing = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular),
              title: Text('CAMBIAR CONTRASEÑA',
                  style: AppTypography.h3
                      .copyWith(color: AppColors.primary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _passwordField(
                    controller: currentPwController,
                    hint: 'Contraseña actual',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _passwordField(
                    controller: newPwController,
                    hint: 'Nueva contraseña',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _passwordField(
                    controller: confirmPwController,
                    hint: 'Confirmar nueva contraseña',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('CANCELAR',
                      style: AppTypography.button
                          .copyWith(color: AppColors.textMuted)),
                ),
                TextButton(
                  onPressed: changing
                      ? null
                      : () async {
                          final newPw = newPwController.text.trim();
                          final confirm =
                              confirmPwController.text.trim();

                          if (newPw.isEmpty || newPw.length < 6) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'La contraseña debe tener al menos 6 caracteres'),
                                backgroundColor:
                                    AppColors.error,
                              ),
                            );
                            return;
                          }
                          if (newPw != confirm) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Las contraseñas no coinciden'),
                                backgroundColor:
                                    AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(
                              () => changing = true);
                          try {
                            await Supabase
                                .instance.client.auth
                                .updateUser(
                                    UserAttributes(
                                        password: newPw));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '✅ Contraseña actualizada'),
                                  backgroundColor:
                                      AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(
                                () => changing = false);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor:
                                    AppColors.error,
                              ),
                            );
                          }
                        },
                  child: changing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        )
                      : Text('GUARDAR',
                          style: AppTypography.button.copyWith(
                              color: AppColors.primary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
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
        obscureText: true,
        style: AppTypography.body
            .copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.body
              .copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
