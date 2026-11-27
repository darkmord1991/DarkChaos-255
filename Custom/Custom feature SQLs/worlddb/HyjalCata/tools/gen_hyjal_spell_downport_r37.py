#!/usr/bin/env python3
"""
Map 750/751/861 round-37 spell downport -- creature_addon aura-layer prerequisite.

272_ imports the 5,461 per-guid `creature_addon` rows the zone importers never
brought across (auras, stand/anim tier, sheath, emote, visibility distance).
1,063 of those rows carry auras, spanning 125 distinct spell ids -- and 52 of
them are absent from the deployed Spell.dbc.

`ObjectMgr::LoadCreatureAddons` logs "has wrong spell 'N' defined in `auras`
field" and DROPS that aura for every spawn that names it, so this file is a HARD
PREREQUISITE of 272_ -- apply it first, exactly as r27 had to precede 259_.

All 52 resolve in the Cata 4.3.4 Spell.dbc (73,281 rows).  Note the id range is
misleading: 16 of the 52 sit in the WotLK 62000-70000 band (62164, 62804, 65050,
67685, ...).  They are NOT WotLK spells -- Blizzard filled id gaps left in 3.3.5
with new Cata content, so "the id looks like Ulduar" is not evidence the client
already has it.  Verified id-by-id against the deployed DBC, not by range.

  python gen_hyjal_spell_downport_r37.py [outdir]
"""

import struct, csv, os, sys

CATA = "k:/tmp/cata-dbc/"
LOC = "k:/tmp/cata-locale/"
LIVE = "K:/Dark-Chaos/Server/data/dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = REPO + "Custom/CSV DBC/Spell.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r37/"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190

# --- 1. straight Cata downports --------------------------------------------
TARGET = [
    62164, 62804, 62856, 62923, 63558, 64549, 64965, 65050, 65164, 65191,
    65316, 65427, 65432, 65734, 67685, 68277, 70696, 73284, 74093, 74094,
    74127, 75824, 75916, 75965, 76136, 76395, 76431, 77042, 78273, 78710,
    78732, 79428, 79752, 79756, 79841, 80109, 80264, 80611, 82358, 89273,
    89303, 89664, 89842, 93361, 93369, 93397, 94029, 97890, 98613, 98676,
    101078,
    # 94656 "Deathwing Attack Looming" is a CLIENT-ONLY gap: it is already in
    # `spell_dbc` (81_ backfilled Deathwing 3639867's spellclick) but has no row
    # in the deployed Spell.dbc, so the click fires a spell the client has never
    # heard of.  Included here for the CSV half; its SQL row is a determinism
    # check against the live one, not a new insert.
    94656,
]

# --- 2. effect-only orphans (no 4.3.4 Spell.dbc row) ------------------------
HANDMADE = {}

# --- 3. Project Neltharion custom ids ---------------------------------------
NELT_CUSTOM = {}

# 69481 effect 2 is TRANS_DOOR (76) whose EffectMiscValue is a GAMEOBJECT entry,
# not a creature -- 200301 "Impaling Spine", which exists in nelt_world and not
# here.  259_ clones it at +3,600,000 to match the Cata GO band on map 750.
MISC_REMAP = {}
REMAP_EFFECTS = {28, 76, 90, 134}  # SUMMON / TRANS_DOOR / KILL_CREDIT / KILL_CREDIT2
REMAP_AURAS = {56, 78}             # TRANSFORM / MOUNTED

MISCB_REMAP = {}

# Kept so the guard travels with the generator: an effect id >= 165 asserts and
# segfaults the worldserver at boot.  Inert for this round's set.
EFFECT_REMAP = {165: 2}


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


