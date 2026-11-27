#!/usr/bin/env python3
"""Downport the 142 Cata spells map 751's band references but 3.3.5 does not have.

WHY THIS IS A DB CHANGE AND NOT A CLIENT REBUILD
This fork's worldserver loads spells from `acore_world.spell_dbc`, a 234-column
runtime overlay table merged over the file at load (LOAD_DBC -> DBCStorage::LoadFromDB
-> DBCDatabaseLoader::Load). So the server can be taught a spell with SQL alone. The
CLIENT still reads its own Spell.dbc, so tooltips/visuals need the CSV half -- emitted
here as an appendix but NOT applied, since that needs a DBC rebuild + MPQ deploy.

For NPC combat abilities the server half is what matters: without it SmartAIMgr
rejects the action at boot and the creature loses the ability entirely.

WHERE THE 142 COME FROM  (every spell-bearing field, taken from the core, not guessed)
  actions, action_param1 : 11 CAST, 28 REMOVEAURASFROMSPELL, 75 ADD_AURA,
                           85 SELF_CAST, 86 CROSS_CAST, 134 INVOKER_CAST,
                           218 CUSTOM_CAST      (`spell` is field 1 of each struct)
  events,  event_param1  : 8 SPELLHIT, 16 FRIENDLY_MISSING_BUFF, 23 HAS_AURA,
                           24 TARGET_BUFFED
  events,  event_param3  : 13 VICTIM_CASTING    (`targetCasting{repeatMin,repeatMax,spellId}`)
  plus creature_template_spell.Spell, npc_spellclick_spells.spell_id, and the
  space-separated `auras` strings on creature_addon / creature_template_addon.

  ACTION 80 IS NOT A SPELL ACTION -- it is CALL_TIMED_ACTIONLIST and its param1 is an
  action-list id (entry*100). The error log says "Action 80 uses non-existent Spell
  entry 73108" because the message prints the ACTION type while the spell came from
  the row's EVENT. Treating action 80's param1 as a spell puts ids like 410154300 in
  the list, which is how this was caught.

Verified against the live server: of the candidates, everything <= 70846 already
exists; the missing set starts at 70956 and is entirely Cata-era.

TWO CLAMPS THAT PREVENT A BOOT CRASH (inherited from Deepholm/tools/spell_downport.py)
  * effect id >= 165 -> 0   : LoadSpellInfoStore indexes a fixed table; a Cata-only
                              effect id asserts and segfaults the worldserver at boot
  * aura id   >= 317 -> 0   : same class
A clamped spell still loads and its other effects still work; only the Cata-only
effect goes inert. That is the correct trade against not loading at all.

Index fields (CastTimes/Duration/Range/Radius) are remapped Cata->3.3.5 BY VALUE, not
by id, because the two clients renumber them.
"""
import os, struct, csv

CATA = "k:/tmp/cata-dbc/"                 # Spell.dbc, SpellEffect.dbc (build 15601)
LOC = "k:/tmp/cata-locale/"               # Cata index tables
LIVE = "K:/Dark-Chaos/Server/data/dbc/"   # 3.3.5 index tables
ROOT = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = ROOT + "Custom/CSV DBC/Spell.csv"
OUT_SQL = ROOT + "Custom/Custom feature SQLs/worlddb/Plaguelands/88_spell_dbc.sql"
OUT_CSV = "k:/tmp/map751_spells_review.csv"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190

