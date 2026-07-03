/// WebSocket Chat Hub — manages real-time chat connections
/// for the Refugios/Moto Posada conversations.
library;

import 'dart:convert';
import 'dart:io';

/// A simple in-memory chat hub that routes messages between participants.
class ChatHub {
  ChatHub._();
  static final _instance = ChatHub._();
  factory ChatHub() => _instance;

  // conversationId -> list of connected WebSockets
  final _conversations = <String, List<WebSocket>>{};

  void join(String conversationId, WebSocket socket) {
    _conversations.putIfAbsent(conversationId, () => []).add(socket);

    socket.listen(
      (data) {
        try {
          final msg = json.decode(data as String) as Map<String, dynamic>;
          msg['timestamp'] = DateTime.now().toUtc().toIso8601String();
          _broadcast(conversationId, msg, sender: socket);
        } catch (_) {}
      },
      onDone: () => _leave(conversationId, socket),
      onError: (_) => _leave(conversationId, socket),
    );
  }

  void _broadcast(String conversationId, Map<String, dynamic> msg, {WebSocket? sender}) {
    final clients = _conversations[conversationId];
    if (clients == null) return;
    final encoded = json.encode(msg);
    for (final client in clients) {
      if (client.readyState == WebSocket.open) {
        client.add(encoded);
      }
    }
  }

  void _leave(String conversationId, WebSocket socket) {
    _conversations[conversationId]?.remove(socket);
    if (_conversations[conversationId]?.isEmpty ?? false) {
      _conversations.remove(conversationId);
    }
  }
}
