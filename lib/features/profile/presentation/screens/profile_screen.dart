/// ProfileScreen — lightweight wrapper that embeds ShowcaseProfileScreen
/// and keeps the logout button in the AppBar.
///
/// OP-R3: the AppBar exposes "EDITAR PERFIL", which pushes ProfileEditScreen
/// (editable profile fields). The onboarding gate is NOT re-run on save —
/// the next app start re-queries the users row (spec OP-R3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../showcase/presentation/screens/showcase_profile_screen.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(AppIcons.profile, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'PERFIL',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          // OP-R3: editable profile fields entry.
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
              );
            },
            child: const Text(
              'EDITAR PERFIL',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.settings, color: AppColors.textMuted),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(AppIcons.logout, color: AppColors.error),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: const ShowcaseProfileScreen(),
    );
  }
}
