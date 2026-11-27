#!/usr/bin/env python3
"""Generate DC's worldforged pickup layer on maps 750/751 from Ascension CoA's worldforged pickups.

CoA ("Conquest of Azeroth") places one-per-character treasure objects ("worldforged pickups") all over
the classic world, each holding one named base item. Maps 750 (80-130) and 751 (130-160) are
coordinate-preserving copies of Kalimdor (map 1) and the Eastern Kingdoms (map 0), so a CoA spawn in a
zone those maps represent keeps its X/Y; its height is re-derived from DC's own terrain, and its item is
cloned and re-levelled to the DC zone band it lands in.

Pipeline (each stage reads the previous one's cache in --work):
  1. replay   CoA's ~40 worldforged migrations into SQLite (coa_replay.py)
  2. place    project map 1 -> 750 / map 0 -> 751, resolve the DC zone from the server .map area grid,
              keep spawns whose stock source zone DC represents, decide the height
              (DC ground / witnessed floor / snap / shallow sea floor) - data/witness_results.json pins
              the DC-spawn witness query (see README)
  3. items    CoA item_template rows of the placed items, out of the CoA world package
  4. assign   pinned id allocation (data/allocation.csv): items, GO templates, spawn guids, displays
  5. emit     pending_db_world SQL + the client DBC rows + the Ascension asset list

The spawn guid IS the per-character "already looted" key (dc_worldforged_pickups.cpp keeps one bit per
guid in character_settings), so allocations are append-only: never renumber an allocated row.

Usage:
  python gen_worldforged_750_751.py --work K:/tmp/worldforged_build            # dry run, report only
  python gen_worldforged_750_751.py --work K:/tmp/worldforged_build --write    # + SQL / CSV rows / assets
"""
import argparse
import csv
import io
import json
import math
import re
import sqlite3
import subprocess
import sys
import time
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import coa_replay  # noqa: E402
from dc_terrain import probe  # noqa: E402
from wdbc import DBC  # noqa: E402

REPO = HERE.parents[3]                 # Custom/Documentation/scripts/worldforged -> repository root
COA_ZIP = Path(r"K:/Dark-Chaos/Ascension COA/azerothcore-wotlk-coa/data/coa-world/coa-world-20260912.zip")
ASC_DATA = Path(r"K:/UntouchedClients/ascension_live/Data")
DC_DBC = REPO / "Custom" / "DBCs"
SERVER_DBC = Path(r"K:/Dark-Chaos/Server/data/dbc")
AREATABLE_CSV = REPO / "Custom" / "CSV DBC" / "AreaTable.csv"
ARMOR_TOOL = REPO / "Custom" / "Documentation" / "scripts" / "gen_zone_gear_armor_dmg.py"
CURVES = Path(r"K:/tmp/cata-itemcurves")
MPQ_EXTRACT = Path(r"K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py")
PENDING_WORLD = REPO / "data" / "sql" / "updates" / "pending_db_world"
ALLOCATION = HERE / "data" / "allocation.csv"
WITNESS = HERE / "data" / "witness_results.json"
OVERRIDES = HERE / "data" / "position_overrides.csv"   # positions pinned by spawn guid (see README)
RETAINED = HERE / "data" / "retained_spawns.json"      # placements DC keeps after CoA dropped them (see README)
EXCLUDED = HERE / "data" / "excluded_spawns.csv"       # CoA pickups DC does not place, with the reason (see README)
SHIPPED_SQL = REPO / "Custom" / "Custom feature SQLs" / "worlddb" / "worldforged"   # applied + archived
WITNESS_TOLERANCE = 0.06               # witness rows hold the spot rounded to 0.1 yd

SCRIPT_NAME = "go_dc_worldforged_pickup"
LOCK_OPEN = 1689                       # stock Lock.dbc "Open" (LOCK_KEY_SKILL / LOCKTYPE_OPEN, no skill)
BLOCKS = {                             # inclusive id blocks, all verified empty 2026-10-06
    "item": (504001, 504999),          # item_template + Item.dbc
    "gotpl": (5000001, 5000999),       # gameobject_template + gameobject_loot_template
    "spawn": (6900001, 6999999),       # gameobject.guid - must match WorldforgedGuidFirst in the C++
    "idi": (200001, 200999),           # ItemDisplayInfo.dbc
    "godi": (200001, 200999),          # GameObjectDisplayInfo.dbc
    # Props, verified empty 2026-11-23. Outside the spawn block on purpose: the C++ sizes every account's claim
    # words by the highest guid in that block, scripted or not.
    "prop_spawn": (9028001, 9028999),  # gameobject.guid of the decoration props beside pickups
    "prop_tpl": (5001001, 5001999),    # their gameobject_template rows (type 5, no loot)
}
COA_PROP_GUIDS = (6976000, 6979999)    # CoA's block for the props it restores beside its pickups (since 2026-11-12)
PROP_RADIUS = 15.0                     # a prop belongs to the nearest pickup this close

# DC zone -> (band low = RequiredLevel, green base item level). Map 750 rows are 309_'s own table;
# map 751 had no gear ladder, so it continues the same curve (+5 per band step, ~400 -> ~440).
ZONE_BAND = {
    4929: (80, 285), 4930: (80, 285), 4931: (88, 315), 4927: (96, 355),
    4928: (96, 355),        # Moonglade is a sanctuary without a band: its Felwood entrance's band
    4926: (104, 372), 4923: (113, 385),
    4933: (130, 400), 4939: (130, 400), 4935: (134, 405), 4936: (138, 410),
    4938: (142, 415), 4937: (145, 420), 4932: (148, 425), 4924: (152, 430),
}
TARGET_MAP = {1: 750, 0: 751}
# Stock zones each DC continent represents. Spawns on map-750/751 chunks that were folded in from any
# other zone (Durotar -> Azshara, Barrens/Stonetalon -> Ashenvale, Wetlands -> Arathi...) are buffer
# terrain DC leaves empty on purpose, so they are not placed.
SOURCE_ZONES = {
    1: {148, 16, 331, 361, 618, 493, 616},
    0: {85, 1497, 130, 267, 36, 45, 47, 28, 139},
}
KEEP_SPELLS = {7823, 43308}            # the only item spells that exist identically in DC's Spell.dbc
MAX_SHALLOW_WATER = 6.0
MAX_RAISED_TERRAIN = 12.0
SAME_TERRAIN = 0.1                     # DC and stock terrain heights this close = DC kept the stock ground
MIN_STRUCTURE_HEIGHT = 0.3             # a CoA height this far above that ground stands on something
WORLDFORGED_MARK = "@Worldforged@"     # Ascension's client-side description tag

ITEM_COLUMNS = (
    "entry class subclass SoundOverrideSubclass name displayid Quality Flags FlagsExtra BuyCount BuyPrice "
    "SellPrice InventoryType AllowableClass AllowableRace ItemLevel RequiredLevel RequiredSkill "
    "RequiredSkillRank requiredspell requiredhonorrank RequiredCityRank RequiredReputationFaction "
    "RequiredReputationRank maxcount stackable ContainerSlots "
    + " ".join(f"stat_type{k} stat_value{k}" for k in range(1, 11))
    + " ScalingStatDistribution ScalingStatValue dmg_min1 dmg_max1 dmg_type1 dmg_min2 dmg_max2 dmg_type2 armor "
    "holy_res fire_res nature_res frost_res shadow_res arcane_res delay ammo_type RangedModRange "
    + " ".join(f"spellid_{k} spelltrigger_{k} spellcharges_{k} spellppmRate_{k} spellcooldown_{k} "
               f"spellcategory_{k} spellcategorycooldown_{k}" for k in range(1, 6))
    + " bonding description PageText LanguageID PageMaterial startquest lockid Material sheath RandomProperty "
    "RandomSuffix block itemset MaxDurability area Map BagFamily TotemCategory socketColor_1 socketContent_1 "
    "socketColor_2 socketContent_2 socketColor_3 socketContent_3 socketBonus GemProperties "
    "RequiredDisenchantSkill ArmorDamageModifier duration ItemLimitCategory HolidayId ScriptName DisenchantID "
    "FoodType minMoneyLoot maxMoneyLoot flagsCustom VerifiedBuild").split()
