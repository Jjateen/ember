#!/usr/bin/env python3
"""Generate a coverage grid of destinations over a neighbourhood.

The points are laid out geometrically around an anchor, not taken from a
landmark database, so they are a starting set to walk and correct rather than
surveyed positions. Adjust SPACING_M and the grid size, then re-run.
"""
import json
import math
import pathlib

# Centre of the Prem Nagar settlement, Goregaon West, Mumbai 400104. This is
# the viewport centre from the reference map link, not the place pin: the pin
# sits north of the dense area, over open ground.
ANCHOR_LAT = 19.1673500
ANCHOR_LNG = 72.8367000

COLS = 4
ROWS = 4
SPACING_M = 180

M_PER_DEG_LAT = 111_320.0
M_PER_DEG_LNG = M_PER_DEG_LAT * math.cos(math.radians(ANCHOR_LAT))

ROW_LETTERS = "ABCDEFGH"


def rarity_for(metres_from_centre: float) -> str:
    """Further out is rarer, so the edges of the area are worth the walk."""
    if metres_from_centre < 120:
        return "common"
    return "uncommon" if metres_from_centre < 260 else "rare"


def build() -> list[dict]:
    out = []
    mid_c = (COLS - 1) / 2
    mid_r = (ROWS - 1) / 2

    for r in range(ROWS):
        for c in range(COLS):
            dx = (c - mid_c) * SPACING_M
            dy = (mid_r - r) * SPACING_M

            lat = ANCHOR_LAT + dy / M_PER_DEG_LAT
            lng = ANCHOR_LNG + dx / M_PER_DEG_LNG

            from_centre = math.hypot(dx, dy)
            ring = max(abs(c - mid_c), abs(mid_r - r))
            ref = f"{ROW_LETTERS[r]}{c + 1}"

            if ring >= 1.5:
                where = "outer edge of the coverage area"
            elif ring >= 0.5:
                where = "middle band of the coverage area"
            else:
                where = "centre of the coverage area"

            out.append({
                "id": f"premnagar_{ref.lower()}",
                "name": f"Prem Nagar {ref}",
                "lat": round(lat, 6),
                "lng": round(lng, 6),
                "token": f"{ref} Coverage Token",
                "rarity": rarity_for(from_centre),
                "hint": f"Grid point {ref}, {where}. "
                        f"Roughly {SPACING_M} m from its neighbours.",
            })
    return out


if __name__ == "__main__":
    points = build()
    target = pathlib.Path(__file__).resolve().parents[1] / "assets" / "destinations.json"
    target.write_text(json.dumps(points, indent=2) + "\n")

    span_x = (COLS - 1) * SPACING_M
    span_y = (ROWS - 1) * SPACING_M
    print(f"wrote {len(points)} points to {target}")
    print(f"grid spans {span_x} m east-west by {span_y} m north-south")
    print(f"anchor {ANCHOR_LAT}, {ANCHOR_LNG}")
