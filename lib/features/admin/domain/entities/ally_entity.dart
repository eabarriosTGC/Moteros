// Domain Entity - Admin (Aliado / Comercio)
class AllyEntity {
  final int id;
  final String businessName;
  final String category;
  final double latitude;
  final double longitude;
  final String benefit;

  const AllyEntity({
    required this.id,
    required this.businessName,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.benefit,
  });
}
