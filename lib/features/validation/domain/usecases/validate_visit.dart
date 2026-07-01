// Use Case: Validar QR + GPS + Evidencia
import '../entities/visit_entity.dart';

class ValidateVisitUseCase {
  /// Valida que el QR escaneado corresponda al lugar,
  /// que el GPS esté a < 100m y guarda la evidencia.
  Future<VisitEntity> execute({
    required String qrToken,
    required double currentLat,
    required double currentLng,
    String? evidenceUrl,
  }) async {
    // TODO: Llamar a /validation del backend Dart Frog
    throw UnimplementedError();
  }
}
