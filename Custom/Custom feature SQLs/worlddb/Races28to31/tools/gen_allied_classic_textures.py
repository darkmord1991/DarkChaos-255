#!/usr/bin/env python3
r"""
gen_allied_classic_textures.py - real retail skins for Void Elf, Lightforged and Mag'har on the classic models.

Dark Iron re-toned its parent's textures because retail's 1024x512 skins do not fit a v264 model. They
do not fit as one file, but the pieces line up, so these races keep the retail paint:

    retail skin, left half    the parent's 512x512 body, except the face block
    retail skin, right half   a head sheet, the same layout as Skin00_00_Extra on Blood Elf and Orc
    retail faceupper          one whole head sheet per face and colour

The head is the hard part. The parent draws it from the classic face block (0,320,256,192 of the
composite: FaceUpper 256x64 over FaceLower 256x128), a different unwrap of the same head. Both models
carry that head, so the mapping comes from the geometry: each parent vertex is projected onto the retail
head surface, which gives it a sheet coordinate next to its block coordinate, and every block texel is
then interpolated across the parent's triangles.

Retail has no eyeball geometry, because it draws eyes from separate textures, so the parent's two eye
islands have no surface to land on. Their disc is found on a sheet in the parent's own colours and the
same rectangle is read from the retail sheet.

The mapping proves itself: warping a sheet of the PARENT must reproduce the parent's real face block.
The tool prints that score for every model and stops below MIN_PROOF.

Draenei's Extra is not a head sheet (it holds the upper head, tentacles, hooves and tail), so Lightforged
re-tones it to the retail skin and then paints every triangle that has a retail surface back in through
the same projection. Hair is retail strands on the parent's ornament atlas, composited in DXT blocks.

Run it with a client that has the parents, then gen_races28to31.py to write the rows:
    python gen_allied_classic_textures.py --client K:\WoWDecompDark\Data --out K:\tmp\races28to31_stage
        [--race voidelf] [--preview <dir>]
"""
import argparse
import csv
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "Tier1Reskins", "tools"))
import gen_darkiron_classic_textures as dark  # noqa: E402
import stage_filestring_assets as stage  # noqa: E402

CHAR_SECTIONS = r"K:\Dark-Chaos\DarkChaos-255-Master\Custom\CSV DBC\CharSections.csv"
PROOF_DIR = r"K:\tmp\t1_proof\character\draenei\{sex}"

SPECS = {
    "voidelf": dict(
        race=29, parent="BloodElf", deploy="VoidElf", prefix="voidelf",
        retail=r"K:\tmp\t1_voidelf\character\voidelf\{sex}", stem="voidelf{sex}", model="voidelf{sex}",
        tones=range(6), faces=range(8), extra="sheet",
        hair=[r"K:\tmp\t1_voidelf\character\voidelf\male\voidelfmalehair00_%02d.blp" % c for c in range(9)]),
    "lightforged": dict(
        race=30, parent="Draenei", deploy="LightforgedDraenei", prefix="lightforgeddraenei",
        retail=r"K:\tmp\t1_lightforgeddraenei\character\lightforgeddraenei\{sex}",
        stem="lightforgeddraenei{sex}", model="lightforgeddraenei{sex}",
        tones=range(3), faces=range(10), extra="retone", skin_hue=(200.0, 300.0),
        hair=[r"K:\tmp\t1_lightforgeddraenei\character\lightforgeddraenei\lightforgeddraeneihair00_%02d.blp" % c
              for c in range(6)]),
    "maghar": dict(
        race=31, parent="Orc", deploy="MagharOrc", prefix="magharorc",
        retail=r"K:\tmp\t1_magharorc\character\orc\{sex}", stem="orc{sex}clan", model="orc{sex}_hd",
        tones=range(10), faces=range(9), extra="sheet", hair=[]),
}

