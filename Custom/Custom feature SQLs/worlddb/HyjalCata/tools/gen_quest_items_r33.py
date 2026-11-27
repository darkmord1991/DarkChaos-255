#!/usr/bin/env python3
"""
Round-33 quest items -- the 54 ids quest_template references across all of its
item fields (StartItem, RequiredItemId1-6, ItemDrop1-4, RewardItem1-4 and
RewardChoiceItemID1-6) and item_template lacks.

    Quest 29287 has `RequiredItemId1` = 69836 but item with entry 69836 does not
    exist, quest can't be done.
    Table 'gameobject_loot_template' Entry 208630 Item 69836: item entry not
    listed in `item_template` - skipped

Round 15 deferred these because `nelt_world.db_item-sparse_15595` only carries 6
of the 20 (it is a partial ItemSparse, ~54k of Cata's ~68k items).  Two other
sources close the gap completely:

  * k:/tmp/cata-dbc/Item.db2  -- Cata build 15595, WDB2, 8 int fields
    (ID, ClassID, SubclassID, SoundOverrideSubclass, Material, DisplayInfoID,
     InventoryType, SheatheType).  The WDB2 header is 48 bytes with NO index
     table when minid == maxid == 0, which is the case here -- getting that
     wrong shifts every record by 6 bytes.  All 20 ids are present.
  * K:/Dark-Chaos/retailextracts/ItemSparse.12.0.5.67823.csv -- names,
    descriptions, quality, stack sizes.  Retail still ships these old quest
    items, so the strings are authentic rather than invented.

18 of the 20 are class 12 (Quest, bind-on-pickup); 52976 is class 7 (Trade
Goods) and 56236 class 15 (Miscellaneous), both left unbound.

DISPLAY IDs: 11 of the 20 Cata display ids already exist in
Custom/CSV DBC/ItemDisplayInfo.csv and are kept.  The other 9 (the Cata-new
98xxx icons) do not, and a display id absent from the DBC makes the core log
"does not have a correct display id (N), must be 0" -- so those get 0.  The
items function; they just show no icon until those ItemDisplayInfo rows and
their BLPs are downported.

    python gen_mf_quest_items.py [outdir]
"""
import struct, csv, os, sys

CATA_ITEM = "k:/tmp/cata-dbc/Item.db2"
RETAIL_SPARSE = "K:/Dark-Chaos/retailextracts/ItemSparse.12.0.5.67823.csv"
FORK_IDI = "K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/ItemDisplayInfo.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r33/"

WANT = [45476, 45477, 45545, 45710, 46094, 46128, 46147, 46389, 46715, 46720,
        46721, 46739, 46741, 46774, 46777, 46781, 47040, 47050, 48104, 48665,
        48780, 48835, 49204, 49350, 49368, 49685, 52581, 52582, 53057, 53408,
        53415, 53424, 53444, 55174, 56263, 56469, 56473, 56575, 56707, 56709,
        56710, 57477, 57489, 60214, 60215, 60638, 60644, 61049, 63387, 67272,
        68638, 68644, 68646, 69986]

# All 54 resolve in the Cata Item.db2, so the retail fallback is inert here --
# it is kept so the generator still works if a Shadowlands id ever joins the set.
RETAIL_ITEM = "K:/Dark-Chaos/retailextracts/Item.csv"   # ';' separated

# 176871 "Fortified Antennae" and 179311 "Synvir Lockbox" are Shadowlands and
# have no Cata Item.db2 row.  Their class/subclass/material/inventorytype come
# from the retail Item.db2 export instead (both are class 15 subclass 0, plain
# junk), and their displayid is 0 because a modern IconFileDataID has no 3.3.5
# ItemDisplayInfo equivalent.
RETAIL_ITEM = "K:/Dark-Chaos/retailextracts/Item.csv"   # ';' separated

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


def load_retail_item(path, want):
    """retail Item.db2 export -- fallback for ids with no Cata row."""
    out = {}
    with open(path, encoding='utf-8', newline='') as f:
        r = csv.reader(f, delimiter=';')
        h = next(r)
        ix = {n: i for i, n in enumerate(h)}
        for row in r:
            try:
                i = int(row[0])
            except (ValueError, IndexError):
                continue
            if i in want:
                out[i] = dict(cls=int(row[ix['ClassID']]), sub=int(row[ix['SubclassID']]),
                              material=int(row[ix['Material']]), displayid=0,
                              invtype=int(row[ix['InventoryType']]),
                              sheath=int(row[ix['SheatheType']]))
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
-- 140  Hyjal round-18 -- the 20 missing Molten Front quest / loot items
-- ---------------------------------------------------------------------------
--     Quest 29287 has `RequiredItemId1` = 69836 but item with entry 69836 does
--     not exist, quest can't be done.
--     Table 'gameobject_loot_template' Entry 208630 Item 69836: item entry not
--     listed in `item_template` - skipped
--
-- Round 15 deferred these because nelt_world's ItemSparse holds only 6 of the
-- 20 (it is a partial table, ~54k of Cata's ~68k items).  Two other sources
-- between them cover all 20:
--   * the Cata client Item.db2 (build 15595) -> class / subclass / material /
--     displayid / inventorytype / sheath.  Its WDB2 header is 48 bytes with NO
--     index table when minid == maxid == 0, which is the case here; getting
--     that wrong shifts every record.
--   * the retail ItemSparse extract -> names and descriptions, so the strings
--     are authentic rather than invented.
--
-- Unblocks the Molten Front chain that needed them: Egg-stinction, Embergris,
-- Steal Magmolias, Fandral's Methods, The Flame Spider Queen, Living Obsidium,
-- Peaked Interest, Starting Young, The Bigger They Are, Aggressive Growth, The
-- Mysterious Seed, Planting Season, A Bitter Pill, How Hot, Singed Wings, Bye
-- Bye Burdy -- plus the Cinderweb Egg Sac / Fire Hawk Egg loot 124_ imported.
--
-- DISPLAY IDs: 11 of the 20 Cata display ids already exist in the fork's
-- ItemDisplayInfo and are kept.  The other 9 (the Cata-new 98xxx icons) do not,
-- and an unknown display makes the core log "does not have a correct display id
-- (N), must be 0" -- so those are set to 0.  The items function; they show no
-- icon until those ItemDisplayInfo rows + their BLPs are downported.
--
-- 18 of the 20 are class 12 (Quest, bind-on-pickup); 52976 is class 7 (Trade
-- Goods) and 56236 class 15 (Miscellaneous), both left unbound.
-- Generated by HyjalCata/tools/gen_mf_quest_items.py.
-- ---------------------------------------------------------------------------

"""


def main():
    want = set(WANT)
    items = load_item_db2(CATA_ITEM, want)
    gap = {i for i in WANT if i not in items}
    if gap:
        items.update(load_retail_item(RETAIL_ITEM, gap))
    missing = [i for i in WANT if i not in items]
    assert not missing, "in neither Cata Item.db2 nor retail Item.csv: %s" % missing
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
        report.append("  [%d] class=%-2d %-36r display=%s%s" % (
            i, it["cls"], name, disp,
            "" if disp else "   (Cata %d not in ItemDisplayInfo -> 0)" % it["displayid"]))

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "267_quest_items.sql")
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
