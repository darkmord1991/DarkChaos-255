#!/usr/bin/env python3
"""Rebuild the map 751 spawns lost after the Neltharion layer import.

30_neltharion_spawn_layer.sql ends with an orphan cleanup that deletes spawns whose
+3600000 clone template does not exist yet. The 29_ templates landed after it ran, so
whole NPC types kept a template and lost every spawn, and 71_ never re-leveled them
because it keys on live spawns. Gameobjects hit the same cleanup, but their templates
never arrived at all.

Rows come straight out of 30_ so nothing is retyped. Zones come from the lookup data
in 61_zone_split.sql, which resolves the same way that file does.

Writes four SQL files into --out and always prints what they depend on.
"""
import argparse
import collections
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PLAGUE = ROOT / "Custom" / "Custom feature SQLs" / "worlddb" / "Plaguelands"
LAYER = PLAGUE / "30_neltharion_spawn_layer.sql"
SPLIT = PLAGUE / "61_zone_split.sql"
OFFSET = 3600000

# Raw entries with no live spawn at all, from the live audit. Every row 30_ holds for them
# is lost, so no per-guid diff is needed. Argent Medic, Hippogryph and Sentry each lost one
# row while the rest of the entry survived, and are left as they are.
LOST_ENTRIES = {
    1056, 1609, 1783, 1784, 1794, 1837, 1841, 1844, 1847, 1850, 1851, 1855, 1884, 4076,
    8477, 8607, 10304, 10698, 10739, 10778, 10816, 10818, 10824, 10825, 10827, 10828,
    10902, 10903, 10904, 10905, 10936, 10940, 10976, 11023, 11064, 11216, 11217, 11286,
    11610, 11613, 11614, 11704, 11710, 11878, 11885, 11898, 12202, 12244, 12247, 12249,
    12251, 12252, 12253, 12254, 12255, 12256, 12261, 12322, 15162, 15566, 15592, 15602,
    16131, 16132, 16184, 16361, 16431, 16494, 16781, 16786, 17689, 17690, 17696, 17698,
    17795, 25909, 26401, 28512, 29210, 29231, 32820, 43803, 44329, 44331, 44332, 44448,
    44449, 44450, 44458, 44487, 44488, 44489, 44552, 44555, 44944, 44946, 44955, 45047,
    45048, 45049, 45050, 45058, 45060, 45061, 45085, 45098, 45101, 45209, 45235, 45239,
    45240, 45241, 45242, 45243, 45416, 45574, 45579, 45683, 45698, 45707, 45729, 45730,
    45738, 46092, 46093, 46094, 46095, 46096, 46558, 48718, 51535, 51604, 54344, 56049,
    60217, 60219, 60221, 60247, 60249, 60251, 60615, 60617, 1337016,
}

# Lost entries that stay out, with the reason.
EXCLUDED_CREATURES = {
    "world event spawn": {32820, 16781, 25909, 51604, 26401, 15566, 15592, 15602},
    "Scourge Invasion, inert on this map": {16361, 16494, 16786, 16431},
    "Neltharion server NPC": {1337016, 56049},
    "archaeology digsite": {60217, 60219, 60221, 60247, 60249, 60251, 60615, 60617},
    "Outdoor PvP, not active on this map": {17689, 17690, 17696, 17698, 17795},
    "placeholder template": {1056, 1609, 54344},
    "sniffed summon or pet": {8477, 10936, 11064, 29210, 29231, 44955, 45683, 48718},
    "vehicle or quest helper with no script here": {43803, 44552, 44555, 45416, 45738, 46558},
    "already restored at Caer Darrow": {11216, 11217, 11286},
}

# Cata-only spawns, which 30_ never carried. guid = Cata guid + 13000000.
# (raw, cata guid, x, y, z, o, spawntime, wander, movement)
CATA_ONLY = [
    (1420, 322876, 642.344, -1848.09, 40.6105, 6.03441, 300, 8, 1),
    (1420, 328779, 925.724, -2080.79, 40.7162, 5.5877, 300, 8, 1),
    (1420, 328798, 871.093, -2118.4, 36.6458, 3.59651, 300, 8, 1),
    (16226, 84742, 2305.29, -5286.12, 82.0207, 4.83456, 300, 0, 0),
    (16232, 84737, 2308.2, -5297.16, 82.0796, 1.78024, 300, 0, 0),
    (16232, 84738, 2309.5, -5294.25, 82.0769, 1.72788, 300, 0, 0),
    (16232, 84739, 2306.32, -5294.14, 82.0769, 1.81514, 300, 0, 0),
    (16232, 84740, 2308.93, -5290.62, 82.1062, 1.79769, 300, 0, 0),
    (16232, 84741, 2305.88, -5290.34, 82.3359, 1.8326, 300, 0, 0),
]

# Spawned on map 750 too, and creature_template is global: these two keep their level or
# Hyjal's critters would jump to 150. 71_ documents the same exclusion.
SHARED_WITH_MAP750 = {1420, 4076}

# Raw gameobject entries worth a clone template: stock template, stock spawns (or the
# Andorhal towers the watchtower quest needs), and no event gating.
RESTORED_GAMEOBJECTS = {
    176213, 175795, 177726, 177668, 153471, 153454, 195606, 2852, 153468, 165587,
    179747, 176094, 176095, 176096, 176097,
    147435, 147436, 147437, 147438, 147439, 147441, 147444, 147446,
}

