/// Mileage Screen — main mileage dashboard with stats, chart, and recent entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/mileage_bloc.dart';
import '../bloc/mileage_event.dart';
import '../bloc/mileage_state.dart';
import 'mileage_manual_entry_screen.dart';

class MileageScreen extends StatefulWidget {
  const MileageScreen({super.key});

  @override
  State<MileageScreen> createState() => _MileageScreenState();
}

class _MileageScreenState extends State<MileageScreen> {
  @override
  void initState() {
    super.initState();
    _loadMileage();
  }

  void _loadMileage() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isNotEmpty) {
      context.read<MileageBloc>().add(LoadMileage(userId: userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.speed_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('MI KILOMETRAJE', style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
      body: BlocBuilder<MileageBloc, MileageState>(
        builder: (context, state) {
          if (state is MileageLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is MileageLoaded) {
            return _buildDashboard(state);
          }
          if (state is MileageError) {
            return _buildError(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MileageManualEntryScreen()),
        ).then((result) {
          if (result == true) _loadMileage();
        }),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnAmber),
        label: const Text('Agregar KM', style: TextStyle(color: AppColors.textOnAmber)),
      ),
    );
  }

  Widget _buildDashboard(MileageLoaded state) {
    final mileage = state.mileage;
    final entries = state.entries ?? [];

    final totalKm = (mileage?['total_km'] as num?)?.toDouble() ?? 0;
    final verifiedKm = (mileage?['verified_km'] as num?)?.toDouble() ?? 0;
    final manualKm = (mileage?['manual_km'] as num?)?.toDouble() ?? 0;
    final monthlyData = mileage?['monthly_breakdown'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () async => _loadMileage(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat cards row
            Row(
              children: [
                Expanded(child: _statCard('${totalKm.toStringAsFixed(0)}', 'KM TOTAL', Icons.speed_rounded, AppColors.primary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _statCard('${verifiedKm.toStringAsFixed(0)}', 'VERIFICADOS', Icons.verified_rounded, AppColors.success)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _statCard('${manualKm.toStringAsFixed(0)}', 'MANUALES', Icons.edit_rounded, AppColors.secondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Monthly chart section
            if (monthlyData.isNotEmpty) ...[
              Text('KILOMETRAJE MENSUAL', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              _buildMonthlyChart(monthlyData),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Recent entries
            Text('ENTRADAS RECIENTES', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
            const SizedBox(height: AppSpacing.sm),
            if (entries.isEmpty)
              _buildEmptyEntries()
            else
              ...entries.take(10).map((entry) => _buildEntryCard(entry)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppSpacing.iconMd),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.monoSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(List monthlyData) {
    // Simple bar chart using containers
    final maxVal = monthlyData.fold<num>(0, (max, m) {
      final val = (m['total'] as num?) ?? 0;
      return val > max ? val : max;
    });

    return Container(
      height: 140,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: monthlyData.take(12).map((m) {
          final value = ((m['total'] as num?) ?? 0).toDouble();
          final month = m['month'] as String? ?? '';
          final ratio = maxVal > 0 ? value / maxVal.toDouble() : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${value.toStringAsFixed(0)}',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 7),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (ratio * 80).clamp(4, 80).toDouble(),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(180),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(month.length >= 3 ? month.substring(0, 3) : month,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 7),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final amount = (entry['amount_km'] as num?)?.toDouble() ?? 0;
    final isVerified = entry['is_verified'] as bool?;
    final rejectionReason = entry['rejection_reason'] as String?;
    final createdAt = entry['created_at'] as String? ?? '';
    final date = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    final photoUrl = entry['odometer_photo_url'] as String?;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isVerified == true) {
      statusText = 'Verificado';
      statusColor = AppColors.success;
      statusIcon = Icons.verified_rounded;
    } else if (rejectionReason != null) {
      statusText = 'Rechazado';
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusText = 'Pendiente';
      statusColor = AppColors.warning;
      statusIcon = Icons.pending_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.smCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Photo thumbnail
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: AppRadius.smCircular,
              ),
              child: photoUrl != null
                  ? ClipRRect(
                      borderRadius: AppRadius.smCircular,
                      child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                        const Icon(Icons.speed, color: AppColors.textMuted, size: 20),
                      ),
                    )
                  : const Icon(Icons.speed, color: AppColors.textMuted, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${amount.toStringAsFixed(1)} km',
                    style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  Text(date, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: statusColor.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusText,
                    style: AppTypography.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEntries() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.speed_rounded, size: 48, color: AppColors.textMuted.withAlpha(60)),
          const SizedBox(height: AppSpacing.sm),
          Text('Sin entradas aún', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text('Agrega KM manuales desde el botón +',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTypography.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadMileage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }
}
