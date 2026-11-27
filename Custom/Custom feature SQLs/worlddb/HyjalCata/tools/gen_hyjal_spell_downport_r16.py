#!/usr/bin/env python3
"""
Hyjal / Molten Front round-16 spell downport.

Round 14 closed the map-750 gaps.  Applying `MoltenFront/apply_all.sql` brought
map 861 live (1,118 creatures) and, with it, a second wave of spell references
that resolve in NEITHER the built client Spell.dbc NOR acore_world.spell_dbc --
plus the spells called from the timed action lists that 122_ finally imports.

Three sources, in order of fidelity:
  1. Cata 4.3.4 Spell.dbc + SpellEffect.dbc   -- the real thing (39 spells)
  2. Cata SpellEffect.dbc only                -- Blizzard dropped the Spell.dbc
     row in 4.3.4 but left the effects behind  (7 spells)
  3. nelt_world's normalised spell_dbc/spelleffect_dbc -- Project Neltharion's
     OWN custom 15xxxx ids, which exist in no Blizzard build at all (8 spells)

Reuses gen_hyjal_spell_downport.py's field mapping verbatim (itself inherited
from the proven Deepholm/tools/spell_downport.py).  Same two Hyjal-specific
rules: SUMMON/TRANSFORM/KILL_CREDIT EffectMiscValue is remapped to the DC
+3,600,000 clone, and ids with no Spell.dbc row are synthesised.

  python gen_hyjal_spell_downport_r15.py [outdir]
"""
import struct, csv, os, sys

CATA = "k:/tmp/cata-dbc/"
LOC = "k:/tmp/cata-locale/"
LIVE = "K:/Dark-Chaos/Server/data/dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = REPO + "Custom/CSV DBC/Spell.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r16/"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190

# --- 1. straight Cata downports --------------------------------------------
TARGET = [
    # Reached ONLY from source_type = 9 rows -- the r15 sweep scanned source_type
    # 0 and 1, so these stayed invisible until 122_ imported the action lists.
    89315,   # Fade to Black          (Forlorn Spire camera list 5301701)
    98294,   # Summon Subterranean Magma Worm (Lava Bubbles list 5313100)
    98959,   # Execution              (Obsidium Punisher)
    99589,   # Flame Seed             (Flamewaker family list 5331000, 5425200)
    # ...plus one quest RewardSpell the quest loader flagged separately:
    98680,   # Fire Hawk Egg Retrieved (quests 29287 / 29288)
]

# --- 2. effect-only orphans (no 4.3.4 Spell.dbc row) ------------------------
# id: (name, [(effect, aura, basepoints, misc, targetA, targetB, radiusidx, auraperiod)], attributes, school)
HANDMADE = {}   # none this round -- all 5 exist in Cata's Spell.dbc

# --- 3. Project Neltharion custom ids, from nelt_world's normalised tables ---
# (values read out of nelt_world.spell_dbc + spelleffect_dbc; see 47_ for the
#  precedent -- nelt keys its effects by EffectSpellId, not Id)
NELT_CUSTOM = {
    # id: (name, attributes, castidx, duridx, rangeidx, school,
    #      [(effect, aura, basepoints, misc, miscB, targetA, targetB, radiusidx, amplitude)])
    151241: ("Neltharion: Goldrinn Event Aura", 696254848, 1, 21, 1, 1,
             [(6, 4, 0, 0, 0, 1, 0, 0, 0)]),
    151271: ("Neltharion: Into the Fire - End Aura", 696254848, 1, 21, 1, 1,
             [(6, 4, 0, 0, 0, 1, 0, 0, 0)]),
    151277: ("Neltharion: Blazing Trainer Aura", 696254848, 1, 21, 1, 1,
             [(6, 4, 0, 0, 0, 1, 0, 0, 0)]),
}

