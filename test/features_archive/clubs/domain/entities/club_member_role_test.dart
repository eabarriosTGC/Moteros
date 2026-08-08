import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features_archive/clubs/domain/entities/club_member_role.dart';

void main() {
  group('ClubMemberRole', () {
    test('uses the canonical database vocabulary', () {
      expect(
        ClubMemberRole.values.map((role) => role.value),
        ['presidente', 'oficial', 'honorable', 'aspirante'],
      );
    });

    test('falls back to aspirante for null or legacy values', () {
      expect(ClubMemberRole.fromValue(null), ClubMemberRole.aspirante);
      expect(ClubMemberRole.fromValue('founder'), ClubMemberRole.aspirante);
      expect(ClubMemberRole.fromValue('captain'), ClubMemberRole.aspirante);
      expect(ClubMemberRole.fromValue('rider'), ClubMemberRole.aspirante);
      expect(ClubMemberRole.fromValue('recruit'), ClubMemberRole.aspirante);
    });

    test('only presidente and oficial can manage members', () {
      expect(ClubMemberRole.presidente.canManageMembers, isTrue);
      expect(ClubMemberRole.oficial.canManageMembers, isTrue);
      expect(ClubMemberRole.honorable.canManageMembers, isFalse);
      expect(ClubMemberRole.aspirante.canManageMembers, isFalse);
    });

    test('presidente can manage every lower role', () {
      expect(
        ClubMemberRole.presidente.assignableRolesFor(
          ClubMemberRole.aspirante,
        ),
        [ClubMemberRole.oficial, ClubMemberRole.honorable],
      );
      expect(
        ClubMemberRole.presidente.canChangeRoleOf(ClubMemberRole.presidente),
        isFalse,
      );
    });

    test('oficial cannot manage presidente or another oficial', () {
      expect(
        ClubMemberRole.oficial.canChangeRoleOf(ClubMemberRole.presidente),
        isFalse,
      );
      expect(
        ClubMemberRole.oficial.canChangeRoleOf(ClubMemberRole.oficial),
        isFalse,
      );
      expect(
        ClubMemberRole.oficial.assignableRolesFor(ClubMemberRole.aspirante),
        [ClubMemberRole.honorable],
      );
    });

    test('oficial can only remove aspirantes', () {
      expect(
        ClubMemberRole.oficial.canRemove(ClubMemberRole.aspirante),
        isTrue,
      );
      expect(
        ClubMemberRole.oficial.canRemove(ClubMemberRole.honorable),
        isFalse,
      );
    });
  });
}
