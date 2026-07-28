/// My Motoposada — manage own listing + incoming requests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotoposadasBloc>().add(const LoadMyMotoposadas());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MotoposadasBloc, MotoposadasState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('MIS MOTOPOSADAS', style: AppTypography.h2.copyWith(color: AppColors.primary)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              onTap: (i) {
                if (i == 1) context.read<MotoposadasBloc>().add(const LoadMyRequests());
              },
              tabs: const [
                Tab(text: 'MIS PUBLICACIONES'),
                Tab(text: 'SOLICITUDES'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMyListings(state),
              _buildRequests(state),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMotoposadaScreen())),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnAmber,
            icon: const Icon(Icons.add),
            label: const Text('CREAR'),
          ),
        );
      },
    );
  }

  Widget _buildMyListings(MotoposadasState state) {
    if (state is MotoposadasLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state is MyMotoposadasLoaded) {
      if (state.motoposadas.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.shelter, size: 64, color: AppColors.textMuted.withAlpha(60)),
                const SizedBox(height: AppSpacing.lg),
                Text('Todavía no ofrecés nada', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMotoposadaScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber),
                  child: const Text('OFRECER MI ESPACIO'),
                ),
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async => context.read<MotoposadasBloc>().add(const LoadMyMotoposadas()),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.motoposadas.length,
          itemBuilder: (_, i) => _buildListingCard(state.motoposadas[i]),
        ),
      );
    }
    if (state is MotoposadasError) return _buildError(state.message);
    return const SizedBox.shrink();
  }

  Widget _buildListingCard(MotoposadaModel mp) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MotoposadaDetailScreen(motoposadaId: mp.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: mp.isActive ? AppColors.primary.withAlpha(30) : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: mp.isActive ? AppColors.primary.withAlpha(15) : AppColors.input,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(mp.type == 'casa' ? Icons.home : Icons.garage_outlined, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mp.title, style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              Text('${mp.typeLabel} · ${mp.visibilityLabel}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: mp.isActive ? AppColors.success.withAlpha(20) : AppColors.textDisabled.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(mp.isActive ? 'ACTIVO' : 'INACTIVO', style: AppTypography.caption.copyWith(
              color: mp.isActive ? AppColors.success : AppColors.textDisabled,
              fontWeight: FontWeight.w700, fontSize: 10,
            )),
          ),
        ]),
      ),
    );
  }

  Widget _buildRequests(MotoposadasState state) {
    if (state is MotoposadasLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state is RequestsLoaded) {
      if (state.requests.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted.withAlpha(60)),
              const SizedBox(height: AppSpacing.lg),
              Text('Sin solicitudes aún', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async => context.read<MotoposadasBloc>().add(const LoadMyRequests()),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.requests.length,
          itemBuilder: (_, i) => _buildRequestCard(state.requests[i]),
        ),
      );
    }
    return const Center(child: Text('Cargando...', style: TextStyle(color: AppColors.textMuted)));
  }

  Widget _buildRequestCard(MotoposadaRequestModel req) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: _statusColor(req.status)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.input, borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(req.guestName ?? req.guestId.substring(0, 8), style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              if (req.guestLevel != null)
                Text('Nv. ${req.guestLevel} · Trust: ${req.guestTrustScore ?? 50}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          _statusBadge(req.status),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text('${_formatDate(req.checkIn)} → ${_formatDate(req.checkOut)} · ${req.guestCount} huésped(es)', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
        if (req.message.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(req.message, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
        ],
        if (req.status == 'pending') ...[
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () => context.read<MotoposadasBloc>().add(RespondToRequest(
                    requestId: req.id, status: 'approved',
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ACEPTAR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: () => context.read<MotoposadasBloc>().add(RespondToRequest(
                    requestId: req.id, status: 'rejected',
                  )),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('RECHAZAR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return AppColors.warning.withAlpha(60);
      case 'approved': return AppColors.success.withAlpha(60);
      case 'rejected': return AppColors.error.withAlpha(60);
      case 'completed': return AppColors.info.withAlpha(60);
      default: return AppColors.border;
    }
  }

  Widget _statusBadge(String s) {
    Color c; String l;
    switch (s) {
      case 'pending': c = AppColors.warning; l = 'PENDIENTE';
      case 'approved': c = AppColors.success; l = 'ACEPTADO';
      case 'rejected': c = AppColors.error; l = 'RECHAZADO';
      case 'completed': c = AppColors.info; l = 'COMPLETADO';
      default: c = AppColors.textMuted; l = s.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withAlpha(20), borderRadius: BorderRadius.circular(4)),
      child: Text(l, style: AppTypography.caption.copyWith(color: c, fontWeight: FontWeight.w700, fontSize: 10)),
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
            Text(msg, style: AppTypography.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.read<MotoposadasBloc>().add(const LoadMyMotoposadas()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
