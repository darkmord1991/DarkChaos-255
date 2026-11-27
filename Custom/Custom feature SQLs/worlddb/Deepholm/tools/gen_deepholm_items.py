#!/usr/bin/env python3
# Generate 3.3.5 item_template rows for the missing Deepholm items by joining the
# retail Item.csv (class/subclass/invtype) + ItemSparse.csv (name/quality/levels/...).
import csv, sys

ITEM_CSV = r"C:/Users/flori/wow.export/Item.csv"
SPARSE_CSV = r"C:/Users/flori/wow.export/ItemSparse.csv"
OUT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/03_item_templates.sql"

QUEST = [58168,58169,58177,58254,58500,58501,58502,58845,58884,58885,58886,58944,58959,58965,
 59062,59123,59144,59323,60264,60266,60297,60382,60383,60487,60490,60501,60504,60574,60575,
 60745,60758,60767,60773,60791,60810,60814,60816,60831,60834,60835,60837,61399,61437,61440,64404]
VENDOR = [62321,62333,62342,62343,62344,62345,62346,62347]
IDS = set(QUEST) | set(VENDOR)

def load(path, key="ID"):
    out = {}
    with open(path, encoding="utf-8", newline="") as f:
        r = csv.DictReader(f, delimiter=";")
        for row in r:
            try:
                i = int(row[key])
            except (ValueError, KeyError):
                continue
            if i in IDS:
                out[i] = row
    return out

item = load(ITEM_CSV)
sparse = load(SPARSE_CSV)

# Cata Item.db2 (WDB2, build 15595) -> id -> DisplayInfoID (field 5) = real 3.3.5-compatible display id
import struct as _st
_d = open(r"k:/tmp/cata-dbc/Item.db2", "rb").read()
_rc,_fc,_rs,_ss = _st.unpack('<4I', _d[4:20]); _B = 48  # 48-byte WDB2 header, no index table
disp_of = { _st.unpack('<i',_d[_B+r*_rs:_B+r*_rs+4])[0]: _st.unpack('<i',_d[_B+r*_rs+20:_B+r*_rs+24])[0]
            for r in range(_rc) }

def iget(d, k, default=0):
    v = d.get(k, "")
    if v is None or v == "":
        return default
    try:
        return int(float(v))
    except ValueError:
        return default

def esc(s):
    return (s or "").replace("\\", "\\\\").replace("'", "''")

rows = []
missing = []
for i in sorted(IDS):
    it = item.get(i); sp = sparse.get(i)
    if not sp:
        missing.append(i); continue
    cls = iget(it, "ClassID") if it else 12
    sub = iget(it, "SubclassID") if it else 0
    invtype = iget(it, "InventoryType") if it else 0
    material = iget(sp, "Material", iget(it, "Material") if it else 0)
    sheath = iget(it, "SheatheType") if it else 0
    name = esc(sp.get("Display_lang", ""))
    quality = iget(sp, "OverallQualityID")
    ilvl = iget(sp, "ItemLevel")
    reqlvl = iget(sp, "RequiredLevel")
    stackable = iget(sp, "Stackable") or 1
    maxcount = iget(sp, "MaxCount")
    buyprice = iget(sp, "BuyPrice")
    sellprice = iget(sp, "SellPrice")
    bonding = iget(sp, "Bonding")
    startquest = iget(sp, "StartQuestID")
    # 3.3.5 item_template (only the columns we have data for; rest take table defaults)
    rows.append("({e},{cls},{sub},'{nm}',{disp},{q},0,1,{bp},{sp},{inv},{il},{rl},{mc},{st},{bd},{stq},{mat},{sh},0)".format(
        e=i, cls=cls, sub=sub, nm=name, disp=disp_of.get(i,0), q=quality, bp=buyprice, sp=sellprice, inv=invtype,
        il=ilvl, rl=reqlvl, mc=maxcount, st=stackable, bd=bonding, stq=startquest, mat=material, sh=sheath))

idlist = ",".join(str(i) for i in sorted(IDS))
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("""-- =====================================================================
-- Deepholm Downport  --  03  Item templates (missing quest + vendor items)
-- ---------------------------------------------------------------------
-- Generated from the retail wow.export extracts Item.csv + ItemSparse.csv
-- (Item.csv -> class/subclass/inventoryType; ItemSparse.csv -> name/quality/
-- levels/prices/stackable/bonding). Covers the 45 quest-referenced + 8 vendor
-- items that Deepholm content needs but acore_world.item_template lacks.
--
-- Notes / follow-ups:
--   * displayid = real DisplayInfoID from the Cata 4.3.4 client Item.db2 (field 5).
--     30 of these display ids already exist in Custom/CSV DBC/ItemDisplayInfo.csv;
--     the 23 that did not are added by 03b_itemdisplayinfo_additions.csv (icons).
--   * The 8 Inscriptions (class 0 / subclass 8) are purchasable but their
--     shoulder-enchant ON-USE spell lives in ItemEffect.db2 (not in these two
--     CSVs) -- add spellid_1/spelltrigger_1 once ItemEffect is extracted.
--   * Unspecified item_template columns fall back to table defaults.
-- =====================================================================

DELETE FROM `item_template` WHERE `entry` IN (""" + idlist + """);

INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,
 `InventoryType`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`startquest`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
""")
    f.write(",\n".join(rows) + ";\n")

print("generated rows:", len(rows))
print("missing from ItemSparse:", missing)
print("OUT:", OUT)
