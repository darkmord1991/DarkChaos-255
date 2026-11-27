#!/usr/bin/env python3
"""
Percent-based consumables for characters above level 80.

Stock potions, bandages, food and drink restore fixed amounts sized for a
level-80 character. Above 80 health and mana keep growing, so each of them gets
one new item, usable from level 81, that restores a share of the maximum
instead. The shares are the level-80 ratios of the stock items (a Runic Healing
Potion is about a fifth of a level-80 health bar, level-80 food refills the bar
in about 25 seconds), so the new items feel the way the old ones do at 80. The
stock items and their spells are not touched.

Each new spell and item is a copy of its stock counterpart with a handful of
fields changed, so icons, cast visuals, cooldown categories and the "must
remain seated" rules come along unchanged.

Outputs (into --out):
    new_spells.csv   232-column rows for wow.export-main/tools/spell-dbc-append.py
    new_items.csv    8-column Item.dbc rows
    consumables.sql  world DB: the item_template rows, the bandage script row and the vendor rows
With --apply-csv the rows are also written into Custom/CSV DBC/Spell.csv and
Item.csv (existing rows with the same ids are replaced, so re-running is safe).

To change a value, edit SPELLS / ITEMS below and run again.

Usage:
    python tools/balance/gen_consumables.py --out <dir> [--apply-csv]
"""

import argparse
import csv
import io
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPELL_CSV = ROOT / "Custom" / "CSV DBC" / "Spell.csv"
ITEM_CSV = ROOT / "Custom" / "CSV DBC" / "Item.csv"

REQUIRED_LEVEL = 81
ITEM_LEVEL = 90

# Vendors on these maps that already sell food or drink also sell the new items.
VENDOR_MAPS = (750, 751)

# ---------------------------------------------------------------------------
# Knobs. EffectBasePoints is stored as value - 1 (EffectDieSides 1 adds it back).
# ---------------------------------------------------------------------------

# new spell id -> (stock spell to copy, fields to change)
SPELLS = {
    # Healing potion: 20% of maximum health. Stock 43185 restores 2700-4500.
    920001: (43185, {
        "Effect_1": "136",                       # SPELL_EFFECT_HEAL_PCT
        "EffectBasePoints_1": "19",
        "EffectDieSides_1": "1",
        "Description_Lang_enUS": "Restores $s1% of your maximum health.",
    }),
    # Mana potion: 24% of maximum mana. Stock 43186 restores 4200-4400.
    920002: (43186, {
        "Effect_1": "137",                       # SPELL_EFFECT_ENERGIZE_PCT
        "EffectBasePoints_1": "23",
        "EffectDieSides_1": "1",
        "EffectMiscValue_1": "0",                # mana
        "Description_Lang_enUS": "Restores $s1% of your maximum mana.",
    }),
    # Bandage: 4% of the target's maximum health per second for 8 seconds (32%). Stock 45544 heals 5800.
    920003: (45544, {
        "EffectAura_1": "20",                    # SPELL_AURA_OBS_MOD_HEALTH
        "EffectBasePoints_1": "3",
        "EffectDieSides_1": "1",
        "NameSubtext_Lang_enUS": "Rank 16",
        "Description_Lang_enUS": "Heals $o1% of the target's maximum health over $d.",
        "AuraDescription_Lang_enUS": "Healing $s1% of maximum health every $t1 seconds.",
    }),
    # Food: 4% of maximum health per second for 24 seconds. Copy of the stock percent food 71074,
    # whose own text promises a Well Fed effect it does not have here.
    920004: (71074, {
        "EffectBasePoints_1": "3",
        "EffectDieSides_1": "1",
        "Description_Lang_enUS":
            "Restores $s1% of your health per second for $d.  Must remain seated while eating.",
    }),
    # Drink: 4% of maximum mana per second for 24 seconds. Stock percent drink 24355 gives 2% for 30.
    920005: (24355, {
        "EffectBasePoints_1": "3",
        "EffectDieSides_1": "1",
        "DurationIndex": "106",                  # 24 seconds, the same as the food
    }),
}