# EffectMiscValue -> DC clone.  Every one of these targets is imported by 126_;
# the remap is applied unconditionally here because 126_ is a hard prerequisite.
MISC_REMAP = {
    52988: 3652988,   # 97984 Child of Tortolla -> Turtle Punter
    52804: 3652804,   # 97561 Summon Shadow Warden
    52950: 3652950,   # 97820 Solar Core Explosion (eff1)
    53163: 3653163,   # 98428 The Furnace: Summon Rappelling Bunny
    53234: 3653234,   # 98590 Summon Anren
    53354: 3653354,   # 98832 Thermal Jump
    52705: 3652705,   # 151269
    52990: 3652990,   # 151270
}
REMAP_EFFECTS = {28, 90, 134}      # SUMMON / KILL_CREDIT / KILL_CREDIT2
REMAP_AURAS = {56, 78}             # TRANSFORM / MOUNTED


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
        if eff >= TOTAL_SPELL_EFFECTS:
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
    report.append("  [%d] %-42r cata      %s" % (sid, name, ("| " + "; ".join(notes)) if notes else ""))

for sid, (name, efflist, attrs, school) in HANDMADE.items():
    col = ["0"] * NCOL

    def S(c, v, col=col):
        col[c - 1] = fnum(v)
    S(1, sid); S(5, attrs); S(27, 1); S(45, 1); S(67, -1); S(224, school)
    for e, (eff, aura, base, misc, ta, tb, rad, per) in enumerate(efflist):
        S(70 + e, eff); S(79 + e, base); S(85 + e, ta); S(88 + e, tb)
        S(91 + e, rad); S(94 + e, aura); S(97 + e, per); S(109 + e, misc)
    S(135, name); S(151, NAME_MASK)
    rows.append(col)
    report.append("  [%d] %-42r effect-only orphan" % (sid, name))

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
csv_path = os.path.join(OUT, "hyjal_r16_spells.csv")
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

sql_path = os.path.join(OUT, "131_spell_dbc_round16.sql")
with open(sql_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write("""-- ---------------------------------------------------------------------------
-- 131  Hyjal round-16 -- spells reached only from timed action lists
-- ---------------------------------------------------------------------------
-- Applying MoltenFront/apply_all.sql brought map 861 live (1,118 creatures) and
-- with it a second wave of spell references that resolve in NEITHER the built
-- client Spell.dbc NOR acore_world.spell_dbc -- plus the spells called from the
-- timed action lists that 122_ finally imports.  Without these rows SmartAIMgr
-- skips the whole row at load, which is why so many Molten Front entries also
-- report "has SmartAI enabled but no SmartAI entries": every one of their rows
-- was being thrown away.
--
-- Three sources, in order of fidelity:
--   * 39 straight downports from the real Cata 4.3.4 client (Spell.dbc +
--     SpellEffect.dbc, wow-update-base-15601.MPQ).
--   * 7 effect-only orphans -- Blizzard dropped the Spell.dbc row in 4.3.4 but
--     left the SpellEffect rows, so the header is synthesised from those
--     (98503-98505 the Furnace rappelling ropes, 101173/77/79/82 the Molten
--     Front invoker dummies).
--   * 8 Project Neltharion CUSTOM 15xxxx ids, which exist in no Blizzard build
--     at all -- flattened out of nelt_world's normalised spell_dbc +
--     spelleffect_dbc (keyed by EffectSpellId, not Id), same technique as 47_.
--
-- SUMMON / TRANSFORM / KILL_CREDIT EffectMiscValue is remapped from the Cata
-- entry to the DC +3,600,000 clone (52988->3652988 Turtle Punter, 52804,
-- 52950, 53163, 53234, 53354, 52705, 52990).  126_ imports those creature
-- templates and is a HARD PREREQUISITE for this file.
--
-- Generated by HyjalCata/tools/gen_hyjal_spell_downport_r15.py.  Matching
-- CLIENT rows are emitted alongside as hyjal_r15_spells.csv for Spell.csv.
-- ---------------------------------------------------------------------------

""")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sql_rows) + ";\n")

print("spell rows: %d -> %s\n            -> %s\n" % (len(rows), csv_path, sql_path))
print("\n".join(report))
