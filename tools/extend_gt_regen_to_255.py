#!/usr/bin/env python3
"""
Rebuild the level-dependent player GT* game tables for a level-255 server.

Covers two bug families, both rooted in the core indexing GT tables at stride
GT_MAX_LEVEL (255) while the shipped tables only had 100 levels per block:

  REGEN (spirit -> HP/MP):
    * GtOCTRegenHP, GtRegenHPPerSpt  - HP-per-spirit (flat at high level)
    * GtRegenMPPerSpt               - MP-per-spirit; mana = sqrt(Int)*Spi*ratio
    The class-block divisor bug (GetGtClassLevelIndex / MAX_CLASSES) zeroed
    low-level Druid regen; the 100-level data also clamped endgame mana to the
    retail L100 cliff (~0).

  COMBAT RATINGS / CRIT (rating/stat -> %):
    * GtCombatRatings               - rating per 1% (DIVISOR in GetRatingMultiplier)
    * GtChanceToMeleeCrit           - melee/ranged crit + dodge per Agility
    * GtChanceToSpellCrit           - spell crit per Intellect
    Because GetRatingMultiplier divides by GtCombatRatings, a mis-strided read of
    a zero-padding row (ratings 25..31) produced classScalar/0 = +Inf, and
    critRating(0)*Inf = NaN -> spell crit shows "-1.#J%" (Inf/NaN) on the sheet.

Source of truth: pristine retail extracts in `Custom/CSV DBC/GT_WOTLK/`
(verified byte-identical to the clean world `*_dbc` tables).

Curves (levels 81-255), all anchored on the last clean retail level (80):
  * mp_sqrt : ratio(L) = ratio(80) * sqrt(80 / L)   (proportional; chosen for regen)
  * flat    : hold the anchor-level value to 255     (HP regen, NPC mana cost, barber)
  * gear    : value(80) * gear growth(L) * relief(L)  (combat ratings: rating per 1%)
  * stat    : value(80) / primary stat growth(L)     (crit per agility / intellect)
HP uses anchor 100 (its data is flat 70-100 anyway); mana/ratings/crit use 80.

"gear" and "stat" (2026-11-15) replace the earlier flat hold for ratings and crit. With a
flat table every rating point kept its level-80 worth while the gear ladder carries 4.4
times the rating by level 160, so crit from rating went from about 7% at 80 to about 30%
at 160. Following the gear curve keeps the percentage a character gets from gear of its
own level where it is at 80. Both growth curves come from tools/balance/gen_reference.py,
the same reference the server's dc_balance_reference table is generated from; levels 1-80
are never changed.

relief(L) (2026-11-24) gives part of that growth back: 1.0 at 80, falling linearly to
RATING_COST_SHARE at RATING_RELIEF_FULL_AT and held there. The meter showed crit, haste and
armour penetration falling well below their level-80 values above 80; the owner chose to close
the gap partly here and partly on the items (tools/balance/gen_item_ratings.py raises every item
above 80 to the rating share of a stock WotLK item of the same budget). Together, gear of a
character's own level gives about 1 / RATING_COST_SHARE times the level-80 percentages.

Layout / indexing
-----------------
Each table is `blocks` contiguous level-runs (11 player classes, 32 combat
ratings, or 1 for the plain level-indexed tables). The CSV "ID" column is 1-based
(ID = block*levels + level); the binary DBC and the world `*_dbc` tables are
0-based (DB_ID = CSV_ID - 1).

Which layer the server actually reads
-------------------------------------
The world `*_dbc` TABLES are the only server-side source. GT .dbc files are pure
float arrays with no ID column (fieldCount 1, recsize 4 - true of stock
AzerothCore v19 too), while every GT format string in DBCfmt.h is "df" (strlen 2).
DBCFileLoader::AutoProduceData starts with `if (strlen(format) != fieldCount)
return nullptr;`, so the file load always fails and LoadDBC falls through to
LoadFromDB. No error is logged because GetNumRows() is non-zero afterwards.
=> Fixing the server means fixing the SQL. The .dbc files matter only to the
   CLIENT, which computes the paper doll locally (PaperDollFrame.lua calls
   GetUnitHealthRegenRateFromSpirit / GetUnitManaRegenRateFromSpirit).
   (Corrected 2026-11-15: the file does load -- its format string is "f", one field;
   "df" is the database format. The world *_dbc rows then replace every row by id,
   so the practical conclusion is unchanged: the SQL decides, and a deleted DB row
   falls back to the file's value.)

Do NOT compile these with csv2wdbc.py: its WDBX definition declares
`ID int, Data float` (2 fields / 8 bytes), which is the wrong binary layout for
a GT table. write_dbc() below emits the correct 1-field / 4-byte form directly
from the in-memory values, which also keeps the comma-decimal CSVs out of the
DBC path entirely.

GtOCTRegenMP is intentionally absent: its store, format string, struct and
lookup are all commented out in the core, so it is dead data. Do not "fix" it.

Outputs: corrected 255-level CSVs (1-based) in the CSV dirs, the client .dbc
files in Custom/DBCs/, and one world-DB SQL update (0-based) in
data/sql/updates/pending_db_world/ (or wherever --sql-out points).

Usage:
    python tools/extend_gt_regen_to_255.py                 # every table
    python tools/extend_gt_regen_to_255.py --only GtCombatRatings,GtChanceToMeleeCrit --sql-out <file.sql>
"""