RETAIL_HEAD_GEOSETS = {3201, 3202}
RETAIL_SURFACE_GEOSETS = {0, 2201, 3201, 3202}
BLOCK_W, BLOCK_H = 256, 192
BLOCK_TOP = 320
SUPERSAMPLE = 2
SHEET = 512
MIN_PROOF = 0.80
# A vertex this far from the retail head has no real counterpart, so its neighbours decide for it.
MAX_MATCH = 0.02
MAX_EXTRA_MATCH = 0.006
# Texels of retail paint spilled past each Extra triangle, so mips and filtering stay inside it.
EXTRA_BLEED = 3
# Keeps lip and eyelid vertices on their own side of a thin gap.
NORMAL_WEIGHT = 0.006
# A triangle stretched this far past the median crosses a seam in the retail unwrap.
MAX_STRETCH = 6.0
HAIR_CUT = 256
# In UV: about 8 texels of the 512 composite.
EYE_MARGIN = 0.016
PELVIS_RECT = (256, 192, 256, 128)
TORSO_RECT = (256, 0, 256, 128)
VERTEX = np.dtype([("p", "<f4", 3), ("w", "u1", 4), ("b", "u1", 4), ("n", "<f4", 3), ("uv", "<f4", 2),
                   ("uv2", "<f4", 2)])
LUMA = np.array([0.299, 0.587, 0.114])


class Mesh:
    def __init__(self, m2, skin):
        if m2[:4] == b"MD21":
            m2 = m2[8:]
        self.m2, self.skin = m2, skin
        n, o = struct.unpack_from("<II", m2, 0x50)
        self.types = [struct.unpack_from("<I", m2, o + i * 16)[0] for i in range(n)]
        n, o = struct.unpack_from("<II", m2, 0x80)
        self.lookup = struct.unpack_from("<%dh" % n, m2, o)
        n, o = struct.unpack_from("<II", m2, 0x3C)
        self.v = np.frombuffer(m2, VERTEX, n, o)
        n, o = struct.unpack_from("<II", skin, 4)
        self.vertex_list = np.frombuffer(skin, "<u2", n, o)
        n, o = struct.unpack_from("<II", skin, 12)
        self.index = np.frombuffer(skin, "<u2", n, o)
        self.sections = struct.unpack_from("<II", skin, 28)
        self.batches = struct.unpack_from("<II", skin, 36)

    def triangles(self, geosets, texture_type):
        out, done = [], set()
        for i in range(self.batches[0]):
            batch = self.batches[1] + i * 24
            submesh = struct.unpack_from("<H", self.skin, batch + 4)[0]
            texture = struct.unpack_from("<H", self.skin, batch + 16)[0]
            if submesh in done or self.types[self.lookup[texture]] != texture_type:
                continue
            section = self.sections[1] + submesh * 48
            geoset, level, _, _, start, count = struct.unpack_from("<HHHHHH", self.skin, section)
            if geoset not in geosets:
                continue
            done.add(submesh)
            first = start | (level << 16)
            out.append(self.vertex_list[self.index[first:first + count]].reshape(-1, 3))
        return np.concatenate(out) if out else np.zeros((0, 3), dtype=int)


def islands(triangles):
    """Triangle groups connected through shared vertices, largest first."""
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b, c in triangles.tolist():
        root = find(a)
        parent[find(b)] = root
        parent[find(c)] = root
    groups = {}
    for i, tri in enumerate(triangles.tolist()):
        groups.setdefault(find(tri[0]), []).append(i)
    return sorted(groups.values(), key=len, reverse=True)


def closest_on_triangles(p, a, b, c):
    """Barycentric coordinates of the point on each triangle closest to each point (Ericson, RTCD 5.1.5)."""
    ab, ac = b - a, c - a
    ap, bp, cp = p - a, p - b, p - c
    d1, d2 = (ab * ap).sum(-1), (ac * ap).sum(-1)
    d3, d4 = (ab * bp).sum(-1), (ac * bp).sum(-1)
    d5, d6 = (ab * cp).sum(-1), (ac * cp).sum(-1)
    vc, vb, va = d1 * d4 - d3 * d2, d5 * d2 - d1 * d6, d3 * d6 - d5 * d4
    denom = va + vb + vc
    denom = np.where(np.abs(denom) < 1e-12, 1e-12, denom)
    v, w = vb / denom, vc / denom

    def safe(x, y):
        y = np.where(np.abs(y) < 1e-12, 1e-12, y)
        return np.clip(x / y, 0.0, 1.0)

    edge = (vc <= 0) & (d1 >= 0) & (d3 <= 0)
    v, w = np.where(edge, safe(d1, d1 - d3), v), np.where(edge, 0.0, w)
    edge = (vb <= 0) & (d2 >= 0) & (d6 <= 0)
    v, w = np.where(edge, 0.0, v), np.where(edge, safe(d2, d2 - d6), w)
    edge = (va <= 0) & (d4 - d3 >= 0) & (d5 - d6 >= 0)
    t = safe(d4 - d3, (d4 - d3) + (d5 - d6))
    v, w = np.where(edge, 1.0 - t, v), np.where(edge, t, w)
    corner = (d1 <= 0) & (d2 <= 0)
    v, w = np.where(corner, 0.0, v), np.where(corner, 0.0, w)
    corner = (d3 >= 0) & (d4 <= d3)
    v, w = np.where(corner, 1.0, v), np.where(corner, 0.0, w)
    corner = (d6 >= 0) & (d5 <= d6)
    v, w = np.where(corner, 0.0, v), np.where(corner, 1.0, w)
    return 1.0 - v - w, v, w