assert len(ITEM_COLUMNS) == 138, len(ITEM_COLUMNS)
ITEM_STRING_COLUMNS = {"name", "description", "ScriptName"}
GOTPL_COLUMNS = (["entry", "type", "displayId", "name", "IconName", "castBarCaption", "unk1", "size"]
                 + [f"Data{i}" for i in range(24)] + ["AIName", "ScriptName", "VerifiedBuild"])
GO_COLUMNS = ("guid id map zoneId areaId spawnMask phaseMask position_x position_y position_z orientation "
              "rotation0 rotation1 rotation2 rotation3 spawntimesecs animprogress state ScriptName VerifiedBuild "
              "Comment").split()
IDI_COLUMNS = ("ID ModelName_1 ModelName_2 ModelTexture_1 ModelTexture_2 InventoryIcon_1 InventoryIcon_2 "
               "GeosetGroup_1 GeosetGroup_2 GeosetGroup_3 Flags SpellVisualID GroupSoundIndex HelmetGeosetVis_1 "
               "HelmetGeosetVis_2 Texture_1 Texture_2 Texture_3 Texture_4 Texture_5 Texture_6 Texture_7 Texture_8 "
               "ItemVisual ParticleColorID").split()
IDI_STRING_FIELDS = {1, 2, 3, 4, 5, 6} | set(range(15, 23))
GODI_COLUMNS = ("ID ModelName Sound_1 Sound_2 Sound_3 Sound_4 Sound_5 Sound_6 Sound_7 Sound_8 Sound_9 Sound_10 "
                "GeoBoxMinX GeoBoxMinY GeoBoxMinZ GeoBoxMaxX GeoBoxMaxY GeoBoxMaxZ ObjectEffectPackageID").split()
ITEM_DBC_COLUMNS = ["ID", "ClassID", "SubclassID", "Sound_Override_Subclassid", "Material", "DisplayInfoID",
                    "InventoryType", "SheatheType"]


# --------------------------------------------------------------------------------------------- helpers
SQL_STRING_ESCAPES = (("\\", "\\\\"), ("'", "''"), ("\n", "\\n"), ("\r", "\\r"), ("\t", "\\t"), ("\0", "\\0"),
                      ("\x1a", "\\Z"))


def esc(value):
    """SQL literal. MySQL treats backslash as an escape, so model paths need it doubled too, and a
    description's line breaks are written as \\n so every row stays on one line."""
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        text = f"{value:.6f}".rstrip("0").rstrip(".")
        return text if text not in ("", "-0") else "0"
    text = str(value)
    for raw, escaped in SQL_STRING_ESCAPES:
        text = text.replace(raw, escaped)
    return "'" + text + "'"


def mround(x):
    """MySQL ROUND(): half away from zero (Python's round() is banker's rounding)."""
    return int(math.floor(abs(x) + 0.5)) * (1 if x >= 0 else -1)


def signed32(n):
    return n - 2 ** 32 if n > 2 ** 31 - 1 else n


def load_areas():
    areas = {}
    with AREATABLE_CSV.open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            areas[int(row["ID"])] = (int(row["ContinentID"]), int(row["ParentAreaID"]), row["AreaName_Lang_enUS"])
    return areas


def zone_of(areas, area_id):
    for _ in range(10):
        if area_id not in areas or not areas[area_id][1]:
            break
        area_id = areas[area_id][1]
    return area_id


def dbc_path(name):
    for root in (DC_DBC, SERVER_DBC):
        if (root / name).exists():
            return root / name
    raise SystemExit(f"DC {name} not found in {DC_DBC} or {SERVER_DBC}")


# ----------------------------------------------------------------------------------------- 1. replay
def coa_db(work):
    path = work / "coa_wf.sqlite"
    if not path.exists():
        print("replaying CoA worldforged SQL ->", path)
        coa_replay.build(path).close()
    return sqlite3.connect(path)


# ----------------------------------------------------------------------------------------- 2. place
def placements(db, areas):
    """Also returns the spawns whose height needs a witness row this run does not have: none yet, or one
    queried at another position (CoA moved the pickup since) - a stale row would decide the wrong spot."""
    witness = {row[0]: row for row in json.loads(WITNESS.read_text())}
    excluded = set()
    if EXCLUDED.exists():
        with EXCLUDED.open(encoding="utf-8", newline="") as fh:
            excluded = {int(r["coa_guid"]) for r in csv.DictReader(fh)}
    loot = defaultdict(list)
    for entry, item in db.execute("SELECT Entry, Item FROM gameobject_loot_template"):
        loot[entry].append(item)
    rows = db.execute("""SELECT g.guid, g.id, g.map, g.position_x, g.position_y, g.position_z, g.orientation,
                                g.rotation0, g.rotation1, g.rotation2, g.rotation3, g.animprogress, g.state,
                                t.name, t.displayId, t.size, t.castBarCaption, t.Data1, t.Data10, t.Data12
                         FROM gameobject g JOIN gameobject_template t ON t.entry = g.id
                         WHERE t.ScriptName = 'worldforged_pickup'
                           AND COALESCE(g.ScriptName, '') IN ('worldforged_pickup', '')   -- '' = the template's script
                           AND t.type = 3 AND g.map IN (0, 1)
                           AND (g.spawnMask & 1) <> 0 AND g.phaseMask <> 0   -- CoA hides duplicates with spawnMask 0
                         ORDER BY g.guid""").fetchall()
    out, stats, need_witness = [], Counter(), []
    for (guid, entry, mp, x, y, z, o, r0, r1, r2, r3, anim, state, name, disp, size, cast, lootid, d10,
         d12) in rows:
        if guid in excluded:
            stats["excluded (data/excluded_spawns.csv)"] += 1
            continue
        dc_map = TARGET_MAP[mp]
        s_exists, s_area, s_z, _ = probe(mp, x, y)
        if not s_exists or zone_of(areas, s_area) not in SOURCE_ZONES[mp]:
            stats["not a DC-represented source zone"] += 1
            continue
        exists, area, tz, lz = probe(dc_map, x, y)
        zone = zone_of(areas, area) if exists else 0
        if not exists or zone not in ZONE_BAND or areas.get(zone, (0,))[0] != dc_map:
            stats["no DC band zone at this spot"] += 1
            continue
        if lz is not None and lz <= -400:
            lz = None
        items = loot.get(lootid, [])
        if len(items) != 1:
            stats["object holds no single item"] += 1
            continue
        # Where DC kept the stock terrain, a CoA height above it stands on the same building, floor or table
        # (CoA snapped its floating pickups to the terrain and has checked the rest in game since). A hole in the
        # terrain on both maps holds the same model (a castle floor), so CoA's measured height stands there too.
        same_hole = tz is None and s_z is None
        on_structure = ((same_hole or (tz is not None and s_z is not None and abs(tz - s_z) < SAME_TERRAIN
                                       and z > tz + MIN_STRUCTURE_HEIGHT))
                        and (lz is None or lz <= z + 1.0))
        row = witness.get(guid)
        if row and len(row) > 5 and max(abs(a - b) for a, b in zip(row[5:8], (x, y, z))) > WITNESS_TOLERANCE:
            row = None
        if row is None and not on_structure and (tz is None or (lz is not None and lz > max(tz, z) + 1.0)
                                                 or abs(z - tz) > 3):
            need_witness.append((guid, dc_map, x, y, z))
            continue
        n, k = (row[1], row[2]) if row else (0, 0)
        new_z, how = None, None
        if on_structure:
            new_z, how = z, "coa_structure"
        elif tz is None:
            if k:
                new_z, how = z, "witnessed"
        elif lz is not None and lz > max(tz, z) + 1.0:
            if k:
                new_z, how = z, "witnessed"
            elif lz - tz <= MAX_SHALLOW_WATER:
                new_z, how = tz, "seafloor"
        elif abs(z - tz) <= 3:
            new_z, how = tz, "ground"
        elif k:
            new_z, how = z, "witnessed"
        elif z > tz:
            new_z, how = tz, "snap_down"
        elif z - tz >= -MAX_RAISED_TERRAIN:
            new_z, how = tz, "snap_up"
        if how in ("snap_down", "snap_up") and lz is not None and lz - tz > 1.5:
            new_z, how = (tz, "seafloor") if lz - tz <= MAX_SHALLOW_WATER else (None, None)
        if new_z is None:
            stats["no trustworthy height on DC terrain"] += 1
            continue
        stats["placed:" + how] += 1
        out.append(dict(coa_guid=guid, coa_entry=entry, dc_map=dc_map, zone=zone, area=area, x=x, y=y,
                        z=round(new_z, 3), coa_z=z, o=o, rot=(r0, r1, r2, r3), anim=anim, state=state, name=name,
                        coa_display=disp, size=size, cast=cast, los=d10, combat=d12, coa_item=items[0]))
    return out, stats, need_witness