# Applied to every new spell: no rank window, learn level of the new tier.
SPELL_COMMON = {"SpellLevel": str(REQUIRED_LEVEL), "BaseLevel": str(REQUIRED_LEVEL), "MaxLevel": "0"}

# new item entry -> (stock item to copy, name, spell, buy price, sell price)
ITEMS = {
    423000: (33447, "Frontier Healing Potion", 920001, 60000, 15000),
    423001: (33448, "Frontier Mana Potion", 920002, 60000, 15000),
    423002: (34722, "Dense Frostweave Bandage", 920003, 30000, 7500),
    423003: (35953, "Frontier Rations", 920004, 20000, 1000),
    423004: (33445, "Frontier Springwater", 920005, 20000, 1000),
}

# ---------------------------------------------------------------------------

csv.field_size_limit(10 ** 9)


def read_csv(path):
    # utf-8-sig: Item.csv starts with a byte order mark, Spell.csv does not.
    with open(path, encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader)
        rows = [row for row in reader if row]
    return header, rows


def write_csv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, quoting=csv.QUOTE_ALL, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def build_spell_rows(header, rows):
    index = {name: position for position, name in enumerate(header)}
    by_id = {row[0]: row for row in rows}
    out = []
    for new_id, (source_id, changes) in sorted(SPELLS.items()):
        source = by_id[str(source_id)]
        assert len(source) == len(header), "spell %d has %d cells" % (source_id, len(source))
        row = list(source)
        row[index["ID"]] = str(new_id)
        for name, value in {**SPELL_COMMON, **changes}.items():
            assert name in index, "Spell.csv has no column %s" % name
            row[index[name]] = value
        out.append(row)
    return out


def build_item_rows(header, rows):
    assert header[0] == "ID" and len(header) == 8, "unexpected Item.csv header"
    by_id = {row[0]: row for row in rows}
    out = []
    for new_id, (source_id, _name, _spell, _buy, _sell) in sorted(ITEMS.items()):
        source = by_id[str(source_id)]
        out.append([str(new_id)] + list(source[1:]))
    return out


