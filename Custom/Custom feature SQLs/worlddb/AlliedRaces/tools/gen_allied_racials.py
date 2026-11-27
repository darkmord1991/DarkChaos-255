#!/usr/bin/env python3
"""
gen_allied_racials.py - author the ten allied-race racial spells for this fork.

Same shape as ../../Pandaren/tools/gen_pandaren_spells.py. Emits:
  1. allied_racials.csv (232-col Spell CSV rows) next to this script
  2. Custom/DBCs/Spell.dbc updated via spell-dbc-append.py (backup .pre-allied-racials.bak)
     - NEVER csv2wdbc: the fork Spell.dbc is the 234-field layout
  3. the same rows appended to Custom/CSV DBC/Spell.csv, so the master CSV stays a faithful
     mirror of the DBC. The Pandaren generator does NOT do this and its rows were merged in by
     hand afterwards; skipping it silently breaks the duplicate-id guard at the top of this
     script, because that guard reads Spell.csv and would happily hand out an id the DBC has
     already used.
  4. ../10_spell_dbc.sql server overlay rows

Every effect id, aura id, mechanic, duration index and range index below was read out of this
fork's own data or the core enums -- none are recalled. See ../00_RACIALS.md for the design and
the spell-effect-range-crash note for why that matters: an effect id >= 165 or an aura id >= 317
asserts and segfaults the worldserver at boot.

Verified constants
  effects  SCHOOL_DAMAGE=2  APPLY_AURA=6  KNOCK_BACK=98            (SharedDefines.h)
  auras    PERIODIC_HEAL=8  MOD_STUN=12  DUMMY=4  PROC_TRIGGER_SPELL=42
           MOD_INCREASE_SWIM_SPEED=58  WATER_BREATHING=82
           FEATHER_FALL=105  MOD_ATTACKER_SPELL_HIT_CHANCE=186     (SpellAuraDefines.h)
  mechanic MECHANIC_STUN=12                                        (SharedDefines.h)
  duration idx 32=6s  35=4s  9=30s  21=infinite                    (Custom/DBCs/SpellDuration.dbc)
  range    idx 1=self  2=melee  4=30yd                             (Frostbolt/Eviscerate/self)
  proc     PROC_FLAG_TAKEN_DAMAGE=0x00100000                       (SpellMgr.h)
  school   1 Physical  4 Fire  8 Nature  16 Frost

Racial resistances use aura 186 MOD_ATTACKER_SPELL_HIT_CHANCE, which is how the stock dwarf
racial Frost Resistance (20596) does it in this client -- "reduces the chance you will be hit by
<school> spells" -- rather than a damage-taken modifier.

A spell's effect value is BasePoints + DieSides, so bp=-3 die=1 yields -2 (percent), matching
Frost Resistance exactly.
"""
import csv
import io
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
SPELL_CSV = os.path.join(REPO, "Custom", "CSV DBC", "Spell.csv")
SPELL_DBC = os.path.join(REPO, "Custom", "DBCs", "Spell.dbc")
APPEND = r"K:\Dark-Chaos\wow.export-main\tools\spell-dbc-append.py"
WORGOBLIN_10 = os.path.join(HERE, "..", "..", "Worgoblin", "10_spell_dbc.sql")
OUT_CSV = os.path.join(HERE, "allied_racials.csv")
OUT_SQL = os.path.join(HERE, "..", "10_spell_dbc.sql")

# retail BfA ids, all verified free against Spell.csv
IDS = {
    "bagoftricks": 312411, "noseproc": 312924, "nosedamage": 312925, "fireresist": 265225,
    "regeneratin": 291944, "swoop": 281954, "cityofgold": 291628,
    "haymaker": 287712, "childofsea": 280331, "rime": 287829,
}
TEMPLATES = {"1776": "gouge", "28877": "passive", "20596": "resist",
             "130": "slowfall", "5697": "breath", "755": "channel"}


