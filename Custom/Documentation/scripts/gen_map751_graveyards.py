#!/usr/bin/env python3
"""Generate `Custom/Custom feature SQLs/worlddb/Plaguelands/69_new_zone_graveyards.sql`.

Ports the AUTHENTIC Cataclysm graveyards for the nine map-751 zones. Sibling of
gen_map750_graveyards.py; same sources, same reasoning:
  * positions: cata_dbc/WorldSafeLocs.dbc (4.3.x, extracted from
    K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ -- WDBC, 6 fields:
    Id, Continent, x, y, z, name stringref). cata_world has NO worldsafelocs
    table, so the DBC is the only position source and the coordinates have to be
    baked into the SQL as literals.
  * zone links + factions: cata_world.graveyard_zone, snapshotted into GY_LINKS
    below (2026-08-19). Faction 469 = Alliance, 67 = Horde, 0 = both.

Map 751 is a coordinate-preserving copy of Eastern Kingdoms, so Blizzard's
ground-verified positions drop in unchanged. Entries outside the 195-tile
footprint are skipped rather than dragged to the edge of the map.

Re-run after editing GY_LINKS; never hand-edit the SQL.
"""

import os
import struct

# (cata_safeloc_id, cata_zone, faction) — snapshot of cata_world.graveyard_zone
GY_LINKS = [
    (509, 28, 469), (569, 28, 67), (829, 28, 0), (869, 28, 0), (1286, 28, 0),
    (1809, 28, 0), (1878, 28, 0),
    (99, 45, 0), (1446, 45, 0),
    (349, 47, 469), (789, 47, 67), (1453, 47, 0), (1454, 47, 0),
    (94, 85, 67), (96, 85, 67), (289, 85, 67), (569, 85, 67), (629, 85, 469),
    (1409, 85, 469), (1874, 85, 0),
    (97, 130, 67), (149, 130, 469), (1256, 130, 0), (1870, 130, 0),
    (510, 139, 0), (634, 139, 0), (909, 139, 0), (927, 139, 0), (1369, 139, 0),
    (1405, 139, 0), (1448, 139, 0), (1449, 139, 0), (1450, 139, 0), (1451, 139, 0),
    (98, 267, 67), (149, 267, 469), (1411, 267, 0), (1447, 267, 0),
    (1452, 267, 0), (1852, 267, 0),
    (96, 1497, 67),
    (1810, 4706, 0), (1811, 4706, 0),
]

# Undercity (1497) has no terrain of its own on 751 — it sits inside the Tirisfal
# tiles — so its ghosts route to the Tirisfal graveyard set.
CATA_TO_DC = {28: 4932, 45: 4938, 47: 4937, 85: 4933, 130: 4935,
              139: 4924, 267: 4936, 1497: 4933, 4706: 4939}

BASE_ID = 15100          # game_graveyard ids; 15100-15199 verified free (max live = 15063)
SPIRIT_HEALER = 6491     # stock Spirit Healer

# map-751 playable footprint from the 195 staged tiles (cols 27-43, rows 25-36)
#   x = (32 - row) * 533.3333 ; y = (32 - col) * 533.3333
FOOT_X = (-2133.4, 3733.4)
FOOT_Y = (-5866.7, 2666.7)

HERE = os.path.dirname(os.path.abspath(__file__))
DBC = os.path.join(HERE, 'cata_dbc', 'WorldSafeLocs.dbc')
OUT = os.path.join(HERE, '..', '..', 'Custom feature SQLs', 'worlddb',
                   'Plaguelands', '69_new_zone_graveyards.sql')


def read_worldsafelocs(path):
    """WDBC: magic, recordCount, fieldCount, recordSize, stringBlockSize, then
    records of (Id, Continent, x, y, z, nameStringRef)."""
    b = open(path, 'rb').read()
    assert b[:4] == b'WDBC', b[:4]
    rc, fc, rs, sb = struct.unpack_from('<4I', b, 4)
    base = 20
    strings = b[base + rc * rs:]
    out = {}
    for i in range(rc):
        o = base + i * rs
        sid, cont, x, y, z, nref = struct.unpack_from('<IIfffI', b, o)
        end = strings.find(b'\x00', nref)
        name = strings[nref:end].decode('utf-8', 'replace') if nref else ''
        out[sid] = (cont, x, y, z, name)
    return out, rc, fc, rs


