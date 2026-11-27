#!/usr/bin/env python3
"""Downport the Cataclysm spells the Silverpine (Forsaken Front) C++ port depends on.

WHY THIS IS THE FIRST SLICE OF THAT PORT, not a script.
    zone_silverpine_forest.cpp (Project-Neltharion 4.3.4, 6,051 lines / 35 scripts)
    references 107 distinct SPELL_ constants. SEVENTY-SEVEN of them do not exist in this
    server's Spell.dbc -- including 83173 SPELL_RISE_FORSAKEN, the cast that triggers the
    entire Val'kyr raise sequence. Nothing in that cluster can even be tested until the
    spells land, so the spells come first.

    Of the 77: 67 are real Cataclysm spells present in the retail 4.3.4 client and are
    handled here. The other 10 -- 151111, 151235, 151316, 151318, 151319, 151321,
    151332-151335 -- are NOT in the client at any id. They sit far above the retail Cata
    range and are Neltharion-CUSTOM, so they have to be authored or substituted; this
    generator deliberately does not invent them.

METHOD -- follows the calibration recorded from HyjalCata/194_, not guesswork.
    Cataclysm split spell data out of Spell.dbc into per-aspect tables, so this is not the
    verbatim copy that Item.db2 was. Two source files, both in the LOCALE archive:
        K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ
          DBFilesClient/Spell.dbc        73,232 rows x 48 fields
          DBFilesClient/SpellEffect.dbc  97,356 rows x 27 fields
    (SpellMisc.dbc does not exist in 4.3.4 -- that is MoP+.)
    Both row counts were re-verified against the extract before generating.

    4.3.4 Spell.dbc column map (empirically calibrated, do not guess):
        1 Attributes | 2..8 -> AttributesEx..AttributesEx7 (9..11 exist in Cata, dropped)
        12 CastingTimeIndex | 13 DurationIndex | 14 PowerType | 15 RangeIndex
        16 Speed (float)    | 17/18 SpellVisualID | 19 SpellIconID | 20 ActiveIconID
        21 Name_lang        | 23 Description_lang | 25 SchoolMask

    SpellEffect.dbc: SpellID at col 24, EffectIndex at col 25, then
        1 Effect | 3 EffectAura | 4 EffectAuraPeriod | 5 EffectBasePoints
        12 EffectMiscValue | 13 EffectMiscValueB | 15 EffectRadiusIndex
        21 EffectTriggerSpell | 22/23 ImplicitTargetA/B

THE ONE TRANSFORM THAT MATTERS -- DieSides.
    3.3.5 computes an effect's value as BasePoints + rand(1..DieSides); Cataclysm dropped
    DieSides entirely. So every effect is written as DieSides = 1 and
    BasePoints = (cata value - 1). Copying the Cata value straight in with DieSides = 0 is
    off by one on every single spell.

SAFETY
    * spell_dbc is an OVERLAY and it WINS over the binary DBC, so minting a row for a spell
      that already resolves would override a correct stock spell globally. Every id here was
      confirmed absent from the binary Spell.dbc (54,027 rows) first -- the binary is the
      oracle, not the spell_dbc table, which is sparse.
    * spell_dbc has 234 columns and every one has a default, so a partial INSERT naming
      only what matters is correct and intentional.
    * Strings are escaped through the driver rules -- a stray apostrophe in a spell name is
      a 1064 at apply time.

SERVER-SIDE ONLY. This makes the SERVER resolve the spells, which is what unblocks the
scripts. The client shows no icon or tooltip until Spell.dbc itself is rebuilt and deployed
with spell-dbc-append.py -- and NOT csv2wdbc, which would destroy this fork's custom
234-field layout.
"""
import os, struct

CATA = r"K:/tmp/_cataspell"
OUT = os.path.join(r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs",
                   "worlddb", "Plaguelands", "112_silverpine_spells.sql")
OURS = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/DBCs/Spell.dbc"
NL = chr(10)
APOS = chr(39)
BT = chr(96)

# the 77 the port needs; the 151xxx block is filtered out by "not in the client"
NEEDED = [74279,76520,78638,79584,79854,79856,79857,80808,81876,83149,83173,83594,83751,
 83762,83768,83769,83839,83843,83903,83927,83982,83993,84012,84013,84014,84053,84181,84182,
 84200,84467,84474,84941,84944,85197,85198,85200,85201,85240,85373,85379,85400,85451,85517,
 85518,85519,85581,85584,85864,85868,85869,85870,85871,85874,85877,85878,85925,85926,85927,
 85950,85952,85965,87239,87249,87251,87253,87255,93199,151111,151235,151316,151318,151319,
 151321,151332,151333,151334,151335]

