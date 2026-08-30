import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/location_service.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../domain/proximity.dart';

/// Time the player must stay inside the radius before a place ignites. Without
/// this, GPS drift alone flips markers on and off at a 50 m radius.
const Duration kDwell = Duration(seconds: 15);

/// The first fixes after a cold start are consistently wrong; ignore them.
const int kWarmupFixes = 3;

/// Movement smaller than this is GPS jitter, not progress, so it must not flip
/// the warmer/colder readout back and forth while standing still.
const double kTrendDeadbandM = 3;

/// Breadcrumbs are capped so a long session cannot grow the trail without end.
const int kTrailLimit = 3000;

class GameController extends ChangeNotifier {
  GameController({
    required this.locationService,
    required this.destinationRepo,
    required this.progressRepo,
  });

  final LocationService locationService;
  final DestinationRepository destinationRepo;
  final ProgressRepository progressRepo;

  StreamSubscription<Fix>? _sub;
  Timer? _dwell;
  Fix? _previous;
  Fix? lastFix;
  int _fixCount = 0;

  final _events = StreamController<UnlockEvent>.broadcast();
  Stream<UnlockEvent> get unlocks => _events.stream;

  List<Destination> destinations = const [];
  Set<String> unlockedIds = const {};
  ProximityResult proximity = ProximityResult.empty;

  final List<GeoPoint> trail = [];
  Trend trend = Trend.steady;
  double? _lastDistanceM;
  String? _lastNearestId;
  double trailMetres = 0;

  String? permissionProblem;
  bool loading = true;

  /// Non-null while a dwell countdown is running, so the UI can draw progress.
  Destination? dwellTarget;
  DateTime? dwellStartedAt;
  bool unlockInFlight = false;

  int get foundCount => unlockedIds.length;
  int get totalCount => destinations.length;

  double? get dwellProgress {
    final started = dwellStartedAt;
    if (started == null) return null;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    return (elapsed / kDwell.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<void> start() async {
    destinations = await destinationRepo.all();
    unlockedIds = await progressRepo.unlockedIds();
    permissionProblem = await locationService.ensurePermission();
    loading = false;
    notifyListeners();

    if (permissionProblem != null) return;
    _sub = locationService.fixes().listen(_onFix, onError: (_) {});
  }

  void _onFix(Fix fix) {
    if (_fixCount++ < kWarmupFixes) {
      _previous = fix;
      return;
    }
    if (!isTrustworthy(fix, previous: _previous, rejectMocked: !kDebugMode)) return;
    if (_previous != null) {
      trailMetres += haversineMeters(_previous!.at, fix.at);
    }
    _previous = fix;
    lastFix = fix;

    trail.add(fix.at);
    if (trail.length > kTrailLimit) trail.removeAt(0);

    proximity = evaluate(at: fix.at, all: destinations, unlocked: unlockedIds);
    _updateTrend();

    final target = proximity.inRadius.isEmpty ? null : proximity.inRadius.first;
    if (target == null) {
      _cancelDwell();
    } else if (dwellTarget?.id != target.id) {
      _startDwell(target);
    }
    notifyListeners();
  }

  void _updateTrend() {
    final d = proximity.distanceM;
    final id = proximity.nearest?.id;
    if (d == null || id == null || id != _lastNearestId || _lastDistanceM == null) {
      trend = Trend.steady;
    } else {
      final delta = d - _lastDistanceM!;
      trend = delta < -kTrendDeadbandM
          ? Trend.warmer
          : (delta > kTrendDeadbandM ? Trend.colder : Trend.steady);
    }
    _lastDistanceM = d;
    _lastNearestId = id;
  }

  void _startDwell(Destination d) {
    _dwell?.cancel();
    dwellTarget = d;
    dwellStartedAt = DateTime.now();
    _dwell = Timer(kDwell, () => _ignite(d));
  }

  void _cancelDwell() {
    _dwell?.cancel();
    _dwell = null;
    dwellTarget = null;
    dwellStartedAt = null;
  }

  Future<void> _ignite(Destination d) async {
    if (unlockInFlight || unlockedIds.contains(d.id)) return;
    unlockInFlight = true;
    try {
      // Persist before celebrating: a crash mid-animation must not lose a place
      // the player physically walked to.
      await progressRepo.markUnlocked(d.id);
      unlockedIds = {...unlockedIds, d.id};
      _cancelDwell();
      proximity = ProximityResult.empty;
      unawaited(HapticFeedback.heavyImpact());
      _events.add(UnlockEvent(d, unlockedIds.length, destinations.length));
      notifyListeners();
    } finally {
      unlockInFlight = false;
    }
  }

  /// Used by the dev flavour and by tests to force an unlock without walking.
  Future<void> debugIgnite(Destination d) => _ignite(d);

  Future<void> resetProgress() async {
    await progressRepo.reset();
    unlockedIds = const {};
    trail.clear();
    trailMetres = 0;
    _cancelDwell();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dwell?.cancel();
    _events.close();
    locationService.dispose();
    super.dispose();
  }
}