def project(points, normals, mesh, triangles):
    """Sheet coordinates of each point on the retail surface, and how far away that surface was."""
    a, b, c = (mesh.v["p"][triangles[:, i]].astype(np.float64) for i in range(3))
    face_normal = np.cross(b - a, c - a)
    face_normal /= np.maximum(np.linalg.norm(face_normal, axis=1, keepdims=True), 1e-12)
    uv = mesh.v["uv"][triangles].astype(np.float64)
    out_uv, out_d = np.zeros((len(points), 2)), np.zeros(len(points))
    for start in range(0, len(points), 64):
        p = points[start:start + 64, None, :]
        u, v, w = closest_on_triangles(p, a[None], b[None], c[None])
        hit = u[..., None] * a[None] + v[..., None] * b[None] + w[..., None] * c[None]
        distance = np.linalg.norm(p - hit, axis=-1)
        facing = (normals[start:start + 64, None, :] * face_normal[None]).sum(-1)
        best = (distance + NORMAL_WEIGHT * (1.0 - facing)).argmin(1)
        rows = np.arange(len(best))
        ub, vb, wb = u[rows, best], v[rows, best], w[rows, best]
        tri_uv = uv[best]
        out_uv[start:start + 64] = ub[:, None] * tri_uv[:, 0] + vb[:, None] * tri_uv[:, 1] + wb[:, None] * tri_uv[:, 2]
        out_d[start:start + 64] = distance[rows, best]
    out_uv[:, 0] = (out_uv[:, 0] - 0.5) * 2.0
    return out_uv, out_d


def rasterise(triangles, block_uv, sheet, width, height, map_u, map_v, drawn):
    """Interpolates sheet coordinates across triangles laid out in block texels."""
    for tri, target, source in zip(triangles, block_uv, sheet):
        lo = np.floor(target.min(0)).astype(int)
        hi = np.ceil(target.max(0)).astype(int)
        x0, y0, x1, y1 = max(lo[0], 0), max(lo[1], 0), min(hi[0], width - 1), min(hi[1], height - 1)
        if x1 < x0 or y1 < y0:
            continue
        basis = np.array([target[1] - target[0], target[2] - target[0]]).T
        if abs(np.linalg.det(basis)) < 1e-6:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        offset = np.stack([xs + 0.5, ys + 0.5], -1) - target[0]
        weights = np.linalg.solve(basis, offset[..., None])[..., 0]
        l1, l2 = weights[..., 0], weights[..., 1]
        l0 = 1.0 - l1 - l2
        inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        map_u[y0:y1 + 1, x0:x1 + 1][inside] = (l0 * source[0, 0] + l1 * source[1, 0] + l2 * source[2, 0])[inside]
        map_v[y0:y1 + 1, x0:x1 + 1][inside] = (l0 * source[0, 1] + l1 * source[1, 1] + l2 * source[2, 1])[inside]
        drawn[y0:y1 + 1, x0:x1 + 1][inside] = True


def spread(map_u, map_v, drawn):
    """Fills undrawn texels from their neighbours, so mips never pull in black."""
    known = drawn.copy()
    while not known.all():
        grown = known.copy()
        total_u, total_v, count = np.zeros_like(map_u), np.zeros_like(map_v), np.zeros_like(map_u)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            mask = np.roll(known, (dy, dx), (0, 1))
            total_u += np.roll(map_u, (dy, dx), (0, 1)) * mask
            total_v += np.roll(map_v, (dy, dx), (0, 1)) * mask
            count += mask
        ring = ~known & (count > 0)
        if not ring.any():
            break
        map_u[ring] = total_u[ring] / count[ring]
        map_v[ring] = total_v[ring] / count[ring]
        grown[ring] = True
        known = grown


