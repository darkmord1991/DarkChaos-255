#!/usr/bin/env python3
"""
Bring the stats of items above level 80 onto the gear ladder: cap the Cataclysm imports, raise ratings.

Why: above 80 the rating needed for 1% grows with the gear ladder (tools/extend_gt_regen_to_255.py, mode
"gear"), and so do creature health and damage (gen_reference.py). The items above 80 come from three
pipelines -- map 750 clones (500000+), map 751 / ladder clones (400000+) and Cataclysm imports (32k-79k).
Measured against the ladder in 11-2026:
  * the Cataclysm imports at RequiredLevel 101-130 carry their native stats: about 3.6x the ladder stamina
    and 2.3x its primary stats, where the clones of the same item level carry about 1.2x;
  * a quarter to a half of the clones carry fewer ratings than a stock level-80 item of the same budget,
    many none at all (the clone rescale keeps the classic source item's stat mix).

Budget unit, per item: share(group, slot) * gen_reference.gear_stat(ItemLevel), where share is the median
points of that stat group per ladder unit on stock level-77..80 green and blue items of the slot, item level
187-226 (the gear the ladder's level-80 anchor stands for). fill = points / budget unit.

Stage 1, Cataclysm imports at RequiredLevel 101-130 (entry below 300000), PvE and PvP alike:
  each stat group above the clones' median fill (times QUALITY_FACTOR) is scaled down to it -- stamina;
  primary stats together with spell power and attack power; secondary stats (ratings, spirit, mp5).
  Resilience is left alone.
Stage 2, every item in scope: ratings below TARGET_FILL are raised to it. An item with ratings gets them
  scaled; an item without any gets two, split 55/45, picked by role (caster, agility, strength, tank shield)
  and entry, in its first two empty stat slots. PvP items (resilience) are skipped here.

Scope: weapons and armour, green to epic, no ScalingStatDistribution (heirlooms scale on their own),
RequiredLevel above 80, plus the clones (entry 400000+) at 77-80. Trinkets, relics, shirts and tabards have
no slot share and are left alone. Stock 1-80 items are never touched.

Each item gets one UPDATE with its final values and its old values in the WHERE clause, so applying it twice,
or after the item changed in the meantime, does nothing. A revert file with the original values is written
next to it.

Usage:
    python tools/balance/gen_item_stats.py --print            # summary only
    python tools/balance/gen_item_stats.py                    # write the SQL and the revert file
"""

import argparse
import statistics
import time
from collections import defaultdict
from pathlib import Path

import pymysql

import gen_reference
from dump_spell_coefficients import world_credentials

ROOT = Path(__file__).resolve().parents[2]
SQL_OUT_DIR = ROOT / "data" / "sql" / "updates" / "pending_db_world"
REVERT_OUT_DIR = ROOT / "Custom" / "Custom feature SQLs" / "worlddb" / "255balance"

# Knobs.
# Stage 2: 1.0 = the rating share of a stock WotLK item of the same budget. The rating tables give 20% back
# above 90 (RATING_COST_SHARE in extend_gt_regen_to_255.py), so gear of a character's own level at fill 1.0
# gives about 1.25 times the percentages a level-80 character gets from the ladder's level-80 gear.
TARGET_FILL = 1.0
# Leave an item's ratings alone when the raise would be smaller than this (fraction of its current ratings).
MIN_RAISE = 0.05
FIRST_SHARE = 0.55
# Stage 1: the cap is the clones' median fill of the group times this (the clone rescale's quality factors).
QUALITY_FACTOR = {2: 0.85, 3: 1.0, 4: 1.15}
CAP_ENTRY_BELOW = 300000          # Cataclysm imports; 300000-399999 are DC's own items
CAP_LEVELS = (101, 130)

# Stat types (ItemModType).
AGILITY, STRENGTH, INTELLECT, SPIRIT, STAMINA = 3, 4, 5, 6, 7
ATTACK_POWER, RANGED_ATTACK_POWER, SPELL_POWER, MANA_REGEN = 38, 39, 45, 43
RESILIENCE = 35
DEFENSE, DODGE, PARRY, BLOCK = 12, 13, 14, 15
HIT, CRIT, HASTE, EXPERTISE, ARMOR_PEN = 31, 32, 36, 37, 44
# 16-30 are the old school-specific hit / crit / haste ratings; they are ratings too.
RATING_TYPES = {DEFENSE, DODGE, PARRY, BLOCK, HIT, CRIT, HASTE, EXPERTISE, ARMOR_PEN} | set(range(16, 31))
PRIMARY_TYPES = {AGILITY, STRENGTH, INTELLECT}
POWER_TYPES = {ATTACK_POWER, RANGED_ATTACK_POWER, SPELL_POWER}

