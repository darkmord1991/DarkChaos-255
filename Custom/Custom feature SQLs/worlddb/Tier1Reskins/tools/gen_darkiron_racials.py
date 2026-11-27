#!/usr/bin/env python3
"""
gen_darkiron_racials.py - author the Dark Iron Dwarf (race 27) racial spells for this fork.

Same shape as ../../AlliedRaces/tools/gen_allied_racials.py. The spell ids are the real ones
(read from the 9.2.7 client DB2s, SkillLineAbility skill lines 2597/2773 - the 12.x retail tables
are TACT-encrypted), all verified free against Custom/CSV DBC/Spell.csv. Emits:

  1. darkiron_racials.csv (232-col Spell CSV rows) next to this script
  2. Custom/DBCs/Spell.dbc updated via spell-dbc-append.py (backup .pre-darkiron-racials.bak)
     - NEVER csv2wdbc: the fork Spell.dbc is the 234-field layout
  3. with --deploy-base/--deploy-out, the same rows appended to a second base: the Spell.dbc the
     client actually carries differs from Custom/DBCs only by ~100 whitespace-trimmed tooltips, so
     the deploy copy is built on the deployed bytes and the client changes by these rows alone
  4. the same rows appended to Custom/CSV DBC/Spell.csv (backup .pre-darkiron-racials.bak)
  5. four SpellIcon rows for the retail racial icons, appended to Custom/DBCs/SpellIcon.dbc
  6. ../03_darkiron_spell_dbc.sql server overlay rows

Racials (retail 9.2.7 -> 3.3.5):

  Fireblood        265221  retail: 4x DISPEL (poison/disease/curse/magic) + DISPEL_MECHANIC bleed,
                           then a scripted primary-stat buff (265226) scaled per effect removed.
                           here: DISPEL misc DISPEL_ALL(7) - GetDispelMask() expands it to all four
                           types - + DISPEL_MECHANIC MECHANIC_BLEED(15) + a flat +3% all stats
                           (MOD_TOTAL_STAT_PERCENTAGE, misc -1, as Blessing of Kings) for 8 s. 3.3.5
                           has no primary stat and data cannot count removed effects.
  Forged in Flames 265224  MOD_DAMAGE_PERCENT_TAKEN(87) misc 1 (physical) -1%, as retail.
  Mass Production  265222  MOD_SKILL_TALENT(98) misc 164 (Blacksmithing) +15, the 3.3.5 size of a
                           racial profession bonus (Engineering Specialization is +15). Retail's
                           crafting-speed half has no 3.3.5 aura.
  Dungeon Delver   265223  inert DUMMY(4) passive: the spellbook entry and tooltip.
                   265227  MOD_SPEED_ALWAYS(129) +4%, never granted: the core applies it while the
                           player is indoors (src/server/scripts/DC/Races/dc_dark_iron.cpp), which
                           no 3.3.5 aura attribute can express.
  Mole Machine     -       not ported: a destination teleport with retail UI, and its id 265225 is
                           already this fork's Vulpera Fire Resistance.

Templates: Blood Fury 20572 (visible 2-min racial self buff, off the GCD - Stoneform carries
NO_AURA_ICON and an immunity flag), Arcane Affinity 28877 (passive), Engineering Specialization
20593 (racial skill bonus).

Verified constants (src/server/shared/SharedDefines.h, game/Spells/Auras/SpellAuraDefines.h)
  effects  DISPEL=38  DISPEL_MECHANIC=108  APPLY_AURA=6
  auras    DUMMY=4  MOD_DAMAGE_PERCENT_TAKEN=87  MOD_SKILL_TALENT=98  MOD_SPEED_ALWAYS=129
           MOD_TOTAL_STAT_PERCENTAGE=137
  dispel   DISPEL_ALL=7 (-> DISPEL_ALL_MASK)   mechanic MECHANIC_BLEED=15
  duration idx 31=8000ms 21=infinite (Custom/CSV DBC/SpellDuration.csv)   range idx 1=self
A spell's effect value is BasePoints + DieSides, so bp=2 die=1 yields 3.
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
APPEND = r"K:\Dark-Chaos\wow.export-main\tools\spell-dbc-append.py"
WORGOBLIN_10 = os.path.join(HERE, "..", "..", "Worgoblin", "10_spell_dbc.sql")
OUT_CSV = os.path.join(HERE, "darkiron_racials.csv")
OUT_SQL = os.path.join(HERE, "..", "03_darkiron_spell_dbc.sql")
BAK = ".pre-darkiron-racials.bak"

IDS = {"fireblood": 265221, "massprod": 265222, "delver": 265223, "forged": 265224,
       "delverspeed": 265227}
TEMPLATES = {"20572": "bloodfury", "28877": "passive", "20593": "skill"}

# New SpellIcon rows -> the retail racial icons (shipped as Interface\Icons\<name>.blp; retail
# spells the forged icon "foreged"). Ids continue the custom band past the table's max.
ICONS = {
    "fireblood": (514642, r"Interface\Icons\Ability_Racial_Fireblood"),
    "forged":    (514643, r"Interface\Icons\Ability_Racial_ForegedInFlames"),
    "delver":    (514644, r"Interface\Icons\Ability_Racial_DungeonDelver"),
    "massprod":  (514645, r"Interface\Icons\Ability_Racial_MassProduction"),
}


def append_spell_icons(path):
    """Append ICONS to a 2-field SpellIcon.dbc in place (backup alongside). Refuses on id clashes."""
    b = open(path, "rb").read()
    magic, n, f, rs, ss = struct.unpack_from("<4s4I", b, 0)
    assert magic == b"WDBC" and f == 2 and rs == 8, (magic, f, rs)
    recs = [struct.unpack_from("<II", b, 20 + i * rs) for i in range(n)]
    strings = bytearray(b[20 + n * rs:20 + n * rs + ss])
    have = {r[0] for r in recs}
    new = sorted(ICONS.values())
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
    print("SpellIcon.dbc: +%d rows (%d -> %d), backup %s" % (len(new), n, len(recs), os.path.basename(bak)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deploy-base", help="the Spell.dbc the client carries (extracted from patch-4)")
    ap.add_argument("--deploy-out", help="where to write deploy-base + these rows")
    a = ap.parse_args()

    with open(SPELL_CSV, encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f)
        hdr = next(rd)
        ix = {n: i for i, n in enumerate(hdr)}
        tpl, exists = {}, set()
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
        for c in reagent_cols:
            r[ix[c]] = "0"
        for k, v in over.items():
            r[ix[k]] = str(v)
        return r

    def zero_slots(over, slots):
        """zero every per-effect column of the given effect slots the caller did not set"""
        for c in hdr:
            for s in slots:
                if c.endswith("_%d" % s) and c.startswith(("Effect", "ImplicitTarget")):
                    over.setdefault(c, 0)
        return over

    def text(name, desc, aura=None, **kw):
        kw.update(Name_Lang_enUS=name, Description_Lang_enUS=desc,
                  AuraDescription_Lang_enUS=desc if aura is None else aura)
        return kw

    rows = []

    rows.append(clone(tpl["bloodfury"], **zero_slots(text(
        "Fireblood",
        "Removes all poison, disease, curse, magic, and bleed effects and increases all your "
        "stats by $s3% for $d.",
        aura="All stats increased by $s3%.",
        ID=IDS["fireblood"],
        Category=0, CategoryRecoveryTime=0, RecoveryTime=120000,
        StartRecoveryCategory=0, StartRecoveryTime=0,
        CastingTimeIndex=1, DurationIndex=31, RangeIndex=1,
        PowerType=0, ManaCost=0, ManaCostPct=0,
        Mechanic=0, DispelType=0, SchoolMask=1,   # physical, as retail: a fire school would let a
                                                  # fire lockout (interrupt) block the dispel
        Effect_1=38, EffectAura_1=0, EffectMiscValue_1=7, ImplicitTargetA_1=1,
        EffectBasePoints_1=99, EffectDieSides_1=1,
        Effect_2=108, EffectAura_2=0, EffectMiscValue_2=15, ImplicitTargetA_2=1,
        EffectBasePoints_2=0, EffectDieSides_2=1,
        Effect_3=6, EffectAura_3=137, EffectMiscValue_3=-1, ImplicitTargetA_3=1,
        EffectBasePoints_3=2, EffectDieSides_3=1,
        SpellIconID=ICONS["fireblood"][0],
    ), (1, 2, 3))))

    rows.append(clone(tpl["passive"], **zero_slots(text(
        "Forged in Flames",
        "Reduces damage taken from Physical attacks by 1%.",
        ID=IDS["forged"],
        Effect_1=6, EffectAura_1=87, EffectMiscValue_1=1, ImplicitTargetA_1=1,
        EffectBasePoints_1=-2, EffectDieSides_1=1,
        SpellIconID=ICONS["forged"][0],
    ), (1, 2, 3))))

    rows.append(clone(tpl["skill"], **zero_slots(text(
        "Mass Production",
        "Increases your Blacksmithing skill by $s1.",
        ID=IDS["massprod"],
        Effect_1=6, EffectAura_1=98, EffectMiscValue_1=164, ImplicitTargetA_1=1,
        EffectBasePoints_1=14, EffectDieSides_1=1,
        SpellIconID=ICONS["massprod"][0],
    ), (1, 2, 3))))

    rows.append(clone(tpl["passive"], **zero_slots(text(
        "Dungeon Delver",
        "While indoors, you move $s1% faster.",
        ID=IDS["delver"],
        Effect_1=6, EffectAura_1=4, EffectMiscValue_1=0, ImplicitTargetA_1=1,
        EffectBasePoints_1=3, EffectDieSides_1=1,
        SpellIconID=ICONS["delver"][0],
    ), (1, 2, 3))))

    rows.append(clone(tpl["passive"], **zero_slots(text(
        "Dungeon Delver",
        "Moving $s1% faster while indoors.",
        ID=IDS["delverspeed"],
        Effect_1=6, EffectAura_1=129, EffectMiscValue_1=0, ImplicitTargetA_1=1,
        EffectBasePoints_1=3, EffectDieSides_1=1,
        SpellIconID=ICONS["delver"][0],
    ), (1, 2, 3))))

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

    # ---- client Spell.dbc append (repo copy) ----
    bak = SPELL_DBC + BAK
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(SPELL_DBC, bak)
    subprocess.check_call([sys.executable, APPEND, "--dbc", bak, "--csv", OUT_CSV, "--out", SPELL_DBC])
    print("Spell.dbc updated (backup: %s)" % os.path.basename(bak))

    if a.deploy_base and a.deploy_out:
        os.makedirs(os.path.dirname(os.path.abspath(a.deploy_out)), exist_ok=True)
        subprocess.check_call([sys.executable, APPEND, "--dbc", a.deploy_base, "--csv", OUT_CSV,
                               "--out", a.deploy_out])
        print("deploy Spell.dbc written: %s" % a.deploy_out)

    append_spell_icons(ICON_DBC)

    # ---- keep the master CSV in step with the DBC (fully quoted, LF, appended at the end) ----
    shutil.copy2(SPELL_CSV, SPELL_CSV + BAK)
    buf = io.StringIO()
    csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(rows)
    with io.open(SPELL_CSV, "a", encoding="utf-8", newline="") as f:
        f.write(buf.getvalue())
    print("Spell.csv appended (%d rows, backup %s)" % (len(rows), BAK))

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
    out = ["-- Dark Iron Dwarf (27): server-side spell definitions for the racials",
           "-- (generated by tools/gen_darkiron_racials.py 1:1 from the client Spell.dbc rows).",
           "-- Grants: ../CharacterCreation/03_custom_racials_skilllineability.sql.",
           "DELETE FROM `spell_dbc` WHERE `ID` IN (%s);" % ids,
           "INSERT INTO `spell_dbc` (%s) VALUES" % ", ".join("`%s`" % c for c in cols)]
    out.append(",\n".join("(" + ", ".join(sql_val(r, c) for c in cols) + ")"
                          for r in sorted(rows, key=lambda r: int(r[0]))) + ";")
    io.open(OUT_SQL, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote %s" % os.path.abspath(OUT_SQL))


if __name__ == "__main__":
    main()
