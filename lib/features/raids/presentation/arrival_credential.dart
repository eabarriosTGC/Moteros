library;

/// Credencial de llegada: token QR o código manual.
///
/// El QR y el código manual son DOS FORMAS de la MISMA credencial: ambos se
/// envían a verify_raid_arrival (única autoridad del servidor). El código
/// manual: 8 caracteres [A-HJKMNP-Z2-9] (sin 0/O/1/I/L), formato XXXX-XXXX.

final _manualCodePattern = RegExp(r'^[A-HJKMNP-Z2-9]{8}$');

/// Normaliza la credencial ingresada:
/// - token QR: se usa tal cual (trim);
/// - código manual: quita espacios/guiones, pasa a mayúsculas y valida el
///   formato de 8 caracteres sin ambiguos.
/// Devuelve null si el formato es inválido (no se toca red ni kilometraje).
String? normalizeArrivalCredential(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('asfaltoclub:arrival:v1:')) return trimmed;
  final manual = trimmed.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (_manualCodePattern.hasMatch(manual)) return manual;
  return null;
}

/// Formato visual del código manual: K7DM4R9X → K7DM-4R9X.
String formatManualCode(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[^A-HJKMNP-Z2-9a-hjkmnp-z2-9]'), '')
      .toUpperCase();
  final capped = cleaned.length > 8 ? cleaned.substring(0, 8) : cleaned;
  if (capped.length <= 4) return capped;
  return '${capped.substring(0, 4)}-${capped.substring(4)}';
}
