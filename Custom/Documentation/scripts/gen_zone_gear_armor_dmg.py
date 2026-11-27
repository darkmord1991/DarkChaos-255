#!/usr/bin/env python3
"""
gen_zone_gear_armor_dmg.py  --  Phase 2 of the zone gear stat-fill.

Cata stores neither `armor` nor weapon `dmg_min/dmg_max` in the item data --
they are DERIVED from ItemLevel + Quality + slot via a set of DBC curves. This
computes them from the real Cata 4.3.4 DBCs and emits an UPDATE .sql for the
items whose primary stats were already filled by HyjalCata/99_zone_gear_statfill.sql.

INPUTS
------
1. --dbc-dir : a folder holding these Cata DBCs (extract from the Cata client
   K:\\UntouchedClients\\Cata\\Data\\enUS\\locale-enUS.MPQ with mpq_stormlib_extract.py):
     ItemDamageOneHand ItemDamageTwoHand ItemDamageOneHandCaster
     ItemDamageTwoHandCaster ItemDamageRanged ItemDamageWand
     ItemArmorTotal ItemArmorQuality ItemArmorShield ArmorLocation   (.dbc)
2. --items-csv : one row per item to compute, columns (header required):
     entry,ItemLevel,Quality,class,subclass,InventoryType,delay,caster
   Export it from acore_world with (this is exactly the 99_ target set):
     SELECT it.entry, it.ItemLevel, it.Quality, it.class, it.subclass,
            it.InventoryType, it.delay,
            (it.stat_type1=5 OR it.stat_type2=5 OR it.stat_type3=5
             OR it.stat_type4=5 OR it.stat_type5=5) AS caster
     FROM item_template it
     WHERE it.entry IN (
       SELECT DISTINCT lt.item FROM creature_loot_template lt
       WHERE lt.Entry IN (SELECT DISTINCT ct.lootid FROM creature_template ct
         WHERE ct.lootid>0 AND ct.entry IN (SELECT DISTINCT id FROM creature WHERE map IN (750,861))))
       AND it.class IN (2,4) AND it.InventoryType>0 AND it.ItemLevel>0
       AND (it.armor=0 AND it.dmg_min1=0);   -- only still-unfilled
   (dump as CSV with a header row.)

OUTPUT : --out .sql  --  idempotent UPDATEs (armor OR dmg_min1/dmg_max1/dmg_type1).

FORMULA (wowdev, Cata):
  weapon dps = ItemDamage<Type>[ItemLevel][Quality];  avg = dps*delay/1000
               dmg_min = round(avg*0.85), dmg_max = round(avg*1.15)
  armor      = round( ItemArmorTotal[ilvl][armorType]
                      * ItemArmorQuality[ilvl][Quality]
                      * ArmorLocation[InventoryType][armorType] )
  shield     = round( ItemArmorShield[ilvl][Quality] )
"""
import struct, argparse, csv, os

