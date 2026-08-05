/// TrustSignalsRow — shared public signals row for host cards and RaidCard
/// (F-M13, TS-R4/TS-R5).
///
/// Dumb stateless widget: renders exactly the 4 public signal values from a
/// [TrustSignals] object. No Supabase dependency, no trust-score /
/// reputation / rating surface (TS-R2, TS-R3) — the model has no such field
/// by construction, so this widget cannot render one.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../trust/domain/models/trust_signals.dart';

class TrustSignalsRow extends StatelessWidget {
  final TrustSignals signals;

  const TrustSignalsRow({super.key, required this.signals});

  @override
  Widget build(BuildContext context) {
    final memberSince = signals.memberSinceLabel;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (memberSince.isNotEmpty) _chip(memberSince, AppColors.secondary),
        _chip('${signals.trips} viajes', AppColors.primary),
        _chip('${signals.km} km', AppColors.success),
        _chip('${signals.badges} insignias', AppColors.warning),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: AppRadius.smCircular,
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
