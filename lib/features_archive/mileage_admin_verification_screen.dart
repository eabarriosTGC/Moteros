/// Admin Mileage Verification Screen — approve/reject pending manual mileage entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/mileage_bloc.dart';
import '../bloc/mileage_event.dart';
import '../bloc/mileage_state.dart';

class AdminMileageVerificationScreen extends StatefulWidget {
  const AdminMileageVerificationScreen({super.key});

  @override
  State<AdminMileageVerificationScreen> createState() => _AdminMileageVerificationScreenState();
}

class _AdminMileageVerificationScreenState extends State<AdminMileageVerificationScreen> {
  final _rejectionController = TextEditingController();
  int? _rejectingEntryId;

  @override
  void initState() {
    super.initState();
    context.read<MileageBloc>().add(const LoadPendingVerifications());
  }

  @override
  void dispose() {
    _rejectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('VERIFICAR KM', style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
      body: BlocBuilder<MileageBloc, MileageState>(
        builder: (context, state) {
          if (state is MileageLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is PendingVerificationsLoaded) {
            final entries = state.entries;
            if (entries.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<MileageBloc>().add(const LoadPendingVerifications()),
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: entries.length,
                itemBuilder: (_, i) => _buildVerificationCard(entries[i]),
              ),
            );
          }
          if (state is MileageError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(state.message, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => context.read<MileageBloc>().add(const LoadPendingVerifications()),
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
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> entry) {
    final id = entry['id'] as int? ?? 0;
    final userId = entry['user_id'] as String? ?? 'Desconocido';
    final amount = (entry['amount_km'] as num?)?.toDouble() ?? 0;
    final photoUrl = entry['odometer_photo_url'] as String?;
    final createdAt = entry['created_at'] as String? ?? '';
    final date = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    final notes = entry['notes'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Usuario: ${userId.length > 8 ? userId.substring(0, 8) : userId}',
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    Text(date, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              // Amount badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: Text('${amount.toStringAsFixed(1)} KM',
                  style: AppTypography.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Photo preview
          if (photoUrl != null) ...[
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: AppRadius.smCircular,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.smCircular,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, color: AppColors.textMuted, size: 32),
                        Text('Sin foto', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Notes
          if (notes != null && notes.isNotEmpty) ...[
            Text('Notas: $notes', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Photo capture location
          if (entry['photo_lat'] != null && entry['photo_lng'] != null) ...[
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${(entry['photo_lat'] as num).toStringAsFixed(4)}, ${(entry['photo_lng'] as num).toStringAsFixed(4)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Action buttons
          if (_rejectingEntryId == id) ...[
            // Rejection form
            TextField(
              controller: _rejectionController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Motivo de rechazo...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smCircular,
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _rejectingEntryId = null;
                        _rejectionController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<MileageBloc>().add(VerifyManualEntry(
                            entryId: id,
                            approved: false,
                            rejectionReason: _rejectionController.text.trim().isEmpty
                                ? 'Foto no válida'
                                : _rejectionController.text.trim(),
                          ));
                      setState(() {
                        _rejectingEntryId = null;
                        _rejectionController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
                    ),
                    child: const Text('RECHAZAR'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<MileageBloc>().add(VerifyManualEntry(
                            entryId: id,
                            approved: true,
                          ));
                    },
                    icon: const Icon(Icons.check, size: AppSpacing.iconSm),
                    label: const Text('APROBAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _rejectingEntryId = id),
                    icon: const Icon(Icons.close, size: AppSpacing.iconSm),
                    label: const Text('RECHAZAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withAlpha(60)),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: AppColors.success.withAlpha(120)),
          const SizedBox(height: AppSpacing.md),
          Text('Sin entradas pendientes', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Todas las entradas han sido verificadas',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => context.read<MileageBloc>().add(const LoadPendingVerifications()),
            icon: const Icon(Icons.refresh, size: AppSpacing.iconSm),
            label: const Text('REFRESCAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
            ),
          ),
        ],
      ),
    );
  }
}
