/// MainShell onTabSelected tests — fix de contadores stale.
///
/// El IndexedStack mantiene vivos los tabs (keep-alive): las pantallas no
/// re-ejecutan initState al volver. El host (app.dart) usa `onTabSelected`
/// para refrescar datos stale al re-entrar (p. ej. contadores de Progreso).
///
/// STRICT TDD: escrito ANTES del callback (RED — onTabSelected no existía).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/widgets/main_shell.dart';

void main() {
  group('MainShell.onTabSelected', () {
    testWidgets('notifica el tab seleccionado al tocar Progreso',
        (tester) async {
      final selected = <AppTab>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            rodarScreen: const SizedBox(),
            progresoScreen: const SizedBox(),
            explorarScreen: const SizedBox(),
            onTabSelected: selected.add,
          ),
        ),
      );

      await tester.tap(find.text('PROGRESO'));
      await tester.pump();

      expect(selected, [AppTab.progreso]);
    });

    testWidgets('no notifica al inicio (solo en cambios de tab)',
        (tester) async {
      final selected = <AppTab>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            rodarScreen: const SizedBox(),
            progresoScreen: const SizedBox(),
            explorarScreen: const SizedBox(),
            onTabSelected: selected.add,
          ),
        ),
      );

      expect(selected, isEmpty);
    });

    testWidgets('callback nulo no rompe la navegación', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            rodarScreen: const SizedBox(),
            progresoScreen: const SizedBox(),
            explorarScreen: const SizedBox(),
          ),
        ),
      );

      await tester.tap(find.text('EXPLORAR'));
      await tester.pump();

      expect(find.text('EXPLORAR'), findsOneWidget);
    });
  });
}
