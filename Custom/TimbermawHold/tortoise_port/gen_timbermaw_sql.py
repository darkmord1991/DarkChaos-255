#!/usr/bin/env python3
"""Timbermaw Hold (map 819) -- port of tortoise-wow's Turtle data onto our level-130 raid.

Reads tortoise_timbermaw_export.json (the Turtle rows, see 00_README.md for how it was made) and
client_asset_plan.json (Turtle display id -> our display id) and writes three pending world SQL
files. Run from anywhere:

    python gen_timbermaw_sql.py [--stamp <rev number>]

Nothing here talks to a database; the output is plain SQL for data/sql/updates/pending_db_world/.
Tuning knobs are the constants at the top; regenerate after changing them.
"""
import argparse
import csv
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PENDING = os.path.join(REPO, "data", "sql", "updates", "pending_db_world")
CDI_CSV = os.path.join(REPO, "Custom", "CSV DBC", "CreatureDisplayInfo.csv")

# --------------------------------------------------------------------------------------------
# Tuning. Turtle's numbers are a level-60 20-man; these turn them into level-130 numbers while
# keeping Turtle's RELATIVE design (which mob is tanky, which hits hard, how fast it swings).
# --------------------------------------------------------------------------------------------
HP_SCALE = 30.0          # Turtle health x30  -> a 600k Turtle boss lands at ~18M
DMG_SCALE = 5.0          # Turtle melee x5    -> a 3,000 Turtle swing lands at ~15k
FINAL_HP = 1.3           # Ursol on top of the above
FINAL_DMG = 1.15
GEODE_HP = 0.4           # the Geode shares Selenaxx's Turtle health; it is an add here
ITEM_ILVL_BASE = 450     # Turtle ilvl 76 -> 450, 2 item levels per Turtle level either side
QUALITY_BUDGET = {4: 1.0, 3: 0.82, 2: 0.7}
TOKEN = 300311           # DC Item Upgrade Token
TOKEN_SET_COST = 100     # replaces Turtle's vanilla crafting mats on Kathor's set quests

MAP, ZONE = 819, 5640
GUID_BASE = 16500000     # reserved Timbermaw creature block 16500000-16509999
GO_GUID_BASE = 16530201
CAMP_GUIDS = (16622020, 16622021, 16622022)
ITEM_BASE = 410200
QUEST_BASE = 700769
CAMP_MAP = 750

# creature_classlevelstats on the live DB (basehp2, damage_exp2, attackpower), read 2026-10-28
CLS = {
    (128, 1): (99703, 1677.69, 1840), (128, 2): (99703, 1705.03, 3348), (128, 8): (79866, 1679.56, 2273),
    (129, 1): (103421, 1755.71, 1863), (129, 2): (103421, 1784.58, 3405), (129, 8): (82845, 1758.92, 2315),
    (130, 1): (107259, 1837.12, 1886), (130, 2): (107259, 1867.61, 3462), (130, 8): (85920, 1841.78, 2357),
}

# Turtle entry -> (our entry, role, ScriptName). Roles: boss / companion / add / trash / camp.
# 4010007 is Ursol ON PURPOSE: Achievement_Criteria 13511 (achievement 60049) already points at
# 4010007 as the final boss, so keeping the final boss on that entry needs no client DBC asset edit.
CREATURES = {
    62934: (4010001, "boss", "boss_karrsh_the_sentinel"),
    62936: (4010002, "boss", "boss_rotgrowl"),
    62937: (4010003, "companion", "npc_kodiak"),
    62935: (4010004, "boss", "boss_ormanos_the_cracked"),
    2139: (4010005, "boss", "boss_loktanag_the_vile"),
    62940: (4010006, "boss", "boss_selenaxx_foulheart"),
    62947: (4010007, "final", "boss_ursol"),
    59816: (4010008, "companion", "npc_corrupted_draenethyst_geode"),
    62938: (4010009, "boss", "boss_archdruid_kronn"),
    62946: (4010010, "boss", "boss_trioch_the_devourer"),
    62941: (4010011, "boss", "boss_chieftain_partath"),
    62886: (4010012, "add", ""),
    62943: (4010013, "add", ""),
    62944: (4010014, "add", ""),
    62945: (4010015, "add", ""),
    62867: (4010101, "trash", ""), 62870: (4010102, "trash", ""), 62871: (4010103, "trash", ""),
    62872: (4010104, "trash", ""), 62873: (4010105, "trash", ""), 62874: (4010106, "trash", ""),
    62875: (4010107, "trash", ""), 62876: (4010108, "trash", ""), 62877: (4010109, "trash", ""),
    62878: (4010110, "trash", ""), 62879: (4010111, "trash", ""), 62880: (4010112, "trash", ""),
    62881: (4010113, "trash", ""), 62882: (4010114, "trash", ""), 62883: (4010115, "trash", ""),
    62884: (4010116, "trash", ""), 62885: (4010117, "trash", ""), 62942: (4010118, "trash", ""),
    62740: (4010201, "camp", ""), 62631: (4010202, "camp", ""), 62630: (4010203, "camp", ""),
}
ENTRY = {t: v[0] for t, v in CREATURES.items()}

# Encounter order = boss data id = DungeonEncounter bit. Brazier guardians open the Barrier of Ursol.
ENCOUNTERS = [
    (4010001, "Karrsh the Sentinel"), (4010002, "Rotgrowl and Kodiak"), (4010005, "Loktanag the Vile"),
    (4010004, "Ormanos the Cracked"), (4010011, "Chieftain Partath"), (4010009, "Archdruid Kronn"),
    (4010006, "Selenaxx Foulheart"), (4010010, "Trioch the Devourer"), (4010007, "Ursol"),
]
ENCOUNTER_DBC_IDS = {0: [1100, 1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108],
                     1: [1218, 1219, 1220, 1221, 1222, 1223, 1224, 1115, 1116],
                     2: [1225, 1226, 1227, 1228, 1229, 1230, 1231, 1117, 1118]}

# Turtle display -> our display. Stock vanilla ids are identical in 3.3.5; Turtle-custom ones were
# re-hosted by client_asset_plan.json (upport rows + staged models). Turtle's 12190 is FireImp.mdx,
# which our client lacks; our 12190 is the stock Imp.mdx with the same ImpSkinRed texture. Do not
# follow the upport to 32986: that id is a female goblin NPC here.
STOCK_DISPLAYS = {959, 9276, 15463, 1086, 1108, 11338, 2687, 1082, 4588, 1460, 4534, 12190}
DISPLAY_OVERRIDE = {}
DROPPED_DISPLAYS = {21578, 21595}   # female satyr variants: model not shipped, male display kept
# Turtle 1.12 CreatureModelScale of those stock displays (twmoa_1180 patch-8.mpq). 1108 is 0.7 on ours.
TW_STOCK_MODEL_SCALE = {959: 0.55, 1082: 1.5, 1086: 1.3, 1108: 0.6, 1460: 3.0, 2687: 1.5, 4534: 1.0, 4588: 1.0,
                        9276: 1.3, 11338: 1.5, 12190: 1.5, 15463: 4.0}

GO_MAP = {  # Turtle GO entry -> (our entry, type, displayId, name, flags, data[0..23])
    300602: (4010001, 5, 5151, "Brazier of Corruption", 16, []),
    300603: (4010002, 5, 5151, "Brazier of Defilement", 16, []),
    300604: (4010003, 5, 5151, "Brazier of Decay", 16, []),
    300605: (4010004, 5, 5151, "Brazier of Putrification", 16, []),
    300606: (4010005, 0, 523, "Barrier of Ursol", 48, [0, 0, 0, 0, 0, 0]),
    2020307: (4010006, 3, 323, "Narkogg's Medicine Pouch", 4, [43, 4010006, 0, 0, 0, 0, 0, 0, None, 0, 1]),
    2020308: (4010007, 3, 3231, "Putrid Flower", 4, [43, 4010007, 0, 0, 0, 0, 0, 0, None, 0, 1]),
    2002565: (4010008, 5, 6450, "Instance Portal", 0, []),
    2008758: (4010009, 5, 6916, "Furbolg Worktable", 0, []),
    20961: (4010010, 8, 192, "Campfire", 0, [4, 10]),
}
SKIP_GOS = {180322}   # Turtle's Ghost Gate would wall our arrival point off (our arrival sits behind it)
OBJECT_SCALING = {5026138: 2.0, 5030596: 3.0}   # Turtle per-spawn sizes (object_scaling): campfire, portal

# Quest items that are raid drops here (Turtle had three of them on outdoor rares).
QUEST_DROPS = {42170: 62934, 42171: 62871, 42172: 2139, 42173: 62946, 42174: 62938, 42224: 62940}
DROPPED_ITEMS = {42016, 42235, 33084}   # Timbermaw Sap, Eternal Essence, a reagent: no quest uses them
CAMP = {  # our entry -> (x, y, z, o) at the Timbermaw camp on map 750, beside Gorn One Eye
    4010201: (7027.8, -2110.5, 587.2, 3.14),
    4010202: (7027.0, -2124.5, 586.9, 3.14),
    4010203: (7030.5, -2130.0, 587.0, 3.14),
}
URSOL_SPAWN = (-7541.0, -3691.2, 376.0, 4.08)   # UrsocRoom floor read off the 819 navmesh (375.9)
GORN_ONE_EYE = 3711555
GREAT_BEAR_SPIRIT = 3711956
OLD_QUESTS = range(700760, 700769)
GATEKEEPER = 3999002


