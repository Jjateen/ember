import 'models.dart';

/// Radius at which a destination ignites.
///
/// This is a compromise forced by the survey: the closest two places in Prem
/// Nagar are 39 m apart, so anything at or above that would put a player inside
/// two zones at once and hand out both tokens from one spot. Below roughly this
/// value, urban GPS error (7-13 m, worse with a blocked sky view) starts
/// refusing to let real arrivals register at all.
const double kUnlockRadiusM = 25;

/// Fixes less precise than the radius cannot place a player inside it with any
/// confidence, so they are discarded rather than trusted.
const double kAccuracyCapM = 25;

/// Implied speed above this means the fix teleported; drop it.
const double kMaxSpeedKmh = 200;

/// Distance at which the UI starts warming toward the unlock.
const double kWarmRadiusM = 120;

class Fix {
  const Fix({
    required this.at,
    required this.accuracyM,
    required this.timestamp,
    this.isMocked = false,
  });

  final GeoPoint at;
  final double accuracyM;
  final DateTime timestamp;
  final bool isMocked;
}

/// Decides whether a fix is worth acting on. Pure, so every rejection reason
/// is directly testable without a device.
bool isTrustworthy(Fix fix, {Fix? previous, bool rejectMocked = true}) {
  if (fix.accuracyM > kAccuracyCapM) return false;
  if (rejectMocked && fix.isMocked) return false;
  if (previous != null) {
    final seconds = fix.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (seconds > 0) {
      final kmh = (haversineMeters(previous.at, fix.at) / seconds) * 3.6;
      if (kmh > kMaxSpeedKmh) return false;
    }
  }
  return true;
}

/// The game rule, in one function: measure to everything still locked, report
/// the nearest and anything inside the radius.
ProximityResult evaluate({
  required GeoPoint at,
  required List<Destination> all,
  required Set<String> unlocked,
  double radiusM = kUnlockRadiusM,
}) {
  Destination? nearest;
  double? best;
  final inRadius = <(double, Destination)>[];

  for (final d in all) {
    if (unlocked.contains(d.id)) continue;
    final m = haversineMeters(at, d.at);
    if (best == null || m < best) {
      best = m;
      nearest = d;
    }
    if (m <= radiusM) inRadius.add((m, d));
  }

  // Sorted so callers taking the first element always get the nearest. With
  // places under 80 m apart, picking an arbitrary one hands out the wrong token.
  inRadius.sort((a, b) => a.$1.compareTo(b.$1));

  return ProximityResult(
    nearest: nearest,
    distanceM: best,
    inRadius: [for (final e in inRadius) e.$2],
  );
}
