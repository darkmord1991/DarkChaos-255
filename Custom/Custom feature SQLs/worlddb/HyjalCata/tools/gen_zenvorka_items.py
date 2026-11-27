#!/usr/bin/env python3
"""
Zen'Vorka's stock -- build item_template rows for the 13 ids his vendor list
references but the fork does not have.

Zen'Vorka (3652822, map 861) is the Molten Front token vendor: he trades the
"Mark of the World Tree" currency for mount/pet/gear sacks.  He carries
UNIT_NPC_FLAG_VENDOR but has no npc_vendor rows at all, so his gossip opens an
empty window -- the entire Mark sink is dead.  nelt_world has all 17 of his
rows, but only 4 of the items exist here, so importing the vendor list first
would just trade a silent empty window for 13 "item entry not listed in
`item_template`" errors.  This builds the 13 first.

Sources are the same pair rounds 19/21 used, for the same reasons:
  * k:/tmp/cata-dbc/Item.db2 -- Cata build 15595, WDB2, 8 int fields.  The
    header is 48 bytes with NO index table when minid == maxid == 0 (true
    here); getting that wrong shifts every record by 6 bytes.
  * K:/Dark-Chaos/retailextracts/ItemSparse.12.0.5.67823.csv -- names,
    descriptions, quality, stack sizes.  Retail still ships these, so the
    strings are authentic rather than invented.

DISPLAY IDs: any Cata display id the fork's ItemDisplayInfo does not have is
written as 0, because an unknown display makes the core log "does not have a
correct display id (N), must be 0".  The items work; they show no icon until
those rows + BLPs are downported.

    python gen_zenvorka_items.py [outdir]
"""
import struct, csv, os, sys

CATA_ITEM = "k:/tmp/cata-dbc/Item.db2"
RETAIL_SPARSE = "K:/Dark-Chaos/retailextracts/ItemSparse.12.0.5.67823.csv"
FORK_IDI = "K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/ItemDisplayInfo.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r23/"

WANT = [70145, 70146, 70147, 70148, 70149, 70150, 70151, 70152, 70153, 70154,
        71087, 71088, 71631]

# retail ItemSparse column indices (0-based; verified against the header)
C_DESC, C_NAME = 2, 6
C_BAGFAMILY, C_STARTQUEST = 12, 13
C_STACKABLE, C_MAXCOUNT = 46, 47
C_ILVL, C_REQLVL, C_QUALITY = 85, 101, 103

COLS = ("entry", "class", "subclass", "name", "displayid", "Quality", "Flags",
        "BuyCount", "BuyPrice", "SellPrice", "InventoryType", "AllowableClass",
        "AllowableRace", "ItemLevel", "RequiredLevel", "maxcount", "stackable",
        "ContainerSlots", "bonding", "description", "startquest", "Material",
        "sheath", "BagFamily", "ScriptName", "VerifiedBuild")


def load_item_db2(path, want):
    d = open(path, 'rb').read()
    assert d[:4] == b'WDB2', path
    rc, fc, rs, sts, th, build, ts, minid, maxid, loc, cts = struct.unpack('<11I', d[4:48])
    base = 48 + ((maxid - minid + 1) * 6 if maxid > minid else 0)
    out = {}
    for r in range(rc):
        off = base + r * rs
        v = struct.unpack('<8i', d[off:off + 32])
        if v[0] in want:
            out[v[0]] = dict(cls=v[1], sub=v[2], material=v[4], displayid=v[5],
                             invtype=v[6], sheath=v[7])
    return out


def load_display_ids(path):
    have = set()
    with open(path, encoding='utf-8', newline='') as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            try:
                have.add(int(row[0]))
            except (ValueError, IndexError):
                pass
    return have


def load_retail(path, want):
    out = {}
    with open(path, encoding='utf-8', newline='') as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            try:
                i = int(row[0])
            except (ValueError, IndexError):
                continue
            if i in want:
                out[i] = row
    return out


