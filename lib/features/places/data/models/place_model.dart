// Modelo Place con serialización JSON para PostGIS
class PlaceModel {
  final int id;
  final String name;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String qrToken;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.qrToken,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        qrToken: json['qr_token'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'qr_token': qrToken,
      };
}
