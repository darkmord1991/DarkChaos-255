#!/usr/bin/env python3
"""Give map 751's Undercity its own AreaTable rows, via the nameSet discriminator.

THE SYMPTOM (after 103_/104_ made the elevators rideable)
    "elevators work perfectly now in undercity - but the area has not changed,
     and so the undercity map is not showing up"

WHY THE WorldMapArea ROW ALONE WAS NOT ENOUGH.
    Adding WMA 1275 (map 751 -> area 1497) was necessary but not sufficient: the
    client never reports area 1497 on map 751 in the first place, so the lookup
    that row answers is never asked.

    The WMO chain itself is provably fine -- the deployed tile places
    world/wmo/lorderon/undercity/undercity.wmo (uid 239598), the root wmoID is
    1150 exactly as WMOAreaTable keys on it, the placement nameSet is 1 for which
    WMOAreaTable has rows, and 215 of the WMO's 216 group ids match. What fails is
    the far end: AreaTable 1497 has ContinentID = 0. An area belongs to exactly one
    continent, and map 751 cannot adopt a map-0 area.

    That is also why the terrain looks right and the interior does not. The importer
    RETAGGED the terrain -- map 751's tiles carry custom area ids 4933/4935/4936 with
    ContinentID 751, not the stock 85/130/267. It could not retag the WMO, because
    WMOAreaTable is keyed by (wmoID, nameSet, groupId) with no map component at all.
    Terrain got its own areas; the WMO interior kept pointing at map 0's.

THE FIX IS BLIZZARD'S OWN, NOT AN INVENTION.
    nameSet is exactly the discriminator for "same WMO, different map, different
    areas". Stock proves it 52 times over. The cleanest case is wmoID 59:

        nameSet 1 -> areas on continent 0
        nameSet 2 -> areas on continent 609   (Scarlet Enclave)
        nameSet 3 -> areas on continent 0

    So: give map 751's placement nameSet 2, and add a parallel set of WMOAreaTable
    rows for nameSet 2 that point at new AreaTable rows owned by continent 751.
    Stock nameSet 1 is untouched, so map 0's Undercity keeps working unchanged.

WHAT THIS WRITES

  1. AreaTable -- two new rows, cloned field-for-field from the stock originals so
     flags, ambience, sound and the localized names all carry over:
         4940 'Undercity'  ContinentID 751, ParentAreaID 0 (a zone in its own right,
                           as stock 1497 is), fresh AreaBit, ExplorationLevel 130 to
                           match Tirisfal 4933 which surrounds it
         4941 'Elevator'   ContinentID 751, ParentAreaID 4940, fresh AreaBit
                           -- cloned from stock 4617, which 3 of the WMO's rows use
                           for the lift shafts
     Fresh AreaBits, not the stock 685/2690: sharing a bit would make exploring
     Undercity on 751 also flag the map-0 one as explored. Both are below 4096, the
     size of the client's explored-zones bitmask.

  2. WMOAreaTable -- the 229 rows for (wmoID 1150, nameSet 1) cloned to nameSet 2,
     each keeping its own subzone name, sound, ambience and flags, with only the
     AreaTableID remapped: 1497 -> 4940, 4617 -> 4941, 0 -> 0 (0 means "no override",
     leave it alone). That preserves the interior naming exactly -- War Quarter,
     Trade Quarter, Canals, Sewers and the 53 'Ruins of Lordaeron' surface groups.

  3. WorldMapArea -- row 1275 repointed from area 1497 to 4940, so the row added
     earlier now matches what the client will actually report.

  4. The ADT placements are handled by the companion script
     patch_undercity_nameset_751.py -- nameSet 1 -> 2 for uid 239598. FOUR tiles
     carry that placement, not one: 30_28, 30_29, 31_28 and 31_29. A WMO is
     duplicated into every tile its footprint overlaps, and missing one would leave
     part of the building resolving to the old area.

AFTER THIS, MAP 751'S VMAPS MUST BE RE-EXTRACTED. The server reads the same triple:
vmap4_extractor writes MODF.NameSet into the vmap dir file (wmo.cpp:584) and
Map::GetAreaId calls GetWMOAreaTableEntryByTripple(rootId, adtId, groupId). Until the
vmaps are rebuilt the server keeps looking up nameSet 1, misses, and falls back to the
terrain area -- degraded, not broken, but the server and client will disagree.
"""
import os, struct, csv, io

ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom"
DBCD = os.path.join(ROOT, "DBCs")
CSVD = os.path.join(ROOT, "CSV DBC")
NL = chr(10)

