/// Direct Messages — list of existing conversations for the current user.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import 'chat_detail_screen.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      _loading = true;
      if (mounted) setState(() {});

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _loading = false;
        if (mounted) setState(() {});
        return;
      }

      // Get distinct conversation_ids where current user is a participant
      final participantResp = await Supabase.instance.client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      final conversationIds = (participantResp as List)
          .map((r) => r['conversation_id'] as String)
          .toList();

      if (conversationIds.isEmpty) {
        _loading = false;
        if (mounted) setState(() {});
        return;
      }

      // Get the latest message per conversation
      final conversations = <Map<String, dynamic>>[];
      for (final convId in conversationIds) {
        final lastMsgResp = await Supabase.instance.client
            .from('chat_messages')
            .select()
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1);

        if ((lastMsgResp as List).isNotEmpty) {
          final lastMsg = lastMsgResp.first;
          final participants = await Supabase.instance.client
              .from('conversation_participants')
              .select()
              .eq('conversation_id', convId);

          final otherParticipantId = ((participants as List)
                  .cast<Map<String, dynamic>>())
              .firstWhere(
                (p) => p['user_id'] != userId,
                orElse: () => <String, dynamic>{},
              )['user_id'] as String?;

          conversations.add({
            'conversation_id': convId,
            'last_message': lastMsg['message'] ?? '',
            'created_at': lastMsg['created_at'] ?? '',
            'other_user_id': otherParticipantId ?? '',
            'sender_id': lastMsg['sender_id'] ?? '',
          });
        }
      }

      // Sort by most recent first
      conversations.sort((a, b) {
        final aTime = a['created_at'] as String? ?? '';
        final bTime = b['created_at'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      // Fetch usernames for other participants
      for (final conv in conversations) {
        final otherId = conv['other_user_id'] as String?;
        if (otherId != null && otherId.isNotEmpty) {
          final name = await _fetchUserName(otherId);
          conv['other_name'] = name;
        }
      }

      _conversations = conversations;
      _loading = false;
      if (mounted) setState(() {});
    } catch (e) {
      _error = e.toString();
      _loading = false;
      if (mounted) setState(() {});
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('MENSAJES',
          style: AppTypography.h3,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: AppSpacing.md),
                        Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!,
                          style: AppTypography.body.copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                            color: AppColors.textMuted, size: 48,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text('Sin conversaciones',
                            style: AppTypography.h2.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Toca el botón para iniciar un chat',
                            style: AppTypography.body.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildNewChatButton(),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: ListView.separated(
                        padding: AppSpacing.screenPadding,
                        itemCount: _conversations.length + 1, // +1 for FAB area
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index == _conversations.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: _buildNewChatButton(),
                            );
                          }
                          return _buildConversationTile(_conversations[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final otherName = conv['other_name'] as String? ?? 'Usuario';
    final lastMsg = conv['last_message'] as String? ?? '';
    final createdAt = conv['created_at'] as String? ?? '';
    final otherId = conv['other_user_id'] as String? ?? '';
    final timestamp = _formatTimestamp(createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withAlpha(40)),
          ),
          child: Center(
            child: Text(
              otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        title: Text(otherName,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          lastMsg.length > 40 ? '${lastMsg.substring(0, 40)}...' : lastMsg,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(timestamp,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                otherUserId: otherId,
                otherUserName: otherName,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewChatButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: () => _showNewChatDialog(),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text('NUEVA CONVERSACIÓN',
          style: AppTypography.button.copyWith(color: AppColors.textOnAmber),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAmber,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          elevation: 0,
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NUEVA CONVERSACIÓN',
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: searchController,
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar usuario por email...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.input,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: () async {
                    final email = searchController.text.trim();
                    if (email.isEmpty) return;

                    try {
                      final userResp = await Supabase.instance.client
                          .from('profiles')
                          .select('id, username, display_name')
                          .eq('username', email)
                          .maybeSingle();

                      if (userResp == null) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Usuario no encontrado'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return;
                      }

                      final userId = userResp['id'] as String;
                      final displayName = (userResp['display_name'] ??
                              userResp['username'] ??
                              'Usuario')
                          .toString();

                      if (ctx.mounted) Navigator.pop(ctx);

                      final currentUserId =
                          Supabase.instance.client.auth.currentUser?.id ?? '';
                      if (userId == currentUserId) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No puedes chatear contigo mismo'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              otherUserId: userId,
                              otherUserName: displayName,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnAmber,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdCircular,
                    ),
                    elevation: 0,
                  ),
                  child: Text('INICIAR CHAT',
                    style: AppTypography.button,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