# Weapons. Stock clones copy the stock row, Cata-new NPCs the cata_world row.
EQUIP_STOCK = {
    1783, 1784, 1837, 1841, 1844, 1855, 1884, 10304, 10818, 10824, 10827, 10828, 10976,
    11023, 11610, 11613, 11878, 11898, 12322, 15162, 16226,
}
EQUIP_CATA = {
    44329, 44331, 44332, 44448, 44449, 44450, 44458, 44944, 45047, 45048, 45049, 45050,
    45058, 45060, 45061, 45085, 45101, 45209, 45240, 45241, 45242, 45243, 45579, 45698,
    45707, 45729, 45730, 46092, 46093, 46094, 46095, 46096, 51535,
}

# Cata quests whose kill objectives stayed on the raw id, because 11_quests only remapped
# entries it saw in the Cata spawn list. They are not used anywhere else.
OBJECTIVE_QUESTS = [26922, 26956, 27085, 27086, 27161, 27173, 27199, 27201, 27202,
                    27613, 27615, 27616, 27619, 27620]
OBJECTIVE_TARGETS = [44329, 44449, 44450, 44448, 44489, 45209, 45239, 45240,
                     46092, 46093, 46094, 46095, 46096]

# Quest chains the restored NPCs carry, still at their Cata levels because 71_ skipped any
# quest with an unspawned giver. MinLevel is the band floor minus 2, as in 71_.
QUEST_BANDS = {146: [26957, 27017],
               150: [27466, 27487, 27488, 27489, 27522, 27524, 27525, 27526, 27527, 27551]}
QUEST_FLOOR = {146: 148, 150: 152}

# Same id, same spot, same movement. No script or formation references any of these.
DUPLICATE_CREATURES = {16712069: 4115730, 16719821: 4136217, 16719939: 4136213,
                       16719818: 4136213, 16719814: 4136213, 16719936: 4136213,
                       16713225: 4108276, 16721734: 6491}


def split_tuple(text):
    """Split one VALUES tuple body on top-level commas, keeping quoted strings whole."""
    values, current, quoted, i = [], [], False, 0
    while i < len(text):
        ch = text[i]
        if quoted:
            current.append(ch)
            if ch == "\\":
                current.append(text[i + 1])
                i += 1
            elif ch == "'":
                quoted = False
        elif ch == "'":
            quoted = True
            current.append(ch)
        elif ch == ",":
            values.append("".join(current))
            current = []
        else:
            current.append(ch)
        i += 1
    values.append("".join(current))
    return values


def parse_layer():
    """Return {table: (columns, [row values])} for the INSERT blocks of 30_."""
    tables, table = {}, None
    for line in LAYER.read_text(encoding="utf-8", errors="replace").splitlines():
        head = re.match(r"INSERT INTO `(\w+)` \((.*)\) VALUES", line)
        if head:
            table = head[1]
            tables.setdefault(table, ([c.strip(" `") for c in head[2].split(",")], []))
            continue
        if table and line.startswith("("):
            tables[table][1].append(split_tuple(line.rstrip(",;")[1:-1]))
        elif not line.startswith("("):
            table = None
    return tables


def parse_zones():
    """Return the two lookups 61_ fills: tile (col,row) and chunk (col,row,xsub,ysub)."""
    text = SPLIT.read_text(encoding="utf-8", errors="replace")
    tiles, chunks = {}, {}
    for block in re.findall(r"INSERT INTO `dc_map751_tilezone`[^;]*;", text):
        for col, row, zone in re.findall(r"\((\d+),(\d+),(\d+)\)", block):
            tiles[int(col), int(row)] = int(zone)
    for block in re.findall(r"INSERT INTO `dc_map751_chunkzone`[^;]*;", text):
        for col, row, xsub, ysub, zone in re.findall(r"\((\d+),(\d+),(\d+),(\d+),(\d+)\)", block):
            chunks[int(col), int(row), int(xsub), int(ysub)] = int(zone)
    return tiles, chunks