import argparse
import csv
import shutil
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "balance"))
import gen_reference  # noqa: E402  (tools/balance/gen_reference.py)

OLD_LEVELS = 100
NEW_LEVELS = 255

# Share of the gear-ladder growth that combat ratings keep above 80 (mode "gear"); the ramp from
# 1.0 at the anchor keeps level 81 next to level 80.
RATING_COST_SHARE = 0.8
RATING_RELIEF_FULL_AT = 90

ROOT = Path(__file__).resolve().parents[1]
PRISTINE_DIR = ROOT / "Custom" / "CSV DBC" / "GT_WOTLK"
CSV_OUT_DIRS = [ROOT / "Custom" / "CSV DBC", ROOT / "Custom" / "CSV DBC" / "Extended_255"]
DBC_OUT_DIR = ROOT / "Custom" / "DBCs"
SQL_OUT_DIR = ROOT / "data" / "sql" / "updates" / "pending_db_world"

# (csv basename, world db *_dbc table, blocks, mode, anchor_level)
TABLES = [
    ("GtOCTRegenHP",         "gtoctregenhp_dbc",         11, "flat",    100),
    ("GtRegenHPPerSpt",      "gtregenhpperspt_dbc",      11, "flat",    100),
    ("GtRegenMPPerSpt",      "gtregenmpperspt_dbc",      11, "mp_sqrt",  80),
    ("GtCombatRatings",      "gtcombatratings_dbc",      32, "gear",     80),
    ("GtChanceToMeleeCrit",  "gtchancetomeleecrit_dbc",  11, "stat",     80),
    ("GtChanceToSpellCrit",  "gtchancetospellcrit_dbc",  11, "stat",     80),
    # Plain level-indexed (single block): LookupEntry(level - 1) in
    # SpellInfo::CalcPowerCost and Player::GetBarberShopCost respectively, both
    # of which returned nullptr above level 100.
    ("GtNPCManaCostScaler",  "gtnpcmanacostscaler_dbc",   1, "flat",    100),
    ("GtBarberShopCostBase", "gtbarbershopcostbase_dbc",  1, "flat",    100),
]

# Non-level-indexed GT tables: copied verbatim from pristine so a DBC rebuilt from
# these dirs is complete. They are NOT affected by the 255 stride and the world
# *_dbc copies are already correct, so they need no extension and no SQL.
# GtOCTClassCombatRatingScalar is the numerator in GetRatingMultiplier and was
# missing from the CSV dirs entirely.
COPY_TABLES = ["GtOCTClassCombatRatingScalar", "GtChanceToMeleeCritBase", "GtChanceToSpellCritBase"]


def parse_float(s):
    s = (s or "").strip()
    return float(s.replace(",", ".")) if s else 0.0


