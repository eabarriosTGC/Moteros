/// Parches Digitales — virtual patches displayed like embroidered badges.
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
        if (state is PatchesLoaded) return _buildScreen(state);
        return Scaffold(appBar: AppBar(title: const Text('Mis Parches')), body: const Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildScreen(PatchesLoaded state) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Parches')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(children: [
            // Stats
            Container(
              width: double.infinity, padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: AppGradients.cardHighlight,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${state.earned}', style: AppTypography.monoMedium.copyWith(color: AppColors.primary)),
                const Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 20)),
                Text('${state.total}', style: AppTypography.monoMedium.copyWith(color: AppColors.textMuted)),
                const SizedBox(width: AppSpacing.sm),
                Text('PARCHES', style: AppTypography.label.copyWith(color: AppColors.textMuted)),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Patch grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
              itemCount: state.patches.length,
              itemBuilder: (_, i) => _buildPatch(state.patches[i]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPatch(PatchEntity patch) {
    final color = Color(int.parse('FF${patch.colorHex}', radix: 16));
    return Container(
      decoration: BoxDecoration(
        color: patch.earned ? color.withAlpha(10) : AppColors.card,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: patch.earned ? color.withAlpha(60) : AppColors.border),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Embroidery ring
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: patch.earned ? color : AppColors.metallicDark,
              width: 3,
            ),
          ),
          child: Center(child: Text(patch.icon, style: TextStyle(
            fontSize: patch.earned ? 28 : 28,
            color: patch.earned ? null : AppColors.textMuted,
          ))),
        ),
        const SizedBox(height: 8),
        Text(patch.name, style: AppTypography.bodySmall.copyWith(
          color: patch.earned ? AppColors.textPrimary : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ), textAlign: TextAlign.center, maxLines: 2),
        if (!patch.earned) ...[
          const SizedBox(height: 4),
          Icon(AppIcons.lock, color: AppColors.textMuted, size: 14),
        ],
      ]),
    );
  }
}
