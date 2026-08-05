/// WhatsApp launcher tests — F-M11 (M-WA-1/2/3).
///
/// - `buildWhatsAppUrl`: wa.me with normalized digits + encoded message,
///   never coordinates or address (M-WA-1, M-WA-3).
/// - `buildAvailabilityMessage`: alias + "disponible" only, no location
///   data (M-WA-3).
/// - `launchWhatsAppContact`: launches wa.me when possible; when
///   canLaunch=false or throws, shows the WhatsApp Web fallback sheet with a
///   copy action — never silent (M-WA-2).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/services/whatsapp_launcher.dart';

const _phone = '+57 300 123 4567';
const _message = 'Hola Che 👋 Vi tu casa de motero. ¿Está disponible?';

void main() {
  group('buildWhatsAppUrl — M-WA-1', () {
    test('normalizes +/spaces/dashes to digits and encodes the message', () {
      final url = buildWhatsAppUrl(_phone, '¿Está disponible?');
      expect(
        url,
        'https://wa.me/573001234567?text=${Uri.encodeComponent('¿Está disponible?')}',
      );
    });

    test('keeps already-clean phone digits', () {
      expect(
        buildWhatsAppUrl('573001234567', 'hola'),
        'https://wa.me/573001234567?text=hola',
      );
    });

    test('URL never contains coordinates or an address (M-WA-3)', () {
      final url = buildWhatsAppUrl(_phone, _message);
      expect(url.contains('lat'), isFalse);
      expect(url.contains('lng'), isFalse);
      expect(url.contains('address'), isFalse);
      expect(url.contains('%2C'), isFalse, reason: 'no comma-formatted coords');
    });
  });

  group('buildAvailabilityMessage — M-WA-3', () {
    test('contains host alias and "disponible"', () {
      final msg = buildAvailabilityMessage('Che');
      expect(msg, contains('Che'));
      expect(msg, contains('disponible'));
    });

    test('never includes coordinates or address', () {
      final msg = buildAvailabilityMessage('Che');
      expect(msg.contains('4.6'), isFalse);
      expect(msg.contains('-74'), isFalse);
      expect(msg.contains('Carrera'), isFalse);
      expect(msg.contains('Calle'), isFalse);
      expect(msg.contains('lat'), isFalse);
      expect(msg.contains('lng'), isFalse);
    });
  });

  group('launchWhatsAppContact — M-WA-1/2', () {
    final uris = <Uri>[];

    Future<bool> fakeLaunch(Uri uri) async {
      uris.add(uri);
      return true;
    }

    Future<void> pumpHost(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('canLaunch=true → launches wa.me, no fallback sheet',
        (tester) async {
      uris.clear();
      await pumpHost(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => launchWhatsAppContact(
                context,
                _phone,
                _message,
                canLaunch: (_) async => true,
                launch: fakeLaunch,
              ),
              child: const Text('Contactar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Contactar'));
      await tester.pumpAndSettle();

      expect(uris, hasLength(1));
      expect(
        uris.single.toString(),
        startsWith('https://wa.me/573001234567?text='),
      );
      // No fallback sheet rendered.
      expect(find.text('Abrir WhatsApp Web'), findsNothing);
    });

    testWidgets('canLaunch=false → fallback sheet with web + copy + clear '
        'message (M-WA-2)', (tester) async {
      uris.clear();
      final clipboard = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );

      await pumpHost(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => launchWhatsAppContact(
                context,
                _phone,
                _message,
                canLaunch: (_) async => false,
                launch: fakeLaunch,
              ),
              child: const Text('Contactar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Contactar'));
      await tester.pumpAndSettle();

      // Fallback sheet: web + copy + clear message.
      expect(find.text('Abrir WhatsApp Web'), findsOneWidget);
      expect(find.text('Copiar mensaje'), findsOneWidget);
      expect(find.textContaining('WhatsApp requerido'), findsOneWidget);
      // Nothing auto-launched at sheet-show time — the web URI is launched
      // only when the user taps the button (covered by the next test).
      expect(uris, isEmpty);

      // Copy action writes the message to the clipboard.
      await tester.tap(find.text('Copiar mensaje'));
      await tester.pumpAndSettle();
      expect(clipboard, contains(_message));
      expect(find.text('Mensaje copiado al portapapeles'), findsOneWidget);
    });

    testWidgets('canLaunch throws → same fallback, never silent (M-WA-2)',
        (tester) async {
      uris.clear();
      await pumpHost(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => launchWhatsAppContact(
                context,
                _phone,
                _message,
                canLaunch: (_) async => throw Exception('boom'),
                launch: fakeLaunch,
              ),
              child: const Text('Contactar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Contactar'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir WhatsApp Web'), findsOneWidget);
      expect(find.text('Copiar mensaje'), findsOneWidget);
      expect(find.textContaining('WhatsApp requerido'), findsOneWidget);
    });

    testWidgets('fallback "Abrir WhatsApp Web" button launches the web URI',
        (tester) async {
      uris.clear();
      await pumpHost(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => launchWhatsAppContact(
                context,
                _phone,
                _message,
                canLaunch: (_) async => false,
                launch: fakeLaunch,
              ),
              child: const Text('Contactar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Contactar'));
      await tester.pumpAndSettle();
      uris.clear(); // discard the pre-computed web URI probe, keep the tap

      await tester.tap(find.text('Abrir WhatsApp Web'));
      await tester.pumpAndSettle();

      expect(
        uris.single.toString(),
        startsWith('https://web.whatsapp.com/send?phone=573001234567&text='),
      );
    });
  });
}