# The 142. Split by where they are referenced so the file documents its own scope.
FROM_SCRIPTS = [
    73108, 73110, 73133, 73134, 73150, 73162, 73167, 73180, 73210, 73304,
    73434, 73442, 73444, 73453, 73523, 73524, 75439, 75967, 76892, 77721,
    78509, 79452, 79732, 79840, 79851, 79853, 79864, 79871, 79884, 79886,
    79890, 79903, 79913, 79914, 79970, 79971, 80146, 80170, 80171, 80382,
    80471, 80472, 80473, 81140, 81167, 81173, 81219, 81705, 81764, 81767,
    82617, 82715, 82797, 82800, 82836, 82841, 83014, 83366, 83486, 83488,
    84282, 84308, 84534, 84535, 84709, 84713, 84873, 85257, 85278, 85280,
    86237, 86817, 87081, 87084, 87104, 87179, 87191, 87228, 87603, 88421,
    88533, 89272, 89582, 89702, 89712, 89932, 90257, 90685, 90686, 91576,
    91683, 91938, 91945, 92072, 93446, 93447, 95002, 95038, 95970, 96433,
    99325, 99356,
]
FROM_AURAS = [
    70956, 73304, 73439, 73440, 73443, 80636, 81464, 83470, 83829, 83847,
    83859, 83988, 84238, 84240, 84386, 84461, 84511, 84684, 84710, 86237,
    86378, 86559, 86802, 86853, 87569, 87969, 88361, 88945, 89097, 89098,
    89159, 89161, 89285, 89286, 92230, 92292, 93451, 93460, 98892, 101059,
    104726, 106283,
]
# Cast by the SmartAI of the 44 creature templates 89_ imports. Only these two are
# absent -- 79721/85681/85690/85691/85710 are already in spell_dbc from 50_/53_.
FROM_NEW_TEMPLATES = [73305, 73309]
# Carried by the 184 items 94_ downports -- recipe "teaches" spells (the 88003-88047
# cooking block), on-equip effects and consumable effects. Without these the recipes
# teach nothing and the core logs "Item (Entry: N) has wrong spellid".
FROM_ITEMS = [
    71354, 79402, 79513, 80169, 80469, 80782, 83176, 83902, 84514, 84516,
    88003, 88004, 88005, 88011, 88012, 88013, 88014, 88016, 88017, 88018,
    88019, 88020, 88021, 88022, 88024, 88025, 88028, 88030, 88031, 88033,
    88034, 88035, 88036, 88037, 88039, 88042, 88044, 88045, 88046, 88047,
    88797, 88990, 89039, 89089, 89145, 89146, 89157, 89158, 89479, 89670,
    89752, 89821, 90283, 90621, 90626, 90628, 90631, 90632, 90633, 90679,
    90976, 91085, 92395, 92396, 92397, 92398, 92643, 93644, 93823, 96133,
    99315, 99500, 99508, 99511, 100052, 100576,
]
# Quest RewardSpell ids the band references. Only these 10 of the 15 missing ones
# exist in the Cata 4.3.4 client -- 89550, 89669, 89781, 94710 and 95818 are absent
# from it entirely (removed before 4.3.4, so cata_world predates its own client) and
# are zeroed by 96_ instead.
FROM_QUEST_REWARDS = [
    83716, 83865, 83935, 88763, 88794, 89457, 90414, 91768, 92229, 99387,
]
# Carried by item 68647 "Dousing Agent", which 96_ builds from nelt_world. Its
# spellid_1 is 96022 -- present in the Cata client, so downported rather than zeroed.
FROM_QUEST_REWARDS = FROM_QUEST_REWARDS + [96022]
TARGET = sorted(set(FROM_SCRIPTS) | set(FROM_AURAS) | set(FROM_NEW_TEMPLATES) | set(FROM_ITEMS) | set(FROM_QUEST_REWARDS))


def load(path):
    with open(path, 'rb') as f:
        d = f.read()
    assert d[:4] == b'WDBC', path
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20 + rc * rs


def i32(d, base, rs, rec, idx): return struct.unpack('<i', d[base + rec * rs + idx * 4: base + rec * rs + idx * 4 + 4])[0]
def f32(d, base, rs, rec, idx): return struct.unpack('<f', d[base + rec * rs + idx * 4: base + rec * rs + idx * 4 + 4])[0]
def u32(d, base, rs, rec, idx): return struct.unpack('<I', d[base + rec * rs + idx * 4: base + rec * rs + idx * 4 + 4])[0]


def cstr(d, strbase, off):
    e = d.index(b'\x00', strbase + off)
    return d[strbase + off:e].decode('utf-8', 'replace')


# ---- index remap (Cata idx -> 3.3.5 idx, matched by VALUE) ----
def idx_values(path, valfield, asfloat=False):
    d, rc, fc, rs, base, _ = load(path)
    return {i32(d, base, rs, r, 0): (f32(d, base, rs, r, valfield) if asfloat else i32(d, base, rs, r, valfield))
            for r in range(rc)}


