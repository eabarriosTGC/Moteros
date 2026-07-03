/// Chat BLoC — manages WebSocket connection and message state.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

sealed class ChatEvent {}
final class ConnectToRoom extends ChatEvent {
  final String roomId;
  final String username;
  ConnectToRoom({required this.roomId, required this.username});
}
final class SendMessage extends ChatEvent {
  final String text;
  SendMessage(this.text);
}
final class Disconnect extends ChatEvent {}

sealed class ChatState {}
final class ChatDisconnected extends ChatState {}
final class ChatConnecting extends ChatState {}
final class ChatConnected extends ChatState {
  final List<ChatMessage> messages;
  ChatConnected({required this.messages});
}

class ChatMessage {
  final String text;
  final String user;
  final String type;
  final String timestamp;
  final bool isMe;

  ChatMessage({
    required this.text,
    required this.user,
    required this.type,
    required this.timestamp,
    required this.isMe,
  });
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String _currentUser = '';
  final List<ChatMessage> _messages = [];

  ChatBloc() : super(ChatDisconnected()) {
    on<ConnectToRoom>(_onConnect);
    on<SendMessage>(_onSend);
    on<Disconnect>((e, emit) => _disconnect());
  }

  Future<void> _onConnect(ConnectToRoom event, Emitter<ChatState> emit) async {
    _currentUser = event.username;
    emit(ChatConnecting());

    try {
      // Connect to the WebSocket chat server
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://10.0.2.2:8082/ws?room=${event.roomId}&user=${Uri.encodeComponent(event.username)}'),
      );

      await _channel!.ready;

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = json.decode(data as String) as Map<String, dynamic>;
            final type = msg['type'] as String? ?? 'message';
            final isMe = msg['user'] == _currentUser &&
                (msg['type'] == 'message');
            
            _messages.add(ChatMessage(
              text: msg['message'] as String? ?? '',
              user: (isMe ? 'Tú' : (msg['user'] as String? ?? 'Anónimo')),
              type: type,
              timestamp: msg['timestamp'] as String? ?? '',
              isMe: isMe,
            ));

            if (state is ChatConnected) {
              emit(ChatConnected(messages: List.from(_messages)));
            }
          } catch (_) {}
        },
        onError: (e) => _disconnect(),
        onDone: () => _disconnect(),
      );

      emit(ChatConnected(messages: List.from(_messages)));
    } catch (e) {
      _channel = null;
      // Fallback: show mock messages
      _messages.addAll([
        ChatMessage(text: 'Hola, ¿tienes disponibilidad para esta noche?', user: 'Tú', type: 'message', timestamp: '', isMe: true),
        ChatMessage(text: '¡Claro! Tengo espacio libre. ¿A qué hora llegas?', user: 'Host', type: 'message', timestamp: '', isMe: false),
      ]);
      emit(ChatConnected(messages: List.from(_messages)));
    }
  }

  void _onSend(SendMessage event, Emitter<ChatState> emit) {
    if (_channel != null && event.text.isNotEmpty) {
      _channel!.sink.add(json.encode({'message': event.text}));
    } else {
      // Fallback: local echo
      _messages.add(ChatMessage(
        text: event.text, user: 'Tú', type: 'message', timestamp: '', isMe: true,
      ));
      if (state is ChatConnected) {
        emit(ChatConnected(messages: List.from(_messages)));
      }
    }
  }

  void _disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    emit(ChatDisconnected());
  }

  @override
  Future<void> close() {
    _disconnect();
    return super.close();
  }
}
