#!/usr/bin/env python3
"""Generate the Jade Forest (map 745) pandaren guard displays + equipment.

The guards (creature 800021 "Panda Bruiser") used to be one display: the stock 3.3.5 Pandaren
Monk critter model scaled x2, unarmed. Pandaren is now a playable race (ChrRaces 22/23, full
CharSections / CharHairGeosets / CharacterFacialHairStyles), so a CreatureDisplayInfoExtra row
with DisplayRaceID 22 composites at runtime exactly like a stock humanoid NPC: fur, face, hair and
beard come from CharSections and the armour from ItemDisplayInfo. BakeName stays empty on purpose -
stock 3.3.5 ships bake-less Extra rows (e.g. 10565/10566 behind displays 15331/15332), so the
client composites them itself.

Emits (idempotent - re-running replaces its own id ranges):
  * rows appended to Custom/CSV DBC/CreatureDisplayInfoExtra.csv and CreatureDisplayInfo.csv
  * the world SQL update (dbc overlays, creature_model_info, template models, equipment, spawns)

Every ItemDisplayInfo id below was probed in the client MPQ chain (models + all texture
components); three shoulders that miss their second texture (113745, 108347, 108367) are excluded.
"""
import argparse
import os
import random

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..', '..'))
CSV_DIR = os.path.join(REPO, 'Custom', 'CSV DBC')

CREATURE_ENTRY = 800021
# creature_template_model has CHECK (Idx <= 3): one entry holds at most 4 displays. The 16 variants
# are therefore spread over 800021 plus three clones of it (identical template, script and gossip),
# and the spawns are dealt round-robin across the four.
CLONE_ENTRIES = [800035, 800036, 800037]
ENTRIES = [CREATURE_ENTRY] + CLONE_ENTRIES
MAX_MODELS_PER_ENTRY = 4
TEMPLATE_COLUMNS = (
    'entry,difficulty_entry_1,difficulty_entry_2,difficulty_entry_3,KillCredit1,KillCredit2,name,subname,'
    'IconName,gossip_menu_id,minlevel,maxlevel,exp,faction,npcflag,speed_walk,speed_run,speed_swim,'
    'speed_flight,detection_range,rank,dmgschool,DamageModifier,BaseAttackTime,RangeAttackTime,BaseVariance,'
    'RangeVariance,unit_class,unit_flags,unit_flags2,dynamicflags,family,type,type_flags,lootid,'
    'pickpocketloot,skinloot,PetSpellDataId,VehicleId,mingold,maxgold,AIName,MovementType,HoverHeight,'
    'HealthModifier,ManaModifier,ArmorModifier,ExperienceModifier,RacialLeader,movementId,RegenHealth,'
    'CreatureImmunitiesId,flags_extra,ScriptName,VerifiedBuild').split(',')
# Every guard spawn on map 745 (all were 800021 when queried 2026-09-26); the spawn-table linter
# wants id AND guid.
SPAWN_GUIDS = [9000113, 9000114, 9000116, 9000117, 9000122, 9000123, 9000124, 9000125, 9000129,
               9000814, 9000815, 9001516, 9001517, 9001526, 9001527, 9001528, 9001530, 9001531,
               9001532, 9001533, 9001534, 9001535, 9001536, 9001537, 9001563]
EXTRA_BASE = 503726     # CreatureDisplayInfoExtra ids (CSV max was 503725)
DISPLAY_BASE = 505151   # CreatureDisplayInfo ids (CSV max was 505150)
MODEL_MALE = 503900     # CreatureModelData: Character\Pandaren\Male\PandarenMale (playable model)
MODEL_FEMALE = 503901
RACE = 22               # DC Pandaren (Alliance id; 23 shares every CharSections row)
DISPLAY_SCALE = 1.1     # creature_template_model.DisplayScale - a touch bigger than a player
# Copied from the working HD pandaren NPC displays (501340 / 501524), per the
# "derive from an existing display on the same skeleton" rule.
BOUNDING_RADIUS = 0.306
COMBAT_REACH = 1.5

