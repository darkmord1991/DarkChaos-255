#!/usr/bin/env python3
"""
Raid-buff percentage conversion for the 255 level cap.

THE PROBLEM
-----------
Every classic raid buff applies SPELL_AURA_MOD_STAT (29), which the core routes
into TOTAL_VALUE:

    SpellAuraEffects.cpp:4226  HandleStatFlatModifier(UNIT_MOD_STAT_*, TOTAL_VALUE, amount)

while gear lands in BASE_VALUE (Player.cpp:7057).  Unit::GetTotalStatValue then
combines them as

    value = ((BASE_VALUE + CreateStat) * BASE_PCT + TOTAL_VALUE) * TOTAL_PCT

so the buff is a constant sitting *next to* the gear pool and is never scaled by
it.  Arcane Intellect's +60 Intellect is worth ~5% at level 80, ~1% at the
level-130 content ceiling (avg top stat per epic piece: 154 at RequiredLevel 80
-> 824 at RequiredLevel 129) and rounding error at 255.

THE FIX
-------
Move the stat effects onto SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE (137), which
hits TOTAL_PCT and therefore multiplies the whole gear pool.  137 -- not
SPELL_AURA_MOD_PERCENT_STAT (80) -- because handler 80 early-returns on
non-players (SpellAuraEffects.cpp:4248), so hunter pets, ghouls and felguards
would silently receive nothing.  137 is also what Blessing of Kings already
uses, so the buffs share one bucket.

Attack power goes to 166/167 (MOD_ATTACK_POWER_PCT / MOD_RANGED_ATTACK_POWER_PCT)
and flat max-health goes to 133 (MOD_INCREASE_HEALTH_PERCENT) for the same reason.

OUTPUTS
-------
  <out>/00_spell_dbc_buff_percent_scaling.sql   acore_world.spell_dbc (234 cols)
                                                + spell_group exclusivity rows
  <out>/spell_csv_rows.csv                      the rewritten 232-col rows, for review
  Custom/CSV DBC/Spell.csv                      patched IN PLACE with --apply-csv
                                                (client tooltips; needs a Spell.dbc
                                                 recompile + patch MPQ redeploy)

Both outputs are derived from the same in-memory rows, so server behaviour and
client tooltip can never drift apart.

Column mapping is inherited from HyjalCata/tools/gen_hyjal_spell_downport.py:
the fork Spell.csv is the 234-field DBC minus the two unk_320 fields at DBC
index 13 and 15, so
    sql = csv[0:13] + [unk_320_2] + [csv[13]] + [unk_320_3] + csv[14:]
Both fillers are verified zero for every spell touched here.

Usage:
    python gen_buff_percent_scaling.py [outdir] [--apply-csv]
"""
import csv
import io
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
SPELL_CSV = os.path.join(REPO, "Custom", "CSV DBC", "Spell.csv")

OUT = "."
APPLY_CSV = False
for a in sys.argv[1:]:
    if a == "--apply-csv":
        APPLY_CSV = True
    else:
        OUT = a

# --- 232-col Spell.csv layout (1-based, as in the Hyjal generator) ----------
C_ID = 1
C_EFFECT = 70          # Effect_1..3            70,71,72
C_DIESIDES = 73        # EffectDieSides_1..3
C_RPPL = 76            # EffectRealPointsPerLevel_1..3
C_BASEPOINTS = 79      # EffectBasePoints_1..3
C_AURA = 94            # EffectAura_1..3
C_MISC = 109           # EffectMiscValue_1..3
C_NAME = 135           # Name_Lang_enUS
C_DESC = 169           # Description_Lang_enUS
C_AURADESC = 186       # AuraDescription_Lang_enUS

SPELL_EFFECT_APPLY_AURA = 6

# --- aura ids (src/server/game/Spells/Auras/SpellAuraDefines.h) -------------
A_MOD_STAT = 29
A_MOD_TOTAL_STAT_PERCENTAGE = 137
A_MOD_INCREASE_HEALTH_PERCENT = 133
A_MOD_ATTACK_POWER_PCT = 166
A_MOD_RANGED_ATTACK_POWER_PCT = 167

# --- stat indices (Stats enum) ---------------------------------------------
S_ALL = -1
S_STR, S_AGI, S_STA, S_INT, S_SPI = 0, 1, 2, 3, 4