# 4.3.4 Spell.dbc
S_ATTR0 = 1
S_CAST, S_DUR, S_POWER, S_RANGE, S_SPEED = 12, 13, 14, 15, 16
S_VIS1, S_VIS2, S_ICON, S_ACTIVEICON = 17, 18, 19, 20
S_NAME, S_DESC, S_SCHOOL = 21, 23, 25
# SpellEffect.dbc
E_SPELLID, E_INDEX = 24, 25
E_EFFECT, E_AURA, E_PERIOD, E_BASE = 1, 3, 4, 5
E_MISC, E_MISCB, E_RADIUS, E_TRIGGER, E_TGTA, E_TGTB = 12, 13, 15, 21, 22, 23


def load(p):
    d = open(p, "rb").read()
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    return d, rc, fc, rs, 20 + rc * rs


def rd(d, off, col):
    return struct.unpack_from("<i", d, off + col * 4)[0]


def rdf(d, off, col):
    return struct.unpack_from("<f", d, off + col * 4)[0]


def rds(d, sb, off, col):
    o = struct.unpack_from("<I", d, off + col * 4)[0]
    if o == 0:
        return ""
    e = d.find(b"\0", sb + o)
    return d[sb + o:e].decode("utf-8", "replace") if e >= 0 else ""


def esc(s):
    """SQL-standard apostrophe doubling, NOT backslash escaping.

    Backslash escaping is wrong under NO_BACKSLASH_ESCAPES; doubling the apostrophe is
    the ANSI form and holds either way. This batch happens to contain zero apostrophes
    and zero backslashes across all 67 names and descriptions (asserted below), so the
    function is a no-op today -- it is correct here so a re-run on different spells
    cannot produce a 1064 at apply time.
    """
    assert chr(92) not in s, "backslash in a spell string, needs a mode-aware escape: %r" % s
    return s.replace(APOS, APOS * 2)