# NPCItemDisplay slots: 1 head, 2 shoulder, 3 shirt, 4 chest, 5 belt, 6 legs, 7 feet, 8 wrist,
# 9 hands, 10 tabard, 11 cape. Head is always empty: there are no pandaren helm models, and the
# hair is half the variety anyway.
KITS = {
    #                 shoulder  chest   belt    legs    feet    wrist   hands
    'jade_mail':     (107627, 107625, 113740, 107628, 107451, 107452, 107624),  # Jade Guardian's
    'jade_chain':    (107627, 107448, 107739, 113747, 107623, 107626, 107453),  # Jade Guardian's alt
    'jade_tiger':    (107207, 110166, 110167, 107212, 107211, 107203, 107221),  # Jade Tiger plate
    'tian_tunic':    (715072, 104620, 105128, 104542, 693119, 104548, 104962),  # Tian + Tushui shoulders
    'tian_vest':     (715080, 104554, 105128, 104541, 693118, 104556, 104967),  # Tian + Huojin shoulders
    'tushui':        (715072, 727784, 108344, 715075, 108371, 715077, 108359),  # Tushui + Shado-Pan
}
TABARDS = {
    'none': 0,
    'golden_lotus': 115148,
    'shado_pan': 115151,
    'cloud_serpent': 115147,
    'tushui': 114472,
    'elders': 695902,
}
CLOAK_JADE = 111154  # Jade Harbinger's Cloak

# (sex, kit, tabard, cloak). Customisation is rolled from a fixed seed below so the set is
# reproducible; the uniform is chosen by hand so the guard force reads as one organisation with
# three ranks (plate officers, mail line guards, light monastery wardens).
VARIANTS = [
    (0, 'jade_tiger', 'golden_lotus', True),
    (0, 'jade_tiger', 'none', False),
    (0, 'jade_mail', 'golden_lotus', False),
    (0, 'jade_mail', 'none', True),
    (0, 'jade_chain', 'cloud_serpent', False),
    (0, 'jade_chain', 'none', False),
    (0, 'tian_tunic', 'tushui', False),
    (0, 'tian_vest', 'none', False),
    (0, 'tushui', 'none', True),
    (0, 'jade_mail', 'elders', False),
    (0, 'tian_tunic', 'shado_pan', False),
    (1, 'jade_tiger', 'golden_lotus', False),
    (1, 'jade_mail', 'none', True),
    (1, 'jade_chain', 'cloud_serpent', False),
    (1, 'tian_vest', 'tushui', False),
    (1, 'tushui', 'none', False),
]

# Valid CharSections grids for race 22 (all full grids, verified against CharSections.csv):
#   male:   skin 0-16, face 0-20, hair style 0-21 (colour 0 only), facial 0-98
#   female: skin 0-16, face 0-19, hair style 0-14, hair colour 0-14, facial 0-11
RANGES = {
    0: dict(skin=16, face=20, hair=21, hair_color=0, facial=98),
    1: dict(skin=16, face=19, hair=14, hair_color=14, facial=11),
}

# creature_equip_template rows: (ItemID1, ItemID2). All present in item_template AND client
# Item.dbc, all models/textures present in patch-D.
EQUIPMENT = [
    (234770, 0),      # Pandaren Guard's Halberd
    (84529, 0),       # Bodyguard's Halberd
    (215805, 0),      # Serpentguard Spear
    (215803, 0),      # Dragonguard's Glaive
    (140716, 0),      # Guardian's Oaken Spear
    (97136, 0),       # Pandaren Longstaff
    (97137, 0),       # Pandaren Standard
    (97138, 0),       # Pandaren Spire
    (97139, 0),       # Pandaren Staff
    (77360, 0),       # Tian Monastery Staff
    (77388, 0),       # Pandaren Flamberge
    (77390, 0),       # Pandaren Greatblade
    (77391, 0),       # Pandaren Greatsword
    (74589, 0),       # Jade Hilted Sword
    (80282, 80284),   # Tian Monastery Saber + Tian Monastery Sword
    (80285, 80283),   # Ringed Pandaren Falchion + Tian Monastery Edge
]