def make_remap(cata_path, live_path, vf_cata, vf_live, asfloat):
    cv = idx_values(cata_path, vf_cata, asfloat)
    lv = idx_values(live_path, vf_live, asfloat)
    val2idx = {}
    for i, v in sorted(lv.items()):
        val2idx.setdefault(round(v, 2), i)

    def remap(ci):
        if ci == 0:
            return 0
        cvval = cv.get(ci)
        if ci in lv and cvval is not None and abs(lv[ci] - cvval) < 0.05:
            return ci
        if cvval is None:
            return ci if ci in lv else 0
        key = round(cvval, 2)
        if key in val2idx:
            return val2idx[key]
        return min(lv.items(), key=lambda kv: abs(kv[1] - cvval))[0]
    return remap


remap_cast = make_remap(LOC + "SpellCastTimes.dbc", LIVE + "SpellCastTimes.dbc", 1, 1, False)
remap_dur = make_remap(LOC + "SpellDuration.dbc", LIVE + "SpellDuration.dbc", 1, 1, False)
remap_range = make_remap(LOC + "SpellRange.dbc", LIVE + "SpellRange.dbc", 3, 3, True)
remap_radius = make_remap(LOC + "SpellRadius.dbc", LIVE + "SpellRadius.dbc", 1, 1, True)

# ---- parse Cata Spell.dbc + SpellEffect.dbc ----
sd, src, sfc, srs, sbase, sstr = load(CATA + "Spell.dbc")
spell = {}
for r in range(src):
    rid = i32(sd, sbase, srs, r, 0)
    if rid in TARGET:
        spell[rid] = r
ed, erc, efc, ers, ebase, estr = load(CATA + "SpellEffect.dbc")
effs = {}
for r in range(erc):
    sid = i32(ed, ebase, ers, r, 24)
    if sid in TARGET:
        effs.setdefault(sid, {})[i32(ed, ebase, ers, r, 25)] = r

with open(FORK_HEADER, encoding='utf-8') as f:
    header = next(csv.reader(f))
NCOL = len(header)
assert NCOL == 232, f"Spell.csv is {NCOL} cols, expected 232"


def fnum(x):
    if isinstance(x, float):
        return str(int(x)) if x == int(x) else repr(round(x, 6))
    return str(x)