rows, report = [], []
for sid in TARGET:
    if sid not in spell:
        report.append("  [%d] MISSING in Cata Spell.dbc -- SKIPPED" % sid)
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
    notes = []
    for e in range(3):
        if e not in effs.get(sid, {}):
            continue
        er = effs[sid][e]
        eff = i32(ed, ebase, ers, er, 1)
        if eff in EFFECT_REMAP:
            notes.append("eff%d effect %d->%d" % (e, eff, EFFECT_REMAP[eff]))
            eff = EFFECT_REMAP[eff]
        if eff >= TOTAL_SPELL_EFFECTS:
            notes.append("eff%d effect %d out of range -> 0" % (e, i32(ed, ebase, ers, er, 1)))
            eff = 0
        if eff == 2:
            has_dmg = True
        _au = i32(ed, ebase, ers, er, 3)
        aura = _au if _au < TOTAL_AURAS else 0
        misc = i32(ed, ebase, ers, er, 12)
        if (eff in REMAP_EFFECTS or aura in REMAP_AURAS) and misc in MISC_REMAP:
            notes.append("eff%d misc %d->%d" % (e, misc, MISC_REMAP[misc]))
            misc = MISC_REMAP[misc]
        S(70 + e, eff)
        S(73 + e, i32(ed, ebase, ers, er, 9))
        S(76 + e, f32(ed, ebase, ers, er, 17))
        S(79 + e, i32(ed, ebase, ers, er, 5))
        S(82 + e, i32(ed, ebase, ers, er, 11))
        S(85 + e, i32(ed, ebase, ers, er, 22))
        S(88 + e, i32(ed, ebase, ers, er, 23))
        S(91 + e, remap_radius(i32(ed, ebase, ers, er, 15)))
        S(94 + e, aura)
        S(97 + e, i32(ed, ebase, ers, er, 4))
        S(103 + e, i32(ed, ebase, ers, er, 8))
        S(106 + e, i32(ed, ebase, ers, er, 10))
        S(109 + e, misc)
        miscb = i32(ed, ebase, ers, er, 13)
        if eff in REMAP_EFFECTS and miscb in MISCB_REMAP:
            notes.append("eff%d miscB %d->%d" % (e, miscb, MISCB_REMAP[miscb]))
            miscb = MISCB_REMAP[miscb]
        S(112 + e, miscb)
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
    report.append("  [%d] %-42r cata      %s" % (sid, name, ("| " + "; ".join(notes)) if notes else ""))

for sid, (name, attrs, cti, dui, rgi, school, efflist) in NELT_CUSTOM.items():
    col = ["0"] * NCOL

    def S(c, v, col=col):
        col[c - 1] = fnum(v)
    S(1, sid); S(5, attrs); S(27, cti); S(39, dui); S(45, rgi); S(67, -1); S(224, school)
    notes = []
    for e, (eff, aura, base, misc, miscb, ta, tb, rad, amp) in enumerate(efflist):
        if (eff in REMAP_EFFECTS or aura in REMAP_AURAS) and misc in MISC_REMAP:
            notes.append("eff%d misc %d->%d" % (e, misc, MISC_REMAP[misc]))
            misc = MISC_REMAP[misc]
        S(70 + e, eff); S(79 + e, base); S(85 + e, ta); S(88 + e, tb)
        S(91 + e, rad); S(94 + e, aura); S(97 + e, amp)
        S(109 + e, misc); S(112 + e, miscb)
    S(135, name); S(151, NAME_MASK)
    rows.append(col)
    report.append("  [%d] %-42r nelt custom %s" % (sid, name, ("| " + "; ".join(notes)) if notes else ""))

os.makedirs(OUT, exist_ok=True)
csv_path = os.path.join(OUT, "hyjal_r37_spells.csv")
with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(header)
    for row in rows:
        w.writerow(row)

ids = [r[0] for r in rows]
sql_rows = []
for r in rows:
    v = r[0:13] + ['0'] + [r[13]] + ['0'] + r[14:]
    assert len(v) == 234, len(v)
    sql_rows.append("(" + ",".join("'" + x.replace("'", "''") + "'" for x in v) + ")")

sql_path = os.path.join(OUT, "r37_spell_dbc.sql")
with open(sql_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write("-- r24: determinism check only -- 98757 already exists in live spell_dbc.\n")
    f.write("-- Compare these values against the live row before appending the CSV.\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sql_rows) + ";\n")

print("spell rows: %d -> %s\n            -> %s\n" % (len(rows), csv_path, sql_path))
print("\n".join(report))
