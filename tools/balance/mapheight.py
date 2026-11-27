"""Terrain height / liquid level from the server's maps/*.map files (port of GridTerrainData.cpp, version 9).
Usage: import mapheight as mh; mh.height(37, x, y), mh.liquid(37, x, y). calibrate() against spawns first if unsure.
Terrain only: WMO/M2 floors (vmaps) are not included."""
import os
import struct

SIZE = 533.3333
RES = 128
MAPDIR = "K:/Dark-Chaos/Server/data/maps"
HOLE_H = (0x1111, 0x2222, 0x4444, 0x8888)
HOLE_V = (0x000F, 0x00F0, 0x0F00, 0xF000)
_cache = {}
SWAP = False  # set by calibrate(): file name order


def _load(mapid, gx, gy):
    key = (mapid, gx, gy)
    if key in _cache:
        return _cache[key]
    a, b = (gy, gx) if SWAP else (gx, gy)
    path = os.path.join(MAPDIR, "%03d%02d%02d.map" % (mapid, a, b))
    if not os.path.exists(path):
        _cache[key] = None
        return None
    data = open(path, "rb").read()
    (magic, ver, build, area_off, area_sz, h_off, h_sz, l_off, l_sz, hole_off, hole_sz) = struct.unpack_from(
        "<4sIIIIIIIIII", data, 0)
    assert magic == b"MAPS" and ver == 9, (path, magic, ver)
    t = {"holes": None, "liq": None}
    fourcc, flags, gh, gmax = struct.unpack_from("<4sIff", data, h_off)
    p = h_off + 16
    t["gh"] = gh
    if flags & 1:
        t["kind"] = "flat"
    elif flags & 2:
        t["kind"] = "int"
        t["v9"] = struct.unpack_from("<%dH" % (129 * 129), data, p)
        p += 129 * 129 * 2
        t["v8"] = struct.unpack_from("<%dH" % (128 * 128), data, p)
        t["mult"] = (gmax - gh) / 65535
    elif flags & 4:
        t["kind"] = "int"
        t["v9"] = struct.unpack_from("<%dB" % (129 * 129), data, p)
        p += 129 * 129
        t["v8"] = struct.unpack_from("<%dB" % (128 * 128), data, p)
        t["mult"] = (gmax - gh) / 255
    else:
        t["kind"] = "float"
        t["v9"] = struct.unpack_from("<%df" % (129 * 129), data, p)
        p += 129 * 129 * 4
        t["v8"] = struct.unpack_from("<%df" % (128 * 128), data, p)
    if hole_off and hole_sz:
        t["holes"] = struct.unpack_from("<256H", data, hole_off)
    if l_off and l_sz:
        lf, lflags, lflags2, ltype, offx, offy, w, h, level = struct.unpack_from("<4sBBHBBBBf", data, l_off)
        q = l_off + 16
        liq = {"level": level, "map": None, "offx": offx, "offy": offy, "w": w, "h": h}
        if not (lflags & 1):
            q += 256 * 2 + 256
        if not (lflags & 2):
            liq["map"] = struct.unpack_from("<%df" % (w * h), data, q)
        t["liq"] = liq
    _cache[key] = t
    return t


def _tile(mapid, x, y):
    return _load(mapid, int(32 - x / SIZE), int(32 - y / SIZE))


def height(mapid, x, y):
    t = _tile(mapid, x, y)
    if not t:
        return None
    if t["kind"] == "flat":
        return t["gh"]
    fx = RES * (32 - x / SIZE)
    fy = RES * (32 - y / SIZE)
    xi, yi = int(fx), int(fy)
    fx -= xi
    fy -= yi
    xi &= RES - 1
    yi &= RES - 1
    if t["holes"]:
        hole = t["holes"][(xi // 8) * 16 + (yi // 8)]
        if hole & HOLE_H[(yi - (yi // 8) * 8) // 2] & HOLE_V[xi % 8 // 2]:
            return None
    v9, v8 = t["v9"], t["v8"]
    h1 = v9[xi * 129 + yi]
    h2 = v9[(xi + 1) * 129 + yi]
    h3 = v9[xi * 129 + yi + 1]
    h4 = v9[(xi + 1) * 129 + yi + 1]
    h5 = 2 * v8[xi * 128 + yi]
    if fx + fy < 1:
        if fx > fy:
            a, b, c = h2 - h1, h5 - h1 - h2, h1
        else:
            a, b, c = h5 - h1 - h3, h3 - h1, h1
    else:
        if fx > fy:
            a, b, c = h2 + h4 - h5, h4 - h2, h5 - h4
        else:
            a, b, c = h4 - h3, h3 + h4 - h5, h5 - h4
    z = a * fx + b * fy + c
    if t["kind"] == "int":
        z = z * t["mult"] + t["gh"]
    return z


def liquid(mapid, x, y):
    t = _tile(mapid, x, y)
    if not t or not t["liq"]:
        return None
    lq = t["liq"]
    if lq["map"] is None:
        return lq["level"]
    fx = RES * (32 - x / SIZE)
    fy = RES * (32 - y / SIZE)
    cx = (int(fx) & (RES - 1)) - lq["offy"]
    cy = (int(fy) & (RES - 1)) - lq["offx"]
    if cx < 0 or cx >= lq["h"] or cy < 0 or cy >= lq["w"]:
        return None
    return lq["map"][cx * lq["w"] + cy]


def calibrate(points, mapid):
    """points: [(x, y, z)]; picks the file-name order whose terrain matches the spawn z best."""
    global SWAP
    best = None
    for swap in (False, True):
        SWAP = swap
        _cache.clear()
        errs = sorted(abs(height(mapid, x, y) - z) for x, y, z in points if height(mapid, x, y) is not None)
        med = errs[len(errs) // 2] if errs else 1e9
        if best is None or med < best[0]:
            best = (med, swap, len(errs))
    SWAP = best[1]
    _cache.clear()
    return best