def sample(image, map_u, map_v):
    pixels = np.asarray(image.convert("RGB"), dtype=np.float64)
    height, width = pixels.shape[:2]
    x = np.clip(map_u * width - 0.5, 0, width - 1.001)
    y = np.clip(map_v * height - 0.5, 0, height - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    out = (pixels[y0, x0] * (1 - fx) * (1 - fy) + pixels[y0, x0 + 1] * fx * (1 - fy)
           + pixels[y0 + 1, x0] * (1 - fx) * fy + pixels[y0 + 1, x0 + 1] * fx * fy)
    return np.clip(out, 0, 255)


def normalised(window, weight):
    window = window - (window * weight).sum((-2, -1), keepdims=True) / weight.sum()
    return window / np.maximum(np.sqrt((window * window * weight).sum((-2, -1), keepdims=True)), 1e-6)


def find_disc(block, box, sheet):
    """Where the block's eye disc sits on a sheet in the same colours, as (x, y, width, height) in sheet texels."""
    size = 28
    x0, y0, x1, y1 = box
    template = Image.fromarray(block[y0:y1, x0:x1].astype(np.uint8)).resize((size, size), Image.Resampling.BILINEAR)
    grid = (np.indices((size, size)) + 0.5) / size - 0.5
    weight = np.exp(-(grid ** 2).sum(0) * 6.0)
    template = normalised(np.asarray(template, dtype=np.float64) @ LUMA, weight)
    best = (-2.0, None)
    for scale in np.linspace(1.2, 4.2, 25):
        span = (x1 - x0) * scale
        factor = size / span
        small = sheet.convert("L").resize((max(int(SHEET * factor), size + 1),) * 2, Image.Resampling.BILINEAR)
        windows = np.lib.stride_tricks.sliding_window_view(np.asarray(small, dtype=np.float64), (size, size))
        score = (normalised(windows, weight) * template * weight).sum((-2, -1))
        y, x = np.unravel_index(score.argmax(), score.shape)
        if score[y, x] > best[0]:
            ratio = (y1 - y0) / (x1 - x0)
            best = (float(score[y, x]), (x / factor, y / factor, span, span * ratio))
    return best


class Warp:
    """Sheet coordinates for every texel of the classic face block."""

    def __init__(self, spec, sex, archives, parent_sheet):
        title = sex.capitalize()
        base = "Character\\%s\\%s\\%s%s" % (spec["parent"], title, spec["parent"], title)
        self.parent = Mesh(stage.read(archives, base + ".m2"), stage.read(archives, base + "00.skin"))
        folder = spec["retail"].format(sex=sex)
        model = spec["model"].format(sex=sex)
        retail = Mesh(open(os.path.join(folder, model + ".m2"), "rb").read(),
                      open(os.path.join(folder, model + "00.skin"), "rb").read())

        block = self.parent.triangles({0}, 1)
        uv = self.parent.v["uv"][block]
        block = block[(uv[:, :, 0].max(1) < 0.5) & (uv[:, :, 1].min(1) > 0.62)]
        groups = islands(block)
        eyes = self.eye_islands(block, groups)
        if not eyes:
            raise SystemExit("%s %s: no pair of eye islands" % (spec["parent"], sex))
        main = np.concatenate([block[g] for i, g in enumerate(groups) if i not in eyes])
        self.eye_triangles = block[groups[eyes[0]]]

        head = retail.triangles(RETAIL_HEAD_GEOSETS, 1)
        head = head[islands(head)[0]]
        vertices = np.unique(main)
        points = self.parent.v["p"][vertices].astype(np.float64)
        normals = self.parent.v["n"][vertices].astype(np.float64)
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
        coords, distance = project(points, normals, retail, head)
        self.match = (float(distance.mean()), float(np.percentile(distance, 95)))
        self.fix_outliers(vertices, main, coords, distance > MAX_MATCH)

        lookup = np.full(len(self.parent.v), -1)
        lookup[vertices] = np.arange(len(vertices))
        target = (self.parent.v["uv"][main] * SHEET - [0.0, BLOCK_TOP]) * SUPERSAMPLE
        source = coords[lookup[main]]
        stretch = self.stretch(target, source * SHEET)
        keep = stretch < np.median(stretch) * MAX_STRETCH
        self.dropped = int((~keep).sum())

        width, height = BLOCK_W * SUPERSAMPLE, BLOCK_H * SUPERSAMPLE
        self.map_u, self.map_v = np.zeros((height, width)), np.zeros((height, width))
        self.drawn = np.zeros((height, width), dtype=bool)
        rasterise(main[keep], target[keep], source[keep], width, height, self.map_u, self.map_v, self.drawn)
        self.coverage = float(self.drawn.mean())
        self.head_map = (self.map_u.copy(), self.map_v.copy(), self.drawn.copy())

        texels = self.parent.v["uv"][self.eye_triangles].reshape(-1, 2) * SHEET - [0.0, BLOCK_TOP]
        lo, hi = np.floor(texels.min(0)).astype(int), np.ceil(texels.max(0)).astype(int)
        self.disc_box = (lo[0], lo[1], hi[0], hi[1])
        self.parent_sheet = parent_sheet
        self.extra_map = self.map_extra(retail) if spec["extra"] == "retone" else None

    def map_extra(self, retail):
        """Composite coordinates for the Extra triangles that have a retail surface to land on.

        Draenei draws its upper head, neck, hooves and tail from Extra. Tentacles and the like find nothing
        close enough and keep their re-toned colour.
        """
        triangles = self.parent.triangles({0}, 8)
        vertices = np.unique(triangles)
        points = self.parent.v["p"][vertices].astype(np.float64)
        normals = self.parent.v["n"][vertices].astype(np.float64)
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
        coords, distance = project(points, normals, retail, retail.triangles(RETAIL_SURFACE_GEOSETS, 1))
        coords[:, 0] = coords[:, 0] / 2.0 + 0.5
        lookup = np.full(len(self.parent.v), -1)
        lookup[vertices] = np.arange(len(vertices))
        close = (distance[lookup[triangles]] < MAX_EXTRA_MATCH).all(1)
        target = self.parent.v["uv"][triangles] * SHEET
        source = coords[lookup[triangles]]
        stretch = self.stretch(target, source * [SHEET * 2, SHEET])
        keep = close & (stretch < np.median(stretch[close]) * MAX_STRETCH)
        map_u, map_v = np.zeros((SHEET, SHEET)), np.zeros((SHEET, SHEET))
        drawn = np.zeros((SHEET, SHEET), dtype=bool)
        rasterise(triangles[keep], target[keep], source[keep], SHEET, SHEET, map_u, map_v, drawn)
        self.extra_share = float(keep.mean())
        return map_u, map_v, drawn

    def paint_extra(self, extra, skin):
        """Lays the retail skin over the re-toned Extra wherever a triangle reached it."""
        map_u, map_v, drawn = self.extra_map
        pixels = np.asarray(extra.convert("RGB"), dtype=np.float64).copy()
        painted = sample(skin, map_u, map_v)
        grown = drawn.copy()
        for _ in range(EXTRA_BLEED):
            spill = np.zeros_like(grown)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                spill |= np.roll(grown, (dy, dx), (0, 1))
            ring = spill & ~grown
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                source = np.roll(grown, (dy, dx), (0, 1)) & ring
                painted[source] = np.roll(painted, (dy, dx), (0, 1))[source]
            grown |= spill
        pixels[grown] = painted[grown]
        return Image.fromarray(pixels.astype(np.uint8), "RGB")

    def eye_islands(self, block, groups):
        """The largest mirrored pair of small islands, plus anything else sitting inside that disc."""
        centres = [self.parent.v["p"][block[g]].reshape(-1, 3).mean(0) for g in groups]
        texels = [self.parent.v["uv"][block[g]].reshape(-1, 2) for g in groups]
        for i in range(1, len(groups)):
            for j in range(i + 1, len(groups)):
                a, b = centres[i], centres[j]
                if abs(a[1]) > 0.01 and abs(a[1] + b[1]) < 0.006 and abs(a[2] - b[2]) < 0.006:
                    low, high = texels[i].min(0) - EYE_MARGIN, texels[i].max(0) + EYE_MARGIN
                    return [k for k in range(1, len(groups))
                            if ((texels[k].mean(0) > low) & (texels[k].mean(0) < high)).all()]
        return []

    @staticmethod
    def stretch(target, source):
        def area(t):
            a, b = t[:, 1] - t[:, 0], t[:, 2] - t[:, 0]
            return np.abs(a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0])
        return np.sqrt(area(source) / np.maximum(area(target), 1e-6))

    @staticmethod
    def fix_outliers(vertices, triangles, coords, bad):
        """Solves unmatched vertices from their mesh neighbours."""
        if not bad.any():
            return
        lookup = {int(v): i for i, v in enumerate(vertices)}
        neighbours = [set() for _ in vertices]
        for tri in triangles.tolist():
            ids = [lookup[v] for v in tri]
            for i in ids:
                neighbours[i].update(ids)
        targets = np.flatnonzero(bad)
        known = ~bad
        for i in targets:
            coords[i] = coords[known].mean(0)
        for _ in range(200):
            for i in targets:
                around = [j for j in neighbours[i] if j != i]
                coords[i] = coords[around].mean(0)

    def set_disc(self, block_rgb):
        score, rect = find_disc(block_rgb, self.disc_box, self.parent_sheet)
        self.disc_score, self.disc_rect = score, rect
        x0, y0, x1, y1 = self.disc_box
        fx, fy = rect[2] / (x1 - x0), rect[3] / (y1 - y0)
        map_u, map_v, drawn = (a.copy() for a in self.head_map)
        scale = SUPERSAMPLE
        for y in range(y0 * scale, y1 * scale):
            for x in range(x0 * scale, x1 * scale):
                if drawn[y, x]:
                    continue
                map_u[y, x] = (rect[0] + (x / scale - x0) * fx) / SHEET
                map_v[y, x] = (rect[1] + (y / scale - y0) * fy) / SHEET
                drawn[y, x] = True
        spread(map_u, map_v, drawn)
        self.map_u, self.map_v = map_u, map_v

    def block(self, sheet):
        """A head sheet laid out as the classic face block."""
        pixels = sample(sheet, self.map_u, self.map_v).astype(np.uint8)
        return Image.fromarray(pixels, "RGB").resize((BLOCK_W, BLOCK_H), Image.Resampling.BOX)