def build_rows():
    rng = random.Random(745021)
    used = set()
    extras, displays = [], []
    for i, (sex, kit, tabard, cloak) in enumerate(VARIANTS):
        r = RANGES[sex]
        while True:
            look = (rng.randint(0, r['skin']), rng.randint(0, r['face']), rng.randint(0, r['hair']),
                    rng.randint(0, r['hair_color']), rng.randint(0, r['facial']))
            # keep fur colour distinct within each sex so no two guards look like twins
            if (sex, look[0]) not in used or len(used) >= 17 * 2:
                used.add((sex, look[0]))
                break
        skin, face, hair, hair_color, facial = look
        sh, chest, belt, legs, feet, wrist, hands = KITS[kit]
        items = [0, sh, 0, chest, belt, legs, feet, wrist, hands, TABARDS[tabard],
                 CLOAK_JADE if cloak else 0]
        extra_id = EXTRA_BASE + i
        display_id = DISPLAY_BASE + i
        extras.append([extra_id, RACE, sex, skin, face, hair, hair_color, facial] + items + [0, ''])
        model = MODEL_FEMALE if sex else MODEL_MALE
        displays.append([display_id, model, 0, extra_id, 1, 255, '', '', '', '', 1, 0, 0, 0, 0, 0])
    return extras, displays


def rewrite_csv(path, id_range, new_rows):
    with open(path, 'rb') as f:
        data = f.read()
    text = data.decode('utf-8-sig')
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    lo, hi = id_range
    kept = [lines[0]]
    for ln in lines[1:]:
        first = ln.split(',', 1)[0].strip('"')
        if first.isdigit() and lo <= int(first) <= hi:
            continue
        kept.append(ln)
    kept += [','.join(str(v) for v in row) for row in new_rows]
    with open(path, 'wb') as f:
        f.write(b'\xef\xbb\xbf' + ('\n'.join(kept) + '\n').encode('utf-8'))


def sql_value(v):
    if isinstance(v, str):
        return "''" if v == '' else "'" + v.replace("'", "''") + "'"
    return str(v)