# ---------------------------------------------------------------------------
# The conversion table.
#
#   sid: (label, {effect_index: (aura, misc, percent)}, description, aura_description)
#
# Effect indices not listed are left exactly as they are.  A `percent` of None
# means "retype the aura but let a SpellScript supply the amount" (prestige).
#
# Category values follow the MoP one-buff-per-category model:
#   all stats +10%   stamina +10%   intellect +10%   spirit +10%
#   attack power +10%   str/agi +5%   food +3%
#
# DEVIATION, deliberate: the all-stats category is 10%, not MoP's 5%.  Blessing
# of Kings is already live at 10% (spell 20217, aura 137).  Setting the category
# to 5% would halve a buff that works correctly today; matching Mark of the Wild
# upward to Kings changes nothing that currently functions.
# ---------------------------------------------------------------------------
PCT_ALL_STATS = 10
PCT_STAMINA = 10
PCT_INTELLECT = 10
PCT_SPIRIT = 10
PCT_ATTACK_POWER = 10
PCT_STR_AGI = 5
PCT_FOOD = 3

CONVERSIONS = {
    # === all stats +10% =====================================================
    # E0 (armor) and E2 (resistances) are deliberately left flat: +750 armor is
    # already meaningless at 255, and a *percentage* armor buff would be a large
    # unrequested buff to tanks.  Only the attribute effect is converted.
    48469: ("Mark of the Wild (Rank 9)",
            {1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_ALL, PCT_ALL_STATS)},
            "Increases the friendly target's armor by $s1, all attributes by $s2% and all resistances by $s3 for $d.",
            "Increases armor by $s1, all attributes by $s2% and all resistances by $s3."),
    48470: ("Gift of the Wild (Rank 4)",
            {1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_ALL, PCT_ALL_STATS)},
            "Increases the friendly target's armor by $s1, all attributes by $s2% and all resistances by $s3 for $d.",
            "Increases armor by $s1, all attributes by $s2% and all resistances by $s3."),
    72588: ("Gift of the Wild (item)",
            {1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_ALL, PCT_ALL_STATS)},
            "Increases the friendly target's armor by $s1, all attributes by $s2% and all resistances by $s3 for $d.",
            "Increases armor by $s1, all attributes by $s2% and all resistances by $s3."),

    # === stamina / max health +10% ==========================================
    48161: ("Power Word: Fortitude (Rank 8)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STA, PCT_STAMINA)},
            "Power infuses the target increasing their Stamina by $s1% for $d.",
            "Increases Stamina by $s1%."),
    48162: ("Prayer of Fortitude (Rank 4)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STA, PCT_STAMINA)},
            "Power infuses all party and raid members increasing their Stamina by $s1% for $d.",
            "Increases Stamina by $s1%."),
    # Commanding Shout and Blood Pact modify max health (aura 230), not stamina,
    # so they take the percentage form of that -- aura 133 -- rather than 137.
    47440: ("Commanding Shout (Rank 3)",
            {0: (A_MOD_INCREASE_HEALTH_PERCENT, 0, PCT_STAMINA)},
            "Increases maximum health of all party and raid members within $a1 yards by $s1%.  Lasts $d.",
            "Maximum health increased by $s1%."),
    47982: ("Blood Pact (Rank 7)",
            {0: (A_MOD_INCREASE_HEALTH_PERCENT, 0, PCT_STAMINA)},
            "Increases the maximum health of party members by $s1%.",
            "Maximum health increased by $s1%."),

    # === intellect +10% =====================================================
    42995: ("Arcane Intellect (Rank 7)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_INT, PCT_INTELLECT)},
            "Increases the target's Intellect by $s1% for $d.",
            "Increases Intellect by $s1%."),
    43002: ("Arcane Brilliance (Rank 3)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_INT, PCT_INTELLECT)},
            "Infuses all party and raid members with brilliance, increasing their Intellect by $s1% for $d.",
            "Increases Intellect by $s1%."),
    # Fel Intelligence also carries EffectRealPointsPerLevel 0.01, which would
    # add level/100 to a *percentage* (+2.55 at 255).  Zeroed below.
    57567: ("Fel Intelligence (Rank 5)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_INT, PCT_INTELLECT),
             1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_SPI, PCT_SPIRIT)},
            "Increases the Intellect of party members by $s1% and Spirit by $s2%.",
            "Intellect increased by $s1% and Spirit increased by $s2%."),

    # === spirit +10% ========================================================
    48073: ("Divine Spirit (Rank 6)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_SPI, PCT_SPIRIT)},
            "Holy power infuses the target, increasing their Spirit by $s1% for $d.",
            "Increases Spirit by $s1%."),
    48074: ("Prayer of Spirit (Rank 3)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_SPI, PCT_SPIRIT)},
            "Holy power infuses all party and raid members, increasing their Spirit by $s1% for $d.",
            "Increases Spirit by $s1%."),

    # === attack power +10% ==================================================
    47436: ("Battle Shout (Rank 9)",
            {0: (A_MOD_ATTACK_POWER_PCT, 0, PCT_ATTACK_POWER),
             1: (A_MOD_RANGED_ATTACK_POWER_PCT, 0, PCT_ATTACK_POWER)},
            "The warrior shouts, increasing attack power of all raid and party members within $a1 yards by $s1%.  Lasts $d.",
            "Increases your attack power by $s1%."),
    48932: ("Blessing of Might (Rank 10)",
            {0: (A_MOD_ATTACK_POWER_PCT, 0, PCT_ATTACK_POWER),
             1: (A_MOD_RANGED_ATTACK_POWER_PCT, 0, PCT_ATTACK_POWER)},
            "Places a blessing on the party or raid member, increasing their attack power by $s1% for $d.",
            "Increases attack power by $s1%."),
    48934: ("Greater Blessing of Might (Rank 5)",
            {0: (A_MOD_ATTACK_POWER_PCT, 0, PCT_ATTACK_POWER),
             1: (A_MOD_RANGED_ATTACK_POWER_PCT, 0, PCT_ATTACK_POWER)},
            "Gives all party and raid members increased attack power by $s1% for $d.",
            "Increases attack power by $s1%."),

    # === strength / agility +5% =============================================
    57623: ("Horn of Winter (Rank 2)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STR, PCT_STR_AGI),
             1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_AGI, PCT_STR_AGI)},
            "The Death Knight blows the Horn of Winter, which generates 10 runic power and increases total Strength and Agility of all party or raid members within $a1 yards by $s1%.  Lasts $d.",
            "Increases your total Strength and Agility by $s1%."),
    58646: ("Strength of Earth Totem (Rank 8)",
            {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STR, PCT_STR_AGI),
             1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_AGI, PCT_STR_AGI)},
            "Increases the Strength and Agility of party and raid members within $a1 yards by $s1%.",
            "Strength and Agility increased by $s1%."),

    # === DC custom Well Fed (Giant Isles fishing food) +3% ==================
    # Food sits deliberately below the raid buffs.  910122/910123 keep their
    # flat Spell Power / haste-rating effects: neither has a clean percentage
    # aura in 3.3.5, and they are tracked separately (see the report).
    910120: ("Well Fed (Agility/Stamina food)",
             {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_AGI, PCT_FOOD),
              1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STA, PCT_FOOD)},
             "Agility increased by $s1% and Stamina increased by $s2%. Lasts $d.",
             "Agility and Stamina increased by $s1%."),
    910121: ("Well Fed (Strength/Stamina food)",
             {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STR, PCT_FOOD),
              1: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STA, PCT_FOOD)},
             "Strength increased by $s1% and Stamina increased by $s2%. Lasts $d.",
             "Strength and Stamina increased by $s1%."),
    910122: ("Well Fed (caster food)",
             {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_INT, PCT_FOOD)},
             "Intellect increased by $s1% and Haste rating increased by $s2. Lasts $d.",
             "Intellect increased by $s1% and Haste rating increased by $s2."),
    910123: ("Well Fed (feast)",
             {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_AGI, PCT_FOOD),
              2: (A_MOD_TOTAL_STAT_PERCENTAGE, S_STA, PCT_FOOD)},
             "Agility increased by $s1%, Spell Power increased by $s2 and Stamina increased by $s3%. Lasts $d.",
             "Agility increased by $s1%, Spell Power increased by $s2, and Stamina increased by $s3%."),
}

