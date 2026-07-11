/// Chat BLoC — manages real-time messaging via Supabase Realtime.
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  StreamSubscription<Map<String, dynamic>>? _subscription;
  RealtimeChannel? _channel;
  String _currentUser = '';
  String _currentRoomId = '';
  final List<ChatMessage> _messages = [];

  ChatBloc() : super(ChatDisconnected()) {
    on<ConnectToRoom>(_onConnect);
    on<SendMessage>(_onSend);
    on<Disconnect>((e, emit) => _disconnect());
  }

  Future<void> _onConnect(ConnectToRoom event, Emitter<ChatState> emit) async {
    _currentUser = event.username;
    _currentRoomId = event.roomId;
    emit(ChatConnecting());

    try {
      // Subscribe to a Supabase Realtime channel for this room
      _channel = Supabase.instance.client.channel('room:${event.roomId}');

      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_messages',
            callback: (payload) {
              _handleMessage(payload.newRecord);
            },
          )
          .subscribe((status, [_]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              emit(ChatConnected(messages: List.from(_messages)));
            }
          });

      // Load existing messages from the chat_messages table
      final existing = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('room_id', event.roomId)
          .order('created_at', ascending: true);
      _messages.clear();
      for (final row in existing) {
        _messages.add(_rowToMessage(row));
      }
      emit(ChatConnected(messages: List.from(_messages)));
    } catch (e) {
      // Fallback: show mock messages
      _messages.addAll([
        ChatMessage(
            text: 'Hola, ¿tienes disponibilidad para esta noche?',
            user: 'Tú',
            type: 'message',
            timestamp: '',
            isMe: true),
        ChatMessage(
            text: '¡Claro! Tengo espacio libre. ¿A qué hora llegas?',
            user: 'Host',
            type: 'message',
            timestamp: '',
            isMe: false),
      ]);
      emit(ChatConnected(messages: List.from(_messages)));
    }
  }

  void _onSend(SendMessage event, Emitter<ChatState> emit) {
    if (event.text.isEmpty) return;
    // Insert message into Supabase chat_messages table
    Supabase.instance.client.from('chat_messages').insert({
      'room_id': _currentRoomId,
      'user': _currentUser,
      'message': event.text,
      'created_at': DateTime.now().toIso8601String(),
    });
    // Optimistic local echo
    _messages.add(ChatMessage(
      text: event.text,
      user: 'Tú',
      type: 'message',
      timestamp: '',
      isMe: true,
    ));
    if (state is ChatConnected) {
      emit(ChatConnected(messages: List.from(_messages)));
    }
  }

  void _disconnect() {
    _subscription?.cancel();
    _channel?.unsubscribe();
    _channel = null;
    _subscription = null;
    emit(ChatDisconnected());
  }

  void _handleMessage(Map<String, dynamic> row) {
    final msg = _rowToMessage(row);
    _messages.add(msg);
    if (state is ChatConnected) {
      emit(ChatConnected(messages: List.from(_messages)));
    }
  }

  ChatMessage _rowToMessage(Map<String, dynamic> row) {
    final user = row['user'] as String? ?? '';
    final isMe = user == _currentUser;
    return ChatMessage(
      text: row['message'] as String? ?? '',
      user: isMe ? 'Tú' : user,
      type: 'message',
      timestamp: row['created_at'] as String? ?? '',
      isMe: isMe,
    );
  }

  @override
  Future<void> close() {
    _disconnect();
    return super.close();
  }
}
