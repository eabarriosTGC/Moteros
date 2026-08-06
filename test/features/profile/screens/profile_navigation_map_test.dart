/// Bounded navigation-map test — M-PN-3 (amended, fix W1).
///
/// STRICT TDD: written BEFORE the gear rewiring lands (RED — the shell
/// still imports profile_screen.dart via progreso_screen.dart:9).
///
/// Asserts ZERO imports of ProfileScreen/ShowcaseProfileScreen in lib/
/// OUTSIDE the conserved chains: `features/profile/` (kept-as-debt files
/// import each other by design — e.g. profile_screen.dart:16),
/// `features_archive/` (archived code) and the barrel
/// `showcase/showcase.dart` (export, not navigation). Bounded
/// reachability from the shell, not a raw import grep (amendment M-PN-3).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no shell-reachable screen imports the conserved profile screens '
      '(M-PN-1/M-PN-3)', () {
    final lib = Directory('lib');
    const forbidden = ['profile_screen.dart', 'showcase_profile_screen.dart'];
    final excludedDirs = <String>{
      '${lib.path}/features/profile',
      '${lib.path}/features_archive',
    };
    final offenders = <String>[];

    void scan(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory) {
          if (excludedDirs.contains(entity.path)) continue;
          scan(entity);
        } else if (entity is File && entity.path.endsWith('.dart')) {
          // Barrel export — not a navigation reference (design 1.2).
          if (entity.path.endsWith('features/showcase/showcase.dart')) {
            continue;
          }
          final content = File(entity.path).readAsStringSync();
          if (forbidden.any(content.contains)) {
            offenders.add(entity.path);
          }
        }
      }
    }

    scan(lib);

    expect(
      offenders,
      isEmpty,
      reason:
          'M-PN-3: no shell-reachable screen may import '
          'ProfileScreen/ShowcaseProfileScreen (bounded reachability — '
          'features/profile/, features_archive/ and the showcase barrel '
          'are out of scope by design). Found: $offenders',
    );
  });
}