def esc(s):
    s = "" if s is None else str(s)
    s = re.sub(r"(?<=[A-Za-z])[?�](?=[A-Za-z])", "'", s)   # Turtle curly apostrophes lost in the dump
    s = s.replace("�", "'").replace("’", "'").replace("‘", "'").replace("–", "-")
    s = s.replace("“", '"').replace("”", '"').replace("…", "...")
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def num(v):
    if v is None:
        return "NULL"
    if isinstance(v, float):
        r = round(v, 4)
        return repr(int(r)) if r == int(r) else repr(r)
    return str(v)


def fix_text(s):
    if s is None:
        return ""
    s = s.replace("\r\n", "\n")
    s = s.replace("?s ", "'s ").replace("?t ", "'t ")
    for a, b in TEXT_FIXES:
        s = s.replace(a, b)
    return s


TEXT_FIXES = [
    ("in the Maw of Ursoc in Azshara", "at the Timbermaw camp before the hold"),
    ("the Maw of Ursoc in Azshara", "the Timbermaw camp before the hold"),
    ("Maw of Ursoc", "Timbermaw camp"),
    ("Muln Earthfury at the Earthen Ring in the Stonetalon Mountains", "Nathok at the Timbermaw camp"),
    ("Riftmaster Ral'pekta in Moro'gai Village of Moonwhisper Coast", "Nathok at the Timbermaw camp"),
    ("Riftmaster Ral’pekta in Moro’gai Village of Moonwhisper Coast", "Nathok at the Timbermaw camp"),
    ("the furbolg of the Timbermaw camp before the hold", "Kathor the Brave at the Timbermaw camp"),
    ("Kalimdor", "Kalimdor"),
]


def rows_sql(table, cols, rows, verb="INSERT INTO"):
    out = ["%s `%s` (%s) VALUES" % (verb, table, ", ".join("`%s`" % c for c in cols))]
    body = []
    for r in rows:
        body.append("(" + ", ".join(r) + ")")
    out.append(",\n".join(body) + ";")
    return "\n".join(out)


# --------------------------------------------------------------------------------------------
ex = json.load(open(os.path.join(HERE, "tortoise_timbermaw_export.json"), encoding="utf-8"))
plan = json.load(open(os.path.join(HERE, "client_asset_plan.json"), encoding="utf-8"))
tmpl = {c["entry"]: c for c in ex["creature_template"]}
cdia = {d["display_id"]: d for d in ex["creature_display_info_addon"]}
items_tw = {i["entry"]: i for i in ex["item_template"]}
spells_tw = {s["entry"]: s for s in ex["spell_template"]}
quests_tw = {q["entry"]: q for q in ex["quest_template"]}
MODEL_SCALE = {int(r["ID"]): float(r["CreatureModelScale"]) for r in plan["cdi_new"]}
MODEL_SCALE.update({int(r["ID"]): float(r["CreatureModelScale"])
                    for r in csv.DictReader(open(CDI_CSV, encoding="utf-8-sig"))})


def display_scale(c, disp):
    """Turtle's creature_template.scale is the FINAL size: the 1.12 client never applies the display's
    CreatureModelScale, and vmangos substitutes that value when the column is 0. Our client multiplies
    DisplayScale by our CreatureModelScale, so it is divided back out here."""
    d = c["display_id1"]
    final = c["scale"] if c["scale"] and c["scale"] > 0 else (
        TW_STOCK_MODEL_SCALE.get(d) or plan["creature"][str(d)]["scale"])
    return final / MODEL_SCALE[disp]


def our_display(d):
    if not d or d in DROPPED_DISPLAYS:
        return None
    if d in DISPLAY_OVERRIDE:
        return DISPLAY_OVERRIDE[d]
    if d in STOCK_DISPLAYS:
        return d
    p = plan["creature"].get(str(d))
    if not p:
        raise SystemExit("no display mapping for Turtle display %d" % d)
    return p["display"]


def level_for(role, tw_level):
    if role in ("boss", "final", "companion", "camp"):
        return 130
    return max(128, min(130, 130 + tw_level - 63))


def est_melee(level, unit_class, dm, bat):
    hp2, dmg2, ap = CLS[(level, unit_class)]
    return (dmg2 * 1.25 + ap / 14.0 * bat / 1000.0) * dm


# ============================================================================================
# 1. creatures
# ============================================================================================
TEMPLATE_COLS = ["entry", "name", "subname", "minlevel", "maxlevel", "exp", "faction", "npcflag", "speed_walk",
                 "speed_run", "rank", "dmgschool", "DamageModifier", "BaseAttackTime", "RangeAttackTime",
                 "BaseVariance", "RangeVariance", "unit_class", "unit_flags", "unit_flags2", "family", "type",
                 "type_flags", "lootid", "AIName", "MovementType", "HealthModifier", "ManaModifier",
                 "ArmorModifier", "ExperienceModifier", "RegenHealth", "CreatureImmunitiesId", "flags_extra",
                 "ScriptName", "VerifiedBuild"]
LOOTED = {62934, 62936, 62935, 2139, 62940, 62947, 62938, 62946, 62941}
template_rows, model_rows, minfo_rows, equip_rows, movement_rows = [], [], [], [], []
expected_melee = {}
new_displays = {}
report = []
for tw_entry, (entry, role, script) in sorted(CREATURES.items(), key=lambda kv: kv[1][0]):
    c = tmpl[tw_entry]
    uc = c["unit_class"] if c["unit_class"] in (1, 2, 8) else 1
    lvl = level_for(role, c["level_min"])
    hp2 = CLS[(lvl, uc)][0]
    tw_hp = c["health_min"]
    hp_target = tw_hp * HP_SCALE * (FINAL_HP if role == "final" else 1.0)
    if tw_entry == 59816:
        hp_target *= GEODE_HP
    bat = c["base_attack_time"] or 2000
    tw_avg = (c["dmg_min"] + c["dmg_max"]) / 2.0
    dmg_target = tw_avg * DMG_SCALE * (FINAL_DMG if role == "final" else 1.0)
    dm = dmg_target / est_melee(lvl, uc, 1.0, bat)
    hm = hp_target / hp2
    if role == "camp":
        hm, dm = 25.0, 4.0
    if tw_entry in (62886, 59816):   # totem and geode never swing; their damage is the script's pulse
        dm = 0.05
    hm, dm = round(max(hm, 0.5), 2), round(max(dm, 0.05), 2)
    expected_melee[entry] = est_melee(lvl, uc, dm, bat)
    boss = role in ("boss", "final", "companion")
    faction = 414 if role == "camp" else 16
    npcflag = 2 if role == "camp" else 0
    rank = 3 if boss else (0 if tw_entry in (62874, 62886, 62945) or role == "camp" else 1)
    tw_type = c["type"] if c["type"] else 10
    type_flags = 4 if boss else 0
    loot = entry if (tw_entry in LOOTED or role in ("trash",)) else 0
    ai = "" if (script or role == "camp") else "SmartAI"
    immun = -286 if boss else 0
    flags_extra = 2148007937 if boss else 0
    mana = 10 if uc in (2, 8) else 1
    template_rows.append([
        num(entry), esc(c["name"]), esc(c["subname"] or None) if c["subname"] else "NULL", num(lvl), num(lvl), "2",
        num(faction), num(npcflag), num(round(c["speed_walk"] or 1.0, 4)), num(round(c["speed_run"] or 1.14286, 5)),
        num(rank), "0", num(dm), num(bat), "2000", "1", "1", num(uc), "0", "0", "0", num(tw_type), num(type_flags),
        num(loot), esc(ai), "0", num(hm), num(mana), "1", "1", "1", num(immun), num(flags_extra), esc(script), "0"])
    disp = our_display(c["display_id1"])
    model_rows.append([num(entry), "0", num(disp), num(round(display_scale(c, disp), 3)), "1", "0"])
    if disp >= 4010001 and disp not in new_displays:
        a = cdia.get(c["display_id1"], {})
        new_displays[disp] = (a.get("bounding_radius", 1.0) or 1.0, a.get("combat_reach", 1.5) or 1.5)
    eq = next((e for e in ex["creature_equip_template"] if e["entry"] == c.get("equipment_id")), None)
    if eq and tw_entry != 62937:
        ids = [61525 == v and 3028 or v for v in (eq["equipentry1"], eq["equipentry2"], eq["equipentry3"])]
        equip_rows.append([num(entry), "1", num(ids[0]), num(ids[1]), num(ids[2]), "0"])
    if tw_entry in (59816, 62886):
        movement_rows.append([num(entry), "1", "0", "0", "1", "0", "0", "0"])
    report.append("%-8d %-28s %-9s lvl %d  HP %10s (HM %7.2f)  melee ~%7d (DM %5.2f)" % (
        entry, c["name"], role, lvl, "{:,}".format(int(hm * hp2)), hm, expected_melee[entry], dm))

# Turtle's values were multiplied by its final scale, which includes the display's model scale. The core
# multiplies ours by DisplayScale only, so the model scale goes in here.
for disp, (br, cr) in sorted(new_displays.items()):
    ms = MODEL_SCALE[disp]
    minfo_rows.append([num(disp), num(round(br * ms, 4)), num(round(cr * ms, 4)), "2", "0", "0"])