def decode_rgba(path):
    data = open(path, "rb").read()
    encoding, alpha_depth, alpha_type = data[8], data[9], data[10]
    width, height = struct.unpack("<II", data[12:20])
    offset = struct.unpack("<I", data[20:24])[0]
    size = struct.unpack("<I", data[84:88])[0]
    if encoding == 2:
        mode = 1 if alpha_depth == 0 else {1: 2, 7: 3}.get(alpha_type, 1)
        return Image.frombytes("RGBA", (width, height), data[offset:offset + size], "bcn", mode)
    return dark.blp_decode(path).convert("RGBA")


def composite_hair(strands, parent):
    """Retail strands on the parent's ornament atlas, block by block, so neither side is re-encoded."""
    width, height = struct.unpack("<II", parent[12:20])
    if parent[8] != 2 or parent[9] != 0 or (width, height) != struct.unpack("<II", strands[12:20]):
        raise SystemExit("expected DXT1 parent hair of the same size")
    colour_blocks = strands[9] == 8
    block_size = 16 if colour_blocks else 8
    out = bytearray(parent)
    offsets = struct.unpack("<16I", parent[20:84])
    sizes = struct.unpack("<16I", parent[84:148])
    source_offsets = struct.unpack("<16I", strands[20:84])
    for mip in range(16):
        if not sizes[mip]:
            break
        mip_w, mip_h = max(width >> mip, 1), max(height >> mip, 1)
        columns, rows = (mip_w + 3) // 4, (mip_h + 3) // 4
        cut = (HAIR_CUT >> mip) // 4
        for row in range(rows):
            for column in range(cut):
                at = source_offsets[mip] + (row * columns + column) * block_size
                block = bytearray(strands[at + block_size - 8:at + block_size])
                c0, c1 = struct.unpack_from("<HH", block, 0)
                if c0 < c1:
                    # DXT5 colour blocks are always four-colour; DXT1 reads c0 <= c1 as three-colour.
                    bits = struct.unpack_from("<I", block, 4)[0] ^ 0x55555555
                    struct.pack_into("<HHI", block, 0, c1, c0, bits)
                out[offsets[mip] + (row * columns + column) * 8:offsets[mip] + (row * columns + column) * 8 + 8] = block
    return bytes(out)


