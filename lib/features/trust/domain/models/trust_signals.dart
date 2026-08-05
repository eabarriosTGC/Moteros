/// TrustSignals — public, display-only signals for host/creator cards
/// (F-M13). Sourced only from data the system already computes (TS-R1):
/// `users.created_at` (member since), `saved_routes` count via the
/// `get_trip_counts` RPC (trips), `user_xp.km_traveled` (km),
/// `user_achievements` count (badges).
///
/// There is NO trust-score / reputation / rating value here by construction
/// (TS-R2) and `user_xp.trust_score` is never selected or modeled (TS-R3) —
/// the column cannot leak into the UI because it is absent from this model.
library;

class TrustSignals {
  final DateTime? memberSince; // users.created_at
  final int trips; // saved_routes count via get_trip_counts RPC
  final int km; // user_xp.km_traveled (rounded)
  final int badges; // user_achievements count

  const TrustSignals({
    this.memberSince,
    this.trips = 0,
    this.km = 0,
    this.badges = 0,
  });

  /// "Miembro desde ago 2023" — Spanish month abbreviation, lowercase,
  /// per spec TS-R1.
  String get memberSinceLabel {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final d = memberSince;
    if (d == null) return '';
    return 'Miembro desde ${months[d.month - 1]} ${d.year}';
  }

  /// Zero-data edge: all fields default to 0 / null → UI renders "0 viajes",
  /// "0 km", "0 insignias" — never a placeholder (TS-R1 scenario 2).
  ///
  /// [trips] is passed in from the get_trip_counts RPC result (NOT from the
  /// joined row — saved_routes RLS would zero it for non-owners).
  factory TrustSignals.fromJoinedUserRow(
    Map<String, dynamic>? userRow, {
    int trips = 0,
  }) {
    if (userRow == null) return TrustSignals(trips: trips);
    final xp = userRow['user_xp'] as Map<String, dynamic>?;
    int countOf(String key) {
      final list = userRow[key] as List?;
      if (list == null || list.isEmpty) return 0;
      return (list.first['count'] as int?) ?? 0; // PostgREST count embed shape
    }

    return TrustSignals(
      memberSince: userRow['created_at'] != null
          ? DateTime.tryParse(userRow['created_at'] as String)
          : null,
      trips: trips,
      km: ((xp?['km_traveled'] as num?) ?? 0).round(),
      badges: countOf('user_achievements'),
    );
  }
}