# ---- spawns
spawns = sorted(ex["creature"], key=lambda s: s["guid"])
guid_of = {}
creature_rows, addon_rows, wp_rows = [], [], []
mv = {}
for m in ex["creature_movement"]:
    mv.setdefault(m["id"], []).append(m)
addon_tw = {a["guid"]: a for a in ex["creature_addon"]}
for i, s in enumerate(spawns):
    g = GUID_BASE + i
    guid_of[s["guid"]] = g
    entry = ENTRY[s["id"]]
    role = CREATURES[s["id"]][1]
    mt = s["movement_type"]
    path = mv.get(s["guid"], [])
    if mt == 2 and not path:
        mt = 0
    wander = s["wander_distance"] if mt == 1 else 0
    if mt == 1 and wander <= 0:
        wander = 5
    has_equip = any(r[0] == num(entry) for r in equip_rows)
    creature_rows.append([num(g), num(entry), num(MAP), num(ZONE), num(ZONE), "7", "1", "1" if has_equip else "0",
                          num(round(s["position_x"], 4)), num(round(s["position_y"], 4)),
                          num(round(s["position_z"], 4)), num(round(s["orientation"], 4)), "604800",
                          num(wander), "0", "1", "0", num(mt), "0", "0", "0", "''", "0", "0",
                          esc("Timbermaw Hold - %s (Turtle guid %d)" % (tmpl[s["id"]]["name"], s["guid"]))])
    a = addon_tw.get(s["guid"])
    stand = a["stand_state"] if (a and role == "trash") else 0
    emote = a["emote_state"] if (a and role == "trash") else 0
    if mt == 2 or stand or emote:
        addon_rows.append([num(g), num(g * 10 if mt == 2 else 0), "0", num(stand), "0", num(emote), "0", "''"])
    if mt == 2:
        for p in sorted(path, key=lambda m: m["point"]):
            o = p["orientation"]
            o = "NULL" if (o is None or o >= 100 or o == 0) else num(round(o, 4))
            wp_rows.append([num(g * 10), num(p["point"]), num(round(p["position_x"], 4)),
                            num(round(p["position_y"], 4)), num(round(p["position_z"], 4)), o, "0",
                            num(p["waittime"] or 0), "0", "0", "0", "100", "0"])
URSOL_GUID = GUID_BASE + len(spawns)
creature_rows.append([num(URSOL_GUID), "4010007", num(MAP), num(ZONE), num(ZONE), "7", "1", "0",
                      num(URSOL_SPAWN[0]), num(URSOL_SPAWN[1]), num(URSOL_SPAWN[2]), num(URSOL_SPAWN[3]), "604800",
                      "0", "0", "1", "0", "0", "0", "0", "0", "''", "0", "0",
                      esc("Timbermaw Hold - Ursol (not spawned by Turtle; UrsocRoom, behind the Barrier of Ursol)")])
camp_rows = []
for (entry, pos), g in zip(sorted(CAMP.items()), CAMP_GUIDS):
    camp_rows.append([num(g), num(entry), num(CAMP_MAP), "0", "0", "1", "1", "1" if any(
        r[0] == num(entry) for r in equip_rows) else "0", num(pos[0]), num(pos[1]), num(pos[2]), num(pos[3]),
        "300", "0", "0", "1", "0", "0", "0", "0", "0", "''", "0", "0",
        esc("Timbermaw camp - %s (Timbermaw Hold quests)" % [t for t in tmpl.values()
                                                            if ENTRY.get(t["entry"]) == entry][0]["name"])])

# ---- gameobjects
go_tmpl_rows, go_addon_rows, go_rows = [], [], []
# Same model files as Turtle's displays and no scale column in GameObjectDisplayInfo, so sizes carry over.
# Every template here has one spawn, so a Turtle per-spawn size becomes the template size.
go_size = {t["entry"]: t["size"] for t in ex["gameobject_template"]}
go_size.update({g["id"]: OBJECT_SCALING[g["guid"]] for g in ex["gameobject"] if g["guid"] in OBJECT_SCALING})
for tw_id, (entry, gtype, disp, name, flags, data) in sorted(GO_MAP.items(), key=lambda kv: kv[1][0]):
    d = list(data) + [0] * (24 - len(data))
    d = [(QUEST_BASE + 3 if v is None else v) for v in d]   # Data8 questId of both chests = Unbridled Darkness (QUESTS[3])
    go_tmpl_rows.append([num(entry), num(gtype), num(disp), esc(name), "''", "''", "''", num(go_size[tw_id])] +
                        [num(v) for v in d] + ["''", "''", "0"])
    go_addon_rows.append([num(entry), "0", num(flags), "0", "0", "0", "0", "0", "0"])
gi = 0
for g in sorted(ex["gameobject"], key=lambda g: g["guid"]):
    if g["id"] in SKIP_GOS:
        continue
    entry = GO_MAP[g["id"]][0]
    go_rows.append([num(GO_GUID_BASE + gi), num(entry), num(MAP), num(ZONE), num(ZONE), "7", "1",
                    num(round(g["position_x"], 4)), num(round(g["position_y"], 4)), num(round(g["position_z"], 4)),
                    num(round(g["orientation"], 4)), num(round(g["rotation0"], 6)), num(round(g["rotation1"], 6)),
                    num(round(g["rotation2"], 6)), num(round(g["rotation3"], 6)), "604800", "100", "1", "''", "0",
                    esc("Timbermaw Hold - %s (Turtle guid %d)" % (GO_MAP[g["id"]][3], g["guid"]))])
    gi += 1

# ============================================================================================
# 2. items
# ============================================================================================
REF = {  # our ilvl-450 epics (410000-410053, live 2026-10-28): stat budget and armour by slot
    "budget": {1: 1138, 2: 550, 3: 886, 5: 1152, 20: 1111, 6: 793, 7: 1174, 8: 733, 9: 593, 10: 860, 11: 579,
               12: 450, 13: 512, 21: 516, 22: 512, 14: 656, 15: 373, 16: 593, 17: 1100, 23: 587, 25: 373,
               26: 367, 28: 300},
    "armor": {(1, 1): 475, (1, 2): 893, (1, 3): 1985, (1, 4): 3546, (3, 1): 439, (3, 2): 825, (3, 3): 1833,
              (3, 4): 3273, (5, 1): 584, (20, 1): 584, (5, 2): 1099, (5, 3): 2442, (5, 4): 4365, (6, 1): 340,
              (6, 2): 638, (6, 3): 1409, (6, 4): 2531, (7, 1): 511, (7, 2): 963, (7, 3): 2136, (7, 4): 3820,
              (8, 1): 414, (8, 2): 779, (8, 3): 1732, (8, 4): 3093, (9, 1): 264, (9, 2): 494, (9, 3): 1101,
              (9, 4): 3186, (10, 1): 366, (10, 2): 687, (10, 3): 1527, (10, 4): 2728, (16, 1): 301,
              (14, 6): 15085},
    "dps": {"1h": 386.0, "2h": 502.0, "caster2h": 339.0, "ranged": 460.0, "wand": 710.0},
    "block": 386,
}
PRIMARY = {3, 4, 5, 6, 7}
OUT_WEIGHT = {3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 45: 0.86, 38: 0.5, 39: 0.4, 43: 2.5, 46: 2.5, 31: 1, 32: 1, 36: 1,
              12: 1, 13: 1, 14: 1, 15: 1, 37: 1, 44: 1, 47: 1, 48: 0.65}


def spell_points(sid):
    """Turtle equip spell -> list of (3.3.5 stat type, budget points). Unmapped effects return []."""
    s = spells_tw.get(sid)
    if not s:
        return []
    out = []
    for k in (1, 2, 3):
        if s["effect%d" % k] not in (6, 35):
            continue
        aura = s["effectApplyAuraName%d" % k]
        misc = s["effectMiscValue%d" % k]
        v = abs(s["effectBasePoints%d" % k] + max(1, s["effectBaseDice%d" % k] or 0))
        if aura == 13:
            out.append((45, v * (0.86 if misc in (126, 127) else 0.7)))
        elif aura == 135:
            out.append((45, v * 0.45))
        elif aura in (52, 57, 71):
            out.append((32, v * 14))
        elif aura in (54, 55):
            out.append((31, v * 10))
        elif aura == 138:
            out.append((36, v * 10))
        elif aura == 30:
            out.append((12, v * 1.2) if misc == 95 else (37, v * 2.5))
        elif aura == 49:
            out.append((13, v * 12))
        elif aura == 47:
            out.append((14, v * 12))
        elif aura == 51:
            out.append((15, v * 5))
        elif aura == 158:
            out.append((48, v * 0.65))
        elif aura == 99:
            out.append((38, v * 0.5))
        elif aura == 124:
            out.append((39, v * 0.4))
        elif aura in (85,):
            out.append((43, v * 2.5))
        elif aura == 134:
            out.append((43, v * 2.5))
        elif aura in (161, 116):
            out.append((46, v * 2.5))
        elif aura == 123:
            out.append((44, v * 0.14) if misc == 1 else (47, v * 0.8))
    return out


ITEM_COLS = ["entry", "class", "subclass", "SoundOverrideSubclass", "name", "displayid", "Quality", "Flags",
             "FlagsExtra", "BuyCount", "BuyPrice", "SellPrice", "InventoryType", "AllowableClass", "AllowableRace",
             "ItemLevel", "RequiredLevel", "maxcount", "stackable"] + \
            ["stat_type%d" % i if j == 0 else "stat_value%d" % i for i in range(1, 11) for j in (0, 1)] + \
            ["dmg_min1", "dmg_max1", "dmg_type1", "armor", "holy_res", "fire_res", "nature_res", "frost_res",
             "shadow_res", "arcane_res", "delay", "ammo_type", "RangedModRange", "bonding", "description",
             "startquest", "Material", "sheath", "block", "MaxDurability", "flagsCustom", "VerifiedBuild"]