def main():
    d, rc, fc, rs, sb = load(os.path.join(CATA, "Spell.dbc"))
    assert (rc, fc) == (73232, 48), "Cata Spell.dbc is %d x %d, expected 73232 x 48" % (rc, fc)
    e, erc, efc, ers, esb = load(os.path.join(CATA, "SpellEffect.dbc"))
    assert (erc, efc) == (97356, 27), "SpellEffect.dbc is %d x %d, expected 97356 x 27" % (erc, efc)

    o_d, o_rc, o_fc, o_rs, _ = load(OURS)
    ours = set(struct.unpack_from("<I", o_d, 20 + i * o_rs)[0] for i in range(o_rc))
    print("our Spell.dbc: %d rows (the oracle)" % o_rc)

    idx = {}
    for i in range(rc):
        idx[struct.unpack_from("<I", d, 20 + i * rs)[0]] = 20 + i * rs

    eff = {}
    for i in range(erc):
        off = 20 + i * ers
        sid = struct.unpack_from("<I", e, off + E_SPELLID * 4)[0]
        if sid in idx:
            eff.setdefault(sid, {})[rd(e, off, E_INDEX)] = off

    todo, absent, already = [], [], []
    for s in NEEDED:
        if s in ours:
            already.append(s)
        elif s not in idx:
            absent.append(s)
        else:
            todo.append(s)
    print("to downport: %d | not in the Cata client: %d | already resolve here: %d"
          % (len(todo), len(absent), len(already)))
    assert not already, "these already resolve, minting would override stock: %s" % already

    L = []
    w = L.append
    w("-- 112_silverpine_spells.sql -- Cata spell prerequisite for the Silverpine port, DB step 51.")
    w("--")
    w("-- GENERATED by Custom/Documentation/scripts/gen_silverpine_spell_downport.py.")
    w("--")
    w("-- THE FIRST SLICE OF THE SILVERPINE / FORSAKEN FRONT PORT IS SPELLS, NOT SCRIPTS.")
    w("--   zone_silverpine_forest.cpp (Neltharion 4.3.4, 6,051 lines / 35 scripts) references")
    w("--   107 distinct spell constants and 77 of them do not exist on this server --")
    w("--   including 83173 SPELL_RISE_FORSAKEN, the cast that triggers the whole Val'kyr")
    w("--   raise. Nothing in that cluster is testable until these land.")
    w("--")
    w("--   %d are real Cataclysm spells and are downported here." % len(todo))
    w("--   %d are NOT in the retail client at any id and are NOT invented here:" % len(absent))
    w("--     " + " ".join(str(x) for x in absent))
    w("--   They sit far above the retail Cata range and are Neltharion-CUSTOM, so they need")
    w("--   authoring or substitution as a separate decision.")
    w("--")
    w("-- SOURCE, both from the LOCALE archive (Cata keeps these there, like Vehicle.dbc):")
    w("--   K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ")
    w("--     DBFilesClient/Spell.dbc        73,232 x 48   (asserted at generate time)")
    w("--     DBFilesClient/SpellEffect.dbc  97,356 x 27   (asserted at generate time)")
    w("--   Cataclysm split spell data across per-aspect tables, so this is a RECONSTRUCTION,")
    w("--   not the verbatim copy Item.db2 allowed. Column map calibrated in HyjalCata/194_.")
    w("--")
    w("-- THE TRANSFORM THAT MATTERS: 3.3.5 computes an effect as BasePoints + rand(1..DieSides)")
    w("--   and Cataclysm dropped DieSides. Every effect below is written as DieSides = 1 with")
    w("--   BasePoints = (cata value - 1). Copying the Cata value in with DieSides = 0 is off")
    w("--   by one on every spell.")
    w("--")
    w("-- SAFETY: spell_dbc is an OVERLAY and WINS over the binary DBC, so a row for a spell")
    w("--   that already resolves would override stock globally. Every id here was confirmed")
    w("--   absent from the BINARY Spell.dbc (%d rows) -- the binary is the oracle; the" % o_rc)
    w("--   spell_dbc table is sparse and reports false positives (see 108_).")
    w("--")
    w("-- SERVER-SIDE ONLY. The server resolves these immediately; the CLIENT shows no icon or")
    w("--   tooltip until Spell.dbc is rebuilt with spell-dbc-append.py. Do NOT use csv2wdbc --")
    w("--   this fork's Spell.dbc is a custom 234-field layout and csv2wdbc would destroy it.")
    w("")
    w("DELETE FROM " + BT + "spell_dbc" + BT + " WHERE " + BT + "ID" + BT + " IN (%s);"
      % ",".join(str(x) for x in todo))
    w("")

    cols = ["ID", "Attributes", "AttributesEx", "AttributesEx2", "AttributesEx3",
            "AttributesEx4", "AttributesEx5", "AttributesEx6", "AttributesEx7",
            "CastingTimeIndex", "DurationIndex", "PowerType", "RangeIndex", "Speed",
            "SpellVisualID_1", "SpellVisualID_2", "SpellIconID", "ActiveIconID",
            "SchoolMask", "ProcChance", "EquippedItemClass",
            "Name_Lang_enUS", "Name_Lang_enGB", "Description_Lang_enUS", "Description_Lang_enGB"]
    for n in (1, 2, 3):
        cols += ["Effect_%d" % n, "EffectAura_%d" % n, "EffectAuraPeriod_%d" % n,
                 "EffectBasePoints_%d" % n, "EffectDieSides_%d" % n,
                 "EffectMiscValue_%d" % n, "EffectMiscValueB_%d" % n,
                 "EffectRadiusIndex_%d" % n, "EffectTriggerSpell_%d" % n,
                 "ImplicitTargetA_%d" % n, "ImplicitTargetB_%d" % n]

    w("INSERT INTO " + BT + "spell_dbc" + BT + " (" + ", ".join(BT + c + BT for c in cols) + ") VALUES")

    rows, neff = [], 0
    for s in todo:
        off = idx[s]
        name = rds(d, sb, off, S_NAME)
        desc = rds(d, sb, off, S_DESC)
        v = [s]
        for k in range(0, 8):
            v.append(rd(d, off, S_ATTR0 + k) & 0xFFFFFFFF)
        v += [rd(d, off, S_CAST), rd(d, off, S_DUR), rd(d, off, S_POWER), rd(d, off, S_RANGE)]
        v.append("%.6g" % rdf(d, off, S_SPEED))
        v += [rd(d, off, S_VIS1), rd(d, off, S_VIS2), rd(d, off, S_ICON),
              rd(d, off, S_ACTIVEICON), rd(d, off, S_SCHOOL) & 0xFFFFFFFF, 101, -1]
        v += [APOS + esc(name) + APOS, APOS + esc(name) + APOS,
              APOS + esc(desc) + APOS, APOS + esc(desc) + APOS]
        for n in (1, 2, 3):
            eo = eff.get(s, {}).get(n - 1)
            if eo is None:
                v += [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            else:
                neff += 1
                v += [rd(e, eo, E_EFFECT), rd(e, eo, E_AURA), rd(e, eo, E_PERIOD),
                      rd(e, eo, E_BASE) - 1,          # the DieSides shift
                      1,
                      rd(e, eo, E_MISC), rd(e, eo, E_MISCB), rd(e, eo, E_RADIUS),
                      rd(e, eo, E_TRIGGER), rd(e, eo, E_TGTA), rd(e, eo, E_TGTB)]
        rows.append(("(" + ", ".join(str(x) for x in v) + ")", esc(name)))

    # THE SEPARATOR GOES BEFORE THE COMMENT, NOT AFTER IT.
    # Writing "(values)   -- name" and then joining on "," puts the comma INSIDE the
    # trailing comment, so MySQL never sees the row separator and the next "(" reads as
    # a new statement -- a 1064 on line 3 that points at the SECOND row while the real
    # fault is the end of the first. Emit the comma/semicolon immediately after ")".
    values_lo = len(L)
    for i, (vals, name) in enumerate(rows):
        w(vals + (";" if i == len(rows) - 1 else ",") + "   -- " + name)
    values_hi = len(L)
    w("")
    w("-- ---------------------------------------------------------------------------")
    w("-- Verification")
    w("-- ---------------------------------------------------------------------------")
    w("SELECT 'spells downported (want %d)' AS what, COUNT(*) AS n" % len(todo))
    w("  FROM " + BT + "spell_dbc" + BT + " WHERE " + BT + "ID" + BT + " IN (%s)"
      % ",".join(str(x) for x in todo))
    w("UNION ALL SELECT '  ...with at least one effect (want %d)', COUNT(*)"
      % sum(1 for s in todo if eff.get(s)))
    w("  FROM " + BT + "spell_dbc" + BT + " WHERE " + BT + "ID" + BT + " IN (%s) AND "
      % ",".join(str(x) for x in todo) + BT + "Effect_1" + BT + " <> 0")
    w("UNION ALL SELECT '  ...every effect row has DieSides = 1 (want 0 violations)', COUNT(*)")
    w("  FROM " + BT + "spell_dbc" + BT + " WHERE " + BT + "ID" + BT + " IN (%s)"
      % ",".join(str(x) for x in todo))
    w("    AND ((" + BT + "Effect_1" + BT + " <> 0 AND " + BT + "EffectDieSides_1" + BT + " <> 1)")
    w("      OR (" + BT + "Effect_2" + BT + " <> 0 AND " + BT + "EffectDieSides_2" + BT + " <> 1)")
    w("      OR (" + BT + "Effect_3" + BT + " <> 0 AND " + BT + "EffectDieSides_3" + BT + " <> 1))")
    w("UNION ALL SELECT 'the raise trigger 83173 is present (want 1)', COUNT(*)")
    w("  FROM " + BT + "spell_dbc" + BT + " WHERE " + BT + "ID" + BT + " = 83173;")

    # ---------------------------------------------------------------------
    # Gate: refuse to write SQL with the comment traps this file has hit.
    # ---------------------------------------------------------------------
    # Structural checks 2 and 3 apply ONLY to the VALUES rows. A verification SELECT
    # legitimately spans lines with unbalanced parens and no trailing separator, so
    # running them file-wide produces pure noise (it did on the first attempt).
    import re
    bad = []
    for n, line in enumerate(L, 1):
        # 1. file-wide: a separator swallowed by a trailing comment -- the 1064 that shipped
        if not line.lstrip().startswith("--") and re.search(r"--[^\n]*[,;]\s*$", line):
            bad.append((n, "separator inside the trailing comment", line[:80]))
    for n in range(values_lo, values_hi):
        line = L[n]
        code = line.split("--", 1)[0]
        # 2. every value row must end in , or ; after its closing paren
        if not re.search(r"\)\s*[,;]\s*$", code):
            bad.append((n + 1, "value row with no , or ; after the closing paren", line[:80]))
        # 3. and must be self-balanced
        if code.count("(") != code.count(")"):
            bad.append((n + 1, "unbalanced parentheses", line[:80]))
    if bad:
        for n, why, txt in bad[:10]:
            print("  GATE line %d: %s -- %s" % (n, why, txt))
        raise SystemExit("refusing to write: %d bad line(s)" % len(bad))
    txt = NL.join(L)
    assert ";;" not in txt, "double semicolon"
    assert txt.count("(") == txt.count(")"), "unbalanced parentheses overall"

    open(OUT, "w", encoding="utf-8", newline=NL).write(txt + NL)
    print("gate: passed (%d lines checked)" % len(L))
    print("wrote %s" % OUT)
    print("  %d spells, %d effect rows, %d SQL lines" % (len(todo), neff, len(L)))
    print("  NOT downported (Neltharion-custom): %s" % absent)


main()
