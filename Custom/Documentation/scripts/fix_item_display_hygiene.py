#!/usr/bin/env python3
"""Two pre-existing item-display defects, found while validating the map-751 import.
Neither is caused by that import; both are server-wide.

1. TWENTY DUPLICATE ItemDisplayInfo IDS -- all in the minted `8,000,000 +
   IconFileDataID` band from the retail item downport, i.e. the mint ran twice for
   those icons. NINETEEN of the twenty pairs are BYTE-IDENTICAL. The twentieth
   (8132761, icon inv_crate_01) differs only in GroupSoundIndex, 7 versus 0.

   Deduped keeping the LAST occurrence of each id. That is deliberate: a DBC loader
   indexes records by id as it reads them, so the last row written is the one the
   client already resolves. Keeping it makes this a pure hygiene change with
   ZERO behavioural difference -- including for 8132761, which keeps the
   GroupSoundIndex 0 it already had. Keeping the "richer" row instead would have
   silently changed one item's pickup sound.

2. FIVE ITEMS POINTING AT A DISPLAY THAT DOES NOT EXIST. Checked against both the
   Cata 4.3.4 client and the stock 3.3.5 client: displays 63765 and 134 are in
   NEITHER, so there is nothing to downport -- these rows have always pointed at
   nothing, and the items render with no icon.

   Repointed at the closest real analogue already in the table, rather than invented:
     63682/63683/63684  Helm of the Forlorn Vanquisher/Conqueror/Protector
                        -> 41441, the display shared by Helm of the Lost
                           Conqueror/Protector/Vanquisher (40616-40618), the exact
                           WotLK equivalents of these Cata tier-helm tokens
     64663              Bile-Etched Brass Key   -> 6710, from Small Brass Key (2719)
     71716              Soothsayer's Runes      -> 11180, from Runes of Summoning (6284)

   NOT changed while here: those three tokens are class 0 (Consumable) where the
   stock tokens are class 15 (Miscellaneous). That is a separate pre-existing
   oddity and changing an item's class affects bag filtering, so it is left alone
   and noted instead.

Writes: ItemDisplayInfo .dbc/.csv (dedupe), Item .dbc/.csv (displayid), and
Plaguelands/98_item_display_repairs.sql for the DB side.
"""
import struct, csv, io, os

ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom"
OUT_SQL = os.path.join(ROOT, "Custom feature SQLs", "worlddb", "Plaguelands",
                       "98_item_display_repairs.sql")
NL = chr(10)
BT = chr(96)

REPOINT = {63682: 41441, 63683: 41441, 63684: 41441, 64663: 6710, 71716: 11180}
WHY = {
    63682: "Helm of the Lost Vanquisher (40618) -- same tier-helm token art",
    63683: "Helm of the Lost Conqueror  (40616) -- same tier-helm token art",
    63684: "Helm of the Lost Protector  (40617) -- same tier-helm token art",
    64663: "Small Brass Key (2719)",
    71716: "Runes of Summoning (6284)",
}


def bt(n):
    return BT + n + BT


