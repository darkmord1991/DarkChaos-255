#!/usr/bin/env python3
"""
Hyjal / Plaguelands round-25 spell downport -- SmartAI-row-rescue round.

The 2026-08-06 Errors.log sweep found 35 `smart_scripts` rows on maps 750/751
discarded at load by SmartAIMgr ("uses non-existent Spell entry N, skipped")
across 27 creature templates with ~600 live spawns.  SmartAIMgr drops the whole
ROW, so each one is a silently missing ability -- and where every row of a
template referenced a missing spell, the template also reports "has SmartAI
enabled but no SmartAI entries" (3601824, 3604472, 3636976).

28 spell ids come straight out of those log lines; 77209/97426 are the two the
Arch Druid of Hyjal (3640150) needs before its own 6 rows can be restored.
Trigger closure over EffectTriggerSpell adds 85716 and 74729 -- 32 in total.
All 32 are absent from BOTH the live server Spell.dbc and `spell_dbc`, and all
32 resolve in the real Cata 4.3.4 Spell.dbc (wow-update-base-15601.MPQ).

Reuses gen_hyjal_spell_downport.py's field mapping verbatim.  Same Hyjal rule:
SUMMON EffectMiscValue is remapped to the DC +3,600,000 clone.

  python gen_hyjal_spell_downport_r25.py [outdir]
"""
import struct, csv, os, sys

CATA = "k:/tmp/cata-dbc/"
LOC = "k:/tmp/cata-locale/"
LIVE = "K:/Dark-Chaos/Server/data/dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
FORK_HEADER = REPO + "Custom/CSV DBC/Spell.csv"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r25/"

TOTAL_SPELL_EFFECTS = 165
TOTAL_AURAS = 317
NAME_MASK = 16712190

# --- 1. straight Cata downports --------------------------------------------
TARGET = [
    # --- map 751 (Plaguelands) SmartAI rows -------------------------------
    85713,    # Intoxicating Venom  -- 3601822 Venom Mist Lurker (38 spawns)
    85826,    # Blinding Webs       -- 3601824 Plague Lurker (39) [ALL its rows]
    83701,    # Summon Berserkers   -- 3601852 Araj the Summoner
    81193,    # Unrelenting Anguish -- 3604472 Haunting Vision (12) [ALL rows]
    85873,    # Flow of Gratitude   -- 3608519/20/21/22 blighted set (37)
    78827,    # Bladestorm          -- 3608297 Magronos the Unyielding (10)
    90789,    # Plague Bite         -- 3608598 Frenzied Plaguehound (85)
    79964,    # Exorcism            -- 3609448 Scarlet Praetorian (44)
    79902, 79901,   # Plague Strike / Blood Plague -- 3610826 Lord Darkscythe
    77522,    # Swoop               -- 3611897 Duskwing
    # --- map 750 (Hyjal / Kalimdor-Cata) SmartAI rows ----------------------
    77471, 77806,   # Shadow Shield / Stealth -- 3603770 Bleakheart Shadowstalker
    20671,    # Summon Phantim Illusion -- 3605314 Phantim
    69375,    # Lob Fire            -- 3636972 Grit
    69373,    # Shoot               -- 3636976 Ticker [ALL its rows]
    74723,    # Summon Unbound Flamesparks -- 3638896 Blazebound Elemental (20)
    79823, 78907, 79825,   # Starfall / Starfire / Summon Unstable Mushroom
                           #   -- 3639931 Grove Tender (10)
    74737,    # Leafy Wail          -- 3640066 Wailing Weed (79)
    75072, 74811,   # Inferno Ping / Swipe -- Baron Geddon 3640147,
                    #   Galrond of the Claw 3640148, Telessra 3640149
    77160, 76963,   # Nimbus Bolt / Wild Tornado -- 3641027 Wormwing Screecher (46)
    77508,    # Fireball            -- 3641396 Fiery Tormentor (13)
    77627,    # Summon Fiery Minion -- 3641500 Twilight Scorchlord (92)
    66060,    # Sprint              -- 3702237 Moonstalker Sire (38)
    # --- Arch Druid of Hyjal 3640150: its 6 nelt rows are restored in 258_,
    #     and SmartAIMgr would discard both cast rows without these ---------
    77209,    # Wrath
    97426,    # Regrowth
    # --- EffectTriggerSpell closure (absent from live Spell.dbc too) -------
    85716,    # triggered by 85713 Intoxicating Venom
    74729,    # triggered by 74737 Leafy Wail
    # NOTE: nothing in this set is a "Generic Quest Invisibility" spell -- every
    # Cata Spell.dbc name was read before the list was frozen.  Keep that check:
    # porting one onto a clone makes the NPC invisible to every player.
]

# --- 2. effect-only orphans (no 4.3.4 Spell.dbc row) ------------------------
HANDMADE = {}

# --- 3. Project Neltharion custom ids ---------------------------------------
NELT_CUSTOM = {}

# SUMMON EffectMiscValue -> DC clone.  12898 "Phantim Illusion" is deliberately
# absent: it is a stock vanilla creature that already exists RAW on our side, so
# 20671 keeps pointing at it.  The other four are Cata-only and are cloned at
# +3,600,000 by 258_map750_smartai_missing_spells.sql.
MISC_REMAP = {
    40080: 3640080,   # Unbound Flame Spirit  (74723)
    41153: 3641153,   # Wild Tornado          (76963)
    41501: 3641501,   # Fiery Minion          (77627)
    42835: 3642835,   # Unstable Shroom       (79825)
}
REMAP_EFFECTS = {28, 90, 134}      # SUMMON / KILL_CREDIT / KILL_CREDIT2
REMAP_AURAS = {56, 78}             # TRANSFORM / MOUNTED

# EffectMiscValueB for SUMMON is a SummonProperties.dbc id.  Cata rows 2929 and
# 2974 do not exist in 3.3.5 (204 records), so substitute the structurally
# identical live rows rather than fabricating DBC entries -- matched on
# (Control, Faction, Title, Slot), only the Cata-era Flags differ:
#   cata 2929 = (0,0,0,0, flags 2368) -> live 64 = (0,0,0,0, flags 0)  wild
#   cata 2974 = (1,0,2,0, flags 4614) -> live 61 = (1,0,2,0, flags 2)  guardian
MISCB_REMAP = {2929: 64, 2974: 61}

# Cata renumbered the effect table past 3.3.5's 164.  Effect 165 is the modern
# direct-damage effect: of the three spells that use it at index 0 AND exist in
# our 3.3.5 Spell.dbc, two (36536 'dd10', 36586 'dd1') carry Effect_1 = 2
# SCHOOL_DAMAGE.  Both users here ('Shoot' 69373, 'Lob Fire' 69375) are direct
# attacks, so map it rather than let the >= TOTAL_SPELL_EFFECTS guard zero it
# (which would leave the spell inert).  Anything else >= 165 still gets zeroed --
# an out-of-range effect id asserts and segfaults the worldserver at boot.
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

os.makedirs(OUT, exist_ok=True)
csv_path = os.path.join(OUT, "hyjal_r25_spells.csv")
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

sql_path = os.path.join(OUT, "r25_spell_dbc.sql")
with open(sql_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write("-- r24: determinism check only -- 98757 already exists in live spell_dbc.\n")
    f.write("-- Compare these values against the live row before appending the CSV.\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ",".join(ids) + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(sql_rows) + ";\n")

print("spell rows: %d -> %s\n            -> %s\n" % (len(rows), csv_path, sql_path))
print("\n".join(report))