# Stage 1 groups: (name, types the fill is measured on, types scaled with it).
CAP_GROUPS = [
    ("stamina", {STAMINA}, {STAMINA}),
    ("primary", PRIMARY_TYPES, PRIMARY_TYPES | POWER_TYPES),
    ("secondary", RATING_TYPES | {SPIRIT, MANA_REGEN}, RATING_TYPES | {SPIRIT, MANA_REGEN}),
]

# Rating pairs for an item that has none, by role; the entry picks one of the three.
PAIRS = {
    "caster": [(CRIT, HASTE), (HASTE, CRIT), (CRIT, HIT)],
    "agility": [(CRIT, HIT), (CRIT, HASTE), (CRIT, ARMOR_PEN)],
    "strength": [(CRIT, HIT), (CRIT, EXPERTISE), (HASTE, CRIT)],
    "tank": [(DEFENSE, BLOCK), (DEFENSE, DODGE), (DEFENSE, PARRY)],
}

SHIELD = 14
SLOT_GROUP = {1: "head", 3: "shoulder", 5: "chest", 20: "chest", 6: "waist", 7: "legs", 8: "feet", 9: "wrist",
              10: "hands", 2: "neck", 11: "finger", 16: "back", 13: "1h", 21: "1h", 22: "1h", 17: "2h",
              15: "ranged", 26: "ranged", 25: "ranged", SHIELD: "shield", 23: "offhand"}

STAT_COLUMNS = ", ".join(f"`stat_type{i}`, `stat_value{i}`" for i in range(1, 11))
SELECT_ITEMS = (
    f"SELECT `entry`, `name`, `InventoryType`, `Quality`, `ItemLevel`, `RequiredLevel`, {STAT_COLUMNS} "
    "FROM `item_template` WHERE `class` IN (2, 4) AND `Quality` IN (2, 3, 4) AND `ScalingStatDistribution` = 0 "
    "AND `ItemLevel` > 0 AND `RequiredLevel` >= 77")


class Item:
    def __init__(self, row):
        self.entry, self.name, self.inv, self.quality, self.ilvl, self.req = row[:6]
        self.original = [(row[6 + 2 * i], row[7 + 2 * i]) for i in range(10)]
        self.stats = [list(pair) for pair in self.original]
        self.slot = SLOT_GROUP.get(self.inv)

    def total(self, types):
        return sum(value for stat, value in self.stats if stat in types and value > 0)

    @property
    def budget(self):
        return gen_reference.gear_stat(self.ilvl)

    def in_scope(self):
        return self.req > 80 or self.entry >= 400000

    def is_clone(self):
        return self.entry >= 400000

    def is_capped_import(self):
        return self.entry < CAP_ENTRY_BELOW and CAP_LEVELS[0] <= self.req <= CAP_LEVELS[1]

    def role(self):
        agi, strength, intel = self.total({AGILITY}), self.total({STRENGTH}), self.total({INTELLECT})
        if intel > 0 and intel >= max(agi, strength):
            return "caster"
        if agi > 0 and agi >= strength:
            return "agility"
        if strength > 0:
            return "tank" if self.inv == SHIELD else "strength"
        if self.total({ATTACK_POWER, RANGED_ATTACK_POWER}) > 0:
            return "agility"
        if self.total({SPELL_POWER}) > 0:
            return "caster"
        return None

    def changes(self):
        """[(slot index, old type, old value, new type, new value)] for every changed stat slot."""
        return [(index, old[0], old[1], new[0], new[1])
                for index, (old, new) in enumerate(zip(self.original, self.stats)) if tuple(new) != tuple(old)]


def stock_shares(items):
    """Median points per ladder budget unit on stock level-80 quest / dungeon gear, by group and slot."""
    groups = {"ratings": RATING_TYPES, **{name: measured for name, measured, _ in CAP_GROUPS}}
    per_slot = defaultdict(lambda: defaultdict(list))
    for item in items:
        if (item.slot and item.req <= 80 and item.entry < 400000 and 187 <= item.ilvl <= 226
                and item.quality in (2, 3) and item.total({RESILIENCE}) == 0 and item.role()):
            for name, types in groups.items():
                per_slot[name][item.slot].append(item.total(types) / item.budget)
    return {name: {slot: statistics.median(values) for slot, values in slots.items()}
            for name, slots in per_slot.items()}


def fill(item, shares, group, types):
    share = shares[group].get(item.slot, 0.0)
    return item.total(types) / (share * item.budget) if share > 0 else None


