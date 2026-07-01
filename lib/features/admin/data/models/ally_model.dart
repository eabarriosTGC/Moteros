// Modelo Ally con serialización JSON
class AllyModel {
  final int id;
  final String businessName;
  final String category;
  final double latitude;
  final double longitude;
  final String benefit;

  const AllyModel({
    required this.id,
    required this.businessName,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.benefit,
  });

  factory AllyModel.fromJson(Map<String, dynamic> json) => AllyModel(
        id: json['id'] as int,
        businessName: json['business_name'] as String,
        category: json['category'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        benefit: json['benefit'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_name': businessName,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'benefit': benefit,
      };
}
