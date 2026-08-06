/// M-ERV-5 — visibleUpcomingRaids pure tests.
///
/// STRICT TDD: escritos ANTES de filtrar la sección 'PRÓXIMOS RAIDS' de
/// Rodar (RED — `visibleUpcomingRaids` no existe aún). La pantalla completa
/// tiene FlutterMap → se testea la función pura (precedente del repo).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/dashboard/presentation/screens/rodar_screen.dart';

void main() {
  group('visibleUpcomingRaids (M-ERV-5)', () {
    final future = DateTime.now()
        .toUtc()
        .add(const Duration(days: 2))
        .toIso8601String();
    final past = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 2))
        .toIso8601String();

    test('excluye raids con scheduled_at vencido (mismo criterio que markers)',
        () {
      final raids = [
        {'id': 1, 'status': 'lobby', 'scheduled_at': future},
        {'id': 2, 'status': 'lobby', 'scheduled_at': past},
        {'id': 3, 'status': 'active', 'scheduled_at': past},
      ];
      final visible = visibleUpcomingRaids(raids);
      expect(visible.map((r) => r['id']), [1]);
    });

    test('mantiene status lobby/active y limita a 3', () {
      final raids = [
        for (var i = 1; i <= 5; i++)
          {'id': i, 'status': 'lobby', 'scheduled_at': future},
        {'id': 99, 'status': 'planned', 'scheduled_at': future},
      ];
      final visible = visibleUpcomingRaids(raids);
      expect(visible, hasLength(3));
      expect(visible.every((r) => r['status'] != 'planned'), isTrue);
    });

    test('scheduled_at null → visible (no rompe filas legacy)', () {
      final raids = [
        {'id': 7, 'status': 'lobby', 'scheduled_at': null},
      ];
      expect(visibleUpcomingRaids(raids), hasLength(1));
    });
  });
}
