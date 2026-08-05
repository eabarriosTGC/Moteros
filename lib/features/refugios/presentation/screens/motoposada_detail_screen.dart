/// Motoposada Detail — view details + send stay request.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../trust/domain/models/trust_signals.dart';
import '../../../trust/presentation/widgets/trust_signals_row.dart';
import '../bloc/motoposadas_bloc.dart';
import '../bloc/motoposadas_event.dart';
import '../bloc/motoposadas_state.dart';

class MotoposadaDetailScreen extends StatefulWidget {
  final int motoposadaId;
  const MotoposadaDetailScreen({super.key, required this.motoposadaId});

  @override
  State<MotoposadaDetailScreen> createState() => _MotoposadaDetailScreenState();
}

class _MotoposadaDetailScreenState extends State<MotoposadaDetailScreen> {
  final _messageController = TextEditingController();
  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));
  int _guestCount = 1;
  bool _showRequestForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load individual detail not supported in Bloc yet; rely on parent state
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendRequest(int motoposadaId) {
    HapticFeedback.mediumImpact();
    context.read<MotoposadasBloc>().add(
      SendMotoposadaRequest(
        motoposadaId: motoposadaId,
        checkIn: _checkIn,
        checkOut: _checkOut,
        guestCount: _guestCount,
        message: _messageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Try to find motoposada from parent state
    final state = context.read<MotoposadasBloc>().state;
    MotoposadaModel? mp;
    if (state is MotoposadasLoaded) {
      mp = state.motoposadas
          .where((m) => m.id == widget.motoposadaId)
          .firstOrNull;
    } else if (state is MyMotoposadasLoaded) {
      mp = state.motoposadas
          .where((m) => m.id == widget.motoposadaId)
          .firstOrNull;
    }

    return BlocListener<MotoposadasBloc, MotoposadasState>(
      listener: (context, state) {
        if (state is RequestSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Solicitud enviada'),
              backgroundColor: AppColors.success,
            ),
          );
          _showRequestForm = false;
        }
        if (state is MotoposadasError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            mp?.title ?? 'Motoposada',
            style: AppTypography.h2.copyWith(color: AppColors.primary),
          ),
        ),
        body: mp == null
            ? const Center(
                child: Text(
                  'Cargando...',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      _badge(mp.typeLabel, AppColors.primary),
                      const SizedBox(height: AppSpacing.sm),
                      // Visibility + guests
                      Row(
                        children: [
                          _miniBadge(mp.visibilityLabel, AppColors.secondary),
                          const SizedBox(width: AppSpacing.sm),
                          _miniBadge(
                            '${mp.maxGuests} huésped(es)',
                            AppColors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Host info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.mdCircular,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                  child: const Icon(
                                    AppIcons.profile,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mp.hostName ?? 'Anfitrión',
                                        style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (mp.hostLevel != null)
                                        Text(
                                          'Nivel ${mp.hostLevel}',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Public host signals (F-M13, TS-R4): sourced from the
                            // joined users row + get_trip_counts RPC — never a
                            // saved_routes embed (RLS zeroes non-owner counts).
                            // Renders whenever the host is present; TrustSignalsRow
                            // shows zeros when data is missing (spec TS-R1).
                            if (mp.hostName != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              TrustSignalsRow(
                                signals: TrustSignals(
                                  memberSince: mp.hostMemberSince,
                                  trips: mp.hostTrips,
                                  km: mp.hostKm,
                                  badges: mp.hostBadges,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Description
                      if (mp.description.isNotEmpty) ...[
                        Text(
                          'DESCRIPCIÓN',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          mp.description,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      // Rules
                      if (mp.rules.isNotEmpty) ...[
                        Text(
                          'REGLAS',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withAlpha(10),
                            borderRadius: AppRadius.mdCircular,
                            border: Border.all(
                              color: AppColors.warning.withAlpha(30),
                            ),
                          ),
                          child: Text(
                            mp.rules,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      // Location
                      Text(
                        'UBICACIÓN',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${mp.lat.toStringAsFixed(4)}, ${mp.lng.toStringAsFixed(4)}',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      if (mp.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          mp.address,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      // Request form
                      if (!_showRequestForm) ...[
                        SizedBox(
                          width: double.infinity,
                          height: AppSpacing.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _showRequestForm = true),
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('SOLICITAR ESTADÍA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnAmber,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.mdCircular,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildRequestForm(mp.id),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRequestForm(int mpId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOLICITUD',
            style: AppTypography.h3.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          // Check-in
          _datePicker('Llegada', _checkIn, (d) => setState(() => _checkIn = d)),
          const SizedBox(height: AppSpacing.sm),
          // Check-out
          _datePicker(
            'Salida',
            _checkOut,
            (d) => setState(() => _checkOut = d),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Guests
          Row(
            children: [
              const Text(
                'Huéspedes: ',
                style: TextStyle(color: AppColors.textMuted),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: _guestCount > 1
                    ? () => setState(() => _guestCount--)
                    : null,
              ),
              Text('$_guestCount', style: AppTypography.h3),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary, size: 20),
                onPressed: () => setState(() => _guestCount++),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Message
          Container(
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 3,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Contale al anfitrión sobre vos...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(AppSpacing.md),
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _sendRequest(mpId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnAmber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'ENVIAR',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => setState(() => _showRequestForm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('CANCELAR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePicker(
    String label,
    DateTime selected,
    ValueChanged<DateTime> onPicked,
  ) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selected,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) onPicked(date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$label: ${selected.day}/${selected.month}',
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withAlpha(25),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withAlpha(60)),
    ),
    child: Text(
      t.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: c,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _miniBadge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withAlpha(15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      t,
      style: AppTypography.caption.copyWith(color: c, fontSize: 10),
    ),
  );
}