rows, report, missing_src, clamped = [], [], [], []
for sid in TARGET:
    if sid not in spell:
        missing_src.append(sid)
        continue
    r = spell[sid]
    col = ["0"] * NCOL

    def S(c, v, _col=col):
        _col[c - 1] = fnum(v)

    S(1, sid)
    for k in range(8):                                    # attributes 1..8 -> cols 5..12 (UNSIGNED)
        S(5 + k, u32(sd, sbase, srs, r, 1 + k))
    S(27, remap_cast(i32(sd, sbase, srs, r, 12)))
    S(39, remap_dur(i32(sd, sbase, srs, r, 13)))
    S(40, i32(sd, sbase, srs, r, 14))                     # PowerType
    S(45, remap_range(i32(sd, sbase, srs, r, 15)))
    S(46, f32(sd, sbase, srs, r, 16))                     # Speed
    S(67, -1)                                             # EquippedItemClass = none
    school = u32(sd, sbase, srs, r, 25)
    S(224, school)
    has_dmg = False
    for e in range(3):
        if e not in effs.get(sid, {}):
            continue
        er = effs[sid][e]
        eff = i32(ed, ebase, ers, er, 1)
        if eff >= TOTAL_SPELL_EFFECTS:
            clamped.append((sid, 'effect', eff))
            eff = 0
        if eff == 2:
            has_dmg = True
        S(70 + e, eff)
        S(73 + e, i32(ed, ebase, ers, er, 9))             # DieSides
        S(76 + e, f32(ed, ebase, ers, er, 17))            # RealPointsPerLevel
        S(79 + e, i32(ed, ebase, ers, er, 5))             # BasePoints
        S(82 + e, i32(ed, ebase, ers, er, 11))            # Mechanic
        S(85 + e, i32(ed, ebase, ers, er, 22))            # ImplicitTargetA
        S(88 + e, i32(ed, ebase, ers, er, 23))            # ImplicitTargetB
        S(91 + e, remap_radius(i32(ed, ebase, ers, er, 15)))
        _au = i32(ed, ebase, ers, er, 3)
        if _au >= TOTAL_AURAS:
            clamped.append((sid, 'aura', _au))
            _au = 0
        S(94 + e, _au)
        S(97 + e, i32(ed, ebase, ers, er, 4))             # AuraPeriod
        S(103 + e, i32(ed, ebase, ers, er, 8))            # ChainTargets
        S(106 + e, i32(ed, ebase, ers, er, 10))           # ItemType
        S(109 + e, i32(ed, ebase, ers, er, 12))           # MiscValue
        S(112 + e, i32(ed, ebase, ers, er, 13))           # MiscValueB
        S(115 + e, i32(ed, ebase, ers, er, 21))           # TriggerSpell
        S(121 + e, u32(ed, ebase, ers, er, 18))           # ClassMaskA
        S(124 + e, u32(ed, ebase, ers, er, 19))           # ClassMaskB
        S(127 + e, u32(ed, ebase, ers, er, 20))           # ClassMaskC
        S(215 + e, f32(ed, ebase, ers, er, 7))            # ChainAmplitude
    name = cstr(sd, sstr, i32(sd, sbase, srs, r, 21))
    S(135, name)
    S(151, NAME_MASK)
    if has_dmg:
        S(212, 2 if school == 1 else 1)                   # DefenseType
    rows.append(col)
    report.append((sid, name, school, len(effs.get(sid, {}))))

