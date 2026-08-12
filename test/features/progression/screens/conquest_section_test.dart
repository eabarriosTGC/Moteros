import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/progression/presentation/screens/progreso_screen.dart';

Map<String, dynamic> _conquest({
  String title = 'Ruta Gotica al Magdalena',
  String origin = 'Bogotá',
  String destination = 'La Calera',
  String? place = 'Mirador de la Calera',
  double km = 42.5,
  String verifiedAt = '2026-08-10T15:00:00.000Z',
  String? photoUrl,
}) =>
    {
      'id': 'arr-1',
      'verified_km': km,
      'verified_at': verifiedAt,
      'photo_url': photoUrl,
      'raids': {
        'description': title,
        'origin_name': origin,
        'destination_name': destination,
      },
      'conquest_places': place == null ? null : {'name': place},
    };

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('muestra conquista verificada: raid, origen→destino, lugar, km, fecha',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ConquestSection(conquests: [_conquest()]),
    ));

    expect(find.text('CONQUISTAS VERIFICADAS'), findsOneWidget);
    expect(find.text('Ruta Gotica al Magdalena'), findsOneWidget);
    expect(find.text('Bogotá → La Calera'), findsOneWidget);
    expect(find.text('Mirador de la Calera'), findsOneWidget);
    expect(find.text('42.5 km'), findsOneWidget);
    expect(find.text('10 ago 2026'), findsOneWidget);
  });

  testWidgets('muestra fotoconquista cuando existe', (tester) async {
    await tester.pumpWidget(_wrap(
      ConquestSection(conquests: [_conquest(photoUrl: 'https://cdn/1.jpg')]),
    ));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('estado vacío: mensaje de verificación QR, no historial de rutas',
      (tester) async {
    await tester.pumpWidget(_wrap(ConquestSection(conquests: const [])));

    expect(find.text('CONQUISTAS VERIFICADAS'), findsOneWidget);
    expect(find.text('Aún no tienes conquistas'), findsOneWidget);
    expect(
      find.textContaining('después de verificar tu llegada con QR'),
      findsOneWidget,
    );
    // El módulo antiguo no debe aparecer en ningún texto.
    expect(find.textContaining('HISTORIAL DE RUTAS'), findsNothing);
    expect(find.textContaining('Sin rutas registradas'), findsNothing);
  });

  testWidgets('lugar ausente no rompe el tile', (tester) async {
    await tester.pumpWidget(_wrap(
      ConquestSection(conquests: [_conquest(place: null)]),
    ));
    expect(find.text('Ruta Gotica al Magdalena'), findsOneWidget);
    expect(find.text('Bogotá → La Calera'), findsOneWidget);
  });
}
