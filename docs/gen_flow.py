#!/usr/bin/env python3
"""Emit the Ember runtime unlock data-flow as SVG."""
import textwrap

W = 1280
CX = 640
BW = 780
SANS = "DejaVu Sans, Verdana, sans-serif"
MONO = "DejaVu Sans Mono, Consolas, monospace"

ROLE = {
    "native":  ("#EFEFEF", "#9E9E9E", "#444444"),
    "chan":    ("#EFEFEF", "#9E9E9E", "#444444"),
    "vm":      ("#FEF3E4", "#D9A441", "#8A5A00"),
    "guard":   ("#FDECEA", "#E0796F", "#B03024"),
    "pure":    ("#FDECEC", "#E26868", "#B94F4F"),
    "persist": ("#F1EAF6", "#9673A6", "#6B3E8F"),
    "emit":    ("#D9EAD3", "#82B366", "#3C7020"),
}

HEAD = [
    ("native", "CLLocationManager  /  FusedLocationProviderClient",
     ["OS delivers a fix. distanceFilter: 10 means at most one callback",
      "per 10 m moved, not one per second."], ""),
    ("chan", "geolocator  &#183;  EventChannel  &#8594;  Stream&lt;Position&gt;",
     ["Position { latitude, longitude, accuracy, speed, isMocked, timestamp }"], ""),
    ("vm", "GameController._onPosition(Position p)",
     ["One subscription, owned app-wide. Cancelled in dispose(),",
      "paused on AppLifecycleState.paused so a backgrounded app stops drawing power."], ""),
    ("guard", "GUARD  &#183;  reject untrustworthy fixes",
     ["if (p.accuracy > 50)                   return;  // fix too fuzzy to trust",
      "if (p.isMocked)                        return;  // Android mock provider",
      "if (impliedSpeed(p, _last) > 200)      return;  // km/h; teleport",
      "if (_fixCount++ &lt; 3)                   return;  // cold-start junk"],
     "Dropped fixes never reach the game rules. The first few fixes after a cold start are always noise."),
    ("pure", "proximity.evaluate(...)  &#8594;  ProximityResult",
     ["for (final d in all.where((d) => !unlocked.contains(d.id)))",
      "  haversineMeters(p, d.at);",
      "",
      "returns ProximityResult { nearest, distanceM, inRadius }"],
     "Pure function: no await, no plugin import, no Flutter import. This is the line every unit test exercises."),
]

BRANCH_L = ("vm", "EVERY fix  &#8594;  notifyListeners()",
            ["Rebuilds the bottom sheet and the range ring only.",
             "Fires roughly once per 10 m walked.",
             "",
             "markers is NOT reassigned on this path."],
            "Rebuilding Set&lt;Marker&gt; here is the bug that freezes the map.")

BRANCH_R = ("vm", "IN RADIUS  &#8594;  start the dwell timer",
            ["_dwell ??= Timer(const Duration(seconds: 15),",
             "                 () => _onDwellComplete(d));",
             "",
             "// on leaving the radius:",
             "_dwell?.cancel(); _dwell = null;"],
            "The dwell timer is what lets a 50 m radius survive GPS drift.")

TAIL = [
    ("persist", "await progressRepository.markUnlocked(d.id)",
     ["Future&lt;Result&lt;void&gt;&gt;  &#8212;  awaited BEFORE anything visible happens.",
      "SharedPreferencesAsync.setStringList('unlocked', [...]);",
      "",
      "switch (result) {",
      "  case Ok():     break;",
      "  case Error():  return;   // no reward if the write failed",
      "}"],
     "Persist first, celebrate second. A crash mid-animation must not eat a place the player physically walked to."),
    ("emit", "_events.add(UnlockEvent(d))   +   notifyListeners()",
     ["HapticFeedback.heavyImpact();",
      "Navigator.push(IgnitionRoute(d));",
      "mapViewModel.rebuildMarkers();   // the ONE place markers are rebuilt"],
     ""),
]

out = []


def note(x, y, text, width=104):
    if not text:
        return 0
    lines = textwrap.wrap(text, width)
    for i, ln in enumerate(lines):
        out.append(f'<text x="{x}" y="{y + i*15:.0f}" font-size="11.8" fill="#7A2321" '
                   f'font-style="italic">{ln}</text>')
    return len(lines) * 15 + 4


