// Domain Entity - Lugar / Punto de Interés
class PlaceEntity {
  final int id;
  final String name;
  final String description;
  final String category; // taller, restaurante, hotel, mirador
  final double latitude;
  final double longitude;
  final String qrToken;

  const PlaceEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.qrToken,
  });
}