def dedupe_idi():
    p = os.path.join(ROOT, "DBCs", "ItemDisplayInfo.dbc")
    d = open(p, "rb").read()
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    base, sb = 20, 20 + rc * rs
    recs = [d[base + i * rs: base + (i + 1) * rs] for i in range(rc)]
    ids = [struct.unpack_from("<I", r, 0)[0] for r in recs]
    # keep the LAST occurrence of each id -- what the client already resolves
    last = {}
    for i, x in enumerate(ids):
        last[x] = i
    keep = sorted(last.values())
    out = b"WDBC" + struct.pack("<4I", len(keep), fc, rs, ss) \
        + b"".join(recs[i] for i in keep) + d[sb:sb + ss]
    open(p, "wb").write(out)
    print("ItemDisplayInfo.dbc: %d -> %d records (%d duplicate rows removed)"
          % (rc, len(keep), rc - len(keep)))

    c = os.path.join(ROOT, "CSV DBC", "ItemDisplayInfo.csv")
    with open(c, encoding="utf-8", newline="") as fh:
        r = csv.reader(fh)
        hdr = next(r)
        rows = [x for x in r if x and x[0].strip() != ""]
    lastc = {}
    for i, x in enumerate(rows):
        lastc[x[0]] = i
    rows = [rows[i] for i in sorted(lastc.values())]
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=NL, quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    open(c, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("ItemDisplayInfo.csv: %d rows" % len(rows))
    return {struct.unpack_from("<I", recs[i], 0)[0] for i in keep}


def repoint_items():
    p = os.path.join(ROOT, "DBCs", "Item.dbc")
    d = bytearray(open(p, "rb").read())
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    n = 0
    for i in range(rc):
        o = 20 + i * rs
        e = struct.unpack_from("<I", d, o)[0]
        if e in REPOINT:
            struct.pack_into("<I", d, o + 5 * 4, REPOINT[e])
            n += 1
    assert n == len(REPOINT), n
    open(p, "wb").write(bytes(d))
    print("Item.dbc: %d displayids repointed" % n)

    c = os.path.join(ROOT, "CSV DBC", "Item.csv")
    with open(c, encoding="utf-8", newline="") as fh:
        r = csv.reader(fh)
        hdr = next(r)
        rows = [x for x in r if x and x[0].strip() != ""]
    ci = hdr.index("DisplayInfoID")
    m = 0
    for x in rows:
        if int(x[0]) in REPOINT:
            x[ci] = str(REPOINT[int(x[0])])
            m += 1
    assert m == len(REPOINT), m
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=NL, quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    open(c, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("Item.csv: %d displayids repointed" % m)


def write_sql():
    ids = ",".join(str(x) for x in sorted(REPOINT))
    with open(OUT_SQL, "w", encoding="utf-8", newline=NL) as fh:
        w = fh.write
        w("-- 98_item_display_repairs.sql -- item display hygiene, DB step 37." + NL + "--" + NL)
        w("-- GENERATED by Custom/Documentation/scripts/fix_item_display_hygiene.py." + NL + "--" + NL)
        w("-- Five items point at an ItemDisplayInfo row that does not exist, so they" + NL)
        w("-- render with no icon. Displays 63765 and 134 are in NEITHER the Cata 4.3.4" + NL)
        w("-- client NOR the stock 3.3.5 client -- there is nothing to downport, these" + NL)
        w("-- rows have always pointed at nothing." + NL + "--" + NL)
        w("-- Repointed at the closest real analogue already in the table:" + NL)
        for e in sorted(REPOINT):
            w("--   %-6d -> %-6d  %s" % (e, REPOINT[e], WHY[e]) + NL)
        w("--" + NL)
        w("-- PRE-EXISTING, not from the map-751 import; found while validating it." + NL)
        w("-- Also not changed here: 63682/63683/63684 are class 0 (Consumable) where the" + NL)
        w("-- stock tier tokens are class 15 (Miscellaneous). Changing an item's class" + NL)
        w("-- affects bag filtering, so that one is left alone and noted." + NL + NL)
        for e in sorted(REPOINT):
            w("UPDATE %s SET %s = %d WHERE %s = %d AND %s = %d;%s"
              % (bt("item_template"), bt("displayid"), REPOINT[e], bt("entry"), e,
                 bt("displayid"), 63765 if e < 64000 else 134, NL))
        w(NL + "-- keep the Item.dbc overlay in step" + NL)
        w("DELETE FROM %s WHERE %s IN (%s);%s" % (bt("item_dbc"), bt("ID"), ids, NL))
        w("INSERT INTO %s (%s, %s, %s, %s, %s, %s, %s, %s)%s"
          % (bt("item_dbc"), bt("ID"), bt("ClassID"), bt("SubclassID"),
             bt("Sound_Override_Subclassid"), bt("Material"), bt("DisplayInfoID"),
             bt("InventoryType"), bt("SheatheType"), NL))
        w("SELECT %s, %s, %s, %s, %s, %s, %s, %s%s"
          % (bt("entry"), bt("class"), bt("subclass"), bt("SoundOverrideSubclass"),
             bt("Material"), bt("displayid"), bt("InventoryType"), bt("sheath"), NL))
        w("FROM %s WHERE %s IN (%s);%s" % (bt("item_template"), bt("entry"), ids, NL + NL))
        w("-- ---------------------------------------------------------------------------" + NL)
        w("-- Verification" + NL)
        w("-- ---------------------------------------------------------------------------" + NL)
        w("SELECT 'items repointed (want %d)' AS what, COUNT(*) AS n" % len(REPOINT) + NL)
        w("  FROM %s WHERE %s IN (%s) AND %s IN (%s)"
          % (bt("item_template"), bt("entry"), ids, bt("displayid"),
             ",".join(str(v) for v in sorted(set(REPOINT.values())))) + NL)
        w("UNION ALL SELECT '  ...still on a dead display (want 0)', COUNT(*)" + NL)
        w("  FROM %s WHERE %s IN (%s) AND %s IN (63765, 134);"
          % (bt("item_template"), bt("entry"), ids, bt("displayid")) + NL)
    print("wrote %s" % OUT_SQL)


if __name__ == "__main__":
    kept = dedupe_idi()
    repoint_items()
    write_sql()
    # every repoint target must exist after the dedupe
    missing = [v for v in set(REPOINT.values()) if v not in kept]
    assert not missing, "repoint target absent from ItemDisplayInfo: %s" % missing
    print("all repoint targets present in ItemDisplayInfo: yes")
