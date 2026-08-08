/// Clan Screen — AsfaltoClub Battle Ride.
/// Pantalla principal del club con stats, miembros y chat.
/// Incluye chat integrado con Realtime en vivo.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/entities/club_member_role.dart';
import '../bloc/club_bloc.dart';
import '../bloc/club_event.dart';
import '../bloc/club_state.dart';

class ClubScreen extends StatefulWidget {
  final int clubId;
  const ClubScreen({super.key, required this.clubId});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  // Chat state
  List<Map<String, dynamic>> _clubMessages = [];
  bool _chatLoading = true;
  String? _chatError;
  RealtimeChannel? _clubChatChannel;
  final Map<String, String> _userNameCache = {};
  final bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClubBloc>().add(LoadClub(clubId: widget.clubId));
    });
    _loadClubChat();
  }

  @override
  void dispose() {
    _clubChatChannel?.unsubscribe();
    _clubChatChannel = null;
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  /// Load existing club messages and subscribe to Realtime
  Future<void> _loadClubChat() async {
    try {
      _chatLoading = true;
      if (mounted) setState(() {});

      final messages = await Supabase.instance.client
          .from('club_messages')
          .select()
          .eq('club_id', widget.clubId)
          .order('created_at', ascending: true);

      _clubMessages = (messages as List).cast<Map<String, dynamic>>();
      _chatLoading = false;

      // Cache user names for existing messages
      for (final msg in _clubMessages) {
        final uid = msg['user_id'] as String?;
        if (uid != null && !_userNameCache.containsKey(uid)) {
          _userNameCache[uid] = await _fetchUserName(uid);
        }
      }

      if (mounted) setState(() {});
      _scrollToBottom();

      // Subscribe to Realtime for new club messages
      _subscribeToClubChat();
    } catch (e) {
      _chatLoading = false;
      _chatError = e.toString();
      if (mounted) setState(() {});
    }
  }

  /// Subscribe to Realtime inserts on club_messages
  void _subscribeToClubChat() {
    _clubChatChannel = Supabase.instance.client.channel('club-${widget.clubId}');

    _clubChatChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'club_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'club_id',
        value: widget.clubId.toString(),
      ),
      callback: (payload) async {
        final newMsg = Map<String, dynamic>.from(payload.newRecord);
        // Fetch username if not cached
        final uid = newMsg['user_id'] as String?;
        if (uid != null && !_userNameCache.containsKey(uid)) {
          _userNameCache[uid] = await _fetchUserName(uid);
        }
        if (mounted) {
          setState(() {
            _clubMessages.add(newMsg);
          });
          _scrollToBottom();
        }
      },
    );

    _clubChatChannel!.subscribe();
  }

  /// Fetch a user's display name from the profiles/users table
  Future<String> _fetchUserName(String userId) async {
    try {
      final resp = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, full_name')
          .eq('id', userId)
          .maybeSingle();
      if (resp != null) {
        return (resp['display_name'] ??
                resp['username'] ??
                resp['full_name'] ??
                userId.substring(0, 8))
            .toString();
      }
    } catch (_) {}
    return userId.substring(0, 8);
  }

  /// Auto-scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Send a club chat message
  void _sendClubChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    Supabase.instance.client.from('club_messages').insert({
      'club_id': widget.clubId,
      'user_id': userId,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).then((_) {
      _chatController.clear();
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });
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
        if (state is ClubLoaded) return _buildClubScreen(state);
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

  Widget _buildClubScreen(ClubLoaded state) {
    final club = state.club;
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
        title: Text(club['name'] ?? 'Club',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          if (isMember && ClubMemberRole.fromValue(state.myRole).canManageMembers)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textMuted),
              onPressed: () => Navigator.pushNamed(context, '/club/members',
                arguments: widget.clubId,
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

            // Club chat (if member)
            if (isMember) _buildClubChat(state),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ClubLoaded state) {
    final club = state.club;
    final tag = (club['tag'] as String? ?? '???').toUpperCase();
    final logoUrl = club['logo_url'] as String?;

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
        Text(club['name'] ?? 'SIN NOMBRE',
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
          club['is_public'] == true ? 'CLUB PÚBLICO' : 'CLUB PRIVADO',
          style: AppTypography.caption.copyWith(
            color: club['is_public'] == true ? AppColors.success : AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(ClubLoaded state) {
    final membersCount = state.members.length;
    final totalRaids = (state.club['total_raids'] as int?) ?? 0;
    final totalKm = (state.club['total_km'] as num?)?.toDouble() ?? 0;
    final totalXp = (state.club['total_xp'] as int?) ?? 0;

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

  Widget _buildMembersSection(ClubLoaded state) {
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
              if (state.isMember &&
                  ClubMemberRole.fromValue(state.myRole).canManageMembers)
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/club/members',
                    arguments: widget.clubId,
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
    final role = ClubMemberRole.fromValue(member['role'] as String?);
    final roleColors = _getRoleColor(role);
    final roleLabels = role.label;

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

  Widget _buildJoinButton(ClubLoaded state) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
          context.read<ClubBloc>().add(JoinClub(
            clubId: widget.clubId,
            userId: userId,
          ));
        },
        icon: const Icon(Icons.group_add_outlined),
        label: Text('UNIRSE AL CLUB', style: AppTypography.button),
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

  Widget _buildLeaveButton(ClubLoaded state) {
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
              title: Text('SALIR DEL CLUB',
                style: AppTypography.h3.copyWith(color: AppColors.error),
              ),
              content: Text('¿Seguro que quieres abandonar el club?',
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
                    context.read<ClubBloc>().add(LeaveClub(
                      clubId: widget.clubId,
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
        label: Text('SALIR DEL CLUB', style: AppTypography.buttonSmall),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        ),
      ),
    );
  }

  Widget _buildClubChat(ClubLoaded state) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHAT DEL CLUB (${_clubMessages.length})',
                style: AppTypography.label.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(Icons.circle, size: 8,
                color: _clubChatChannel != null ? AppColors.success : AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Chat messages list
          if (_chatLoading)
            SizedBox(
              height: 200,
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else if (_chatError != null)
            SizedBox(
              height: 200,
              child: Center(
                child: Text('Error: $_chatError',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                ),
              ),
            )
          else if (_clubMessages.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Text('Sin mensajes aún. ¡Sé el primero en escribir!',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                controller: _chatScrollController,
                padding: EdgeInsets.zero,
                itemCount: _clubMessages.length,
                itemBuilder: (context, index) {
                  final msg = _clubMessages[index];
                  final uid = msg['user_id'] as String? ?? '';
                  final isMe = uid == currentUserId;
                  final userName = _userNameCache[uid] ?? uid.substring(0, 8);
                  final text = msg['message'] as String? ?? '';
                  final createdAt = msg['created_at'] as String? ?? '';

                  return _buildClubChatBubble(
                    userName: userName,
                    text: text,
                    createdAt: createdAt,
                    isMe: isMe,
                  );
                },
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
                    onSubmitted: (_) => _sendClubChat(),
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
                  onPressed: _sendClubChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a chat bubble for club messages
  Widget _buildClubChatBubble({
    required String userName,
    required String text,
    required String createdAt,
    required bool isMe,
  }) {
    final timestamp = _formatTimestamp(createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isMe
                  ? AppColors.primary.withAlpha(30)
                  : AppColors.secondary.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(
                color: isMe
                    ? AppColors.primary.withAlpha(60)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: AppTypography.caption.copyWith(
                  color: isMe ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(userName,
                      style: AppTypography.caption.copyWith(
                        color: isMe ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (timestamp.isNotEmpty)
                      Text(timestamp,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary.withAlpha(20)
                        : AppColors.input,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isMe
                          ? AppColors.primary.withAlpha(40)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(text,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format timestamp for display
  String _formatTimestamp(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return 'ayer';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}