def build_sql(extras, displays):
    assert len(displays) <= len(ENTRIES) * MAX_MODELS_PER_ENTRY, 'more variants than model slots'
    e_lo, e_hi = extras[0][0], extras[-1][0]
    d_lo, d_hi = displays[0][0], displays[-1][0]
    out = []
    w = out.append
    w('-- DC: Jade Forest (map 745) pandaren guards - varied composited displays + weapons.')
    w('-- Generated by Custom/Custom feature SQLs/worlddb/JadeForestGuards/tools/gen_jade_guards.py')
    w(f'-- "Panda Bruiser" {CREATURE_ENTRY} + clones {", ".join(map(str, CLONE_ENTRIES))}: {len(displays)} '
      f'displays (was 1 critter model), {len(EQUIPMENT)} random weapon sets. Idempotent - safe to re-run.')
    w('-- The matching client DBC rows are in Custom/CSV DBC (CreatureDisplayInfo, CreatureDisplayInfoExtra).')
    w('')
    w('-- Server-side DBC overlay rows')
    w(f'DELETE FROM `creaturedisplayinfoextra_dbc` WHERE `ID` BETWEEN {e_lo} AND {e_hi};')
    w('INSERT INTO `creaturedisplayinfoextra_dbc` (`ID`, `DisplayRaceID`, `DisplaySexID`, `SkinID`, `FaceID`, '
      '`HairStyleID`, `HairColorID`, `FacialHairID`, `NPCItemDisplay1`, `NPCItemDisplay2`, `NPCItemDisplay3`, '
      '`NPCItemDisplay4`, `NPCItemDisplay5`, `NPCItemDisplay6`, `NPCItemDisplay7`, `NPCItemDisplay8`, '
      '`NPCItemDisplay9`, `NPCItemDisplay10`, `NPCItemDisplay11`, `Flags`, `BakeName`) VALUES')
    w(',\n'.join('(' + ', '.join(sql_value(v) for v in row) + ')' for row in extras) + ';')
    w('')
    w(f'DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` BETWEEN {d_lo} AND {d_hi};')
    w('INSERT INTO `creaturedisplayinfo_dbc` (`ID`, `ModelID`, `SoundID`, `ExtendedDisplayInfoID`, '
      '`CreatureModelScale`, `CreatureModelAlpha`, `TextureVariation_1`, `TextureVariation_2`, '
      '`TextureVariation_3`, `PortraitTextureName`, `BloodLevel`, `BloodID`, `NPCSoundID`, `ParticleColorID`, '
      '`CreatureGeosetData`, `ObjectEffectPackageID`) VALUES')
    w(',\n'.join('(' + ', '.join(sql_value(v) for v in row) + ')' for row in displays) + ';')
    w('')
    w('-- creature_model_info (without it the spawn refuses to load)')
    w(f'DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN {d_lo} AND {d_hi};')
    w('INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, '
      '`DisplayID_Other_Gender`, `VerifiedBuild`) VALUES')
    w(',\n'.join(f'({d[0]}, {BOUNDING_RADIUS}, {COMBAT_REACH}, {e[2]}, 0, 0)'
                 for d, e in zip(displays, extras)) + ';')
    w('')
    entries_sql = ', '.join(str(e) for e in ENTRIES)
    w('-- Clones of 800021 (creature_template_model caps an entry at 4 displays)')
    cols = ', '.join(f'`{c}`' for c in TEMPLATE_COLUMNS)
    sel = ', '.join('`c`.`e`' if c == 'entry' else f'`t`.`{c}`' for c in TEMPLATE_COLUMNS)
    clone_list = ' UNION ALL '.join(f'SELECT {e} AS `e`' for e in CLONE_ENTRIES)
    w('-- Intended linter flag ("No DELETE before INSERT"): creature_template may not be DELETEd, so this')
    w('-- INSERT is made idempotent with NOT EXISTS instead.')
    w(f'INSERT INTO `creature_template` ({cols})')
    w(f'SELECT {sel} FROM `creature_template` `t` JOIN ({clone_list}) `c`')
    w(f'WHERE `t`.`entry` = {CREATURE_ENTRY} AND NOT EXISTS '
      f'(SELECT 1 FROM `creature_template` `x` WHERE `x`.`entry` = `c`.`e`);')
    w('')
    w(f'-- Display pools: {MAX_MODELS_PER_ENTRY} variants per entry, every variant equally likely. Variant '
      'k goes to entry k % 4, so each entry mixes plate, mail, light and female guards.')
    w(f'DELETE FROM `creature_template_model` WHERE `CreatureID` IN ({entries_sql});')
    w('INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, '
      '`Probability`, `VerifiedBuild`) VALUES')
    model_rows = [f'({ENTRIES[i % len(ENTRIES)]}, {i // len(ENTRIES)}, {d[0]}, {DISPLAY_SCALE}, 1, 0)'
                  for i, d in enumerate(displays)]
    w(',\n'.join(sorted(model_rows, key=lambda r: (int(r[1:7]), int(r.split(', ')[1])))) + ';')
    w('')
    w('-- Weapons: every entry gets all sets, picked at random per spawn (creature.equipment_id = -1)')
    w(f'DELETE FROM `creature_equip_template` WHERE `CreatureID` IN ({entries_sql});')
    w('INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, '
      '`VerifiedBuild`) VALUES')
    w(',\n'.join(f'({e}, {i}, {a}, {b}, 0, 0)' for e in ENTRIES for i, (a, b) in enumerate(EQUIPMENT, 1)) + ';')
    w('')
    w('-- Deal the spawns round-robin across the four entries, then give all of them random weapons')
    for k, entry in enumerate(ENTRIES):
        guids = SPAWN_GUIDS[k::len(ENTRIES)]
        w(f'UPDATE `creature` SET `id` = {entry} WHERE `id` IN ({entries_sql}) AND `guid` IN '
          f'({", ".join(str(g) for g in guids)});')
    w(f'UPDATE `creature` SET `equipment_id` = -1 WHERE `id` IN ({entries_sql}) AND `guid` IN (')
    w(',\n'.join(', '.join(str(g) for g in SPAWN_GUIDS[i:i + 10]) for i in range(0, len(SPAWN_GUIDS), 10)) + ');')
    return '\n'.join(out) + '\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sql', required=True, help='SQL file to write (pending_db_world/rev_*.sql)')
    args = ap.parse_args()
    extras, displays = build_rows()
    rewrite_csv(os.path.join(CSV_DIR, 'CreatureDisplayInfoExtra.csv'),
                (EXTRA_BASE, EXTRA_BASE + len(VARIANTS) - 1), extras)
    rewrite_csv(os.path.join(CSV_DIR, 'CreatureDisplayInfo.csv'),
                (DISPLAY_BASE, DISPLAY_BASE + len(VARIANTS) - 1), displays)
    with open(args.sql, 'w', newline='\n', encoding='utf-8') as f:
        f.write(build_sql(extras, displays))
    for e, d in zip(extras, displays):
        print(f'display {d[0]} extra {e[0]} sex {e[2]} skin {e[3]} face {e[4]} hair {e[5]}/{e[6]} '
              f'facial {e[7]} items {e[8:19]}')


if __name__ == '__main__':
    main()
