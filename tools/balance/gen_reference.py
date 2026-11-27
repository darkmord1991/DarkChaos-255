#!/usr/bin/env python3
"""
Build the rows of `dc_balance_reference`: per-level growth factors that every
DarkChaos scaling rule above level 80 reads.

The rule (owner's decision, 2026-11-15): levels 1-80 stay WotLK. Above 80 each
ratio keeps the value it has at 80 -- pet damage against owner damage, rage per
hit, and so on. A ratio can only be held if something says how much the owner
side grew, and that is this table. Level 80 is 1.0 in every column.

    ref_item_level  item level of the questing gear a character of that level wears
    gear_growth     stamina / primary stat on one armour piece, against level 80
    weapon_growth   weapon damage per second, against level 80
    health_growth   reference player health, against level 80
    melee_growth    size of one white melee hit, against level 80

The curves are MEASURED, not designed: the anchor points below were read from
`item_template` on 2026-11-14 (green and blue items of the DarkChaos gear ladder,
entries 420000-422031, plus stock level-80 greens and blues). When the ladder
changes, re-measure the anchors, re-run this script and re-apply the SQL files
that derive from the table (they compute from the level-80 row, so re-running
them is safe).

Levels 161-255 hold the level-160 item level: no gear exists above 160 yet, so
only the base-stat part keeps growing there.

Usage:
    python tools/balance/gen_reference.py --print
    python tools/balance/gen_reference.py --out <file.sql>
"""

import argparse
import math
from pathlib import Path

MIN_LEVEL = 80
MAX_LEVEL = 255

# ---------------------------------------------------------------------------
# Knobs. Everything a balance pass may want to change is in this block.
# ---------------------------------------------------------------------------

# (level, item level) of questing gear, linear in between.
# 80 is the average of the level-80 greens and blues on this server (stock
# item level 187-200 plus the first ladder pieces); 90-160 is the gear ladder.
REF_ITEM_LEVEL = [
    (80, 217),
    (90, 328),
    (100, 362),
    (113, 388),
    (130, 430),
    (160, 520),
    (255, 520),
]

# (item level, one-hand weapon damage per second), green and blue weapons.
# Interpolated on a log scale; outside the range the nearest segment's slope is kept.
WEAPON_DPS = [
    (217, 131.7),
    (320, 327.4),
    (403, 711.1),
    (463, 1230.2),
    (500, 1728.2),
]

# (item level, stamina or main primary stat on one armour piece), green and blue.
# Same interpolation; above the last point the ladder's own budget exponent applies.
GEAR_STAT = [
    (217, 68.0),
    (320, 105.0),
    (403, 178.0),
    (463, 237.0),
    (500, 278.5),
]
GEAR_BUDGET_EXPONENT = 2.13

# Class averages from `player_class_stats` (linear above 80).
BASE_HEALTH_80 = 7351.9
BASE_HEALTH_PER_LEVEL = 489.9
BASE_STAMINA_80 = 114.4
BASE_STAMINA_PER_LEVEL = 1.9
BASE_STRENGTH_80 = 175.0
BASE_STRENGTH_PER_LEVEL = 3.0

# What a level-80 character in the reference gear gets from that gear.
GEAR_STAMINA_80 = 900.0
GEAR_STRENGTH_80 = 800.0

# Share of a level-80 white hit that comes from the weapon itself; the rest is
# attack power. Two-hander at level 80: 179 weapon + 214 from attack power.
WEAPON_SHARE_OF_HIT_80 = 0.45

# ---------------------------------------------------------------------------


def lerp_points(points, x):
    """Linear interpolation over sorted (x, y) points, clamped at both ends."""
    if x <= points[0][0]:
        return float(points[0][1])
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return float(points[-1][1])


def log_interp(points, x):
    """Log-scale interpolation; beyond either end the nearest segment's slope continues."""
    if x <= points[1][0]:
        (x0, y0), (x1, y1) = points[0], points[1]
    elif x >= points[-2][0]:
        (x0, y0), (x1, y1) = points[-2], points[-1]
    else:
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            if x0 <= x <= x1:
                break
    slope = math.log(y1 / y0) / (x1 - x0)
    return y0 * math.exp(slope * (x - x0))


def ref_item_level(level):
    return lerp_points(REF_ITEM_LEVEL, level)


def weapon_dps(item_level):
    return log_interp(WEAPON_DPS, item_level)


def gear_stat(item_level):
    last_ilvl, last_stat = GEAR_STAT[-1]
    if item_level > last_ilvl:
        return last_stat * (item_level / last_ilvl) ** GEAR_BUDGET_EXPONENT
    return log_interp(GEAR_STAT, item_level)


def gear_growth(level):
    return gear_stat(ref_item_level(level)) / gear_stat(ref_item_level(MIN_LEVEL))


def weapon_growth(level):
    return weapon_dps(ref_item_level(level)) / weapon_dps(ref_item_level(MIN_LEVEL))


def reference_health(level):
    base = BASE_HEALTH_80 + BASE_HEALTH_PER_LEVEL * (level - MIN_LEVEL)
    stamina = (BASE_STAMINA_80 + BASE_STAMINA_PER_LEVEL * (level - MIN_LEVEL)
               + GEAR_STAMINA_80 * gear_growth(level))
    return base + 10.0 * stamina