def strand_colour(image):
    pixels = np.asarray(image.convert("RGB"), dtype=np.float64)[:, :180]
    return pixels.reshape(-1, 3).mean(0)


def parent_hair_colours(spec, archives, rows):
    """Colour id to (mean strand colour, file bytes), for matching beards, scalps and the atlas to new hair."""
    colours = {}
    for row in rows:
        if row["RaceID"] != str(spec["id"]) or row["BaseSection"] != "3" or not row["TextureName_1"]:
            continue
        colour = int(row["ColorIndex"])
        if colour in colours or row["Flags"] != "17":
            continue
        path = os.path.join(os.environ.get("TEMP", "."), "hair_probe.blp")
        data = stage.read(archives, row["TextureName_1"])
        open(path, "wb").write(data)
        colours[colour] = (strand_colour(decode_rgba(path)), data)
    return colours


def retone_skin(image, tone, average, hue):
    """Moves skin-coloured pixels to the tone, softly, and leaves hooves, teeth and metal alone."""
    pixels = np.asarray(image.convert("RGB"), dtype=np.float64)
    h, sat, val = dark._hsv(pixels)
    low, high = hue
    weight = np.clip((h - low) / 12.0, 0, 1) * np.clip((high - h) / 12.0, 0, 1)
    weight *= np.clip((sat - 0.06) / 0.1, 0, 1) * np.clip((val - 0.08) / 0.1, 0, 1)
    moved = np.asarray(dark.retone(image, tone, average), dtype=np.float64)
    return Image.fromarray((pixels + (moved - pixels) * weight[..., None]).astype(np.uint8), "RGB")


