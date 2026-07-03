/// Refugios — Red de Refugios / Moto Posada.
/// SOS button + map of hosts + contact + chat placeholder.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../bloc/refugios_bloc.dart';
import '../bloc/refugios_event.dart';
import '../bloc/refugios_state.dart';

class RefugiosScreen extends StatefulWidget {
  const RefugiosScreen({super.key});

  @override
  State<RefugiosScreen> createState() => _RefugiosScreenState();
}

class _RefugiosScreenState extends State<RefugiosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RefugiosBloc>().add(LoadRefugios());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RefugiosBloc, RefugiosState>(
      builder: (context, state) {
        if (state is RefugiosLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state is RefugiosLoaded) return _buildScreen(context, state);
        return const Scaffold(body: Center(child: Text('Cargando...', style: TextStyle(color: Colors.white54))));
      },
    );
  }

  Widget _buildScreen(BuildContext context, RefugiosLoaded state) {
    final center = state.refugios.isNotEmpty
        ? LatLng(state.refugios.first.latitude, state.refugios.first.longitude)
        : const LatLng(4.60971, -74.08175);

    return Scaffold(
      appBar: AppBar(title: const Text('Red de Refugios')),
      body: Column(children: [
        // Mini map
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('🚨 Alerta SOS enviada a refugios cercanos'),
              backgroundColor: AppColors.error,
            ));
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: state.refugios.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _buildHostCard(context, state.refugios[i], state.selectedHostId == state.refugios[i].id),
          ),
        ),
      ]),
    );
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
          IconButton(
            icon: const Icon(AppIcons.chat, color: AppColors.primary, size: AppSpacing.iconMd),
            onPressed: () => _openChat(context, refugio),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Icon(AppIcons.location, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(child: Text(refugio.address, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(AppIcons.phone, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(refugio.phone, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        ]),
        if (refugio.benefit.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(4)),
            child: Text('🎁 ${refugio.benefit}', style: AppTypography.caption.copyWith(color: AppColors.success)),
          ),
        ],
      ]),
    );
  }

  void _openChat(BuildContext context, RefugioEntity refugio) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => ChatBloc(),
        child: _RealChatScreen(refugio: refugio),
      ),
    ));
  }


  void _scrollToHost(RefugiosLoaded state, int hostId) {
    context.read<RefugiosBloc>().add(ContactHost(hostId: hostId, hostName: ''));
  }
}

/// Real-time chat screen powered by WebSocket + ChatBloc
class _RealChatScreen extends StatefulWidget {
  final RefugioEntity refugio;
  const _RealChatScreen({required this.refugio});

  @override
  State<_RealChatScreen> createState() => _RealChatScreenState();
}

class _RealChatScreenState extends State<_RealChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatBloc>().add(ConnectToRoom(
        roomId: 'refugio-${widget.refugio.id}',
        username: 'Viajero',
      ));
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(SendMessage(text));
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.refugio.name)),
          body: Column(children: [
            // Connection status
            if (state is ChatConnecting)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: AppColors.secondary.withAlpha(40),
                child: Row(children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('Conectando...', style: AppTypography.caption.copyWith(color: AppColors.secondary)),
                ]),
              ),
            if (state is ChatDisconnected && _hasMessages)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: Colors.red.withAlpha(40),
                child: Text('Desconectado — modo offline', style: AppTypography.caption.copyWith(color: AppColors.error)),
              ),
            // Messages
            Expanded(
              child: state is ChatConnected
                  ? ListView.builder(
                      controller: _scrollController,
                      padding: AppSpacing.screenPadding,
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _buildBubble(state.messages[i]),
                    )
                  : const Center(child: Text('Conectando al chat...', style: TextStyle(color: AppColors.textMuted))),
            ),
            // Input
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                )),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
                      boxShadow: AppShadows.neonOrange.take(1).toList()),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  bool get _hasMessages => context.read<ChatBloc>().state is ChatConnected;

  Widget _buildBubble(ChatMessage msg) {
    final isSystem = msg.type == 'system' || msg.type == 'join' || msg.type == 'leave';
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(child: Text(msg.text, style: AppTypography.caption.copyWith(color: AppColors.textMuted))),
      );
    }
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMe ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: msg.isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: msg.isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!msg.isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(msg.user, style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ]),
      ),
    );
  }
}
