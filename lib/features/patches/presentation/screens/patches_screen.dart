/// Parches Digitales — rediseño AsfaltoClub con Supabase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/patches_bloc.dart';

class PatchesScreen extends StatefulWidget {
  const PatchesScreen({super.key});

  @override
  State<PatchesScreen> createState() => _PatchesScreenState();
}

class _PatchesScreenState extends State<PatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatchesBloc>().add(LoadPatches());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatchesBloc, PatchesState>(
      builder: (context, state) {
        if (state is PatchesLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is PatchesError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.error,
                      color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error al cargar parches',
                      style: AppTypography.h2
                          .copyWith(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: Text(state.msg,
                        style: AppTypography.body.copyWith(
                            color: AppColors.textMuted),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<PatchesBloc>().add(LoadPatches()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnAmber,
                    ),
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is PatchesLoaded) return _buildScreen(state);
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Text('Inicializando...',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text('MIS PARCHES',
          style: AppTypography.h2.copyWith(color: AppColors.primary)),
      centerTitle: true,
    );
  }

  Widget _buildScreen(PatchesLoaded state) {
    final progress = state.total > 0 ? state.earned / state.total : 0.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // ── Progress header ──
              Container(
                width: double.infinity,
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mdCircular,
                  border: Border.all(
                      color: AppColors.primary.withAlpha(30)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${state.earned}',
                            style: AppTypography.monoMedium
                                .copyWith(color: AppColors.primary)),
                        const Text(' / ',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 20)),
                        Text('${state.total}',
                            style: AppTypography.monoMedium
                                .copyWith(color: AppColors.textMuted)),
                        const SizedBox(width: AppSpacing.sm),
                        Text('PARCHES',
                            style: AppTypography.label.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // ── Progress bar (ámbar) ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.trackInactive,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.trackActive),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% completado',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Grid de parches ──
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: state.patches.length,
                itemBuilder: (_, i) =>
                    _buildPatchBadge(state.patches[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatchBadge(PatchEntity patch) {
    final isEarned = patch.earned;

    Color badgeColor;
    try {
      badgeColor = Color(int.parse('FF${patch.colorHex}', radix: 16));
    } catch (_) {
      badgeColor = AppColors.primary;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isEarned
            ? badgeColor.withAlpha(15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isEarned
              ? badgeColor.withAlpha(80)
              : AppColors.border,
          width: isEarned ? 2 : 1,
        ),
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: badgeColor.withAlpha(40),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Badge content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(patch.icon,
                    style: TextStyle(
                      fontSize: 28,
                      color: isEarned
                          ? null
                          : AppColors.textDisabled,
                    )),
                const SizedBox(height: 4),
                Text(
                  patch.name,
                  style: AppTypography.caption.copyWith(
                    color: isEarned
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight:
                        isEarned ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Lock icon for unearned
          if (!isEarned)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(AppIcons.lock,
                  color: AppColors.textMuted, size: 14),
            ),

          // Checkmark for earned
          if (isEarned)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    color: Colors.black, size: 12),
              ),
            ),

          // Glow overlay for earned
          if (isEarned)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        badgeColor.withAlpha(10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
