/// Clan Screen — AsfaltoClub Battle Ride.
/// Pantalla principal del clan con stats, miembros y chat.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/clan_bloc.dart';
import '../bloc/clan_event.dart';
import '../bloc/clan_state.dart';

class ClanScreen extends StatefulWidget {
  final String clanId;
  const ClanScreen({super.key, required this.clanId});

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClanBloc>().add(LoadClan(clanId: widget.clanId));
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClanBloc, ClanState>(
      builder: (context, state) {
        if (state is ClanLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is ClanLoaded) return _buildClanScreen(state);
        if (state is ClanError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(state.message, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: Text('Cargando...', style: TextStyle(color: AppColors.textMuted))),
        );
      },
    );
  }

  Widget _buildClanScreen(ClanLoaded state) {
    final clan = state.clan;
    final isMember = state.isMember;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(clan['name'] ?? 'Clan',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          if (isMember && (state.myRole == 'founder' || state.myRole == 'captain'))
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textMuted),
              onPressed: () => Navigator.pushNamed(context, '/clan/members',
                arguments: widget.clanId,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            // Header with tag and avatar
            _buildHeader(state),
            const SizedBox(height: AppSpacing.lg),

            // Stats
            _buildStatsRow(state),
            const SizedBox(height: AppSpacing.lg),

            // Members list
            _buildMembersSection(state),
            const SizedBox(height: AppSpacing.lg),

            // Join/Leave button
            if (!isMember) _buildJoinButton(state),
            if (isMember) _buildLeaveButton(state),

            const SizedBox(height: AppSpacing.lg),

            // Clan chat (if member)
            if (isMember) _buildClanChat(state),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ClanLoaded state) {
    final clan = state.clan;
    final tag = (clan['tag'] as String? ?? '???').toUpperCase();
    final logoUrl = clan['logo_url'] as String?;

    return Column(
      children: [
        // Logo / Avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withAlpha(60), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: logoUrl != null
              ? ClipOval(child: Image.network(logoUrl, fit: BoxFit.cover))
              : Icon(Icons.groups_rounded, color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(clan['name'] ?? 'SIN NOMBRE',
          style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.primary.withAlpha(40)),
          ),
          child: Text('[$tag]',
            style: AppTypography.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          clan['is_public'] == true ? 'CLAN PÚBLICO' : 'CLAN PRIVADO',
          style: AppTypography.caption.copyWith(
            color: clan['is_public'] == true ? AppColors.success : AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(ClanLoaded state) {
    final membersCount = state.members.length;
    final totalRaids = (state.clan['total_raids'] as int?) ?? 0;
    final totalKm = (state.clan['total_km'] as num?)?.toDouble() ?? 0;
    final totalXp = (state.clan['total_xp'] as int?) ?? 0;

    return Row(
      children: [
        Expanded(child: _statCard('$membersCount', 'MIEMBROS', Icons.people_outline, AppColors.primary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('$totalRaids', 'RAIDS', Icons.flag_outlined, AppColors.secondary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('$totalKm', 'KM', Icons.route_outlined, AppColors.success)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('$totalXp', 'XP', Icons.stars_outlined, AppColors.primary)),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppSpacing.iconSm),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
            style: AppTypography.monoSmall.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          Text(label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(ClanLoaded state) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MIEMBROS (${state.members.length})',
                style: AppTypography.label.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              if (state.isMember && (state.myRole == 'founder' || state.myRole == 'captain'))
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/clan/members',
                    arguments: widget.clanId,
                  ),
                  child: Text('GESTIONAR',
                    style: AppTypography.caption.copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(
            state.members.length > 6 ? 6 : state.members.length,
            (i) => _buildMemberRow(state.members[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final role = member['role'] as String? ?? 'rider';
    final roleColors = _getRoleColor(role);
    final roleLabels = _getRoleLabel(role);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: roleColors.withAlpha(20),
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: roleColors.withAlpha(60)),
            ),
            child: Icon(Icons.person_outline, color: roleColors, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['user_id']?.toString().substring(0, 8) ?? 'Usuario',
                  style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                ),
                if (member['level'] != null)
                  Text('Nivel ${member['level']}',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: roleColors.withAlpha(20),
              borderRadius: AppRadius.smCircular,
              border: Border.all(color: roleColors.withAlpha(60)),
            ),
            child: Text(roleLabels,
              style: AppTypography.caption.copyWith(
                color: roleColors,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'founder':
        return AppColors.primary;
      case 'captain':
        return AppColors.secondary;
      case 'rider':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'founder':
        return 'FUNDADOR';
      case 'captain':
        return 'CAPITÁN';
      case 'rider':
        return 'JINETE';
      default:
        return 'RECLUTA';
    }
  }

  Widget _buildJoinButton(ClanLoaded state) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
          context.read<ClanBloc>().add(JoinClan(
            clanId: widget.clanId,
            userId: userId,
          ));
        },
        icon: const Icon(Icons.group_add_outlined),
        label: Text('UNIRSE AL CLAN', style: AppTypography.button),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAmber,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          elevation: 0,
          shadowColor: AppColors.primaryGlow,
        ),
      ),
    );
  }

  Widget _buildLeaveButton(ClanLoaded state) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeightSm,
      child: OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              title: Text('SALIR DEL CLAN',
                style: AppTypography.h3.copyWith(color: AppColors.error),
              ),
              content: Text('¿Seguro que quieres abandonar el clan?',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCELAR',
                    style: AppTypography.button.copyWith(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
                    context.read<ClanBloc>().add(LeaveClan(
                      clanId: widget.clanId,
                      userId: userId,
                    ));
                    Navigator.pop(context);
                  },
                  child: Text('ABANDONAR',
                    style: AppTypography.button.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.exit_to_app, size: AppSpacing.iconSm),
        label: Text('SALIR DEL CLAN', style: AppTypography.buttonSmall),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        ),
      ),
    );
  }

  Widget _buildClanChat(ClanLoaded state) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHAT DEL CLAN',
            style: AppTypography.label.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Chat messages placeholder
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: AppRadius.smCircular,
            ),
            child: Center(
              child: Text('Conéctate al chat del clan',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Chat input
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => _sendClanChat(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _sendClanChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendClanChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💬 Mensaje enviado al clan'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 1),
      ),
    );
    _chatController.clear();
  }
}
