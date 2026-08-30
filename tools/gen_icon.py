#!/usr/bin/env python3
"""Draw the launcher icon: one lit block on the pale ground of the palette.

Drawn directly with PIL rather than rasterising an SVG, because the SVG
renderers available here either drop opacity or cache stale output by file URL.
"""
import pathlib

from PIL import Image, ImageDraw

SIZE = 1024
SS = 4

BG = (237, 237, 237, 255)
HALO = (247, 228, 226, 255)
RING = (216, 217, 207, 255)
TOP = (255, 135, 135, 255)
RIGHT = (226, 104, 104, 255)
LEFT = (185, 79, 79, 255)

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def draw_icon(size: int) -> Image.Image:
    s = size * SS
    img = Image.new("RGBA", (s, s), BG)
    d = ImageDraw.Draw(img)

    cx, cy = s / 2, s / 2 + s * 0.03
    r = s * 0.37
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=HALO,
              outline=RING, width=int(s * 0.018))

    w = s * 0.28
    h = w * 0.5
    depth = s * 0.24

    top = [(cx, cy - h), (cx + w, cy), (cx, cy + h), (cx - w, cy)]
    left = [(cx - w, cy), (cx, cy + h), (cx, cy + h + depth), (cx - w, cy + depth)]
    right = [(cx, cy + h), (cx + w, cy), (cx + w, cy + depth), (cx, cy + h + depth)]

    d.polygon(left, fill=LEFT)
    d.polygon(right, fill=RIGHT)
    d.polygon(top, fill=TOP)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    root = pathlib.Path(__file__).resolve().parents[1]
    master = draw_icon(SIZE)

    res = root / "android" / "app" / "src" / "main" / "res"
    for name, px in DENSITIES.items():
        out = res / f"mipmap-{name}"
        out.mkdir(parents=True, exist_ok=True)
        master.resize((px, px), Image.LANCZOS).save(out / "ic_launcher.png")
        print(f"  mipmap-{name}/ic_launcher.png  {px}x{px}")

    docs = root / "docs"
    docs.mkdir(exist_ok=True)
    master.resize((512, 512), Image.LANCZOS).save(docs / "icon.png")
    print(f"wrote {docs / 'icon.png'}")


if __name__ == "__main__":
    main()
