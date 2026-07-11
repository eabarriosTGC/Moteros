/// Chat Detail — individual DM conversation with another user using Realtime.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';

class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatDetailScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Generate a deterministic conversation ID
  String _buildConversationId() {
    final ids = [_currentUserId, widget.otherUserId]..sort();
    return ids.join('-');
  }

  /// Load existing messages and subscribe to Realtime
  Future<void> _loadMessages() async {
    try {
      _loading = true;
      if (mounted) setState(() {});

      final conversationId = _buildConversationId();

      // Ensure conversation_participants exists
      await _ensureConversation(conversationId);

      // Load existing messages
      final resp = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      _messages = (resp as List).cast<Map<String, dynamic>>();
      _loading = false;

      if (mounted) setState(() {});
      _scrollToBottom();

      // Subscribe to Realtime
      _subscribeToChat(conversationId);
    } catch (e) {
      _error = e.toString();
      _loading = false;
      if (mounted) setState(() {});
    }
  }

  /// Ensure both users are in conversation_participants
  Future<void> _ensureConversation(String conversationId) async {
    // Check if current user is already a participant
    final existing = await Supabase.instance.client
        .from('conversation_participants')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (existing == null) {
      await Supabase.instance.client.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': _currentUserId,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    // Check if other user is a participant
    final otherExisting = await Supabase.instance.client
        .from('conversation_participants')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', widget.otherUserId)
        .maybeSingle();

    if (otherExisting == null) {
      await Supabase.instance.client.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': widget.otherUserId,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  /// Subscribe to Realtime inserts on chat_messages for this conversation
  void _subscribeToChat(String conversationId) {
    _channel = Supabase.instance.client.channel('dm-$conversationId');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        final newMsg = Map<String, dynamic>.from(payload.newRecord);
        // Only add if not already present (avoid duplicates from own sends)
        final alreadyExists = _messages.any(
          (m) => m['id'] == newMsg['id'],
        );
        if (!alreadyExists) {
          if (mounted) {
            setState(() {
              _messages.add(newMsg);
            });
            _scrollToBottom();
          }
        }
      },
    );

    _channel!.subscribe();
  }

  /// Send a DM message
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_currentUserId.isEmpty) return;

    final conversationId = _buildConversationId();

    // Optimistic local addition
    final optimisticMsg = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch, // temp id
      'conversation_id': conversationId,
      'sender_id': _currentUserId,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();
    _messageController.clear();

    // Insert into DB
    Supabase.instance.client.from('chat_messages').insert({
      'conversation_id': conversationId,
      'sender_id': _currentUserId,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).catchError((e) {
      if (mounted) {
        // Remove optimistic message on error
        setState(() {
          _messages.removeWhere(
            (m) => m['id'] == optimisticMsg['id'],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Center(
                child: Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : '?',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(widget.otherUserName,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: AppSpacing.screenPadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                color: AppColors.error, size: 40,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(_error!,
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                  color: AppColors.textMuted, size: 40,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Sin mensajes aún',
                                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                                ),
                                Text('Envía un mensaje para iniciar la conversación',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final senderId = msg['sender_id'] as String? ?? '';
                              final isMe = senderId == _currentUserId;
                              final text = msg['message'] as String? ?? '';
                              final createdAt = msg['created_at'] as String? ?? '';

                              return _buildMessageBubble(
                                text: text,
                                createdAt: createdAt,
                                isMe: isMe,
                              );
                            },
                          ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.input,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: AppColors.textMuted),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a DM message bubble
  Widget _buildMessageBubble({
    required String text,
    required String createdAt,
    required bool isMe,
  }) {
    final timestamp = _formatTimestamp(createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 40),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary.withAlpha(20)
                    : AppColors.input,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: isMe
                      ? const Radius.circular(AppRadius.md)
                      : const Radius.circular(AppRadius.xs),
                  bottomRight: isMe
                      ? const Radius.circular(AppRadius.xs)
                      : const Radius.circular(AppRadius.md),
                ),
                border: Border.all(
                  color: isMe
                      ? AppColors.primary.withAlpha(40)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(text,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (timestamp.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(timestamp,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 40),
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
