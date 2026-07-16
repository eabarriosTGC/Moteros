/// Raid Lobby Screen — AsfaltoClub Battle Ride.
/// Pantalla de espera con participantes, mapa miniatura, chat y botón ready.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';
import 'raid_live_screen.dart';

class RaidLobbyScreen extends StatefulWidget {
  final String raidId;
  final Map<String, dynamic>? initialRaid;
  final List<Map<String, dynamic>>? initialParticipants;

  const RaidLobbyScreen({
    super.key,
    required this.raidId,
    this.initialRaid,
    this.initialParticipants,
  });

  @override
  State<RaidLobbyScreen> createState() => _RaidLobbyScreenState();
}

class _RaidLobbyScreenState extends State<RaidLobbyScreen> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final List<ChatMessage> _chatMessages = [];
  Map<String, dynamic>? _localRaid;
  List<Map<String, dynamic>>? _localParticipants;
  bool _hasLoadedLocally = false;

  @override
  void initState() {
    super.initState();
    _localRaid = widget.initialRaid;
    _localParticipants = widget.initialParticipants;
    _hasLoadedLocally = widget.initialRaid != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RaidBloc>().add(LoadRaidById(raidId: widget.raidId));
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
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        // Use local data from create flow if available while DB query runs
        if (state is RaidLoading && _hasLoadedLocally) {
          return _buildLobby(RaidLobby(
            raid: _localRaid!,
            participants: _localParticipants ?? [],
            isHost: true,
            allReady: (_localParticipants?.length ?? 0) > 0 &&
                (_localParticipants?.every((p) => p['is_ready'] == true) ?? false),
          ));
        }
        if (state is RaidLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is RaidLobby) return _buildLobby(state);
        if (state is RaidActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RaidLiveScreen(raidId: widget.raidId),
              ),
            );
          });
        }
        if (state is RaidError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Error',
                    style: AppTypography.h2.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Text(
              'Cargando...',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLobby(RaidLobby state) {
    final raid = state.raid;
    final isHost = state.isHost;

    return Scaffold(
      backgroundColor: AppColors.elevated,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              raid['description'] ?? 'RAID',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
            Text(
              '${raid['mode'] ?? 'Free Ride'} · ${_formatDate(raid['scheduled_at'])}',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: state.allReady
                  ? AppColors.success.withAlpha(20)
                  : AppColors.primary.withAlpha(20),
              borderRadius: AppRadius.smCircular,
              border: Border.all(
                color: state.allReady
                    ? AppColors.success.withAlpha(60)
                    : AppColors.primary.withAlpha(60),
              ),
            ),
            child: Text(
              state.allReady ? 'TODOS LISTOS' : 'ESPERANDO...',
              style: AppTypography.caption.copyWith(
                color: state.allReady ? AppColors.success : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mini map
          _buildMiniMap(raid),
          // Participants
          Expanded(child: _buildParticipantsList(state)),
          // Chat
          _buildChatInput(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildMiniMap(Map<String, dynamic> raid) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.monitor,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Stack(
        children: [
          // Grid simulation for map background
          CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _MapGridPainter(),
          ),
          // Route line (simulated)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 2),
                  ),
                  child: const Icon(
                    Icons.flag,
                    color: AppColors.success,
                    size: 18,
                  ),
                ),
                Container(
                  width: 2,
                  height: 30,
                  color: AppColors.primary.withAlpha(60),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          // Origin/dest labels
          Positioned(
            top: 12,
            left: 12,
            child: _buildMapLabel('ORIGEN', AppColors.success),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: _buildMapLabel('DESTINO', AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildParticipantsList(RaidLobby state) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final p = state.participants[i];
        final isReady = p['is_ready'] as bool? ?? false;
        final isHostPlayer = p['user_id'] == state.raid['host_id'];

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdCircular,
            border: Border.all(
              color: isReady
                  ? AppColors.success.withAlpha(60)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.success.withAlpha(20)
                      : AppColors.input,
                  borderRadius: AppRadius.mdCircular,
                  border: Border.all(
                    color: isReady
                        ? AppColors.success.withAlpha(80)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: isReady ? AppColors.success : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p['user_id']?.toString().substring(0, 8) ?? 'Usuario',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isHostPlayer) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HOST',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Ready indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isReady
                      ? AppColors.success.withAlpha(25)
                      : AppColors.textDisabled.withAlpha(15),
                  border: Border.all(
                    color: isReady ? AppColors.success : AppColors.textDisabled,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isReady ? Icons.check : Icons.hourglass_empty_outlined,
                  color: isReady ? AppColors.success : AppColors.textDisabled,
                  size: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: TextField(
                controller: _chatController,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Chat de raid...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
                onSubmitted: (_) => _sendChat(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _sendChat,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(RaidLobby state) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final myParticipant = state.participants.firstWhere(
      (p) => p['user_id'] == userId,
      orElse: () => <String, dynamic>{},
    );
    final amReady = myParticipant['is_ready'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Leave button
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.error.withAlpha(40)),
            ),
            child: IconButton(
              icon: const Icon(Icons.exit_to_app, color: AppColors.error),
              onPressed: () {
                context.read<RaidBloc>().add(
                  LeaveRaid(raidId: widget.raidId, userId: userId),
                );
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Ready toggle
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.read<RaidBloc>().add(
                    ToggleReady(raidId: widget.raidId, userId: userId),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: amReady
                      ? AppColors.success
                      : AppColors.input,
                  foregroundColor: amReady
                      ? Colors.black
                      : AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdCircular,
                    side: BorderSide(
                      color: amReady ? AppColors.success : AppColors.border,
                      width: amReady ? 1.5 : 1,
                    ),
                  ),
                  elevation: 0,
                  shadowColor: amReady ? AppColors.successGlow : null,
                ),
                child: Text(
                  amReady ? '✓ LISTO' : 'READY',
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          if (state.isHost) ...[
            const SizedBox(width: AppSpacing.sm),
            // Start raid button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: state.allReady
                      ? () {
                          HapticFeedback.mediumImpact();
                          context.read<RaidBloc>().add(
                            StartRaid(raidId: widget.raidId),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnAmber,
                    disabledBackgroundColor: AppColors.textDisabled.withAlpha(
                      20,
                    ),
                    disabledForegroundColor: AppColors.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdCircular,
                    ),
                    elevation: 0,
                    shadowColor: AppColors.primaryGlow,
                  ),
                  child: Text(
                    'INICIAR RAID',
                    style: AppTypography.buttonSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatMessages.add(ChatMessage(text: text, isMe: true));
      _chatController.clear();
    });
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

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  ChatMessage({required this.text, required this.isMe});
}

/// Grid painter for simulated map background
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x15FF8C00)
      ..strokeWidth = 0.5;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