def clone_medians(items, shares):
    """The clones' median fill per stage-1 group: the level the imports are capped to."""
    medians = {}
    for name, measured, _ in CAP_GROUPS:
        values = [fill(item, shares, name, measured) for item in items
                  if item.in_scope() and item.is_clone() and item.req > 80 and item.slot and item.role()
                  and item.total({RESILIENCE}) == 0]
        medians[name] = statistics.median(v for v in values if v is not None and v > 0)
    return medians


def cap_import(item, shares, medians):
    """Stage 1. Returns the names of the groups that were scaled down."""
    capped = []
    for name, measured, scaled in CAP_GROUPS:
        current = fill(item, shares, name, measured)
        if not current:
            continue
        cap = medians[name] * QUALITY_FACTOR[item.quality]
        if name == "secondary":
            cap = max(cap, TARGET_FILL * QUALITY_FACTOR[item.quality], TARGET_FILL)
        if current <= cap:
            continue
        factor = cap / current
        for pair in item.stats:
            if pair[0] in scaled and pair[1] > 0:
                pair[1] = max(1, round(pair[1] * factor))
        capped.append(name)
    return capped


def raise_ratings(item, shares):
    """Stage 2. Returns 'scaled', 'added' or why nothing changed."""
    if item.total({RESILIENCE}) > 0:
        return "pvp"
    share = shares["ratings"].get(item.slot, 0.0)
    if share <= 0:
        return "no slot share"
    role = item.role()
    if not role:
        return "no role"

    target = round(TARGET_FILL * share * item.budget)
    current = item.total(RATING_TYPES)
    if target <= current * (1 + MIN_RAISE) or target - current < 2:
        return "at target"

    if current > 0:
        factor = target / current
        for pair in item.stats:
            if pair[0] in RATING_TYPES and pair[1] > 0:
                pair[1] = max(pair[1] + 1, round(pair[1] * factor))
        return "scaled"

    free = [pair for pair in item.stats if pair[0] == 0 or pair[1] <= 0]
    if not free:
        return "no free slot"
    first, second = PAIRS[role][item.entry % 3]
    if len(free) == 1:
        free[0][:] = [first, target]
        return "added"
    first_value = max(1, round(target * FIRST_SHARE))
    free[0][:] = [first, first_value]
    free[1][:] = [second, max(1, target - first_value)]
    return "added"


def update_sql(entry, changes, reverse=False):
    sets, guards = [], [f"`entry` = {entry}"]
    for index, old_type, old_value, new_type, new_value in changes:
        column = index + 1
        set_type, set_value = (old_type, old_value) if reverse else (new_type, new_value)
        was_type, was_value = (new_type, new_value) if reverse else (old_type, old_value)
        if set_type != was_type:
            sets.append(f"`stat_type{column}` = {set_type}")
        sets.append(f"`stat_value{column}` = {set_value}")
        guards.append(f"`stat_type{column}` = {was_type} AND `stat_value{column}` = {was_value}")
    set_tokens = [part + "," for part in sets[:-1]] + sets[-1:]
    return (wrap("UPDATE `item_template` SET ", set_tokens, " ", "    ") + "\n"
            + wrap("    WHERE ", guards, " AND ", "    AND ") + ";")


def wrap(head, tokens, joiner, continuation, width=120):
    """Join tokens after `head`; a token that would pass `width` starts a new line with `continuation`."""
    lines, line = [], head + tokens[0]
    for token in tokens[1:]:
        if len(line) + len(joiner) + len(token) > width:
            lines.append(line)
            line = continuation + token
        else:
            line += joiner + token
    lines.append(line)
    return "\n".join(lines)


def band(level):
    for top, name in ((80, "77-80"), (90, "81-90"), (100, "91-100"), (115, "101-115"), (130, "116-130"),
                      (145, "131-145"), (160, "146-160")):
        if level <= top:
            return name
    return "161+"