# Decimals carried by the CSV and SQL text. Crit per agility is around 0.00004 above level 80,
# so six decimals would round away several percent of the value.
DECIMALS = 9


def fmt_csv(v):
    # Dot decimals: the main-folder CSVs were moved to them, and a comma is not a number to csv2wdbc.
    return fmt_sql(v)


def fmt_sql(v):
    if v == 0:
        return "0"
    return f"{v:.{DECIMALS}f}".rstrip("0").rstrip(".")


def read_pristine(name, blocks):
    """base[block][level] (1..100) of floats from a pristine 1-based CSV."""
    base = [[0.0] * (OLD_LEVELS + 1) for _ in range(blocks)]
    with open(PRISTINE_DIR / f"{name}.csv", encoding="utf-8") as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            if len(row) < 2:
                continue
            cid = int(row[0])                      # 1-based: block*100 + level
            block = (cid - 1) // OLD_LEVELS
            level = (cid - 1) % OLD_LEVELS + 1
            if 0 <= block < blocks:
                base[block][level] = parse_float(row[1])
    return base


def quantize(v):
    """Round to the 6 decimals fmt_csv/fmt_sql serialise.

    The CSV and SQL carry text with DECIMALS decimals while the DBC carries a raw
    float32, so an unrounded generated value would leave the client holding a
    slightly different number than the server. Round once here and every layer
    is identical by construction.
    """
    return float(f"{v:.{DECIMALS}f}") if v else 0.0


def rating_relief(level, anchor):
    ramp = min(1.0, (level - anchor) / (RATING_RELIEF_FULL_AT - anchor))
    return 1.0 - (1.0 - RATING_COST_SHARE) * ramp


def gen_value(base, block, level, mode, anchor):
    if level <= anchor:
        return base[block][level]
    a = base[block][anchor]
    if mode == "mp_sqrt":
        return quantize(a * (anchor / level) ** 0.5) if a > 0.0 else 0.0
    if mode == "gear":
        return quantize(a * gen_reference.gear_growth(level) * rating_relief(level, anchor))
    if mode == "stat":
        return quantize(a / gen_reference.stat_growth(level))
    return a                                       # flat hold


def write_csv(path, base, blocks, mode, anchor):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(["ID", "Data"])
        for block in range(blocks):
            for level in range(1, NEW_LEVELS + 1):
                csv_id = block * NEW_LEVELS + level            # 1-based
                w.writerow([str(csv_id), fmt_csv(gen_value(base, block, level, mode, anchor))])


def dbc_name(csv_name):
    """GtRegenMPPerSpt -> gtRegenMPPerSpt.dbc (client/server filename casing)."""
    return csv_name[0].lower() + csv_name[1:] + ".dbc"


def write_dbc(path, base, blocks, mode, anchor):
    """Write the client-side WDBC.

    GT game tables carry no ID column: the record index IS the id. Header is
    magic + recordCount, fieldCount=1, recordSize=4, stringBlockSize=1, followed
    by the float array and a single null byte (offset 0 = empty string).
    Verified against pristine stock AzerothCore v19 gt*.dbc.
    """
    values = [gen_value(base, block, level, mode, anchor)
              for block in range(blocks)
              for level in range(1, NEW_LEVELS + 1)]

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"WDBC")
        f.write(struct.pack("<4I", len(values), 1, 4, 1))
        f.write(struct.pack("<%df" % len(values), *values))
        f.write(b"\x00")
    return len(values)


