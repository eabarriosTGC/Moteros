/// SaveRouteDialog tests — botón GUARDAR deshabilitado con nombre vacío.
///
/// STRICT TDD: escritos ANTES de extraer el diálogo (RED — SaveRouteDialog
/// no existía). Widget aislado (sin FlutterMap — precedente del repo).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/tracker/presentation/widgets/save_route_dialog.dart';

void main() {
  group('SaveRouteDialog', () {
    Future<void> openDialog(
      WidgetTester tester, {
      required ValueChanged<String> onSave,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SaveRouteDialog(onSave: onSave),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    TextButton saveButton(WidgetTester tester) {
      return tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'GUARDAR'),
      );
    }

    testWidgets('GUARDAR deshabilitado con nombre vacío', (tester) async {
      await openDialog(tester, onSave: (_) {});

      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('GUARDAR se habilita al escribir y llama onSave + pop',
        (tester) async {
      String? saved;
      await openDialog(tester, onSave: (name) => saved = name);

      await tester.enterText(find.byType(TextField), 'ruta test');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(TextButton, 'GUARDAR'));
      await tester.pumpAndSettle();

      expect(saved, 'ruta test');
      expect(find.byType(SaveRouteDialog), findsNothing); // hizo pop
    });

    testWidgets('CANCELAR cierra sin onSave', (tester) async {
      String? saved;
      await openDialog(tester, onSave: (name) => saved = name);

      await tester.tap(find.widgetWithText(TextButton, 'CANCELAR'));
      await tester.pumpAndSettle();

      expect(saved, isNull);
      expect(find.byType(SaveRouteDialog), findsNothing);
    });
  });
}
