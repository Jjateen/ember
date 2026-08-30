#!/usr/bin/env python3
"""Emit the Ember Flutter layer diagram as SVG."""
from html import escape

W = 1520
PAD = 34
BOX_GAP = 14

SANS = "DejaVu Sans, Verdana, sans-serif"
MONO = "DejaVu Sans Mono, Consolas, monospace"

BANDS = [
    ("1  PRESENTATION", "Widgets only. No business logic, no await, no plugin imports.",
     "#FCEBEA", "#E0A9A6", "#B94F4F", [
        ("EmberApp · StatelessWidget", [
            "MaterialApp(",
            "  theme: emberTheme,",
            "  home: HomeShell())",
        ]),
        ("HomeShell · StatefulWidget", [
            "NavigationBar + IndexedStack",
            "IndexedStack keeps GoogleMap",
            "alive across tab switches",
        ]),
        ("MapScreen · StatelessWidget", [
            "ListenableBuilder(",
            "  listenable: viewModel,",
            "  builder: (ctx, _) => GoogleMap(",
            "    markers:  viewModel.markers,",
            "    circles:  viewModel.rangeRing,",
            "    tiles:    Esri | OSM))",
        ]),
        ("TrayScreen · PlaceSheet · IgnitionScreen", [
            "GridView.builder  -> 60 token tiles",
            "showModalBottomSheet()  -> detail",
            "Navigator.push(IgnitionRoute)",
            "  pushed from GameController's",
            "  unlock stream, not from a tap",
        ]),
     ]),
    ("2  VIEW MODELS", "ChangeNotifier. Most of the logic lives here. Exposes Commands, never Futures, to the view.",
     "#FEF3E4", "#E0BE8A", "#B37400", [
        ("GameController · app-scoped singleton", [
            "class GameController extends ChangeNotifier {",
            "  StreamSubscription<Position>? _sub;",
            "  Timer?      _dwell;",
            "  Set<String> _unlocked = {};",
            "  List<GeoPoint> trail;     Trend trend;",
            "  final _events = StreamController<UnlockEvent>.broadcast();",
            "",
            "  Stream<UnlockEvent> get unlocks => _events.stream;",
            "  void _onPosition(Position p);",
            "  void _onDwellComplete(Destination d);",
            "}",
        ]),
        ("MapViewModel · route-scoped", [
            "class MapViewModel extends ChangeNotifier {",
            "  Command0<void> load;",
            "  List<Marker> markers;   // widgets, cheap",
            "  Polyline trail;         // breadcrumbs",
            "  ProximityView? nearest; // per GPS tick",
            "}",
            "",
            "class TrayViewModel extends ChangeNotifier {",
            "  Command0<void> load;",
            "  List<TokenTile> tiles;",
            "}",
        ]),
     ]),
    ("3  DOMAIN", "Pure Dart. Zero imports from Flutter, geolocator or Firebase. Where every unit test points.",
     "#FDECEC", "#E26868", "#B94F4F", [
        ("proximity.dart · the game rules", [
            "double haversineMeters(GeoPoint a, GeoPoint b);",
            "",
            "ProximityResult evaluate({",
            "  required GeoPoint at,",
            "  required double   accuracyM,",
            "  required List<Destination> all,",
            "  required Set<String>       unlocked,",
            "  double radiusM      = 50,",
            "  double accuracyCapM = 50,",
            "});",
        ]),
        ("models · immutable value types", [
            "class Destination {",
            "  final String  id, name, tokenName, hint;",
            "  final GeoPoint at;",
            "  final Rarity   rarity;",
            "}",
            "class ProximityResult {",
            "  final Destination?       nearest;",
            "  final double?            distanceM;",
            "  final List<Destination>  inRadius;",
            "}",
            "enum Rarity { common, uncommon, rare }",
        ]),
     ]),
    ("4  DATA · REPOSITORIES", "Abstract. One per data type. Source of truth. Never reference each other.",
     "#F1EAF6", "#B99BCB", "#7B52A0", [
        ("abstract DestinationRepository", [
            "Future<Result<List<Destination>>> all();",
            "",
            "impl AssetDestinationRepository",
            "     <- assets/destinations.json",
            "impl FirestoreDestinationRepository   (phase 2)",
        ]),
        ("abstract ProgressRepository", [
            "Future<Result<Set<String>>> unlockedIds();",
            "Future<Result<void>>        markUnlocked(String id);",
            "Stream<Set<String>>         watch();",
            "",
            "impl LocalProgressRepository",
            "impl FirestoreProgressRepository      (phase 2)",
        ]),
     ]),
    ("5  DATA · SERVICES", "Stateless. Each wraps exactly one external source. No caching, no rules, no decisions.",
     "#E7EEF7", "#9BB6D6", "#3D6FA8", [
        ("abstract LocationService", [
            "Stream<Position> positions(LocationSettings s);",
            "Future<LocationPermission> ensurePermission();",
            "",
            "impl GeolocatorLocationService",
            "impl FakeLocationService   <- testing/ + dev flavour",
        ]),
        ("LocalStoreService", [
            "Future<List<String>?> getStringList(String k);",
            "Future<void> setStringList(String k, List<String> v);",
            "",
            "wraps SharedPreferencesAsync",
            "(the plain SharedPreferences API is now legacy)",
        ]),
        ("AssetBundleService", [
            "Future<String> loadString(String path);",
            "  -> destinations.json",
            "  -> assets/tokens/*.png  (rendered",
            "     from the Rhino models)",
        ]),
     ]),
    ("6  PLUGINS  ->  PLATFORM CHANNELS  ->  NATIVE SDKs", "Async message passing across the Dart/native boundary. Everything above runs on the UI isolate.",
     "#EFEFEF", "#B5B5B5", "#555555", [
        ("geolocator 14.0.3", [
            "EventChannel -> Stream<Position>",
            "Android: FusedLocationProviderClient",
            "iOS:     CLLocationManager",
            "",
            "NOTE: geolocator has no geofencing API.",
            "Region monitoring needs native_geofence.",
        ]),
        ("flutter_map 8.3.2 + latlong2", [
            "Pure Dart canvas, no platform view.",
            "Markers are ordinary widgets.",
            "",
            "Tiles: Esri imagery (native max z19)",
            "       OSM streets, both keyless",
        ]),
        ("shared_preferences 2.5.5", [
            "MethodChannel",
            "Android: SharedPreferences XML",
            "iOS:     NSUserDefaults",
        ]),
     ]),
]


