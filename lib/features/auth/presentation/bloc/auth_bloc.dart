import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _apiClient;

  AuthBloc({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
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

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
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
