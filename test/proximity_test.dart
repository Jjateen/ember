import 'package:ember/domain/models.dart';
import 'package:ember/domain/proximity.dart';
import 'package:flutter_test/flutter_test.dart';

const futala = GeoPoint(21.1466, 79.0350);

Destination dest(String id, GeoPoint at) => Destination(
      id: id,
      name: id,
      at: at,
      tokenName: '$id token',
      rarity: Rarity.common,
      hint: '',
    );

Fix fix(GeoPoint at, {double acc = 8, bool mocked = false, DateTime? t}) =>
    Fix(at: at, accuracyM: acc, timestamp: t ?? DateTime(2026, 1, 1), isMocked: mocked);

/// Moves `metres` north of a point, which is the easy axis: one degree of
/// latitude is ~111.32 km everywhere.
GeoPoint north(GeoPoint from, double metres) =>
    GeoPoint(from.lat + metres / 111320.0, from.lng);

void main() {
  group('haversine', () {
    test('measures a known northward offset', () {
      expect(haversineMeters(futala, north(futala, 100)), closeTo(100, 1));
      expect(haversineMeters(futala, north(futala, 1000)), closeTo(1000, 5));
    });

    test('is zero for the same point', () {
      expect(haversineMeters(futala, futala), closeTo(0, 0.001));
    });
  });

  group('isPlausible', () {
    test('accepts a vague fix, because it still says roughly where you are', () {
      // Gating the map on precision is what stranded the app on "waiting for a
      // location fix" while the phone was reporting a position perfectly well.
      expect(isPlausible(fix(futala, acc: kAccuracyCapM + 50)), isTrue);
    });

    test('rejects a mocked fix when asked to', () {
      expect(isPlausible(fix(futala, mocked: true)), isFalse);
      expect(isPlausible(fix(futala, mocked: true), rejectMocked: false), isTrue);
    });

    test('rejects a teleport between consecutive fixes', () {
      final a = fix(futala, t: DateTime(2026, 1, 1, 0, 0, 0));
      final b = fix(north(futala, 5000), t: DateTime(2026, 1, 1, 0, 0, 10));
      expect(isPlausible(b, previous: a), isFalse);
    });

    test('accepts a plausible walking pace', () {
      final a = fix(futala, t: DateTime(2026, 1, 1, 0, 0, 0));
      final b = fix(north(futala, 15), t: DateTime(2026, 1, 1, 0, 0, 10));
      expect(isPlausible(b, previous: a), isTrue);
    });
  });

  group('isPreciseEnough', () {
    test('separates showing a position from awarding a token', () {
      expect(isPreciseEnough(fix(futala, acc: kAccuracyCapM - 1)), isTrue);
      expect(isPreciseEnough(fix(futala, acc: kAccuracyCapM + 1)), isFalse);
    });

    test('tolerates the accuracy a phone actually reports outdoors', () {
      // Real handsets commonly report 20-40 m; gating at the radius meant
      // nothing ever unlocked in the field.
      expect(isPreciseEnough(fix(futala, acc: 30)), isTrue);
    });
  });

  group('evaluate', () {
    final all = [dest('a', futala), dest('b', north(futala, 3000))];

    test('reports the nearest still-locked place', () {
      final r = evaluate(at: north(futala, 120), all: all, unlocked: {});
      expect(r.nearest!.id, 'a');
      expect(r.distanceM, closeTo(120, 2));
      expect(r.inRadius, isEmpty);
    });

    test('lists a place once inside the radius', () {
      final r = evaluate(at: north(futala, 20), all: all, unlocked: {});
      expect(r.inRadius.map((d) => d.id), ['a']);
    });

    test('orders overlapping places nearest first', () {
      // The real Prem Nagar set has places 39 m apart, so more than one can sit
      // inside the radius; taking the first must never hand out the wrong token.
      final close = [
        dest('far', north(futala, 24)),
        dest('near', north(futala, 4)),
        dest('mid', north(futala, 14)),
      ];
      final r = evaluate(at: futala, all: close, unlocked: {});
      expect(r.inRadius.map((d) => d.id), ['near', 'mid', 'far']);
      expect(r.nearest!.id, 'near');
    });

    test('excludes places already unlocked', () {
      final r = evaluate(at: futala, all: all, unlocked: {'a'});
      expect(r.inRadius, isEmpty);
      expect(r.nearest!.id, 'b');
    });

    test('the boundary is inclusive and just outside it is not', () {
      expect(evaluate(at: north(futala, kUnlockRadiusM - 1), all: all, unlocked: {}).inRadius,
          hasLength(1));
      expect(evaluate(at: north(futala, kUnlockRadiusM + 1), all: all, unlocked: {}).inRadius,
          isEmpty);
    });

    test('the radius stays under the closest real spacing', () {
      // Prem Nagar's tightest pair is 39 m apart. A radius at or above that
      // would unlock both from one spot.
      expect(kUnlockRadiusM, lessThan(39));
    });

    test('returns nothing to aim at once everything is lit', () {
      final r = evaluate(at: futala, all: all, unlocked: {'a', 'b'});
      expect(r.nearest, isNull);
      expect(r.distanceM, isNull);
    });
  });
}
