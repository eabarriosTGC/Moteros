import '../entities/visit_entity.dart';
import '../../data/datasources/validation_remote_datasource.dart';
import '../../data/models/visit_model.dart';

class ValidateVisitUseCase {
  final ValidationRemoteDataSource _dataSource;

  ValidateVisitUseCase(this._dataSource);

  Future<VisitEntity> execute({
    required String qrToken,
    required double currentLat,
    required double currentLng,
    String? evidenceUrl,
  }) async {
    final json = await _dataSource.validateQr(
      qrToken: qrToken,
      lat: currentLat,
      lng: currentLng,
      evidenceUrl: evidenceUrl,
    );
    final model = VisitModel.fromResponse(json);
    return VisitEntity(
      id: model.id,
      userId: model.userId,
      placeId: model.placeId,
      verifiedAt: DateTime.parse(model.verifiedAt),
      evidenceUrl: model.evidenceUrl,
      isVerified: model.isVerified,
    );
  }
}