item_map = {}
for tw in sorted(items_tw):
    if tw not in DROPPED_ITEMS:
        item_map[tw] = ITEM_BASE + len(item_map)
quest_ids = {}   # filled below; startquest needs them, so items are emitted after quests are numbered
item_rows, item_dbc_rows, item_report, vault_items = [], [], [], []


def fallback_main(cls, sub, inv):
    """Main stat for an item whose Turtle value was only a proc/use effect we cannot port."""
    if cls == 2:
        if sub in (10, 19):          # staff, wand
            return 45
        if sub in (13, 15, 2, 3, 18, 16):   # fist, dagger, bow, gun, crossbow, thrown
            return 3
        return 4
    if sub == 1:
        return 5
    if sub in (2, 3):
        return 3
    if sub in (4, 6):
        return 4
    if sub in (7, 8, 9, 10, 11):     # relics
        return 45
    return 32 if inv in (2, 11, 12) else 7


VAULT_SLOT = {1: "Head", 2: "Neck", 3: "Shoulder", 5: "Chest", 20: "Chest", 6: "Waist", 7: "Legs", 8: "Feet",
              9: "Wrist", 10: "Hands", 11: "Finger", 12: "Trinket", 16: "Back", 14: "Shield", 23: "Offhand",
              15: "Ranged", 25: "Ranged", 26: "Ranged", 28: "Ranged"}
VAULT_ARMOR = {1: "Cloth", 2: "Leather", 3: "Mail", 4: "Plate"}


def vault_rows():
    out = []
    for entry, cls, sub, inv in vault_items:
        armor = VAULT_ARMOR.get(sub, "Misc") if cls == 4 else "Misc"
        out.append([num(entry), "440", "470", "1023", "NULL", esc(armor), esc(VAULT_SLOT.get(inv, "Weapon")), "7", "10",
                    esc("Timbermaw Hold")])
    return out


def build_items():
    for tw, entry in sorted(item_map.items(), key=lambda kv: kv[1]):
        it = items_tw[tw]
        inv = it["inventory_type"]
        cls, sub = it["class"], it["subclass"]
        q = it["quality"]
        disp_plan = plan["item"].get(str(it["display_id"]), {})
        disp = disp_plan.get("display", 0)
        equip = cls in (2, 4) and inv not in (0, 18, 24)
        tw_il = it["item_level"] or 0
        if equip and tw_il < 70:   # Turtle left raid items at ilvl 0/60 here and there
            tw_il = 76
        ilvl = ITEM_ILVL_BASE + (tw_il - 76) * 2 if equip else max(1, tw_il)
        req = 130 if equip else 0
        stats = []
        dmin = dmax = armor = block = 0
        res = [0] * 6
        if equip:
            pts = {}
            for n in range(1, 11):
                t, v = it["stat_type%d" % n], it["stat_value%d" % n]
                if t in PRIMARY and v:
                    pts[t] = pts.get(t, 0) + v
            dropped = []
            for n in range(1, 6):
                sid = it["spellid_%d" % n]
                if not sid:
                    continue
                conv = spell_points(sid) if it["spelltrigger_%d" % n] == 1 else []
                if not conv:
                    dropped.append(spells_tw.get(sid, {}).get("name", str(sid)))
                for t, p in conv:
                    pts[t] = pts.get(t, 0) + p
            total = sum(pts.values())
            budget = REF["budget"].get(inv, 600) * QUALITY_BUDGET.get(q, 0.8) * ilvl / ITEM_ILVL_BASE
            if 39 in pts:   # 3.3.5 attack power already covers ranged
                pts[38] = pts.get(38, 0) + pts.pop(39)
            if total <= 0 or (pts.keys() <= {7} and dropped):
                pts = {fallback_main(cls, sub, inv): 1.0, 7: 1.0}
            total = sum(pts.values())
            for t, p in sorted(pts.items(), key=lambda kv: -kv[1])[:10]:
                v = int(round(budget * p / total / OUT_WEIGHT.get(t, 1)))
                if v > 0:
                    stats.append((t, v))
            for k, col in enumerate(("holy_res", "fire_res", "nature_res", "frost_res", "shadow_res", "arcane_res")):
                res[k] = int(it[col] or 0) * 5
            if cls == 4 and sub in (1, 2, 3, 4) or (cls == 4 and sub == 6):
                base = REF["armor"].get((inv, sub))
                if base is None and inv == 5:
                    base = REF["armor"].get((20, sub))
                armor = int(round((base or (it["armor"] or 0) * 5) * QUALITY_BUDGET.get(q, 0.8) * ilvl / ITEM_ILVL_BASE))
            if cls == 4 and sub == 6:
                block = int(round(REF["block"] * QUALITY_BUDGET.get(q, 0.8) * ilvl / ITEM_ILVL_BASE))
            if cls == 2:
                caster = any(t in (45, 43) for t, _ in stats) and not any(t in (38, 39) for t, _ in stats)
                if inv in (15, 25, 26):
                    kind = "wand" if sub == 19 else "ranged"
                elif inv == 17:
                    kind = "caster2h" if caster else "2h"
                else:
                    kind = "1h"
                dps = REF["dps"][kind] * QUALITY_BUDGET.get(q, 0.8) * ilvl / ITEM_ILVL_BASE
                if kind == "1h" and caster:
                    dps *= 0.75
                delay = it["delay"] or 2000
                ratio = (it["dmg_max1"] / it["dmg_min1"]) if it["dmg_min1"] else 1.5
                avg = dps * delay / 1000.0
                dmin = int(round(avg * 2 / (1 + ratio)))
                dmax = int(round(dmin * ratio))
            item_report.append("%d -> %d %-40s ilvl %d->%d  %s%s" % (
                tw, entry, it["name"], tw_il, ilvl, " ".join("%d:%d" % s for s in stats),
                ("  [dropped: %s]" % ", ".join(dropped)) if dropped else ""))
        flags = it["flags"] or 0
        if tw in QUEST_DROPS or tw in (42175, 42176):
            flags |= 0x800
        sq = it.get("start_quest") or 0
        sq = quest_ids.get(sq, 0)
        stat_cols = []
        for n in range(10):
            if n < len(stats):
                stat_cols += [num(stats[n][0]), num(stats[n][1])]
            else:
                stat_cols += ["0", "0"]
        sell = int((it["sell_price"] or 0) * 10)
        item_rows.append([num(entry), num(cls), num(sub), "-1", esc(it["name"]), num(disp), num(q), num(flags), "0",
                          "1", "0", num(sell), num(inv), num(it["allowable_class"] or -1), "-1", num(ilvl),
                          num(req), num(it["max_count"] or 0), num(it["stackable"] or 1)] + stat_cols +
                         [num(dmin), num(dmax), num(it["dmg_type1"] or 0), num(armor)] + [num(r) for r in res] +
                         [num(it["delay"] or 0 if cls == 2 else 0), "0", num(it["range_mod"] or 0 if cls == 2 else 0),
                          num(it["bonding"] or 0), esc(it["description"] or ""), num(sq), num(it["material"] or 0),
                          num(it["sheath"] or 0), num(block), num(it["max_durability"] or 0), "0", "0"])
        item_dbc_rows.append((entry, cls, sub, -1, it["material"] or 0, disp, inv, it["sheath"] or 0))
        if equip and q == 4:
            vault_items.append((entry, cls, sub, inv))


# ============================================================================================
# 3. quests
# ============================================================================================
NARKOGG, KATHOR, NATHOK = 4010201, 4010202, 4010203
QUESTS = [  # (turtle id, starter, ender, prev turtle id, rewards dict)
    (41930, NARKOGG, NARKOGG, None, {"token": 60}),
    (41931, NARKOGG, NARKOGG, 41930, {"token": 60}),
    (41932, NARKOGG, NARKOGG, 41931, {"token": 60}),
    (41933, NARKOGG, NARKOGG, 41932, {"token": 60}),
    (41934, NARKOGG, NARKOGG, 41933, {"token": 120}),
    (42022, None, KATHOR, 41933, {}),
    (41937, None, GREAT_BEAR_SPIRIT, None, {}),
    (41953, NATHOK, NATHOK, None, {"token": 60}),
    (42009, NATHOK, NATHOK, None, {"token": 60}),
    (42023, KATHOR, KATHOR, None, {"set": True}),
    (42024, KATHOR, KATHOR, None, {"set": True}),
    (42025, KATHOR, KATHOR, None, {"set": True}),
    (42026, KATHOR, KATHOR, None, {"set": True}),
    (42027, KATHOR, KATHOR, None, {"set": True}),
    (42028, KATHOR, KATHOR, None, {"set": True}),
]
for i, qd in enumerate(QUESTS):
    quest_ids[qd[0]] = QUEST_BASE + i

