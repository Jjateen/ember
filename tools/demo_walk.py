#!/usr/bin/env python3
"""Drive the emulator's GPS along a serpentine route through every destination.

Movement is interpolated rather than teleported, for two reasons: it looks like
walking on camera, and the app rejects fixes implying more than 200 km/h, so a
straight jump between grid points would be silently discarded.
"""
import argparse
import json
import math
import pathlib
import subprocess
import sys
import time

M_PER_DEG_LAT = 111_320.0

# Real walking pace. The recording is sped up afterwards, so the app sees a
# plausible GPS cadence rather than a jog, and the trail is shaped by genuine
# movement instead of long jumps.
STEP_M = 2.0
STEP_DELAY_S = 2.0

# Lateral wobble, in metres, so the trace reads as someone walking rather than
# a machine following a spline.
WOBBLE_M = 1.2
HOLD_S = 16.0
SETTLE_S = 1.0


def geo_fix(lat: float, lng: float) -> None:
    subprocess.run(
        ["adb", "emu", "geo", "fix", f"{lng:.6f}", f"{lat:.6f}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
    )


def m_per_deg_lng(lat: float) -> float:
    return M_PER_DEG_LAT * math.cos(math.radians(lat))


def metres(a: tuple, b: tuple) -> float:
    dlat = (b[0] - a[0]) * M_PER_DEG_LAT
    dlng = (b[1] - a[1]) * m_per_deg_lng((a[0] + b[0]) / 2)
    return math.hypot(dlat, dlng)


def nearest_first(points: list[dict]) -> list[dict]:
    """Greedy nearest-neighbour from the western-most place.

    The destinations are surveyed positions rather than a grid, so there is no
    row structure to walk along; this just avoids obvious doubling back.
    """
    remaining = sorted(points, key=lambda p: p["lng"])
    route = [remaining.pop(0)]
    while remaining:
        here = (route[-1]["lat"], route[-1]["lng"])
        nxt = min(remaining, key=lambda p: metres(here, (p["lat"], p["lng"])))
        remaining.remove(nxt)
        route.append(nxt)
    return route


def catmull_rom(p0, p1, p2, p3, t):
    """Position along the curve from p1 to p2, in lat/lng."""
    t2, t3 = t * t, t * t * t
    out = []
    for i in range(2):
        a, b, c, d = p0[i], p1[i], p2[i], p3[i]
        out.append(0.5 * ((2 * b)
                          + (-a + c) * t
                          + (2 * a - 5 * b + 4 * c - d) * t2
                          + (-a + 3 * b - 3 * c + d) * t3))
    return (out[0], out[1])


def curve_between(route: list[tuple], i: int) -> list[tuple]:
    """Sampled curve from route[i] to route[i+1], road-like rather than straight.

    OSM has no geometry for the lanes inside the settlement, and a routing
    engine detours over a kilometre around a 70 m gap, so the path is smoothed
    through the surveyed points instead of snapped to mapped roads.
    """
    p1, p2 = route[i], route[i + 1]
    p0 = route[i - 1] if i > 0 else p1
    p3 = route[i + 2] if i + 2 < len(route) else p2

    span = metres(p1, p2)
    steps = max(2, int(span / STEP_M))
    pts = []
    for n in range(1, steps + 1):
        t = n / steps
        lat, lng = catmull_rom(p0, p1, p2, p3, t)
        if WOBBLE_M and n < steps:
            sway = math.sin(t * math.pi * 3) * WOBBLE_M
            dlat, dlng = p2[0] - p1[0], p2[1] - p1[1]
            norm = math.hypot(dlat, dlng) or 1e-9
            lat += (-dlng / norm) * sway / M_PER_DEG_LAT
            lng += (dlat / norm) * sway / m_per_deg_lng(lat)
        pts.append((lat, lng))
    return pts


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hold", type=float, default=HOLD_S)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    src = pathlib.Path(__file__).resolve().parents[1] / "assets" / "destinations.json"
    route = nearest_first(json.loads(src.read_text()))

    legs = [metres((route[i]["lat"], route[i]["lng"]),
                   (route[i + 1]["lat"], route[i + 1]["lng"]))
            for i in range(len(route) - 1)]
    travel = sum(legs) / STEP_M * STEP_DELAY_S
    total = travel + len(route) * (args.hold + SETTLE_S)

    print('route: ' + ' -> '.join(p['name'] for p in route))
    print(f"path {sum(legs):.0f} m over {len(route)} points")
    print(f"estimated runtime {total / 60:.1f} min\n")
    if args.dry_run:
        return 0

    start = (route[0]["lat"] - 90 / M_PER_DEG_LAT, route[0]["lng"])
    geo_fix(*start)
    time.sleep(2.5)

    coords = [(p["lat"], p["lng"]) for p in route]
    approach = [start] + coords

    t0 = time.time()
    for i, p in enumerate(route, 1):
        for lat, lng in curve_between(approach, i - 1):
            geo_fix(lat, lng)
            time.sleep(STEP_DELAY_S)
        geo_fix(p["lat"], p["lng"])
        print(f"[{time.time()-t0:6.1f}s] {i:2}/{len(route)}  {p['name']:16} "
              f"holding {args.hold:.0f}s", flush=True)
        time.sleep(args.hold)
        time.sleep(SETTLE_S)

    print(f"\ndone in {(time.time()-t0)/60:.1f} min")
    return 0


if __name__ == "__main__":
    sys.exit(main())
