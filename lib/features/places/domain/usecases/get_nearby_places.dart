import '../entities/place_entity.dart';
import '../../data/datasources/place_remote_datasource.dart';
import '../../data/models/place_model.dart';

class GetNearbyPlacesUseCase {
  final PlaceRemoteDataSource _dataSource;

  GetNearbyPlacesUseCase(this._dataSource);

  Future<List<PlaceEntity>> execute(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    final jsonList = await _dataSource.getNearbyPlaces(lat, lng, radiusMeters);
    return jsonList
        .map((json) => PlaceModel.fromJson(json))
        .map((model) => PlaceEntity(
              id: model.id,
              name: model.name,
              description: model.description,
              category: model.category,
              latitude: model.latitude,
              longitude: model.longitude,
              qrToken: model.qrToken,
              address: model.address,
              city: model.city,
              department: model.department,
              imageUrl: model.imageUrl,
            ))
        .toList();
  }
}
