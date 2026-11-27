#!/usr/bin/env python3
"""
gen_item_dbc_append_r48.py  --  Phase 2 of the map-750 gear clone (309_).

WHY THIS EXISTS
---------------
Every cloned item needs a row in Item.dbc. Without one, ObjectMgr::LoadItemTemplates
**silently drops the whole item_template row** -- no error, no warning, the item
simply does not exist in game. That is the single most expensive trap in this
project's item work, so this step is not optional and must land BEFORE the
worldserver restart that picks up 309_.

WHAT IT DOES
------------
Reads `dc_map750_item_clone` (created by 309_) and appends one Item.csv row per
clone, copying the SOURCE item's DBC row verbatim apart from the id -- so the
clone keeps the original's display, inventory type, material and sheathe, which
is exactly what "same item, rescaled" means.

If a source item has no Item.csv row of its own (there is a known tail of ~536
such item_template rows on this realm), the row is synthesised from
item_template instead and counted separately in the report -- those are worth
looking at, because the SOURCE item is invisible in game for the same reason.

Output is written SORTED BY ID: DBC records are looked up by binary search on
the id column, so an unsorted file breaks lookups for everything after the first
out-of-order row.

USAGE
-----
    python gen_item_dbc_append_r48.py \
        --dsn <host>,<user>,<password>[,<port>] \
        --csv "Custom/CSV DBC/Item.csv"

    # then compile and deploy:
    python Custom/Documentation/scripts/dbc-compile.py --only Item
    # Item.dbc is enGB-shadowed: deploy to patch-4 AND patch-enGB-3, and to the
    # server's own data/dbc -- the server reads Item.dbc too.

The --dsn format is comma-separated to match gen_zone_gear_armor_dmg.py.
Writes <csv>.bak before touching anything; --dry-run reports and writes nothing.
"""
import argparse
import csv
import os
import shutil
import sys

FIELDS = ["ID", "ClassID", "SubclassID", "Sound_Override_Subclassid",
          "Material", "DisplayInfoID", "InventoryType", "SheatheType"]

CLONE_QUERY = """
SELECT m.src_entry, m.clone_entry, m.src_kind,
       it.class AS ClassID, it.subclass AS SubclassID, it.Material,
       it.displayid AS DisplayInfoID, it.InventoryType, it.sheath AS SheatheType
FROM dc_map750_item_clone m
JOIN item_template it ON it.entry = m.clone_entry
ORDER BY m.clone_entry
"""


def rows_from_mysql(dsn, db):
    import pymysql
    parts = dsn.split(",")
    if len(parts) < 3:
        sys.exit("--dsn must be host,user,password[,port]")
    host, user, pw = parts[0], parts[1], parts[2]
    port = int(parts[3]) if len(parts) > 3 else 3306
    conn = pymysql.connect(host=host, user=user, password=pw, port=port,
                           database=db, cursorclass=pymysql.cursors.DictCursor)
    with conn.cursor() as cur:
        cur.execute(CLONE_QUERY)
        return cur.fetchall()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", required=True, help="host,user,password[,port]")
    ap.add_argument("--db", default="acore_world")
    ap.add_argument("--csv", required=True, help="path to Custom/CSV DBC/Item.csv")
    ap.add_argument("--out", default=None, help="default: rewrite --csv in place")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    clones = rows_from_mysql(a.dsn, a.db)
    if not clones:
        sys.exit("dc_map750_item_clone is empty -- apply 309_ first.")

    with open(a.csv, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        existing = {}
        order = []
        for row in reader:
            existing[int(row["ID"])] = row
            order.append(int(row["ID"]))

    added, skipped, synthesised, missing_src = 0, 0, 0, []
    for c in clones:
        cid, sid = int(c["clone_entry"]), int(c["src_entry"])
        if cid in existing:
            skipped += 1
            continue
        src = existing.get(sid)
        if src is not None:
            row = dict(src)
            row["ID"] = str(cid)
        else:
            # No DBC row for the source either -- synthesise from item_template.
            missing_src.append(sid)
            synthesised += 1
            row = {
                "ID": str(cid),
                "ClassID": str(c["ClassID"]),
                "SubclassID": str(c["SubclassID"]),
                "Sound_Override_Subclassid": "-1",
                "Material": str(c["Material"]),
                "DisplayInfoID": str(c["DisplayInfoID"]),
                "InventoryType": str(c["InventoryType"]),
                "SheatheType": str(c["SheatheType"]),
            }
        existing[cid] = row
        added += 1

    print(f"clones in map : {len(clones)}")
    print(f"added         : {added}")
    print(f"already there : {skipped}")
    print(f"synthesised   : {synthesised} (source item had no Item.dbc row of its own)")
    if missing_src:
        head = ", ".join(str(x) for x in sorted(set(missing_src))[:15])
        print(f"  source ids without a DBC row: {head}"
              f"{' ...' if len(set(missing_src)) > 15 else ''}")
        print("  NOTE: those SOURCE items are themselves invisible in game for the")
        print("        same reason -- worth a separate pass.")

    if a.dry_run:
        print("dry run -- nothing written")
        return

    out = a.out or a.csv
    if out == a.csv and not os.path.exists(a.csv + ".bak"):
        shutil.copy2(a.csv, a.csv + ".bak")
        print(f"backup        : {a.csv}.bak")

    # DBC lookups are a binary search on the id column -- write sorted.
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS, quoting=csv.QUOTE_ALL)
        w.writeheader()
        for i in sorted(existing):
            w.writerow({k: existing[i].get(k, "0") for k in FIELDS})
    print(f"wrote         : {out}  ({len(existing)} rows)")


if __name__ == "__main__":
    main()