# === DC Prestige stat auras -- a straight bug fix ===========================
# 800010-800019 are SPELL_AURA_DUMMY (4) in the DBC.  dc_prestige_spells.cpp
# binds an AuraScript to SPELL_AURA_ANY and computes
#     amount = prestigeLevel * Prestige.StatBonusPercent + challenge bonus
# into it -- but DUMMY has no stat handler, so the whole prestige stat bonus is
# currently dead.  Retyping the aura to 137 makes the existing script live with
# no code change; `percent = None` leaves EffectBasePoints alone because the
# script overwrites the amount in DoEffectCalcAmount anyway.
for _lvl in range(1, 11):
    CONVERSIONS[800009 + _lvl] = (
        "DC Prestige %d" % _lvl,
        {0: (A_MOD_TOTAL_STAT_PERCENTAGE, S_ALL, None)},
        "Increases all of your attributes.",
        "Increases all of your attributes.",
    )

# --- Mark of the Wild / Gift of the Wild join the Blessing of Kings ---------
# exclusivity group.  Once both are aura 137 with misc -1 they would otherwise
# MULTIPLY (AuraEffect::HandleModTotalPercentStat -> GetTotalAuraMultiplier),
# giving 1.10 * 1.10 to any raid with a druid and a paladin.  Group 1006 already
# holds the Kings family and carries stack_rule 1.
#
# These must be the FIRST RANK of each chain, not the max rank the conversion
# table touches.  LoadSpellGroups rejects anything else outright --
#     SpellMgr.cpp:1755  else if (spellInfo->GetRank() > 1)
#         "Spell {} listed in `spell_group` is not first rank of spell."
# -- and erases the row, so listing 48469/48470 silently leaves the two buffs
# stacking.  Registering the chain head covers every rank anyway, because
# GetSpellSpellGroupMapBounds (SpellMgr.cpp:730) resolves through
# GetFirstSpellInChain before looking the group up:
#     1126  Mark of the Wild rank 1 -> covers rank 9 (48469)
#     21849 Gift of the Wild rank 1 -> covers rank 4 (48470)
#     72588 Gift of the Wild (item) -> not in spell_ranks, is its own head
KINGS_GROUP = 1006
KINGS_GROUP_ADDITIONS = [1126, 21849, 72588]
# Max-rank ids shipped by an earlier revision of this file.  LoadSpellGroups
# erases them at load rather than applying them, so they never had any effect --
# but they stay in the table and repeat their error on every startup until
# deleted, so the generated DELETE clears them too.
KINGS_GROUP_STALE = [48469, 48470]


