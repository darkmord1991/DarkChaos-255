#!/usr/bin/env python3
r"""
gen_races28to31_racials.py - author the racial spells of races 28-31 for this fork.

Drakkari Troll 28, Void Elf 29, Lightforged Draenei 30, Mag'har Orc 31. Same shape as
../../Tier1Reskins/tools/gen_darkiron_racials.py. Retail spell ids and values come from the 9.2.7
client DB2s (skill lines 2421, 2423, 2598; decode with db2-decode-loose.js, the 12.x Spell tables are
TACT-encrypted). Design and every deviation from retail: ../00_RACIALS.md. Emits:

  1. races28to31_racials.csv (232-col Spell CSV rows) next to this script
  2. Custom/DBCs/Spell.dbc updated via spell-dbc-append.py - NEVER csv2wdbc, this fork's Spell.dbc
     is the 234-field layout
  3. the same rows appended to Custom/CSV DBC/Spell.csv
  4. the racial icon rows appended to Custom/DBCs/SpellIcon.dbc
  5. the 13 retail icons in Custom/Client patches needed/Interface/Icons/, hasMips rewritten to 0
  6. ../10_spell_dbc.sql, the server overlay rows

Backups are .pre-races28to31.bak beside each file. Refuses to run twice.

Usage (--icons is a folder holding the retail BLPs, found by file name in any subfolder):
    node casc-extract.js get --install "I:/World of Warcraft" --id <fdid> --out <dir>/<fdid>.blp
    python gen_races28to31_racials.py --icons <dir>

Templates: Blood Fury 20572 (visible racial self buff, off the GCD), Arcane Affinity 28877
(passive), Engineering Specialization 20593 (racial skill bonus), Berserking 26297.

Verified constants (SharedDefines.h, SpellAuraDefines.h, SpellMgr.h)
  effects  SCHOOL_DAMAGE=2 DUMMY=3 APPLY_AURA=6 HEAL=10 TRANS_DOOR=50 SUMMON_OBJECT_SLOT4=107
  auras    DUMMY=4 PROC_TRIGGER_SPELL=42 MOD_DAMAGE_PERCENT_DONE=79 MOD_DAMAGE_PERCENT_TAKEN=87
           MOD_SKILL_TALENT=98 MOD_INCREASE_HEALTH_PERCENT=133 MOD_HEALING_DONE_PERCENT=136
           REDUCE_PUSHBACK=149 MOD_MOUNTED_SPEED_NOT_STACK=172 MELEE_SLOW=193
           MOD_FLIGHT_SPEED_MOUNTED_NOT_STACKING=211 MOD_AURA_DURATION_BY_DISPEL=245 MOD_CRIT_PCT=290
  targets  CASTER=1 UNIT_SRC_AREA_ENEMY=15 UNIT_DEST_AREA_ENEMY=16 SRC_CASTER=22
           UNIT_SRC_AREA_ALLY=30 DEST_CASTER_SUMMON=32 DEST_CASTER_FRONT=47 DEST_DEST=87
  indices  duration 8=15s 29=12s 32=6s 4=2min; radius 8=5y 14=8y 15=3y 10=30y;
           range 1=self 5=40y 13=50000y; cast 1=instant 5=2s
  masks    school holy=2 frost=16 shadow=32 arcane=64 all=127; dispel curse=2 disease=3 poison=4
A spell's effect value is BasePoints + DieSides, so bp=9 die=1 yields 10.

Slot 4 for the rift: effects 104-106 are the traps and Demonic Circle, nothing uses 107, so a
warlock's circle and a hunter's traps survive a Spatial Rift. Effect and aura ids at or above
165 / 317 assert at server boot, and retail's 179, 332, 382 and 447 are all past that, which is why
those racials are rebuilt rather than copied. The gate below refuses any such row.
"""
import argparse
import csv
import io
import os
import re
import shutil
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
SPELL_CSV = os.path.join(REPO, "Custom", "CSV DBC", "Spell.csv")
SPELL_DBC = os.path.join(REPO, "Custom", "DBCs", "Spell.dbc")
ICON_DBC = os.path.join(REPO, "Custom", "DBCs", "SpellIcon.dbc")
ICON_STAGE = os.path.join(REPO, "Custom", "Client patches needed", "Interface", "Icons")
APPEND = r"K:\Dark-Chaos\wow.export-main\tools\spell-dbc-append.py"
WORGOBLIN_10 = os.path.join(HERE, "..", "..", "Worgoblin", "10_spell_dbc.sql")
OUT_CSV = os.path.join(HERE, "races28to31_racials.csv")
OUT_SQL = os.path.join(HERE, "..", "10_spell_dbc.sql")
BAK = ".pre-races28to31.bak"

