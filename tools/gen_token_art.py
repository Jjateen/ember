#!/usr/bin/env python3
"""Render the token models from tokens.3dm into flat-shaded PNGs.

Rhino files cannot be drawn by Flutter, and a 3D engine would be a large
dependency for six small pictures, so each model is rendered once here to a
sprite the app just displays. Objects in the file are unnamed, so they are
grouped into models by proximity.

Run inside the venv that has rhino3dm:
    ../.venv-3dm/bin/python tools/gen_token_art.py ../tokens.3dm
"""
import pathlib
import sys

import numpy as np
import rhino3dm as r3
from PIL import Image, ImageDraw

SIZE = 512
SS = 2
MARGIN = 0.10
CLUSTER_THRESHOLD = 2.0

LIT = np.array([226, 104, 104], float)
COLD = np.array([174, 176, 164], float)
LIGHT = np.array([0.35, 0.5, 0.79])


def collect() -> list[tuple[np.ndarray, np.ndarray, int]]:
    """Returns (vertices, triangles, object index) from cached render meshes.

    A Brep yields one mesh per face, so meshes are tagged with the object they
    came from; grouping must happen per object or a single solid splits apart.
    """
    model = r3.File3dm.Read(str(SRC))
    out = []
    for obj_index, obj in enumerate(model.Objects):
        geom = obj.Geometry
        meshes = []
        if isinstance(geom, r3.Extrusion):
            mesh = geom.GetMesh(r3.MeshType.Any)
            if mesh:
                meshes.append(mesh)
        elif isinstance(geom, r3.Brep):
            for face in geom.Faces:
                mesh = face.GetMesh(r3.MeshType.Any)
                if mesh:
                    meshes.append(mesh)
        for mesh in meshes:
            verts = np.array([[mesh.Vertices[i].X, mesh.Vertices[i].Y, mesh.Vertices[i].Z]
                              for i in range(len(mesh.Vertices))], float)
            tris = []
            for i in range(len(mesh.Faces)):
                f = mesh.Faces[i]
                tris.append([f[0], f[1], f[2]])
                if len(f) > 3 and f[3] != f[2]:
                    tris.append([f[0], f[2], f[3]])
            if len(verts) and tris:
                out.append((verts, np.array(tris, int), obj_index))
    return out


def cluster(parts):
    obj_ids = sorted({p[2] for p in parts})
    obj_centre = {}
    for oid in obj_ids:
        pts = np.vstack([v for v, _, o in parts if o == oid])
        obj_centre[oid] = pts.mean(axis=0)[:2]

    centres = np.array([obj_centre[o] for o in obj_ids])
    parent = list(range(len(obj_ids)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a in range(len(obj_ids)):
        for b in range(a + 1, len(obj_ids)):
            if np.linalg.norm(centres[a] - centres[b]) < CLUSTER_THRESHOLD:
                ra, rb = find(a), find(b)
                if ra != rb:
                    parent[rb] = ra

    by_root = {}
    for i, oid in enumerate(obj_ids):
        by_root.setdefault(find(i), []).append(oid)

    groups = []
    for root, oids in by_root.items():
        members = [i for i, p in enumerate(parts) if p[2] in set(oids)]
        x = float(np.mean([centres[obj_ids.index(o)][0] for o in oids]))
        groups.append((x, members))
    return [g for _, g in sorted(groups)]


def render(parts, idx_list, base_rgb) -> Image.Image:
    verts_all, tris_all = [], []
    offset = 0
    for i in idx_list:
        v, t = parts[i][0], parts[i][1]
        verts_all.append(v)
        tris_all.append(t + offset)
        offset += len(v)
    V = np.vstack(verts_all)
    T = np.vstack(tris_all)

    view = np.array([-1.0, -1.0, -0.85])
    view /= np.linalg.norm(view)
    right = np.cross(view, [0, 0, 1.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, view)

    sx = V @ right
    sy = -(V @ up)
    depth = V @ view

    s = SIZE * SS
    w, h = sx.max() - sx.min(), sy.max() - sy.min()
    scale = (s * (1 - 2 * MARGIN)) / max(w, h)
    px = (sx - (sx.min() + sx.max()) / 2) * scale + s / 2
    py = (sy - (sy.min() + sy.max()) / 2) * scale + s / 2

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    normals = np.cross(b - a, c - a)
    lengths = np.linalg.norm(normals, axis=1)
    keep = lengths > 1e-12
    normals[keep] /= lengths[keep, None]
    shade = np.abs(normals @ LIGHT).clip(0, 1)
    order = np.argsort(depth[T].mean(axis=1))[::-1]

    for k in order:
        if not keep[k]:
            continue
        tone = 0.42 + 0.58 * shade[k]
        rgb = tuple(int(v) for v in (base_rgb * tone).clip(0, 255))
        tri = T[k]
        d.polygon([(px[tri[0]], py[tri[0]]),
                   (px[tri[1]], py[tri[1]]),
                   (px[tri[2]], py[tri[2]])],
                  fill=rgb + (255,))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "tokens.3dm").resolve()
    root = pathlib.Path(__file__).resolve().parents[1]
    out_dir = root / "assets" / "tokens"
    out_dir.mkdir(parents=True, exist_ok=True)

    parts = collect()
    groups = cluster(parts)
    print(f"{len(parts)} meshes -> {len(groups)} models")

    for n, group in enumerate(groups, 1):
        for suffix, colour in (("lit", LIT), ("cold", COLD)):
            img = render(parts, group, colour)
            path = out_dir / f"token_{n}_{suffix}.png"
            img.save(path)
        print(f"  model {n}: {len(group)} meshes -> token_{n}_lit.png / _cold.png")
