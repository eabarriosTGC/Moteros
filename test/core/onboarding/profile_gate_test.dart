/// Unit tests for the field-presence onboarding gate predicate (OP-R1, ADR-001).
///
/// STRICT TDD: this file was written BEFORE lib/core/onboarding/profile_gate.dart
/// existed. The gate must decide onboarding state from REAL field presence in
/// the users row — it must never consult the `onboarding_complete` metadata
/// boolean (phantom-flag bug class, ADR-001).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/onboarding/profile_gate.dart';

void main() {
  group('isProfileComplete (OP-R1 field-presence gate)', () {
    test('all fields null/empty → false', () {
      expect(isProfileComplete(), isFalse);
      expect(isProfileComplete(fullName: '', bikeModel: '', city: ''), isFalse);
    });

    test('metadata flag onboarding_complete=true with empty row (phantom) → false',
        () {
      // ADR-001: the boolean flag SHALL NOT satisfy the gate. The function
      // has no parameter for the flag — presence of the flag in metadata must
      // not change the outcome.
      const phantomMetadata = <String, dynamic>{'onboarding_complete': true};
      expect(phantomMetadata['onboarding_complete'], isTrue, reason: 'fixture sanity');
      expect(
        isProfileComplete(
          fullName: null,
          bikeModel: null,
          city: null,
        ),
        isFalse,
        reason: 'flag set but users row empty → incomplete',
      );
    });

    test('null row (missing users row) → false', () {
      // maybeSingle() returns null when the row does not exist.
      expect(
        isProfileComplete(
          fullName: null as String?,
          bikeModel: null as String?,
          city: null as String?,
        ),
        isFalse,
      );
    });

    test('2 of 3 fields present → false', () {
      expect(
        isProfileComplete(fullName: 'Ana', bikeModel: 'MT-07', city: null),
        isFalse,
      );
      expect(
        isProfileComplete(fullName: 'Ana', bikeModel: null, city: 'Medellín'),
        isFalse,
      );
      expect(
        isProfileComplete(fullName: null, bikeModel: 'MT-07', city: 'Medellín'),
        isFalse,
      );
    });

    test('all 3 non-empty → true', () {
      expect(
        isProfileComplete(
          fullName: 'Ana',
          bikeModel: 'Yamaha MT-07',
          city: 'Medellín',
        ),
        isTrue,
      );
    });

    test('whitespace-only fields → false (values are trimmed)', () {
      expect(
        isProfileComplete(
          fullName: '   ',
          bikeModel: ' ',
          city: '\t',
        ),
        isFalse,
      );
    });

    test('values with surrounding whitespace → true (trimmed before check)', () {
      expect(
        isProfileComplete(
          fullName: '  Ana María  ',
          bikeModel: ' MT-07 ',
          city: ' Medellín ',
        ),
        isTrue,
      );
    });
  });
}
