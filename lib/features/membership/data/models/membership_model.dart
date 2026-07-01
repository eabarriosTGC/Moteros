// Modelo Membership con serialización JSON
class MembershipModel {
  final int id;
  final int userId;
  final String plan;
  final String startDate;
  final String endDate;
  final bool isActive;

  const MembershipModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) =>
      MembershipModel(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        plan: json['plan'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
        isActive: json['is_active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plan': plan,
        'start_date': startDate,
        'end_date': endDate,
        'is_active': isActive,
      };
}