def measure(box):
    title, lines = box
    return max([len(title) * 0.60] + [len(l) * 0.585 for l in lines])


def build():
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="HEIGHT" '
        f'viewBox="0 0 {W} HEIGHT" font-family="{SANS}">',
        '<defs><marker id="a" markerWidth="12" markerHeight="12" refX="10" refY="6" '
        'orient="auto"><path d="M0,1 L10,6 L0,11 z" fill="#333"/></marker></defs>',
        f'<rect width="{W}" height="HEIGHT" fill="#ffffff"/>',
    ]

    y = 30
    out.append(f'<text x="{PAD}" y="{y+23}" font-size="28" font-weight="bold" fill="#111">'
               'Ember &#8212; Flutter application architecture</text>')
    out.append(f'<text x="{PAD}" y="{y+49}" font-size="14.5" fill="#666">'
               'Dependencies point downward only. Layers 1&#8211;2 are Flutter; layer 3 is plain Dart; '
               'layers 4&#8211;5 are swappable behind interfaces; layer 6 is async platform channels.</text>')
    y += 80

    for (label, sub, bg, border, accent, boxes) in BANDS:
        n = len(boxes)
        avail = W - PAD * 2 - 22
        widths = [measure(b) for b in boxes]
        raw = [max(150.0, w) for w in widths]
        scale = (avail - BOX_GAP * (n - 1)) / sum(raw)
        bw = [w * scale for w in raw]

        maxlines = max(len(b[1]) for b in boxes)
        boxh = 40 + maxlines * 16.5 + 12
        bandh = 48 + boxh + 16

        out.append(f'<rect x="{PAD}" y="{y}" width="{W-PAD*2}" height="{bandh}" rx="9" '
                   f'fill="{bg}" stroke="{border}" stroke-width="1.6"/>')
        out.append(f'<text x="{PAD+14}" y="{y+26}" font-size="15" font-weight="bold" '
                   f'fill="{accent}" letter-spacing="1.4">{escape(label)}</text>')
        out.append(f'<text x="{PAD+14}" y="{y+43}" font-size="12.6" fill="#5c5c5c">{escape(sub)}</text>')

        bx = PAD + 11
        for i, (title, lines) in enumerate(boxes):
            out.append(f'<rect x="{bx:.1f}" y="{y+48}" width="{bw[i]:.1f}" height="{boxh}" rx="6" '
                       f'fill="#ffffff" stroke="{border}" stroke-width="1.3"/>')
            out.append(f'<text x="{bx+11:.1f}" y="{y+48+21}" font-size="13.2" font-weight="bold" '
                       f'fill="#1a1a1a">{escape(title)}</text>')
            ly = y + 48 + 40
            for ln in lines:
                out.append(f'<text x="{bx+11:.1f}" y="{ly:.1f}" font-size="11.7" fill="#333" '
                           f'font-family="{MONO}" xml:space="preserve">{escape(ln)}</text>')
                ly += 16.5
            bx += bw[i] + BOX_GAP

        y += bandh
        if (label, sub, bg, border, accent, boxes) != BANDS[-1]:
            out.append(f'<line x1="{W/2}" y1="{y+3}" x2="{W/2}" y2="{y+24}" stroke="#333" '
                       f'stroke-width="2.2" marker-end="url(#a)"/>')
            y += 29

    y += 6
    out.append('</svg>')
    return "\n".join(out).replace("HEIGHT", str(int(y)))


open("arch_layers.svg", "w").write(build())
print("wrote arch_layers.svg")