TEMPLATES = {"20572": "buff", "28877": "passive", "20593": "skill", "26297": "berserking"}

# key: (SpellIcon id, name in the client, retail file name)
ICONS = {
    "rift":      (517346, "Ability_Racial_SpatialRift",       "ability_racial_spatialrift"),
    "entropic":  (517347, "Ability_Racial_EntropicEmbrace",   "ability_racial_entropicembrace"),
    "calm":      (517348, "Ability_Racial_PreturnaturalCalm", "ability_racial_preturnaturalcalm"),
    "chill":     (517349, "Ability_Racial_ChillOfNight",      "ability_racial_chillofnight"),
    "judgment":  (517350, "Ability_Racial_OrbitalStrike",     "ability_racial_orbitalstrike"),
    "reckoning": (517351, "Ability_Racial_FinalVerdict",      "ability_racial_finalverdict"),
    "holy":      (517352, "Ability_Racial_HolyResistance",    "ability_racial_holyresistance"),
    "forge":     (517353, "Ability_Racial_ForgeOfLight",      "ability_racial_forgeoflight"),
    "demonbane": (517354, "Ability_Racial_Demonbane",         "ability_racial_demonbane"),
    "ancestral": (517355, "Ability_Racial_AncestralCall",     "ability_racial_ancestralcall"),
    "skies":     (517356, "Ability_Racial_OpenSkies",         "ability_racial_openskies"),
    "vigor":     (517357, "Ability_Racial_SympatheticVigor",  "ability_racial_sympatheticvigor"),
    "savage":    (517358, "Ability_Racial_PureBlood",         "ability_racial_pureblood"),
}
ICON_BERSERKING = 1661
ICON_FROST = 133

ENTROPIC_PROC_MASK = 0x14154   # melee, ranged and spell hits, harmful and helpful
OBJECT_DEMONIC_CIRCLE = 191083  # the rift's look; Generic type, nothing can click it
OBJECT_FORGE = 1685
OBJECT_ANVIL = 1684


def stage_icons(src):
    found = {}
    for d, _, files in os.walk(src):
        for f in files:
            found[f.lower()] = os.path.join(d, f)
    os.makedirs(ICON_STAGE, exist_ok=True)
    for _, name, retail in ICONS.values():
        p = found.get(retail + ".blp")
        if not p:
            raise SystemExit("icon missing from --icons: %s" % retail)
        b = bytearray(open(p, "rb").read())
        if b[:4] != b"BLP2" or b[8] != 2:
            raise SystemExit("not a DXT BLP2: %s" % p)
        b[11] = 0                  # retail writes 16; 0 is what the shipped racial icons carry
        open(os.path.join(ICON_STAGE, name + ".blp"), "wb").write(b)
    print("staged %d icons in %s" % (len(ICONS), ICON_STAGE))


