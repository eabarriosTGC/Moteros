/// CasaMotero payload builders — pure shaping of create-RPC params and the
/// eligibility/details selects.
///
/// Privacy contract (M-CRUD-4/5, M-MAPA-1, M-WA-1/3):
/// - The create payload carries approx + exact + phone + disclaimer; the
///   phone is normalized (non-digits stripped) BEFORE the RPC because the
///   SQL regex `^\+?[0-9]{7,15}$` rejects spaces/dashes.
/// - NO `address` key (the app never collects an address) and NO
///   cédula/identity key (OP-R2 continuity, Ley 1581 de 2012).
/// - The public eligibility select requests `id` only — private columns
///   (lat_exact/lng_exact/whatsapp_phone) are never selected publicly.
library;

/// Strips every non-digit character: `+57 300 123 4567` → `573001234567`.
String normalizePhoneDigits(String phone) =>
    phone.replaceAll(RegExp(r'[^0-9]'), '');

/// Params map for the `create_casa_motero` RPC (migration 026). The RPC is
/// SECURITY DEFINER: it derives `user_id` from `auth.uid()` — this payload
/// never carries an owner identity parameter.
Map<String, dynamic> buildCasaMoteroCreateParams({
  required String title,
  required String description,
  required int maxGuests,
  required double lat, // approx (jittered by the form — UX)
  required double lng,
  required double latExact, // exact (private, owner-only table)
  required double lngExact,
  required String whatsappPhone,
  required DateTime disclaimerAcceptedAt,
}) {
  return {
    'p_title': title,
    'p_description': description,
    'p_max_guests': maxGuests,
    'p_lat': lat,
    'p_lng': lng,
    'p_lat_exact': latExact,
    'p_lng_exact': lngExact,
    'p_whatsapp_phone': normalizePhoneDigits(whatsappPhone),
    'p_disclaimer_accepted_at': disclaimerAcceptedAt.toIso8601String(),
  };
}

/// Eligibility pre-check select (M-CRUD-1 UX only, NOT a security boundary):
/// `SELECT id FROM motoposadas WHERE user_id = auth.uid() AND
/// poi_type = 'casa_motero'`. Requests `id` only — never private columns.
String buildCasaMoteroEligibilitySelect() => 'id';

/// Params for the `get_motoposada_whatsapp` RPC (F-M11, phone on demand).
Map<String, dynamic> buildCasaMoteroWhatsappParams(int id) => {'p_id': id};