def zone_of(x, y, tiles, chunks):
    """Same arithmetic as 61_, chunks first and whole tiles second. 4924 is its default."""
    col_f = 32 - y / 533.3333333
    row_f = 32 - x / 533.3333333
    col, row = int(col_f // 1), int(row_f // 1)
    xsub, ysub = int(((row_f - row) * 16) // 1), int(((col_f - col) * 16) // 1)
    return tiles.get((col, row), chunks.get((col, row, xsub, ysub), 4924))


# Quest repairs, stage two. Stock quests are shared with map 0, so their rows are never
# edited: a clone joins as an extra giver and earns the raw objective through KillCredit.

# Lost NPCs whose stock quests were never linked to the map 751 clones.
QUEST_NPCS = {1855, 10304, 10739, 10778, 10976, 11023, 11216, 11286, 11610, 11878, 11898,
              16131, 16132}

# Clones standing on 751 whose raw entry is a stock kill objective. None is spawned on 750.
KILL_CREDIT = {1783, 1817, 1831, 8563, 8564, 8565, 8596, 8597, 8598, 8600, 8601, 8602,
               10605, 11613, 11896}
# Scholomance clones on map 822, clone entry -> stock objective.
KILL_CREDIT_822 = {5700029: 10506, 5700035: 11261, 5700040: 11622}

# Cata quests whose kill targets have a clone on 751. 44955 is the one I excluded as a
# summon, the quest needs it.
OBJECTIVE_QUESTS_2 = [26931, 26933, 26938, 26956, 27084, 27204]
OBJECTIVE_TARGETS_2 = [44432, 44433, 44474, 44476, 44487, 44488, 44955, 45098, 45235]

# Stock SmartAI the clones never received. Tirion completes Redemption through it, Eva
# hands out her first quest through it, the marks turn Smokey's charge into quest credit.
MARKS = [12256, 12255, 12254, 12253, 12252, 12251, 12249, 12244]
SAI_COPIES = {1855, 11216, *MARKS}

# All Along the Watchtowers. Stock npc_andorhal_tower credits me->GetEntry(), which on a
# clone is the wrong id, so the clones do the same check in SmartAI with the raw id.
TOWERS = [10902, 10903, 10904, 10905]

SMART_COLUMNS = ("entryorguid source_type id link event_type event_phase_mask event_chance "
                 "event_flags event_param1 event_param2 event_param3 event_param4 event_param5 "
                 "event_param6 action_type action_param1 action_param2 action_param3 action_param4 "
                 "action_param5 action_param6 target_type target_param1 target_param2 target_param3 "
                 "target_param4 target_x target_y target_z target_o comment").split()
CONDITION_COLUMNS = ("SourceTypeOrReferenceId SourceGroup SourceEntry SourceId ElseGroup "
                     "ConditionTypeOrReference ConditionTarget ConditionValue1 ConditionValue2 "
                     "ConditionValue3 NegativeCondition ErrorType ErrorTextId ScriptName "
                     "Comment").split()


def csv(values):
    return ", ".join(str(v) for v in sorted(values))


def table(name, columns, rows):
    head = f"INSERT INTO `{name}` (" + ", ".join(f"`{c}`" for c in columns) + ") VALUES\n"
    return head + ",\n".join("(" + ", ".join(r) + ")" for r in rows) + ";\n"


def restored_creatures(rows, col, tiles, chunks):
    """Rows of the lost entries, zoned and carrying the right equipment id."""
    excluded = {raw for ids in EXCLUDED_CREATURES.values() for raw in ids}
    keep, zones = [], collections.defaultdict(collections.Counter)
    for src in rows:
        raw = int(src[col["id"]]) - OFFSET
        if raw not in LOST_ENTRIES or raw in excluded:
            continue
        row = list(src)
        zone = zone_of(float(row[col["position_x"]]), float(row[col["position_y"]]), tiles, chunks)
        row[col["zoneId"]] = row[col["areaId"]] = str(zone)
        row[col["equipment_id"]] = "-1" if raw in EQUIP_STOCK | EQUIP_CATA else "0"
        # These walkers have no path in any source, and the core would only log and idle them
        if row[col["MovementType"]] == "2":
            row[col["MovementType"]] = "0"
        row[col["Comment"]] = "'Plague-Nel restore'"
        keep.append(row)
        zones[raw + OFFSET][zone] += 1

    for raw, guid, x, y, z, o, spawn, wander, movement in CATA_ONLY:
        zone = zone_of(x, y, tiles, chunks)
        row = ["0"] * len(col)
        values = dict(guid=guid + 13000000, id=raw + OFFSET, map=751, zoneId=zone, areaId=zone,
                      spawnMask=1, phaseMask=1, equipment_id=-1 if raw in EQUIP_STOCK else 0,
                      position_x=x, position_y=y, position_z=z, orientation=o, spawntimesecs=spawn,
                      wander_distance=wander, curhealth=1, MovementType=movement)
        for name, value in values.items():
            row[col[name]] = str(value)
        row[col["ScriptName"]] = "''"
        row[col["Comment"]] = "'Cata-only restore'"
        keep.append(row)
        zones[raw + OFFSET][zone] += 1

    # Dominant zone per entry, ties to the lower id, as 71_ and 106_ resolve it
    dominant = {e: min(c, key=lambda z: (-c[z], z)) for e, c in zones.items()}
    return keep, dominant


def creature_sql(layer, keep, dominant, col):
    guids = [int(r[col["guid"]]) for r in keep]
    spawned = csv(dominant)
    entries = sorted(e for e in dominant if e - OFFSET not in SHARED_WITH_MAP750)
    ecsv = csv(entries)
    addon_cols, addon_rows = layer["creature_addon"]
    wanted = set(guids)
    addons = [r for r in addon_rows if int(r[0]) in wanted]
    out = [f"""-- Map 751: restore the spawns lost after the Neltharion layer import.
--
-- 30_neltharion_spawn_layer ends with an orphan cleanup that deletes spawns whose clone
-- template does not exist yet. The 29_ templates landed too late, so these NPC types kept
-- a template and lost every spawn. 71_ and 106_ key on live spawns, so they were never
-- re-leveled or re-scaled either, and every quest touching them stayed unscaled.
--
-- Rows are the 30_ originals. guid = source guid + 13000000, as in that layer.
-- Generated by Custom/Documentation/scripts/gen_map751_spawn_restore.py
--
-- Left out on purpose: world event spawns, Scourge Invasion NPCs, Outdoor PvP doodads,
-- archaeology digsites, Neltharion server NPCs, sniffed summons and scriptless vehicles.
--
-- Safe to run twice. DO NOT re-apply 30_, it wipes the whole 13.0-13.5M block.

-- Spawns
DELETE FROM `creature` WHERE `map` = 751 AND `id` IN ({spawned}) AND `guid` IN ({csv(guids)});
"""]
    out.append(table("creature", list(col), keep))
    out.append(f"""
-- Addons: mounts, auras and paths
DELETE FROM `creature_addon` WHERE `guid` IN ({csv(int(r[0]) for r in addons)});
""")
    out.append(table("creature_addon", addon_cols, addons))
    out.append(f"""
-- Equipment: the import never brought these rows, and the spawns use a random equip id
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN ({csv(i + OFFSET for i in EQUIP_STOCK)});
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT `CreatureID` + 3600000, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, 0
FROM `creature_equip_template`
WHERE `CreatureID` IN ({csv(EQUIP_STOCK)});
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN ({csv(i + OFFSET for i in EQUIP_CATA)});
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT `CreatureID` + 3600000, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, 0
FROM `cata_world`.`creature_equip_template`
WHERE `CreatureID` IN ({csv(EQUIP_CATA)});

-- Levels. The band table owns the numbers, as in 71_. Roach and Toad are also spawned on
-- map 750 and creature_template is global, so they stay out of this and the stats below.
DELETE FROM `dc_map751_entryzone` WHERE `entry` IN ({ecsv});
""")
    out.append(table("dc_map751_entryzone", ["entry", "zone"],
                     [[str(e), str(dominant[e])] for e in entries]))
    out.append(f"""
-- Frozen originals. These two pair with no DELETE on purpose: the first run must win, or
-- a second run would snapshot values this file already changed.
INSERT IGNORE INTO `dc_map751_snap` (`entry`, `minlevel`, `maxlevel`, `rank`)
SELECT `entry`, `minlevel`, `maxlevel`, `rank`
FROM `creature_template`
WHERE `entry` IN ({ecsv});
INSERT IGNORE INTO `dc_map751_stat_snap` (`entry`, `HealthModifier`, `ManaModifier`, `DamageModifier`, `ArmorModifier`)
SELECT `entry`, `HealthModifier`, `ManaModifier`, `DamageModifier`, `ArmorModifier`
FROM `creature_template`
WHERE `entry` IN ({ecsv});

UPDATE `creature_template` `t`
JOIN `dc_map751_entryzone` `e` ON `e`.`entry` = `t`.`entry`
JOIN `dc_map751_snap` `s` ON `s`.`entry` = `t`.`entry`
JOIN `dc_map751_band` `b` ON `b`.`zone` = `e`.`zone` SET
  `t`.`minlevel` = LEAST(`b`.`t_hi` + IF(`s`.`rank` > 0, 2, 0), GREATEST(`b`.`t_lo`,
    `b`.`t_lo` + ROUND((LEAST(GREATEST(`s`.`minlevel`, `b`.`s_lo`), `b`.`s_hi`) - `b`.`s_lo`)
    * (`b`.`t_hi` - `b`.`t_lo`) / GREATEST(`b`.`s_hi` - `b`.`s_lo`, 1)) + IF(`s`.`rank` > 0, 2, 0))),
  `t`.`maxlevel` = LEAST(`b`.`t_hi` + IF(`s`.`rank` > 0, 2, 0), GREATEST(`b`.`t_lo`,
    `b`.`t_lo` + ROUND((LEAST(GREATEST(`s`.`maxlevel`, `b`.`s_lo`), `b`.`s_hi`) - `b`.`s_lo`)
    * (`b`.`t_hi` - `b`.`t_lo`) / GREATEST(`b`.`s_hi` - `b`.`s_lo`, 1)) + IF(`s`.`rank` > 0, 2, 0)))
WHERE `t`.`entry` IN ({ecsv});

-- Stats: the 106_ curve, always from the snapshot so it cannot ratchet
UPDATE `creature_template` `t`
JOIN `dc_map751_stat_snap` `snap` ON `snap`.`entry` = `t`.`entry`
JOIN `dc_map751_rank_scale` `r` ON `r`.`rank` = `t`.`rank`
JOIN `creature_classlevelstats` `s` ON `s`.`level` = `t`.`maxlevel` AND `s`.`class` = `t`.`unit_class` SET
  `t`.`HealthModifier` = GREATEST(`snap`.`HealthModifier`, (`s`.`basehp2` * `r`.`hp_factor`) / `s`.`basehp0`),
  `t`.`ManaModifier` = IF(`s`.`basemana` > 0, LEAST(`snap`.`ManaModifier`,
    (`s`.`basehp0` * GREATEST(`snap`.`HealthModifier`, (`s`.`basehp2` * `r`.`hp_factor`) / `s`.`basehp0`))
    / `s`.`basemana`), `snap`.`ManaModifier`),
  `t`.`DamageModifier` = GREATEST(`snap`.`DamageModifier`, `r`.`dmg_floor`)
WHERE `t`.`entry` IN ({ecsv})
  AND `t`.`maxlevel` BETWEEN 130 AND 160
  AND `t`.`rank` <> 3
  AND `t`.`type` <> 8
  AND `s`.`basehp0` > 0;

-- Quest objectives: point the kill targets at the spawned clones, as 11_quests does
UPDATE `quest_template` SET
""")
    targets = csv(OBJECTIVE_TARGETS)
    slots = [f"  `RequiredNpcOrGo{n}` = IF(`RequiredNpcOrGo{n}` IN ({targets}), "
             f"`RequiredNpcOrGo{n}` + 3600000, `RequiredNpcOrGo{n}`)" for n in range(1, 5)]
    out.append(",\n".join(slots))
    out.append(f"\nWHERE `ID` IN ({csv(OBJECTIVE_QUESTS)});\n")
    out.append("\n-- Quest levels: these chains stayed at their Cata levels, scaled like the rest of 71_\n")
    scaled = sorted(q for ids in QUEST_BANDS.values() for q in ids)
    for minlevel, ids in QUEST_BANDS.items():
        out.append(f"UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = {minlevel} "
                   f"WHERE `ID` IN ({csv(ids)});\n")
    out.append(f"DELETE FROM `dc_map751_questband` WHERE `quest` IN ({csv(scaled)});\n")
    out.append(table("dc_map751_questband", ["quest", "t_lo"],
                     [[str(q), str(QUEST_FLOOR[m])] for m, ids in QUEST_BANDS.items() for q in ids]))
    return "".join(out), guids, addons


def gameobject_sql(layer, tiles, chunks):
    columns, rows = layer["gameobject"]
    col = {name: i for i, name in enumerate(columns)}
    keep = []
    for src in rows:
        raw = int(src[col["id"]]) - OFFSET
        if raw not in RESTORED_GAMEOBJECTS:
            continue
        row = list(src)
        zone = zone_of(float(row[col["position_x"]]), float(row[col["position_y"]]), tiles, chunks)
        row[col["zoneId"]] = row[col["areaId"]] = str(zone)
        # Every gameobject row in 30_ carries spawnMask 0, live rows were corrected to 1 later
        row[col["spawnMask"]] = "1"
        row[col["Comment"]] = "'Plague-Nel restore'"
        rotation = [float(row[col[f"rotation{i}"]]) for i in range(4)]
        if abs(sum(v * v for v in rotation) - 1) > 0.01:
            half = float(row[col["orientation"]]) / 2
            row[col["rotation0"]] = row[col["rotation1"]] = "0"
            row[col["rotation2"]] = f"{math.sin(half):.6f}"
            row[col["rotation3"]] = f"{math.cos(half):.6f}"
        keep.append(row)
    raws = csv(RESTORED_GAMEOBJECTS)
    clones = csv(r + OFFSET for r in RESTORED_GAMEOBJECTS)
    guids = [int(r[col["guid"]]) for r in keep]
    sql = f"""-- Map 751: restore the gameobjects the orphan cleanup of 30_ removed.
--
-- Unlike the creatures these never got a template, so each one is cloned from stock here.
-- Only entries with stock spawns qualify, which keeps out the seasonal decorations that
-- make up most of the lost rows, plus the Andorhal towers the watchtower quest needs.
-- Generated by Custom/Documentation/scripts/gen_map751_spawn_restore.py
--
-- Safe to run twice.

-- Templates. gameobject_template rows may not be deleted, so they go through a scratch copy.
DROP TABLE IF EXISTS `_dc_map751_go_tpl`;
CREATE TABLE `_dc_map751_go_tpl` LIKE `gameobject_template`;
DELETE FROM `_dc_map751_go_tpl`;
INSERT INTO `_dc_map751_go_tpl` SELECT * FROM `gameobject_template` WHERE `entry` IN ({raws});
UPDATE `_dc_map751_go_tpl` SET `entry` = `entry` + 3600000;
REPLACE INTO `gameobject_template` SELECT * FROM `_dc_map751_go_tpl`;
DROP TABLE `_dc_map751_go_tpl`;

-- Flags and faction live in the side table, 103_ shows what happens without it
DELETE FROM `gameobject_template_addon` WHERE `entry` IN ({clones});
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry` + 3600000, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`
FROM `gameobject_template_addon`
WHERE `entry` IN ({raws});

-- Spawns
DELETE FROM `gameobject` WHERE `map` = 751 AND `id` IN ({clones}) AND `guid` IN ({csv(guids)});
"""
    return sql + table("gameobject", columns, keep), keep, col


def dedupe_sql():
    guids = csv(DUPLICATE_CREATURES)
    ids = csv(set(DUPLICATE_CREATURES.values()))
    return f"""-- Map 751: remove duplicated spawns.
--
-- 30_ replaced the Cata creature layer but never removed the Cata gameobject layer, so
-- those rows sit exactly on their Neltharion copies. The Cata and extension imports also
-- carry repeats of their own, such as doors listed six times. 46 pooled nodes are listed
-- twice in the same pool.
--
-- A duplicate is the same entry at the same spot with the same facing. Different facing
-- is left alone, that is how some decorations are built. One copy always stays, preferring
-- the pooled set, then the Neltharion layer, then the extension, then the Cata layer.
-- Event-bound and script-bound rows are never removed, nor worldforged pickups, whose guid
-- is their claim key. A pooled row only goes when its survivor is in the same pool.
--
-- Everything removed is kept in the dc_map751_dedupe_*_bak tables.
-- Generated by Custom/Documentation/scripts/gen_map751_spawn_restore.py
--
-- Safe to run twice.

DROP TABLE IF EXISTS `_dc_map751_go_rank`;
CREATE TABLE `_dc_map751_go_rank` (
  `guid` INT UNSIGNED NOT NULL,
  `id` INT UNSIGNED NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `o` FLOAT NOT NULL,
  `rnk` TINYINT UNSIGNED NOT NULL,
  `pool_entry` INT UNSIGNED NOT NULL,
  `locked` TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`),
  KEY `idx_id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
DELETE FROM `_dc_map751_go_rank`;
INSERT INTO `_dc_map751_go_rank` (`guid`, `id`, `x`, `y`, `z`, `o`, `rnk`, `pool_entry`, `locked`)
SELECT
  `g`.`guid`, `g`.`id`, `g`.`position_x`, `g`.`position_y`, `g`.`position_z`, `g`.`orientation`,
  CASE
    WHEN `g`.`guid` BETWEEN 15000000 AND 15099999 THEN 0
    WHEN `g`.`guid` BETWEEN 13500000 AND 13999999 THEN 1
    WHEN `g`.`guid` BETWEEN 16000000 AND 16777215 THEN 2
    WHEN `g`.`guid` BETWEEN 12000000 AND 12999999 THEN 3
    ELSE 4
  END,
  COALESCE(`p`.`pool_entry`, 0),
  `g`.`guid` BETWEEN 6900000 AND 6999999
FROM `gameobject` `g`
LEFT JOIN `pool_gameobject` `p` ON `p`.`guid` = `g`.`guid`
WHERE `g`.`map` = 751;
UPDATE `_dc_map751_go_rank` SET `locked` = 1 WHERE `guid` IN (SELECT `guid` FROM `game_event_gameobject`);
UPDATE `_dc_map751_go_rank` SET `locked` = 1 WHERE `guid` IN (SELECT -`entryorguid` FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` < 0);
UPDATE `_dc_map751_go_rank` SET `locked` = 1 WHERE `guid` IN (SELECT `target_param1` FROM `smart_scripts` WHERE `target_type` = 14);

DROP TABLE IF EXISTS `_dc_map751_go_dedupe`;
CREATE TABLE `_dc_map751_go_dedupe` (
  `guid` INT UNSIGNED NOT NULL,
  `id` INT UNSIGNED NOT NULL,
  `keep_guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
DELETE FROM `_dc_map751_go_dedupe`;
INSERT INTO `_dc_map751_go_dedupe` (`guid`, `id`, `keep_guid`)
SELECT
  `a`.`guid`, `a`.`id`, MIN(`b`.`guid`)
FROM `_dc_map751_go_rank` `a`
JOIN `_dc_map751_go_rank` `b` ON `b`.`id` = `a`.`id`
  AND ABS(`b`.`x` - `a`.`x`) < 0.05
  AND ABS(`b`.`y` - `a`.`y`) < 0.05
  AND ABS(`b`.`z` - `a`.`z`) < 0.05
  AND ABS(SIN((`b`.`o` - `a`.`o`) / 2)) < 0.01
  AND (`b`.`rnk` < `a`.`rnk` OR (`b`.`rnk` = `a`.`rnk` AND `b`.`guid` < `a`.`guid`))
WHERE `a`.`locked` = 0
  AND (`a`.`pool_entry` = 0 OR `a`.`pool_entry` = `b`.`pool_entry`)
GROUP BY `a`.`guid`, `a`.`id`;

CREATE TABLE IF NOT EXISTS `dc_map751_dedupe_go_bak` LIKE `gameobject`;
CREATE TABLE IF NOT EXISTS `dc_map751_dedupe_pool_bak` LIKE `pool_gameobject`;
CREATE TABLE IF NOT EXISTS `dc_map751_dedupe_creature_bak` LIKE `creature`;
DELETE FROM `dc_map751_dedupe_go_bak` WHERE `guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);
INSERT INTO `dc_map751_dedupe_go_bak`
SELECT `g`.* FROM `gameobject` `g` WHERE `g`.`guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);
DELETE FROM `dc_map751_dedupe_pool_bak` WHERE `guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);
INSERT INTO `dc_map751_dedupe_pool_bak`
SELECT `p`.* FROM `pool_gameobject` `p` WHERE `p`.`guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);

DELETE FROM `pool_gameobject` WHERE `guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);
DELETE FROM `gameobject_addon` WHERE `guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);
DELETE FROM `gameobject` WHERE `map` = 751 AND `id` IN (SELECT `id` FROM `_dc_map751_go_dedupe`) AND `guid` IN (SELECT `guid` FROM `_dc_map751_go_dedupe`);
DROP TABLE `_dc_map751_go_rank`, `_dc_map751_go_dedupe`;

-- Creatures: same entry, same spot, same movement. Pairs where one copy walks away, such as
-- the Caer Darrow citizens, are two real NPCs and stay.
DELETE FROM `dc_map751_dedupe_creature_bak` WHERE `guid` IN ({guids});
INSERT INTO `dc_map751_dedupe_creature_bak`
SELECT `c`.* FROM `creature` `c` WHERE `c`.`guid` IN ({guids});
DELETE FROM `creature_addon` WHERE `guid` IN ({guids});
DELETE FROM `creature` WHERE `map` = 751 AND `id` IN ({ids}) AND `guid` IN ({guids});
"""


def quest_repair_sql(layer, tiles, chunks):
    columns, rows = layer["creature"]
    col = {name: i for i, name in enumerate(columns)}
    gargoyles = []
    for src in rows:
        if int(src[col["id"]]) - OFFSET != 44955:
            continue
        row = list(src)
        zone = zone_of(float(row[col["position_x"]]), float(row[col["position_y"]]), tiles, chunks)
        assert zone == 4932, zone
        row[col["zoneId"]] = row[col["areaId"]] = str(zone)
        row[col["equipment_id"]] = "0"
        if row[col["MovementType"]] == "2":
            row[col["MovementType"]] = "0"
        row[col["Comment"]] = "'Plague-Nel restore'"
        gargoyles.append(row)
    guids = [int(r[col["guid"]]) for r in gargoyles]

    smart = ", ".join(f"`{c}`" for c in SMART_COLUMNS)
    picked = ", ".join(
        "IF(`target_type` = 20 AND `target_param1` = 177668, 3777668, `target_param1`)"
        if c == "target_param1" else ("`entryorguid` + 3600000" if c == "entryorguid" else f"`{c}`")
        for c in SMART_COLUMNS)
    copies = csv(i + OFFSET for i in SAI_COPIES)
    marks = [i + OFFSET for i in MARKS]
    conditions = [["13", "1", "19250", "0", str(group), "31", "0", "3", str(entry), "0", "0", "0", "0", "''",
                   "'Place Smokeys Explosive targets Mark of Detonation clone'"]
                  for group, entry in enumerate(marks, start=8)]
    conditions.append(["13", "4", "19250", "0", "1", "31", "0", "3", "3612247", "0", "0", "0", "0", "''",
                       "'Place Smokeys Explosive targets Scourge Structure clone'"])
    tower_ai = [[str(raw + OFFSET), "0", "0", "0", "10", "0", "100", "0", "2", "30", "1000", "1000", "1", "0",
                 "33", str(raw), "0", "0", "0", "0", "0", "7", "0", "0", "0", "0", "0", "0", "0", "0",
                 "'DC ADAPTATION q5097 - Beacon Torch at the tower grants the stock credit'"]
                for raw in TOWERS]
    tower_conditions = [["22", "1", str(raw + OFFSET), "0", "0", "30", "1", "176093", "10", "0", "0", "0", "0", "''",
                         "'Only with a lit Beacon Torch beside the tower'"] for raw in TOWERS]
    towers = csv(raw + OFFSET for raw in TOWERS)
    slots = ",\n".join(
        f"  `RequiredNpcOrGo{n}` = IF(`RequiredNpcOrGo{n}` IN ({csv(OBJECTIVE_TARGETS_2)}), "
        f"`RequiredNpcOrGo{n}` + 3600000, `RequiredNpcOrGo{n}`)" for n in range(1, 5))
    raws = csv(QUEST_NPCS)
    clones = csv(i + OFFSET for i in QUEST_NPCS)
    credit_822 = "".join(f"UPDATE `creature_template` SET `KillCredit1` = {raw} "
                         f"WHERE `entry` = {entry} AND `KillCredit1` = 0;\n"
                         for entry, raw in sorted(KILL_CREDIT_822.items()))
    out = [f"""-- Map 751: make the broken quests completable and give the restored NPCs their quests.
--
-- Stock quests are shared with map 0, so no stock quest row is edited here. A clone joins
-- as an extra giver and earns the raw objective through KillCredit. Cata quests are only
-- used on this map, so their objectives point straight at the clones, as 11_quests does.
-- Generated by Custom/Documentation/scripts/gen_map751_spawn_restore.py
--
-- Safe to run twice.

-- Ebon Gargoyles: The Farmers Militia needs them, so they were not sniffed summons after all
DELETE FROM `creature` WHERE `map` = 751 AND `id` = 3644955 AND `guid` IN ({csv(guids)});
"""]
    out.append(table("creature", list(col), gargoyles))
    out.append("""DELETE FROM `dc_map751_entryzone` WHERE `entry` = 3644955;
INSERT INTO `dc_map751_entryzone` (`entry`, `zone`) VALUES
(3644955, 4932);
DELETE FROM `dc_map751_snap` WHERE `entry` = 3644955;
INSERT INTO `dc_map751_snap` (`entry`, `minlevel`, `maxlevel`, `rank`) VALUES
(3644955, 40, 40, 0);
DELETE FROM `dc_map751_stat_snap` WHERE `entry` = 3644955;
INSERT INTO `dc_map751_stat_snap` (`entry`, `HealthModifier`, `ManaModifier`, `DamageModifier`, `ArmorModifier`) VALUES
(3644955, 1, 1, 0.65, 1);
UPDATE `creature_template` SET `minlevel` = 152, `maxlevel` = 152 WHERE `entry` = 3644955;
UPDATE `creature_template` `t`
JOIN `dc_map751_stat_snap` `snap` ON `snap`.`entry` = `t`.`entry`
JOIN `dc_map751_rank_scale` `r` ON `r`.`rank` = `t`.`rank`
JOIN `creature_classlevelstats` `s` ON `s`.`level` = `t`.`maxlevel` AND `s`.`class` = `t`.`unit_class` SET
  `t`.`HealthModifier` = GREATEST(`snap`.`HealthModifier`, (`s`.`basehp2` * `r`.`hp_factor`) / `s`.`basehp0`),
  `t`.`DamageModifier` = GREATEST(`snap`.`DamageModifier`, `r`.`dmg_floor`)
WHERE `t`.`entry` = 3644955;

-- Cata kill objectives that still named the raw entry
UPDATE `quest_template` SET
""")
    out.append(slots)
    out.append(f"""
WHERE `ID` IN ({csv(OBJECTIVE_QUESTS_2)});

-- Stock kill objectives: clones credit the raw entry, the quest rows stay untouched
UPDATE `creature_template` SET `KillCredit1` = `entry` - 3600000 WHERE `KillCredit1` = 0 AND `entry` IN ({csv(i + OFFSET for i in KILL_CREDIT)});
{credit_822}
-- Scholomance clone: Doctor Krastinov also requires using both remains, and gameobjects have
-- no kill credit, so the two spawns on map 822 become the stock objects. Same script.
UPDATE `gameobject` SET `id` = 176544 WHERE `map` = 822 AND `id` = 5800036 AND `guid` = 16530033;
UPDATE `gameobject` SET `id` = 176545 WHERE `map` = 822 AND `id` = 5800037 AND `guid` = 16530034;

-- Stock SmartAI the clones never received. The mark despawn targets the map 751 gameobject.
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN ({copies});
INSERT INTO `smart_scripts` ({smart})
SELECT
  {picked}
FROM `smart_scripts`
WHERE `source_type` = 0
  AND `entryorguid` IN ({csv(SAI_COPIES)});
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `ScriptName` = '' AND `entry` IN ({copies});

-- Forsaken Trooper already has its script rows, but no AI to run them
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `ScriptName` = '' AND `entry` = 3645085;

-- Smokeys charge only reaches entries named in conditions, and those are stock entries
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` = 19250 AND `ConditionValue2` IN ({csv(marks + [3612247])});
""")
    out.append(table("conditions", CONDITION_COLUMNS, conditions))
    out.append(f"""
-- Andorhal towers: same check as stock npc_andorhal_tower, crediting the raw entry
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN ({towers});
""")
    out.append(table("smart_scripts", SMART_COLUMNS, tower_ai))
    out.append(f"""UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `ScriptName` = '' AND `entry` IN ({towers});
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND `SourceEntry` IN ({towers});
""")
    out.append(table("conditions", CONDITION_COLUMNS, tower_conditions))
    out.append(f"""
-- Quest links, enders first so nothing is ever offered without a turn-in
DELETE FROM `creature_questender` WHERE `id` IN ({clones});
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT `id` + 3600000, `quest`
FROM `creature_questender`
WHERE `id` IN ({raws});
DELETE FROM `creature_queststarter` WHERE `id` IN ({clones});
INSERT INTO `creature_queststarter` (`id`, `quest`)
SELECT `id` + 3600000, `quest`
FROM `creature_queststarter`
WHERE `id` IN ({raws});
""")
    return "".join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    layer = parse_layer()
    tiles, chunks = parse_zones()
    columns, rows = layer["creature"]
    col = {name: i for i, name in enumerate(columns)}

    keep, dominant = restored_creatures(rows, col, tiles, chunks)
    creature_text, guids, addons = creature_sql(layer, keep, dominant, col)
    go_text, go_keep, go_col = gameobject_sql(layer, tiles, chunks)

    print(f"creatures {len(keep)} rows, {len(dominant)} entries, {len(addons)} addons")
    print("zones:", collections.Counter(r[col["zoneId"]] for r in keep).most_common())
    print(f"gameobjects {len(go_keep)} rows, {len(RESTORED_GAMEOBJECTS)} entries")
    print("GO zones:", collections.Counter(r[go_col["zoneId"]] for r in go_keep).most_common())
    paths = {r[1] for r in addons if r[1] != "0"}
    moving = [r for r in keep if r[col["MovementType"]] == "2"]
    print("paths:", sorted(paths), "MT2 rows:", len(moving))
    with_path = {r[0] for r in addons if r[1] != "0"}
    print("MT2 without path:", [r[col["guid"]] for r in moving if r[col["guid"]] not in with_path])
    print("auras:", sorted({a for r in addons for a in r[7].strip("'").split() if a != "NULL"}))
    print("mounts:", sorted({r[2] for r in addons if r[2] != "0"}))
    print("entries:", csv(dominant))
    spots = collections.Counter((r[col["id"]], r[col["position_x"]], r[col["position_y"]],
                                 r[col["position_z"]]) for r in keep)
    print("stacked rows inside the restore:", sum(1 for n in spots.values() if n > 1))
    caer = {13018037, 13045423, 13045424} | set(range(13131325, 13131348))
    print("guid overlap with Caer Darrow:", sorted(caer & set(guids)))
    print("duplicate guids:", len(guids) - len(set(guids)), "over cap:", sum(g > 16777215 for g in guids))
    bad = 0
    for r in go_keep:
        q = [float(r[go_col[f"rotation{i}"]]) for i in range(4)]
        bad += abs(sum(v * v for v in q) - 1) > 0.01
    print("GO rows with a non-unit rotation:", bad)
    print("GO rows with spawnMask 0:", sum(r[go_col["spawnMask"]] == "0" for r in go_keep))
    print("creature rows still MT2:", sum(r[col["MovementType"]] == "2" for r in keep))
    print("tuple widths:", {len(r) for r in keep}, {len(r) for r in go_keep}, {len(r) for r in addons})
    print("per-reason exclusions:")
    per_entry = collections.Counter(int(r[col["id"]]) - OFFSET for r in rows)
    for why, ids in EXCLUDED_CREATURES.items():
        print(f"  {sum(per_entry[i] for i in ids & LOST_ENTRIES):4d}  {why}")

    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        for name, text in (("map751_lost_creatures.sql", creature_text),
                           ("map751_lost_gameobjects.sql", go_text),
                           ("map751_dedupe_spawns.sql", dedupe_sql()),
                           ("map751_quest_repairs.sql", quest_repair_sql(layer, tiles, chunks))):
            (args.out / name).write_text(text, encoding="utf-8", newline="\n")
            print("wrote", args.out / name)


if __name__ == "__main__":
    main()
