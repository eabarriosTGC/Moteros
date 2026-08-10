library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/raid_conquest_repository.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';
import '../screens/raid_arrival_screen.dart';
import '../screens/raid_qr_management_screen.dart';

Future<void> showRaidJoinSheet(
  BuildContext context,
  Map<String, dynamic> raid, {
  String? currentUserId,
  Widget Function(Map<String, dynamic> raid)? arrivalScreenBuilder,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => RaidJoinSheet(
      raid: raid,
      currentUserId: currentUserId,
      arrivalScreenBuilder: arrivalScreenBuilder,
    ),
  );
}

class RaidJoinSheet extends StatelessWidget {
  final Map<String, dynamic> raid;
  final String? currentUserId;

  /// Seam de testabilidad: en pruebas permite sustituir RaidArrivalScreen
  /// (que crea un MobileScannerController de cámara real) por un stub.
  final Widget Function(Map<String, dynamic> raid)? arrivalScreenBuilder;

  const RaidJoinSheet({
    super.key,
    required this.raid,
    this.currentUserId,
    this.arrivalScreenBuilder,
  });

  String get _raidId => raid['id'].toString();

  Map<String, dynamic> _liveRaid(RaidState state) {
    if (state is RaidsLoaded) {
      for (final item in state.raids) {
        if (item['id'].toString() == _raidId) return item;
      }
    }
    return raid;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        final item = _liveRaid(state);
        final type = item['raid_type']?.toString() ?? 'scheduled';
        final permanent = type == 'permanent';
        final participants = ((item['raid_participants'] as List?) ?? const []);
        final participantCount =
            (item['participant_count'] as num?)?.toInt() ?? participants.length;
        final userId = currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
        final joined = userId != null &&
            participants.any((participant) => participant['user_id'] == userId);
        final isHost = userId != null && item['host_id'] == userId;
        final distance = (item['distance_km'] as num?)?.toDouble();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(25),
                      child: Icon(
                        permanent ? Icons.all_inclusive : Icons.event,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['description']?.toString() ?? 'Raid',
                            style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
                          ),
                          Text(
                            permanent ? 'RAID PERMANENTE' : 'RODADA CON FECHA',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _info(Icons.trip_origin, 'Origen', item['origin_name']?.toString() ?? 'Punto de salida'),
                _info(Icons.location_on, 'Destino', item['destination_name']?.toString() ?? 'Destino'),
                if (distance != null)
                  _info(Icons.route, 'Distancia verificada', '${distance.toStringAsFixed(1)} km'),
                if (!permanent)
                  _info(Icons.schedule, 'Fecha', _formatDate(item['starts_at'] ?? item['scheduled_at'])),
                _info(
                  Icons.groups,
                  permanent ? 'Conquistadores' : 'Moteros inscritos',
                  permanent
                      ? 'Completa el raid cuando quieras'
                      : '$participantCount confirmado${participantCount == 1 ? '' : 's'}',
                ),
                if (!permanent && participantCount > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showRoster(context, item),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('VER QUIÉNES VAN'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (isHost) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _manageCodes(context, item),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('ADMINISTRAR CÓDIGOS'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (permanent || joined) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _verifyArrival(context, item),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('VERIFICAR LLEGADA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: userId == null ? null : () => _join(context, item, userId),
                      icon: const Icon(Icons.group_add),
                      label: const Text('UNIRME A LA RODADA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                ],
                if (!permanent && joined && !isHost)
                  Center(
                    child: TextButton(
                      onPressed: () => _leave(context, item, userId),
                      child: const Text('ABANDONAR RODADA', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(value, style: const TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );

  String _formatDate(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return 'Fecha por confirmar';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} · '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _join(
    BuildContext context,
    Map<String, dynamic> raid,
    String userId,
  ) async {
    final showOnRoster = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Privacidad de la rodada'),
        content: const Text(
          '¿Quieres que los demás inscritos vean tu nombre y foto en la lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('SOLO CONTADOR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('MOSTRARME'),
          ),
        ],
      ),
    );
    if (showOnRoster == null || !context.mounted) return;
    context.read<RaidBloc>().add(
          JoinRaid(
            raidId: raid['id'].toString(),
            userId: userId,
            showOnRoster: showOnRoster,
          ),
        );
    HapticFeedback.mediumImpact();
  }

  void _leave(BuildContext context, Map<String, dynamic> raid, String userId) {
    context.read<RaidBloc>().add(
          LeaveRaid(raidId: raid['id'].toString(), userId: userId),
        );
    HapticFeedback.mediumImpact();
  }

  void _verifyArrival(BuildContext context, Map<String, dynamic> raid) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            arrivalScreenBuilder?.call(raid) ?? RaidArrivalScreen(raid: raid),
      ),
    );
  }

  void _manageCodes(BuildContext context, Map<String, dynamic> raid) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RaidQrManagementScreen(raid: raid)),
    );
  }

  void _showRoster(BuildContext context, Map<String, dynamic> raid) {
    final raidId = (raid['id'] as num).toInt();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: RaidConquestRepository().loadRoster(raidId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            final people = snapshot.data ?? const [];
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOTEROS CONFIRMADOS', style: AppTypography.h3.copyWith(color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.sm),
                  if (people.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text(
                        'Los participantes de este raid eligieron no aparecer públicamente.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          final person = people[index];
                          final name = person['full_name'] ?? person['username'] ?? 'Motero';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: person['profile_image'] == null
                                  ? null
                                  : NetworkImage(person['profile_image'].toString()),
                              child: person['profile_image'] == null ? const Icon(Icons.person) : null,
                            ),
                            title: Text(name.toString()),
                            subtitle: person['username'] == null
                                ? null
                                : Text('@${person['username']}'),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