WMOID = 1150
SRC_NS, NEW_NS = 1, 2
AREA_UC, AREA_ELEV = 4940, 4941
SRC_UC, SRC_ELEV = 1497, 4617
EXPL_LEVEL = 130
AREA_REMAP = {SRC_UC: AREA_UC, SRC_ELEV: AREA_ELEV, 0: 0}

A_ID, A_CONT, A_PARENT, A_BIT, A_EXPL, A_NAME = 0, 1, 2, 3, 10, 11
W_ID, W_WMOID, W_NS, W_GROUP, W_AREA = 0, 1, 2, 3, 10


def load(p):
    d = open(p, "rb").read()
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    recs = [bytearray(d[20 + i * rs: 20 + (i + 1) * rs]) for i in range(rc)]
    return rc, fc, rs, recs, d[20 + rc * rs: 20 + rc * rs + ss]


def save(p, fc, rs, recs, sb):
    out = b"WDBC" + struct.pack("<4I", len(recs), fc, rs, len(sb)) \
        + b"".join(bytes(r) for r in recs) + sb
    open(p, "wb").write(out)


def read_csv(p):
    with open(p, encoding="utf-8-sig", newline="") as fh:
        r = csv.reader(fh)
        hdr = next(r)
        rows = [x for x in r if x and x[0].strip() != ""]
    return hdr, rows


def write_csv(p, hdr, rows, bom):
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=NL, quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    enc = "utf-8-sig" if bom else "utf-8"
    open(p, "w", encoding=enc, newline="").write(buf.getvalue())


def do_areatable():
    p = os.path.join(DBCD, "AreaTable.dbc")
    rc, fc, rs, recs, sb = load(p)
    by = {struct.unpack_from("<I", r, 0)[0]: r for r in recs}
    assert AREA_UC not in by and AREA_ELEV not in by, "target ids already exist"
    used = set(struct.unpack_from("<i", r, A_BIT * 4)[0] for r in recs)
    free = [b for b in range(1, 4096) if b not in used]
    bit_uc, bit_elev = free[0], free[1]

    for newid, srcid, parent, bit in ((AREA_UC, SRC_UC, 0, bit_uc),
                                      (AREA_ELEV, SRC_ELEV, AREA_UC, bit_elev)):
        n = bytearray(by[srcid])
        struct.pack_into("<i", n, A_ID * 4, newid)
        struct.pack_into("<i", n, A_CONT * 4, 751)
        struct.pack_into("<i", n, A_PARENT * 4, parent)
        struct.pack_into("<i", n, A_BIT * 4, bit)
        struct.pack_into("<i", n, A_EXPL * 4, EXPL_LEVEL)
        recs.append(n)
    save(p, fc, rs, recs, sb)
    print("AreaTable.dbc: %d -> %d records (4940 bit=%d, 4941 bit=%d)"
          % (rc, len(recs), bit_uc, bit_elev))

    hdr, rows = read_csv(os.path.join(CSVD, "AreaTable.csv"))
    src = {x[0]: x for x in rows}
    for newid, srcid, parent, bit in ((AREA_UC, SRC_UC, 0, bit_uc),
                                      (AREA_ELEV, SRC_ELEV, AREA_UC, bit_elev)):
        r = list(src[str(srcid)])
        r[A_ID] = str(newid)
        r[A_CONT] = "751"
        r[A_PARENT] = str(parent)
        r[A_BIT] = str(bit)
        r[A_EXPL] = str(EXPL_LEVEL)
        rows.append(r)
    write_csv(os.path.join(CSVD, "AreaTable.csv"), hdr, rows, True)
    print("AreaTable.csv: %d rows" % len(rows))