def flatten(under, over):
    """Lays a retail underwear texture over the body it sits on: the parent's are opaque, retail's are not."""
    base = under.convert("RGBA")
    base.alpha_composite(over.resize(base.size))
    return base.convert("RGB")


def bake_sex(spec, key, sex, archives, rows, out, preview):
    title = sex.capitalize()
    race = spec["parent"]
    folder = spec["retail"].format(sex=sex)
    stem = spec["stem"].format(sex=sex)
    prefix = spec["prefix"] + sex
    target = os.path.join(out, "Character", spec["deploy"], title)
    os.makedirs(target, exist_ok=True)

    def from_client(name):
        path = os.path.join(os.environ.get("TEMP", "."), "client_probe.blp")
        open(path, "wb").write(stage.read(archives, "Character\\%s\\%s\\%s%s%s" % (race, title, race, title, name)))
        return dark.blp_decode(path)

    extra = from_client("Skin00_00_Extra.blp")
    upper, lower = from_client("FaceUpper00_00.blp"), from_client("FaceLower00_00.blp")
    truth = np.concatenate([np.asarray(upper, dtype=np.float64), np.asarray(lower, dtype=np.float64)])
    if spec["extra"] == "sheet":
        reference = extra
    else:
        whole = dark.blp_decode(os.path.join(PROOF_DIR.format(sex=sex), "draenei%sskin00_00_hd.blp" % sex))
        reference = whole.crop((SHEET, 0, SHEET * 2, SHEET))

    warp = Warp(spec, sex, archives, reference)
    warp.set_disc(truth)
    got = sample(reference, warp.head_map[0], warp.head_map[1])
    got = np.asarray(Image.fromarray(got.astype(np.uint8)).resize((BLOCK_W, BLOCK_H), Image.Resampling.BOX),
                     dtype=np.float64)
    mask = np.asarray(Image.fromarray(warp.head_map[2]).resize((BLOCK_W, BLOCK_H), Image.Resampling.NEAREST))
    proof = float(np.corrcoef(got[mask] @ LUMA, truth[mask] @ LUMA)[0, 1])
    error = float(np.abs(got[mask] - truth[mask]).mean())
    print("%s %-6s match %.1f mm (p95 %.1f), block %.0f%%, dropped %d, proof %.3f, error %.1f, disc %.2f at %s"
          % (key, sex, warp.match[0] * 1000, warp.match[1] * 1000, warp.coverage * 100, warp.dropped, proof, error,
             warp.disc_score, tuple(round(x) for x in warp.disc_rect)))
    if warp.extra_map:
        print("    Extra triangles painted from retail: %.0f%%" % (warp.extra_share * 100))
    if proof < MIN_PROOF:
        raise SystemExit("%s %s: the head mapping fails its proof (%.3f)" % (key, sex, proof))

    has_torso = any(r["RaceID"] == str(spec["id"]) and r["SexID"] == ("0" if sex == "male" else "1")
                    and r["BaseSection"] == "4" and r["TextureName_2"] for r in rows)
    average = dark.source_avg_lum(extra)
    sheets = []
    for tone in spec["tones"]:
        cc = "%02d" % tone
        retail_skin = dark.blp_decode(os.path.join(folder, "%sskin00_%s.blp" % (stem, cc)))
        if retail_skin.size != (SHEET * 2, SHEET):
            raise SystemExit("unexpected skin size %s" % (retail_skin.size,))
        body = retail_skin.crop((0, 0, SHEET, SHEET))
        head = retail_skin.crop((SHEET, 0, SHEET * 2, SHEET))
        body.paste(warp.block(head), (0, BLOCK_TOP))
        dark.blp_write_palettised(body, os.path.join(target, "%sskin00_%s.blp" % (prefix, cc)))
        if spec["extra"] == "sheet":
            sheet = head
        else:
            # The middle of the face: the sheet's own background is white.
            colour = np.asarray(warp.block(head), dtype=np.float64)[20:60, 70:190].reshape(-1, 3).mean(0)
            sheet = warp.paint_extra(retone_skin(extra, colour, average, spec["skin_hue"]), retail_skin)
        dark.blp_write_palettised(sheet, os.path.join(target, "%sskin00_%s_Extra.blp" % (prefix, cc)))

        for kind, rect in (("pelvis", PELVIS_RECT), ("torso", TORSO_RECT)):
            if kind == "torso" and not has_torso:
                continue
            over = decode_rgba(os.path.join(folder, "%snaked%sskin00_%s.blp" % (stem, kind, cc)))
            x, y, w, h = rect
            flat = flatten(body.crop((x, y, x + w, y + h)), over)
            dark.blp_write_palettised(flat, os.path.join(target, "%snaked%sskin00_%s.blp" % (prefix, kind, cc)))

        for face in spec["faces"]:
            vv = "%02d" % face
            face_sheet = dark.blp_decode(os.path.join(folder, "%sfaceupper%s_%s.blp" % (stem, vv, cc)))
            block = warp.block(face_sheet)
            dark.blp_write_palettised(block.crop((0, 0, BLOCK_W, 64)),
                                      os.path.join(target, "%sfaceupper%s_%s.blp" % (prefix, vv, cc)))
            dark.blp_write_palettised(block.crop((0, 64, BLOCK_W, BLOCK_H)),
                                      os.path.join(target, "%sfacelower%s_%s.blp" % (prefix, vv, cc)))
            if preview and face == spec["faces"][0]:
                sheets.append(block)
    if preview:
        canvas = Image.new("RGB", (BLOCK_W * len(sheets), BLOCK_H * 2), (40, 0, 40))
        canvas.paste(Image.fromarray(truth.astype(np.uint8)), (0, 0))
        canvas.paste(Image.fromarray(got.astype(np.uint8)), (BLOCK_W, 0))
        for i, block in enumerate(sheets):
            canvas.paste(block, (i * BLOCK_W, BLOCK_H))
        canvas.save(os.path.join(preview, "%s_%s.png" % (key, sex)))
    return has_torso