def box(x, y, w, role, title, lines, n, notew=104):
    bg, br, ac = ROLE[role]
    h = 34 + len(lines) * 16.5 + 10
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h:.0f}" rx="7" fill="{bg}" '
               f'stroke="{br}" stroke-width="1.8"/>')
    out.append(f'<text x="{x+14}" y="{y+23}" font-size="13.6" font-weight="bold" fill="{ac}">{title}</text>')
    ly = y + 43
    for ln in lines:
        out.append(f'<text x="{x+14}" y="{ly:.1f}" font-size="11.7" fill="#333" '
                   f'font-family="{MONO}" xml:space="preserve">{ln}</text>')
        ly += 16.5
    return h + note(x + 2, y + h + 15, n, notew)


def arrow(x, y0, y1, label=""):
    out.append(f'<line x1="{x}" y1="{y0}" x2="{x}" y2="{y1}" stroke="#333" stroke-width="2.2" '
               f'marker-end="url(#a)"/>')
    if label:
        out.append(f'<text x="{x+10}" y="{(y0+y1)/2+4:.0f}" font-size="11.5" fill="#555" '
                   f'font-family="{MONO}">{label}</text>')


out.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="HEIGHT" '
           f'viewBox="0 0 {W} HEIGHT" font-family="{SANS}">')
out.append('<defs><marker id="a" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto">'
           '<path d="M0,1 L10,6 L0,11 z" fill="#333"/></marker></defs>')
out.append(f'<rect width="{W}" height="HEIGHT" fill="#ffffff"/>')

y = 28
out.append(f'<text x="34" y="{y+24}" font-size="27" font-weight="bold" fill="#111">'
           'Ember &#8212; one GPS fix, end to end</text>')
out.append(f'<text x="34" y="{y+49}" font-size="14.3" fill="#666">'
           'The only flow in the app that matters. Every other screen is a list or a sheet.</text>')
y += 78

for role, title, lines, n in HEAD:
    y += box(CX - BW // 2, y, BW, role, title, lines, n)
    arrow(CX, y + 4, y + 27)
    y += 31

LW = 590
lx, rx = 30, W - 30 - LW
out.append(f'<line x1="{CX}" y1="{y-31}" x2="{CX}" y2="{y-14}" stroke="#333" stroke-width="2.2"/>')
out.append(f'<line x1="{lx+LW//2}" y1="{y-14}" x2="{rx+LW//2}" y2="{y-14}" stroke="#333" stroke-width="2.2"/>')
for bxc in (lx + LW // 2, rx + LW // 2):
    out.append(f'<line x1="{bxc}" y1="{y-14}" x2="{bxc}" y2="{y+3}" stroke="#333" '
               f'stroke-width="2.2" marker-end="url(#a)"/>')
y += 8

start = y
hl = box(lx, y, LW, BRANCH_L[0], BRANCH_L[1], BRANCH_L[2], BRANCH_L[3], 78)
hr = box(rx, y, LW, BRANCH_R[0], BRANCH_R[1], BRANCH_R[2], BRANCH_R[3], 78)
y = start + max(hl, hr) + 16

rxc = rx + LW // 2
out.append(f'<line x1="{rxc}" y1="{y-10}" x2="{rxc}" y2="{y+10}" stroke="#333" stroke-width="2.2"/>')
out.append(f'<line x1="{rxc}" y1="{y+10}" x2="{CX}" y2="{y+10}" stroke="#333" stroke-width="2.2"/>')
out.append(f'<line x1="{CX}" y1="{y+10}" x2="{CX}" y2="{y+30}" stroke="#333" stroke-width="2.2" '
           f'marker-end="url(#a)"/>')
out.append(f'<text x="{CX+14}" y="{y+6}" font-size="11.5" fill="#555" font-family="{MONO}">'
           'timer completes: 15 s held inside the radius</text>')
y += 36

for i, (role, title, lines, n) in enumerate(TAIL):
    y += box(CX - BW // 2, y, BW, role, title, lines, n)
    if i < len(TAIL) - 1:
        arrow(CX, y + 4, y + 27)
        y += 31

y += 26
out.append('</svg>')
open("arch_flow.svg", "w").write("\n".join(out).replace("HEIGHT", str(int(y))))
print("wrote arch_flow.svg", int(y))
