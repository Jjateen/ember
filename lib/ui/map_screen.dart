import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import '../domain/proximity.dart';
import '../theme/ember_theme.dart';
import 'game_controller.dart';

/// Both tile services are keyless but neither is unconditional: OSM forbids
/// bulk and offline use, and Esri asks for attribution and a subscription at
/// commercial volume. A real launch needs its own tiles.
const String kTileUserAgent = 'dev.jjateen.ember';
const String kStreetTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kSatelliteTiles =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

enum BaseMap { satellite, street }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.game});
  final GameController game;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  Timer? _ticker;
  GeoPoint? _followed;
  bool _firstFix = true;
  BaseMap _base = BaseMap.satellite;

  void _zoom(double delta) {
    final c = _map.camera;
    _map.move(c.center, (c.zoom + delta).clamp(3.0, 19.0));
  }

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

    if (me != null && (me.lat != _followed?.lat || me.lng != _followed?.lng)) {
      _followed = me;
      final zoom = _firstFix ? 16.8 : _map.camera.zoom;
      _firstFix = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(LatLng(me.lat, me.lng), zoom);
      });
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: const MapOptions(
                  initialCenter: LatLng(19.1673500, 72.8367000),
                  initialZoom: 16,
                  interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  if (_base == BaseMap.satellite)
                    TileLayer(
                      urlTemplate: kSatelliteTiles,
                      userAgentPackageName: kTileUserAgent,
                      maxNativeZoom: 19,
                      // The camera pans continuously while walking; without a
                      // wider buffer the map shows grey holes as tiles load.
                      panBuffer: 2,
                      keepBuffer: 6,
                      tileProvider: NetworkTileProvider(),
                    )
                  else
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_desaturate),
                      child: TileLayer(
                        urlTemplate: kStreetTiles,
                        userAgentPackageName: kTileUserAgent,
                        panBuffer: 2,
                        keepBuffer: 6,
                        tileProvider: NetworkTileProvider(),
                      ),
                    ),
                  if (g.trail.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [for (final t in g.trail) LatLng(t.lat, t.lng)],
                        strokeWidth: 5,
                        color: Ember.deepRed.withValues(alpha: 0.75),
                        borderStrokeWidth: 2,
                        borderColor: Colors.white.withValues(alpha: 0.85),
                      ),
                    ]),
                  if (me != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: LatLng(me.lat, me.lng),
                        radius: kUnlockRadiusM,
                        useRadiusInMeter: true,
                        color: Ember.red.withValues(alpha: 0.12),
                        borderColor: Ember.red.withValues(alpha: 0.7),
                        borderStrokeWidth: 1.6,
                      ),
                    ]),
                  MarkerLayer(markers: _markers(g, me)),
                ],
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Chip(found: g.foundCount, total: g.totalCount),
                      const Spacer(),
                      _Island(children: [
                        _IslandBtn(
                          icon: _base == BaseMap.satellite
                              ? Icons.map_outlined
                              : Icons.satellite_alt_outlined,
                          onTap: () => setState(() => _base = _base == BaseMap.satellite
                              ? BaseMap.street
                              : BaseMap.satellite),
                        ),
                        const _IslandDivider(),
                        _IslandBtn(icon: Icons.add, onTap: () => _zoom(1)),
                        const _IslandDivider(),
                        _IslandBtn(icon: Icons.remove, onTap: () => _zoom(-1)),
                        const _IslandDivider(),
                        _IslandBtn(
                          icon: Icons.my_location,
                          onTap: () {
                            final at = widget.game.lastFix?.at;
                            if (at != null) _map.move(LatLng(at.lat, at.lng), 17.2);
                          },
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: _Attribution(base: _base),
              ),
            ],
          ),
        ),
        _Sheet(
          game: g,
          nearest: g.proximity.nearest,
          distanceM: g.proximity.distanceM,
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
          Row(
            children: [
              Text(
                dwelling ? 'HOLD POSITION' : 'NEAREST',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: warm ? Ember.red : Ember.muted,
                    ),
              ),
              if (!dwelling) ...[
                const SizedBox(width: 8),
                _TrendPill(trend: game.trend),
              ],
              const Spacer(),
              Text(
                '${(game.trailMetres / 1000).toStringAsFixed(2)} km walked',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
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

/// A single floating capsule, so the controls travel together and cannot be
/// clipped by the sheet the way free-floating buttons were.
class _Island extends StatelessWidget {
  const _Island({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Ember.card.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
}

class _IslandDivider extends StatelessWidget {
  const _IslandDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 26, height: 1, color: Ember.line);
}

class _IslandBtn extends StatelessWidget {
  const _IslandBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 44,
          child: Icon(icon, size: 21, color: Ember.ink),
        ),
      );
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.base});
  final BaseMap base;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: Ember.card.withValues(alpha: 0.78),
        child: Text(
          base == BaseMap.satellite ? 'Imagery © Esri' : '© OpenStreetMap contributors',
          style: const TextStyle(fontSize: 8.5, color: Ember.ink),
        ),
      );
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.trend});
  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg) = switch (trend) {
      Trend.warmer => ('WARMER', Icons.arrow_upward_rounded, Ember.red),
      Trend.colder => ('COLDER', Icons.arrow_downward_rounded, Ember.muted),
      Trend.steady => ('HOLDING', Icons.remove_rounded, Ember.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: trend == Trend.warmer ? Ember.coral.withValues(alpha: 0.22) : Ember.sage,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: fg),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: fg)),
      ]),
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
