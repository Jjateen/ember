#!/usr/bin/env python3
"""Render each token model into a flat-shaded PNG the app can display.

Flutter cannot draw Rhino files, and a 3D engine would be a heavy dependency
for six small pictures, so each model is rasterised once here to a sprite.

Run inside the venv that has rhino3dm:
    ../.venv-3dm/bin/python tools/gen_token_art.py ../tokens
"""
import math
import pathlib
import sys

import numpy as np
import rhino3dm as r3
from PIL import Image, ImageDraw

SIZE = 512
SS = 2
MARGIN = 0.08

LIT = np.array([226, 104, 104], float)
COLD = np.array([174, 176, 164], float)
LIGHT = np.array([0.35, 0.5, 0.79])

# Yaw applied per model, in degrees about the vertical axis, so each building
# presents the face it should. The camera is fixed, looking from the north-east,
# so a model whose front sits away from that direction has to be turned.
ROTATE_DEG = {
    "detective_agency": 90,
}

# Source file stem -> destination id in assets/destinations.json.
MODEL_FOR = {
    "mandir": "sankat_mochan_hanuman",
    "detective agency": "detective_agency",
    "vachanalay": "vachanalay",
    "self emplyed": "self_employee",
    "open space": "open_space",
    "road": "the_road",
}


def meshes_in(path: pathlib.Path):
    """Every cached render mesh in the file, as (vertices, triangles)."""
    model = r3.File3dm.Read(str(path))
    out = []
    for obj in model.Objects:
        geom = obj.Geometry
        found = []
        if isinstance(geom, r3.Extrusion):
            mesh = geom.GetMesh(r3.MeshType.Any)
            if mesh:
                found.append(mesh)
        elif isinstance(geom, r3.Brep):
            for face in geom.Faces:
                mesh = face.GetMesh(r3.MeshType.Any)
                if mesh:
                    found.append(mesh)
        elif isinstance(geom, r3.Mesh):
            found.append(geom)

        for mesh in found:
            verts = np.array([[mesh.Vertices[i].X, mesh.Vertices[i].Y, mesh.Vertices[i].Z]
                              for i in range(len(mesh.Vertices))], float)
            tris = []
            for i in range(len(mesh.Faces)):
                f = mesh.Faces[i]
                tris.append([f[0], f[1], f[2]])
                if len(f) > 3 and f[3] != f[2]:
                    tris.append([f[0], f[2], f[3]])
            if len(verts) and tris:
                out.append((verts, np.array(tris, int)))
    return out


def render(parts, base_rgb, yaw_deg: float = 0) -> Image.Image:
    verts, tris, offset = [], [], 0
    for v, t in parts:
        verts.append(v)
        tris.append(t + offset)
        offset += len(v)
    V, T = np.vstack(verts), np.vstack(tris)

    if yaw_deg:
        a = math.radians(yaw_deg)
        c, s_ = math.cos(a), math.sin(a)
        centre = V.mean(axis=0)
        xy = V[:, :2] - centre[:2]
        V = np.column_stack([
            xy @ np.array([[c, s_], [-s_, c]]) + centre[:2],
            V[:, 2],
        ])

    view = np.array([-1.0, -1.0, -0.85])
    view /= np.linalg.norm(view)
    right = np.cross(view, [0, 0, 1.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, view)

    sx, sy, depth = V @ right, -(V @ up), V @ view

    s = SIZE * SS
    scale = (s * (1 - 2 * MARGIN)) / max(sx.max() - sx.min(), sy.max() - sy.min())
    px = (sx - (sx.min() + sx.max()) / 2) * scale + s / 2
    py = (sy - (sy.min() + sy.max()) / 2) * scale + s / 2

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    normals = np.cross(b - a, c - a)
    lengths = np.linalg.norm(normals, axis=1)
    good = lengths > 1e-12
    normals[good] /= lengths[good, None]
    shade = np.abs(normals @ LIGHT).clip(0, 1)

    for k in np.argsort(depth[T].mean(axis=1))[::-1]:
        if not good[k]:
            continue
        rgb = tuple(int(v) for v in (base_rgb * (0.42 + 0.58 * shade[k])).clip(0, 255))
        tri = T[k]
        d.polygon([(px[tri[0]], py[tri[0]]),
                   (px[tri[1]], py[tri[1]]),
                   (px[tri[2]], py[tri[2]])], fill=rgb + (255,))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    src_dir = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "../tokens").resolve()
    out_dir = pathlib.Path(__file__).resolve().parents[1] / "assets" / "tokens"
    out_dir.mkdir(parents=True, exist_ok=True)

    seen, missing = set(), []
    for path in sorted(src_dir.glob("*.3dm")):
        dest_id = MODEL_FOR.get(path.stem.lower())
        if dest_id is None:
            missing.append(path.name)
            continue
        parts = meshes_in(path)
        if not parts:
            print(f"  !! {path.name}: no render meshes")
            continue
        yaw = ROTATE_DEG.get(dest_id, 0)
        for suffix, colour in (("lit", LIT), ("cold", COLD)):
            render(parts, colour, yaw).save(out_dir / f"{dest_id}_{suffix}.png")
        seen.add(dest_id)
        faces = sum(len(t) for _, t in parts)
        print(f"  {path.name:24} -> {dest_id:24} {len(parts):4} meshes {faces:6} faces")

    for name in missing:
        print(f"  !! unmapped file: {name}")
    unresolved = set(MODEL_FOR.values()) - seen
    if unresolved:
        print(f"  !! no model rendered for: {sorted(unresolved)}")
    print(f"{len(seen)}/{len(MODEL_FOR)} models rendered")