def coa_props(db):
    """The decoration props CoA stands beside some pickups (a nest, crates, a wrecked boat...), restored from
    Ascension since 2026-11-12 in their own guid block. Each belongs to the nearest spawned pickup within
    PROP_RADIUS; the caller keeps those whose pickup DC places itself."""
    lo, hi = COA_PROP_GUIDS
    data_cols = ", ".join(f"t.Data{i}" for i in range(24))
    rows = db.execute(f"""SELECT g.guid, g.id, g.map, g.position_x, g.position_y, g.position_z, g.orientation,
                                 g.rotation0, g.rotation1, g.rotation2, g.rotation3, g.animprogress, g.state,
                                 t.type, t.name, t.displayId, t.size, {data_cols}
                          FROM gameobject g JOIN gameobject_template t ON t.entry = g.id
                          WHERE g.guid BETWEEN {lo} AND {hi} AND g.map IN (0, 1)
                            AND (g.spawnMask & 1) <> 0 AND g.phaseMask <> 0
                          ORDER BY g.guid""").fetchall()
    pickups = db.execute("""SELECT g.guid, g.map, g.position_x, g.position_y FROM gameobject g
                            JOIN gameobject_template t ON t.entry = g.id
                            WHERE t.ScriptName = 'worldforged_pickup' AND COALESCE(g.ScriptName, '') IN ('worldforged_pickup', '')
                              AND (g.spawnMask & 1) <> 0 AND g.phaseMask <> 0""").fetchall()
    out = []
    for row in rows:
        guid, entry, mp, x, y, z, o, r0, r1, r2, r3, anim, state, kind, name, disp, size = row[:17]
        if kind != 5:                  # decoration only: nothing a player could open or use
            continue
        dist, owner = min(((math.hypot(px - x, py - y), pg) for pg, pm, px, py in pickups if pm == mp),
                          default=(None, None))
        if owner is None or dist > PROP_RADIUS:
            continue
        out.append(dict(coa_guid=guid, coa_entry=entry, map=mp, x=x, y=y, z=z, o=o, rot=(r0, r1, r2, r3),
                        anim=anim, state=state, name=name, coa_display=disp, size=size, data=list(row[17:]),
                        owner=owner))
    return out


def witness_query(spots):
    """The read-only query that fills data/witness_results.json: DC creatures and objects within 25 yd of
    each spot, and how many stand within 4 yd of its height. DC's own pickups are left out, or they would
    witness themselves. Each row carries the position it answers for."""
    spots = json.dumps([[g, m, round(x, 1), round(y, 1), round(z, 1)] for g, m, x, y, z in spots],
                       separators=(",", ":"))
    lo, hi = BLOCKS["spawn"]
    return ("SELECT JSON_ARRAYAGG(JSON_ARRAY(t.g,t.n,t.k,t.b,t.zm,t.x,t.y,t.z)) j FROM (SELECT c.g,c.x,c.y,c.z,"
            "COUNT(o.z) n,SUM(ABS(o.z-c.z)<=4) k,ROUND(MIN(ABS(o.z-c.z)),1) b,"
            "ROUND(MAX(IF(ABS(o.z-c.z)<=4,o.z,NULL)),1) zm FROM JSON_TABLE('" + spots + "','$[*]' COLUMNS("
            "g INT PATH '$[0]',m INT PATH '$[1]',x DOUBLE PATH '$[2]',y DOUBLE PATH '$[3]',z DOUBLE PATH "
            "'$[4]')) c LEFT JOIN (SELECT map,position_x x,position_y y,position_z z FROM creature WHERE map IN "
            "(750,751) UNION ALL SELECT map,position_x,position_y,position_z FROM gameobject WHERE map IN "
            f"(750,751) AND guid NOT BETWEEN {lo} AND {hi}) o ON o.map=c.m AND o.x BETWEEN c.x-25 AND c.x+25 "
            "AND o.y BETWEEN c.y-25 AND c.y+25 AND (o.x-c.x)*(o.x-c.x)+(o.y-c.y)*(o.y-c.y)<=625 "
            "GROUP BY c.g,c.x,c.y,c.z) t")


