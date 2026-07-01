// Domain Entity - Membresía
class MembershipEntity {
  final int id;
  final int userId;
  final String plan; // basic, premium
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const MembershipEntity({
    required this.id,
    required this.userId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });
}
