import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  StreamSubscription? _authSubscription;

  AuthBloc() : super(AuthInitial()) {
    // Listen for real‑time auth state changes from Supabase
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        if (session != null && session.user != null) {
          final user = session.user;
          emit(Authenticated(
            user: UserEntity(
              id: user.id,
              email: user.email ?? '',
              role: user.userMetadata?['role'] as String? ?? 'rider',
            ),
          ));
        } else {
          emit(Unauthenticated());
        }
      },
    );

    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      if (response.user == null) {
        emit(const AuthError('Credenciales inválidas'));
      }
      // Auth state change listener will emit Authenticated
    } catch (e) {
      final message = _extractError(e);
      emit(AuthError(message));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: event.email,
        password: event.password,
        data: {
          if (event.fullName != null) 'full_name': event.fullName,
          'role': 'rider',
        },
      );
      if (response.user != null) {
        // If email confirmation is disabled, the session will be set automatically
        // and the auth listener will emit Authenticated.
        // If it requires confirmation, we stay in a "check your email" state.
        if (response.session == null) {
          emit(const AuthError('Revisa tu correo para confirmar la cuenta'));
        }
      }
    } catch (e) {
      final message = _extractError(e);
      emit(AuthError(message));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
      );
      // Auth state change listener handles the rest
    } catch (e) {
      final message = _extractError(e);
      emit(AuthError(message));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await Supabase.instance.client.auth.signOut();
    // Auth state change listener will emit Unauthenticated
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user != null) {
      final user = session.user;
      emit(Authenticated(
        user: UserEntity(
          id: user.id,
          email: user.email ?? '',
          role: user.userMetadata?['role'] as String? ?? 'rider',
        ),
      ));
    } else {
      emit(Unauthenticated());
    }
  }

  String _extractError(Object e) {
    final msg = e.toString();
    // Supabase AuthException.message
    if (msg.contains('Invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesión';
    }
    if (msg.contains('User already registered')) {
      return 'El correo ya está registrado';
    }
    return 'Error de autenticación';
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
