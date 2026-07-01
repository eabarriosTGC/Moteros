// Use Case: Obtener lugares cercanos
import '../entities/place_entity.dart';

class GetNearbyPlacesUseCase {
  Future<List<PlaceEntity>> execute(double lat, double lng, double radiusKm) async {
    // TODO: Consultar backend con filtro geoespacial
    throw UnimplementedError();
  }
}
