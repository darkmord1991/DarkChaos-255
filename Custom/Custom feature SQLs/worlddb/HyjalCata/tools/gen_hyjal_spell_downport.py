#!/usr/bin/env python3
"""
Hyjal (map 750) round-14 spell downport.

Downports the 10 Cata 4.3.4 spells that map-750 content references but that
exist in NEITHER the built client Spell.dbc NOR acore_world.spell_dbc, and
hand-authors the 2 that Blizzard dropped from 4.3.4's Spell.dbc but kept in
SpellEffect.dbc.

Emits, side by side:
  * <out>/hyjal_r14_spells.csv          -- fork Spell.csv rows (232 cols, append to Custom/CSV DBC/Spell.csv)
  * <out>/112_spell_dbc_round14.sql     -- acore_world.spell_dbc rows (234 cols) + spell_target_position

Field mapping is inherited verbatim from the proven
Deepholm/tools/spell_downport.py (Cata Spell.dbc 48 fields + SpellEffect.dbc
27 fields -> 3.3.5 monolithic layout), including the index remaps and the
TOTAL_SPELL_EFFECTS / TOTAL_AURAS clamps that keep LoadSpellInfoStore from
asserting.

Two Hyjal-specific additions over the Deepholm tool:
  1. EffectMiscValue remap for SUMMON effects -- the four summon spells carry
     the *Cata* creature entry, which on DC is the +3,600,000 clone.
  2. ENTRY_OVERRIDES / HANDMADE for the ids with no Cata Spell.dbc row.

Inputs (extract once, forward-slash paths):
  k:/tmp/cata-dbc/Spell.dbc, SpellEffect.dbc   <- Cata Data/wow-update-base-15601.MPQ
  k:/tmp/cata-locale/{SpellCastTimes,SpellDuration,SpellRange,SpellRadius}.dbc
  K:/Dark-Chaos/Server/data/dbc/               <- the live 3.3.5 index tables
"""
import struct, csv, os, sys

CATA = "k:/tmp/cata-dbc/"
LOC = "k:/tmp/cata-locale/"
LIVE = "K:/Dark-Chaos/Server/data/dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = REPO + "Custom/CSV DBC/Spell.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r14/"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190
CLONE_OFFSET = 3600000

# --- what to downport -------------------------------------------------------
# summon spells: the whole Aessina's Miracle / Walking the Dog / Call the Flock
# chains are dead without them (they are what creates the scripted vehicles).
SUMMONS = [74138, 77574, 77577, 97241]
# Molten Front flamegate teleports (Firelands Hatchery / Crucible / Forgeworks
# IN+OUT bunnies 3675004 / 3675015 / 3675019 cast these).
FLAMEGATES = [75667, 76162, 76405, 77662, 77802, 77815]
TARGET = SUMMONS + FLAMEGATES

# SUMMON (28) EffectMiscValue -> DC clone entry.
SUMMON_ENTRY_REMAP = {39659: 3639659, 41406: 3641406, 41459: 3641459, 52597: 3652597}

# Cata teleport destinations are nelt map 1 (Kalimdor) with Hyjal coordinates;
# on DC that geometry lives on map 750.  Values from nelt_world.spell_target_position.
TARGET_POSITIONS = {
    75667: (750, 4553.50, -2575.39, 829.9, 0.0),
    76162: (750, 5021.26, -2024.61, 1149.6, 0.0),
    76405: (750, 5038.86, -2044.54, 1368.7, 0.0),
    77662: (750, 4679.90, -3668.82, 696.9, 0.0),
    77802: (750, 4651.76, -3685.19, 955.6, 0.0),
    77815: (750, 4537.40, -2577.99, 1123.9, 0.0),
    # DC-authored replacements for the two capital portals (see HANDMADE below)
    300600: (0, -8833.38, 628.628, 94.0066, 1.06535),
    300601: (1, 1629.85, -4373.64, 31.5573, 3.69762),
}

# Ids Blizzard removed from 4.3.4's Spell.dbc but whose SpellEffect rows survive
# (both are pure DUMMY markers -- SmartAI on Turtle Punter 3652988 keys off them).
# Authored by hand from the surviving SpellEffect row + the SmartAI usage.
HANDMADE = {
    # id: (name, [(effect, aura, basepoints, misc, targetA, targetB, radiusidx, auraperiod), ...], attributes, school)
    96565: ("Punting Season: Turtle Punt Hit", [(3, 0, 1, 0, 22, 7, 16, 1)], 0x00000180, 1),
    98102: ("And the Meek Shall Inherit Kalimdor: Child Update", [(3, 0, 0, 0, 25, 0, 0, 0)], 0x00000180, 1),
    # DC-authored capital portals.  Cata's own 84505/84506 ("Portal to Stormwind"
    # / "Portal to Orgrimmar", the data0 of GOs 3809080/3809081) are absent from
    # Blizzard's Spell.dbc in every build we have -- confirmed by dense-neighbour
    # check, 84501-84503 and 84507-84511 are all present.  Rather than leave the
    # two Nordrassil portals as permanently broken GoType-22 casters, 121_ points
    # them at these two straight TELEPORT_UNITS spells (EFFECT_0 target 25/17 =
    # the standard "read spell_target_position" shape the flamegates use).
    300600: ("Portal to Stormwind", [(5, 0, 0, 0, 25, 17, 0, 0)], 0x00000100, 1),
    300601: ("Portal to Orgrimmar", [(5, 0, 0, 0, 25, 17, 0, 0)], 0x00000100, 1),
}


