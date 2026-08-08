/// Club Members Screen — AsfaltoClub Clubs module.
/// Lista de miembros con roles, gestión de roles e invitaciones.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/entities/club_member_role.dart';
import '../bloc/club_bloc.dart';
import '../bloc/club_event.dart';
import '../bloc/club_state.dart';

class ClubMembersScreen extends StatefulWidget {
  final int clubId;
  const ClubMembersScreen({super.key, required this.clubId});

  @override
  State<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  final _inviteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClubBloc>().add(LoadClub(clubId: widget.clubId));
    });
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClubBloc, ClubState>(
      builder: (context, state) {
        if (state is ClubLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is ClubLoaded) return _buildScreen(state);
        if (state is ClubError) {
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

  Widget _buildScreen(ClubLoaded state) {
    final currentRole = ClubMemberRole.fromValue(state.myRole);
    final canManage = currentRole.canManageMembers;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('MIEMBROS (${state.members.length})',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Invite section (only for presidente/oficial)
          if (canManage) _buildInviteSection(state),

          // Members list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.members.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) =>
                  _buildMemberCard(state, state.members[i], currentRole),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(ClubLoaded state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INVITAR MIEMBRO',
            style: AppTypography.label.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: AppRadius.mdCircular,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _inviteController,
                    style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Email o nombre de usuario',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => _inviteMember(state),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
                  onPressed: () => _inviteMember(state),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    ClubLoaded state,
    Map<String, dynamic> member,
    ClubMemberRole currentRole,
  ) {
    final role = ClubMemberRole.fromValue(member['role'] as String?);
    final roleColor = _getRoleColor(role);
    final roleLabel = role.label;
    final isSelf = member['user_id'] == Supabase.instance.client.auth.currentUser?.id;
    final memberId = member['user_id'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: roleColor.withAlpha(40)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: roleColor.withAlpha(20),
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: roleColor.withAlpha(60)),
            ),
            child: Icon(Icons.person, color: roleColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      memberId.length >= 8 ? memberId.substring(0, 8) : memberId,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('TÚ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondary, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(roleLabel,
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: roleColor.withAlpha(20),
              borderRadius: AppRadius.smCircular,
              border: Border.all(color: roleColor.withAlpha(60)),
            ),
            child: Text(roleLabel,
              style: AppTypography.caption.copyWith(
                color: roleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Role management follows the canonical club hierarchy.
          if (!isSelf &&
              (currentRole.canChangeRoleOf(role) ||
                  currentRole.canRemove(role))) ...[
            const SizedBox(width: AppSpacing.sm),
            _buildManageButton(state, member, currentRole),
          ],
        ],
      ),
    );
  }

  Widget _buildManageButton(
    ClubLoaded state,
    Map<String, dynamic> member,
    ClubMemberRole currentRole,
  ) {
    final role = ClubMemberRole.fromValue(member['role'] as String?);
    final memberId = member['user_id'] as String? ?? '';
    final assignableRoles = currentRole.assignableRolesFor(role);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
      onSelected: (value) {
        if (value == 'kick') {
            _confirmKick(state, memberId);
        } else {
          _changeRole(state, memberId, value);
        }
      },
      itemBuilder: (_) => [
        for (final assignableRole in assignableRoles)
          PopupMenuItem(
            value: assignableRole.value,
            child: ListTile(
              leading: Icon(
                assignableRole.index < role.index
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: _getRoleColor(assignableRole),
              ),
              title: Text(
                'Cambiar a ${assignableRole.label}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              dense: true,
            ),
          ),
        if (currentRole.canRemove(role)) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'kick',
            child: ListTile(
              leading: Icon(Icons.person_remove, color: AppColors.error),
              title: Text(
                'Expulsar',
                style: TextStyle(color: AppColors.error),
              ),
              dense: true,
            ),
          ),
        ],
      ],
    );
  }

  void _changeRole(ClubLoaded state, String memberId, String newRole) {
    HapticFeedback.lightImpact();
    context.read<ClubBloc>().add(UpdateMemberRole(
      clubId: widget.clubId,
      memberId: memberId,
      newRole: newRole,
    ));
  }

  void _confirmKick(ClubLoaded state, String memberId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        title: Text('EXPULSAR MIEMBRO',
          style: AppTypography.h3.copyWith(color: AppColors.error),
        ),
        content: Text('¿Seguro que quieres expulsar a este miembro?',
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
              HapticFeedback.mediumImpact();
              context.read<ClubBloc>().add(KickMember(
                clubId: widget.clubId,
                memberId: memberId,
              ));
            },
            child: Text('EXPULSAR',
              style: AppTypography.button.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _inviteMember(ClubLoaded state) {
    final emailOrUsername = _inviteController.text.trim();
    if (emailOrUsername.isEmpty) return;
    HapticFeedback.lightImpact();
    context.read<ClubBloc>().add(InviteMember(
      clubId: widget.clubId,
      emailOrUsername: emailOrUsername,
    ));
    _inviteController.clear();
  }

  Color _getRoleColor(ClubMemberRole role) {
    switch (role) {
      case ClubMemberRole.presidente:
        return AppColors.primary;
      case ClubMemberRole.oficial:
        return AppColors.secondary;
      case ClubMemberRole.honorable:
        return AppColors.success;
      case ClubMemberRole.aspirante:
        return AppColors.textMuted;
    }
  }
}
