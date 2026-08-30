import 'models.dart';

/// Radius at which a destination ignites.
///
/// This is a compromise forced by the survey: the closest two places in Prem
/// Nagar are 39 m apart, so anything at or above that would put a player inside
/// two zones at once and hand out both tokens from one spot. Below roughly this
/// value, urban GPS error (7-13 m, worse with a blocked sky view) starts
/// refusing to let real arrivals register at all.
const double kUnlockRadiusM = 25;

/// Precision required before a fix may *unlock* anything. Deliberately looser
/// than the radius: phones routinely report 20-40 m at cold start, indoors, or
/// between buildings, and gating at the radius meant nothing ever unlocked in
/// the field. The fifteen-second dwell is the real filter; this only excludes
/// garbage.
const double kAccuracyCapM = 40;

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

/// Whether a fix is believable enough to draw on the map.
///
/// Deliberately does not test precision. A vague fix still says roughly where
/// somebody is, and refusing to show it strands the UI on "waiting for a
/// location fix" when the phone is in fact reporting a position.
bool isPlausible(Fix fix, {Fix? previous, bool rejectMocked = true}) {
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

/// Whether a fix is precise enough to award a token. Separate from
/// [isPlausible] on purpose: showing a position and granting a reward are
/// different levels of trust.
bool isPreciseEnough(Fix fix) => fix.accuracyM <= kAccuracyCapM;

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
