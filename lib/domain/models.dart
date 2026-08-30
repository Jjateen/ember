import 'dart:math' as math;

enum Rarity { common, uncommon, rare }

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.at,
    required this.tokenName,
    required this.rarity,
    required this.hint,
  });

  final String id;
  final String name;
  final GeoPoint at;
  final String tokenName;
  final Rarity rarity;
  final String hint;

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'] as String,
        name: j['name'] as String,
        at: GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        tokenName: j['token'] as String,
        rarity: Rarity.values.byName(j['rarity'] as String? ?? 'common'),
        hint: j['hint'] as String? ?? '',
      );
}

class ProximityResult {
  const ProximityResult({this.nearest, this.distanceM, this.inRadius = const []});

  final Destination? nearest;
  final double? distanceM;
  final List<Destination> inRadius;

  static const empty = ProximityResult();
}

class UnlockEvent {
  const UnlockEvent(this.destination, this.ordinal, this.total);
  final Destination destination;
  final int ordinal;
  final int total;
}

/// Great-circle distance. Earth treated as a sphere; error is well under the
/// GPS noise floor at the scales this app cares about.
double haversineMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180.0;
