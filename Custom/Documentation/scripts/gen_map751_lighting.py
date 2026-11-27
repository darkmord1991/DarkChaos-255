#!/usr/bin/env python3
"""Give map 751 its per-zone terrain lighting, transplanted from the Cata client.

Map 751 had **2** Light rows against map 750's 79, so every zone fell back to the
map-wide default: no per-zone fog, no colour grading, and no skybox anywhere.

Map 751 is a coordinate-preserving copy of Eastern Kingdoms (continent 0) -- proven
independently when TrinityCore's Silverpine waypoint path transposed onto it 1:1 --
so a Cata continent-0 Light row moves across with ContinentID 0 -> 751 and its
coordinates untouched. Same method map 750 got from Kalimdor.

Light.dbc positions are ADT-space x36 with the axes SWAPPED relative to the field
names (calibrated on Dalaran during the map-750 work):
    worldX = 17066.666 - dbcZ/36        worldY = 17066.666 - dbcX/36
    worldZ = dbcY/36                    radius = falloff/36
Footprint comes from the WDT's MAIN chunk rather than a bounding rectangle, and a
light is kept when it reaches ANY present tile -- radii run to 1500 yd and a light
may legitimately be centred off-map.

What transplants:
  * Light            -- one row per in-footprint Cata light, ContinentID -> 751
  * LightParams      -- Cata has 10 fields, ours 9: the trailing `Flags` is dropped.
                        Params are matched to ours by CONTENT (the param row minus
                        its id, plus all 18 LightIntBand and 6 LightFloatBand rows
                        minus theirs) so a param we already share is reused instead
                        of cloned. Only unmatched params are minted.
  * LightIntBand / LightFloatBand -- written at the formula addresses the engine
                        resolves: IntBand.ID = (param-1)*18 + type+1,
                        FloatBand.ID = (param-1)*6 + type+1. A new param id is only
                        usable if BOTH band ranges are also free.
  * LightSkybox      -- nothing to add. The only skybox in this footprint is
                        StratholmeSkybox, already our id 1, and the model ships
                        stock in common-2.MPQ (the client resolves .mdx -> .m2).

Appends to the CSVs; recompile and deploy with the usual DBC pipeline. Note the
map-750 trap: light tooling has previously edited Custom/DBCs/*.dbc in place while
leaving the CSVs behind, which a later recompile then silently reverts. All five
light tables were verified CSV/DBC-identical before this ran.
"""
import struct, os, csv, shutil, collections

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.environ.get("SCRATCH", "")
CATA = os.path.join(SP, "lt", "cata")
WDT = os.path.join(SP, "lt", "DCPlaguelands.wdt")
CSVDIR = os.path.normpath(os.path.join(HERE, "..", "..", "CSV DBC"))
TILE = 1600.0 / 3.0
DEST_MAP = 751
SRC_CONTINENT = 0


def dbc(p):
    d = open(p, "rb").read()
    m, rc, fc, rs, ss = struct.unpack_from("<4sIIII", d, 0)
    return [struct.unpack_from("<%dI" % fc, d, 20 + i * rs) for i in range(rc)], fc


def f32(w):
    return struct.unpack("<f", struct.pack("<I", w))[0]


def fmt(v):
    if isinstance(v, float):
        s = "%.7g" % v
        return "0" if s in ("0", "-0") else s
    return str(v)


def read_csv(name):
    """Cells come back UNQUOTED -- several of these CSVs quote every field, and a
    raw split leaves '"1"' where an int is expected."""
    with open(os.path.join(CSVDIR, name), "rb") as fh:
        text = fh.read().decode("utf-8-sig")
    lines = text.split("\n")
    hdr = [h.strip().strip('"') for h in lines[0].split(",")]
    rows = [[c.strip().strip('"') for c in ln.split(",")] for ln in lines[1:] if ln.strip()]
    return hdr, rows, text


