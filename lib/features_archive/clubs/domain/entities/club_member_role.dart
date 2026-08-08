/// Canonical roles stored in `public.club_members.role`.
enum ClubMemberRole {
  presidente('presidente', 'PRESIDENTE'),
  oficial('oficial', 'OFICIAL'),
  honorable('honorable', 'HONORABLE'),
  aspirante('aspirante', 'ASPIRANTE');

  const ClubMemberRole(this.value, this.label);

  final String value;
  final String label;

  static ClubMemberRole fromValue(String? value) {
    return ClubMemberRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ClubMemberRole.aspirante,
    );
  }

  bool get canManageMembers =>
      this == ClubMemberRole.presidente || this == ClubMemberRole.oficial;

  bool canChangeRoleOf(ClubMemberRole target) {
    return switch (this) {
      ClubMemberRole.presidente => target != ClubMemberRole.presidente,
      ClubMemberRole.oficial =>
        target == ClubMemberRole.honorable ||
            target == ClubMemberRole.aspirante,
      _ => false,
    };
  }

  bool canRemove(ClubMemberRole target) {
    return switch (this) {
      ClubMemberRole.presidente => target != ClubMemberRole.presidente,
      ClubMemberRole.oficial => target == ClubMemberRole.aspirante,
      _ => false,
    };
  }

  List<ClubMemberRole> assignableRolesFor(ClubMemberRole target) {
    final roles = switch (this) {
      ClubMemberRole.presidente => const [
        ClubMemberRole.oficial,
        ClubMemberRole.honorable,
        ClubMemberRole.aspirante,
      ],
      ClubMemberRole.oficial => const [
        ClubMemberRole.honorable,
        ClubMemberRole.aspirante,
      ],
      _ => const <ClubMemberRole>[],
    };

    return roles.where((role) => role != target).toList(growable: false);
  }
}