def merge_witness(path):
    """Fold a witness query result (the JSON array, or the row object holding it as "j") into WITNESS."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data["j"]
    if any(len(row) != 8 for row in data):
        raise SystemExit("witness rows must carry their position: [guid, n, k, b, zm, x, y, z]")
    rows = {row[0]: row for row in json.loads(WITNESS.read_text())}
    rows.update({row[0]: row for row in data})
    WITNESS.write_text(json.dumps([rows[g] for g in sorted(rows)], separators=(",", ":")) + "\n")
    print(f"merged {len(data)} witness rows into {WITNESS}")


# ----------------------------------------------------------------------------------------- 3. items
def coa_items(work, wanted):
    cache = work / "coa_items.json"
    if cache.exists():
        data = {int(k): v for k, v in json.loads(cache.read_text(encoding="utf-8")).items()}
        if wanted <= set(data):
            return data
    found, cols = {}, []
    with zipfile.ZipFile(COA_ZIP) as z, z.open("item_template.sql") as fh:
        for raw in io.TextIOWrapper(fh, encoding="utf-8"):
            if raw.startswith("  `"):
                cols.append(raw.split("`")[1])
            elif raw.startswith("INSERT INTO"):
                for vals in parse_values(raw):
                    if int(vals[0][1]) in wanted:
                        found[int(vals[0][1])] = {c: v for c, v in zip(cols, vals)}
    missing = wanted - set(found)
    if missing:
        raise SystemExit(f"{len(missing)} CoA items missing from the world package: {sorted(missing)[:20]}")
    cache.write_text(json.dumps({k: v for k, v in found.items()}), encoding="utf-8")
    return found


ESC_MAP = {"0": "\0", "'": "'", '"': '"', "b": "\b", "n": "\n", "r": "\r", "t": "\t", "Z": "\x1a", "\\": "\\"}


def parse_values(line):
    """mysqldump VALUES tuples -> lists of (is_string, text)."""
    i, n = line.index("VALUES") + 6, len(line)
    while i < n:
        while i < n and line[i] != "(":
            i += 1
        if i >= n:
            return
        i += 1
        vals, cur, quoted, in_str = [], [], False, False
        while i < n:
            c = line[i]
            if in_str:
                if c == "\\":
                    cur.append(ESC_MAP.get(line[i + 1], line[i + 1]))
                    i += 2
                    continue
                if c == "'":
                    if line[i + 1:i + 2] == "'":
                        cur.append("'")
                        i += 2
                        continue
                    in_str = False
                else:
                    cur.append(c)
                i += 1
                continue
            if c == "'":
                in_str, quoted = True, True
            elif c in ",)":
                vals.append((quoted, "".join(cur)))
                cur, quoted = [], False
                if c == ")":
                    i += 1
                    yield vals
                    break
            elif not c.isspace():          # our own SQL writes ", " between values
                cur.append(c)
            i += 1


def num(field, default=0):
    quoted, text = field
    if not quoted and text.upper() == "NULL":
        return None
    if text == "":
        return default
    return float(text) if any(ch in text for ch in ".eE") else int(text)


def text_of(field):
    quoted, text = field
    return None if (not quoted and text.upper() == "NULL") else text


# ---------------------------------------------------------------------------------------- 4. assign
class Allocation:
    def __init__(self, path):
        self.path = path
        self.ids = defaultdict(dict)
        if path.exists():
            with path.open(encoding="utf-8", newline="") as fh:
                for row in csv.DictReader(fh):
                    self.ids[row["kind"]][row["key"]] = int(row["id"])

    def assign(self, kind, keys):
        lo, hi = BLOCKS[kind]
        taken = self.ids[kind]
        nxt = max(taken.values(), default=lo - 1) + 1
        for key in keys:
            if key in taken:
                continue
            if nxt > hi:
                raise SystemExit(f"id block for {kind} exhausted ({lo}-{hi})")
            taken[key] = nxt
            nxt += 1
        return taken

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("w", encoding="utf-8", newline="") as fh:
            w = csv.writer(fh, lineterminator="\n")
            w.writerow(["kind", "key", "id"])
            for kind in sorted(self.ids):
                for key, value in sorted(self.ids[kind].items(), key=lambda kv: kv[1]):
                    w.writerow([kind, key, value])


# ---------------------------------------------------------------------------------- display mapping
def existing_ids(name):
    try:
        return set(DBC(dbc_path(name)).ids())
    except SystemExit:
        return None


def idi_row(dbc, rid):
    row = []
    for f in range(25):
        row.append(dbc.s(rid, f) if f in IDI_STRING_FIELDS else dbc.i(rid, f))
    return row


def idi_key(row):
    return tuple((v.lower() if isinstance(v, str) else v) for v in row[1:])


def build_display_maps(work, item_displays, go_displays, pinned_idi, pinned_godi):
    """CoA display id -> DC display id. Ascension renumbered displays, so rows are matched on their full
    content, never on the id; a display DC lacks becomes a new row (filled in by the caller). A row an
    earlier run added (pinned in the allocation) keeps its id, even where another row has the same model."""
    asc_idi = DBC(work / "asc_dbc" / "ItemDisplayInfo.dbc")
    dc_idi = DBC(dbc_path("ItemDisplayInfo.dbc"))
    asc_go = DBC(work / "asc_dbc" / "GameObjectDisplayInfo.dbc")
    dc_go = DBC(dbc_path("GameObjectDisplayInfo.dbc"))
    valid = {
        11: existing_ids("SpellVisual.dbc"), 12: existing_ids("ItemGroupSounds.dbc"),
        13: existing_ids("HelmetGeosetVisData.dbc"), 14: existing_ids("HelmetGeosetVisData.dbc"),
        23: existing_ids("ItemVisuals.dbc"), 24: existing_ids("ParticleColor.dbc"),
    }
    dc_by_key = {}
    for rid in sorted(dc_idi.ids()):
        dc_by_key.setdefault(idi_key(idi_row(dc_idi, rid)), rid)
    # *_ours: the rows of every display in our id block, new or added by an earlier run - the server takes
    # them from the SQL overlays whatever the client DBC already holds
    idi_map, idi_new, idi_ours, idi_zeroed = {}, {}, {}, Counter()
    for did in sorted(item_displays):
        if not asc_idi.has(did):
            raise SystemExit(f"CoA item display {did} is not in Ascension's ItemDisplayInfo.dbc")
        row = idi_row(asc_idi, did)
        for f, ids in valid.items():
            if row[f] and ids is not None and row[f] not in ids:
                idi_zeroed[IDI_COLUMNS[f]] += 1
                row[f] = 0
        hit = dc_by_key.get(idi_key(row))
        pin = pinned_idi.get(str(did))
        if pin is not None and dc_idi.has(pin) and idi_key(idi_row(dc_idi, pin)) == idi_key(row):
            hit = pin
            idi_ours[did] = [pin] + row[1:]
        elif dc_idi.has(did) and idi_key(idi_row(dc_idi, did)) == idi_key(row):
            hit = did
        idi_map[did] = hit
        if hit is None:
            idi_new[did] = idi_ours[did] = row
    go_by_model = {}
    for rid in dc_go.ids():
        key = dc_go.s(rid, 1).lower().rsplit(".", 1)[0]
        if key not in go_by_model or rid < go_by_model[key]:
            go_by_model[key] = rid
    go_map, go_new, go_ours = {}, {}, {}
    for did in sorted(go_displays):
        if not asc_go.has(did):
            raise SystemExit(f"CoA GO display {did} is not in Ascension's GameObjectDisplayInfo.dbc")
        model = asc_go.s(did, 1)
        key = model.lower().rsplit(".", 1)[0]
        row = [did, model] + [0] * 10 + [asc_go.f(did, f) for f in range(12, 18)] + [0]
        pin = pinned_godi.get(str(did))
        if pin is not None and dc_go.has(pin) and dc_go.s(pin, 1).lower().rsplit(".", 1)[0] == key:
            go_map[did] = pin
            go_ours[did] = [pin] + row[1:]
        elif dc_go.has(did) and dc_go.s(did, 1).lower().rsplit(".", 1)[0] == key:
            go_map[did] = did
        elif key in go_by_model:
            go_map[did] = go_by_model[key]
        else:
            go_map[did] = None
            go_new[did] = go_ours[did] = row
    return idi_map, idi_new, idi_ours, idi_zeroed, go_map, go_new, go_ours


# ------------------------------------------------------------------------------------------ 5. items
def slot_weight(inv):
    if inv in (1, 5, 7, 20):
        return 1.15
    if inv in (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26):
        return 0.75
    return 1.00


def scaled_item(src, zone, clone_id, display_id):
    """309_/312_'s rescale: the target budget from ilvl/slot/quality, spread over the source's own
    positive stats in its own proportions, any single stat capped at 40% of the budget."""
    band_lo, base = ZONE_BAND[zone]
    quality = num(src["Quality"])
    inv = num(src["InventoryType"])
    src_ilvl = num(src["ItemLevel"])
    spread = mround((min(max(src_ilvl, 5), 70) - 5) * 20 / 65)
    ilvl = max(240, min(470, base + spread - 10 + {3: 8, 4: 16}.get(quality, 0)))
    budget = mround(0.00207 * ilvl ** 2.13 * slot_weight(inv) * {3: 1.00, 4: 1.15}.get(quality, 0.85))
    cap = max(1, mround(budget * 0.40))
    stats = [(num(src[f"stat_type{k}"]), num(src[f"stat_value{k}"])) for k in range(1, 11)]
    positive = [(t, v) for t, v in stats if t and v and v > 0]
    total = sum(v for _, v in positive)
    scaled = [(t, min(cap, mround(v * budget / total))) for t, v in positive] if total else []

    row = {}
    for col in ITEM_COLUMNS:
        field = src.get(col)
        if field is None:
            raise SystemExit(f"CoA item_template has no column {col}")
        row[col] = text_of(field) if col in ITEM_STRING_COLUMNS else num(field)
    row.update(entry=clone_id, displayid=display_id, ItemLevel=ilvl, RequiredLevel=band_lo,
               Flags=(row["Flags"] or 0) & ~0x8, ScalingStatDistribution=0, ScalingStatValue=0,
               dmg_min2=0, dmg_max2=0, dmg_type2=0, RandomProperty=0, RandomSuffix=0,
               BuyPrice=min(2 ** 63 - 1, mround((row["BuyPrice"] or 0) * 12)),
               SellPrice=min(4294967295, mround((row["SellPrice"] or 0) * 12)),
               RequiredReputationFaction=0, RequiredReputationRank=0, startquest=0, PageText=0, lockid=0,
               itemset=0, area=0, Map=0, socketColor_1=0, socketContent_1=0, socketColor_2=0,
               socketContent_2=0, socketColor_3=0, socketContent_3=0, socketBonus=0, GemProperties=0,
               RequiredDisenchantSkill=-1, DisenchantID=0, ItemLimitCategory=0, HolidayId=0, ScriptName="",
               minMoneyLoot=0, maxMoneyLoot=0, flagsCustom=0, VerifiedBuild=0)
    for k in range(1, 11):
        t, v = scaled[k - 1] if k <= len(scaled) else (0, 0)
        row[f"stat_type{k}"], row[f"stat_value{k}"] = t, v
    kept = [k for k in range(1, 6) if row[f"spellid_{k}"] in KEEP_SPELLS]
    spells = [{s: row[f"{s}_{k}"] for s in ("spellid", "spelltrigger", "spellcharges", "spellppmRate",
                                              "spellcooldown", "spellcategory", "spellcategorycooldown")}
              for k in kept]
    for k in range(1, 6):
        src_spell = spells[k - 1] if k <= len(spells) else None
        for s, empty in (("spellid", 0), ("spelltrigger", 0), ("spellcharges", 0), ("spellppmRate", 0),
                         ("spellcooldown", -1), ("spellcategory", 0), ("spellcategorycooldown", -1)):
            row[f"{s}_{k}"] = src_spell[s] if src_spell else empty
    desc = row["description"] or ""
    if desc.startswith(WORLDFORGED_MARK):
        flavour = desc[len(WORLDFORGED_MARK):].strip()
        desc = f"Worldforged - {flavour}" if flavour else "Worldforged"
    row["description"] = desc or "Worldforged"
    return row, budget, sum(v for _, v in scaled)


def apply_armor_damage(work, items):
    """Armor and weapon damage come from the Cata curve DBCs via gen_zone_gear_armor_dmg.py, exactly as
    310_ did for map 750's clones. Only its armor/dmg numbers are taken: the tool writes dmg_type1 = 0,
    which would turn an elemental wand physical. Thrown weapons go through the ranged curve (the tool skips
    subclass 16); fishing poles and misc weapons keep their own damage."""
    csv_path, sql_path = work / "armor_dmg_items.csv", work / "armor_dmg.sql"
    with csv_path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["entry", "ItemLevel", "Quality", "class", "subclass", "InventoryType", "delay", "caster"])
        for r in items:
            sub = 2 if r["class"] == 2 and r["subclass"] == 16 else r["subclass"]
            caster = any(r[f"stat_type{k}"] in (5, 45) for k in range(1, 11))
            w.writerow([r["entry"], r["ItemLevel"], r["Quality"], r["class"], sub, r["InventoryType"],
                        r["delay"], int(caster)])
    res = subprocess.run([sys.executable, str(ARMOR_TOOL), "--dbc-dir", str(CURVES), "--items-csv",
                          str(csv_path), "--out", str(sql_path)], capture_output=True, text=True)
    if res.returncode:
        raise SystemExit("gen_zone_gear_armor_dmg.py failed:\n" + res.stdout + res.stderr)
    by_entry = {r["entry"]: r for r in items}
    filled = Counter()
    for line in sql_path.read_text().splitlines():
        m = re.match(r"UPDATE `item_template` SET (.*) WHERE `entry`=(\d+);", line)
        if not m:
            continue
        r = by_entry[int(m.group(2))]
        for col, val in re.findall(r"`(\w+)`=([-\d.]+)", m.group(1)):
            if col in ("armor", "dmg_min1", "dmg_max1"):
                r[col] = int(val)
                filled[col] += 1
    return res.stdout.strip(), filled


# ------------------------------------------------------------------------------------------ 6. emit
def values_block(table, columns, rows, verb="INSERT"):
    """One statement per table, so codestyle-sql sees its DELETE on the line right before it."""
    head = f"{verb} INTO `{table}` (" + ", ".join(f"`{c}`" for c in columns) + ") VALUES"
    return head + "\n" + ",\n".join("(" + ", ".join(esc(v) for v in r) + ")" for r in rows) + ";"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", type=Path, required=True)
    ap.add_argument("--write", action="store_true", help="write SQL, DBC rows, asset list and allocation")
    ap.add_argument("--delta", metavar="NAME",
                    help="with --write: emit only the changes against the shipped SQL, as a new pending file "
                         "rev_<ns>_worldforged_<NAME>.sql")
    ap.add_argument("--note", type=Path, help="text file whose lines open the --delta file's header")
    ap.add_argument("--merge-witness", type=Path, metavar="JSON",
                    help="fold a witness query result into data/witness_results.json and stop")
    a = ap.parse_args()
    if a.merge_witness:
        merge_witness(a.merge_witness)
        return
    a.work.mkdir(parents=True, exist_ok=True)
    if not (a.work / "asc_dbc" / "ItemDisplayInfo.dbc").exists():
        raise SystemExit(f"extract Ascension's DBCs into {a.work / 'asc_dbc'} first (see README)")

    areas = load_areas()
    db = coa_db(a.work)
    placed, stats, need_witness = placements(db, areas)
    if need_witness:
        sql_path = a.work / "witness_query.sql"
        sql_path.write_text(witness_query(need_witness) + "\n", encoding="utf-8")
        raise SystemExit(f"{len(need_witness)} spawns need a witness row for their current position. Run "
                         f"{sql_path} read-only against the world DB, save the result's JSON array and pass it "
                         f"to --merge-witness, then re-run.")
    retained = json.loads(RETAINED.read_text(encoding="utf-8")) if RETAINED.exists() else []
    live = {p["coa_guid"] for p in placed}
    kept = [{k: v for k, v in r.items() if k != "why"} for r in retained if r["coa_guid"] not in live]
    placed += kept
    stats["retained (CoA dropped it)"] = len(kept)
    print("placement:", dict(sorted(stats.items())))

    items = coa_items(a.work, {p["coa_item"] for p in placed})
    gear, dropped = [], Counter()
    for p in placed:
        it = items[p["coa_item"]]
        klass, inv, quality = num(it["class"]), num(it["InventoryType"]), num(it["Quality"])
        if klass not in (2, 4) or not inv:
            dropped[f"not gear (class {klass})"] += 1
            continue
        if quality < 2:
            dropped["grey/white quality"] += 1
            continue
        positive = sum(1 for k in range(1, 11)
                       if num(it[f"stat_type{k}"]) and (num(it[f"stat_value{k}"]) or 0) > 0)
        if not positive and inv in (2, 11, 12, 16, 23):
            dropped["jewelry/cloak/off-hand with no stats (its power was an Ascension-only spell)"] += 1
            continue
        gear.append(p)
    print("dropped spawns:", dict(dropped), "| placing", len(gear))

    alloc = Allocation(ALLOCATION)
    shipped_ids = {kind: set(ids.values()) for kind, ids in alloc.ids.items()}
    order = sorted(gear, key=lambda p: (p["dc_map"], p["zone"], p["coa_guid"]))
    spawn_ids = alloc.assign("spawn", [str(p["coa_guid"]) for p in order])
    tpl_ids = alloc.assign("gotpl", sorted({f"{p['coa_entry']}:{p['zone']}" for p in gear},
                                           key=lambda s: (int(s.split(":")[1]), int(s.split(":")[0]))))
    item_ids = alloc.assign("item", sorted({f"{p['coa_item']}:{p['zone']}" for p in gear},
                                           key=lambda s: (int(s.split(":")[1]), int(s.split(":")[0]))))
    overrides = {}
    if OVERRIDES.exists():
        with OVERRIDES.open(encoding="utf-8", newline="") as fh:
            overrides = {int(r["spawn_guid"]): r for r in csv.DictReader(fh)}
    # A prop stands only beside a pickup DC places from CoA's current data at CoA's own spot: not beside a
    # retained copy (frozen, coa_z unknown) nor one whose position is pinned.
    live = {p["coa_guid"]: p for p in gear if "coa_z" in p and spawn_ids[str(p["coa_guid"])] not in overrides}
    props = [pr for pr in coa_props(db) if pr["owner"] in live]
    print(f"props: {len(props)} beside {len({pr['owner'] for pr in props})} DC pickups")

    idi_map, idi_new, idi_ours, idi_zeroed, go_map, go_new, go_ours = build_display_maps(
        a.work, {num(items[p["coa_item"]]["displayid"]) for p in gear},
        {p["coa_display"] for p in gear} | {pr["coa_display"] for pr in props}, alloc.ids["idi"], alloc.ids["godi"])
    idi_ids = alloc.assign("idi", [str(d) for d in sorted(idi_new)])
    godi_ids = alloc.assign("godi", [str(d) for d in sorted(go_new)])
    for d in idi_new:
        idi_map[d] = idi_ids[str(d)]
        idi_new[d][0] = idi_ids[str(d)]
    for d in go_new:
        go_map[d] = godi_ids[str(d)]
        go_new[d][0] = godi_ids[str(d)]
    print(f"item displays: {len(idi_map)} used, {len(idi_ours)} ours, {len(idi_new)} of them new; fields zeroed "
          f"(no DC row): {dict(idi_zeroed)}")
    print(f"GO displays: {len(go_map)} used, {len(go_ours)} ours, {len(go_new)} of them new")

    item_rows, budgets = {}, []
    for key, clone in sorted(item_ids.items(), key=lambda kv: kv[1]):
        coa_item, zone = (int(x) for x in key.split(":"))
        if not any(p["coa_item"] == coa_item and p["zone"] == zone for p in gear):
            continue
        src = items[coa_item]
        row, budget, spent = scaled_item(src, zone, clone, idi_map[num(src["displayid"])])
        item_rows[clone] = row
        budgets.append((budget, spent))
    tool_out, filled = apply_armor_damage(a.work, list(item_rows.values()))
    print("armor/damage:", tool_out, dict(filled))

    tpl_rows, loot_rows = [], []
    by_tpl = {}
    for p in gear:
        tpl = tpl_ids[f"{p['coa_entry']}:{p['zone']}"]
        by_tpl.setdefault(tpl, p)
    for tpl, p in sorted(by_tpl.items()):
        item = item_rows[item_ids[f"{p['coa_item']}:{p['zone']}"]]
        data = [LOCK_OPEN, tpl, 0, 0, 0, 0, 0, 0, 0, 0, p["los"], 0, p["combat"]] + [0] * 11
        tpl_rows.append([tpl, 3, go_map[p["coa_display"]], p["name"], "", p["cast"] or "", "", p["size"]]
                        + data + ["", SCRIPT_NAME, 0])
        loot_rows.append([tpl, item["entry"], 0, 100, 0, 1, 0, 1, 1, f"Worldforged: {item['name']}"])
    prop_tpl_ids = alloc.assign("prop_tpl", sorted({str(pr["coa_entry"]) for pr in props}, key=int))
    prop_spawn_ids = alloc.assign("prop_spawn", sorted({str(pr["coa_guid"]) for pr in props}, key=int))
    for entry, pr in sorted({pr["coa_entry"]: pr for pr in props}.items()):
        tpl_rows.append([prop_tpl_ids[str(entry)], 5, go_map[pr["coa_display"]], pr["name"], "", "", "", pr["size"]]
                        + pr["data"] + ["", "", 0])
    go_rows = []
    for p in order:
        tpl = tpl_ids[f"{p['coa_entry']}:{p['zone']}"]
        guid = spawn_ids[str(p["coa_guid"])]
        zone_name = re.sub(r"\s*\(.*\)$", "", areas[p["zone"]][2])
        x, y, z, o, area, rot = round(p["x"], 3), round(p["y"], 3), p["z"], round(p["o"], 5), p["area"], p["rot"]
        if guid in overrides:
            ov = overrides[guid]
            x, y, z, o, area = float(ov["x"]), float(ov["y"]), float(ov["z"]), float(ov["o"]), int(ov["area"])
            rot = (0, 0, math.sin(o / 2), math.cos(o / 2))
        go_rows.append([guid, tpl, p["dc_map"], p["zone"], area, 1, 1, x, y, z, o]
                       + [round(r, 6) for r in rot]
                       + [0, p["anim"] or 0, p["state"] if p["state"] is not None else 1, "", 0,
                          f"Worldforged: {p['name']} ({zone_name}, CoA guid {p['coa_guid']})"])
    if overrides:
        print(f"position overrides applied: {sum(1 for r in go_rows if r[0] in overrides)} of {len(overrides)}")
    # A prop moves with its pickup (the height DC gave the pickup minus CoA's keeps the scene together), except
    # where DC changed the ground under a prop standing on it: there it keeps its height above DC's ground.
    prop_rows = []
    for pr in sorted(props, key=lambda pr: pr["coa_guid"]):
        owner = live[pr["owner"]]
        owner_guid = spawn_ids[str(pr["owner"])]
        _, _, tz, _ = probe(owner["dc_map"], pr["x"], pr["y"])
        _, _, s_z, _ = probe(pr["map"], pr["x"], pr["y"])
        if tz is not None and s_z is not None and abs(tz - s_z) >= SAME_TERRAIN and abs(pr["z"] - s_z) <= 3:
            z = round(tz + pr["z"] - s_z, 3)
        else:
            z = round(pr["z"] + owner["z"] - owner["coa_z"], 3)
        prop_rows.append([prop_spawn_ids[str(pr["coa_guid"])], prop_tpl_ids[str(pr["coa_entry"])], owner["dc_map"],
                          owner["zone"], owner["area"], 1, 1, round(pr["x"], 3), round(pr["y"], 3), z, round(pr["o"], 5)]
                         + [round(r, 6) for r in pr["rot"]]
                         + [0, pr["anim"] or 0, pr["state"] if pr["state"] is not None else 1, "", 0,
                            f"Worldforged prop: {pr['name']} (beside {owner['name']} {owner_guid}, "
                            f"CoA guid {pr['coa_guid']})"])

    report(gear, item_rows, item_ids, budgets, areas)
    if not a.write:
        print("\ndry run - pass --write to emit files")
        return

    if a.delta:
        note = a.note.read_text(encoding="utf-8").splitlines() if a.note else []
        sql_path = write_delta(a.work, a.delta, note, shipped_ids, areas, item_rows, idi_ours, go_ours, tpl_rows,
                               loot_rows, go_rows, prop_rows)
    else:
        sql_path = write_sql(item_rows, idi_ours, go_ours, tpl_rows, loot_rows, go_rows, prop_rows)
    alloc.save()
    # every row of ours: apply_client_dbc.py skips what the DBCs hold, stage_assets.py what the client has
    write_client_rows(a.work, item_rows, idi_ours, go_ours)
    print("wrote", sql_path)


def report(gear, item_rows, item_ids, budgets, areas):
    spawns = Counter(p["zone"] for p in gear)
    ilvls = defaultdict(list)
    for key, clone in item_ids.items():
        if clone in item_rows:
            ilvls[int(key.split(":")[1])].append(item_rows[clone]["ItemLevel"])
    print("\n  zone                                  spawns  items  ilvl")
    for zone in sorted(spawns, key=lambda z: (ZONE_BAND[z][0], z)):
        lv = sorted(ilvls[zone])
        print(f"  {areas[zone][2]:<36} {spawns[zone]:>6} {len(lv):>6}  {lv[0]}-{lv[-1]}")
    print(f"  items: {len(item_rows)} clones, stat budget used {sum(s for _, s in budgets)} of "
          f"{sum(b for b, _ in budgets)} (the 40% single-stat cap keeps the rest)")


def write_sql(item_rows, idi_new, go_new, tpl_rows, loot_rows, go_rows, prop_rows):
    lo_i, hi_i = BLOCKS["item"]
    lo_t, hi_t = BLOCKS["gotpl"]
    lo_s, hi_s = BLOCKS["spawn"]
    lo_d, hi_d = BLOCKS["idi"]
    lo_g, hi_g = BLOCKS["godi"]
    items = [item_rows[k] for k in sorted(item_rows)]
    parts = [HEADER.format(spawns=len(go_rows), templates=len(tpl_rows), items=len(items), idi=len(idi_new),
                           godi=len(go_new), lo_s=lo_s, hi_s=hi_s, script=SCRIPT_NAME).strip(), ""]
    parts += [values_block("item_template", ITEM_COLUMNS, [[r[c] for c in ITEM_COLUMNS] for r in items], "REPLACE"),
              "",
              f"DELETE FROM `item_dbc` WHERE `ID` BETWEEN {lo_i} AND {hi_i};",
              values_block("item_dbc", ITEM_DBC_COLUMNS, [item_dbc_row(r) for r in items]), ""]
    if idi_new:
        parts += [f"DELETE FROM `itemdisplayinfo_dbc` WHERE `ID` BETWEEN {lo_d} AND {hi_d};",
                  values_block("itemdisplayinfo_dbc", IDI_COLUMNS,
                               [[signed32(v) if isinstance(v, int) else v for v in r] for r in
                                sorted(idi_new.values())]), ""]
    if go_new:
        parts += [f"DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` BETWEEN {lo_g} AND {hi_g};",
                  values_block("gameobjectdisplayinfo_dbc", GODI_COLUMNS, sorted(go_new.values())), ""]
    parts += [values_block("gameobject_template", GOTPL_COLUMNS, tpl_rows, "REPLACE"), "",
              f"DELETE FROM `gameobject_loot_template` WHERE `Entry` BETWEEN {lo_t} AND {hi_t};",
              values_block("gameobject_loot_template",
                           ["Entry", "Item", "Reference", "Chance", "QuestRequired", "LootMode", "GroupId",
                            "MinCount", "MaxCount", "Comment"], loot_rows), "",
              f"DELETE FROM `gameobject` WHERE `guid` BETWEEN {lo_s} AND {hi_s} AND `id` BETWEEN {lo_t} AND {hi_t};",
              values_block("gameobject", GO_COLUMNS, go_rows), ""]
    if prop_rows:
        (lo_ps, hi_ps), (lo_pt, hi_pt) = BLOCKS["prop_spawn"], BLOCKS["prop_tpl"]
        parts += [f"DELETE FROM `gameobject` WHERE `guid` BETWEEN {lo_ps} AND {hi_ps} AND `id` BETWEEN {lo_pt} AND {hi_pt};",
                  values_block("gameobject", GO_COLUMNS, prop_rows), ""]
    PENDING_WORLD.mkdir(parents=True, exist_ok=True)
    existing = sorted(PENDING_WORLD.glob("rev_*_worldforged_750_751.sql"))
    path = existing[0] if existing else PENDING_WORLD / f"rev_{time.time_ns()}_worldforged_750_751.sql"
    path.write_text("\n".join(parts).rstrip() + "\n", encoding="utf-8", newline="\n")
    return path


def shipped_state(work, name=None):
    """What the applied SQL left in the world DB: the archived files, then any worldforged file still pending
    (except delta `name`'s own, when given), replayed in filename order like the updater. Returns the
    gameobject tables (SQLite) and the item_template rows by entry."""
    own = f"_worldforged_{name}.sql" if name else None
    files = sorted([f for f in list(SHIPPED_SQL.glob("*.sql")) + list(PENDING_WORLD.glob("rev_*_worldforged_*.sql"))
                    if not (own and f.name.endswith(own))], key=lambda f: f.name)
    rp = coa_replay.Replayer(work / ("dc_shipped.sqlite" if name else "dc_final.sqlite"))
    items, overlays = {}, defaultdict(set)
    for f in files:
        text = f.read_text(encoding="utf-8")
        rp.run(text, f.name)
        for stmt in coa_replay.split_statements(text):
            if re.match(r"(REPLACE|INSERT)\s+INTO\s+`item_template`", stmt):
                cols = re.findall(r"`(\w+)`", stmt[:stmt.index("VALUES")])[1:]
                for vals in parse_values(stmt):
                    row = {c: (text_of(v) if c in ITEM_STRING_COLUMNS else num(v)) for c, v in zip(cols, vals)}
                    items[row["entry"]] = row
            m = re.match(r"(?:REPLACE|INSERT)\s+INTO\s+`(itemdisplayinfo_dbc|gameobjectdisplayinfo_dbc)`", stmt)
            if m:
                overlays[m.group(1)] |= {num(vals[0]) for vals in parse_values(stmt)}
    if rp.failures:
        raise SystemExit(f"replaying the shipped worldforged SQL failed: {rp.failures[:3]}")
    print(f"shipped state: {len(files)} files, "
          f"{rp.db.execute('SELECT COUNT(*) FROM gameobject').fetchone()[0]} spawns, {len(items)} items, "
          f"{len(overlays['itemdisplayinfo_dbc'])} + {len(overlays['gameobjectdisplayinfo_dbc'])} display overlays")
    return rp.db, items, overlays


def differs(a, b, tolerance=1e-3):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) > tolerance
    return (a if a is not None else "") != (b if b is not None else "")


SPAWN_CMP = [i for i, c in enumerate(GO_COLUMNS) if c not in ("guid", "VerifiedBuild", "Comment")]


def spawn_diff(db, block, rows):
    """Shipped spawns of one guid block against this run's rows: (shipped by guid, removed, moved, added)."""
    lo, hi = BLOCKS[block]
    shipped = {r[0]: r for r in db.execute(f"SELECT * FROM gameobject WHERE guid BETWEEN {lo} AND {hi}")}
    ours = {r[0]: r for r in rows}
    removed = sorted(set(shipped) - set(ours))
    # CoA re-rounds coordinates now and then (1421.494141 -> 1421.49): not a move
    moved = [r for g, r in sorted(ours.items()) if g in shipped
             and any(differs(r[i], shipped[g][i], 0.01) for i in SPAWN_CMP)]
    added = [r for g, r in sorted(ours.items()) if g not in shipped]
    return shipped, removed, moved, added


def spawn_statements(block, tpl_block, removed, moved, added):
    """DELETE + INSERT for one spawn block, every DELETE also scoped to that block's templates."""
    lo_t, hi_t = BLOCKS[tpl_block]
    parts = []
    if removed:
        parts += [f"DELETE FROM `gameobject` WHERE `guid` IN ({', '.join(map(str, removed))}) "
                  f"AND `id` BETWEEN {lo_t} AND {hi_t};", ""]
    if moved or added:
        rows = moved + added
        parts += [f"DELETE FROM `gameobject` WHERE `guid` IN ({', '.join(str(r[0]) for r in rows)}) "
                  f"AND `id` BETWEEN {lo_t} AND {hi_t};",
                  values_block("gameobject", GO_COLUMNS, rows), ""]
    return parts


def write_delta(work, name, note, shipped_ids, areas, item_rows, idi_ours, go_ours, tpl_rows, loot_rows, go_rows,
                prop_rows):
    """The changes against the shipped state, as one new pending file: spawns and props removed, moved or added
    (deleted and re-inserted whole, so a re-run is harmless), templates and loot added or changed, new items,
    and the display overlays the shipped SQL lacks. Item rows are never deleted: characters may hold them."""
    db, shipped_items, overlays = shipped_state(work, name)
    idi_new = {r[0]: r for r in idi_ours.values() if r[0] not in overlays["itemdisplayinfo_dbc"]}
    go_new = {r[0]: r for r in go_ours.values() if r[0] not in overlays["gameobjectdisplayinfo_dbc"]}
    shipped_go, removed, moved, added = spawn_diff(db, "spawn", go_rows)
    shipped_props, props_removed, props_moved, props_added = spawn_diff(db, "prop_spawn", prop_rows)

    shipped_tpl = {r[0]: r for r in db.execute("SELECT * FROM gameobject_template")}
    tpl_changed = [r for r in tpl_rows if r[0] not in shipped_tpl
                   or any(differs(a, b) for a, b in zip(r[:-1], shipped_tpl[r[0]][:-1]))]
    shipped_loot = defaultdict(list)
    for r in db.execute("SELECT * FROM gameobject_loot_template ORDER BY Entry, Item"):
        shipped_loot[r[0]].append(r)
    loot_changed = [r for r in loot_rows if [tuple(r[:9])] != [tuple(x[:9]) for x in shipped_loot.get(r[0], [])]]

    new_items = [item_rows[k] for k in sorted(item_rows) if k not in shipped_items]
    drifted = [item_rows[k] for k in sorted(item_rows) if k in shipped_items
               and any(differs(item_rows[k][c], shipped_items[k].get(c)) for c in ITEM_COLUMNS)]
    unrecorded = sorted(set(item_rows) - set(shipped_items) - shipped_ids.get("item", set()))
    print(f"delta: {len(removed)} spawns removed, {len(moved)} moved, {len(added)} added; props {len(props_removed)} "
          f"removed, {len(props_moved)} moved, {len(props_added)} added; "
          f"{len(tpl_changed)} templates and {len(loot_changed)} loot rows new or changed; {len(new_items)} new "
          f"items ({len(unrecorded)} newly allocated), {len(drifted)} shipped items regenerate differently; "
          f"{len(idi_new)} + {len(go_new)} new display rows")

    def zone_of_row(r):
        return re.sub(r"\s*\(.*\)$", "", areas.get(r[3], (0, 0, "?"))[2])

    lines = [f"-- {ln}".rstrip() for ln in note]
    if note:
        lines.append("--")
    lines += [f"-- GENERATED by Custom/Documentation/scripts/worldforged/gen_worldforged_750_751.py --delta {name}:",
              "-- the changes against the applied worldforged SQL. Spawn guids never change (they are the claim key).",
              f"--   {len(removed)} spawns removed, {len(moved)} moved, {len(added)} added; props "
              f"{len(props_removed)} removed, {len(props_moved)} moved, {len(props_added)} added;",
              f"--   {len(tpl_changed)} gameobject templates and {len(new_items)} item clones new or changed;",
              f"--   {len(idi_new)} new ItemDisplayInfo + {len(go_new)} new GameObjectDisplayInfo rows (overlays below; the "
              "client needs the DBC rows and assets - README).", "--"]
    if removed:
        lines.append(f"-- Removed ({len(removed)}):")
        lines += [f"--   {g}  {shipped_go[g][20]}" for g in removed]
        lines.append("--")
    if moved:
        lines.append(f"-- Moved ({len(moved)}), shipped -> now:")
        for r in moved:
            s = shipped_go[r[0]]
            where = (zone_of_row(s) if s[3] == r[3] else f"{zone_of_row(s)} -> {zone_of_row(r)}")
            name_ = re.sub(r"^Worldforged: | \(.*$", "", r[20])
            lines.append(f"--   {r[0]}  {name_} ({where})  {s[7]:.1f}, {s[8]:.1f}, {s[9]:.3f} -> "
                         f"{r[7]:.1f}, {r[8]:.1f}, {r[9]:.3f}")
        lines.append("--")
    if added:
        lines.append(f"-- Added ({len(added)}):")
        lines += [f"--   {r[0]}  tpl {r[1]}  {r[20][len('Worldforged: '):]}  {r[7]:.1f}, {r[8]:.1f}, {r[9]:.3f}"
                  for r in added]
        lines.append("--")
    for label, rows in (("Props removed", [shipped_props[g] for g in props_removed]), ("Props moved", props_moved),
                        ("Props added", props_added)):
        if rows:
            lines.append(f"-- {label} ({len(rows)}):")
            lines += [f"--   {r[0]}  tpl {r[1]}  {r[20][len('Worldforged prop: '):]}  {r[7]:.1f}, {r[8]:.1f}, {r[9]:.3f}"
                      for r in rows]
            lines.append("--")
    for r in tpl_changed:
        if r[0] in shipped_tpl:
            fields = [f"{c} {shipped_tpl[r[0]][i]} -> {r[i]}" for i, c in enumerate(GOTPL_COLUMNS[:-1])
                      if differs(r[i], shipped_tpl[r[0]][i])]
            lines.append(f"-- Template {r[0]} {r[3]}: " + ", ".join(fields))
    parts = ["\n".join(lines).rstrip(), ""]

    lo_i, hi_i = BLOCKS["item"]
    items = new_items + drifted
    if items:
        ids = ", ".join(str(r["entry"]) for r in items)
        parts += [values_block("item_template", ITEM_COLUMNS, [[r[c] for c in ITEM_COLUMNS] for r in items], "REPLACE"),
                  "", f"DELETE FROM `item_dbc` WHERE `ID` IN ({ids});",
                  values_block("item_dbc", ITEM_DBC_COLUMNS, [item_dbc_row(r) for r in items]), ""]
    if idi_new:
        rows = sorted(idi_new.values())
        parts += [f"DELETE FROM `itemdisplayinfo_dbc` WHERE `ID` IN ({', '.join(str(r[0]) for r in rows)});",
                  values_block("itemdisplayinfo_dbc", IDI_COLUMNS,
                               [[signed32(v) if isinstance(v, int) else v for v in r] for r in rows]), ""]
    if go_new:
        rows = sorted(go_new.values())
        parts += [f"DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` IN ({', '.join(str(r[0]) for r in rows)});",
                  values_block("gameobjectdisplayinfo_dbc", GODI_COLUMNS, rows), ""]
    if tpl_changed:
        parts += [values_block("gameobject_template", GOTPL_COLUMNS, tpl_changed, "REPLACE"), ""]
    if loot_changed:
        parts += [f"DELETE FROM `gameobject_loot_template` WHERE `Entry` IN "
                  f"({', '.join(str(r[0]) for r in loot_changed)});",
                  values_block("gameobject_loot_template",
                               ["Entry", "Item", "Reference", "Chance", "QuestRequired", "LootMode", "GroupId",
                                "MinCount", "MaxCount", "Comment"], loot_changed), ""]
    parts += spawn_statements("spawn", "gotpl", removed, moved, added)
    parts += spawn_statements("prop_spawn", "prop_tpl", props_removed, props_moved, props_added)
    PENDING_WORLD.mkdir(parents=True, exist_ok=True)
    existing = sorted(PENDING_WORLD.glob(f"rev_*_worldforged_{name}.sql"))
    path = existing[0] if existing else PENDING_WORLD / f"rev_{time.time_ns()}_worldforged_{name}.sql"
    path.write_text("\n".join(parts).rstrip() + "\n", encoding="utf-8", newline="\n")
    return path


def item_dbc_row(r):
    return [r["entry"], r["class"], r["subclass"], r["SoundOverrideSubclass"], r["Material"], r["displayid"],
            r["InventoryType"], r["sheath"]]


def write_client_rows(work, item_rows, idi_new, go_new):
    with (work / "Item.csv.rows").open("w", encoding="utf-8", newline="") as fh:
        for k in sorted(item_rows):
            fh.write(",".join(f'"{v}"' for v in item_dbc_row(item_rows[k])) + "\n")
    with (work / "ItemDisplayInfo.csv.rows").open("w", encoding="utf-8", newline="") as fh:
        for r in sorted(idi_new.values()):
            fh.write(",".join(f'"{v}"' for v in r) + "\n")
    (work / "GameObjectDisplayInfo.rows.json").write_text(json.dumps(sorted(go_new.values())), encoding="utf-8")
    (work / "ItemDisplayInfo.rows.json").write_text(json.dumps(sorted(idi_new.values())), encoding="utf-8")
    new_ids = {r[0] for r in idi_new.values()}
    usage = defaultdict(set)
    for r in item_rows.values():
        if r["displayid"] in new_ids:
            usage[r["displayid"]].add(r["InventoryType"])
    (work / "ItemDisplayInfo.usage.json").write_text(
        json.dumps({str(k): sorted(v) for k, v in sorted(usage.items())}), encoding="utf-8")


HEADER = """
-- ---------------------------------------------------------------------------------------------------
-- Worldforged pickups on maps 750 (80-130) and 751 (130-160), ported from Ascension CoA
-- ---------------------------------------------------------------------------------------------------
-- GENERATED by Custom/Documentation/scripts/worldforged/gen_worldforged_750_751.py - edit the generator,
-- not this file. Ids are pinned in that folder's data/allocation.csv.
--
-- WHAT IT IS. CoA hides "worldforged" treasures across the classic world: a sack, a corpse, a crate,
-- named after the one item it holds, that every character may open ONCE. Maps 750/751 copy Kalimdor and
-- the Eastern Kingdoms coordinate for coordinate, so every CoA pickup standing in a zone those maps
-- represent is placed at the same X/Y here, its height re-read from DC's own terrain, and its item
-- cloned and re-levelled to the DC band of the zone it lands in.
--
--   {spawns} spawns | {templates} gameobject templates | {items} item clones
--   {idi} new ItemDisplayInfo rows | {godi} new GameObjectDisplayInfo rows (SQL overlays below; the
--   client needs the matching DBC rows and assets - see the generator's README)
--
-- ITEMS follow 309_/312_'s model: target budget 0.00207 * ilvl^2.13 * slot * quality, spread over the
-- source's own positive stats, no stat above 40% of the budget; armor and weapon damage from the Cata
-- curve DBCs (gen_zone_gear_armor_dmg.py). Map 750 uses 309_'s band table; map 751 continues it.
-- Ascension-only item spells (PvE/PvP Power, scripted procs, profession bonuses) are dropped.
--
-- ONE LOOT PER CHARACTER is enforced by the C++ script `{script}`
-- (src/server/scripts/DC/Worldforged/dc_worldforged_pickups.cpp): spawn guid N ({lo_s}-{hi_s}) is bit
-- N-{lo_s} of the character's "dc-worldforged" character_settings row. NEVER renumber these spawns.
-- Needs EnablePlayerSettings = 1 in worldserver.conf.
--
-- Idempotent: item_template and gameobject_template rows are REPLACEd (codestyle-sql forbids deleting from
-- template tables); every other table deletes its own id range right before its INSERT.
-- ---------------------------------------------------------------------------------------------------
"""

if __name__ == "__main__":
    main()