def load(path):
    with open(path, 'rb') as f:
        d = f.read()
    assert d[:4] == b'WDBC', path
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20 + rc * rs


def i32(d, b, rs, r, i): return struct.unpack('<i', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]
def u32(d, b, rs, r, i): return struct.unpack('<I', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]
def f32(d, b, rs, r, i): return struct.unpack('<f', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]


def cstr(d, sb, off):
    e = d.index(b'\x00', sb + off)
    return d[sb + off:e].decode('utf-8', 'replace')


# ---- index remap (Cata idx -> 3.3.5 idx, matched by value) -----------------
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
assert NCOL == 232, NCOL


def fnum(x):
    if isinstance(x, float):
        return str(int(x)) if x == int(x) else repr(round(x, 6))
    return str(x)


rows = []
report = []
for sid in TARGET:
    if sid not in spell:
        report.append("  [%d] MISSING in Cata Spell.dbc -- skipped" % sid)
        continue
    r = spell[sid]
    col = ["0"] * NCOL

    def S(c, v, col=col):
        col[c - 1] = fnum(v)

    S(1, sid)
    for k in range(8):
        S(5 + k, u32(sd, sbase, srs, r, 1 + k))
    S(27, remap_cast(i32(sd, sbase, srs, r, 12)))
    S(39, remap_dur(i32(sd, sbase, srs, r, 13)))
    S(40, i32(sd, sbase, srs, r, 14))
    S(45, remap_range(i32(sd, sbase, srs, r, 15)))
    S(46, f32(sd, sbase, srs, r, 16))
    S(67, -1)
    school = u32(sd, sbase, srs, r, 25)
    S(224, school)
    has_dmg = False
    remapped = []
    for e in range(3):
        if e not in effs.get(sid, {}):
            continue
        er = effs[sid][e]
        eff = i32(ed, ebase, ers, er, 1)
        if eff >= TOTAL_SPELL_EFFECTS:
            eff = 0
        if eff == 2:
            has_dmg = True
        misc = i32(ed, ebase, ers, er, 12)
        if eff == 28 and misc in SUMMON_ENTRY_REMAP:      # <-- Hyjal clone remap
            remapped.append("eff%d SUMMON %d->%d" % (e, misc, SUMMON_ENTRY_REMAP[misc]))
            misc = SUMMON_ENTRY_REMAP[misc]
        S(70 + e, eff)
        S(73 + e, i32(ed, ebase, ers, er, 9))
        S(76 + e, f32(ed, ebase, ers, er, 17))
        S(79 + e, i32(ed, ebase, ers, er, 5))
        S(82 + e, i32(ed, ebase, ers, er, 11))
        S(85 + e, i32(ed, ebase, ers, er, 22))
        S(88 + e, i32(ed, ebase, ers, er, 23))
        S(91 + e, remap_radius(i32(ed, ebase, ers, er, 15)))
        _au = i32(ed, ebase, ers, er, 3)
        S(94 + e, _au if _au < TOTAL_AURAS else 0)
        S(97 + e, i32(ed, ebase, ers, er, 4))
        S(103 + e, i32(ed, ebase, ers, er, 8))
        S(106 + e, i32(ed, ebase, ers, er, 10))
        S(109 + e, misc)
        S(112 + e, i32(ed, ebase, ers, er, 13))
        S(115 + e, i32(ed, ebase, ers, er, 21))
        S(121 + e, u32(ed, ebase, ers, er, 18))
        S(124 + e, u32(ed, ebase, ers, er, 19))
        S(127 + e, u32(ed, ebase, ers, er, 20))
        S(215 + e, f32(ed, ebase, ers, er, 7))
    name = cstr(sd, sstr, i32(sd, sbase, srs, r, 21))
    S(135, name)
    S(151, NAME_MASK)
    if has_dmg:
        S(212, 2 if school == 1 else 1)
    rows.append(col)
    report.append("  [%d] %-45r effects=%d %s" % (sid, name, len(effs.get(sid, {})), ("| " + "; ".join(remapped)) if remapped else ""))

