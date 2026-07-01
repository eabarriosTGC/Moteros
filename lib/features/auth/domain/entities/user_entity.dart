// Domain Entity - Capa de Dominio Pura (sin dependencias externas)
class UserEntity {
  final int id;
  final String email;
  final String role; // aspirant, member, admin, ally

  const UserEntity({
    required this.id,
    required this.email,
    required this.role,
  });
}