def append_spell_icons(path):
    """Append ICONS to a 2-field SpellIcon.dbc in place (backup alongside). Refuses on id clashes."""
    b = open(path, "rb").read()
    magic, n, f, rs, ss = struct.unpack_from("<4s4I", b, 0)
    assert magic == b"WDBC" and f == 2 and rs == 8, (magic, f, rs)
    recs = [struct.unpack_from("<II", b, 20 + i * rs) for i in range(n)]
    strings = bytearray(b[20 + n * rs:20 + n * rs + ss])
    have = {r[0] for r in recs}
    new = sorted((v[0], "Interface\\Icons\\" + v[1]) for v in ICONS.values())
    clash = [i for i, _ in new if i in have]
    if clash:
        raise SystemExit("REFUSING: SpellIcon ids already used: %s" % clash)
    for rid, name in new:
        off = len(strings)
        strings += name.encode("ascii") + b"\0"
        recs.append((rid, off))
    out = struct.pack("<4s4I", b"WDBC", len(recs), 2, 8, len(strings))
    out += b"".join(struct.pack("<II", *r) for r in recs) + bytes(strings)
    bak = path + BAK
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(path, bak)
    open(path, "wb").write(out)
    print("SpellIcon.dbc: +%d rows (%d -> %d)" % (len(new), n, len(recs)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icons", required=True, help="folder holding the retail icon BLPs")
    a = ap.parse_args()

    with open(SPELL_CSV, encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f)
        hdr = next(rd)
        ix = {n: i for i, n in enumerate(hdr)}
        tpl, all_ids = {}, set()
        for r in rd:
            all_ids.add(int(r[0]))
            if r[0] in TEMPLATES:
                tpl.setdefault(TEMPLATES[r[0]], r)
    assert len(hdr) == 232, "expected the 232-column Spell CSV, got %d" % len(hdr)
    missing = set(TEMPLATES.values()) - set(tpl)
    if missing:
        raise SystemExit("template spells missing from Spell.csv: %s" % sorted(missing))

    loc_cols = [c for c in hdr if re.match(
        r"(Name|NameSubtext|Description|AuraDescription)_Lang_(?!Mask)", c)]
    reagent_cols = [c for c in hdr if c.startswith(("Reagent_", "ReagentCount_"))]

    def clone(base, slots=(1, 2, 3), **over):
        over.setdefault("SpellVisualID_1", 0)
        for c in hdr:                        # every per-effect column the caller did not set
            for s in slots:
                if c.endswith("_%d" % s) and c.startswith(("Effect", "ImplicitTarget")):
                    over.setdefault(c, 0)
        r = list(tpl[base])
        for c in loc_cols:
            r[ix[c]] = ""
        for c in reagent_cols:
            r[ix[c]] = "0"
        for k, v in over.items():
            r[ix[k]] = str(v)
        return r

    def text(sid, name, desc, aura=None, icon=None, **kw):
        kw.update(ID=sid, Name_Lang_enUS=name, Description_Lang_enUS=desc,
                  AuraDescription_Lang_enUS=desc if aura is None else aura)
        kw["SpellIconID"] = ICONS[icon][0] if icon in ICONS else icon
        return kw

    def active(**kw):
        kw.setdefault("Category", 0)
        kw.setdefault("CategoryRecoveryTime", 0)
        kw.setdefault("RecoveryTime", 0)
        kw.setdefault("StartRecoveryCategory", 0)
        kw.setdefault("StartRecoveryTime", 0)
        kw.setdefault("CastingTimeIndex", 1)
        kw.setdefault("DurationIndex", 0)
        kw.setdefault("RangeIndex", 1)
        kw.setdefault("PowerType", 0)
        kw.setdefault("ManaCost", 0)
        kw.setdefault("ManaCostPct", 0)
        kw.setdefault("Mechanic", 0)
        kw.setdefault("DispelType", 0)
        kw.setdefault("SchoolMask", 1)
        kw.setdefault("PreventionType", 0)
        return kw

    rows = []

    # ---- Void Elf 29 ----
    rows.append(clone("passive", **text(
        255668, "Chill of Night", "Reduces Shadow and Arcane damage taken by 1%.", icon="chill",
        Effect_1=6, EffectAura_1=87, EffectMiscValue_1=96, ImplicitTargetA_1=1,
        EffectBasePoints_1=-2, EffectDieSides_1=1)))
    rows.append(clone("passive", **text(
        255670, "Preternatural Calm", "Your spell casts are not delayed by taking damage.", icon="calm",
        Effect_1=6, EffectAura_1=149, ImplicitTargetA_1=1, EffectBasePoints_1=99, EffectDieSides_1=1)))
    rows.append(clone("passive", **text(
        255669, "Entropic Embrace",
        "Your abilities have a chance to empower you with the essence of the Void, increasing your "
        "damage and healing by $256374s1% for $256374d.", icon="entropic",
        Effect_1=6, EffectAura_1=42, ImplicitTargetA_1=1, EffectTriggerSpell_1=256374,
        ProcTypeMask=ENTROPIC_PROC_MASK, ProcChance=5)))
    rows.append(clone("buff", **active(**text(
        256374, "Entropic Embrace", "Damage and healing increased by $s1%.", icon="entropic",
        aura="Damage and healing increased by $w1%.", DurationIndex=29, SchoolMask=32,
        Effect_1=6, EffectAura_1=79, EffectMiscValue_1=127, ImplicitTargetA_1=1,
        EffectBasePoints_1=4, EffectDieSides_1=1,
        Effect_2=6, EffectAura_2=136, ImplicitTargetA_2=1, EffectBasePoints_2=4, EffectDieSides_2=1))))
    rows.append(clone("buff", **active(**text(
        256948, "Spatial Rift",
        "Tear a rift in space up to 30 yards ahead of you. Use Spatial Rift: Teleport within $d to "
        "step through it.", icon="rift", aura="A rift in space is open.",
        RecoveryTime=180000, DurationIndex=32, SpellVisualID_1=10677,
        Effect_1=6, EffectAura_1=4, ImplicitTargetA_1=1,
        Effect_2=107, EffectMiscValue_2=OBJECT_DEMONIC_CIRCLE, ImplicitTargetA_2=47,
        EffectRadiusIndex_2=10))))
    rows.append(clone("buff", **active(**text(
        257040, "Spatial Rift: Teleport",
        "Step through your Spatial Rift, teleporting you to it.", icon="rift", aura="",
        CasterAuraSpell=256948, SpellVisualID_1=10694, Effect_1=3, ImplicitTargetA_1=1))))

    # ---- Lightforged Draenei 30 ----
    rows.append(clone("passive", **text(
        255651, "Holy Resistance", "Reduces Holy damage taken by 1%.", icon="holy",
        Effect_1=6, EffectAura_1=87, EffectMiscValue_1=2, ImplicitTargetA_1=1,
        EffectBasePoints_1=-2, EffectDieSides_1=1)))
    rows.append(clone("skill", **text(
        255650, "Forge of Light", "Increases your Blacksmithing skill by $s1.", icon="forge",
        Effect_1=6, EffectAura_1=98, EffectMiscValue_1=164, ImplicitTargetA_1=1,
        EffectBasePoints_1=9, EffectDieSides_1=1)))
    rows.append(clone("buff", **active(**text(
        259930, "Forge of Light", "Summon a forge and an anvil for $d.", icon="forge", aura="",
        CastingTimeIndex=5, DurationIndex=4, RecoveryTime=900000, SchoolMask=2,
        StartRecoveryCategory=133, StartRecoveryTime=1500,
        Effect_1=50, EffectMiscValue_1=OBJECT_FORGE, ImplicitTargetA_1=32,
        Effect_2=50, EffectMiscValue_2=OBJECT_ANVIL, ImplicitTargetA_2=47, EffectRadiusIndex_2=15))))
    rows.append(clone("buff", **active(**text(
        255647, "Light's Judgment",
        "Call down a strike of Holy energy, dealing Holy damage to enemies within 5 yards after 3 sec.",
        icon="judgment", aura="", RecoveryTime=150000, RangeIndex=5, SchoolMask=2, Targets=64,
        StartRecoveryCategory=133, StartRecoveryTime=1500, PreventionType=1,
        Effect_1=3, ImplicitTargetA_1=87, EffectRadiusIndex_1=8))))
    rows.append(clone("buff", **active(**text(
        256893, "Light's Judgment", "Holy damage to enemies within 5 yards.", icon="judgment", aura="",
        RangeIndex=13, SchoolMask=2, Targets=64, SpellVisualID_1=126,
        Effect_1=2, ImplicitTargetA_1=16, EffectRadiusIndex_1=8,
        EffectBasePoints_1=0, EffectDieSides_1=1))))
    rows.append(clone("passive", **text(
        255652, "Light's Reckoning",
        "Erupt with Light upon death, dealing Holy damage to enemies within 8 yards and healing "
        "nearby allies.", icon="reckoning",
        Effect_1=6, EffectAura_1=4, ImplicitTargetA_1=1)))
    burst = clone("buff", **active(**text(
        256896, "Light's Reckoning", "Holy damage to enemies and healing to allies within 8 yards.",
        icon="reckoning", aura="", SchoolMask=2, SpellVisualID_1=3643,
        Effect_1=2, ImplicitTargetA_1=22, ImplicitTargetB_1=15, EffectRadiusIndex_1=14,
        EffectBasePoints_1=0, EffectDieSides_1=1,
        Effect_2=10, ImplicitTargetA_2=22, ImplicitTargetB_2=30, EffectRadiusIndex_2=14,
        EffectBasePoints_2=0, EffectDieSides_2=1)))
    burst[ix["Attributes"]] = str(int(burst[ix["Attributes"]]) | 0x00800000)  # ALLOW_CAST_WHILE_DEAD
    rows.append(burst)
    rows.append(clone("passive", **text(
        255653, "Demonbane", "Experience gained from killing demons increased by $s1%.", icon="demonbane",
        Effect_1=6, EffectAura_1=4, ImplicitTargetA_1=1, EffectBasePoints_1=19, EffectDieSides_1=1)))

    # ---- Mag'har Orc 31 ----
    rows.append(clone("passive", **text(
        273216, "Open Skies", "Mounted speed increased by $s1%.", icon="skies",
        Effect_1=6, EffectAura_1=172, ImplicitTargetA_1=1, EffectBasePoints_1=9, EffectDieSides_1=1,
        Effect_2=6, EffectAura_2=211, ImplicitTargetA_2=1, EffectBasePoints_2=9, EffectDieSides_2=1)))
    rows.append(clone("passive", **text(
        273217, "Sympathetic Vigor", "Increases pet health by $s1%.", icon="vigor",
        Effect_1=6, EffectAura_1=4, ImplicitTargetA_1=1, EffectBasePoints_1=9, EffectDieSides_1=1)))
    rows.append(clone("passive", **text(
        273218, "Sympathetic Vigor", "Health increased by $s1%.", icon="vigor",
        Effect_1=6, EffectAura_1=133, ImplicitTargetA_1=1, EffectBasePoints_1=9, EffectDieSides_1=1)))
    rows.append(clone("passive", **text(
        273220, "Savage Blood",
        "Reduces the duration of Poison, Disease and Curse effects on you by 10%.", icon="savage",
        Effect_1=6, EffectAura_1=245, EffectMiscValue_1=4, ImplicitTargetA_1=1,
        EffectBasePoints_1=-11, EffectDieSides_1=1,
        Effect_2=6, EffectAura_2=245, EffectMiscValue_2=3, ImplicitTargetA_2=1,
        EffectBasePoints_2=-11, EffectDieSides_2=1,
        Effect_3=6, EffectAura_3=245, EffectMiscValue_3=2, ImplicitTargetA_3=1,
        EffectBasePoints_3=-11, EffectDieSides_3=1)))
    rows.append(clone("buff", **active(**text(
        274738, "Ancestral Call",
        "Invoke the spirits of your ancestors, granting you one of four blessings at random for 15 sec.",
        icon="ancestral", aura="", RecoveryTime=120000, Effect_1=3, ImplicitTargetA_1=1))))
    blessing = "Invoke the spirits of your ancestors, granting you their power."
    rows.append(clone("buff", **active(**text(
        274739, "Rictus of the Laughing Skull", blessing, icon="ancestral",
        aura="Critical strike chance increased by $w1%.", DurationIndex=8, SpellVisualID_1=47,
        Effect_1=6, EffectAura_1=290, ImplicitTargetA_1=1, EffectBasePoints_1=2, EffectDieSides_1=1))))
    rows.append(clone("buff", **active(**text(
        274740, "Zeal of the Burning Blade", blessing, icon="ancestral",
        aura="Attack and casting speed increased by $w1%.", DurationIndex=8, SpellVisualID_1=47,
        Effect_1=6, EffectAura_1=193, ImplicitTargetA_1=1, EffectBasePoints_1=2, EffectDieSides_1=1))))
    rows.append(clone("buff", **active(**text(
        274741, "Ferocity of the Frostwolf", blessing, icon="ancestral",
        aura="Damage done increased by $w1%.", DurationIndex=8, SpellVisualID_1=47,
        Effect_1=6, EffectAura_1=79, EffectMiscValue_1=127, ImplicitTargetA_1=1,
        EffectBasePoints_1=2, EffectDieSides_1=1))))
    rows.append(clone("buff", **active(**text(
        274742, "Might of the Blackrock", blessing, icon="ancestral",
        aura="Healing done increased by $w1%. Damage taken reduced by 3%.", DurationIndex=8,
        SpellVisualID_1=47,
        Effect_1=6, EffectAura_1=136, ImplicitTargetA_1=1, EffectBasePoints_1=2, EffectDieSides_1=1,
        Effect_2=6, EffectAura_2=87, EffectMiscValue_2=127, ImplicitTargetA_2=1,
        EffectBasePoints_2=-4, EffectDieSides_2=1))))

    # ---- Drakkari Troll 28 (Regeneration and Da Voodoo Shuffle are the stock spells) ----
    rows.append(clone("berserking", slots=(), SpellVisualID_1=14331, **text(
        910200, "Blood of the Gods",
        "Drink the blood of the fallen gods, increasing your attack and casting speed by $s1% for $d.",
        aura="Attack and casting speed increased by $w1%.", icon=ICON_BERSERKING)))
    rows.append(clone("passive", **text(
        910201, "Frozen Empire", "Reduces Frost damage taken by 1%.", icon=ICON_FROST,
        Effect_1=6, EffectAura_1=87, EffectMiscValue_1=16, ImplicitTargetA_1=1,
        EffectBasePoints_1=-2, EffectDieSides_1=1)))

    # ---- gates ----
    ids = [int(r[0]) for r in rows]
    taken = sorted(set(ids) & all_ids)
    if taken:
        raise SystemExit("REFUSING: spell rows already in Spell.csv: %s" % taken)
    if len(set(ids)) != len(ids):
        raise SystemExit("duplicate ids in this batch")
    for r in rows:
        for s in (1, 2, 3):
            eff = int(r[ix["Effect_%d" % s]] or 0)
            aur = int(r[ix["EffectAura_%d" % s]] or 0)
            if eff >= 165 or aur >= 317:
                raise SystemExit("spell %s effect slot %d out of range: effect=%d aura=%d"
                                 % (r[0], s, eff, aur))

    stage_icons(a.icons)

    with open(OUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(hdr)
        w.writerows(rows)
    print("wrote %s (%d rows)" % (OUT_CSV, len(rows)))

    bak = SPELL_DBC + BAK
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(SPELL_DBC, bak)
    subprocess.check_call([sys.executable, APPEND, "--dbc", bak, "--csv", OUT_CSV, "--out", SPELL_DBC])
    print("Spell.dbc updated")

    append_spell_icons(ICON_DBC)

    # ---- keep the master CSV in step with the DBC (fully quoted, LF, appended at the end) ----
    shutil.copy2(SPELL_CSV, SPELL_CSV + BAK)
    buf = io.StringIO()
    csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(rows)
    with io.open(SPELL_CSV, "a", encoding="utf-8", newline="") as f:
        f.write(buf.getvalue())
    print("Spell.csv appended (%d rows)" % len(rows))

    # ---- server overlay SQL (column list taken verbatim from the Worgoblin file) ----
    src = io.open(WORGOBLIN_10, encoding="utf-8").read()
    m = re.search(r"INSERT INTO `spell_dbc` \((.*?)\) VALUES", src, re.S)
    cols = [c.strip().strip("`") for c in m.group(1).split(",")]

    def csv_name(col):
        m2 = re.fullmatch(r"AttributesEx([2-7])", col)
        if m2:
            return "AttributesEx" + "BCDEFG"[int(m2.group(1)) - 2]
        if col.startswith("unk_320"):
            return None
        if col == "SpellName":
            return "Name_Lang_enUS"
        m3 = re.fullmatch(r"EffectBonusMultiplier_([1-3])", col)
        if m3:
            return "Field%d" % (226 + int(m3.group(1)))
        return col

    unmapped = [c for c in cols if csv_name(c) is not None and csv_name(c) not in ix]
    if unmapped:
        raise SystemExit("spell_dbc columns with no CSV source: %s" % unmapped)

    def sql_val(row, col):
        cn = csv_name(col)
        if cn is None:
            return "0"
        v = row[ix[cn]]
        if v == "":
            return "''"
        try:
            float(v)
            return v
        except ValueError:
            return "'" + v.replace("\\", "\\\\").replace("'", "''") + "'"

    out = ["-- Races 28-31: server-side spell definitions for the racials",
           "-- (generated by tools/gen_races28to31_racials.py 1:1 from the client Spell.dbc rows).",
           "DELETE FROM `spell_dbc` WHERE `ID` IN (%s);" % ", ".join(str(i) for i in sorted(ids)),
           "INSERT INTO `spell_dbc` (%s) VALUES" % ", ".join("`%s`" % c for c in cols)]
    out.append(",\n".join("(" + ", ".join(sql_val(r, c) for c in cols) + ")"
                          for r in sorted(rows, key=lambda r: int(r[0]))) + ";")
    io.open(OUT_SQL, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote %s" % os.path.abspath(OUT_SQL))


if __name__ == "__main__":
    main()
