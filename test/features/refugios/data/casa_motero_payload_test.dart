/// CasaMotero payload builders — pure functions that shape the create RPC
/// params and the eligibility/details selects.
///
/// Contract (M-CRUD-4/5, M-MAPA-1, M-WA-1/3):
/// - Phone is normalized (strip non-digits) BEFORE the RPC — the SQL regex
///   `^\d{7,15}$` rejects spaces/dashes/`+`.
/// - NO `address`, NO cédula/identity key anywhere in the payload.
/// - Eligibility/select builders never request lat_exact/lng_exact/
///   whatsapp_phone (those live only in the owner-only details select).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/data/models/casa_motero_payload.dart';

/// Identity-document patterns — same list as no_cedula_guard_test.dart
/// (OP-R2 continuity, Ley 1581 de 2012).
final List<RegExp> _identityPatterns = [
  RegExp(r'c[ée]dula', caseSensitive: false),
  RegExp(r'documento', caseSensitive: false),
  RegExp(r'identidad', caseSensitive: false),
  RegExp(r'\bdni\b', caseSensitive: false),
  RegExp(r'pasaporte', caseSensitive: false),
];

void _expectNoIdentityKeys(Map<String, dynamic> payload) {
  for (final key in payload.keys) {
    for (final pattern in _identityPatterns) {
      expect(
        pattern.hasMatch(key),
        isFalse,
        reason: 'payload key "$key" must not reference an identity document '
            '(/${pattern.pattern}/)',
      );
    }
  }
}

void main() {
  group('normalizePhoneDigits — M-WA-1/3', () {
    test('strips +, spaces, dashes and parentheses', () {
      expect(normalizePhoneDigits('+57 300 123 4567'), '573001234567');
      expect(normalizePhoneDigits('+57-300-123-4567'), '573001234567');
      expect(normalizePhoneDigits('(300) 123-4567'), '3001234567');
    });

    test('keeps already-clean digits intact', () {
      expect(normalizePhoneDigits('573001234567'), '573001234567');
    });

    test('empty string stays empty (no crash)', () {
      expect(normalizePhoneDigits(''), '');
    });
  });

  group('buildCasaMoteroCreateParams — M-CRUD-4/5, M-MAPA-1, M-WA-1/3', () {
    final params = buildCasaMoteroCreateParams(
      title: 'Casa del Che',
      description: 'Patio y parqueadero cubierto',
      maxGuests: 4,
      lat: 4.612345, // approx (jittered by the form)
      lng: -74.081234,
      latExact: 4.610123, // exact (private)
      lngExact: -74.078901,
      whatsappPhone: '+57 300 123 4567',
      disclaimerAcceptedAt: DateTime.utc(2026, 8, 5, 12, 0, 0),
    );

    test('carries approx + exact + capacity + disclaimer', () {
      expect(params['p_title'], 'Casa del Che');
      expect(params['p_description'], 'Patio y parqueadero cubierto');
      expect(params['p_max_guests'], 4);
      expect(params['p_lat'], 4.612345);
      expect(params['p_lng'], -74.081234);
      expect(params['p_lat_exact'], 4.610123);
      expect(params['p_lng_exact'], -74.078901);
      expect(params['p_disclaimer_accepted_at'], '2026-08-05T12:00:00.000Z');
    });

    test('phone is normalized (non-digits stripped) BEFORE the RPC', () {
      expect(params['p_whatsapp_phone'], '573001234567');
    });

    test('no address key — the app never collects an address (M-WA-3)', () {
      expect(params.containsKey('address'), isFalse);
      expect(params.containsKey('p_address'), isFalse);
      expect(params.values.any((v) => v is String && v.contains('Carrera')),
          isFalse);
    });

    test('no identity-document key (M-CRUD-4)', () {
      _expectNoIdentityKeys(params);
    });

    test('exact coordinates never appear in the public-side keys', () {
      // The RPC payload does carry exact coords (private table insert), but
      // only under the explicit p_lat_exact/p_lng_exact keys — never as the
      // public lat/lng.
      expect(params['p_lat_exact'], isNot(params['p_lat']));
      expect(params['p_lng_exact'], isNot(params['p_lng']));
    });
  });

  group('buildCasaMoteroEligibilitySelect — M-CRUD-1 pre-check (UX)', () {
    test('selects only id, never private columns', () {
      final select = buildCasaMoteroEligibilitySelect();
      expect(select, 'id');
      expect(select.contains('lat_exact'), isFalse);
      expect(select.contains('lng_exact'), isFalse);
      expect(select.contains('whatsapp_phone'), isFalse);
    });
  });

  group('buildCasaMoteroWhatsappParams — M-WA-1', () {
    test('passes the single id param named p_id', () {
      expect(buildCasaMoteroWhatsappParams(42), {'p_id': 42});
    });
  });
}