def replace_rows(path, new_rows):
    """Append the new rows at the end of the CSV, first dropping earlier copies of the same ids.

    Works on the file's bytes so that every other row stays exactly as it is: re-writing a 56 MB
    Spell.csv through the csv module would risk re-quoting rows this script has no business touching.
    The rows written here never contain a line break, so a copy from an earlier run is one line.
    """
    data = Path(path).read_bytes()
    assert b"\r\n" not in data[:65536], "%s is not LF" % path
    removed = 0
    for row in new_rows:
        prefix = ('"%s",' % row[0]).encode("ascii")
        lines = data.split(b"\n")
        kept = [line for line in lines if not line.startswith(prefix)]
        removed += len(lines) - len(kept)
        data = b"\n".join(kept)
    if not data.endswith(b"\n"):
        data += b"\n"
    buffer = io.StringIO(newline="")
    csv.writer(buffer, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(new_rows)
    Path(path).write_bytes(data + buffer.getvalue().encode("utf-8"))
    return removed, len(new_rows)


def render_sql():
    spell_ids = ", ".join(str(i) for i in sorted(SPELLS))
    item_ids = ", ".join(str(i) for i in sorted(ITEMS))
    lo, hi = min(ITEMS), max(ITEMS)
    maps = ", ".join(str(m) for m in VENDOR_MAPS)
    out = []
    out.append("-- DarkChaos: percent-based consumables for level 81 and above"
               " (generated by tools/balance/gen_consumables.py)")
    out.append("--")
    out.append("-- Five new items, usable from level %d, that restore a share of the maximum instead of a fixed amount:"
               % REQUIRED_LEVEL)
    out.append("--   423000 Frontier Healing Potion    20% of maximum health")
    out.append("--   423001 Frontier Mana Potion       24% of maximum mana")
    out.append("--   423002 Dense Frostweave Bandage   32% of the target's maximum health over 8 seconds (First Aid 400)")
    out.append("--   423003 Frontier Rations           4% of maximum health per second for 24 seconds")
    out.append("--   423004 Frontier Springwater       4% of maximum mana per second for 24 seconds")
    out.append("-- The shares are what the stock level-80 items give a level-80 character. Each item is a copy of its stock")
    out.append("-- counterpart (33447, 33448, 34722, 35953, 33445) with a new name, spell, level and price; the stock items")
    out.append("-- are not touched. The spells (%s) are rows of Spell.dbc and the items need" % spell_ids)
    out.append("-- rows in Item.dbc: the server needs both DBC files in place before this file does anything.")
    out.append("--")
    out.append("-- Every vendor on maps %s that already sells food or drink also sells all five." % maps)
    out.append("-- Re-running gives the same result. Apply to acore_world, then restart the worldserver.")
    out.append("")
    for entry, (source, name, spell, buy, sell) in sorted(ITEMS.items()):
        assert "'" not in name
        out.append("-- %s" % name)
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_consumable`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_consumable` SELECT * FROM `item_template` WHERE `entry` = %d;" % source)
        out.append("UPDATE `dc_tmp_consumable` SET `entry` = %d, `name` = '%s', `ItemLevel` = %d, `RequiredLevel` = %d, "
                   "`BuyPrice` = %d, `SellPrice` = %d, `spellid_1` = %d, `VerifiedBuild` = 0;"
                   % (entry, name, ITEM_LEVEL, REQUIRED_LEVEL, buy, sell, spell))
        out.append("REPLACE INTO `item_template` SELECT * FROM `dc_tmp_consumable`;")
        out.append("DROP TEMPORARY TABLE `dc_tmp_consumable`;")
        out.append("")
    out.append("-- The bandage keeps the Recently Bandaged rule of every other bandage.")
    out.append("DELETE FROM `spell_script_names` WHERE `spell_id` = 920003 AND `ScriptName` = 'spell_gen_bandage';")
    out.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (920003, 'spell_gen_bandage');")
    out.append("")
    out.append("-- Vendors")
    out.append("DELETE FROM `npc_vendor` WHERE `item` IN (%s);" % item_ids)
    out.append("INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`) "
               "SELECT DISTINCT `v`.`entry`, 0, `n`.`entry`, 0, 0, 0, 0 FROM `npc_vendor` AS `v` "
               "JOIN `item_template` AS `it` ON `it`.`entry` = `v`.`item` AND `it`.`class` = 0 AND `it`.`subclass` = 5 "
               "JOIN `item_template` AS `n` ON `n`.`entry` BETWEEN %d AND %d "
               "WHERE `v`.`entry` IN (SELECT `id` FROM `creature` WHERE `map` IN (%s));" % (lo, hi, maps))
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", type=Path, required=True, help="directory for the generated files")
    parser.add_argument("--apply-csv", action="store_true", help="also write the rows into Spell.csv and Item.csv")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    spell_header, spell_rows = read_csv(SPELL_CSV)
    assert len(spell_header) == 232, "Spell.csv must have 232 columns, found %d" % len(spell_header)
    new_spells = build_spell_rows(spell_header, spell_rows)
    write_csv(args.out / "new_spells.csv", spell_header, new_spells)

    item_header, item_rows = read_csv(ITEM_CSV)
    new_items = build_item_rows(item_header, item_rows)
    write_csv(args.out / "new_items.csv", item_header, new_items)

    with open(args.out / "consumables.sql", "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render_sql())

    print("spells: %s" % ", ".join(row[0] for row in new_spells))
    print("items:  %s" % ", ".join(",".join(row) for row in new_items))

    if args.apply_csv:
        removed, added = replace_rows(SPELL_CSV, new_spells)
        print("Spell.csv: removed %d earlier rows, appended %d" % (removed, added))
        removed, added = replace_rows(ITEM_CSV, new_items)
        print("Item.csv: removed %d earlier rows, appended %d" % (removed, added))


if __name__ == "__main__":
    main()