locs, rc, fc, rs = read_worldsafelocs(DBC)
print(f"WorldSafeLocs.dbc: {rc} records, {fc} fields, recordSize {rs}")

used = sorted({sid for sid, _z, _f in GY_LINKS})
missing = [s for s in used if s not in locs]
print(f"distinct safelocs referenced: {len(used)}   missing from DBC: {missing}")

kept, skipped = {}, []
for sid in used:
    cont, x, y, z, name = locs[sid]
    if not (FOOT_X[0] <= x <= FOOT_X[1] and FOOT_Y[0] <= y <= FOOT_Y[1]):
        skipped.append((sid, name, round(x), round(y)))
        continue
    kept[sid] = (x, y, z, name)

print(f"inside the map-751 footprint: {len(kept)}   outside (skipped): {len(skipped)}")
for s in skipped:
    print(f"   skipped {s[0]:5d} {s[1]:34s} x={s[2]} y={s[3]}")

newid = {sid: BASE_ID + i for i, sid in enumerate(sorted(kept))}

# graveyard_zone's PK is (ID, GhostZone). Two source zones can collapse onto one DC
# zone — Undercity 1497 folds into Tirisfal 4933 — and then a safeloc linked to both
# yields the SAME (id, zone) pair twice. Deduplicate, and if the two rows disagree on
# faction take 0 (both), which is the permissive, non-stranding choice.
by_pair = {}
for sid, z, f in GY_LINKS:
    if sid not in kept:
        continue
    key = (sid, CATA_TO_DC[z])
    if key in by_pair and by_pair[key] != f:
        by_pair[key] = 0
    else:
        by_pair.setdefault(key, f)
links = [(sid, dc, f) for (sid, dc), f in by_pair.items()]
dropped = len([1 for s, z, _f in GY_LINKS if s in kept]) - len(links)
zones = sorted({dc for _s, dc, _f in links})
print(f"graveyards {len(kept)}, links {len(links)} "
      f"({dropped} duplicate (id,zone) pair(s) collapsed), zones covered {zones}")

L = []
w = L.append
w("-- 69_new_zone_graveyards.sql — map 751 Lordaeron extension, DB step 8.")
w("-- GENERATED by Custom/Documentation/scripts/gen_map751_graveyards.py — do not hand-edit.")
w("--")
w("-- Map 751 had ZERO rows in game_graveyard, so every death anywhere in the eight")
w("-- zones fell back to whatever the core could find — the single stale 4924 link.")
w("-- This ports Blizzard's own Cataclysm graveyard set: positions from the 4.3.x")
w("-- WorldSafeLocs.dbc (cata_world has no worldsafelocs table, so they are literals),")
w("-- zone links and faction routing from cata_world.graveyard_zone.")
w("--")
w(f"-- {len(kept)} graveyards at ids {BASE_ID}-{BASE_ID + len(kept) - 1} (band verified free,")
w("-- live max was 15063 from the map-750 set), {} zone links.".format(len(links)))
w("-- Faction 469 = Alliance only, 67 = Horde only, 0 = both.")
w("-- Undercity ghosts route to the Tirisfal set: 4934 has no terrain of its own.")
w("-- A stock Spirit Healer (6491) is spawned at every graveyard, guids allocated")
w("-- from MAX(guid)+1 at apply time — spawn guids are 24-bit, see 67_.")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- Graveyard locations")
w("-- ---------------------------------------------------------------------------")
w(f"DELETE FROM `graveyard_zone` WHERE `ID` BETWEEN {BASE_ID} AND {BASE_ID + 199};")
w(f"DELETE FROM `game_graveyard` WHERE `ID` BETWEEN {BASE_ID} AND {BASE_ID + 199};")
w("DELETE FROM `graveyard_zone` WHERE `GhostZone` IN (4924,4932,4933,4935,4936,4937,4938,4939);")
w("")
vals = []
for sid in sorted(kept):
    x, y, z, name = kept[sid]
    nm = name.replace("'", "''")
    vals.append(f"({newid[sid]},751,{x:.4f},{y:.4f},{z:.4f},'{nm} (751)')")