def load_rows(path, wanted):
    csv.field_size_limit(10 ** 8)
    found = {}
    with open(path, encoding="utf-8", newline="") as f:
        rdr = csv.reader(f)
        header = next(rdr)
        for row in rdr:
            if not row:
                continue
            try:
                sid = int(row[0])
            except ValueError:
                continue
            if sid in wanted:
                found[sid] = row
    return header, found


def convert(row, spec):
    """Apply one spell's effect changes to a 232-col CSV row, in place."""
    before, after = [], []
    for idx, (aura, misc, pct) in sorted(spec.items()):
        eff = row[C_EFFECT - 1 + idx]
        before.append("E%d(eff=%s aura=%s bp=%s misc=%s)" % (
            idx, eff, row[C_AURA - 1 + idx],
            int(row[C_BASEPOINTS - 1 + idx]) + 1, row[C_MISC - 1 + idx]))

        # Every converted effect must already be an aura application; a non-aura
        # effect here would mean the conversion table is pointed at the wrong
        # effect index.
        assert int(eff) in (SPELL_EFFECT_APPLY_AURA, 65, 128), \
            "spell effect %s at index %d is not an aura application" % (eff, idx)

        row[C_AURA - 1 + idx] = str(aura)
        row[C_MISC - 1 + idx] = str(misc)
        if pct is not None:
            # EffectBasePoints is stored as (value - 1); the core adds DieSides
            # back on.  DieSides is forced to 1 so the amount is exactly `pct`.
            row[C_BASEPOINTS - 1 + idx] = str(pct - 1)
            row[C_DIESIDES - 1 + idx] = "1"
        # A per-level ramp on a percentage is nonsense (+2.55 at level 255).
        row[C_RPPL - 1 + idx] = "0"

        after.append("E%d(eff=%s aura=%s bp=%s misc=%s)" % (
            idx, eff, row[C_AURA - 1 + idx],
            int(row[C_BASEPOINTS - 1 + idx]) + 1, row[C_MISC - 1 + idx]))
    return before, after