QUEST_COLS = ["ID", "QuestType", "QuestLevel", "MinLevel", "QuestSortID", "QuestInfoID", "SuggestedGroupNum",
              "RewardXPDifficulty", "RewardMoney", "StartItem", "Flags",
              "RewardItem1", "RewardAmount1", "RewardItem2", "RewardAmount2",
              "RewardChoiceItemID1", "RewardChoiceItemQuantity1", "RewardChoiceItemID2", "RewardChoiceItemQuantity2",
              "RewardChoiceItemID3", "RewardChoiceItemQuantity3", "RewardChoiceItemID4", "RewardChoiceItemQuantity4",
              "RewardChoiceItemID5", "RewardChoiceItemQuantity5", "RewardChoiceItemID6", "RewardChoiceItemQuantity6",
              "RewardFactionID1", "RewardFactionOverride1", "AllowableRaces", "LogTitle", "LogDescription",
              "QuestDescription", "QuestCompletionLog",
              "RequiredNpcOrGo1", "RequiredNpcOrGo2", "RequiredNpcOrGoCount1", "RequiredNpcOrGoCount2",
              "RequiredItemId1", "RequiredItemId2", "RequiredItemId3", "RequiredItemId4",
              "RequiredItemCount1", "RequiredItemCount2", "RequiredItemCount3", "RequiredItemCount4",
              "ObjectiveText1", "VerifiedBuild"]
quest_rows, addon_q_rows, starter_rows, ender_rows, offer_rows, request_rows, qmap_rows = [], [], [], [], [], [], []


def build_quests():
    for i, (tw, starter, ender, prev, rw) in enumerate(QUESTS):
        q = quests_tw[tw]
        qid = quest_ids[tw]
        req_items = [(item_map.get(q["ReqItemId%d" % n]), q["ReqItemCount%d" % n]) for n in range(1, 5)
                     if q["ReqItemId%d" % n]]
        if rw.get("set"):
            req_items = [r for r in req_items if r[0] and items_tw[[k for k, v in item_map.items() if v == r[0]][0]]["class"] == 15]
            req_items.append((TOKEN, TOKEN_SET_COST))
        req_items = [r for r in req_items if r[0]]
        req_npc = [(ENTRY.get(q["ReqCreatureOrGOId%d" % n]), q["ReqCreatureOrGOCount%d" % n]) for n in range(1, 5)
                   if q["ReqCreatureOrGOId%d" % n] and ENTRY.get(q["ReqCreatureOrGOId%d" % n])]
        choices = [item_map[q["RewChoiceItemId%d" % n]] for n in range(1, 7) if q["RewChoiceItemId%d" % n] in item_map]
        rew_items = []
        if rw.get("token"):
            rew_items.append((TOKEN, rw["token"]))
        if tw == 41933:
            rew_items.append((item_map[42234], 1))
        rep = sum(q.get("RewRepValue%d" % n) or 0 for n in range(1, 6) if q.get("RewRepFaction%d" % n) == 576)
        start_item = item_map.get(q["SrcItemId"], 0) if q["SrcItemId"] else 0
        money = 0 if rw.get("set") else 400000
        cols = [num(qid), "2", "-1", "128", num(ZONE), "62", "0", "0", num(money), num(start_item), "8"]
        ri = rew_items + [(0, 0)] * (2 - len(rew_items))
        for a, b in ri[:2]:
            cols += [num(a), num(b)]
        ch = choices + [0] * (6 - len(choices))
        for c in ch[:6]:
            cols += [num(c), "1" if c else "0"]
        cols += ["576" if rep else "0", num(rep * 100), "0", esc(fix_text(q["Title"])),
                 esc(fix_text(q["Objectives"])), esc(fix_text(q["Details"])), esc(fix_text(q["EndText"]))]
        rn = req_npc + [(0, 0)] * (2 - len(req_npc))
        cols += [num(rn[0][0]), num(rn[1][0]), num(rn[0][1]), num(rn[1][1])]
        rq = req_items + [(0, 0)] * (4 - len(req_items))
        cols += [num(r[0]) for r in rq[:4]] + [num(r[1]) for r in rq[:4]]
        cols += [esc(fix_text(q["ObjectiveText1"] or "")), "0"]
        quest_rows.append(cols)
        prev_id = quest_ids.get(prev, 0) if prev else 0
        allow = q["RequiredClasses"] or 0
        addon_q_rows.append([num(qid), "0", num(allow), "0", num(prev_id), "0", "0", "0", "0", "0", "0", "0", "0",
                             "0", "0", "0", "0", "0"])
        if starter:
            starter_rows.append([num(starter), num(qid)])
        ender_rows.append([num(ender), num(qid)])
        if q["OfferRewardText"]:
            offer_rows.append([num(qid), "0", "0", "0", "0", "0", "0", "0", "0", esc(fix_text(q["OfferRewardText"])), "0"])
        if q["RequestItemsText"]:
            request_rows.append([num(qid), "0", "0", esc(fix_text(q["RequestItemsText"])), "0"])
        qmap_rows.append([num(qid), num(MAP), "1"])


# ============================================================================================
# 4. loot
# ============================================================================================
LOOT_COLS = ["Entry", "Item", "Reference", "Chance", "QuestRequired", "LootMode", "GroupId", "MinCount", "MaxCount",
             "Comment"]
loot_rows, go_loot_rows = [], []


def build_loot():
    raw = {}
    for r in ex["creature_loot_template"]:
        raw.setdefault(r["entry"], []).append(r)
    ref901397 = [r["item"] for r in ex["reference_loot_template"] if r["entry"] == 901397]
    for tw_boss in sorted(LOOTED, key=lambda t: ENTRY[t]):
        entry = ENTRY[tw_boss]
        name = tmpl[tw_boss]["name"]
        rows = raw.get(tw_boss, [])
        groups = {}
        for r in rows:
            if r["mincountOrRef"] < 0:
                if -r["mincountOrRef"] == 901397:
                    groups.setdefault(9, []).extend(ref901397)
                continue
            it = items_tw.get(r["item"])
            if r["item"] not in item_map or not it:
                continue
            if it["class"] in (2, 4) and it["inventory_type"] not in (0,):
                groups.setdefault(r["groupid"] or 1, []).append(r["item"])
            elif it["class"] == 15 or r["item"] in (42177, 42306):
                loot_rows.append([num(entry), num(item_map[r["item"]]), "0", "100", "0", "1", "0",
                                  "2" if it["class"] == 15 else "1", "2" if it["class"] == 15 else "1",
                                  esc("%s - %s" % (name, it["name"]))])
        gear_groups = [g for k, g in sorted(groups.items()) if g]
        if tw_boss != 62947 and len(gear_groups) == 1:
            gear_groups.append(gear_groups[0])
        for gid, g in enumerate(gear_groups, start=1):
            for item in g:
                loot_rows.append([num(entry), num(item_map[item]), "0", "0", "0", "1", num(gid), "1", "1",
                                  esc("%s - raid gear, group %d" % (name, gid))])
        if tw_boss == 62947:
            loot_rows.append([num(entry), num(item_map[42306]), "0", "100", "0", "1", "0", "1", "1",
                              esc("Ursol - Corrupted Hide of Ursol (starts Hide of a Wild God)")])
        loot_rows.append([num(entry), num(TOKEN), "0", "100", "0", "1", "0", "80" if tw_boss == 62947 else "40",
                          "100" if tw_boss == 62947 else "55", esc("%s - upgrade tokens" % name)])
    for tw_item, tw_src in sorted(QUEST_DROPS.items()):
        loot_rows.append([num(ENTRY[tw_src]), num(item_map[tw_item]), "0", "100", "1", "1", "0", "1", "1",
                          esc("%s - %s (quest)" % (tmpl[tw_src]["name"], items_tw[tw_item]["name"]))])
    for tw_entry, (entry, role, _) in sorted(CREATURES.items(), key=lambda kv: kv[1][0]):
        if role == "trash":
            loot_rows.append([num(entry), num(TOKEN), "0", "35", "0", "1", "0", "2", "4",
                              esc("%s - upgrade tokens" % tmpl[tw_entry]["name"])])
    for tw_go, item in ((2020307, 42175), (2020308, 42176)):
        go_loot_rows.append([num(GO_MAP[tw_go][0]), num(item_map[item]), "0", "100", "1", "1", "0", "1", "1",
                             esc("%s (quest)" % items_tw[item]["name"])])


build_quests()
build_items()
build_loot()
# a boss that only had a shared reference keeps its whole pool; loot rows must be unique per (Entry, Item)
seen = set()
loot_rows = [r for r in loot_rows if not ((r[0], r[1], r[6]) in seen or seen.add((r[0], r[1], r[6])))]

# ============================================================================================
# 5. trash SmartAI -- SMART_ACTION_CUSTOM_CAST (218) carries a level-130 basepoint for every
#    fixed-damage spell, sized off the caster's own expected melee swing.
# ============================================================================================
SMART_COLS = ["entryorguid", "source_type", "id", "link", "event_type", "event_phase_mask", "event_chance",
              "event_flags", "event_param1", "event_param2", "event_param3", "event_param4", "event_param5",
              "event_param6", "action_type", "action_param1", "action_param2", "action_param3", "action_param4",
              "action_param5", "action_param6", "target_type", "target_param1", "target_param2", "target_param3",
              "target_param4", "target_x", "target_y", "target_z", "target_o", "comment"]