def main():
    with open(SPELL_CSV, encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f)
        hdr = next(rd)
        ix = {n: i for i, n in enumerate(hdr)}
        tpl = {}
        exists = set()
        for r in rd:
            if r[0] in TEMPLATES:
                tpl.setdefault(TEMPLATES[r[0]], r)
            if r[0] in {str(v) for v in IDS.values()}:
                exists.add(r[0])
    assert len(hdr) == 232, "expected the 232-column Spell CSV, got %d" % len(hdr)
    missing = set(TEMPLATES.values()) - set(tpl)
    if missing:
        raise SystemExit("template spells missing from Spell.csv: %s" % sorted(missing))
    if exists:
        raise SystemExit("REFUSING: spell rows already in Spell.csv: %s" % sorted(exists))

    loc_cols = [c for c in hdr if re.match(
        r"(Name|NameSubtext|Description|AuraDescription)_Lang_(?!Mask)", c)]
    reagent_cols = [c for c in hdr if c.startswith(("Reagent_", "ReagentCount_"))]

    def clone(base, **over):
        r = list(base)
        for c in loc_cols:
            r[ix[c]] = ""
        for c in reagent_cols:          # no racial costs a reagent; Slow Fall wants a feather
            r[ix[c]] = "0"
        for k, v in over.items():
            r[ix[k]] = str(v)
        return r

    def zero_slots(over, slots):
        """zero every per-effect column for the given effect slots"""
        for c in hdr:
            for s in slots:
                if c.endswith("_%d" % s) and c.startswith(("Effect", "ImplicitTarget")):
                    over.setdefault(c, 0)
        return over

    def describe(name, desc, **kw):
        kw.update(Name_Lang_enUS=name, Description_Lang_enUS=desc, AuraDescription_Lang_enUS=desc)
        return kw

    rows = []

    # ---------------------------------------------------------------- Vulpera (24)
    rows.append(clone(tpl["gouge"], **zero_slots(describe(
        "Bag of Tricks",
        "Reach into your bag and pull out a trick, dealing $s1 Fire damage to an enemy.",
        ID=IDS["bagoftricks"],
        Category=0, CategoryRecoveryTime=0, RecoveryTime=90000,
        Mechanic=0, AuraInterruptFlags=0, DurationIndex=0,
        PowerType=0, ManaCost=0,
        EquippedItemClass=-1, EquippedItemSubclass=0, EquippedItemInvTypes=0,
        BaseLevel=1, SpellLevel=1, MaxLevel=0,
        RangeIndex=4, SchoolMask=4, DefenseType=1,
        Effect_1=2, EffectAura_1=0, EffectMechanic_1=0, ImplicitTargetA_1=6,
        EffectBasePoints_1=199, EffectDieSides_1=1,
        SpellIconID=245,
    ), (2, 3))))

    rows.append(clone(tpl["passive"], **describe(
        "Nose for Trouble",
        "Being struck has a chance to leave your attacker exposed, dealing damage to them.",
        ID=IDS["noseproc"],
        Effect_1=6, EffectAura_1=42, EffectTriggerSpell_1=IDS["nosedamage"],
        EffectBasePoints_1=0, EffectDieSides_1=1, EffectMiscValue_1=0,
        ProcTypeMask=0x00100000, ProcChance=15,
        ImplicitTargetA_1=1, SpellIconID=71,
    )))

    rows.append(clone(tpl["gouge"], **zero_slots(describe(
        "Nose for Trouble",
        "Deals $s1 damage to your attacker.",
        ID=IDS["nosedamage"],
        Category=0, CategoryRecoveryTime=0, RecoveryTime=0,
        Mechanic=0, AuraInterruptFlags=0, DurationIndex=0,
        PowerType=0, ManaCost=0,
        EquippedItemClass=-1, EquippedItemSubclass=0, EquippedItemInvTypes=0,
        BaseLevel=1, SpellLevel=1, MaxLevel=0,
        RangeIndex=2, SchoolMask=1, DefenseType=2,
        Effect_1=2, EffectAura_1=0, EffectMechanic_1=0, ImplicitTargetA_1=6,
        EffectBasePoints_1=99, EffectDieSides_1=1,
        SpellIconID=71,
    ), (2, 3))))

    rows.append(clone(tpl["resist"], **describe(
        "Fire Resistance",
        "Reduces the chance you will be hit by Fire spells by $s1%.",
        ID=IDS["fireresist"],
        Effect_1=6, EffectAura_1=186, EffectMiscValue_1=4,
        EffectBasePoints_1=-3, EffectDieSides_1=1,
        ImplicitTargetA_1=1, SpellIconID=133,
    )))

    # ---------------------------------------------------------------- Zandalari Troll (25)
    rows.append(clone(tpl["channel"], **zero_slots(describe(
        "Regeneratin'",
        "Concentrate to restore health over $d. Moving or taking damage cancels the effect.",
        ID=IDS["regeneratin"],
        RecoveryTime=150000, CategoryRecoveryTime=0, Category=0,
        DurationIndex=32, RangeIndex=1,
        PowerType=0, ManaCost=0, ManaPerSecond=0,
        EquippedItemClass=-1, EquippedItemSubclass=0, EquippedItemInvTypes=0,
        BaseLevel=1, SpellLevel=1, MaxLevel=0,
        Effect_1=6, EffectAura_1=8, EffectAuraPeriod_1=1000,
        EffectBasePoints_1=999, EffectDieSides_1=1, ImplicitTargetA_1=1,
        SpellIconID=146,
    ), (2, 3))))

    rows.append(clone(tpl["slowfall"], **zero_slots(describe(
        "Pterrordax Swoop",
        "Spread your arms and glide, slowing your rate of descent for $d.",
        ID=IDS["swoop"],
        RecoveryTime=120000, DurationIndex=9, RangeIndex=1,
        PowerType=0, ManaCost=0,
        Effect_1=6, EffectAura_1=105, ImplicitTargetA_1=1,
        EffectBasePoints_1=0, EffectDieSides_1=1,
        SpellIconID=505,
    ), (2, 3))))

    rows.append(clone(tpl["passive"], **describe(
        "City of Gold",
        "You loot additional gold from creatures.",
        ID=IDS["cityofgold"],
        Effect_1=6, EffectAura_1=4, EffectMiscValue_1=0,
        EffectBasePoints_1=1, EffectDieSides_1=1,
        ImplicitTargetA_1=1, SpellIconID=146,
    )))

    # ---------------------------------------------------------------- Kul Tiran (26)
    rows.append(clone(tpl["gouge"], **describe(
        "Haymaker",
        "Wind up and deliver a mighty punch, dealing $s1 damage, knocking your target back "
        "and stunning them for $d.",
        ID=IDS["haymaker"],
        Category=0, CategoryRecoveryTime=0, RecoveryTime=150000,
        Mechanic=12, AuraInterruptFlags=0, DurationIndex=35,
        PowerType=0, ManaCost=0,
        EquippedItemClass=-1, EquippedItemSubclass=0, EquippedItemInvTypes=0,
        BaseLevel=1, SpellLevel=1, MaxLevel=0,
        RangeIndex=2, SchoolMask=1, DefenseType=2,
        Effect_1=2, EffectAura_1=0, EffectMechanic_1=0, ImplicitTargetA_1=6,
        EffectBasePoints_1=299, EffectDieSides_1=1,
        Effect_2=98, EffectAura_2=0, EffectMechanic_2=0, ImplicitTargetA_2=6,
        EffectBasePoints_2=29, EffectDieSides_2=1, EffectMiscValue_2=15,
        Effect_3=6, EffectAura_3=12, EffectMechanic_3=12, ImplicitTargetA_3=6,
        EffectBasePoints_3=0, EffectDieSides_3=1,
        SpellIconID=129,
    )))

    rows.append(clone(tpl["breath"], **zero_slots(describe(
        "Child of the Sea",
        "You can breathe underwater indefinitely and swim faster.",
        ID=IDS["childofsea"],
        Attributes=80, DurationIndex=21, RangeIndex=1,
        PowerType=0, ManaCost=0,
        Effect_1=6, EffectAura_1=82, EffectBasePoints_1=0, EffectDieSides_1=1,
        ImplicitTargetA_1=1,
        Effect_2=6, EffectAura_2=58, EffectBasePoints_2=19, EffectDieSides_2=1,
        ImplicitTargetA_2=1,
        SpellIconID=545,
    ), (3,))))

    rows.append(clone(tpl["resist"], **describe(
        "Rime of the Ancient Mariner",
        "Reduces the chance you will be hit by Frost and Nature spells by $s1%.",
        ID=IDS["rime"],
        Effect_1=6, EffectAura_1=186, EffectMiscValue_1=16,
        EffectBasePoints_1=-3, EffectDieSides_1=1, ImplicitTargetA_1=1,
        Effect_2=6, EffectAura_2=186, EffectMiscValue_2=8,
        EffectBasePoints_2=-3, EffectDieSides_2=1, ImplicitTargetA_2=1,
        SpellIconID=133,
    )))

    # ---- sanity gate: nothing may exceed the values that assert at server boot
    for r in rows:
        for s in (1, 2, 3):
            eff = int(r[ix["Effect_%d" % s]] or 0)
            aur = int(r[ix["EffectAura_%d" % s]] or 0)
            if eff >= 165 or aur >= 317:
                raise SystemExit("spell %s effect slot %d out of range: effect=%d aura=%d"
                                 % (r[0], s, eff, aur))

    with open(OUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(hdr)
        w.writerows(rows)
    print("wrote %s (%d rows)" % (OUT_CSV, len(rows)))

    # ---- client Spell.dbc append ----
    bak = SPELL_DBC + ".pre-allied-racials.bak"
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(SPELL_DBC, bak)
    subprocess.check_call([sys.executable, APPEND, "--dbc", bak, "--csv", OUT_CSV,
                           "--out", SPELL_DBC])
    print("Spell.dbc updated (backup: %s)" % os.path.basename(bak))

    # ---- keep the master CSV in step with the DBC ----
    # Spell.csv is fully quoted, LF, no BOM, and is NOT sorted: new rows go on the end, which is
    # where the Pandaren racials sit too.
    shutil.copy2(SPELL_CSV, SPELL_CSV + ".pre-allied-racials.bak")
    buf = io.StringIO()
    csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(rows)
    with io.open(SPELL_CSV, "a", encoding="utf-8", newline="") as f:
        f.write(buf.getvalue())
    print("Spell.csv appended (%d rows, backup .pre-allied-racials.bak)" % len(rows))

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

    ids = ", ".join(str(v) for v in sorted(IDS.values()))
    out = ["-- Allied races: server-side spell definitions for the ten racials",
           "-- (generated by tools/gen_allied_racials.py 1:1 from the client Spell.dbc rows).",
           "DELETE FROM `spell_dbc` WHERE `ID` IN (%s);" % ids,
           "INSERT INTO `spell_dbc` (%s) VALUES" % ", ".join("`%s`" % c for c in cols)]
    out.append(",\n".join("(" + ", ".join(sql_val(r, c) for c in cols) + ")"
                          for r in sorted(rows, key=lambda r: int(r[0]))) + ";")
    io.open(OUT_SQL, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote %s" % os.path.abspath(OUT_SQL))


if __name__ == "__main__":
    main()