def append_csv(name, newrows, label):
    path = os.path.join(CSVDIR, name)
    text = open(path, "rb").read().decode("utf-8-sig")
    lines = [ln for ln in text.split("\n")[1:] if ln.strip()]
    existing = {ln.split(",", 1)[0].strip().strip('"') for ln in lines}
    dup = [r[0] for r in newrows if str(r[0]) in existing]
    if dup:
        raise SystemExit("ABORT: %s already has ids %s" % (name, dup[:6]))
    # match the file's own quoting convention rather than imposing one
    quoted = bool(lines) and lines[0].split(",")[0].strip().startswith('"')
    def cell(v):
        s = fmt(v)
        return ('"%s"' % s) if quoted else s
    shutil.copyfile(path, path + ".pre_map751_light.bak")
    body = text if text.endswith("\n") else text + "\n"
    out = body + "\n".join(",".join(cell(c) for c in r) for r in newrows) + "\n"
    open(path, "wb").write(b"\xef\xbb\xbf" + out.encode("utf-8"))
    print("  %-20s %6d -> %6d (+%d %s, quoted=%s)"
          % (name, len(existing), len(existing) + len(newrows), len(newrows), label, quoted))


def tiles_from_wdt(path):
    d = open(path, "rb").read()
    pos, out = 0, set()
    while pos + 8 <= len(d):
        tag = d[pos:pos + 4][::-1].decode("ascii", "replace")
        size = struct.unpack_from("<I", d, pos + 4)[0]
        if tag == "MAIN":
            for i in range(64 * 64):
                if struct.unpack_from("<I", d, pos + 8 + i * 8)[0] & 1:
                    out.add((i % 64, i // 64))
        pos += 8 + size
    return out


def main():
    tiles = tiles_from_wdt(WDT)
    centres = [(17066.666 - (ty + 0.5) * TILE, 17066.666 - (tx + 0.5) * TILE) for tx, ty in tiles]
    print("footprint: %d tiles" % len(tiles))

    clight, _ = dbc(os.path.join(CATA, "Light.dbc"))
    cparam, cpfc = dbc(os.path.join(CATA, "LightParams.dbc"))
    cint, _ = dbc(os.path.join(CATA, "LightIntBand.dbc"))
    cfloat, _ = dbc(os.path.join(CATA, "LightFloatBand.dbc"))
    cparam_by = {p[0]: p for p in cparam}
    cint_by = {r[0]: r for r in cint}
    cfloat_by = {r[0]: r for r in cfloat}

    # ---- our side ---------------------------------------------------------
    lh, lrows, _ = read_csv("Light.csv")
    ph, prows, _ = read_csv("LightParams.csv")
    ih, irows, _ = read_csv("LightIntBand.csv")
    fh_, frows, _ = read_csv("LightFloatBand.csv")
    our_pids = {int(r[0]) for r in prows}
    our_iids = {int(r[0]) for r in irows}
    our_fids = {int(r[0]) for r in frows}
    our_int_by = {int(r[0]): r for r in irows}
    our_float_by = {int(r[0]): r for r in frows}

    def our_param_key(pid):
        p = next(r for r in prows if int(r[0]) == pid)
        parts = [tuple(x.strip() for x in p[1:])]
        for t in range(18):
            b = our_int_by.get((pid - 1) * 18 + t + 1)
            parts.append(tuple(x.strip() for x in b[1:]) if b else None)
        for t in range(6):
            b = our_float_by.get((pid - 1) * 6 + t + 1)
            parts.append(tuple(x.strip() for x in b[1:]) if b else None)
        return tuple(parts)

    def cata_param_key(pid):
        p = cparam_by[pid]
        # drop the trailing Cata-only Flags field so the shapes line up
        parts = [tuple(str(struct.unpack("<i", struct.pack("<I", v))[0]) for v in p[1:cpfc - 1])]
        for t in range(18):
            b = cint_by.get((pid - 1) * 18 + t + 1)
            parts.append(tuple(str(struct.unpack("<i", struct.pack("<I", v))[0]) for v in b[1:]) if b else None)
        for t in range(6):
            b = cfloat_by.get((pid - 1) * 6 + t + 1)
            parts.append(tuple(str(struct.unpack("<i", struct.pack("<I", v))[0]) for v in b[1:]) if b else None)
        return tuple(parts)

    print("indexing our %d LightParams by content..." % len(our_pids))
    ours_by_key = {}
    for pid in our_pids:
        ours_by_key.setdefault(our_param_key(pid), pid)

    # ---- pick the lights --------------------------------------------------
    keep = []
    for r in clight:
        if r[1] != SRC_CONTINENT:
            continue
        X, Y, Z = f32(r[2]), f32(r[3]), f32(r[4])
        if X == 0 and Y == 0 and Z == 0:
            continue
        worldX = 17066.666 - Z / 36.0
        worldY = 17066.666 - X / 36.0
        radius = f32(r[6]) / 36.0
        near = min(((cx - worldX) ** 2 + (cy - worldY) ** 2) ** 0.5 for cx, cy in centres)
        if near <= radius + TILE * 0.71:      # half-diagonal of a tile
            keep.append(r)
    print("in-footprint cata continent-0 lights: %d" % len(keep))

    # ---- map their params -------------------------------------------------
    needed = sorted({p for r in keep for p in r[10:15] if p})
    nxt_p = max(our_pids) + 1

    def band_free(p):
        return (all(((p - 1) * 18 + t + 1) not in our_iids for t in range(18))
                and all(((p - 1) * 6 + t + 1) not in our_fids for t in range(6)))

    pmap, new_params, new_int, new_float = {}, [], [], []
    reused = 0
    for cp in needed:
        if cp not in cparam_by:
            continue
        k = cata_param_key(cp)
        if k in ours_by_key:
            pmap[cp] = ours_by_key[k]
            reused += 1
            continue
        while not (nxt_p not in our_pids and band_free(nxt_p)):
            nxt_p += 1
        newid = nxt_p
        nxt_p += 1
        pmap[cp] = newid
        src = cparam_by[cp]
        new_params.append([newid] + [struct.unpack("<i", struct.pack("<I", v))[0] for v in src[1:cpfc - 1]])
        for t in range(18):
            b = cint_by.get((cp - 1) * 18 + t + 1)
            if b:
                new_int.append([(newid - 1) * 18 + t + 1] + [struct.unpack("<i", struct.pack("<I", v))[0] for v in b[1:]])
        for t in range(6):
            b = cfloat_by.get((cp - 1) * 6 + t + 1)
            if b:
                new_float.append([(newid - 1) * 6 + t + 1] + [struct.unpack("<i", struct.pack("<I", v))[0] for v in b[1:]])
    print("params needed %d: reused %d, minted %d" % (len(needed), reused, len(new_params)))

    # ---- build the Light rows --------------------------------------------
    nxt_l = max(int(r[0]) for r in lrows) + 1
    new_lights = []
    nsky = 0
    for r in keep:
        vals = [nxt_l, DEST_MAP]
        vals += [f32(r[i]) for i in (2, 3, 4, 5, 6)]
        for i in range(7, 10):
            vals.append(struct.unpack("<i", struct.pack("<I", r[i]))[0])
        for p in r[10:15]:
            vals.append(pmap.get(p, 0) if p else 0)
        if len(vals) != len(lh):
            raise SystemExit("ABORT: built %d Light columns, header has %d" % (len(vals), len(lh)))
        new_lights.append(vals)
        if any(cparam_by.get(p, (0, 0))[1] for p in r[10:15] if p):
            nsky += 1
        nxt_l += 1
    print("light rows: %d (%d carry a skybox)" % (len(new_lights), nsky))

    print("\nappending:")
    if new_params:
        append_csv("LightParams.csv", new_params, "params")
    if new_int:
        append_csv("LightIntBand.csv", new_int, "int bands")
    if new_float:
        append_csv("LightFloatBand.csv", new_float, "float bands")
    append_csv("Light.csv", new_lights, "lights")
    print("\nmap 751 Light rows: 2 -> %d" % (2 + len(new_lights)))


main()
