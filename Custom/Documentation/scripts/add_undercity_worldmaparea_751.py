#!/usr/bin/env python3
"""Give map 751 a WorldMapArea row for Undercity, so the M map opens on the city.

THE SYMPTOM
    "in undercity it still shows the ruins of lordareron area and the worldmap
     is not showing undercity as well"

WHAT IS ACTUALLY WRONG -- ONLY THE SECOND HALF.

  The AREA NAME is correct and needs no change. Undercity's area is not assigned
  by the terrain at all: the tile's MCNK areaIds are 4933 / 4935 / 4936 (Tirisfal,
  Silverpine, Hillsbrad) and there is no "Ruins of Lordaeron" among them. The name
  comes from WMOAreaTable, and that lookup is intact on map 751:
      - the ADT does place world/wmo/lorderon/undercity/undercity.wmo (uid 239598)
      - the WMO's root wmoID is 1150, exactly what WMOAreaTable keys on
      - the placement's nameSet is 1, and WMOAreaTable has rows for nameSet 0 AND 1
      - 215 of the WMO's 216 group ids have a matching WMOAreaTable row
  Of the 229 rows for that WMO, 53 are named "Ruins of Lordaeron" -- the whole
  above-ground keep ruins are part of the SAME WMO and carry that subzone name in
  stock too. All of them resolve to AreaTableID 1497 (Undercity). So standing in
  the ruins courtyard and reading "Ruins of Lordaeron" is stock behaviour, byte for
  byte identical to map 0. Nothing to fix there.

  The WORLD MAP is genuinely broken. The client picks the map to draw by looking up
  WorldMapArea on (current MapID, current AreaID). Undercity's only WMA row is id
  382 with MapID = 0. On map 751 that never matches, so the map falls back to the
  continent and Undercity is unreachable from the map UI.

THE FIX -- one appended WMA row, a verbatim clone of stock 382 with MapID 751.

Map 0 and map 751 share the same coordinate frame for this tile: the Undercity
elevators sit at exactly (1596.15, 291.80), (1595.26, 188.64), (1544.24, 240.77) on
BOTH maps, to the last decimal. So the stock rect transfers with no transform:
    LocLeft 873.1926  LocRight -86.1824  LocTop 1877.945  LocBottom 1237.841

AreaName stays "Undercity" -- that string repoints the map tiles, so reusing it
reuses the stock Interface/WorldMap/Undercity/ art the client already ships.
The .dbc string-block offset for it (507) is reused as-is, so the string block is
not touched at all: the file grows by exactly one 44-byte record.

TWO WMA ROWS FOR ONE AreaID IS A SUPPORTED SHAPE, not a hack. Precedent in the very
files being edited: AreaID 268 (AzsharaCrater) already has rows on map 37 and map
1451, and stock Blizzard ships AreaID 2257 (DeeprunTram) twice on map 369.

NO OVERLAY ROWS ARE NEEDED: stock Undercity has zero WorldMapOverlay rows -- cities
are drawn fully revealed, there is no exploration fog to clear.

Writes Custom/DBCs/WorldMapArea.dbc and Custom/CSV DBC/WorldMapArea.csv.
Deploy afterwards with sync-dbc-deploy.js + the patch MPQs.
"""
import os, struct, csv, io

ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom"
DBC = os.path.join(ROOT, "DBCs", "WorldMapArea.dbc")
CSV = os.path.join(ROOT, "CSV DBC", "WorldMapArea.csv")
NL = chr(10)

SRC_ID = 382        # stock Undercity, map 0
NEW_ID = 1275       # current max is 1274
NEW_MAP = 751


def main():
    d = open(DBC, "rb").read()
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    assert (fc, rs) == (11, 44), (fc, rs)
    base, sb = 20, 20 + rc * rs
    recs = [bytearray(d[base + i * rs: base + (i + 1) * rs]) for i in range(rc)]
    by = {struct.unpack_from("<I", r, 0)[0]: r for r in recs}

    assert NEW_ID not in by, "id %d already present" % NEW_ID
    src = by[SRC_ID]

    # guard: the row we are cloning must really be map 0 / area 1497
    assert struct.unpack_from("<i", src, 4)[0] == 0, "source is not map 0"
    assert struct.unpack_from("<i", src, 8)[0] == 1497, "source is not area 1497"

    # guard: nothing on map 751 may already claim area 1497
    for r in recs:
        m = struct.unpack_from("<i", r, 4)[0]
        a = struct.unpack_from("<i", r, 8)[0]
        assert not (m == NEW_MAP and a == 1497), "map 751 already has an area-1497 row"

    new = bytearray(src)                      # verbatim clone -- rect, art name, all of it
    struct.pack_into("<I", new, 0, NEW_ID)
    struct.pack_into("<i", new, 4, NEW_MAP)

    out = b"WDBC" + struct.pack("<4I", rc + 1, fc, rs, ss) \
        + b"".join(bytes(r) for r in recs) + bytes(new) + d[sb:sb + ss]
    open(DBC, "wb").write(out)
    print("WorldMapArea.dbc: %d -> %d records" % (rc, rc + 1))

    # read-back verification
    d2 = open(DBC, "rb").read()
    rc2, fc2, rs2, ss2 = struct.unpack("<4I", d2[4:20])
    sb2 = 20 + rc2 * rs2

    def S(o):
        if o <= 0:
            return ""
        e = d2.find(b"\0", sb2 + o)
        return d2[sb2 + o: e].decode("utf-8", "replace")

    got = None
    for i in range(rc2):
        o = 20 + i * rs2
        if struct.unpack_from("<I", d2, o)[0] == NEW_ID:
            v = [struct.unpack_from("<i", d2, o + k * 4)[0] for k in range(fc2)]
            f = [struct.unpack_from("<f", d2, o + k * 4)[0] for k in range(fc2)]
            got = (v, f, S(v[3]))
    assert got, "new row not found on read-back"
    v, f, nm = got
    print("  id=%d map=%d area=%d name=%r" % (v[0], v[1], v[2], nm))
    print("  L=%.4f R=%.4f T=%.3f B=%.3f  DisplayMapID=%d parentWMA=%d"
          % (f[4], f[5], f[6], f[7], v[8], v[10]))
    print("  string block untouched:", d[sb:sb + ss] == d2[sb2:sb2 + ss2])
    print("  originals byte-identical:", d[base:sb] == d2[20:20 + rc * rs])
    print("  art dir reused:", "Interface" + chr(92) + "WorldMap" + chr(92) + nm)

    # CSV
    with open(CSV, encoding="utf-8", newline="") as fh:
        r = csv.reader(fh)
        hdr = next(r)
        rows = [x for x in r if x and x[0].strip() != ""]
    srcrow = next(x for x in rows if x[0] == str(SRC_ID))
    newrow = list(srcrow)
    newrow[0] = str(NEW_ID)
    newrow[1] = str(NEW_MAP)
    assert not any(x[0] == str(NEW_ID) for x in rows), "csv already has that id"
    rows.append(newrow)
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=NL, quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    open(CSV, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("WorldMapArea.csv: %d rows (appended %s)" % (len(rows), newrow))


main()
