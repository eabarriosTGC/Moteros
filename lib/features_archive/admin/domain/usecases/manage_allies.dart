import '../entities/ally_entity.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../data/models/ally_model.dart';

class ManageAlliesUseCase {
  final AdminRemoteDataSource _dataSource;

  ManageAlliesUseCase(this._dataSource);

  Future<List<AllyEntity>> getAllies() async {
    final jsonList = await _dataSource.getAllies();
    return jsonList
        .map((json) => AllyModel.fromJson(json))
        .map((model) => AllyEntity(
              id: model.id,
              businessName: model.businessName,
              category: model.category,
              description: model.description,
              benefit: model.benefit,
              address: model.address,
              phone: model.phone,
              website: model.website,
              latitude: model.latitude,
              longitude: model.longitude,
            ))
        .toList();
  }

  Future<AllyEntity> create({
    required String businessName,
    required String category,
    String? description,
    String? benefit,
    String? address,
    String? phone,
    String? website,
    double? latitude,
    double? longitude,
  }) async {
    final json = await _dataSource.createAlly({
      'businessName': businessName,
      'category': category,
      'description': description,
      'benefit': benefit,
      'address': address,
      'phone': phone,
      'website': website,
      'latitude': latitude,
      'longitude': longitude,
    });
    return AllyEntity(
      id: json['id'] as int,
      businessName: businessName,
      category: category,
      description: description,
      benefit: benefit,
      address: address,
      phone: phone,
      website: website,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
