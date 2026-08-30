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

STEP_M = 22.0
STEP_DELAY_S = 0.6
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


def serpentine(points: list[dict]) -> list[dict]:
    """Row by row, alternating direction, so the route never doubles back."""
    rows: dict = {}
    for p in points:
        rows.setdefault(round(p["lat"], 5), []).append(p)

    ordered = []
    for i, lat in enumerate(sorted(rows, reverse=True)):
        row = sorted(rows[lat], key=lambda p: p["lng"], reverse=bool(i % 2))
        ordered.extend(row)
    return ordered


def walk(a: tuple, b: tuple) -> None:
    dist = metres(a, b)
    steps = max(1, int(dist / STEP_M))
    for i in range(1, steps + 1):
        t = i / steps
        geo_fix(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        time.sleep(STEP_DELAY_S)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hold", type=float, default=HOLD_S)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    src = pathlib.Path(__file__).resolve().parents[1] / "assets" / "destinations.json"
    route = serpentine(json.loads(src.read_text()))

    legs = [metres((route[i]["lat"], route[i]["lng"]),
                   (route[i + 1]["lat"], route[i + 1]["lng"]))
            for i in range(len(route) - 1)]
    travel = sum(legs) / STEP_M * STEP_DELAY_S
    total = travel + len(route) * (args.hold + SETTLE_S)

    print(f"route: {' -> '.join(p['name'].split()[-1] for p in route)}")
    print(f"path {sum(legs):.0f} m over {len(route)} points")
    print(f"estimated runtime {total / 60:.1f} min\n")
    if args.dry_run:
        return 0

    start = (route[0]["lat"] + 260 / M_PER_DEG_LAT, route[0]["lng"])
    geo_fix(*start)
    time.sleep(2.5)

    here = start
    t0 = time.time()
    for i, p in enumerate(route, 1):
        target = (p["lat"], p["lng"])
        walk(here, target)
        here = target
        geo_fix(*target)
        print(f"[{time.time()-t0:6.1f}s] {i:2}/{len(route)}  {p['name']:16} "
              f"holding {args.hold:.0f}s", flush=True)
        time.sleep(args.hold)
        time.sleep(SETTLE_S)

    print(f"\ndone in {(time.time()-t0)/60:.1f} min")
    return 0


if __name__ == "__main__":
    sys.exit(main())