def sql_block(table, base, blocks, mode, anchor, per_line=5):
    note = {"mp_sqrt": "sqrt(80/L) curve from L80",
            "gear": (f"L{anchor} value times gear growth above L{anchor}, x{RATING_COST_SHARE} from "
                     f"L{RATING_RELIEF_FULL_AT} (ramped)"),
            "stat": f"L{anchor} value divided by primary stat growth above L{anchor}"
            }.get(mode, f"flat hold from L{anchor}")
    rows = []
    for block in range(blocks):
        for level in range(1, NEW_LEVELS + 1):
            db_id = block * NEW_LEVELS + (level - 1)           # 0-based
            rows.append((db_id, gen_value(base, block, level, mode, anchor)))
    out = [
        f"-- {table}: retail 1..{anchor} preserved + {note}",
        f"-- (0-based, {blocks} blocks x {NEW_LEVELS})",
        f"DELETE FROM `{table}`;",
        f"INSERT INTO `{table}` (`ID`, `Data`) VALUES",
    ]
    tuples = [f"({i}, {fmt_sql(v)})" for i, v in rows]
    for n in range(0, len(tuples), per_line):
        term = ";" if n + per_line >= len(tuples) else ","
        out.append("    " + ", ".join(tuples[n:n + per_line]) + term)
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description="Rebuild the level-indexed GT* game tables for level 255.")
    parser.add_argument("--only", help="comma-separated table names (as in TABLES); default is every table")
    parser.add_argument("--sql-out", type=Path, help="write the SQL here instead of pending_db_world")
    args = parser.parse_args()

    tables = TABLES
    if args.only:
        wanted = {name.strip() for name in args.only.split(",")}
        unknown = wanted - {name for name, _, _, _, _ in TABLES}
        assert not unknown, f"unknown table(s): {sorted(unknown)}"
        tables = [row for row in TABLES if row[0] in wanted]

    print(f"Reading pristine extracts from {PRISTINE_DIR}")
    bases = {name: read_pristine(name, blocks) for name, _, blocks, _, _ in tables}

    for name, _, blocks, mode, anchor in tables:
        for d in CSV_OUT_DIRS:
            write_csv(d / f"{name}.csv", bases[name], blocks, mode, anchor)
            print(f"  CSV {d / (name + '.csv')}  ({blocks * NEW_LEVELS} rows)")

        dbc_path = DBC_OUT_DIR / dbc_name(name)
        n = write_dbc(dbc_path, bases[name], blocks, mode, anchor)
        print(f"  DBC {dbc_path}  ({n} records)")

    # complete the set with the non-level-indexed support tables (verbatim)
    for name in ([] if args.only else COPY_TABLES):
        src = PRISTINE_DIR / f"{name}.csv"
        for d in CSV_OUT_DIRS:
            d.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, d / f"{name}.csv")
            print(f"  CSV (verbatim) {d / (name + '.csv')}")

    sql_path = args.sql_out or (SQL_OUT_DIR / f"rev_{time.time_ns()}.sql")
    sql_path.parent.mkdir(parents=True, exist_ok=True)
    blocks_sql = [sql_block(t, bases[n], b, m, a) for n, t, b, m, a in tables]
    header = (
        "-- DarkChaos: rebuild level-indexed player GT* tables for level 255"
        " (generated by tools/extend_gt_regen_to_255.py).\n"
        "-- Source: pristine retail GT_WOTLK extracts (clean per-block data). Levels 1-80 are the retail values.\n"
        "-- Above 80: combat ratings cost more per 1% in step with the gear ladder, less a relief of\n"
        f"-- {1 - RATING_COST_SHARE:.0%} reached at level {RATING_RELIEF_FULL_AT}, and crit per agility / intellect"
        " falls in step\n"
        "-- with primary stats (both curves from tools/balance/gen_reference.py). Mana regen per spirit follows\n"
        "-- anchor(L80)*(80/L)^0.5; HP regen, NPC mana cost and barber cost are held flat past their anchor.\n"
        f"-- Tables in this file: {', '.join(t for _, t, _, _, _ in tables)}.\n"
        f"-- 0-based ID = block*{NEW_LEVELS} + (level-1). Re-running replaces every row of those tables.\n"
        "-- Apply to acore_world, then restart the worldserver. The clients need the matching gt*.dbc files.\n"
    )
    with open(sql_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(header + "\n" + "\n\n".join(blocks_sql) + "\n")
    total = sum(b * NEW_LEVELS for _, _, b, _, _ in tables)
    print(f"  SQL {sql_path}  ({total} rows across {len(tables)} tables)")


if __name__ == "__main__":
    main()
