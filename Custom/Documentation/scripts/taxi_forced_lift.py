#!/usr/bin/env python3
"""Lift gen_taxi.py's FORCED (Alliance-only, map 751) flight paths over trees and buildings.

LEADIN in gen_taxi.py was computed against the ADT heightmap only, and the Alterac /
Silverpine pines it crosses are 50-110 yd tall, so the 12 forced paths flew through
~2.2 tree crowns per 1000 yd (Blizzard's own 751 routes: 0.3). This tool:

  1. runs gen_taxi.py in dump mode against a temp copy of the CSVs, which writes the
     finished but UN-lifted forced polylines (LEADIN and FORCED_VIA applied) plus a
     fingerprint of each;
  2. reads the map-751 ground (MCVT) and every M2 doodad (MDDF + the model's bounding
     box) and WMO (MODF extents) under those polylines straight from the client archives;
  3. raises each polyline -- never lowers a point, never moves one sideways -- until the
     Catmull-Rom spline the client and server fly through it clears the obstacles;
  4. writes taxi_forced_lift.json next to this script, which gen_taxi.py applies.

Re-run whenever gen_taxi.py reports an entry as stale, then run gen_taxi.py.

    python taxi_forced_lift.py [--data K:\\WoWDecompDark\\Data]

Needs StormLib (x64 DLL, see STORMLIB below); archives are opened read-only.
"""
import argparse, ctypes, datetime, json, math, os, re, shutil, struct, subprocess, sys, tempfile
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
CSV_DIR = os.path.join(REPO, "Custom", "CSV DBC")
OUT_JSON = os.path.join(HERE, "taxi_forced_lift.json")
STORMLIB = r"K:\Dark-Chaos\Release2.3.01\x64\StormLib.dll"
MAP_ID, MAP_DIR = 751, "DCPlaguelands"
GRID = 533.3333333
RES = 128

# ---- lift parameters --------------------------------------------------------------
OBST_CLEAR = 10.0     # yd above the top of a tree / building in cruise
OBST_PAD = 3.0        # yd added to an obstacle's horizontal radius
TERRAIN_CLEAR = 20.0  # yd above the ground in cruise
END_FREE = 15.0       # yd of path at each end with no constraint (the flight master's spot)
RAMP = 100.0          # yd of path over which the clearances ramp up from END_FREE
GRADIENT = 0.6        # max climb / descent per yd the lift itself introduces
END_GRADIENT = 0.8    # max climb out of / descent into a flight master
STEP = 4.0            # yd between dense samples
WMO_CELL = 2.0        # yd, resolution of the building height grid
# A route passing right by a giant tree's trunk is bent around it instead of climbing over
# it: 402->401's custom lead-in passed 3 yd from a 221 yd Silverpine backdrop pine and would
# otherwise climb 185 yd. Only where ONE doodad needs more than NUDGE_TRIGGER of lift.
NUDGE_TRIGGER = 20.0  # yd of lift one doodad may cost before the route goes around it
NUDGE_MAX = 60.0      # yd the route may move sideways at one spot
NUDGE_SPAN = 90.0     # yd of route on each side the move is blended over
HARD = 0.7            # the final spline must keep this share of each clearance
# M2 doodads that are not solid: fog banks, bird flocks, light shafts, emitters, domes.
NOT_SOLID = re.compile(r"fog|mist|cloud|bird|smoke|steam|emitter|(^|_)fx|fx(_|$)|spell|beam|"
                       r"shaft|glow|sparkle|fire|flame|dust|leaves|butterfl|insect|firefl|wisp|"
                       r"rain|snow|weather|waterfall|splash|ripple|aura|portal|dome|sky|ray|"
                       r"lightbeam|godray|particle|bubbles|vapor|ember|haze")


