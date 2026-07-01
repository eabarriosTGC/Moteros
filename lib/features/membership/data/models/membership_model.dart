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
        userId: json['userId'] as int,
        plan: json['plan'] as String,
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        isActive: json['isActive'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'plan': plan,
        'startDate': startDate,
        'endDate': endDate,
        'isActive': isActive,
      };
}
