import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import '../domain/proximity.dart';
import '../theme/ember_theme.dart';
import 'game_controller.dart';

/// OpenStreetMap's tile policy requires a User-Agent that identifies the app.
/// Their public server also forbids bulk or offline use, so a real launch needs
/// its own tile source.
const String kTileUserAgent = 'dev.jjateen.ember';
const String kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.game});
  final GameController game;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  Timer? _ticker;
  bool _centredOnce = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && widget.game.dwellTarget != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final me = g.lastFix?.at;

    if (me != null && !_centredOnce) {
      _centredOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(LatLng(me.lat, me.lng), 16.6);
      });
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: const MapOptions(
            initialCenter: LatLng(19.1718491, 72.8382547),
            initialZoom: 16,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(_desaturate),
              child: TileLayer(
                urlTemplate: kTileUrl,
                userAgentPackageName: kTileUserAgent,
                tileProvider: NetworkTileProvider(),
              ),
            ),
            if (me != null)
              CircleLayer(circles: [
                CircleMarker(
                  point: LatLng(me.lat, me.lng),
                  radius: kUnlockRadiusM,
                  useRadiusInMeter: true,
                  color: Ember.red.withValues(alpha: 0.10),
                  borderColor: Ember.red.withValues(alpha: 0.55),
                  borderStrokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(markers: _markers(g, me)),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: _Chip(found: g.foundCount, total: g.totalCount),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _Sheet(
            game: g,
            nearest: g.proximity.nearest,
            distanceM: g.proximity.distanceM,
          ),
        ),
      ],
    );
  }

  List<Marker> _markers(GameController g, GeoPoint? me) => [
        for (final d in g.destinations)
          Marker(
            point: LatLng(d.at.lat, d.at.lng),
            width: 30,
            height: 30,
            child: _Pin(
              lit: g.unlockedIds.contains(d.id),
              warming: g.dwellTarget?.id == d.id,
            ),
          ),
        if (me != null)
          Marker(
            point: LatLng(me.lat, me.lng),
            width: 22,
            height: 22,
            child: const _Me(),
          ),
      ];
}

/// Pulls the basemap toward grey so the red markers are the only saturated
/// thing on screen.
const List<double> _desaturate = <double>[
  0.50, 0.42, 0.08, 0, 18,
  0.38, 0.54, 0.08, 0, 18,
  0.38, 0.42, 0.20, 0, 18,
  0, 0, 0, 1, 0,
];

class _Pin extends StatelessWidget {
  const _Pin({required this.lit, required this.warming});
  final bool lit;
  final bool warming;

  @override
  Widget build(BuildContext context) {
    final fill = lit ? Ember.red : (warming ? Ember.coral : Ember.card);
    final border = lit ? Ember.coral : (warming ? Ember.red : Ember.muted);
    return Center(
      child: Container(
        width: lit ? 20 : 16,
        height: lit ? 20 : 16,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: lit ? 3 : 2),
          boxShadow: lit
              ? [BoxShadow(color: Ember.red.withValues(alpha: 0.45), blurRadius: 12, spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }
}

class _Me extends StatelessWidget {
  const _Me();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Ember.ink,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.found, required this.total});
  final int found;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Ember.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Ember.line),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(
            text: '$found',
            style: const TextStyle(
              color: Ember.red,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: '/$total  IGNITED',
            style: const TextStyle(color: Ember.muted, letterSpacing: 1.1, fontSize: 11),
          ),
        ])),
      );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.game, required this.nearest, required this.distanceM});

  final GameController game;
  final Destination? nearest;
  final double? distanceM;

  @override
  Widget build(BuildContext context) {
    if (game.permissionProblem != null) {
      return _Panel(child: Text(game.permissionProblem!));
    }
    if (nearest == null) {
      return _Panel(
        child: Text(
          game.foundCount == game.totalCount
              ? 'Every place is lit. Nothing left to find.'
              : 'Waiting for a location fix…',
          style: const TextStyle(color: Ember.muted),
        ),
      );
    }

    final d = distanceM ?? 0;
    final dwelling = game.dwellTarget != null;
    final warm = d <= kWarmRadiusM;
    final progress = dwelling
        ? (game.dwellProgress ?? 0)
        : (1 - ((d - kUnlockRadiusM) / (kWarmRadiusM - kUnlockRadiusM))).clamp(0.0, 1.0);

    return _Panel(
      warm: warm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dwelling ? 'HOLD POSITION' : (warm ? 'NEAREST · WARMING' : 'NEAREST · COLD'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: warm ? Ember.red : Ember.muted,
                ),
          ),
          const SizedBox(height: 3),
          Text(nearest!.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                d >= 1000 ? (d / 1000).toStringAsFixed(1) : d.round().toString(),
                style: const TextStyle(
                  color: Ember.red,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(d >= 1000 ? 'km' : 'm', style: const TextStyle(color: Ember.muted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Ember.sage,
              valueColor: AlwaysStoppedAnimation(dwelling ? Ember.red : Ember.coral),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dwelling
                ? 'Stay put · ignites in ${(kDwell.inSeconds * (1 - (game.dwellProgress ?? 0))).ceil()} s'
                : 'Ignites within ${kUnlockRadiusM.round()} m',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.warm = false});
  final Widget child;
  final bool warm;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: BoxDecoration(
          gradient: warm
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFECEA), Ember.card],
                )
              : null,
          color: warm ? null : Ember.card,
          border: const Border(top: BorderSide(color: Ember.line)),
        ),
        child: SafeArea(top: false, child: child),
      );
}
