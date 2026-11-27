#!/usr/bin/env python3
"""
Round-39 spell downport -- quest reward spells.

`ObjectMgr::LoadQuests` drops a RewardSpell/RewardDisplaySpell whose spell is
absent, so 28 quests have been handing out nothing. 21 of the 26 distinct ids
resolve in the Cata 4.3.4 Spell.dbc and are downported here.

Reachability was checked FIRST (the lesson from the ~2,100 orphan quests): 17 of
the 28 quests have a questgiver, 11 do not. Both sets are included -- see the
TARGET comments -- because it is one generator run either way.

  python gen_hyjal_spell_downport_r39.py [outdir]
"""

import struct, csv, os, sys

CATA = "k:/tmp/cata-dbc/"
LOC = "k:/tmp/cata-locale/"
LIVE = "K:/Dark-Chaos/Server/data/dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = REPO + "Custom/CSV DBC/Spell.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r39/"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190

# --- 1. straight Cata downports --------------------------------------------
TARGET = [
    # Quest reward / display-reward spells. `Quest N has RewardSpell = X but
    # spell X does not exist, quest will not have a spell reward.`
    # REACHABLE quests (a questgiver exists) -- these are the ones that matter:
    65465,    # q13935 Defend the Tree!
    65498,    # q13947 Blastranaar!
    65688,    # q13974 Tweedle's Tiny Package
    76629,    # q13981 They Set Them Up The Bomb!
    69950,    # q14249 Shear Will
    68185,    # q14270 The Keystone Shard
    76479,    # q25621 Field Test: Gnomecorder (RewardSpell AND RewardDisplaySpell)
    77851,    # q25945 We're Here to Do One Thing... (display)
    89755,    # q28044 Touch the Untouchable
    90147,    # q28261 Deceivers In Our Midst
    90133,    # q28364 The Chieftain's Key
    # UNREACHABLE today (no questgiver of any kind) but downported anyway: it is
    # the same generator run, it clears their log lines too, and 268_ showed the
    # relation layer keeps growing -- when a giver appears the reward works.
    62858,    # q13620 To Dinah, at Once!
    64118,    # q13798 Rain of Destruction
    64578,    # q13853 Return Fire
    65716,    # q13982 In a Bind
    67597,    # q14202 Survey the Lakeshore
    74916,    # q25251 Final Confrontation
    77534,    # q25267 Message for Garrosh
    78054,    # q26004 Krom'gar Fortress (display)
    78306,    # q26058 In Defense of Krom'gar Fortress (display)
    89362,    # q28229 Nature and Nurture
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
csv_path = os.path.join(OUT, "hyjal_r39_spells.csv")
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

sql_path = os.path.join(OUT, "r39_spell_dbc.sql")
with open(sql_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write("-- r24: determinism check only -- 98757 already exists in live spell_dbc.\n")
    f.write("-- Compare these values against the live row before appending the CSV.\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sql_rows) + ";\n")

print("spell rows: %d -> %s\n            -> %s\n" % (len(rows), csv_path, sql_path))
print("\n".join(report))
