// Use Case: Procesar activación de membresía post-pago
import '../entities/membership_entity.dart';

class ActivateMembershipUseCase {
  Future<MembershipEntity> execute(String paymentId) async {
    // TODO: Webhook desde MercadoPago/PayU
    throw UnimplementedError();
  }
}
