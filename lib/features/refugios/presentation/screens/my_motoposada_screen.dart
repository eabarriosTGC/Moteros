/// My Motoposada — manage own listing + incoming requests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/services/whatsapp_launcher.dart';
import '../bloc/motoposadas_bloc.dart';
import '../bloc/motoposadas_event.dart';
import '../bloc/motoposadas_state.dart';
import 'create_motoposada_screen.dart';
import 'motoposada_detail_screen.dart';

class MyMotoposadaScreen extends StatefulWidget {
  const MyMotoposadaScreen({super.key});

  @override
  State<MyMotoposadaScreen> createState() => _MyMotoposadaScreenState();
}

class _MyMotoposadaScreenState extends State<MyMotoposadaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Casa de motero (F-M9): cached eligibility (max-1 UX pre-check, M-CRUD-1)
  // and last listings — eligibility/other states must not blank the tab.
  bool? _eligibilityHas;
  List<MotoposadaModel>? _cachedListings;

  // Request tabs (031): caches por rol. RequestsLoaded es un estado único
  // compartido — cada tab renderiza SOLO su rol (isHost) y conserva su
  // último listado cuando el otro tab recarga (patrón _cachedListings).
  List<MotoposadaRequestModel>? _cachedReceived;
  List<MotoposadaRequestModel>? _cachedMyStays;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotoposadasBloc>().add(const LoadMyMotoposadas());
      context.read<MotoposadasBloc>().add(const CheckCasaMoteroEligibility());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MotoposadasBloc, MotoposadasState>(
      listener: (context, state) {
        if (state is CasaMoteroEligibilityLoaded) {
          setState(() => _eligibilityHas = state.has);
        }
        if (state is MyMotoposadasLoaded) {
          _cachedListings = state.motoposadas;
        }
        if (state is RequestsLoaded) {
          if (state.isHost) {
            _cachedReceived = state.requests;
          } else {
            _cachedMyStays = state.requests;
          }
        }
        if (state is MotoposadaRequestContactLoaded) {
          final phone = state.phone;
          if (phone == null || phone.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('La contraparte no registró un teléfono'),
              ),
            );
          } else {
            launchWhatsAppContact(
              context,
              phone,
              'Hola, te contacto por nuestra solicitud de Motoposada en Asfalto Club.',
            );
          }
        }
        if (state is ReviewSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Evaluación publicada'), backgroundColor: AppColors.success),
          );
          context.read<MotoposadasBloc>().add(
            _tabController.index == 1 ? const LoadReceivedRequests() : const LoadMyRequests(),
          );
        }
        if (state is MotoposadaReputationLoaded) {
          _showReputation(state.reputation);
        }
        if (state is MotoposadaIncidentReported) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reporte enviado para revisión'),
            backgroundColor: AppColors.success,
          ));
        }
        if (state is MotoposadaParticipantBlocked) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Usuario bloqueado. No podrán crear nuevas estancias entre ustedes.'),
            backgroundColor: AppColors.success,
          ));
        }
        // Acciones de request (031): feedback + recarga del tab activo.
        if (state is RequestResponded ||
            state is RequestCompleted ||
            state is RequestCancelled) {
          final msg = switch (state) {
            RequestResponded() => '✅ Solicitud actualizada',
            RequestCompleted() => '✅ Estancia finalizada',
            _ => '✅ Solicitud cancelada',
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.success),
          );
          context.read<MotoposadasBloc>().add(
            _tabController.index == 1
                ? const LoadReceivedRequests()
                : const LoadMyRequests(),
          );
        }
      },
      child: BlocBuilder<MotoposadasBloc, MotoposadasState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'MIS MOTOPOSADAS',
                style: AppTypography.h2.copyWith(color: AppColors.primary),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                onTap: (i) {
                  // 031: buzones separados — RECIBIDAS (host, hacia mis
                  // motoposadas) y MIS ESTANCIAS (guest, mis solicitudes).
                  if (i == 1) {
                    context.read<MotoposadasBloc>().add(
                      const LoadReceivedRequests(),
                    );
                  }
                  if (i == 2) {
                    context.read<MotoposadasBloc>().add(const LoadMyRequests());
                  }
                },
                tabs: const [
                  Tab(text: 'MIS PUBLICACIONES'),
                  Tab(text: 'RECIBIDAS'),
                  Tab(text: 'MIS ESTANCIAS'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMyListings(state),
                _buildReceived(state),
                _buildMyStays(state),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateMotoposadaScreen(),
                ),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              icon: const Icon(Icons.add),
              label: const Text('CREAR'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyListings(MotoposadasState state) {
    if (state is MotoposadasLoading && _cachedListings == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state is MotoposadasError && _cachedListings == null) {
      return _buildError(state.message);
    }
    // Latest listings, or the last cached ones (eligibility/other states
    // must not blank the tab — the listener keeps the cache fresh).
    final listings = state is MyMotoposadasLoaded
        ? state.motoposadas
        : _cachedListings;
    if (listings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Casa de motero entry (M-CRUD-1 UX): only while the user does NOT
        // already own a casa_motero (eligibility pre-check).
        if (_eligibilityHas == false) _buildCasaMoteroEntry(),
        Expanded(
          child: listings.isEmpty
              ? _buildEmptyListings()
              : _buildListingsList(listings),
        ),
      ],
    );
  }

  /// "Ofrecer casa de motero" entry — F-M9 (M-CRUD-1/5). Opens the
  /// casa_motero create form.
  Widget _buildCasaMoteroEntry() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Material(
        color: AppColors.secondary.withAlpha(12),
        borderRadius: AppRadius.mdCircular,
        child: InkWell(
          borderRadius: AppRadius.mdCircular,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateMotoposadaScreen(
                mode: CreateMotoposadaMode.casaMotero,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.secondary.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ofrecer casa de motero',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Recibí moteros con tu espacio',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyListings() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.shelter,
              size: 64,
              color: AppColors.textMuted.withAlpha(60),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Todavía no ofrecés nada',
              style: AppTypography.h2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateMotoposadaScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
              ),
              child: const Text('OFRECER MI ESPACIO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsList(List<MotoposadaModel> listings) {
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<MotoposadasBloc>().add(const LoadMyMotoposadas()),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: listings.length,
        itemBuilder: (_, i) => _buildListingCard(listings[i]),
      ),
    );
  }

  Widget _buildListingCard(MotoposadaModel mp) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MotoposadaDetailScreen(motoposadaId: mp.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(
            color: mp.isActive
                ? AppColors.primary.withAlpha(30)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mp.isActive
                        ? AppColors.primary.withAlpha(15)
                        : AppColors.input,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    mp.isCasaMotero
                        ? Icons.home_work_outlined
                        : (mp.type == 'casa'
                              ? Icons.home
                              : Icons.garage_outlined),
                    color: mp.isCasaMotero
                        ? AppColors.secondary
                        : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mp.title,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${mp.poiTypeLabel} · ${mp.visibilityLabel}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: mp.isActive
                        ? AppColors.success.withAlpha(20)
                        : AppColors.textDisabled.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    mp.isActive ? 'ACTIVO' : 'INACTIVO',
                    style: AppTypography.caption.copyWith(
                      color: mp.isActive
                          ? AppColors.success
                          : AppColors.textDisabled,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            // Casa de motero owner actions (M-CRUD-2/5): edit, disponible
            // toggle and delete — only rendered for the owner's casa_motero.
            if (mp.isCasaMotero) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openCasaMoteroEdit(mp),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'EDITAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteCasaMotero(mp),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text(
                        'ELIMINAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'DISPONIBLE',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: mp.isActive,
                        activeThumbColor: AppColors.primary,
                        onChanged: (_) => context.read<MotoposadasBloc>().add(
                          UpdateCasaMotero(
                            id: mp.id,
                            title: mp.title,
                            description: mp.description,
                            maxGuests: mp.maxGuests,
                            lat: mp.lat,
                            lng: mp.lng,
                            isActive: !mp.isActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Edit flow (M-CRUD-5): reuses the create form in casa_motero edit mode;
  /// the form prefetches owner-only details via LoadCasaMoteroDetails.
  void _openCasaMoteroEdit(MotoposadaModel mp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMotoposadaScreen(
          mode: CreateMotoposadaMode.casaMotero,
          existing: mp,
        ),
      ),
    );
  }

  /// Delete flow (M-CRUD-2): confirm dialog, then `mp_delete_own` — the
  /// details row disappears via FK CASCADE (atomic).
  void _confirmDeleteCasaMotero(MotoposadaModel mp) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'Eliminar tu casa de motero',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Se va a eliminar "${mp.title}" y ya no aparecerá en el mapa. '
          'Esta acción no se puede deshacer.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MotoposadasBloc>().add(DeleteMotoposada(id: mp.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'SÍ, ELIMINAR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// RECIBIDAS (031): solicitudes hacia MIS motoposadas — acciones de host.
  /// Usa el estado RequestsLoaded SOLO cuando isHost; si el otro tab recargó,
  /// muestra el caché de este rol (nunca datos del rol equivocado).
  Widget _buildReceived(MotoposadasState state) {
    final List<MotoposadaRequestModel>? requests =
        state is RequestsLoaded && state.isHost
        ? state.requests
        : _cachedReceived;
    if (requests == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textMuted.withAlpha(60),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sin solicitudes recibidas aún',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<MotoposadasBloc>().add(const LoadReceivedRequests()),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: requests.length,
        itemBuilder: (_, i) => _buildHostRequestCard(requests[i]),
      ),
    );
  }

  /// MIS ESTANCIAS (031): mis solicitudes como guest — sin acciones de host.
  Widget _buildMyStays(MotoposadasState state) {
    final List<MotoposadaRequestModel>? requests =
        state is RequestsLoaded && !state.isHost
        ? state.requests
        : _cachedMyStays;
    if (requests == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 64,
              color: AppColors.textMuted.withAlpha(60),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Todavía no pediste ninguna estancia',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<MotoposadasBloc>().add(const LoadMyRequests()),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: requests.length,
        itemBuilder: (_, i) => _buildGuestRequestCard(requests[i]),
      ),
    );
  }

  /// Tarjeta de solicitud RECIBIDA (host): perfil del guest + acciones
  /// ACEPTAR/RECHAZAR (pending) y COMPLETAR (approved, finalización
  /// controlada 031). Todas las mutaciones van por RPC — el server valida
  /// propiedad, transiciones y fechas cruzadas.
  Widget _buildHostRequestCard(MotoposadaRequestModel req) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: _statusColor(req.status)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.guestName ?? req.guestId.substring(0, 8),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (req.guestLevel != null)
                      Text(
                        'Nv. ${req.guestLevel} · Trust: ${req.guestTrustScore ?? 50}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _statusBadge(req.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_formatDate(req.checkIn)} → ${_formatDate(req.checkOut)} · ${req.guestCount} huésped(es)',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (req.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              req.message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (req.status == 'pending') ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => context.read<MotoposadasBloc>().add(
                        RespondToRequest(requestId: req.id, status: 'approved'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ACEPTAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => context.read<MotoposadasBloc>().add(
                        RespondToRequest(requestId: req.id, status: 'rejected'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'RECHAZAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (req.status == 'approved') ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.read<MotoposadasBloc>().add(
                    FetchMotoposadaRequestContact(requestId: req.id),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('WHATSAPP'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.read<MotoposadasBloc>().add(
                    CompleteMotoposadaRequest(requestId: req.id),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('FINALIZAR ESTANCIA'),
                ),
              ],
            ),
          ],
          if (req.status == 'completed') ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.read<MotoposadasBloc>().add(
                    LoadMotoposadaReputation(userId: req.guestId),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('REPUTACIÓN'),
                ),
                if (!req.hasReviewed)
                  ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(req),
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('EVALUAR HUÉSPED'),
                  )
                else
                  const Chip(label: Text('YA EVALUADO')),
              ],
            ),
            _safetyActions(req),
          ],
        ],
      ),
    );
  }

  /// Tarjeta de MIS ESTANCIAS (guest): motoposada + estado + CANCELAR
  /// (solo pending/approved antes del check-in — el server es la frontera
  /// real con `cancel_motoposada_request`; el check client-side es UX).
  Widget _buildGuestRequestCard(MotoposadaRequestModel req) {
    final canCancel =
        (req.status == 'pending' || req.status == 'approved') &&
        req.checkIn.isAfter(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: _statusColor(req.status)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.motoposadaTitle ?? 'Motoposada #${req.motoposadaId}',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_formatDate(req.checkIn)} → ${_formatDate(req.checkOut)} · ${req.guestCount} huésped(es)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(req.status),
            ],
          ),
          if (req.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              req.message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () => context.read<MotoposadasBloc>().add(
                  CancelMotoposadaRequest(requestId: req.id),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text(
                  'CANCELAR ESTANCIA',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
          if (req.status == 'approved' || req.status == 'completed') ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.read<MotoposadasBloc>().add(
                FetchMotoposadaRequestContact(requestId: req.id),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('CONTACTAR POR WHATSAPP'),
            ),
          ],
          if (req.status == 'completed') ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: req.hostId == null ? null : () => context.read<MotoposadasBloc>().add(
                    LoadMotoposadaReputation(userId: req.hostId!),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('REPUTACIÓN'),
                ),
                if (!req.hasReviewed)
                  ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(req),
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('EVALUAR ANFITRIÓN'),
                  )
                else
                  const Chip(label: Text('YA EVALUADO')),
              ],
            ),
            _safetyActions(req),
          ],
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(MotoposadaRequestModel req) async {
    var rating = 5;
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Evaluar estancia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tu evaluación ayuda a que la comunidad viaje con más confianza.'),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  tooltip: '${index + 1} estrellas',
                  onPressed: () => setDialogState(() => rating = index + 1),
                  icon: Icon(index < rating ? Icons.star : Icons.star_border, color: AppColors.primary),
                )),
              ),
              TextField(
                controller: controller,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Comentario opcional'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('PUBLICAR')),
          ],
        ),
      ),
    );
    if (submitted == true && mounted) {
      context.read<MotoposadasBloc>().add(
        SubmitReview(requestId: req.id, rating: rating, comment: controller.text.trim()),
      );
    }
    controller.dispose();
  }

  Widget _safetyActions(MotoposadaRequestModel req) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Wrap(spacing: AppSpacing.sm, children: [
      TextButton.icon(
        onPressed: () => _showIncidentDialog(req),
        icon: const Icon(Icons.flag_outlined, size: 16),
        label: const Text('REPORTAR INCIDENTE'),
      ),
      TextButton.icon(
        onPressed: () => _confirmBlock(req),
        icon: const Icon(Icons.block, size: 16),
        label: const Text('BLOQUEAR USUARIO'),
      ),
    ]),
  );

  Future<void> _showIncidentDialog(MotoposadaRequestModel req) async {
    var category = 'behavior';
    final controller = TextEditingController();
    final submit = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Reportar incidente'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            items: const [
              DropdownMenuItem(value: 'behavior', child: Text('Comportamiento inapropiado')),
              DropdownMenuItem(value: 'harassment', child: Text('Acoso o amenaza')),
              DropdownMenuItem(value: 'property_damage', child: Text('Daño a la propiedad')),
              DropdownMenuItem(value: 'fraud', child: Text('Fraude o suplantación')),
              DropdownMenuItem(value: 'other', child: Text('Otro')),
            ],
            onChanged: (value) => setDialogState(() => category = value ?? 'other'),
          ),
          TextField(controller: controller, maxLength: 1000, maxLines: 5,
            decoration: const InputDecoration(labelText: 'Describe lo ocurrido')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ENVIAR')),
        ],
      ),
    ));
    final description = controller.text.trim();
    controller.dispose();
    if (submit == true && description.length >= 10 && mounted) {
      context.read<MotoposadasBloc>().add(ReportMotoposadaIncident(
        requestId: req.id, category: category, description: description));
    } else if (submit == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el incidente con al menos 10 caracteres')));
    }
  }

  Future<void> _confirmBlock(MotoposadaRequestModel req) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Bloquear usuario'),
      content: const Text('No podrán enviarse nuevas solicitudes de Motoposada. Las estancias y reportes anteriores se conservarán.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('BLOQUEAR')),
      ],
    ));
    if (confirmed == true && mounted) {
      context.read<MotoposadasBloc>().add(BlockMotoposadaParticipant(requestId: req.id));
    }
  }

  void _showReputation(MotoposadaReputation reputation) {
    String score(double? average, int count) => count == 0 ? 'Sin evaluaciones' : '${average?.toStringAsFixed(1) ?? '—'} / 5 ($count)';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reputación en Motoposadas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Como anfitrión: ${score(reputation.hostAverage, reputation.hostReviews)}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Como huésped: ${score(reputation.guestAverage, reputation.guestReviews)}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR'))],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return AppColors.warning.withAlpha(60);
      case 'approved':
        return AppColors.success.withAlpha(60);
      case 'rejected':
        return AppColors.error.withAlpha(60);
      case 'completed':
        return AppColors.info.withAlpha(60);
      default:
        return AppColors.border;
    }
  }

  Widget _statusBadge(String s) {
    Color c;
    String l;
    switch (s) {
      case 'pending':
        c = AppColors.warning;
        l = 'PENDIENTE';
      case 'approved':
        c = AppColors.success;
        l = 'ACEPTADO';
      case 'rejected':
        c = AppColors.error;
        l = 'RECHAZADO';
      case 'completed':
        c = AppColors.info;
        l = 'COMPLETADO';
      default:
        c = AppColors.textMuted;
        l = s.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l,
        style: AppTypography.caption.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.error, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              msg,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.read<MotoposadasBloc>().add(
                const LoadMyMotoposadas(),
              ),
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
