/// Profile — user info, settings, membership status.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_buttons.dart';
import '../../../patches/presentation/screens/patches_screen.dart';
import '../../../patches/presentation/bloc/patches_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.card,
                ),
                child: const Icon(AppIcons.profile, color: AppColors.textMuted, size: 40),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Usuario de Prueba', style: AppTypography.h2),
              Text('test@moteros.app', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.md),

              // Membership status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: AppGradients.cardHighlight,
                  borderRadius: AppRadius.mdCircular,
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.fuel, color: AppColors.primary, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MEMBREŠÍA ACTUAL', style: AppTypography.caption),
                          const SizedBox(height: 4),
                          Text('Miembro', style: AppTypography.h3.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Ver plan', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Menu items
              _menuItem(AppIcons.badge, 'Mis Parches', '12 coleccionados', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatchesScreen()))),
              _menuItem(AppIcons.route, 'Historial de Rutas', '3 lugares visitados'),
              _menuItem(AppIcons.group, 'Comunidad', 'Conectar con moteros'),
              _menuItem(AppIcons.shield, 'Modo Conducción', 'Interfaz simplificada'),
              _menuItem(AppIcons.settings, 'Configuración', ''),
              const SizedBox(height: AppSpacing.lg),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(AppIcons.logout, color: AppColors.error),
                  label: const Text('Cerrar Sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withAlpha(60)),
                    minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: AppSpacing.iconMd),
      title: Text(title, style: AppTypography.body),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted))
          : null,
      trailing: Icon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
