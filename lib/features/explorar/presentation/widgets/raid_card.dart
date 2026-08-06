/// Raid Card — banner premium para las próximas raids en Explorar.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../trust/domain/models/trust_signals.dart';
import '../../../trust/presentation/widgets/trust_signals_row.dart';

class RaidCard extends StatelessWidget {
  final Map<String, dynamic> raid;
  final VoidCallback? onTap;

  const RaidCard({
    super.key,
    required this.raid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = raid['description'] as String? ?? 'Raid';
    final mode = raid['mode'] as String? ?? 'Free Ride';
    final participants = (raid['raid_participants'] as List?)?.length ?? 0;
    final scheduledAt = raid['scheduled_at'] as String? ?? '';
    final date = _formatDate(scheduledAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF101E43),
                  Color(0xFF183776),
                  Color(0xFF2453A6),
                ],
                stops: [0.0, 0.58, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF183776).withAlpha(75),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  top: -38,
                  child: Container(
                    width: 135,
                    height: 135,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(10),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -55,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4D78D4).withAlpha(22),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(18),
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: Colors.white.withAlpha(18),
                              ),
                            ),
                            child: const Icon(
                              Icons.route_rounded,
                              color: Color(0xFFFF9418),
                              size: 29,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.h2.copyWith(
                                    color: Colors.white,
                                    fontSize: 21,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _infoChip(
                                      icon: Icons.bolt_rounded,
                                      text: mode.toUpperCase(),
                                      foreground: const Color(0xFFFFA11A),
                                      background: const Color(0xFFFF9418)
                                          .withAlpha(24),
                                    ),
                                    _infoChip(
                                      icon: Icons.calendar_month_rounded,
                                      text: date,
                                      foreground: Colors.white70,
                                      background: Colors.white.withAlpha(12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(13),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withAlpha(18),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.people_alt_outlined,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$participants',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (raid['users'] is Map<String, dynamic>) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(23),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withAlpha(15),
                            ),
                          ),
                          child: TrustSignalsRow(
                            signals: TrustSignals.fromJoinedUserRow(
                              raid['users'] as Map<String, dynamic>?,
                              trips: (raid['creator_trips'] as int?) ?? 0,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 17),
                      Container(
                        height: 1,
                        color: Colors.white.withAlpha(18),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          const Icon(
                            Icons.touch_app_rounded,
                            size: 17,
                            color: Color(0xFF9FF8C4),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Toca para ver detalles y unirte',
                              style: AppTypography.body.copyWith(
                                color: const Color(0xFF9FF8C4),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String value) {
    if (value.isEmpty) return 'Sin fecha';

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }

    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];

    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}