# (event, timers..., spell, bp0 pct, bp1 pct, target, target_params, comment)
IC = 0      # in combat timer
HP = 2      # own health pct window
AGGRO = 4
FRIEND = 14  # friendly hp deficit, radius
RESET = 25
VICTIM, RANDOM, SELF, INVOKER = 2, 5, 1, 7
KITS = {
    4010101: [(IC, (4000, 7000, 8000, 12000), 15284, 0, 0, VICTIM, (), "Cleave"),
              (HP, (0, 30, 0, 0), 8599, 0, 0, SELF, (), "Enrage at 30%")],
    4010102: [(IC, (2000, 4000, 7000, 10000), 34344, 0.55, 0, RANDOM, (40, 1), "Shadow Bolt"),
              (IC, (6000, 9000, 14000, 18000), 15654, 0.08, 0, RANDOM, (40, 1), "Shadow Word: Pain")],
    4010103: [(IC, (2000, 4000, 7000, 10000), 15801, 0.55, 0, VICTIM, (), "Lightning Bolt"),
              (IC, (8000, 12000, 14000, 18000), 15501, 0.35, 0, VICTIM, (), "Earth Shock"),
              (FRIEND, (400000, 40, 10000, 14000), 15982, ("heal", 0.04), 0, INVOKER, (), "Healing Wave")],
    4010104: [(IC, (3000, 6000, 14000, 20000), 12024, 0, 0, RANDOM, (30, 1), "Net"),
              (IC, (5000, 8000, 12000, 16000), 16509, 0.07, 0, VICTIM, (), "Rend")],
    4010105: [(AGGRO, (0, 0, 0, 0), ("summon", 4010012), 0, 0, SELF, (), "Summon Totem of Corruption"),
              (IC, (5000, 8000, 12000, 16000), 15501, 0.35, 0, VICTIM, (), "Earth Shock")],
    4010106: [(IC, (2000, 4000, 9000, 13000), 13298, 0.04, 0, VICTIM, (), "Poison"),
              (IC, (6000, 10000, 16000, 22000), 12023, 0, 0, RANDOM, (20, 1), "Web")],
    4010107: [(IC, (4000, 7000, 10000, 14000), 32736, 0, 0, VICTIM, (), "Mortal Strike"),
              (IC, (8000, 12000, 16000, 22000), 12024, 0, 0, RANDOM, (30, 1), "Net")],
    4010108: [(IC, (2000, 4000, 8000, 11000), 20690, 0.06, 0.4, RANDOM, (40, 1), "Moonfire"),
              (IC, (8000, 12000, 18000, 24000), 22415, 0, 0.05, RANDOM, (30, 1), "Entangling Roots")],
    4010109: [(IC, (5000, 8000, 12000, 16000), 23931, 0.35, 0, SELF, (), "Thunderclap"),
              (IC, (10000, 14000, 20000, 26000), 15593, 0, 0, SELF, (), "War Stomp")],
    4010110: [(IC, (3000, 5000, 6000, 8000), 31608, 0.15, 0, SELF, (), "Disease Cloud"),
              (IC, (8000, 12000, 18000, 24000), 7279, 0, 0, SELF, (), "Black Sludge")],
    4010111: [(IC, (2000, 4000, 8000, 12000), 21067, 0.45, 0.05, VICTIM, (), "Poison Bolt"),
              (IC, (5000, 8000, 14000, 18000), 16128, 0.06, 0, VICTIM, (), "Infected Bite")],
    4010112: [(IC, (4000, 7000, 10000, 14000), 5568, 0, 0, SELF, (), "Trample"),
              (IC, (9000, 13000, 18000, 24000), 15593, 0, 0, SELF, (), "War Stomp")],
    4010113: [(IC, (2000, 4000, 7000, 10000), 34344, 0.5, 0, RANDOM, (40, 1), "Shadow Bolt"),
              (IC, (8000, 12000, 20000, 26000), 22884, 0, 0, SELF, (), "Psychic Scream")],
    4010114: [(IC, (3000, 6000, 9000, 13000), 15583, 0.08, 0, VICTIM, (), "Rupture"),
              (IC, (5000, 8000, 7000, 11000), 15582, 0, 0, VICTIM, (), "Backstab")],
    4010115: [(RESET, (0, 0, 0, 0), 8822, 0, 0, SELF, (), "Stealth on reset"),
              (IC, (4000, 7000, 14000, 20000), 21060, 0, 0, RANDOM, (10, 1), "Blind"),
              (IC, (2000, 5000, 6000, 9000), 15582, 0, 0, VICTIM, (), "Backstab")],
    4010116: [(IC, (2000, 4000, 7000, 10000), 15242, 0.6, 0, RANDOM, (40, 1), "Fireball"),
              (IC, (8000, 12000, 18000, 24000), 19717, 0.08, 0, RANDOM, (40, 1), "Rain of Fire")],
    4010117: [(IC, (3000, 6000, 8000, 12000), 27556, 0.3, 0.06, VICTIM, (), "Rake"),
              (IC, (8000, 12000, 14000, 18000), 5568, 0, 0, SELF, (), "Trample")],
    4010118: [(FRIEND, (500000, 40, 9000, 13000), 22883, ("heal", 0.05), 0, INVOKER, (), "Heal"),
              (IC, (3000, 5000, 9000, 12000), 20690, 0.06, 0.4, RANDOM, (40, 1), "Moonfire")],
    4010012: [(IC, (2000, 2000, 6000, 6000), 24099, 0.08, 0.02, SELF, (), "Corruption pulse (Poison Bolt Volley)")],
    4010013: [(IC, (1000, 3000, 5000, 7000), 34344, 0.55, 0, RANDOM, (40, 1), "Shadow Bolt")],
    4010014: [(AGGRO, (0, 0, 0, 0), ("summon", 4010015), 0, 0, SELF, (), "Summon Foulheart Imp"),
              (IC, (1000, 3000, 5000, 7000), 34344, 0.55, 0, RANDOM, (40, 1), "Shadow Bolt")],
    4010015: [(IC, (1000, 2000, 3000, 4000), 20801, 0.35, 0, VICTIM, (), "Firebolt")],
}
smart_rows = []


def build_smart():
    names = {v[0]: tmpl[k]["name"] for k, v in CREATURES.items()}
    for entry, kit in sorted(KITS.items()):
        for i, (ev, ep, spell, bp0, bp1, tgt, tp, label) in enumerate(kit):
            melee = expected_melee[entry]
            evp = list(ep) + [0] * (6 - len(ep))
            if isinstance(spell, tuple) and spell[0] == "summon":
                action = [12, spell[1], 4, 30000, 1, 0, 0]   # TEMPSUMMON_CORPSE_TIMED_DESPAWN, attack invoker
            elif isinstance(bp0, tuple):   # heals sized against a ~1.2M-health raid trash mob
                heal = int(1200000 * bp0[1])
                action = [218, spell, 0, heal, 0, 0, 0]
            elif bp0 or bp1:
                action = [218, spell, 0, int(melee * bp0) if bp0 else 0, int(melee * bp1) if bp1 else 0, 0, 0]
            else:
                action = [11, spell, 0, 0, 0, 0, 0]
            tpp = list(tp) + [0] * (4 - len(tp))
            smart_rows.append([num(entry), "0", num(i), "0", num(ev), "0", "100", "0"] + [num(v) for v in evp] +
                              [num(v) for v in action] + [num(tgt)] + [num(v) for v in tpp] + ["0", "0", "0", "0"] +
                              [esc("%s - %s" % (names[entry], label))])


build_smart()

# ============================================================================================
# 6. creature_text for the scripted encounters (GroupID == Talk() argument in the C++)
# ============================================================================================
YELL, EMOTE_BOSS, SAY = 14, 41, 12
TEXTS = {
    4010001: [(0, YELL, "None pass the Sentinel. The hold is closed to the living."),
              (1, YELL, "The brazier burns for Ursol. You will feed it."),
              (2, YELL, "Brothers! To the gate!"),
              (3, YELL, "The... flame... gutters..."),
              (4, EMOTE_BOSS, "The Brazier of Corruption gutters and goes dark.")],
    4010002: [(0, YELL, "Kodiak! Fresh tracks. Bring them down!"),
              (1, YELL, "Run, then. Kodiak loves a chase."),
              (2, YELL, "KODIAK! You will pay for that, flesh!"),
              (3, YELL, "The hunt... is ended..."),
              (4, EMOTE_BOSS, "The Brazier of Defilement gutters and goes dark.")],
    4010003: [(0, EMOTE_BOSS, "Kodiak roars in fury over Rotgrowl's body!")],
    4010004: [(0, YELL, "Small... things... in my hall."),
              (1, EMOTE_BOSS, "Ormanos cracks, and pieces of him tear free!"),
              (2, YELL, "Crumble."),
              (3, YELL, "The stone... rests...")],
    4010005: [(0, YELL, "Rot takes all. Rot takes YOU."),
              (1, EMOTE_BOSS, "Loktanag's corruption spills out across the floor!"),
              (2, YELL, "Into the soil with you."),
              (3, YELL, "The roots... wither...")],
    4010006: [(0, YELL, "The crystal sings for me, mortals. Can you hear it?"),
              (1, EMOTE_BOSS, "The Corrupted Draenethyst Geode shields Selenaxx!"),
              (2, YELL, "Servants of the Foulheart, to me!"),
              (3, YELL, "Its song is... silent..."),
              (4, EMOTE_BOSS, "The Geode shatters and Selenaxx's shield fails!")],
    4010007: [(0, YELL, "You walk into my dream... and you will never wake."),
              (1, YELL, "My sons! Defend your father!"),
              (2, YELL, "The Nightmare is ETERNAL!"),
              (3, YELL, "At last... the dream... is quiet..."),
              (4, EMOTE_BOSS, "The last brazier dies. The Barrier of Ursol fades, and something vast stirs above."),
              (5, YELL, "Enough! The Nightmare claims you all!")],
    4010009: [(0, YELL, "The dream showed me your coming. It showed me your end."),
              (1, YELL, "Shadowkeepers, rise from the dark!"),
              (2, YELL, "Sleep, and do not wake."),
              (3, YELL, "Ursol... forgive me..."),
              (4, EMOTE_BOSS, "The Brazier of Decay gutters and goes dark.")],
    4010010: [(0, EMOTE_BOSS, "Trioch's three heads turn toward you as one."),
              (1, EMOTE_BOSS, "Trioch rears back, all three throats glowing!"),
              (3, EMOTE_BOSS, "Trioch the Devourer collapses, its heads hissing into silence.")],
    4010011: [(0, YELL, "Intruders in my hold! I will crack your bones and suck the marrow!"),
              (1, YELL, "Illuminators! Light the way to their deaths!"),
              (2, YELL, "Hungry. Always so HUNGRY!"),
              (3, YELL, "The tribe... is... broken..."),
              (4, EMOTE_BOSS, "The Brazier of Putrification gutters and goes dark.")],
}
text_rows = []
for cid, lines in sorted(TEXTS.items()):
    for gid, typ, text in lines:
        text_rows.append([num(cid), num(gid), "0", esc(text), num(typ), "0", "100", "0", "0", "0", "0",
                          "3" if typ == EMOTE_BOSS else "0", esc("Timbermaw Hold - %d group %d" % (cid, gid))])


