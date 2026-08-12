import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/arrival_credential.dart';

void main() {
  group('normalizeArrivalCredential', () {
    test('token QR se usa tal cual (trim)', () {
      const token = 'asfaltoclub:arrival:v1:abc-123:xyz';
      expect(normalizeArrivalCredential(token), token);
      expect(normalizeArrivalCredential('  $token  '), token);
    });

    test('código manual normaliza minúsculas, espacios y guiones', () {
      expect(normalizeArrivalCredential('k7dm-4r9x'), 'K7DM4R9X');
      expect(normalizeArrivalCredential(' k7dm 4r9x '), 'K7DM4R9X');
      expect(normalizeArrivalCredential('K7DM-4R9X'), 'K7DM4R9X');
    });

    test('código manual con caracteres ambiguos es inválido', () {
      // 0, O, 1, I, L no pertenecen al alfabeto del código.
      expect(normalizeArrivalCredential('K7DM-0R9X'), isNull);
      expect(normalizeArrivalCredential('K7DM-1R9X'), isNull);
      expect(normalizeArrivalCredential('K7DM-LR9X'), isNull);
      expect(normalizeArrivalCredential('K7DM-OR9X'), isNull);
      expect(normalizeArrivalCredential('K7DM-IR9X'), isNull);
    });

    test('longitud distinta de 8 es inválida', () {
      expect(normalizeArrivalCredential('K7DM'), isNull);
      expect(normalizeArrivalCredential('K7DM4R9X2'), isNull);
      expect(normalizeArrivalCredential(''), isNull);
    });

    test('caracteres fuera del alfabeto son inválidos', () {
      expect(normalizeArrivalCredential('K7DM!!!!'), isNull);
      expect(normalizeArrivalCredential('K7DM-R9X.'), isNull);
    });
  });

  group('formatManualCode', () {
    test('formatea XXXX-XXXX', () {
      expect(formatManualCode('K7DM4R9X'), 'K7DM-4R9X');
    });

    test('limpia caracteres ajenos y pasa a mayúsculas', () {
      expect(formatManualCode('k7dm-4r9x'), 'K7DM-4R9X');
      expect(formatManualCode('k7dm 4r9x!'), 'K7DM-4R9X');
    });

    test('acota a 8 caracteres', () {
      expect(formatManualCode('K7DM4R9XZZZ'), 'K7DM-4R9X');
    });

    test('parciales no rompen', () {
      expect(formatManualCode('K7'), 'K7');
      expect(formatManualCode('K7DM4'), 'K7DM-4');
    });
  });
}