def median_or_dash(values):
    return f"{statistics.median(values):.2f}" if values else "  - "


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--conf", default="K:/Dark-Chaos/Server/configs/worldserver.conf")
    parser.add_argument("--print", action="store_true", help="summary only, write nothing")
    args = parser.parse_args()

    connection = pymysql.connect(**world_credentials(args.conf), connect_timeout=10, read_timeout=600)
    try:
        with connection.cursor() as cursor:
            cursor.execute(SELECT_ITEMS)
            items = [Item(row) for row in cursor.fetchall()]
    finally:
        connection.close()

    shares = stock_shares(items)
    medians = clone_medians(items, shares)
    print("Stock level-80 rating share per slot: "
          + ", ".join(f"{slot} {value:.2f}" for slot, value in sorted(shares["ratings"].items())))
    print("Clone median fill (import caps, blue): "
          + ", ".join(f"{name} {value:.2f}" for name, value in medians.items()))

    updates, reverts = [], []
    counts = defaultdict(lambda: defaultdict(int))
    fills = defaultdict(lambda: defaultdict(list))
    for item in sorted((i for i in items if i.in_scope()), key=lambda i: i.entry):
        key = band(item.req)
        family = "import" if item.is_capped_import() else "other"
        measure = item.slot in shares["ratings"] and item.role() is not None
        if measure:
            for name, types in (("sta", {STAMINA}), ("prim", PRIMARY_TYPES), ("rat", RATING_TYPES)):
                group = {"sta": "stamina", "prim": "primary", "rat": "ratings"}[name]
                value = fill(item, shares, group, types)
                if value is not None:
                    fills[(key, family)][name + "0"].append(value)

        capped = cap_import(item, shares, medians) if item.is_capped_import() else []
        stage2 = raise_ratings(item, shares)
        if capped:
            counts[key]["capped"] += 1
        counts[key][stage2] += 1

        if measure:
            for name, types in (("sta", {STAMINA}), ("prim", PRIMARY_TYPES), ("rat", RATING_TYPES)):
                group = {"sta": "stamina", "prim": "primary", "rat": "ratings"}[name]
                value = fill(item, shares, group, types)
                if value is not None:
                    fills[(key, family)][name + "1"].append(value)

        changes = item.changes()
        if changes:
            what = ", ".join(([f"capped {'/'.join(capped)}"] if capped else [])
                             + ([f"ratings {stage2}"] if stage2 in ("scaled", "added") else []))
            updates.append(f"-- {item.entry} {item.name} (RL {item.req}, ilvl {item.ilvl}, {what})\n"
                           + update_sql(item.entry, changes))
            reverts.append(update_sql(item.entry, changes, reverse=True))

    order = sorted(counts, key=lambda k: int(k.split("-")[0].rstrip("+")))
    print("\nBand      capped  rat.scaled  rat.added  at-target  pvp  other")
    for key in order:
        c = counts[key]
        other = sum(v for r, v in c.items() if r not in ("capped", "scaled", "added", "at target", "pvp"))
        print(f"  {key:8s} {c['capped']:6d} {c['scaled']:10d} {c['added']:10d} {c['at target']:10d} "
              f"{c['pvp']:4d} {other:6d}")
    print("\nMedian fill before -> after      stamina         primary         ratings")
    for key in order:
        for family in ("import", "other"):
            f = fills[(key, family)]
            if not f["sta0"]:
                continue
            print(f"  {key:8s} {family:6s} n={len(f['sta0']):5d}   "
                  + "   ".join(f"{median_or_dash(f[n + '0'])} -> {median_or_dash(f[n + '1'])}"
                             for n in ("sta", "prim", "rat")))
    print(f"\n{len(updates)} items change.")

    if args.print:
        return

    stamp = time.time_ns()
    header = (
        "-- DarkChaos: item stats above level 80 onto the gear ladder (generated by tools/balance/gen_item_stats.py).\n"
        "-- 1. Cataclysm imports at RequiredLevel 101-130 (entry < 300000, PvE and PvP): stamina, primary stats\n"
        "--    (with spell power / attack power) and secondary stats capped at the map 750/751 clones' median for\n"
        "--    the same slot and item level (epics +15%, greens -15%); resilience untouched.\n"
        f"-- 2. Every weapon / armour item above 80 (and the 400000+ clones at 77-80): ratings raised to fill\n"
        f"--    {TARGET_FILL} of a stock WotLK item of the same ladder budget; items with none get two by role;\n"
        "--    PvP items skipped. Stock 1-80 items are never touched.\n"
        "-- Each UPDATE checks the old values, so a second run changes nothing. Goes with the GtCombatRatings\n"
        "-- relief (RATING_COST_SHARE in tools/extend_gt_regen_to_255.py).\n"
        "-- Apply to acore_world, restart the worldserver; clients need their WDB cache cleared to see it.\n"
        f"-- Revert: Custom/Custom feature SQLs/worlddb/255balance/item_stats_revert_{stamp}.sql\n")
    sql_path = SQL_OUT_DIR / f"rev_{stamp}.sql"
    sql_path.write_text(header + "\n" + "\n".join(updates) + "\n", encoding="utf-8", newline="\n")
    revert_path = REVERT_OUT_DIR / f"item_stats_revert_{stamp}.sql"
    revert_path.write_text(
        f"-- Reverts data/sql/updates/pending_db_world/rev_{stamp}.sql (item stats above 80): restores the\n"
        "-- original stat columns. Each UPDATE checks the new values, so it only touches unchanged items.\n\n"
        + "\n".join(reverts) + "\n", encoding="utf-8", newline="\n")
    print(f"SQL    {sql_path}\nRevert {revert_path}")


if __name__ == "__main__":
    main()