# ============================================================================================
# writers
# ============================================================================================
def header(title, body):
    return "-- " + "=" * 92 + "\n" + "\n".join("-- " + l if l else "--" for l in [title, ""] + body) + \
        "\n-- " + "=" * 92 + "\n"


def write(path, parts):
    txt = "\n\n".join(p.strip("\n") for p in parts if p) + "\n"
    txt = re.sub(r"\n{3,}", "\n\n", txt)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stamp", default="1793300000000000000")
    a = ap.parse_args()
    base = int(a.stamp)
    f1 = os.path.join(PENDING, "rev_%d.sql" % base)
    f2 = os.path.join(PENDING, "rev_%d.sql" % (base + 1))
    f3 = os.path.join(PENDING, "rev_%d.sql" % (base + 2))
    note = ["Source: tortoise-wow (Turtle 1.18.1 restoration), map 819 data as of 2026-10-27, converted by",
            "Custom/TimbermawHold/tortoise_port/gen_timbermaw_sql.py -- regenerate, do not hand-edit."]
    old_spawns = ("DELETE FROM `creature` WHERE `id` BETWEEN 4010001 AND 4010199 "
                  "AND `guid` BETWEEN 16500000 AND 16509999;")
    p1 = [header("Timbermaw Hold (map 819) -- 1/3: creatures, spawns, patrols and gameobjects", note + [
        "",
        "REPLACES the previous Timbermaw content: the seven invented encounters, their 15 trash kits and",
        "3 pooled rares. Entries 4010001-4010015 / 4010101-4010118 are reused for Turtle's creatures; the",
        "old 4010151-4010153 rare templates are left in place but no longer spawned or scripted.",
        "Needs the client display rows (CreatureDisplayInfo/CreatureModelData 4010001+) on the SERVER",
        "dbc before this is applied, or every Turtle-model creature refuses to load.",
        "",
        "Ursol (4010007) is the final boss and stays on that entry so Achievement_Criteria 13511 keeps",
        "working. The Turtle 'Ghost Gate' is not spawned: it stands between our arrival point and the hold."]),
        "-- creature templates (REPLACE: these rows supersede the previous Timbermaw design)",
        rows_sql("creature_template", TEMPLATE_COLS, template_rows, "REPLACE INTO"),
        "DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4010001 AND 4010299;\n" +
        rows_sql("creature_template_model", ["CreatureID", "Idx", "CreatureDisplayID", "DisplayScale", "Probability",
                                             "VerifiedBuild"], model_rows),
        "DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 4010001 AND 4010099;\n" +
        rows_sql("creature_model_info", ["DisplayID", "BoundingRadius", "CombatReach", "Gender", "DisplayID_Other_Gender",
                                         "VerifiedBuild"], minfo_rows),
        "DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 4010001 AND 4010299;\n" +
        rows_sql("creature_equip_template", ["CreatureID", "ID", "ItemID1", "ItemID2", "ItemID3", "VerifiedBuild"],
                 equip_rows),
        "DELETE FROM `creature_template_movement` WHERE `CreatureId` BETWEEN 4010001 AND 4010299;\n" +
        rows_sql("creature_template_movement", ["CreatureId", "Ground", "Swim", "Flight", "Rooted", "Chase", "Random",
                                                "InteractionPauseTimer"], movement_rows),
        "-- the old pooled rare elites",
        "DELETE FROM `pool_creature` WHERE `pool_entry` = 300020;\nDELETE FROM `pool_template` WHERE `entry` = 300020;",
        "-- spawns: Turtle's 282 + Ursol",
        "DELETE FROM `creature_addon` WHERE `guid` BETWEEN 16500000 AND 16509999;\n" + old_spawns + "\n" +
        rows_sql("creature", ["guid", "id", "map", "zoneId", "areaId", "spawnMask", "phaseMask", "equipment_id",
                              "position_x", "position_y", "position_z", "orientation", "spawntimesecs",
                              "wander_distance", "currentwaypoint", "curhealth", "curmana", "MovementType", "npcflag",
                              "unit_flags", "dynamicflags", "ScriptName", "VerifiedBuild", "CreateObject", "Comment"],
                 creature_rows).replace("INSERT INTO", "INSERT INTO", 1),
        "DELETE FROM `creature_addon` WHERE `guid` BETWEEN 16500000 AND 16509999;\n" +
        rows_sql("creature_addon", ["guid", "path_id", "mount", "bytes1", "bytes2", "emote", "visibilityDistanceType",
                                    "auras"], addon_rows),
        "-- patrols (creature_movement -> waypoint_data, path id = guid * 10)",
        "DELETE FROM `waypoint_data` WHERE `id` BETWEEN 165000000 AND 165099999;\n" +
        rows_sql("waypoint_data", ["id", "point", "position_x", "position_y", "position_z", "orientation", "velocity",
                                   "delay", "smoothTransition", "move_type", "action", "action_chance", "wpguid"],
                 wp_rows),
        "-- gameobjects",
        rows_sql("gameobject_template", ["entry", "type", "displayId", "name", "IconName", "castBarCaption", "unk1",
                                         "size"] + ["Data%d" % i for i in range(24)] + ["AIName", "ScriptName",
                                                                                        "VerifiedBuild"],
                 go_tmpl_rows, "REPLACE INTO"),
        "DELETE FROM `gameobject_template_addon` WHERE `entry` BETWEEN 4010001 AND 4010099;\n" +
        rows_sql("gameobject_template_addon", ["entry", "faction", "flags", "mingold", "maxgold", "artkit0", "artkit1",
                                               "artkit2", "artkit3"], go_addon_rows),
        "DELETE FROM `gameobject` WHERE `id` BETWEEN 4010001 AND 4010099 AND `guid` BETWEEN 16530200 AND 16530299;\n" +
        rows_sql("gameobject", ["guid", "id", "map", "zoneId", "areaId", "spawnMask", "phaseMask", "position_x",
                                "position_y", "position_z", "orientation", "rotation0", "rotation1", "rotation2",
                                "rotation3", "spawntimesecs", "animprogress", "state", "ScriptName", "VerifiedBuild",
                                "Comment"], go_rows),
        "-- the brazier, barrier and boss scripts live in instance_timbermaw_hold.cpp (already bound to map 819)",
        "UPDATE `instance_template` SET `script` = 'instance_timbermaw_hold' WHERE `map` = 819;",
        "SELECT 'templates (want %d)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `creature_template` WHERE `entry` IN (%s)\n"
        "UNION ALL SELECT 'spawns on 819 in the block (want %d)', CAST(COUNT(*) AS CHAR) FROM `creature` WHERE `map` = 819 AND `guid` BETWEEN 16500000 AND 16509999\n"
        "UNION ALL SELECT 'patrol points (want %d)', CAST(COUNT(*) AS CHAR) FROM `waypoint_data` WHERE `id` BETWEEN 165000000 AND 165099999\n"
        "UNION ALL SELECT 'gameobjects (want %d)', CAST(COUNT(*) AS CHAR) FROM `gameobject` WHERE `guid` BETWEEN 16530200 AND 16530299\n"
        "UNION ALL SELECT 'spawns with no template (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature` c LEFT JOIN `creature_template` t ON t.`entry` = c.`id` WHERE c.`map` = 819 AND t.`entry` IS NULL\n"
        "UNION ALL SELECT 'models with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID` WHERE m.`CreatureID` BETWEEN 4010001 AND 4010299 AND i.`DisplayID` IS NULL\n"
        "UNION ALL SELECT 'guid above 0xFFFFFF (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature` WHERE `guid` > 16777215;" % (
            len(template_rows), ", ".join(r[0] for r in template_rows), len(creature_rows), len(wp_rows), len(go_rows)),
    ]
    verify = [p1.pop()]
    write(f1, p1)

    p2 = [header("Timbermaw Hold (map 819) -- 2/3: items and loot", note + [
        "",
        "Turtle's raid items, re-scaled to our tier (Turtle ilvl 76 -> 450, Required Level 130). Stats keep",
        "Turtle's MIX; the budget is our own ilvl-450 epics' per slot. Vanilla equip spells became 3.3.5",
        "ratings / spell power / AP / mp5; procs, class-relic modifiers and Turtle-only auras were dropped.",
        "Every entry needs an Item.dbc row on the server (Custom/CSV DBC/Item.csv) or the core drops it.",
        "The previous Timbermaw items 410000-410053 are left in item_template (players may own them) but",
        "no longer drop and are no longer offered by the Great Vault."]),
        rows_sql("item_template", ITEM_COLS, item_rows, "REPLACE INTO"),
        "DELETE FROM `creature_loot_template` WHERE `Entry` BETWEEN 4010001 AND 4010299;\n" +
        rows_sql("creature_loot_template", LOOT_COLS, loot_rows),
        "UPDATE `creature_template` SET `lootid` = 0 WHERE `entry` IN (4010151, 4010152, 4010153);",
        "DELETE FROM `gameobject_loot_template` WHERE `Entry` BETWEEN 4010001 AND 4010099;\n" +
        rows_sql("gameobject_loot_template", LOOT_COLS, go_loot_rows),
        "-- boss token payouts (dc_seasonal_creature_rewards keys on the creature entry)",
        "DELETE FROM `dc_seasonal_creature_rewards` WHERE `creature_id` BETWEEN 4010001 AND 4010199;\n" +
        rows_sql("dc_seasonal_creature_rewards", ["season_id", "creature_id", "reward_type", "base_token_amount",
                                                  "base_essence_amount", "creature_rank", "content_type",
                                                  "difficulty_level", "seasonal_multiplier", "minimum_players",
                                                  "group_split_tokens", "enabled"],
                 [["1", num(e), "1", "1000" if e == 4010007 else "500", "300" if e == 4010007 else "150", "3", "2",
                   "1", "2.5", "20", "1", "1"] for e, _ in ENCOUNTERS]),
        "-- Great Vault choices",
        "DELETE FROM `dc_vault_loot_table` WHERE `source` = 'Timbermaw Hold';\n" +
        rows_sql("dc_vault_loot_table", ["item_id", "item_level_min", "item_level_max", "class_mask", "spec_name",
                                         "armor_type", "slot_type", "role_mask", "weight", "source"], vault_rows()),
        "SELECT 'items (want %d)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `item_template` WHERE `entry` BETWEEN %d AND %d\n"
        "UNION ALL SELECT 'loot pointing at a missing item (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature_loot_template` l LEFT JOIN `item_template` i ON i.`entry` = l.`Item` WHERE l.`Entry` BETWEEN 4010001 AND 4010299 AND i.`entry` IS NULL\n"
        "UNION ALL SELECT 'vault entries (want %d)', CAST(COUNT(*) AS CHAR) FROM `dc_vault_loot_table` WHERE `source` = 'Timbermaw Hold';" % (
            len(item_rows), ITEM_BASE, ITEM_BASE + len(item_rows) - 1, len(vault_items)),
    ]
    verify.append(p2.pop())
    write(f2, p2)

    enc_rows = []
    for d_, ids in sorted(ENCOUNTER_DBC_IDS.items()):
        for bit, eid in enumerate(ids):
            enc_rows.append([num(eid), "0", num(ENCOUNTERS[bit][0]), "0",
                             esc("%s%s" % (ENCOUNTERS[bit][1], {0: "", 1: " (Heroic)", 2: " (Mythic)"}[d_]))])
    p3 = [header("Timbermaw Hold (map 819) -- 3/3: quests, camp NPCs, encounters, texts, trash AI", note + [
        "",
        "Quests 700769-700783 are Turtle's raid quests (DungeonQuest band). Narkogg, Kathor and Nathok stand",
        "at the Timbermaw camp on map 750 next to Gorn One Eye. Turtle's chains through Swamp of Sorrows,",
        "Zul'Gurub and Moonwhisper Coast were not ported; their raid steps were re-homed to the camp.",
        "The previous quests 700760-700768 are retired: no longer offered, still turn-in-able at the",
        "Timbermaw Gatekeeper so nobody is left holding a dead quest."]),
        rows_sql("quest_template", QUEST_COLS, quest_rows, "REPLACE INTO"),
        "DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700769 AND 700799;\n" +
        rows_sql("quest_template_addon", ["ID", "MaxLevel", "AllowableClasses", "SourceSpellID", "PrevQuestID",
                                          "NextQuestID", "ExclusiveGroup", "BreadcrumbForQuestId",
                                          "RewardMailTemplateID", "RewardMailDelay", "RequiredSkillID",
                                          "RequiredSkillPoints", "RequiredMinRepFaction", "RequiredMaxRepFaction",
                                          "RequiredMinRepValue", "RequiredMaxRepValue", "ProvidedItemCount",
                                          "SpecialFlags"], addon_q_rows),
        "DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 700769 AND 700799;\n" +
        rows_sql("quest_offer_reward", ["ID", "Emote1", "Emote2", "Emote3", "Emote4", "EmoteDelay1", "EmoteDelay2",
                                        "EmoteDelay3", "EmoteDelay4", "RewardText", "VerifiedBuild"], offer_rows),
        "DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 700769 AND 700799;\n" +
        rows_sql("quest_request_items", ["ID", "EmoteOnComplete", "EmoteOnIncomplete", "CompletionText",
                                         "VerifiedBuild"], request_rows),
        "DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 700760 AND 700799;\n" +
        rows_sql("creature_queststarter", ["id", "quest"], starter_rows),
        "DELETE FROM `creature_questender` WHERE `quest` BETWEEN 700769 AND 700799;\n" +
        rows_sql("creature_questender", ["id", "quest"], ender_rows),
        "DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700769 AND 700799;\n" +
        rows_sql("dc_dungeon_quest_mapping", ["quest_id", "dungeon_id", "enabled"], qmap_rows),
        "-- camp quest givers on map 750",
        "DELETE FROM `creature` WHERE `id` BETWEEN 4010201 AND 4010203 AND `guid` BETWEEN 16622020 AND 16622022;\n" +
        rows_sql("creature", ["guid", "id", "map", "zoneId", "areaId", "spawnMask", "phaseMask", "equipment_id",
                              "position_x", "position_y", "position_z", "orientation", "spawntimesecs",
                              "wander_distance", "currentwaypoint", "curhealth", "curmana", "MovementType", "npcflag",
                              "unit_flags", "dynamicflags", "ScriptName", "VerifiedBuild", "CreateObject", "Comment"],
                 camp_rows),
        "-- encounters: 9 per difficulty, bit order == boss data id in timbermaw_hold.h",
        "DELETE FROM `instance_encounters` WHERE `entry` IN (%s);\n" % ", ".join(r[0] for r in enc_rows) +
        rows_sql("instance_encounters", ["entry", "creditType", "creditEntry", "lastEncounterDungeon", "comment"],
                 enc_rows),
        "-- creature_text (the C++ Talk() ids)",
        "DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 4010001 AND 4010299;\n" +
        rows_sql("creature_text", ["CreatureID", "GroupID", "ID", "Text", "Type", "Language", "Probability", "Emote",
                                   "Duration", "Sound", "BroadcastTextId", "TextRange", "comment"], text_rows),
        "-- trash and add AI",
        "DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4010001 AND 4010299;\n" +
        rows_sql("smart_scripts", SMART_COLS, smart_rows),
        "SELECT 'quests (want %d)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `quest_template` WHERE `ID` BETWEEN 700769 AND 700799\n"
        "UNION ALL SELECT 'quest rewards with no item (want 0)', CAST(COUNT(*) AS CHAR) FROM `quest_template` q LEFT JOIN `item_template` i ON i.`entry` = q.`RewardChoiceItemID1` WHERE q.`ID` BETWEEN 700769 AND 700799 AND q.`RewardChoiceItemID1` <> 0 AND i.`entry` IS NULL\n"
        "UNION ALL SELECT 'encounters (want 27)', CAST(COUNT(*) AS CHAR) FROM `instance_encounters` WHERE `creditEntry` BETWEEN 4010001 AND 4010011\n"
        "UNION ALL SELECT 'smart rows (want %d)', CAST(COUNT(*) AS CHAR) FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4010001 AND 4010299;" % (
            len(quest_rows), len(smart_rows)),
    ]
    verify.append(p3.pop())
    write(f3, p3)
    write(os.path.join(HERE, "verify_after_apply.sql"), [
        "-- Run after the three pending files are applied (read-only). Every 'want' should match."] + verify)

    with open(os.path.join(HERE, "item_dbc_rows.json"), "w", encoding="utf-8") as fh:
        json.dump(item_dbc_rows, fh)
    with open(os.path.join(HERE, "generated_report.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("CREATURES\n" + "\n".join(report) + "\n\nITEMS\n" + "\n".join(item_report) + "\n")
    print("wrote", f1, f2, f3)
    print("creatures %d spawns %d waypoints %d gos %d items %d loot %d quests %d smart %d texts %d" % (
        len(template_rows), len(creature_rows), len(wp_rows), len(go_rows), len(item_rows), len(loot_rows),
        len(quest_rows), len(smart_rows), len(text_rows)))


if __name__ == "__main__":
    main()
