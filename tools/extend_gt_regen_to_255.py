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
  * flat    : hold the anchor-level value to 255     (HP, combat ratings, crit)
HP uses anchor 100 (its data is flat 70-100 anyway); mana/ratings/crit use 80.
"Flat" for combat ratings = rating stays as effective at 255 as at 80.

Layout / indexing
-----------------
Each table is `blocks` contiguous level-runs (11 player classes, or 32 combat
ratings). The CSV "ID" column is 1-based (ID = block*levels + level); the binary
DBC and the world `*_dbc` tables are 0-based (DB_ID = CSV_ID - 1).

Outputs: corrected 255-level CSVs (1-based) in the CSV dirs, and one world-DB
SQL update (0-based) in data/sql/updates/pending_db_world/.
"""

import csv
import shutil
import time
from pathlib import Path

OLD_LEVELS = 100
NEW_LEVELS = 255

ROOT = Path(__file__).resolve().parents[1]
PRISTINE_DIR = ROOT / "Custom" / "CSV DBC" / "GT_WOTLK"
CSV_OUT_DIRS = [ROOT / "Custom" / "CSV DBC", ROOT / "Custom" / "CSV DBC" / "Extended_255"]
SQL_OUT_DIR = ROOT / "data" / "sql" / "updates" / "pending_db_world"

# (csv basename, world db *_dbc table, blocks, mode, anchor_level)
TABLES = [
    ("GtOCTRegenHP",        "gtoctregenhp_dbc",        11, "flat",    100),
    ("GtRegenHPPerSpt",     "gtregenhpperspt_dbc",     11, "flat",    100),
    ("GtRegenMPPerSpt",     "gtregenmpperspt_dbc",     11, "mp_sqrt",  80),
    ("GtCombatRatings",     "gtcombatratings_dbc",     32, "flat",     80),
    ("GtChanceToMeleeCrit", "gtchancetomeleecrit_dbc", 11, "flat",     80),
    ("GtChanceToSpellCrit", "gtchancetospellcrit_dbc", 11, "flat",     80),
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


def fmt_csv(v):
    if v == 0:
        return "0"
    return f"{v:.6f}".rstrip("0").rstrip(".").replace(".", ",")


def fmt_sql(v):
    if v == 0:
        return "0"
    return f"{v:.6f}".rstrip("0").rstrip(".")


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


def gen_value(base, block, level, mode, anchor):
    if level <= anchor:
        return base[block][level]
    if mode == "mp_sqrt":
        a = base[block][anchor]
        return a * (anchor / level) ** 0.5 if a > 0.0 else 0.0
    return base[block][anchor]                     # flat hold


def write_csv(path, base, blocks, mode, anchor):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(["ID", "Data"])
        for block in range(blocks):
            for level in range(1, NEW_LEVELS + 1):
                csv_id = block * NEW_LEVELS + level            # 1-based
                w.writerow([str(csv_id), fmt_csv(gen_value(base, block, level, mode, anchor))])


def sql_block(table, base, blocks, mode, anchor, per_line=16):
    note = "sqrt(80/L) curve from L80" if mode == "mp_sqrt" else f"flat hold from L{anchor}"
    rows = []
    for block in range(blocks):
        for level in range(1, NEW_LEVELS + 1):
            db_id = block * NEW_LEVELS + (level - 1)           # 0-based
            rows.append((db_id, gen_value(base, block, level, mode, anchor)))
    out = [
        f"-- {table}: retail 1..{anchor} preserved + {note} (0-based, {blocks} blocks x {NEW_LEVELS})",
        f"DELETE FROM `{table}`;",
        f"INSERT INTO `{table}` (`ID`, `Data`) VALUES",
    ]
    tuples = [f"({i}, {fmt_sql(v)})" for i, v in rows]
    for n in range(0, len(tuples), per_line):
        term = ";" if n + per_line >= len(tuples) else ","
        out.append("    " + ", ".join(tuples[n:n + per_line]) + term)
    return "\n".join(out)


def main():
    print(f"Reading pristine extracts from {PRISTINE_DIR}")
    bases = {name: read_pristine(name, blocks) for name, _, blocks, _, _ in TABLES}

    for name, _, blocks, mode, anchor in TABLES:
        for d in CSV_OUT_DIRS:
            write_csv(d / f"{name}.csv", bases[name], blocks, mode, anchor)
            print(f"  CSV {d / (name + '.csv')}  ({blocks * NEW_LEVELS} rows)")

    # complete the set with the non-level-indexed support tables (verbatim)
    for name in COPY_TABLES:
        src = PRISTINE_DIR / f"{name}.csv"
        for d in CSV_OUT_DIRS:
            d.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, d / f"{name}.csv")
            print(f"  CSV (verbatim) {d / (name + '.csv')}")

    SQL_OUT_DIR.mkdir(parents=True, exist_ok=True)
    sql_path = SQL_OUT_DIR / f"rev_{time.time_ns()}.sql"
    blocks_sql = [sql_block(t, bases[n], b, m, a) for n, t, b, m, a in TABLES]
    header = (
        "-- DarkChaos: rebuild level-indexed player GT* tables for level 255.\n"
        "-- Source: pristine retail GT_WOTLK extracts (clean per-block data).\n"
        "-- Fixes: regen collapse/zero-Druid + combat-rating divide-by-zero (NaN crit).\n"
        "-- Mana ratio L>80 = anchor(L80)*(80/L)^0.5; HP/ratings/crit held flat past anchor.\n"
        f"-- 0-based ID = block*{NEW_LEVELS} + (level-1).\n"
    )
    sql_path.write_text(header + "\n" + "\n\n".join(blocks_sql) + "\n", encoding="utf-8")
    total = sum(b * NEW_LEVELS for _, _, b, _, _ in TABLES)
    print(f"  SQL {sql_path}  ({total} rows across {len(TABLES)} tables)")


if __name__ == "__main__":
    main()