def sqlstr(v):
    """MySQL single-quoted literal.  Backslash is an escape character by default
    in MySQL, so it has to be doubled alongside the quote."""
    return "'" + v.replace(chr(92), chr(92) * 2).replace("'", "''") + "'"


def csv_to_sql(row):
    """232-col Spell.csv row -> 234-col spell_dbc row (see module docstring)."""
    v = row[0:13] + ["0"] + [row[13]] + ["0"] + row[14:]
    assert len(v) == 234, len(v)
    return v


def main():
    header, found = load_rows(SPELL_CSV, set(CONVERSIONS))
    assert len(header) == 232, "Spell.csv has %d columns, expected 232" % len(header)

    missing = sorted(set(CONVERSIONS) - set(found))
    if missing:
        sys.exit("FATAL: not present in Spell.csv: %s" % missing)

    report = []
    for sid in sorted(CONVERSIONS):
        label, spec, desc, auradesc = CONVERSIONS[sid]
        row = found[sid]
        before, after = convert(row, spec)
        row[C_DESC - 1] = desc
        row[C_AURADESC - 1] = auradesc
        report.append("  [%-6d] %-38s %s\n             %s-> %s"
                      % (sid, label, "  ".join(before), " " * 38, "  ".join(after)))

    os.makedirs(OUT, exist_ok=True)
    ids = sorted(CONVERSIONS)

    # --- review CSV --------------------------------------------------------
    review = os.path.join(OUT, "spell_csv_rows.csv")
    with open(review, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        for sid in ids:
            w.writerow(found[sid])

    # --- server-side SQL ---------------------------------------------------
    sql_path = os.path.join(OUT, "00_spell_dbc_buff_percent_scaling.sql")
    with open(sql_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(SQL_HEADER)
        f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (%s);\n\n"
                % ",".join(str(i) for i in ids))
        f.write("INSERT INTO `spell_dbc` VALUES\n")
        f.write(",\n".join("(" + ",".join(sqlstr(x) for x in csv_to_sql(found[sid])) + ")"
                           for sid in ids) + ";\n\n")
        f.write(SQL_GROUP_HEADER)
        f.write("DELETE FROM `spell_group` WHERE `id` = %d AND `spell_id` IN (%s);\n\n"
                % (KINGS_GROUP, ",".join(str(i) for i in KINGS_GROUP_ADDITIONS + KINGS_GROUP_STALE)))
        f.write("INSERT INTO `spell_group` (`id`, `spell_id`) VALUES\n")
        f.write(",\n".join("(%d, %d)" % (KINGS_GROUP, i) for i in KINGS_GROUP_ADDITIONS) + ";\n")

    # --- client-side CSV, patched in place ---------------------------------
    # Line-level replacement, not a csv round-trip: Spell.csv is 55 MB of
    # already-QUOTE_ALL rows and rewriting all 54,923 of them would bury 31 real
    # changes in a whole-file diff.  Verified safe -- the file is LF-terminated
    # and none of the target records contain an embedded newline, so each record
    # is exactly one line.
    if APPLY_CSV:
        rendered = {}
        for sid in ids:
            buf = io.StringIO()
            csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n").writerow(found[sid])
            rendered[('"%d"' % sid) + ","] = buf.getvalue()

        tmp = SPELL_CSV + ".tmp"
        replaced = 0
        with open(SPELL_CSV, encoding="utf-8", newline="") as src, \
                open(tmp, "w", encoding="utf-8", newline="") as dst:
            for line in src:
                for prefix, new in rendered.items():
                    if line.startswith(prefix):
                        line = new
                        replaced += 1
                        break
                dst.write(line)
        assert replaced == len(ids), "replaced %d rows, expected %d" % (replaced, len(ids))
        os.replace(tmp, SPELL_CSV)

    print("converted %d spells\n" % len(ids))
    print("\n".join(report))
    print("\n  SQL : %s" % sql_path)
    print("  CSV : %s" % review)
    print("  client Spell.csv: %s" % ("PATCHED IN PLACE" if APPLY_CSV else "not touched (pass --apply-csv)"))


SQL_HEADER = """-- ---------------------------------------------------------------------------
-- 00  Raid-buff percentage conversion for the 255 level cap
-- ---------------------------------------------------------------------------
-- Generated by Balance/tools/gen_buff_percent_scaling.py -- do not hand-edit.
--
-- PROBLEM.  Classic raid buffs apply SPELL_AURA_MOD_STAT (29), which the core
-- routes into TOTAL_VALUE (SpellAuraEffects.cpp:4226) while gear lands in
-- BASE_VALUE (Player.cpp:7057).  Unit::GetTotalStatValue combines them as
--     ((BASE_VALUE + CreateStat) * BASE_PCT + TOTAL_VALUE) * TOTAL_PCT
-- so the buff never scales with the gear pool.  Arcane Intellect's +60 Intellect
-- is ~5% of a level-80 raider, ~1% at the level-130 ceiling, and nothing at 255.
--
-- FIX.  Stat effects move to SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE (137), which
-- hits TOTAL_PCT and therefore multiplies gear.  137 rather than
-- SPELL_AURA_MOD_PERCENT_STAT (80) because handler 80 early-returns on
-- non-players (SpellAuraEffects.cpp:4248) -- pets would get nothing.  Attack
-- power moves to 166/167, flat max health to 133.
--
-- Values follow the MoP one-buff-per-category model:
--     all stats +10%   stamina/health +10%   intellect +10%   spirit +10%
--     attack power +10%   strength/agility +5%   food +3%
-- The all-stats category is 10% rather than MoP's 5% so that Blessing of Kings
-- (spell 20217, already aura 137 at 10% and already scaling correctly) is not
-- halved -- Mark of the Wild is matched upward to it instead.
--
-- Also included: DC Prestige auras 800010-800019 were SPELL_AURA_DUMMY, so the
-- percentage computed by dc_prestige_spells.cpp went nowhere and the entire
-- prestige stat bonus was inert.  Retyping them to 137 activates the existing
-- script with no code change.
--
-- NOT converted here, deliberately:
--   * Mark of the Wild's armor and resistance effects -- flat +750 armor is
--     already negligible at 255, and a percentage armor buff would be a large
--     unrequested buff to tanks.
--   * Mana regen (Blessing of Wisdom 48936/48938, Mana Spring 58777, aura 85
--     flat mp5).  The correct percentage depends on how gtRegenMPPerSpt was
--     regenerated for 255; picking one blind would be a guess.
--   * Shadow Protection / resistance buffs (aura 143).  Resistance is
--     effectively vestigial at this level cap.
--   * Well Fed 910122/910123 Spell Power and haste-rating effects -- neither
--     has a clean percentage aura in 3.3.5.
--
-- The matching CLIENT rows are written into Custom/CSV DBC/Spell.csv by the
-- same generator (--apply-csv) and need a Spell.dbc recompile plus a patch MPQ
-- redeploy before tooltips read correctly.
-- ---------------------------------------------------------------------------

"""

SQL_GROUP_HEADER = """
-- --- Mark of the Wild / Gift of the Wild join the Blessing of Kings group ---
-- Both families now carry aura 137 with EffectMiscValue -1.  Two such auras
-- MULTIPLY (HandleModTotalPercentStat -> GetTotalAuraMultiplier), so without
-- this a raid with both a druid and a paladin would get 1.10 * 1.10 = +21% to
-- every attribute.  Group 1006 already holds the Kings family with stack_rule 1.
--
-- These are the FIRST RANK of each chain (1126 Mark of the Wild, 21849 Gift of
-- the Wild), not the max ranks the spell_dbc block above converts.  LoadSpellGroups
-- erases any row whose spell has GetRank() > 1 --
--     "Spell {} listed in `spell_group` is not first rank of spell."
-- -- so listing 48469/48470 here would load cleanly enough to look right in the
-- SQL but leave the two buffs stacking at +21%.  The chain head covers every
-- rank regardless: GetSpellSpellGroupMapBounds resolves the looked-up spell
-- through GetFirstSpellInChain before consulting the group map.
--
-- The DELETE also clears 48469/48470, which an earlier revision of this file
-- inserted.  They are erased at load with an error apiece rather than applied,
-- so they never had any effect, but they persist in the table and repeat the
-- error on every startup until deleted.

"""


if __name__ == "__main__":
    main()