# ---- hand-authored ids (no Cata Spell.dbc row) -----------------------------
for sid, (name, efflist, attrs, school) in HANDMADE.items():
    col = ["0"] * NCOL

    def S(c, v, col=col):
        col[c - 1] = fnum(v)
    S(1, sid)
    S(5, attrs)
    S(27, 1)          # cast time index 1 = instant
    S(45, 1)          # range index 1 = self only
    S(67, -1)
    S(224, school)
    for e, (eff, aura, base, misc, ta, tb, rad, per) in enumerate(efflist):
        S(70 + e, eff)
        S(79 + e, base)
        S(85 + e, ta)
        S(88 + e, tb)
        S(91 + e, rad)
        S(94 + e, aura)
        S(97 + e, per)
        S(109 + e, misc)
    S(135, name)
    S(151, NAME_MASK)
    rows.append(col)
    report.append("  [%d] %-45r HAND-AUTHORED (no 4.3.4 Spell.dbc row)" % (sid, name))

os.makedirs(OUT, exist_ok=True)
csv_path = os.path.join(OUT, "hyjal_r14_spells.csv")
with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(header)
    for row in rows:
        w.writerow(row)

# ---- spell_dbc SQL (234 cols = csv[0:13] + unk_320_2 + ShapeshiftExclude + unk_320_3 + csv[14:])
ids = [r[0] for r in rows]
sql_rows = []
for r in rows:
    v = r[0:13] + ['0'] + [r[13]] + ['0'] + r[14:]
    assert len(v) == 234, len(v)
    sql_rows.append("(" + ",".join("'" + x.replace("'", "''") + "'" for x in v) + ")")

sql_path = os.path.join(OUT, "112_spell_dbc_round14.sql")
with open(sql_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write("""-- ---------------------------------------------------------------------------
-- 112  Hyjal round-14 -- server-side spell_dbc for the last 12 missing spells
-- ---------------------------------------------------------------------------
-- Audit (map 750 / Molten Front): every spell id referenced by Hyjal content
-- was diffed against BOTH the built client Spell.dbc (Custom/DBCs/Spell.dbc)
-- and acore_world.spell_dbc.  12 resolved in neither, so the server cannot
-- cast them at all:
--   74138 Summon Spawn of Smolderos      -- quest 25294 "Walking the Dog"
--   77574 Summon Float Vehicle           -- quest chain "Aessina's Miracle"
--   77577 Summon Aessina                 -- ditto (rides seat 2 of the above)
--   97241 Quill of the Bird-Queen        -- quest 29147 "Call the Flock"
--   75667/76162/76405/77662/77802/77815  -- the 6 Molten Front flamegate
--                                           teleports (Hatchery / Crucible /
--                                           Forgeworks IN+OUT)
--   96565/98102                          -- Turtle Punter (3652988) SmartAI
--                                           triggers; Blizzard dropped these
--                                           from 4.3.4's Spell.dbc but left
--                                           their SpellEffect rows, so they
--                                           are hand-authored from those.
--   300600/300601                        -- DC-authored capital-portal teleports
--                                           (see 121_; Cata's 84505/84506 are
--                                           absent from Blizzard's own data).
-- Generated by HyjalCata/tools/gen_hyjal_spell_downport.py off the real Cata
-- 4.3.4 client (wow-update-base-15601.MPQ).  The four SUMMON effects have
-- their EffectMiscValue remapped from the Cata entry to the DC +3,600,000
-- clone (39659->3639659, 41406->3641406, 41459->3641459, 52597->3652597) --
-- without that they would summon nothing.
-- The matching CLIENT rows go into Custom/CSV DBC/Spell.csv (see the .csv
-- this generator emits next to this file) and need a Spell.dbc recompile.
-- ---------------------------------------------------------------------------

""")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sql_rows) + ";\n\n")
    f.write("""-- --- teleport destinations for the 6 flamegate spells -----------------------
-- Their EFFECT_0 is TELEPORT_UNITS with ImplicitTargetB = 17 (TARGET_DEST_DB),
-- which reads spell_target_position.  Coordinates from nelt_world (its map 1 =
-- Kalimdor holds the Cata Hyjal geometry that DC re-hosts on map 750).

""")
    f.write("DELETE FROM `spell_target_position` WHERE `ID` IN (" + ",".join(str(x) for x in sorted(TARGET_POSITIONS)) + ");\n\n")
    f.write("INSERT INTO `spell_target_position` (`ID`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`) VALUES\n")
    f.write(",\n".join("(%d, %d, %s, %s, %s, %s)" % (sid, m, x, y, z, o)
                       for sid, (m, x, y, z, o) in sorted(TARGET_POSITIONS.items())) + ";\n")

print("spell rows: %d -> %s\n            -> %s\n" % (len(rows), csv_path, sql_path))
print("\n".join(report))