w("INSERT INTO `game_graveyard` (`ID`,`Map`,`x`,`y`,`z`,`Comment`) VALUES")
w(",\n".join(vals) + ";")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- Zone links (which graveyard a ghost in which zone routes to, per faction)")
w("-- ---------------------------------------------------------------------------")
lv = []
for sid, dc, f in sorted(links, key=lambda t: (t[1], t[0])):
    nm = kept[sid][3].replace("'", "''")
    lv.append(f"({newid[sid]},{dc},{f},'{nm} -> zone {dc}')")
w("INSERT INTO `graveyard_zone` (`ID`,`GhostZone`,`Faction`,`Comment`) VALUES")
w(",\n".join(lv) + ";")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- Spirit healers, one per graveyard")
w("-- ---------------------------------------------------------------------------")
w(f"DELETE c FROM `creature` c WHERE c.`map` = 751 AND c.`id` = {SPIRIT_HEALER};")
w("SET @sh := (SELECT MAX(`guid`) FROM `creature`);")
w("INSERT INTO `creature`")
w("  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,")
w("   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,")
w("   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,")
w("   `npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)")
w("SELECT")
w(f"  @sh := @sh + 1, {SPIRIT_HEALER}, 751, z.`zone`, z.`zone`,")
w("  1, 1, 0, g.`x`, g.`y`, g.`z`, 0, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Lordaeron-ext GY'")
w("FROM `game_graveyard` g")
w("-- JOIN, not a scalar subquery: guarantees a non-null zone (the column is NOT NULL)")
w("-- and quietly skips any graveyard that ended up with no zone link.")
w("-- One row per graveyard even when it serves several zones.")
w("JOIN (SELECT `ID`, MIN(`GhostZone`) AS `zone` FROM `graveyard_zone` GROUP BY `ID`) z")
w("  ON z.`ID` = g.`ID`")
w(f"WHERE g.`Map` = 751 AND g.`ID` BETWEEN {BASE_ID} AND {BASE_ID + 199};")
w("")
w("-- guid ceiling guard (0xFFFFFF); must return 0")
w("SELECT 'PROBLEM: spirit healer guid over cap' AS problem, COUNT(*) AS n")
w("FROM `creature` WHERE `guid` > 16777215;")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- Verification")
w("-- ---------------------------------------------------------------------------")
w("SELECT 'graveyards on map 751' AS what, COUNT(*) AS n FROM `game_graveyard` WHERE `Map` = 751")
w("UNION ALL SELECT 'zone links', COUNT(*) FROM `graveyard_zone`")
w("  WHERE `GhostZone` IN (4924,4932,4933,4935,4936,4937,4938,4939)")
w("UNION ALL SELECT 'spirit healers spawned', COUNT(*) FROM `creature`")
w(f"  WHERE `map` = 751 AND `id` = {SPIRIT_HEALER};")
w("")
w("SELECT `GhostZone`, COUNT(*) AS graveyards, SUM(`Faction`=0) AS both_factions,")
w("       SUM(`Faction`=469) AS alliance, SUM(`Faction`=67) AS horde")
w("FROM `graveyard_zone`")
w("WHERE `GhostZone` IN (4924,4932,4933,4935,4936,4937,4938,4939)")
w("GROUP BY `GhostZone` ORDER BY `GhostZone`;")
w("")
w("-- every zone with spawns must have at least one graveyard reachable by BOTH")
w("-- factions, or one faction dies into a permanent corpse run")
w("SELECT 'PROBLEM: zone with no neutral/either-faction graveyard' AS problem, z.`zone`")
w("FROM (SELECT DISTINCT `zoneId` AS `zone` FROM `creature` WHERE `map` = 751) z")
w("WHERE NOT EXISTS (SELECT 1 FROM `graveyard_zone` g")
w("                  WHERE g.`GhostZone` = z.`zone` AND g.`Faction` = 0)")
w("  AND NOT (EXISTS (SELECT 1 FROM `graveyard_zone` g2 WHERE g2.`GhostZone` = z.`zone` AND g2.`Faction` = 469)")
w("       AND EXISTS (SELECT 1 FROM `graveyard_zone` g3 WHERE g3.`GhostZone` = z.`zone` AND g3.`Faction` = 67));")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8', newline='\n').write("\n".join(L) + "\n")
print(f"\nwrote {os.path.normpath(OUT)}  ({len(L)} lines)")