def health_growth(level):
    return reference_health(level) / reference_health(MIN_LEVEL)


def reference_attack_power(level):
    strength = (BASE_STRENGTH_80 + BASE_STRENGTH_PER_LEVEL * (level - MIN_LEVEL)
                + GEAR_STRENGTH_80 * gear_growth(level))
    return 3.0 * level + 2.0 * strength - 20.0


def melee_growth(level):
    attack_power = reference_attack_power(level) / reference_attack_power(MIN_LEVEL)
    return (WEAPON_SHARE_OF_HIT_80 * weapon_growth(level)
            + (1.0 - WEAPON_SHARE_OF_HIT_80) * attack_power)


def armor_growth(level):
    """The armor formula's constant against level 80 (Unit::CalcArmorReducedDamage: 467.5 * L - 22167.5).

    A flat armor bonus that grows like this gives the same damage reduction at every level.
    Not a column of the table: only the rank generator needs it.
    """
    return (467.5 * level - 22167.5) / (467.5 * MIN_LEVEL - 22167.5)


def stat_growth(level):
    """Main primary stat of a character in the reference gear (base stat plus gear), against level 80.

    Not a column of the table: only the game-table generator needs it, for crit per agility / intellect.
    """
    def stat(at_level):
        return (BASE_STRENGTH_80 + BASE_STRENGTH_PER_LEVEL * (at_level - MIN_LEVEL)
                + GEAR_STRENGTH_80 * gear_growth(at_level))
    return stat(level) / stat(MIN_LEVEL)


def build_rows():
    rows = []
    for level in range(MIN_LEVEL, MAX_LEVEL + 1):
        rows.append((
            level,
            int(round(ref_item_level(level))),
            round(gear_growth(level), 4),
            round(weapon_growth(level), 4),
            round(health_growth(level), 4),
            round(melee_growth(level), 4),
        ))
    return rows


COLUMNS = ("level", "ref_item_level", "gear_growth", "weapon_growth", "health_growth", "melee_growth")

HEADER = """\
-- DarkChaos: balance reference table, levels 80-255 (generated by tools/balance/gen_reference.py)
--
-- One row per level with growth factors against level 80 (level 80 is 1 in every column):
--   ref_item_level  item level of the questing gear a character of that level wears
--   gear_growth     stamina / primary stat on one armour piece
--   weapon_growth   weapon damage per second
--   health_growth   reference player health
--   melee_growth    size of one white melee hit
-- The curves are measured from the gear ladder in item_template (2026-11-14). Levels 161-255 hold the level-160 item
-- level because no gear exists above 160 yet.
--
-- Readers: the worldserver loads the table at startup (rage income above level 80), and the pet level-stat file
-- that follows this one computes from it. Re-running replaces every row. Apply to acore_world, then restart the
-- worldserver. To change a curve, edit the knobs in the generator and generate a new file; do not edit rows by hand.
"""


def render_sql(rows):
    out = [HEADER]
    out.append("CREATE TABLE IF NOT EXISTS `dc_balance_reference` (")
    out.append("  `level` TINYINT UNSIGNED NOT NULL,")
    out.append("  `ref_item_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0,")
    out.append("  `gear_growth` FLOAT NOT NULL DEFAULT 1,")
    out.append("  `weapon_growth` FLOAT NOT NULL DEFAULT 1,")
    out.append("  `health_growth` FLOAT NOT NULL DEFAULT 1,")
    out.append("  `melee_growth` FLOAT NOT NULL DEFAULT 1,")
    out.append("  PRIMARY KEY (`level`)")
    out.append(") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;")
    out.append("")
    out.append("DELETE FROM `dc_balance_reference` WHERE `level` BETWEEN %d AND %d;" % (MIN_LEVEL, MAX_LEVEL))
    out.append("INSERT INTO `dc_balance_reference` (%s) VALUES" % ", ".join("`%s`" % c for c in COLUMNS))
    for index, row in enumerate(rows):
        assert len(row) == len(COLUMNS)
        end = ";" if index == len(rows) - 1 else ","
        out.append("(%d, %d, %s, %s, %s, %s)%s" % (row + (end,)))
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", type=Path, help="write the SQL file here")
    parser.add_argument("--print", action="store_true", dest="show", help="print the table for a few levels")
    args = parser.parse_args()

    rows = build_rows()
    assert rows[0][2:] == (1.0, 1.0, 1.0, 1.0), "level 80 must be the unit row"
    for previous, row in zip(rows, rows[1:]):
        assert all(b >= a for a, b in zip(previous[2:], row[2:])), "growth must not fall at level %d" % row[0]

    if args.show or not args.out:
        print("%5s %6s %8s %8s %8s %8s" % ("level", "ilvl", "gear", "weapon", "health", "melee"))
        for row in rows:
            if row[0] in (80, 81, 85, 90, 100, 113, 130, 145, 160, 200, 255):
                print("%5d %6d %8.3f %8.3f %8.3f %8.3f" % row)

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(render_sql(rows))
        print("wrote %s (%d rows)" % (args.out, len(rows)))


if __name__ == "__main__":
    main()