# ---- StormLib (read-only) ---------------------------------------------------------
class Archives:
    """Root archives of a 3.3.5 client Data dir, highest priority first."""

    def __init__(self, data):
        lib = ctypes.WinDLL(STORMLIB)
        vp = ctypes.c_void_p
        lib.SFileOpenArchive.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                         ctypes.POINTER(vp)]
        lib.SFileOpenArchive.restype = ctypes.c_bool   # C bool, NOT BOOL
        lib.SFileOpenFileEx.argtypes = [vp, ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(vp)]
        lib.SFileOpenFileEx.restype = ctypes.c_bool
        lib.SFileGetFileSize.argtypes = [vp, ctypes.POINTER(ctypes.c_uint32)]
        lib.SFileGetFileSize.restype = ctypes.c_uint32
        lib.SFileReadFile.argtypes = [vp, vp, ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32), vp]
        lib.SFileReadFile.restype = ctypes.c_bool
        lib.SFileCloseFile.argtypes = [vp]
        lib.SFileCloseFile.restype = ctypes.c_bool
        self.lib = lib

        def prio(name):
            stem = name[:-4].lower()
            if stem == "patch":
                return (1, "")
            if stem.startswith("patch-"):
                return (2, stem[6:].rjust(2, "0"))
            return (0, {"common": "0", "common-2": "1", "expansion": "2", "lichking": "3"}.get(stem, "9"))

        names = sorted((n for n in os.listdir(data) if n.lower().endswith(".mpq")), key=prio, reverse=True)
        self.handles = []
        for n in names:
            h = vp()
            if lib.SFileOpenArchive(os.path.join(data, n), 0, 0x100, ctypes.byref(h)):  # 0x100 = read-only
                self.handles.append((n, h))
        if not self.handles:
            raise SystemExit("no archives opened in " + data)

    def read(self, name):
        name = name.replace("/", "\\").encode("latin1")
        lib = self.lib
        for _, h in self.handles:
            f = ctypes.c_void_p()
            if not lib.SFileOpenFileEx(h, name, 0, ctypes.byref(f)):
                continue
            try:
                size = lib.SFileGetFileSize(f, None)
                if size == 0xFFFFFFFF or size > 256 * 1024 * 1024:
                    continue
                buf = ctypes.create_string_buffer(size)
                got = ctypes.c_uint32()
                if lib.SFileReadFile(f, buf, size, ctypes.byref(got), None):
                    return buf.raw[:got.value]
            finally:
                lib.SFileCloseFile(f)
        return None


# ---- geometry helpers --------------------------------------------------------------
def sample_triangle(a, b, c, step):
    """Points covering a triangle at roughly `step` spacing (corners included)."""
    n = max(1, int(math.ceil(max(math.dist(a, b), math.dist(a, c), math.dist(b, c)) / step)))
    ab = [(b[k] - a[k]) / n for k in range(3)]
    ac = [(c[k] - a[k]) / n for k in range(3)]
    for i in range(n + 1):
        for j in range(n + 1 - i):
            yield (a[0] + ab[0] * i + ac[0] * j, a[1] + ab[1] * i + ac[1] * j, a[2] + ab[2] * i + ac[2] * j)


# ---- ADT: terrain, doodads, WMOs --------------------------------------------------
def chunks(d, start=0, end=None):
    p, end = start, len(d) if end is None else min(end, len(d))
    while p + 8 <= end:
        magic = d[p:p + 4][::-1].decode("latin1")
        size = struct.unpack_from("<I", d, p + 4)[0]
        yield magic, p, size
        p += 8 + size


