import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/community/presentation/screens/community_screen.dart';
import '../../../membership/presentation/screens/membership_screen.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../../../patches/presentation/screens/patches_screen.dart';
import '../../../safemode/presentation/screens/safe_mode_screen.dart';
import '../../../chat/presentation/screens/direct_messages_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../refugios/presentation/screens/refugios_screen.dart';
import '../../../progression/presentation/widgets/xp_progress_card.dart';
import '../../../progression/presentation/screens/achievements_screen.dart';
import '../../../progression/presentation/screens/leaderboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _followers = 0, _following = 0;
  XpData? _xpData;
  String _displayName = '';
  String _email = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  void _loadUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _email = user.email ?? '';
    _avatarUrl = user.userMetadata?['avatar_url'] as String? ?? '';
    // Derive display name from email prefix or user_metadata
    final metaName = user.userMetadata?['full_name'] as String? ??
                     user.userMetadata?['name'] as String?;
    if (metaName != null && metaName.isNotEmpty) {
      _displayName = metaName;
    } else {
      _displayName = _email.split('@').first
          .split('.')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
  }

  Future<void> _loadData() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;

      _followers = await Supabase.instance.client
          .from('user_follows')
          .count(CountOption.exact)
          .eq('followed_id', uid);
      _following = await Supabase.instance.client
          .from('user_follows')
          .count(CountOption.exact)
          .eq('follower_id', uid);

      _xpData = await fetchXpData(uid);

      if (mounted) setState(() {});
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
            if (_xpData != null) ...[
              XpProgressCard(
                data: _xpData!,
                onAchievementsTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                onLeaderboardTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              ),
              const SizedBox(height: 16),
            ],
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
    final displayName = _displayName.isNotEmpty ? _displayName : 'Motero';
    final email = _email.isNotEmpty ? _email : 'cargando...';
    return Column(children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2.5),
          color: AppColors.surface,
          boxShadow: AppShadows.amberGlow,
          image: _avatarUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
              : null,
        ),
        child: _avatarUrl.isEmpty
            ? const Icon(AppIcons.profile, color: AppColors.primary, size: 40)
            : null,
      ),
      const SizedBox(height: 8),
      Text(displayName, style: AppTypography.h2.copyWith(color: AppColors.textPrimary, letterSpacing: 1)),
      Text(email, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdCircular, border: Border.all(color: AppColors.primary.withAlpha(50))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: AppRadius.smCircular),
          child: const Icon(AppIcons.fuel, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MEMBRESÍA', style: AppTypography.caption.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5)),
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
      _item(AppIcons.trophy, 'Logros', sub: '17 logros RPG por desbloquear',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
      _item(AppIcons.medal, 'Ranking', sub: 'Top riders por XP',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
      _item(AppIcons.shelter, 'Refugios', sub: 'Aliados y motoposadas comunitarias',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RefugiosScreen()))),
      _item(AppIcons.chat, 'Mensajes', sub: 'Chat directo con otros moteros',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectMessagesScreen()))),
      _item(AppIcons.badge, 'Mis Parches',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatchesScreen()))),
      _item(AppIcons.route, 'Historial de Rutas',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteTrackerScreen()))),
      _item(AppIcons.group, 'Comunidad', sub: 'Buscar y seguir moteros',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen()))),
      _item(AppIcons.shield, 'Modo Conducción',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeModeScreen()))),
      _item(AppIcons.settings, 'Configuración',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
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
        context.read<AuthBloc>().add(LogoutRequested());
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