def read_dbc(path):
    d = open(path, "rb").read()
    magic, rc, fc, rs, sbs = struct.unpack("<4siiii", d[:20])
    assert magic == b"WDBC", path
    rows = []
    for i in range(rc):
        r = d[20 + i*rs : 20 + (i+1)*rs]
        rows.append((struct.unpack("<%di" % (rs//4), r),
                     struct.unpack("<%df" % (rs//4), r)))
    return rows  # list of (ints, floats)

def load(dbc_dir, name):
    return read_dbc(os.path.join(dbc_dir, name + ".dbc"))

ITEMS_QUERY = """
SELECT it.entry, s.Itemlevel AS ItemLevel, s.Quality, it.class, it.subclass,
       it.InventoryType, s.Delay AS delay,
       (s.Stat_Type1=5 OR s.Stat_Type2=5 OR s.Stat_Type3=5 OR s.Stat_Type4=5 OR s.Stat_Type5=5) AS caster
FROM acore_world.item_template it
JOIN nelt_world.`db_item-sparse_15595` s ON s.ID = it.entry
WHERE it.class IN (2,4) AND it.InventoryType>0 AND it.ItemLevel>0
  AND it.armor=0 AND it.dmg_min1=0
  AND it.entry IN (
    SELECT DISTINCT lt.item FROM acore_world.creature_loot_template lt
    WHERE lt.Entry IN (SELECT DISTINCT ct.lootid FROM acore_world.creature_template ct
      WHERE ct.lootid>0 AND ct.entry IN (SELECT DISTINCT id FROM acore_world.creature WHERE map IN (750,861))))
"""

def rows_from_mysql(dsn):
    # dsn = "host,user,password[,port]" -- runs the export query directly.
    # NOTE the WHERE keys on it.ItemLevel>0, so run AFTER 99_zone_gear_statfill.sql
    # has filled the shells (and after MoltenFront applies, to include MF gear).
    import pymysql
    parts = dsn.split(","); host, user, pw = parts[0], parts[1], parts[2]
    port = int(parts[3]) if len(parts) > 3 else 3306
    c = pymysql.connect(host=host, user=user, password=pw, port=port, cursorclass=pymysql.cursors.DictCursor)
    with c.cursor() as cur:
        cur.execute(ITEMS_QUERY); return cur.fetchall()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dbc-dir", required=True)
    ap.add_argument("--items-csv", help="CSV of items (or use --mysql)")
    ap.add_argument("--mysql", help='connect + run the export query: "host,user,password[,port]"')
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    # damage tables keyed by ItemLevel (field 8), value = dps floats[quality 0..6] at flt[1..7]
    dmg = {}
    for t in ("OneHand","TwoHand","OneHandCaster","TwoHandCaster","Ranged","Wand"):
        d = {}
        for ints, flts in load(a.dbc_dir, "ItemDamage"+t):
            d[ints[8]] = flts[1:8]
        dmg[t] = d
    # ItemArmorTotal: key ItemLevel (int field1), value [cloth,leather,mail,plate] flt[2..5]
    atot = {ints[1]: flts[2:6] for ints, flts in load(a.dbc_dir, "ItemArmorTotal")}
    # ItemArmorQuality: key ItemLevel (int field8), qmod flt[1..7]
    aqual = {ints[8]: flts[1:8] for ints, flts in load(a.dbc_dir, "ItemArmorQuality")}
    # ItemArmorShield: key ItemLevel (int field1), armor flt[2..8]
    ashield = {ints[1]: flts[2:9] for ints, flts in load(a.dbc_dir, "ItemArmorShield")}
    # ArmorLocation: key InventoryType (int field0), [cloth,leather,mail,plate] flt[1..4]
    aloc = {ints[0]: flts[1:5] for ints, flts in load(a.dbc_dir, "ArmorLocation")}

    RANGED = {2,3,18}   # bow, gun, crossbow
    TWOH   = {1,5,6,8,10}  # axe2h, mace2h, polearm, sword2h, staff
    ONEH   = {0,4,7,13,15} # axe1h, mace1h, sword1h, fist, dagger

    # ArmorLocation.dbc only defines the canonical slots. InventoryType 20 (Robe)
    # is a chest variant and carries no row of its own -- all-zero, which would
    # yield armor=0. Blizzard treats it as InventoryType 5 (Chest).
    ARMOR_SLOT = {20: 5}

    def wtype(sub, caster):
        if sub in RANGED: return "Ranged"
        if sub == 19:     return "Wand"
        if sub in TWOH:   return "TwoHandCaster" if caster else "TwoHand"
        if sub in ONEH:   return "OneHandCaster" if caster else "OneHand"
        return None       # thrown(16)/fishing(20) -> skip

    if a.mysql:
        records = rows_from_mysql(a.mysql)
    elif a.items_csv:
        with open(a.items_csv, newline="") as f:
            records = list(csv.DictReader(f))
    else:
        ap.error("need --items-csv or --mysql")

    out = []
    n_w = n_a = n_skip = 0
    if True:
        for row in records:
            e   = int(row["entry"]); ilvl = int(row["ItemLevel"])
            q   = max(0, min(6, int(row["Quality"])))
            cls = int(row["class"]); sub = int(row["subclass"])
            inv = int(row["InventoryType"]); delay = int(row["delay"] or 0)
            caster = str(row.get("caster","0")).strip() in ("1","True","true")
            if cls == 2:  # weapon
                t = wtype(sub, caster)
                if not t or ilvl not in dmg[t] or delay <= 0: n_skip += 1; continue
                dps = dmg[t][ilvl][q]
                avg = dps * delay / 1000.0
                mn, mx = round(avg*0.85), round(avg*1.15)
                out.append(f"UPDATE `item_template` SET `dmg_min1`={mn},`dmg_max1`={mx},`dmg_type1`=0 WHERE `entry`={e};")
                n_w += 1
            elif cls == 4:  # armor
                if sub == 6:  # shield
                    if ilvl not in ashield: n_skip += 1; continue
                    arm = round(ashield[ilvl][q])
                elif sub in (1,2,3,4) and ARMOR_SLOT.get(inv, inv) in aloc \
                        and ilvl in atot and ilvl in aqual:
                    slot = ARMOR_SLOT.get(inv, inv)
                    arm = round(atot[ilvl][sub-1] * aqual[ilvl][q] * aloc[slot][sub-1])
                else:
                    n_skip += 1; continue   # neck/ring/trinket (subclass 0) -> no armor
                if arm <= 0:
                    # ArmorLocation has no modifier for this slot -- emitting 0 would
                    # re-create the very bug this script exists to fix.
                    n_skip += 1; continue
                out.append(f"UPDATE `item_template` SET `armor`={arm} WHERE `entry`={e};")
                n_a += 1

    with open(a.out, "w") as f:
        f.write("-- generated by gen_zone_gear_armor_dmg.py -- Cata-DBC-derived armor/damage.\n")
        f.write("-- Run AFTER HyjalCata/99_zone_gear_statfill.sql. Idempotent.\n")
        f.write("\n".join(out) + "\n")
    print(f"weapons={n_w} armor={n_a} skipped={n_skip} -> {a.out}")

if __name__ == "__main__":
    main()
