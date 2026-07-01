import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../data/datasources/firebase_auth_service.dart';
import '../../data/datasources/google_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _apiClient;
  final FirebaseAuthService _firebaseAuthService;
  late final GoogleAuthRepository _googleAuthRepository;

  AuthBloc({
    required ApiClient apiClient,
    required FirebaseAuthService firebaseAuthService,
  })  : _apiClient = apiClient,
        _firebaseAuthService = firebaseAuthService,
        super(AuthInitial()) {
    _googleAuthRepository = GoogleAuthRepository(apiClient);
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
      final response = await _apiClient.post(
        '/auth/login',
        data: {'email': event.email, 'password': event.password},
      );

      final token = response.data['token'] as String;
      final refreshToken = response.data['refreshToken'] as String;
      final email = response.data['email'] as String;
      final role = response.data['role'] as String;

      await _apiClient.setTokens(token, refreshToken);

      emit(Authenticated(
        user: UserEntity(id: 0, email: email, role: role),
        token: token,
        refreshToken: refreshToken,
      ));
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? 'Error de conexión';
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError('Error inesperado'));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'email': event.email,
          'password': event.password,
          'fullName': event.fullName,
        },
      );

      final token = response.data['token'] as String;
      final refreshToken = response.data['refreshToken'] as String;
      final email = response.data['email'] as String;
      final role = response.data['role'] as String;

      await _apiClient.setTokens(token, refreshToken);

      emit(Authenticated(
        user: UserEntity(id: 0, email: email, role: role),
        token: token,
        refreshToken: refreshToken,
      ));
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? 'Error de conexión';
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError('Error inesperado'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. Iniciar sesión con Google (Firebase Auth + google_sign_in)
      final googleResult = await _firebaseAuthService.signInWithGoogle();

      if (googleResult['success'] != true) {
        emit(AuthError(googleResult['error'] as String));
        return;
      }

      // 2. Enviar ID token al backend Dart Frog
      final backendResult = await _googleAuthRepository.signInWithGoogle(
        idToken: googleResult['idToken'] as String,
        email: googleResult['email'] as String,
        fullName: googleResult['displayName'] as String,
        photoUrl: googleResult['photoUrl'] as String?,
      );

      final token = backendResult['token'] as String;
      final refreshToken = backendResult['refreshToken'] as String;
      final role = backendResult['role'] as String;
      final email = backendResult['email'] as String;

      await _apiClient.setTokens(token, refreshToken);

      emit(Authenticated(
        user: UserEntity(id: 0, email: email, role: role),
        token: token,
        refreshToken: refreshToken,
      ));
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? 'Error de conexión';
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError('Error al iniciar sesión con Google'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _firebaseAuthService.signOut();
    await _apiClient.clearTokens();
    emit(Unauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final token = await _apiClient.tokenStorage.getToken();
    if (token != null) {
      emit(Authenticated(
        user: const UserEntity(id: 0, email: '', role: ''),
        token: token,
        refreshToken: '',
      ));
    } else {
      emit(Unauthenticated());
    }
  }
}