def do_wmoareatable():
    p = os.path.join(DBCD, "WMOAreaTable.dbc")
    rc, fc, rs, recs, sb = load(p)
    nextid = max(struct.unpack_from("<I", r, 0)[0] for r in recs) + 1
    for r in recs:
        assert not (struct.unpack_from("<i", r, W_WMOID * 4)[0] == WMOID
                    and struct.unpack_from("<i", r, W_NS * 4)[0] == NEW_NS), \
            "nameSet 2 rows for wmoID 1150 already exist"

    src = [r for r in recs if struct.unpack_from("<i", r, W_WMOID * 4)[0] == WMOID
           and struct.unpack_from("<i", r, W_NS * 4)[0] == SRC_NS]
    seen = {}
    added = []
    for r in src:
        n = bytearray(r)
        struct.pack_into("<I", n, W_ID * 4, nextid)
        nextid += 1
        struct.pack_into("<i", n, W_NS * 4, NEW_NS)
        old = struct.unpack_from("<i", r, W_AREA * 4)[0]
        assert old in AREA_REMAP, "unexpected AreaTableID %d on a 1150 row" % old
        struct.pack_into("<i", n, W_AREA * 4, AREA_REMAP[old])
        seen[old] = seen.get(old, 0) + 1
        added.append(n)
    recs.extend(added)
    save(p, fc, rs, recs, sb)
    print("WMOAreaTable.dbc: %d -> %d records (+%d nameSet-2 rows)"
          % (rc, len(recs), len(added)))
    print("   AreaTableID remap:", {k: (AREA_REMAP[k], v) for k, v in seen.items()})

    hdr, rows = read_csv(os.path.join(CSVD, "WMOAreaTable.csv"))
    ci = {n: i for i, n in enumerate(hdr)}
    cid, cw, cns, ca = ci["ID"], ci["WMOID"], ci["NameSetID"], ci["AreaTableID"]
    nid = max(int(x[cid]) for x in rows) + 1
    new = []
    for x in rows:
        if int(x[cw]) == WMOID and int(x[cns]) == SRC_NS:
            y = list(x)
            y[cid] = str(nid)
            nid += 1
            y[cns] = str(NEW_NS)
            y[ca] = str(AREA_REMAP[int(x[ca])])
            new.append(y)
    rows.extend(new)
    write_csv(os.path.join(CSVD, "WMOAreaTable.csv"), hdr, rows, False)
    print("WMOAreaTable.csv: %d rows (+%d)" % (len(rows), len(new)))


def do_worldmaparea():
    p = os.path.join(DBCD, "WorldMapArea.dbc")
    rc, fc, rs, recs, sb = load(p)
    hit = 0
    for r in recs:
        if struct.unpack_from("<I", r, 0)[0] == 1275:
            assert struct.unpack_from("<i", r, 8)[0] == SRC_UC, "WMA 1275 is not on area 1497"
            struct.pack_into("<i", r, 8, AREA_UC)
            hit += 1
    assert hit == 1, "WMA 1275 not found"
    save(p, fc, rs, recs, sb)
    print("WorldMapArea.dbc: row 1275 area %d -> %d" % (SRC_UC, AREA_UC))

    hdr, rows = read_csv(os.path.join(CSVD, "WorldMapArea.csv"))
    n = 0
    for x in rows:
        if x[0] == "1275":
            assert x[2] == str(SRC_UC)
            x[2] = str(AREA_UC)
            n += 1
    assert n == 1
    write_csv(os.path.join(CSVD, "WorldMapArea.csv"), hdr, rows, False)
    print("WorldMapArea.csv: row 1275 repointed")


def verify():
    rc, fc, rs, recs, sb = load(os.path.join(DBCD, "AreaTable.dbc"))

    def S(o):
        if o <= 0:
            return ""
        e = sb.find(b"\0", o)
        return sb[o:e].decode("utf-8", "replace")

    for i in (SRC_UC, AREA_UC, AREA_ELEV):
        r = [x for x in recs if struct.unpack_from("<I", x, 0)[0] == i][0]
        v = [struct.unpack_from("<i", r, k * 4)[0] for k in range(fc)]
        print("   area %-5d continent=%-4d parent=%-5d areabit=%-5d expl=%-4d name=%r"
              % (v[0], v[1], v[2], v[3], v[10], S(v[A_NAME])))

    rc, fc, rs, recs, sb = load(os.path.join(DBCD, "WMOAreaTable.dbc"))
    from collections import Counter
    c = Counter()
    ids = []
    for r in recs:
        ids.append(struct.unpack_from("<I", r, 0)[0])
        if struct.unpack_from("<i", r, W_WMOID * 4)[0] == WMOID:
            c[(struct.unpack_from("<i", r, W_NS * 4)[0],
               struct.unpack_from("<i", r, W_AREA * 4)[0])] += 1
    print("   wmoID 1150 rows by (nameSet, areaId):")
    for k in sorted(c):
        print("      nameSet %-2d area %-6d x%d" % (k[0], k[1], c[k]))
    print("   WMOAreaTable row ids unique:", len(ids) == len(set(ids)))


if __name__ == "__main__":
    do_areatable()
    do_wmoareatable()
    do_worldmaparea()
    verify()
