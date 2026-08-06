/// isExpiredRaid — M-ERV-1 pure tests (W5 — expired-raid visibility).
///
/// STRICT TDD: escritos ANTES del filtro en los markers de Rodar (RED —
/// `isExpiredRaid` no existe aún).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/dashboard/presentation/screens/rodar_screen.dart';

void main() {
  group('isExpiredRaid (M-ERV-1)', () {
    test('scheduled_at en el pasado → true (UTC)', () {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      expect(isExpiredRaid({'scheduled_at': past.toIso8601String()}), isTrue);
    });

    test('scheduled_at en el futuro → false', () {
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      expect(isExpiredRaid({'scheduled_at': future.toIso8601String()}), isFalse);
    });

    test('scheduled_at null → false (filas legacy no rompen)', () {
      expect(isExpiredRaid({'scheduled_at': null}), isFalse);
    });

    test('scheduled_at ausente → false', () {
      expect(isExpiredRaid(const {}), isFalse);
    });

    test('scheduled_at con valor corrupto → false (sin throw)', () {
      expect(isExpiredRaid({'scheduled_at': 'no-es-una-fecha'}), isFalse);
    });
  });
}
