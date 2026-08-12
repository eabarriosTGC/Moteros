library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/raid_conquest_repository.dart';

class RaidConquestHistoryScreen extends StatefulWidget {
  const RaidConquestHistoryScreen({super.key});

  @override
  State<RaidConquestHistoryScreen> createState() => _RaidConquestHistoryScreenState();
}

class _RaidConquestHistoryScreenState extends State<RaidConquestHistoryScreen> {
  final _repository = RaidConquestRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadMyConquests();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.loadMyConquests());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MIS CONQUISTAS'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return _message(
              Icons.cloud_off,
              RaidConquestRepository.friendlyError(snapshot.error!),
            );
          }
          final arrivals = snapshot.data ?? const [];
          if (arrivals.isEmpty) {
            return _message(
              Icons.emoji_events_outlined,
              'Tus rutas verificadas aparecerán aquí después de escanear un QR en el destino.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: arrivals.length,
              itemBuilder: (context, index) => _card(arrivals[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> arrival) {
    final raid = Map<String, dynamic>.from((arrival['raids'] as Map?) ?? const {});
    final place = Map<String, dynamic>.from((arrival['conquest_places'] as Map?) ?? const {});
    final km = (arrival['verified_km'] as num?)?.toDouble() ?? 0;
    final date = DateTime.tryParse(arrival['verified_at']?.toString() ?? '')?.toLocal();
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    place['name']?.toString() ?? raid['destination_name']?.toString() ?? 'Destino',
                    style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${km.toStringAsFixed(1)} km',
                  style: AppTypography.monoLarge.copyWith(color: AppColors.primary, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${raid['origin_name'] ?? 'Origen'} → ${raid['destination_name'] ?? 'Destino'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              date == null
                  ? 'Fecha no disponible'
                  : '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/${date.year}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (arrival['photo_url'] != null) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: AppRadius.mdCircular,
                child: Image.network(
                  arrival['photo_url'].toString(),
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 70, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}
