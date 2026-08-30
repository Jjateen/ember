import 'models.dart';

/// Radius at which a destination ignites. Values below ~50 m are not viable:
/// urban GPS error is 7-13 m and both platforms advise 100 m+ for geofences.
const double kUnlockRadiusM = 50;

/// Fixes less precise than this are discarded rather than trusted.
const double kAccuracyCapM = 50;

/// Implied speed above this means the fix teleported; drop it.
const double kMaxSpeedKmh = 200;

/// Distance at which the UI starts warming toward the unlock.
const double kWarmRadiusM = 200;

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
  final inRadius = <Destination>[];

  for (final d in all) {
    if (unlocked.contains(d.id)) continue;
    final m = haversineMeters(at, d.at);
    if (best == null || m < best) {
      best = m;
      nearest = d;
    }
    if (m <= radiusM) inRadius.add(d);
  }

  return ProximityResult(nearest: nearest, distanceM: best, inRadius: inRadius);
}
