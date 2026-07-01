import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

final class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String? fullName;

  const RegisterRequested({
    required this.email,
    required this.password,
    this.fullName,
  });

  @override
  List<Object?> get props => [email, password, fullName];
}

final class LogoutRequested extends AuthEvent {}

final class CheckAuthStatus extends AuthEvent {}

final class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}
