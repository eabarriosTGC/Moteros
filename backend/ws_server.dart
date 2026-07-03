/// Standalone WebSocket chat server for real-time messaging.
/// Runs on port 8082 alongside the main Dart Frog server on 8081.
library;

import 'dart:convert';
import 'dart:io';

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8082);
  print('⚡ WebSocket Chat Server running on ws://0.0.0.0:8082');

  await for (final request in server) {
    if (request.uri.path == '/ws') {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        handleConnection(socket, request.uri.queryParameters);
      } catch (e) {
        print('WebSocket upgrade failed: $e');
        request.response.statusCode = 400;
        request.response.close();
      }
    } else {
      request.response.statusCode = 404;
      request.response.close();
    }
  }
}

/// Active chat rooms: roomId -> set of WebSockets
final _rooms = <String, Set<WebSocket>>{};

void handleConnection(WebSocket socket, Map<String, String> queryParams) {
  final roomId = queryParams['room'] ?? 'general';
  final username = queryParams['user'] ?? 'Anónimo';

  _rooms.putIfAbsent(roomId, () => {}).add(socket);
  print('🔌 $username joined room $roomId (${_rooms[roomId]!.length} users)');

  // Welcome message
  socket.add(json.encode({
    'type': 'system',
    'message': 'Bienvenido a la conversación',
    'room': roomId,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  }));

  // Broadcast join to room
  _broadcast(roomId, {
    'type': 'join',
    'user': username,
    'message': '$username se unió al chat',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  }, exclude: socket);

  socket.listen(
    (data) {
      try {
        final msg = json.decode(data as String) as Map<String, dynamic>;
        msg['user'] = username;
        msg['timestamp'] = DateTime.now().toUtc().toIso8601String();
        msg['type'] = 'message';
        _broadcast(roomId, msg);
      } catch (e) {
        print('Invalid message: $e');
      }
    },
    onDone: () {
      _rooms[roomId]?.remove(socket);
      if (_rooms[roomId]?.isEmpty ?? false) _rooms.remove(roomId);
      print('🔌 $username left room $roomId');
      _broadcast(roomId, {
        'type': 'leave',
        'user': username,
        'message': '$username abandonó el chat',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    },
    onError: (e) {
      _rooms[roomId]?.remove(socket);
      print('⚠️ $username error: $e');
    },
  );
}

void _broadcast(String roomId, Map<String, dynamic> message, {WebSocket? exclude}) {
  final clients = _rooms[roomId];
  if (clients == null) return;
  final encoded = json.encode(message);
  for (final client in clients.toList()) {
    if (client != exclude && client.readyState == WebSocket.open) {
      client.add(encoded);
    }
  }
}