def bake_hair(spec, archives, rows, out):
    colours = parent_hair_colours(spec, archives, rows)
    mapping = {}
    target = os.path.join(out, "Character", spec["deploy"])
    os.makedirs(target, exist_ok=True)
    for colour, path in enumerate(spec["hair"]):
        strands = open(path, "rb").read()
        mean = strand_colour(decode_rgba(path))

        def distance(candidate):
            return float(((colours[candidate][0] - mean) ** 2).sum())

        mapping[colour] = min(colours, key=distance)
        # Some parent colours are custom recolours in another format, which cannot take the block copy.
        atlases = [c for c in colours if colours[c][1][8:10] == b"\x02\x00"
                   and colours[c][1][12:20] == strands[12:20]]
        with open(os.path.join(target, "%shair00_%02d.blp" % (spec["prefix"], colour)), "wb") as f:
            f.write(composite_hair(strands, colours[min(atlases, key=distance)][1]))
    return mapping


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--client", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--race", choices=sorted(SPECS), action="append")
    parser.add_argument("--preview")
    args = parser.parse_args()

    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
    archives = stage.open_archives(args.client)
    with open(CHAR_SECTIONS, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    manifest_path = os.path.join(args.out, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    ids = {"BloodElf": 10, "Draenei": 11, "Orc": 2}
    for key in args.race or sorted(SPECS):
        spec = SPECS[key]
        spec["id"] = ids[spec["parent"]]
        entry = dict(race=spec["race"], parent=spec["id"], deploy=spec["deploy"], prefix=spec["prefix"],
                     tones=len(spec["tones"]), faces=len(spec["faces"]), hair=len(spec["hair"]))
        for sex in ("male", "female"):
            entry["torso_" + sex] = bake_sex(spec, key, sex, archives, rows, args.out, args.preview)
        entry["hair_map"] = bake_hair(spec, archives, rows, args.out)
        manifest[key] = entry
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
