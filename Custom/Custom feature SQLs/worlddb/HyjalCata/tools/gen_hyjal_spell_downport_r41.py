#!/usr/bin/env python3
"""
Round-41 spell downport -- item_template on-use / on-equip spells.

29 boot lines of the form

    Item (Entry: 45044) has wrong (not existing) spell in spellid_1 (62817)

22 items / 23 distinct spell ids. Every one of the 22 items is a Cata
`quest_template.StartItem` (the source item handed out on quest accept) for a
map-750 Ashenvale/Azshara or map-861 Molten Front quest, so the spell IS the
quest mechanic -- ObjectMgr zeroes the SpellId at load, which leaves the item
inert and the quest uncompletable. This is NOT the same class as the bag-family
/ wrong-Map lines in the same log block; those are handled in the SQL file's
sections 3 and 4.

Screened first, exactly as r41 did:
  * all 23 exist in the Cata 4.3.4 Spell.dbc (73,281 rows);
  * NONE exists in stock AC v19 Spell.dbc (49,839 rows), so this is a
    never-downported gap, not a custom-DBC rebuild regression.

*** THE CLOSURE IS 28, NOT 23. ***
Walking EffectTriggerSpell (and re-running the description-token pass that
[[cata-spell-downport-from-client]] mandates) pulls in 5 more ids that are
equally absent:

    63566  Kill Credit                      <- trigger of 63565 Siphon Fel Fire
    64075  Summon Felfire Projectile Bunny  <- trigger of 64074 Throw Accursed Ore
    67914  Summon Mortar bunny              <- trigger of 67923 Target Mortar Barrage
    68411  Absorb Water Elemental           <- trigger of 68413 Spongy!
    69202  Cryomatic 16 Freeze Lens         <- trigger of 69230

Shipping the 23 alone would have left five dangling references -- the item
resolves, the spell it needs does not.

SUMMON / KILL_CREDIT2 EffectMiscValue creature entries, resolved against the
live acore_world:
    33965 Felfire Projectile Bunny  present at the STOCK id  -> no remap
    33736 Fel Fire Bunny            present as 3633736       -> remapped
    35761 Mortar Barrage            absent  -> imported at 3635761 by the SQL
    35762 Arcane Charge             absent  -> imported at 3635762 by the SQL
    36130 Scalding Water Lord       absent  -> imported at 3636130 by the SQL
(35762 must NOT be pointed at stock 23429 "Arcane Charge" -- unrelated Tempest
Keep mob, wrong faction and display.)

CREATE_ITEM EffectItemType 45066 (Bathed Concoction) and 46314 (Bloodcup Braid)
both already exist in item_template -- no item work needed.

Seven of the 28 are DUMMY-only and stay inert until something scripts them;
they are downported anyway so the item casts and the log line clears. Listed in
the SQL file's closing note -- do not read "no error" as "quest works".

  python gen_hyjal_spell_downport_r41.py [outdir]
"""

import struct, csv, os, sys

CATA = "k:/tmp/cata-dbc/"
LOC = "k:/tmp/cata-locale/"
LIVE = "K:/Dark-Chaos/Server/data/dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = REPO + "Custom/CSV DBC/Spell.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r41/"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190

# --- 1. straight Cata downports --------------------------------------------
TARGET = [
    # -- item_template spellid_1 / spellid_2, one line per boot error --------
    62817,    # 45044 Cloak of Cenarius            -- 13626 Respect for the Fallen
    62981,    # 45065 Unbathed Concoction          -- 13642 Bathed in Light
    63565,    # 45478 Reinforced Canister          -- 13730 Playing With Felfire
    64074,    # 45598 Accursed Ore                 -- 13798 Rain of Destruction
    63797,    # 45683 Tainted Blood of the Kaldorei-- 13805 Pierce Their Heart!
    65001,    # 46316 Orc-Hair Braid               -- 13875 Gurtar's Request
    65115,    # 46352 Gift of the Earth            -- 13880 Hot Lava
    65433,    # 46701 Tweedle's Improvised Explosive- 13944 Small Hands, Short Fuse
    65739,    # 46776 Jinx's Goggles               -- 13980 They're Out There!
    67922,    # 49038 Arcane Charge                -- 14250 Renewable Resource
    67923,    # 49042 Artillery Signal
    68283,    # 49132 Fireliminator X-21 spellid_1 -- 14308 When Science Attacks
    69635,    # 49132 Fireliminator X-21 spellid_2
    68413,    # 49168 Enchanted Azshari Sea Sponge -- 14323 Absorbent
    68422,    # 49176 Engorged Azshari Sea Sponge  -- 14324 Full of Hot Water
    68531,    # 49201 Dingy Wizard Hat (on-equip)  -- 14340 Dressed to Impress
    69217,    # 49533 Ironwrought Key (OPEN_LOCK)
    69230,    # 49596 Cryomatic 16                 -- 14261 Ice Cold
    69743,    # 49700 SFG                          -- 14472 In The Face!
    69744,    # 49701 Stealth Field Generator      -- 24452 Profitability Scouting
    91647,    # 64637 Tanrir's Overcharged Totem   -- 28615 Turning the Earth
    97012,    # 68997 Guardian's Staff             -- 29126 The Power of Malorne
    97324,    # 69212 Quill of the Bird-Queen      -- 29148 Wings Aflame
    # -- EffectTriggerSpell closure, equally missing -------------------------
    63566,    # <- 63565   KILL_CREDIT2 33736 -> 3633736
    64075,    # <- 64074   SUMMON 33965 (stock id, no remap)
    67914,    # <- 67923   SUMMON 35761 -> 3635761
    68411,    # <- 68413   DUMMY
    69202,    # <- 69230   APPLY_AURA 4
]

# --- 2. effect-only orphans (no 4.3.4 Spell.dbc row) ------------------------
HANDMADE = {}

# --- 3. Project Neltharion custom ids ---------------------------------------
NELT_CUSTOM = {}

# Cata creature entries -> the ids they actually live at here. 33965 is
# deliberately absent: it is present at its stock WotLK id and must not move.
MISC_REMAP = {
    33736: 3633736,   # Fel Fire Bunny            (already imported)
    35761: 3635761,   # Mortar Barrage            (imported by this round's SQL)
    35762: 3635762,   # Arcane Charge             (imported by this round's SQL)
    36130: 3636130,   # Scalding Water Lord       (imported by this round's SQL)
}
REMAP_EFFECTS = {28, 76, 90, 134}  # SUMMON / TRANS_DOOR / KILL_CREDIT / KILL_CREDIT2
REMAP_AURAS = {56, 78}             # TRANSFORM / MOUNTED

MISCB_REMAP = {}

# Kept so the guard travels with the generator: an effect id >= 165 asserts and
# segfaults the worldserver at boot.  Inert for this round's set (max is 77).
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
csv_path = os.path.join(OUT, "hyjal_r41_spells.csv")
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

sql_path = os.path.join(OUT, "r41_spell_dbc.sql")
with open(sql_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write("-- r41: 28 item on-use/on-equip spells (23 from the boot log + 5 trigger closure).\n")
    f.write("-- Downported verbatim from the Cata 4.3.4 client. See the generator header.\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sql_rows) + ";\n")

print("spell rows: %d -> %s\n            -> %s\n" % (len(rows), csv_path, sql_path))
print("\n".join(report))
