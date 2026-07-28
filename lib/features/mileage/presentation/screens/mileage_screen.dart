/// Mileage Screen — main mileage dashboard with total KM display.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/mileage_bloc.dart';
import '../bloc/mileage_event.dart';
import '../bloc/mileage_state.dart';

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
    );
  }

  Widget _buildDashboard(MileageLoaded state) {
    final mileage = state.mileage;
    final totalKm = (mileage?['total_km'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: () async => _loadMileage(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total KM hero card
            _buildTotalKmCard(totalKm),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalKmCard(double totalKm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgCircular,
      ),
      child: Column(
        children: [
          const Icon(Icons.speed_rounded, color: AppColors.textOnAmber, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(
            totalKm.toStringAsFixed(0),
            style: AppTypography.h1.copyWith(color: AppColors.textOnAmber, fontSize: 48, fontWeight: FontWeight.w900),
          ),
          const Text(
            'KM TOTALES',
            style: TextStyle(color: AppColors.textOnAmber, letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.w600),
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