class Tile:
    def __init__(self, data):
        self.v9 = [0.0] * (129 * 129)
        self.v8 = [0.0] * (128 * 128)
        self.doodads, self.wmos = [], []
        mmdx = mwmo = b""
        mmid = mwid = ()
        for magic, p, size in chunks(data):
            o = p + 8
            if magic == "MCNK":
                self._mcnk(data, p, size)
            elif magic == "MMDX":
                mmdx = data[o:o + size]
            elif magic == "MMID":
                mmid = struct.unpack_from("<%dI" % (size // 4), data, o)
            elif magic == "MWMO":
                mwmo = data[o:o + size]
            elif magic == "MWID":
                mwid = struct.unpack_from("<%dI" % (size // 4), data, o)
            elif magic == "MDDF":
                for i in range(size // 36):
                    nid, uid, px, py, pz, _, _, _, sc, _ = struct.unpack_from("<II6fHH", data, o + i * 36)
                    off = mmid[nid]
                    name = mmdx[off:mmdx.index(b"\0", off)].decode("latin1")
                    self.doodads.append((uid, name, 17066.666 - pz, 17066.666 - px, py, sc / 1024.0))
            elif magic == "MODF":
                for i in range(size // 64):
                    nid, uid, px, py, pz, rx, ry, rz, ax, ay, az, bx, by, bz = struct.unpack_from("<II12f", data,
                                                                                                 o + i * 64)
                    off = mwid[nid]
                    name = mwmo[off:mwmo.index(b"\0", off)].decode("latin1")
                    # extents are in placement space: world x = 17066.666 - z, y = 17066.666 - x
                    # (a WMO crossing tiles is listed by each of them: uid dedupes it)
                    self.wmos.append((uid, name, (px, py, pz, rx, ry, rz),
                                      (17066.666 - max(az, bz), 17066.666 - min(az, bz),
                                       17066.666 - max(ax, bx), 17066.666 - min(ax, bx), max(ay, by))))

    def _mcnk(self, d, p, size):
        h = p + 8
        ix, iy = struct.unpack_from("<II", d, h + 4)
        ofs_height = struct.unpack_from("<I", d, h + 20)[0]
        base = struct.unpack_from("<f", d, h + 104 + 8)[0]
        q = p + ofs_height
        if d[q:q + 4] != b"TVCM":
            q = next((sp for m, sp, _ in chunks(d, h + 128, p + 8 + size) if m == "MCVT"), None)
            if q is None:
                return
        hm = struct.unpack_from("<145f", d, q + 8)
        for y in range(9):
            for x in range(9):
                self.v9[(iy * 8 + y) * 129 + ix * 8 + x] = base + hm[y * 17 + x]
        for y in range(8):
            for x in range(8):
                self.v8[(iy * 8 + y) * 128 + ix * 8 + x] = base + hm[y * 17 + 9 + x]

    def height(self, x, y):
        """GridTerrainData::getHeightFromFloat, the server's own triangle interpolation."""
        fx, fy = RES * (32 - x / GRID), RES * (32 - y / GRID)
        xi, yi = int(fx), int(fy)
        fx, fy = fx - xi, fy - yi
        xi &= RES - 1
        yi &= RES - 1
        v9, h5 = self.v9, 2 * self.v8[xi * 128 + yi]
        if fx + fy < 1:
            if fx > fy:
                h1, h2 = v9[xi * 129 + yi], v9[(xi + 1) * 129 + yi]
                a, b, c = h2 - h1, h5 - h1 - h2, h1
            else:
                h1, h3 = v9[xi * 129 + yi], v9[xi * 129 + yi + 1]
                a, b, c = h5 - h1 - h3, h3 - h1, h1
        else:
            if fx > fy:
                h2, h4 = v9[(xi + 1) * 129 + yi], v9[(xi + 1) * 129 + yi + 1]
                a, b, c = h2 + h4 - h5, h4 - h2, h5 - h4
            else:
                h3, h4 = v9[xi * 129 + yi + 1], v9[(xi + 1) * 129 + yi + 1]
                a, b, c = h4 - h3, h3 + h4 - h5, h5 - h4
        return a * fx + b * fy + c


class World:
    CELL = 32.0

    def __init__(self, arch):
        self.arch = arch
        self.tiles = {}
        self.m2box = {}
        self.profiles = {}
        self.wmo_cache = {}
        self.cells = defaultdict(list)   # (cx, cy) -> [(kind, name, geometry...)]
        self.wmo_grid = {}               # (ix, iy) at WMO_CELL -> (highest z, name)
        self.placed = set()
        self.loaded = set()
        self.skipped = defaultdict(float)   # non-solid model -> tallest seen

    @staticmethod
    def tile_of(x, y):
        return int(32 - x / GRID), int(32 - y / GRID)

    def tile(self, gx, gy):
        if (gx, gy) not in self.tiles:
            d = self.arch.read("World\\Maps\\%s\\%s_%d_%d.adt" % (MAP_DIR, MAP_DIR, gy, gx))
            self.tiles[(gx, gy)] = Tile(d) if d else None
        return self.tiles[(gx, gy)]

    def ground(self, x, y):
        t = self.tile(*self.tile_of(x, y))
        return None if t is None else t.height(x, y)

    def bbox(self, name):
        if name not in self.m2box:
            d = self.arch.read(re.sub(r"\.(mdx|mdl)$", ".m2", name, flags=re.I))
            box = None
            if d and d[:4] == b"MD20":
                box = struct.unpack_from("<6f", d, 0xA0)
            elif d and d[:4] == b"MD21":
                box = struct.unpack_from("<6f", d, 8 + 0xA0)
            self.m2box[name] = box
        return self.m2box[name]

    def _add(self, x0, y0, x1, y1, item):
        for cx in range(int(math.floor(x0 / self.CELL)), int(math.floor(x1 / self.CELL)) + 1):
            for cy in range(int(math.floor(y0 / self.CELL)), int(math.floor(y1 / self.CELL)) + 1):
                self.cells[(cx, cy)].append(item)

    def m2_profile(self, name):
        """Radial height profile of an M2's mesh, model units: prof[i] = the highest point at
        horizontal distance i..i+1 from the model's vertical axis (None where there is none).

        A bounding cylinder is useless for conifers: Silverpine's backdrop pine
        (silverpinetree04) is 229 yd tall and 22 yd wide at the base of its crown, and a
        cylinder makes it 229 yd tall 22 yd out. Rotation-invariant, so yaw does not matter.
        """
        if name not in self.profiles:
            path = re.sub(r"\.(mdx|mdl)$", ".m2", name, flags=re.I)
            d = self.arch.read(path)
            skin = self.arch.read(path[:-3] + "00.skin")
            prof = None
            if d and d[:4] == b"MD20" and skin and skin[:4] == b"SKIN":
                nv, ov = struct.unpack_from("<II", d, 0x3C)
                verts = [struct.unpack_from("<3f", d, ov + i * 48) for i in range(nv)]
                nl, ol, nt, ot = struct.unpack_from("<IIII", skin, 4)
                look = struct.unpack_from("<%dH" % nl, skin, ol)
                tri = struct.unpack_from("<%dH" % nt, skin, ot)
                bins = {}
                for k in range(0, nt - 2, 3):
                    for x, y, z in sample_triangle(*(verts[look[tri[k + i]]] for i in range(3)), step=1.0):
                        r = int(math.hypot(x, y))
                        if z > bins.get(r, -1e9):
                            bins[r] = z
                if bins:
                    prof = [bins.get(i) for i in range(max(bins) + 1)]
            self.profiles[name] = prof
        return self.profiles[name]

    def wmo_triangles(self, name):
        """Every triangle of a WMO's groups, local space."""
        if name not in self.wmo_cache:
            tris = []
            root = self.arch.read(name)
            ngroups = 0
            if root:
                for magic, p, size in chunks(root):
                    if magic == "MOHD":
                        ngroups = struct.unpack_from("<I", root, p + 8 + 4)[0]
                        break
            for g in range(ngroups):
                d = self.arch.read(name[:-4] + "_%03d.wmo" % g)
                if not d:
                    continue
                for magic, p, size in chunks(d):
                    if magic != "MOGP":
                        continue
                    movt = movi = None
                    for sm, sp, ss in chunks(d, p + 8 + 68, p + 8 + size):
                        if sm == "MOVT":
                            movt = struct.unpack_from("<%df" % (ss // 4), d, sp + 8)
                        elif sm == "MOVI":
                            movi = struct.unpack_from("<%dH" % (ss // 2), d, sp + 8)
                    if movt and movi:
                        v = [movt[i:i + 3] for i in range(0, len(movt), 3)]
                        tris.extend((v[movi[i]], v[movi[i + 1]], v[movi[i + 2]]) for i in range(0, len(movi) - 2, 3))
            self.wmo_cache[name] = tris
        return self.wmo_cache[name]

    def load_obstacles(self, gx, gy):
        if (gx, gy) in self.loaded:
            return
        self.loaded.add((gx, gy))
        t = self.tile(gx, gy)
        if t is None:
            return
        for uid, name, x, y, z, s in t.doodads:
            if ("m2", uid) in self.placed:
                continue
            self.placed.add(("m2", uid))
            box = self.bbox(name)
            if not box:
                continue
            height = (box[5] - box[2]) * s
            base = re.split(r"[\\/]", name)[-1].lower()
            if NOT_SOLID.search(base):
                self.skipped[base] = max(self.skipped[base], height)
                continue
            if height < 4.0 or max(box[3] - box[0], box[4] - box[1]) * s < 3.0:
                continue
            prof = self.m2_profile(name)
            if prof is None:   # no mesh to read: fall back to the bounding cylinder
                prof = [box[5]] * int(math.ceil(max(abs(v) for v in (box[0], box[1], box[3], box[4]))))
            reach = len(prof) * s + OBST_PAD
            self._add(x - reach, y - reach, x + reach, y + reach, ("m2", base, x, y, z, s, prof, reach))
        for uid, name, (px, py, pz, rx, ry, rz), (x0, x1, y0, y1, top) in t.wmos:
            if ("wmo", uid) in self.placed:
                continue
            self.placed.add(("wmo", uid))
            base = re.split(r"[\\/]", name)[-1].lower()
            tris = self.wmo_triangles(name) if abs(rx) <= 10 and abs(rz) <= 10 else None
            if not tris:
                # steeply tilted or unreadable: the placement's world box (coarse, conservative)
                self._add(x0 - OBST_PAD, y0 - OBST_PAD, x1 + OBST_PAD, y1 + OBST_PAD,
                          ("box", base, x0 - OBST_PAD, y0 - OBST_PAD, x1 + OBST_PAD, y1 + OBST_PAD, top))
                continue
            # The real geometry, rasterised into a WMO_CELL height grid. A group's bounding box is
            # far too coarse: one Greymane Wall group spans 416 yd and 282 yd of mostly open air.
            # Placement transform, calibrated against MODF's own extents (median error 0.00 yd over
            # 89 placements): yaw = rotation.y + 180 deg, world x/y = (17066.666 - pz, 17066.666 - px)
            # + R(yaw) * local x/y, z = py + local z. Small tilts (<= 10 deg) are ignored.
            a = math.radians(ry + 180.0)
            ux, uy = math.cos(a), math.sin(a)
            ox, oy = 17066.666 - pz, 17066.666 - px

            def world(v):
                return ox + v[0] * ux - v[1] * uy, oy + v[0] * uy + v[1] * ux, py + v[2]

            for tri in tris:
                for wx, wy, wz in sample_triangle(*(world(v) for v in tri), step=WMO_CELL * 0.75):
                    key = (int(math.floor(wx / WMO_CELL)), int(math.floor(wy / WMO_CELL)))
                    if wz > self.wmo_grid.get(key, (-1e9,))[0]:
                        self.wmo_grid[key] = (wz, base)

    @staticmethod
    def m2_top(item, d):
        """Highest point of an M2 placement within OBST_PAD of horizontal distance d, or None."""
        _, _, _, _, oz, s, prof, reach = item
        if d > reach:
            return None
        lo = max(0, int((d - OBST_PAD) / s))
        hi = min(len(prof) - 1, int((d + OBST_PAD) / s))
        zs = [v for v in prof[lo:hi + 1] if v is not None]
        return oz + max(zs) * s if zs else None

    @staticmethod
    def m2_top_beyond(item, d):
        """Highest point of an M2 placement at horizontal distance >= d - OBST_PAD, or None.
        Monotone in d, so a gap between a tree's branches is never mistaken for open air."""
        _, _, _, _, oz, s, prof, reach = item
        zs = [v for v in prof[max(0, int((d - OBST_PAD) / s)):] if v is not None]
        return oz + max(zs) * s if zs else None

    def m2_near(self, x, y):
        return [it for it in self.cells.get((int(math.floor(x / self.CELL)), int(math.floor(y / self.CELL))), ())
                if it[0] == "m2"]

    def obstacle_top(self, x, y):
        """(top, name) of the tallest solid object within OBST_PAD of (x, y), or (None, None)."""
        best = (None, None)
        for item in self.cells.get((int(math.floor(x / self.CELL)), int(math.floor(y / self.CELL))), ()):
            if item[0] == "m2":
                name = item[1]
                top = self.m2_top(item, math.hypot(x - item[2], y - item[3]))
                if top is None:
                    continue
            else:
                _, name, x0, y0, x1, y1, top = item
                if not (x0 <= x <= x1 and y0 <= y <= y1):
                    continue
            if best[0] is None or top > best[0]:
                best = (top, name)
        r = int(math.ceil(OBST_PAD / WMO_CELL))
        cx, cy = int(math.floor(x / WMO_CELL)), int(math.floor(y / WMO_CELL))
        for i in range(cx - r, cx + r + 1):
            for j in range(cy - r, cy + r + 1):
                hit = self.wmo_grid.get((i, j))
                if hit and (best[0] is None or hit[0] > best[0]):
                    best = hit
        return best


# ---- spline ------------------------------------------------------------------------
def catmull_rom(points, per_yd=0.5):
    """Sample the uniform Catmull-Rom spline MoveSpline flies through `points`
    (end points doubled as the virtual controls, as Spline::InitCatmullRom does)."""
    P = [points[0]] + points + [points[-1]]
    out = []
    for s in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[s - 1], P[s], P[s + 1], P[s + 2]
        n = max(2, int(math.dist(p1, p2) * per_yd))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append((s - 1, tuple(0.5 * (2 * p1[i] + (-p0[i] + p2[i]) * t
                                              + (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * t2
                                              + (-p0[i] + 3 * p1[i] - 3 * p2[i] + p3[i]) * t3)
                                       for i in range(3))))
    out.append((len(points) - 1, tuple(points[-1])))
    return out


# ---- the lift ----------------------------------------------------------------------
def ramp(d):
    """0 inside END_FREE of an end, rising linearly to 1 at RAMP."""
    return min(1.0, max(0.0, (d - END_FREE) / (RAMP - END_FREE)))


def nudge(world, dense, total):
    """Bend the route sideways where it would otherwise have to climb far over something.

    Takes the worst spot in cruise (more than NUDGE_TRIGGER of lift needed), tries sideways
    bumps of up to NUDGE_MAX either way, blended over NUDGE_SPAN of route, and keeps the one
    that needs the least lift over that stretch (a yard of sideways move counts 0.2 yd of
    lift). Trying offsets rather than pushing away from each doodad handles clusters: a
    route between two pines 29 yd apart (Ambermill) is pushed both ways at once and goes
    nowhere. Moves dense samples in place; returns [(what forced it, yd moved)]."""
    kof = [ramp(min(d[0], total - d[0])) for d in dense]

    def excess(j, x, y):
        k = kof[j]
        need = -1e9
        g = world.ground(x, y)
        if g is not None:
            need = g + TERRAIN_CLEAR * k
        top, _ = world.obstacle_top(x, y)
        if top is not None and k > 0:
            need = max(need, top + OBST_CLEAR * k)
        return max(0.0, need - dense[j][3])

    moved, handled = [], []
    for _ in range(16):
        ex = [excess(j, d[1], d[2]) if kof[j] >= 1 and not any(abs(d[0] - h) < NUDGE_SPAN / 2 for h in handled)
              else 0.0 for j, d in enumerate(dense)]
        c = max(range(len(dense)), key=lambda j: ex[j])
        if ex[c] <= NUDGE_TRIGGER:
            break
        cause = world.obstacle_top(dense[c][1], dense[c][2])[1] or "ground"
        a, b = dense[max(0, c - 2)], dense[min(len(dense) - 1, c + 2)]
        n = math.hypot(b[1] - a[1], b[2] - a[2]) or 1.0
        nx, ny = -(b[2] - a[2]) / n, (b[1] - a[1]) / n
        window = [(j, 0.5 * (1 + math.cos(math.pi * abs(dense[j][0] - dense[c][0]) / NUDGE_SPAN)) * kof[j])
                  for j in range(len(dense)) if abs(dense[j][0] - dense[c][0]) < NUDGE_SPAN]
        best_cost, best_o = max(ex_j for ex_j in (excess(j, dense[j][1], dense[j][2]) for j, _ in window)), 0
        for o in range(-int(NUDGE_MAX), int(NUDGE_MAX) + 1, 3):
            if o == 0:
                continue
            cost = max(excess(j, dense[j][1] + nx * o * w, dense[j][2] + ny * o * w) for j, w in window) \
                + 0.2 * abs(o)
            if cost < best_cost:
                best_cost, best_o = cost, o
        handled.append(dense[c][0])
        if best_o == 0:
            continue
        for j, w in window:
            dense[j][1] += nx * best_o * w
            dense[j][2] += ny * best_o * w
        moved.append(("%s @%d,%d" % (cause, round(dense[c][1]), round(dense[c][2])), best_o))
    return moved


def lift(world, pts):
    pts = [tuple(p) for p in pts]
    # dense samples along the polyline: (arc length, x, y, z_orig, waypoint index or None)
    dense = []
    s = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        seg = math.dist(a, b)
        n = max(1, int(seg / STEP))
        for k in range(n):
            t = k / n
            dense.append([s + seg * t, a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t,
                          a[2] + (b[2] - a[2]) * t, i if k == 0 else None])
        s += seg
    dense.append([s, pts[-1][0], pts[-1][1], pts[-1][2], len(pts) - 1])
    total = s
    for g in {World.tile_of(d[1] + ox, d[2] + oy) for d in dense for ox in (-80, 0, 80) for oy in (-80, 0, 80)}:
        world.load_obstacles(*g)
    nudged = nudge(world, dense, total)

    def need_at(x, y, k, share):
        """Lowest z allowed over (x, y) with the clearances scaled by k * share, and why."""
        z, why = -1e9, None
        gz = world.ground(x, y)
        if gz is not None:
            z, why = gz + TERRAIN_CLEAR * k * share, "ground"
        if k > 0:
            top, name = world.obstacle_top(x, y)
            if top is not None and top + OBST_CLEAR * k * share > z:
                z, why = top + OBST_CLEAR * k * share, name
        return z, why

    def required(d, share=1.0):
        """Lowest z allowed at a dense sample (never below the path itself), and why."""
        z, why = need_at(d[1], d[2], ramp(min(d[0], total - d[0])), share)
        return (d[3], "path") if d[3] >= z else (z, why)

    # Take-off and landing may not be steeper than END_GRADIENT (never below the path itself):
    # a tall tree right beside a flight master is clipped at the very start/end instead of
    # turning the landing into a dive (Stormpike: 66 yd down over the last 26 yd).
    cap = [max(d[3], min(pts[0][2] + END_GRADIENT * d[0], pts[-1][2] + END_GRADIENT * (total - d[0])))
           for d in dense]

    def envelope(req):
        """Smallest profile >= req whose slope never exceeds GRADIENT (two passes), under cap."""
        z = [min(r, c) for r, c in zip(req, cap)]
        for i in range(1, len(z)):
            z[i] = max(z[i], z[i - 1] - GRADIENT * (dense[i][0] - dense[i - 1][0]))
        for i in range(len(z) - 2, -1, -1):
            z[i] = max(z[i], z[i + 1] - GRADIENT * (dense[i + 1][0] - dense[i][0]))
        z = [min(v, c) for v, c in zip(z, cap)]
        z[0], z[-1] = pts[0][2], pts[-1][2]   # the ends stay where gen_taxi put them
        return z

    req = [required(d)[0] for d in dense]
    clipped = sorted({required(d)[1] for d, r, c in zip(dense, req, cap) if r > c + 0.5})
    # Waypoints: every original one (its x/y IS the route) at the lifted height, plus dense
    # samples added wherever the flown spline still passes too close to something. The
    # spline is checked at its OWN x/y, not the polyline's: at a corner Catmull-Rom bulges
    # sideways over trees the straight segment never crossed. Such a spot raises the
    # requirement of the nearest dense sample, which also becomes a waypoint.
    keep = sorted({i for i, d in enumerate(dense) if d[4] is not None})
    last = len(dense) - 1
    for _ in range(300):
        z = envelope(req)
        poly = [(dense[i][1], dense[i][2], z[i]) for i in keep]
        worst = {}
        for seg, p in catmull_rom(poly):
            if seg >= len(keep) - 1:
                continue
            lo, hi = keep[seg], keep[seg + 1]
            j = min(range(lo, hi + 1), key=lambda m: (dense[m][1] - p[0]) ** 2 + (dense[m][2] - p[1]) ** 2)
            if j in (0, last) or req[j] > cap[j] + 0.5:
                continue   # an end, or inside the take-off/landing cone: cannot go higher there
            k = ramp(min(dense[j][0], total - dense[j][0]))
            short = need_at(p[0], p[1], k, HARD)[0] - p[2]
            if short > 0.5 and short > worst.get(seg, (0,))[0]:
                worst[seg] = (short, j, need_at(p[0], p[1], k, 1.0)[0])
        if not worst:
            break
        for short, j, full in worst.values():
            # a little over the full requirement: the spline sags between waypoints
            req[j] = max(req[j], full + 0.5 * short)
        keep = sorted(set(keep) | {j for _, j, _ in worst.values()})
    else:
        print("  WARNING: spline check did not settle")
    z = envelope(req)
    poly = [(dense[i][1], dense[i][2], z[i]) for i in keep]

    # report: what the flown spline clears before and after
    def clearance(points):
        worst_obj = worst_gnd = None
        for _, p in catmull_rom(points):
            dd = [None, p[0], p[1], p[2], None]
            j = min(range(len(dense)), key=lambda m: (dense[m][1] - p[0]) ** 2 + (dense[m][2] - p[1]) ** 2)
            if ramp(min(dense[j][0], total - dense[j][0])) < 1:
                continue
            top, name = world.obstacle_top(p[0], p[1])
            if top is not None and (worst_obj is None or p[2] - top < worst_obj[0]):
                worst_obj = (round(p[2] - top, 1), name)
            gz = world.ground(p[0], p[1])
            if gz is not None and (worst_gnd is None or p[2] - gz < worst_gnd):
                worst_gnd = round(p[2] - gz, 1)
        return worst_obj, worst_gnd

    before, after = clearance(pts), clearance(poly)
    causes = defaultdict(int)
    for i, d in enumerate(dense):
        r, why = required(d)
        if r > d[3] + 0.5 and why not in ("path",):
            causes[why] += 1
    stats = {"waypoints": [len(pts), len(poly)],
             "max_raise": round(max(zz - d[3] for zz, d in zip(z, dense)), 1),
             "length": round(total),
             "before": {"worst_object_clearance": before[0], "worst_ground_clearance": before[1]},
             "after": {"worst_object_clearance": after[0], "worst_ground_clearance": after[1]},
             "raised_by": dict(sorted(causes.items(), key=lambda kv: -kv[1])[:8]),
             "bent_around": nudged,
             "clipped_at_ends": clipped}
    return poly, stats


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data", default=r"K:\WoWDecompDark\Data", help="client Data directory")
    args = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix="taxi_lift_")
    try:
        for n in ("TaxiNodes", "TaxiPath", "TaxiPathNode"):
            shutil.copy(os.path.join(CSV_DIR, n + ".csv"), tmp)
        dump = os.path.join(tmp, "forced.json")
        env = dict(os.environ, DC_TAXI_CSV_DIR=tmp, DC_TAXI_DUMP_FORCED=dump)
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "gen_taxi.py")], env=env, check=True,
                       stdout=subprocess.DEVNULL)
        with open(dump, encoding="utf-8") as f:
            forced = json.load(f)["paths"]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    world = World(Archives(args.data))
    out = []
    for e in forced:
        if e["map"] != MAP_ID:
            raise SystemExit(f"forced path {e['from']}->{e['to']} is on map {e['map']}, this tool reads {MAP_ID}")
        poly, stats = lift(world, e["points"])
        out.append({"from": e["from"], "to": e["to"], "fingerprint": e["fingerprint"],
                    "points": [[round(x, 2), round(y, 2), round(z, 2)] for x, y, z in poly], "stats": stats})
        print("%d->%d  %d -> %d waypoints, raised up to %.0f yd; worst object clearance %s -> %s, "
              "ground %s -> %s" % (e["from"], e["to"], stats["waypoints"][0], stats["waypoints"][1],
                                   stats["max_raise"], stats["before"]["worst_object_clearance"],
                                   stats["after"]["worst_object_clearance"],
                                   stats["before"]["worst_ground_clearance"],
                                   stats["after"]["worst_ground_clearance"]))
        print("      raised by:", stats["raised_by"])
        print("      bent around:", stats["bent_around"], "| clipped at the ends:", stats["clipped_at_ends"])
    tall_skipped = sorted(((h, n) for n, h in world.skipped.items() if h >= 15), reverse=True)
    print("non-solid models ignored (>= 15 yd):", ", ".join("%s %.0f" % (n, h) for h, n in tall_skipped[:20]))
    params = {k: globals()[k] for k in ("OBST_CLEAR", "OBST_PAD", "TERRAIN_CLEAR", "END_FREE", "RAMP", "END_GRADIENT",
                                         "GRADIENT", "STEP", "HARD")}
    with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"generated": datetime.date.today().isoformat(), "client": args.data, "params": params,
                   "paths": out}, f, indent=1)
        f.write("\n")
    print("wrote", OUT_JSON)


if __name__ == "__main__":
    main()