# ---- CSV appendix (client half, not applied here) ----
with open(OUT_CSV, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(header)
    w.writerows(rows)

# ---- spell_dbc SQL (server half) ----
# spell_dbc(234) = csv[0:13] + unk_320_2(0) + ShapeshiftExclude + unk_320_3(0) + csv[14:]
sqlrows, ids = [], []
for rcols in rows:
    v = rcols[0:13] + ['0'] + [rcols[13]] + ['0'] + rcols[14:]
    assert len(v) == 234, len(v)
    ids.append(rcols[0])
    sqlrows.append("(" + ",".join("'" + x.replace("'", "''") + "'" for x in v) + ")")

hdr = f"""-- 88_spell_dbc.sql -- map 751 Lordaeron extension, DB step 27.
--
-- GENERATED by Custom/Documentation/scripts/gen_map751_spell_dbc.py -- do not hand-edit.
-- Source: k:/tmp/cata-dbc/Spell.dbc + SpellEffect.dbc (Cata 4.3.4 build 15601).
--
-- The {len(TARGET)} Cata spells the map-751 band references and 3.3.5 does not have.
-- Clears the largest error class in the boot log: ~120 lines of
--   "SmartAIMgr: Entry N ... uses non-existent Spell entry NNNNN, skipped."
-- and, with them, the 35 "Creature entry (N) has SmartAI enabled but no SmartAI
-- entries" lines -- verified that ZERO band templates actually lack smart_scripts
-- rows, so every one of those was a template whose rows were ALL skipped for a
-- missing spell. Both classes clear together.
--
-- THIS IS A DB CHANGE, NOT A CLIENT REBUILD. This fork's worldserver loads spells
-- from `acore_world.spell_dbc`, a 234-column runtime table merged OVER the file
-- (LOAD_DBC -> DBCStorage::LoadFromDB -> DBCDatabaseLoader::Load), so the server can
-- be taught a spell in SQL alone. Same mechanism 50_/51_/53_/59_ already use.
-- The CLIENT still reads its own Spell.dbc, so cast bars and visuals need the CSV
-- half: k:/tmp/map751_spells_review.csv is generated alongside this file, ready to
-- append to Custom/CSV DBC/Spell.csv at the next DBC rebuild. NOT applied here,
-- because that needs a repack + MPQ deploy and these are NPC abilities -- the damage
-- and the behaviour come from the server.
--
-- TWO CLAMPS KEEP THE WORLDSERVER FROM CRASHING AT BOOT:
--   * effect id >= 165 -> 0, aura id >= 317 -> 0.
--     LoadSpellInfoStore indexes fixed-size tables; a Cata-only id asserts and
--     segfaults during startup. A clamped spell still loads and its other effects
--     still work -- only the Cata-only effect goes inert, which beats the row not
--     loading at all. Clamped in this batch: {len(clamped)}.
--   * SpellCastTimes / SpellDuration / SpellRange / SpellRadius indexes are remapped
--     Cata -> 3.3.5 BY VALUE, not by id -- the two clients renumber those tables, so
--     copying the raw index gives a spell the wrong range or duration.
--
-- Fields not set are left 0 (SpellVisual, SpellIconID, reagents, totems...). That is
-- deliberate: a nonzero index into a table the 3.3.5 client does not have is worse
-- than none.
--
-- {len(rows)} rows.{' NOT FOUND in the Cata source: ' + ','.join(map(str, missing_src)) if missing_src else ''}
"""

os.makedirs(os.path.dirname(OUT_SQL), exist_ok=True)
with open(OUT_SQL, 'w', encoding='utf-8', newline='\n') as f:
    f.write(hdr)
    f.write("\nDELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sqlrows) + ";\n")
    f.write("""
-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'spells added (want %d)' AS what, COUNT(*) AS n
FROM `spell_dbc` WHERE `ID` IN (%s)
UNION ALL SELECT 'band SmartAI spell refs still unresolvable (want 0)', COUNT(*) FROM (
  SELECT DISTINCT spell FROM (
    SELECT `action_param1` AS spell FROM `smart_scripts`
      WHERE `action_type` IN (11,28,75,85,86,134,218) AND `action_param1` > 70000
        AND ((`entryorguid` BETWEEN 4100000 AND 4199999) OR (`entryorguid` BETWEEN 410000000 AND 419999999))
    UNION ALL SELECT `event_param1` FROM `smart_scripts`
      WHERE `event_type` IN (8,16,23,24) AND `event_param1` > 70000
        AND ((`entryorguid` BETWEEN 4100000 AND 4199999) OR (`entryorguid` BETWEEN 410000000 AND 419999999))
    UNION ALL SELECT `event_param3` FROM `smart_scripts`
      WHERE `event_type` = 13 AND `event_param3` > 70000
        AND ((`entryorguid` BETWEEN 4100000 AND 4199999) OR (`entryorguid` BETWEEN 410000000 AND 419999999))
  ) z WHERE NOT EXISTS (SELECT 1 FROM `spell_dbc` d WHERE d.`ID` = z.spell)
) q;

-- must be empty: a spell we added that carries an effect or aura id this core
-- cannot index -- these are what crash the worldserver during startup
SELECT 'PROBLEM: out-of-range effect/aura survived' AS problem, `ID`, `Effect_1`, `Effect_2`, `Effect_3`,
       `EffectAura_1`, `EffectAura_2`, `EffectAura_3`
FROM `spell_dbc` WHERE `ID` IN (%s)
  AND (`Effect_1` >= 165 OR `Effect_2` >= 165 OR `Effect_3` >= 165
    OR `EffectAura_1` >= 317 OR `EffectAura_2` >= 317 OR `EffectAura_3` >= 317);
""" % (len(rows), ",".join(ids), ",".join(ids)))

print(f"spells requested : {len(TARGET)}")
print(f"rows generated   : {len(rows)}  ({NCOL} csv cols -> 234 spell_dbc cols)")
if missing_src:
    print(f"NOT IN CATA SRC  : {missing_src}")
if clamped:
    print(f"clamped          : {len(clamped)}")
    for sid, kind, val in clamped:
        print(f"    {sid:>7} {kind} {val} -> 0")
print(f"\nSQL -> {OUT_SQL}")
print(f"CSV -> {OUT_CSV}")
print("\nsample:")
for sid, name, school, ne in report[:12]:
    print(f"   {sid:>7} {name!r:44s} school={school} effects={ne}")
