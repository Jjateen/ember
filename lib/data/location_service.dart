import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/models.dart';
import '../domain/proximity.dart';

/// The seam that makes the game testable and demoable indoors. Everything above
/// this line is plugin-free.
abstract class LocationService {
  Stream<Fix> fixes();

  /// Returns null when permission was granted, or a human-readable reason.
  Future<String?> ensurePermission();

  void dispose();
}

class GeolocatorLocationService implements LocationService {
  StreamSubscription<Position>? _sub;
  final _out = StreamController<Fix>.broadcast();

  @override
  Stream<Fix> fixes() {
    _sub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (p) => _out.add(Fix(
        at: GeoPoint(p.latitude, p.longitude),
        accuracyM: p.accuracy,
        timestamp: p.timestamp,
        isMocked: p.isMocked,
      )),
      onError: _out.addError,
    );
    return _out.stream;
  }

  @override
  Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location is switched off on this device.';
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied) {
      return 'Ember needs location access to know when you arrive.';
    }
    if (p == LocationPermission.deniedForever) {
      return 'Location is blocked for Ember. Enable it in system settings.';
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _out.close();
  }
}

/// Drives the game from a scripted route. Used by tests and by the dev flavour
/// so the whole loop can be demonstrated without walking outside.
class FakeLocationService implements LocationService {
  final _out = StreamController<Fix>.broadcast();
  Fix? last;

  @override
  Stream<Fix> fixes() => _out.stream;

  @override
  Future<String?> ensurePermission() async => null;

  void emit(double lat, double lng, {double accuracyM = 8, bool mocked = false}) {
    final f = Fix(
      at: GeoPoint(lat, lng),
      accuracyM: accuracyM,
      timestamp: DateTime.now(),
      isMocked: mocked,
    );
    last = f;
    _out.add(f);
  }

  @override
  void dispose() => _out.close();
}
