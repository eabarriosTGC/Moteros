import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/validate_visit.dart';
import 'validation_event.dart';
import 'validation_state.dart';

class ValidationBloc extends Bloc<ValidationEvent, ValidationState> {
  final ValidateVisitUseCase _validateVisit;

  ValidationBloc({required ValidateVisitUseCase validateVisit})
      : _validateVisit = validateVisit,
        super(ValidationInitial()) {
    on<QrCodeScanned>(_onQrCodeScanned);
    on<GpsReady>(_onGpsReady);
    on<ValidateVisitSubmitted>(_onValidateVisitSubmitted);
    on<ResetValidation>(_onReset);
  }

  String _qrToken = '';

  void _onQrCodeScanned(
    QrCodeScanned event,
    Emitter<ValidationState> emit,
  ) {
    _qrToken = event.qrToken;
    emit(WaitingForGps(_qrToken));
  }

  void _onGpsReady(
    GpsReady event,
    Emitter<ValidationState> emit,
  ) {
    emit(ReadyToValidate(
      qrToken: event.qrToken,
      latitude: event.latitude,
      longitude: event.longitude,
    ));
  }

  Future<void> _onValidateVisitSubmitted(
    ValidateVisitSubmitted event,
    Emitter<ValidationState> emit,
  ) async {
    emit(Validating());
    try {
      final visit = await _validateVisit.execute(
        qrToken: _qrToken,
        currentLat: event.latitude,
        currentLng: event.longitude,
        evidenceUrl: event.evidenceUrl,
      );
      emit(VisitVerified(visit.placeId));
    } on DioException catch (e) {
      final msg =
          e.response?.data?['error'] as String? ?? 'Error de conexion';
      emit(ValidationError(msg));
    } catch (e) {
      emit(ValidationError('Error inesperado'));
    }
  }

  void _onReset(
    ResetValidation event,
    Emitter<ValidationState> emit,
  ) {
    _qrToken = '';
    emit(ValidationInitial());
  }
}
