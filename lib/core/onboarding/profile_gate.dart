/// Field-presence onboarding gate (F-M12, ADR-001).
///
/// Onboarding state is decided by the ACTUAL users row: `full_name`,
/// `bike_model` and `city` must all be non-empty. The `onboarding_complete`
/// metadata boolean is deliberately NOT consulted — a flag can be true while
/// the underlying data is absent (phantom-flag bug class, same as the earlier
/// "phantom position" issue). Querying the row makes the gate self-healing:
/// any future edit that empties a field re-blocks navigation on next start.
library;

/// True only when the three mandatory fields are all non-empty.
/// The `onboarding_complete` metadata flag is deliberately NOT consulted.
bool isProfileComplete({String? fullName, String? bikeModel, String? city}) {
  final f = fullName?.trim() ?? '';
  final b = bikeModel?.trim() ?? '';
  final c = city?.trim() ?? '';
  return f.isNotEmpty && b.isNotEmpty && c.isNotEmpty;
}
