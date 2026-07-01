import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {}

final class AuthLoading extends AuthState {}

final class Authenticated extends AuthState {
  final UserEntity user;
  final String token;
  final String refreshToken;

  const Authenticated({
    required this.user,
    required this.token,
    required this.refreshToken,
  });

  @override
  List<Object?> get props => [user, token, refreshToken];
}

final class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

final class Unauthenticated extends AuthState {}
