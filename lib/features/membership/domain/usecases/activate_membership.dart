import '../entities/membership_entity.dart';
import '../../data/datasources/membership_remote_datasource.dart';
import '../../data/models/membership_model.dart';

class ActivateMembershipUseCase {
  final MembershipRemoteDataSource _dataSource;

  ActivateMembershipUseCase(this._dataSource);

  Future<MembershipEntity?> getCurrent() async {
    final json = await _dataSource.getCurrent();
    if (json == null) return null;
    final model = MembershipModel.fromJson(json);
    return MembershipEntity(
      id: model.id,
      userId: model.userId,
      plan: model.plan,
      startDate: DateTime.parse(model.startDate),
      endDate: DateTime.parse(model.endDate),
      isActive: model.isActive,
    );
  }

  Future<MembershipEntity> execute({
    required String paymentId,
    String plan = 'basic',
  }) async {
    final json = await _dataSource.activate(
      paymentId: paymentId,
      plan: plan,
    );
    final model = MembershipModel.fromJson(json);
    return MembershipEntity(
      id: model.id,
      userId: model.userId,
      plan: model.plan,
      startDate: DateTime.parse(model.startDate),
      endDate: DateTime.parse(model.endDate),
      isActive: model.isActive,
    );
  }
}
