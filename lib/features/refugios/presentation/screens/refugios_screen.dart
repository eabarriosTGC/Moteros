/// Refugios — Red de Refugios / Moto Posada con pestaña Comunitaria.
/// Tab 1: Refugios comerciales (aliados)
/// Tab 2: Motoposadas comunitarias (usuarios ofrecen su casa)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';
import '../bloc/refugios_bloc.dart';
import '../bloc/refugios_event.dart';
import '../bloc/refugios_state.dart';
import '../bloc/motoposadas_bloc.dart';
import '../bloc/motoposadas_event.dart';
import '../bloc/motoposadas_state.dart';
import 'motoposada_detail_screen.dart';
import 'my_motoposada_screen.dart';
import 'create_motoposada_screen.dart';

class RefugiosScreen extends StatefulWidget {
  const RefugiosScreen({super.key});

  @override
  State<RefugiosScreen> createState() => _RefugiosScreenState();
}

class _RefugiosScreenState extends State<RefugiosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedHostId;
  final _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RefugiosBloc>().add(LoadRefugios());
      context.read<MotoposadasBloc>().add(const LoadMotoposadas());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _scrollToHost(RefugiosLoaded state, int id) {
    setState(() => _selectedHostId = id);
    final idx = state.refugios.indexWhere((r) => r.id == id);
    if (idx >= 0 && _listScroll.hasClients) {
      _listScroll.animateTo(idx * 120.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refugios'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'ALIADOS'),
            Tab(text: 'COMUNIDAD'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCommercialTab(),
          _buildCommunityTab(),
        ],
      ),
    );
  }

  // ═══════════════════ TAB 1: COMMERCIAL ALLIES ═══════════════════

  Widget _buildCommercialTab() {
    return BlocBuilder<RefugiosBloc, RefugiosState>(
      builder: (context, state) {
        if (state is RefugiosLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is RefugiosLoaded) return _buildAlliesScreen(state);
        return const Center(child: Text('Cargando...', style: TextStyle(color: Colors.white54)));
      },
    );
  }

  Widget _buildAlliesScreen(RefugiosLoaded state) {
    final center = state.refugios.isNotEmpty
        ? LatLng(state.refugios.first.latitude, state.refugios.first.longitude)
        : const LatLng(4.60971, -74.08175);

    return Column(children: [
      SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 11, minZoom: 5, maxZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.moteros.moteros_app',
            ),
            MarkerLayer(markers: state.refugios.map((r) => Marker(
              point: LatLng(r.latitude, r.longitude),
              width: 36, height: 36,
              child: GestureDetector(
                onTap: () => _scrollToHost(state, r.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card, shape: BoxShape.circle,
                    border: Border.all(color: r.color, width: 2.5),
                    boxShadow: [BoxShadow(color: r.color.withAlpha(50), blurRadius: 6)],
                  ),
                  child: Icon(r.icon, color: r.color, size: 18),
                ),
              ),
            )).toList()),
          ],
        ),
      ),
      // SOS banner
      GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeModeScreen()));
        },
        child: Container(
          width: double.infinity, margin: const EdgeInsets.all(AppSpacing.sm),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)]),
            borderRadius: AppRadius.mdCircular,
            boxShadow: [BoxShadow(color: Colors.red.withAlpha(60), blurRadius: 12, spreadRadius: 2)],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(AppIcons.sos, color: Colors.white, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text('ALERTA SOS · AUXILIO INMEDIATO', style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      // Host list
      Expanded(
        child: ListView.separated(
          controller: _listScroll,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: state.refugios.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _buildHostCard(context, state.refugios[i], _selectedHostId == state.refugios[i].id),
        ),
      ),
    ]);
  }

  Widget _buildHostCard(BuildContext context, RefugioEntity refugio, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected ? refugio.color.withAlpha(12) : AppColors.card,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: isSelected ? refugio.color.withAlpha(80) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: refugio.color.withAlpha(25), borderRadius: AppRadius.mdCircular),
            child: Icon(refugio.icon, color: refugio.color, size: AppSpacing.iconMd),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(refugio.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            Text(refugio.type.replaceAll('_', ' ').toUpperCase(), style: AppTypography.caption.copyWith(color: refugio.color, fontWeight: FontWeight.w700)),
          ])),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(refugio.description, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text(refugio.benefit, style: AppTypography.caption.copyWith(color: AppColors.success)),
        if (refugio.phone != null && refugio.phone!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('📞 ${refugio.phone}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ]),
    );
  }

  // ═══════════════════ TAB 2: COMMUNITY MOTOPOSADAS ═══════════════════

  Widget _buildCommunityTab() {
    return BlocBuilder<MotoposadasBloc, MotoposadasState>(
      builder: (context, state) {
        if (state is MotoposadasLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (state is MotoposadasLoaded) return _buildMotoposadasList(state);
        return _buildEmptyState();
      },
    );
  }

  Widget _buildMotoposadasList(MotoposadasLoaded state) {
    if (state.motoposadas.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: () async => context.read<MotoposadasBloc>().add(const LoadMotoposadas()),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 80),
        itemCount: state.motoposadas.length + 1, // +1 for header
        itemBuilder: (_, i) {
          if (i == 0) return _buildTabHeader();
          final mp = state.motoposadas[i - 1];
          return _buildMotoposadaCard(mp);
        },
      ),
    );
  }

  Widget _buildTabHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(25), AppColors.secondary.withAlpha(15)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(AppIcons.shelter, color: AppColors.primary, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text('MOTOPOSADAS', style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text('Moteros ofrecen su casa GRATIS para la comunidad',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMotoposadaScreen())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('OFRECER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyMotoposadaScreen())),
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('MIS PUB.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMotoposadaCard(MotoposadaModel mp) {
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
          border: Border.all(color: AppColors.primary.withAlpha(20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                mp.type == 'casa' ? Icons.home_outlined : Icons.garage_outlined,
                color: AppColors.primary, size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mp.title, style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 2),
                  Row(children: [
                    _chip(mp.typeLabel, AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    _chip(mp.visibilityLabel, AppColors.secondary),
                  ]),
                  if (mp.hostName != null) ...[
                    const SizedBox(height: 4),
                    Text('👤 ${mp.hostName}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withAlpha(15), borderRadius: BorderRadius.circular(4)),
    child: Text(t, style: AppTypography.caption.copyWith(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.shelter, size: 64, color: AppColors.textMuted.withAlpha(60)),
            const SizedBox(height: AppSpacing.lg),
            Text('Sin motoposadas aún', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text('Sé el primero en ofrecer tu espacio',
              style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMotoposadaScreen())),
              icon: const Icon(Icons.add),
              label: const Text('OFRECER MI ESPACIO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
