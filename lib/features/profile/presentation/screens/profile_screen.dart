import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../membership/presentation/screens/membership_screen.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../../../patches/presentation/screens/patches_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _followers = 0, _following = 0;

  @override
  void initState() { super.initState(); _loadFollowData(); }

  Future<void> _loadFollowData() async {
    try {
      final api = context.read<ApiClient>();
      final f1 = await api.get('/follows?type=followers');
      final f2 = await api.get('/follows?type=following');
      if (mounted) setState(() {
        _followers = (f1.data as Map)['count'] as int? ?? 0;
        _following = (f2.data as Map)['count'] as int? ?? 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(children: [
            _buildHeader(),
            _buildFollowRow(),
            const SizedBox(height: 16),
            _buildMembership(context),
            const SizedBox(height: 16),
            _buildMenu(context),
            const SizedBox(height: 16),
            _buildLogout(context),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2), color: AppColors.card),
        child: const Icon(AppIcons.profile, color: AppColors.textMuted, size: 40)),
      const SizedBox(height: 8),
      const Text('Usuario de Prueba', style: AppTypography.h2),
      Text('test@moteros.app', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildFollowRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _stat('$_followers', 'Seguidores'),
      Container(width: 1, height: 32, color: AppColors.border),
      _stat('$_following', 'Seguidos'),
    ]);
  }

  Widget _stat(String c, String l) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
      Text(c, style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
      Text(l, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
    ]));
  }

  Widget _buildMembership(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(gradient: AppGradients.cardHighlight, borderRadius: AppRadius.mdCircular, border: Border.all(color: AppColors.primary.withAlpha(40))),
      child: Row(children: [
        const Icon(AppIcons.fuel, color: AppColors.primary, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MEMBRESÍA', style: AppTypography.caption),
          const SizedBox(height: 4),
          Text('Miembro', style: AppTypography.h3.copyWith(color: AppColors.primary)),
        ])),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
          child: const Text('Ver plan', style: TextStyle(color: AppColors.primary))),
      ]),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Column(children: [
      _item(AppIcons.badge, 'Mis Parches', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatchesScreen()))),
      _item(AppIcons.route, 'Historial de Rutas', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteTrackerScreen()))),
      _item(AppIcons.group, 'Comunidad', sub: 'Buscar y seguir moteros', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen()))),
      _item(AppIcons.shield, 'Modo Conducción'),
      _item(AppIcons.settings, 'Configuración'),
    ]);
  }

  Widget _item(IconData ic, String t, {String sub = '', VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(ic, color: AppColors.primary, size: 24),
      title: Text(t, style: AppTypography.body),
      subtitle: sub.isEmpty ? null : Text(sub, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
      trailing: Icon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLogout(BuildContext context) {
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: () {
        context.read<ApiClient>().clearTokens();
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LogoutScreen()), (r) => false);
      },
      icon: const Icon(AppIcons.logout, color: AppColors.error),
      label: const Text('Cerrar Sesión'),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withAlpha(60)),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular)),
    ));
  }
}

class LogoutScreen extends StatelessWidget {
  const LogoutScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Sesión cerrada', style: TextStyle(color: Colors.white54))));
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen();
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  void _search() async {
    setState(() => _loading = true);
    try {
      await context.read<ApiClient>().get('/follows?type=followers');
      setState(() => _results = [
        {'id': 1, 'fullName': 'Usuario de Prueba', 'email': 'test@moteros.app', 'role': 'member'},
      ]);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunidad')),
      body: SafeArea(
        child: Column(children: [
          Padding(padding: AppSpacing.screenPadding, child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar moteros...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: IconButton(icon: const Icon(Icons.search, color: AppColors.primary), onPressed: _search),
              filled: true, fillColor: AppColors.input,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          )),
          if (_loading) const Center(child: CircularProgressIndicator()),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            itemBuilder: (_, i) => _buildUserTile(_results[i]),
          )),
        ]),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> u) {
    final name = (u['fullName'] ?? u['email'] ?? '') as String;
    final role = (u['role'] ?? '') as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.mdCircular),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(25)),
          child: const Icon(AppIcons.profile, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
          Text(role, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ])),
        OutlinedButton(
          onPressed: () async {
            try { await context.read<ApiClient>().post('/follows', data: {'user_id': u['id']}); } catch (_) {}
          },
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(80, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Seguir', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