def esc(s):
    return "'" + (s or "").replace("\\", "\\\\").replace("'", "''") + "'"


def num(row, idx, default=0):
    try:
        v = row[idx].strip()
        return int(float(v)) if v else default
    except (ValueError, IndexError):
        return default


HEADER = """-- ---------------------------------------------------------------------------
-- 151  Hyjal round-23 -- Zen'Vorka's 13 missing stock items
-- ---------------------------------------------------------------------------
-- Zen'Vorka (3652822, map 861) is the Molten Front token vendor -- he is what
-- the "Mark of the World Tree" currency is FOR.  He carries the vendor npcflag
-- but has zero npc_vendor rows, so his window opens empty and the whole Mark
-- sink is dead content.  nelt_world has all 17 of his rows; 13 of the items do
-- not exist here, so 152_ cannot import the vendor list until these exist --
-- otherwise the empty window is merely traded for 13 "item entry not listed in
-- `item_template` - skipped" errors.
--
-- Sources are the pair rounds 19/21 used: the Cata client Item.db2 (build
-- 15595) for class / subclass / material / display / inventorytype / sheath,
-- and the retail ItemSparse extract for names and descriptions, so the strings
-- are authentic rather than invented.
--
-- DISPLAY IDs: any Cata display the fork's ItemDisplayInfo lacks is written as
-- 0 -- an unknown display makes the core log "does not have a correct display
-- id (N), must be 0".  The items work; they show no icon until those rows and
-- their BLPs are downported.
--
-- Generated by HyjalCata/tools/gen_zenvorka_items.py.  Apply BEFORE 152_.
-- ---------------------------------------------------------------------------

"""


def main():
    want = set(WANT)
    items = load_item_db2(CATA_ITEM, want)
    missing = [i for i in WANT if i not in items]
    assert not missing, "not in Item.db2: %s" % missing
    displays = load_display_ids(FORK_IDI)
    retail = load_retail(RETAIL_SPARSE, want)

    rows, report = [], []
    for i in WANT:
        it = items[i]
        rt = retail.get(i)
        name = (rt[C_NAME] if rt else "Item %d" % i).strip()
        desc = (rt[C_DESC] if rt else "").strip()
        quality = num(rt, C_QUALITY, 1) if rt else 1
        stackable = max(1, num(rt, C_STACKABLE, 1)) if rt else 1
        maxcount = num(rt, C_MAXCOUNT, 0) if rt else 0
        startquest = num(rt, C_STARTQUEST, 0) if rt else 0
        bagfamily = num(rt, C_BAGFAMILY, 0) if rt else 0
        ilvl = max(1, num(rt, C_ILVL, 1)) if rt else 1
        reqlvl = num(rt, C_REQLVL, 0) if rt else 0
        disp = it["displayid"] if it["displayid"] in displays else 0
        bonding = 1 if it["cls"] == 12 else 0        # quest items bind on pickup
        vals = (i, it["cls"], it["sub"], esc(name), disp, quality, 0, 1,
                0, 0, it["invtype"], -1, -1,
                ilvl, reqlvl, maxcount, stackable, 0,
                bonding, esc(desc), startquest, it["material"], it["sheath"],
                bagfamily, "''", 0)
        rows.append("(" + ", ".join(str(v) for v in vals) + ")")
        report.append("  [%d] class=%-2d %-38r display=%s%s" % (
            i, it["cls"], name, disp,
            "" if disp else "   (Cata %d not in ItemDisplayInfo -> 0)" % it["displayid"]))

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "151_zenvorka_items.sql")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER)
        f.write("DELETE FROM `item_template` WHERE `entry` IN (%s);\n\n"
                % ",".join(str(i) for i in WANT))
        f.write("INSERT INTO `item_template` (%s) VALUES\n"
                % ", ".join("`%s`" % c for c in COLS))
        f.write(",\n".join(rows) + ";\n")

    print("generated %d item rows -> %s" % (len(rows), path))
    print("\n".join(report))


if __name__ == "__main__":
    main()
