class AllyModel {
  final int id;
  final String businessName;
  final String category;
  final String? description;
  final String? benefit;
  final String? address;
  final String? phone;
  final String? website;
  final double? latitude;
  final double? longitude;

  const AllyModel({
    required this.id,
    required this.businessName,
    required this.category,
    this.description,
    this.benefit,
    this.address,
    this.phone,
    this.website,
    this.latitude,
    this.longitude,
  });

  factory AllyModel.fromJson(Map<String, dynamic> json) => AllyModel(
        id: json['id'] as int,
        businessName: json['businessName'] as String,
        category: json['category'] as String,
        description: json['description'] as String?,
        benefit: json['benefit'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toCreateJson() => {
        'businessName': businessName,
        'category': category,
        'description': description,
        'benefit': benefit,
        'address': address,
        'phone': phone,
        'website': website,
        'latitude': latitude,
        'longitude': longitude,
      };
}
