#!/usr/bin/env python3
"""
gen_pandaren_spells.py - author the five Pandaren racial spells (MoP ids) for this fork.

Emits:
  1. pandaren_spells.csv (232-col Spell CSV rows) next to this script
  2. Custom/DBCs/Spell.dbc updated via spell-dbc-append.py (backup .pre-pandaren.bak)
     - NEVER csv2wdbc: the fork Spell.dbc is the 234-field layout
  3. ../10_spell_dbc.sql server overlay rows, column list taken verbatim from the
     known-good Worgoblin 10_spell_dbc.sql (mapping: dbc234 = csv[0:13]+[0]+csv[13]+[0]+csv[14:])

Templates (cloned from the fork's own Spell.csv, values verified 2026-08-27):
  Gouge (1776)           -> Quaking Palm: aura 12 MOD_STUN + EffectMechanic 14 INCAPACITATE,
                            DurationIndex 35 (4s), AuraInterruptFlags 2 (break on damage),
                            RangeIndex 2 (melee)
  Arcane Affinity (28877)-> passives: Attributes 80 (passive), aura 98 MOD_SKILL for Gourmand,
                            aura 4 DUMMY for Epicurean/Inner Peace/Bouncy (implemented in core,
                            see dc_pandaren notes in 00_README.md)

Spell ids are retail MoP (verified in SkyFire_548 SQL): 107072 Epicurean, 107073 Gourmand,
107074 Inner Peace, 107076 Bouncy, 107079 Quaking Palm.
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
OUT_CSV = os.path.join(HERE, "pandaren_spells.csv")
OUT_SQL = os.path.join(HERE, "..", "10_spell_dbc.sql")

IDS = {"epicurean": 107072, "gourmand": 107073, "innerpeace": 107074,
       "bouncy": 107076, "quakingpalm": 107079}


def main():
    with open(SPELL_CSV, encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f)
        hdr = next(rd)
        ix = {n: i for i, n in enumerate(hdr)}
        templates = {}
        exists = set()
        for r in rd:
            if r[0] in ("1776", "28877"):
                templates.setdefault(r[0], r)
            if r[0] in {str(v) for v in IDS.values()}:
                exists.add(r[0])
    assert len(hdr) == 232
    if exists:
        raise SystemExit("REFUSING: spell rows already in Spell.csv: %s" % sorted(exists))
    gouge, passive = templates["1776"], templates["28877"]

    # locale-string columns of the four blocks; cleared on every clone
    loc_cols = [c for c in hdr if re.match(
        r"(Name|NameSubtext|Description|AuraDescription)_Lang_(?!Mask)", c)]

    def clone(base, **over):
        r = list(base)
        for c in loc_cols:
            r[ix[c]] = ""
        for k, v in over.items():
            r[ix[k]] = str(v)
        return r

    def zero_fx23(over):
        """zero every per-effect column for effect slots 2 and 3"""
        for c in hdr:
            if c.endswith("_2") or c.endswith("_3"):
                if c.startswith(("Effect", "ImplicitTarget", "SpellVisualID")):
                    over.setdefault(c, 0)
        return over

    rows = []
    # ---- Quaking Palm ----
    rows.append(clone(gouge, **zero_fx23(dict(
        ID=IDS["quakingpalm"],
        Category=0, CategoryRecoveryTime=0, RecoveryTime=30000,
        PowerType=0, ManaCost=0,
        EquippedItemClass=-1, EquippedItemSubclass=0, EquippedItemInvTypes=0,
        BaseLevel=1, SpellLevel=1, MaxLevel=0,
        Mechanic=14,                       # MECHANIC_INCAPACITATE (top-level, for DR/immunity)
        Effect_1=6, EffectAura_1=12,       # APPLY_AURA / MOD_STUN
        EffectMechanic_1=14, ImplicitTargetA_1=6,
        EffectBasePoints_1=0, EffectDieSides_1=1,
        Name_Lang_enUS="Quaking Palm",
        Description_Lang_enUS="Strikes the target with a quaking palm, incapacitating "
                              "the target for $d. Any damage caused will awaken the target.",
    ))))

    def make_passive(key, name, desc, aura, misc, bp, icon):
        rows.append(clone(passive,
            ID=IDS[key],
            EffectAura_1=aura, EffectMiscValue_1=misc, EffectBasePoints_1=bp,
            SpellIconID=icon,
            Name_Lang_enUS=name, Description_Lang_enUS=desc,
            AuraDescription_Lang_enUS=desc,
        ))
    # ---- passives ----
    make_passive("epicurean", "Epicurean",
                 "Your love of food is unmatched: the stat benefits from eating food are doubled.",
                 4, 0, 0, 1467)
    make_passive("gourmand", "Gourmand",
                 "Your Cooking skill is increased by $s1.",
                 98, 185, 14, 1467)          # bp 14 + die 1 = +15 cooking
    make_passive("innerpeace", "Inner Peace",
                 "Your rested experience bonus lasts twice as long as normal.",
                 4, 0, 0, 51)
    make_passive("bouncy", "Bouncy",
                 "You take half falling damage.",
                 4, 0, 0, 505)

    with open(OUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(hdr)
        w.writerows(rows)
    print("wrote %s (%d rows)" % (OUT_CSV, len(rows)))

    # ---- client Spell.dbc append ----
    bak = SPELL_DBC + ".pre-pandaren.bak"
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(SPELL_DBC, bak)
    subprocess.check_call([sys.executable, APPEND, "--dbc", bak, "--csv", OUT_CSV,
                           "--out", SPELL_DBC])
    print("Spell.dbc updated (backup: %s)" % os.path.basename(bak))

    # ---- server overlay SQL ----
    src = io.open(WORGOBLIN_10, encoding="utf-8").read()
    m = re.search(r"INSERT INTO `spell_dbc` \((.*?)\) VALUES", src, re.S)
    cols = [c.strip().strip("`") for c in m.group(1).split(",")]

    def csv_name(col):
        m2 = re.fullmatch(r"AttributesEx([2-7])", col)
        if m2:
            return "AttributesEx" + "BCDEFG"[int(m2.group(1)) - 2]
        if col.startswith("unk_320"):
            return None                     # the two padding fields
        if col == "SpellName":
            return "Name_Lang_enUS"
        m3 = re.fullmatch(r"EffectBonusMultiplier_([1-3])", col)
        if m3:                              # WDBX export leaves these unnamed
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
    out = ["-- Pandaren: server-side spell definitions for the five racials",
           "-- (generated by tools/gen_pandaren_spells.py 1:1 from the client Spell.dbc rows).",
           "DELETE FROM `spell_dbc` WHERE `ID` IN (%s);" % ids,
           "INSERT INTO `spell_dbc` (%s) VALUES" % ", ".join("`%s`" % c for c in cols)]
    lines = []
    for row in sorted(rows, key=lambda r: int(r[0])):
        lines.append("(" + ", ".join(sql_val(row, c) for c in cols) + ")")
    out.append(",\n".join(lines) + ";")
    io.open(OUT_SQL, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote %s" % os.path.abspath(OUT_SQL))


if __name__ == "__main__":
    main()
