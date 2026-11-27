#!/usr/bin/env python3
"""
gen_pet_family_abilities.py - the hunter pet families added after WotLK, with their real abilities.

Supersedes the first wiring pass (../rev_1791304116069959900.sql, generated outside the repo), which
gave these families stock 3.3.5 specials as stand-ins. Emits:

  1. pet_family_abilities.csv (232-col Spell CSV rows) next to this script
  2. Custom/DBCs/Spell.dbc via spell-dbc-append.py (backup .pre-petfamilies.bak), checked by a gate:
     every old record byte-identical except Feed Pet 6991, whose Description is the only change
     - NEVER csv2wdbc: the fork Spell.dbc is the 234-field layout
  3. the same rows appended to Custom/CSV DBC/Spell.csv, and 6991's description replaced in place
  4. four SpellIcon rows appended to Custom/DBCs/SpellIcon.dbc (ids continue the custom band)
  5. Custom/CSV DBC/CreatureFamily.csv rows 50-60 set to the values below
  6. --sql: the server delta (spell_dbc, spell_proc, spell_script_names, skilllineability_dbc,
     creaturefamily_dbc)

Families (skill line ids: Cata for 808/811/817, retail for the rest; talent tree as retail for the
five post-Cata families; basic attack Bite for all, as both Cata and retail have it):

  50 Fox          808  Ferocity  Tailspin        90314 (+ debuff 90315)   Cata 4.3
  52 Dog          811  Ferocity  Lock Jaw        90327                    Cata 4.3 (root)
  55 Shale Spider 817  Tenacity  Web Wrap        96201                    Cata 4.3
  56 Direhorn     1305 Tenacity  Gore            263861 (+ Mortal Wounds 115804)   retail 12.1
  57 Feathermane  2361 Tenacity  Feather Flurry  263916                   retail 12.1
  58 Mechanical   2189 Cunning   Defense Matrix  263868                   retail 12.1
  59 Quilen       986  Tenacity  Stone Armor     160049 (+ effect 160048) retail 12.1
  60 Blood Beast  2719 Tenacity  Blood Bolt      288962                   retail 12.1

Every spell is a clone of the stock 3.3.5 pet ability closest in shape (Cata itself built Tailspin,
Lock Jaw and Web Wrap from Dust Cloud, Pin and Web), with the donor's mechanics, numbers, levels,
names and tooltips. Effect slots are written in full; everything per-effect not set here is zeroed.
Cooldowns, durations and levels are the donor's; focus cost is 0 as in the donors. Visuals are 3.3.5
ones (Cata/retail visual ids do not exist in this client): Dust Cloud for Tailspin, Pin for Lock
Jaw, Web for Web Wrap, boar Gore for Gore, Shield Generator 64677 for Defense Matrix, Flash Feathery
Explosion 39180 for Feather Flurry, Stoneform 20594 for Stone Armor, Twilight Bloodbolt 71446 for
Blood Bolt. Stone Armor's 40% health threshold needs src/server/scripts/DC/Pets/
dc_hunter_pet_abilities.cpp.

CategoryEnumID is client-only (the server's CreatureFamily format skips it): Talent.dbc CategoryMask
picks the per-family movement talents, so each family borrows the id of a stock family of the same
tree that has them (Ferocity land: Hyena 10 / Wolf 23; Tenacity: Boar 3, Bear 1, Turtle 21,
Crocolisk 7, Scorpid 15; Cunning land: Spider 17).

Verified constants (SharedDefines.h, SpellAuraDefines.h)
  effects  APPLY_AURA=6  TRIGGER_SPELL=64  DUMMY=3
  auras    STUN=12  OBS_MOD_HEALTH=20  ROOT=26  DECREASE_SPEED=33  PROC_TRIGGER_SPELL=42
           MOD_DODGE_PERCENT=49  DAMAGE_PERCENT_TAKEN=87  MOD_HEALING_PCT=118  MELEE_RANGED_HASTE=192
  targets  CASTER=1  TARGET_ENEMY=6  SRC_CASTER=22  SRC_AREA_ENEMY=15  DEST_TARGET_ENEMY=53
           DEST_AREA_ENEMY=16
  mechanic ROOT=7  SLOW_ATTACK=8  SNARE=11  STUN=12
  duration 1=10s 8=15s 9=30s 18=20s 27=3s 29=12s 32=6s 35=4s     range 1=self 2=melee 6=100y 7=10y
  attr0    AURA_IS_DEBUFF=0x04000000
An effect's value is BasePoints + DieSides here: bp=-51 die=1 yields -50.
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
FAMILY_CSV = os.path.join(REPO, "Custom", "CSV DBC", "CreatureFamily.csv")
SPELL_DBC = os.path.join(REPO, "Custom", "DBCs", "Spell.dbc")
ICON_DBC = os.path.join(REPO, "Custom", "DBCs", "SpellIcon.dbc")
SLA_DBC = os.path.join(REPO, "Custom", "DBCs", "SkillLineAbility.dbc")
APPEND = r"K:\Dark-Chaos\wow.export-main\tools\spell-dbc-append.py"
WORGOBLIN_10 = os.path.join(REPO, "Custom", "Custom feature SQLs", "worlddb", "Worgoblin", "10_spell_dbc.sql")
OUT_CSV = os.path.join(HERE, "pet_family_abilities.csv")
BAK = ".pre-petfamilies.bak"

FEED_PET = 6991
FEED_PET_OLD = ("Feed your pet the selected item.  Feeding your pet increases happiness.  "
                "Using food close to the pet's level will have a better result.")
FEED_PET_NEW = "Feed your pet the selected item, instantly restoring 50% of its total health. Not usable in combat."

ICONS = {
    "tailspin": (514646, r"Interface\Icons\INV_Misc_MonsterTail_01"),
    "gore":     (514647, r"Interface\Icons\inv_pet_direhorn"),
    "stone":    (514648, r"Interface\Icons\achievement_moguraid_01"),
    "bloodbolt": (514649, r"Interface\Icons\artifactability_blooddeathknight_umbilicuseternus"),
}

# donor spell id -> role
TEMPLATES = {50285: "dustcloud", 54404: "dustcloud_debuff", 50245: "pin", 4167: "web", 35290: "gore",
             26064: "shellshield", 53186: "passive_proc", 35387: "poisonspit"}

# Skill line ability donors (stock 3.3.5 rows, copied with the skill line replaced)
BITE = (208, [17253, 17255, 17256, 17257, 17258, 17259, 17260, 17261, 27050, 52473, 52474])
DASH_CHARGE = (208, [61684, 61685])     # Wolf: Ferocity land
DASH = (203, [61684])                   # Spider: Cunning land
CHARGE = (214, [61685])                 # Crab: Tenacity

# family, name, skill line, line name, PetTalentType, CategoryEnumID, special, passive donor, movement
FAMILIES = [
    (50, "Fox", 808, "Pet - Fox", 0, 10, 90314, (218, [17220]), DASH_CHARGE),
    (52, "Dog", 811, "Pet - Dog", 0, 23, 90327, (214, [17211]), DASH_CHARGE),
    (55, "Shale Spider", 817, "Pet - Exotic Shale Spider", 1, 15, 96201, (203, [17219]), CHARGE),
    (56, "Direhorn", 1305, "Pet - Direhorn", 1, 3, 263861, (211, [7000]), CHARGE),
    (57, "Feathermane", 2361, "Pet - Feathermane", 1, 1, 263916, (655, [17216]), CHARGE),
    (58, "Mechanical", 2189, "Pet - Mechanical", 2, 17, 263868, (251, [17221]), DASH),
    (59, "Quilen", 986, "Pet - Exotic Quilen", 1, 21, 160049, (251, [17221]), CHARGE),
    (60, "Blood Beast", 2719, "Pet - Blood Beast", 1, 7, 288962, (654, [17215]), CHARGE),
]
FIRST_SLA_ID = 31600
LAST_SLA_ID = 31799          # the delete range also covers the first pass (31600-31738)

STONE_ARMOR_SCRIPT = "spell_pet_quilen_stone_armor"


def effect(slot, **kw):
    return {"%s_%d" % (k, slot): v for k, v in kw.items()}


def spells():
    """(template role, overrides) per new spell; text keys: name, sub, desc, aura."""
    tailspin_desc = ("Your fox twirls its tail around, kicking up an obscuring cloud of dust, causing all "
                     "enemies within $90314a1 yards to have their melee and ranged attack speed reduced by "
                     "$90315s1% for $90315d.")
    stone_armor = ("When falling below $s2% health, the Quilen's skin will change to stone, causing it to take "
                   "$160048s1% less damage and regenerate $160048s2% of its maximum health every $160048t2 sec "
                   "for $160048d.\r\n\r\nThis effect can only occur once every $s3 sec.")
    return [
        ("dustcloud", dict(
            ID=90314, name="Tailspin", sub="Special Ability", desc=tailspin_desc, aura="",
            RecoveryTime=25000, BaseLevel=30, SpellLevel=30, ManaCost=0, SpellIconID=ICONS["tailspin"][0],
            **effect(1, Effect=64, EffectBasePoints=-1, EffectDieSides=1, ImplicitTargetA=53,
                     ImplicitTargetB=16, EffectRadiusIndex=13, EffectTriggerSpell=90315))),
        ("dustcloud_debuff", dict(
            ID=90315, name="Tailspin", sub="", desc=tailspin_desc,
            aura="Melee and ranged attack speed reduced by $s1%.",
            ProcTypeMask=0, ProcChance=101, ProcCharges=0, DurationIndex=9, SpellIconID=ICONS["tailspin"][0],
            **effect(1, Effect=6, EffectAura=192, EffectBasePoints=-21, EffectDieSides=1, EffectMechanic=8,
                     ImplicitTargetA=22, ImplicitTargetB=15, EffectRadiusIndex=13))),
        ("pin", dict(
            ID=90327, name="Lock Jaw", sub="Special Ability",
            desc="Dog locks its jaws on the target, holding it in place for $d.", aura="Locked in place.",
            BaseLevel=20, SpellLevel=20, SpellIconID=2253,
            **effect(1, Effect=6, EffectAura=26, EffectBasePoints=-1, EffectDieSides=1, ImplicitTargetA=6))),
        ("web", dict(
            ID=96201, name="Web Wrap", sub="Special Ability",
            desc="Encases the target in sticky webs, stunning them for $d.", aura="Webbed.",
            Mechanic=12, RecoveryTime=45000, BaseLevel=20, SpellLevel=20, DurationIndex=27,
            **effect(1, Effect=6, EffectAura=12, EffectBasePoints=0, EffectDieSides=0, ImplicitTargetA=6))),
        ("gore", dict(
            ID=263861, name="Gore", sub="Special Ability",
            desc=("The Direhorn drives its horns into the target, causing the Mortal Wounds effect.\r\n\r\n"
                  "|cFFFFFFFFMortal Wounds|r\r\nGrievously wounds the target, reducing the effectiveness of "
                  "any healing received for $115804d."),
            aura="", RecoveryTime=6000, ManaCost=0, BaseLevel=1, SpellLevel=1, SpellIconID=ICONS["gore"][0],
            **effect(1, Effect=64, EffectBasePoints=-1, EffectDieSides=1, ImplicitTargetA=6,
                     EffectTriggerSpell=115804))),
        ("web", dict(
            ID=115804, name="Mortal Wounds", sub="",
            desc="Grievously wounds the target, reducing the effectiveness of any healing received for $d.",
            aura="Healing effects received reduced by $s1%.",
            DispelType=0, Mechanic=0, Attributes=327696 | 0x04000000, AttributesEx=512, RecoveryTime=0,
            BaseLevel=0, SpellLevel=0, DurationIndex=1, PowerType=0, ManaCost=0, RangeIndex=6, SpellIconID=138,
            SpellVisualID_1=0, SpellClassSet=0, SpellClassMask_1=0, SpellClassMask_2=0, SpellClassMask_3=0,
            DefenseType=0, PreventionType=0, SchoolMask=1,
            **effect(1, Effect=6, EffectAura=118, EffectBasePoints=-51, EffectDieSides=1, EffectMiscValue=127,
                     ImplicitTargetA=6))),
        ("shellshield", dict(
            ID=263916, name="Feather Flurry", sub="Special Ability",
            desc=("The Feathermane flaps wildly, flinging feathers into the air that distract its enemies, "
                  "increasing dodge chance by $s1% for $d."),
            aura="Dodge chance increased by $s1%.",
            RecoveryTime=90000, BaseLevel=8, SpellLevel=8, DurationIndex=18, SpellIconID=2378, SpellVisualID_1=8456,
            **effect(1, Effect=6, EffectAura=49, EffectBasePoints=29, EffectDieSides=1, EffectMiscValue=0,
                     ImplicitTargetA=1))),
        ("shellshield", dict(
            ID=263868, name="Defense Matrix", sub="Special Ability",
            desc=("The Mechanical contraption creates a personal defense matrix around itself, reducing damage "
                  "taken by $s1% for $d."),
            aura="Damage reduced by $s1%.",
            BaseLevel=14, SpellLevel=14, SpellIconID=3845, SpellVisualID_1=13707,
            **effect(1, Effect=6, EffectAura=87, EffectBasePoints=-51, EffectDieSides=1, EffectMiscValue=127,
                     ImplicitTargetA=1))),
        ("passive_proc", dict(
            ID=160049, name="Stone Armor", sub="Special Ability", desc=stone_armor, aura="",
            ProcTypeMask=664232, ProcChance=100, ProcCharges=0, BaseLevel=14, SpellLevel=14, RangeIndex=1,
            SpellIconID=ICONS["stone"][0], SpellClassSet=9, SpellClassMask_1=0, SpellClassMask_2=268435456,
            SpellClassMask_3=0,
            **effect(1, Effect=6, EffectAura=42, EffectBasePoints=-1, EffectDieSides=1, ImplicitTargetA=1,
                     EffectTriggerSpell=160048),
            **effect(2, Effect=3, EffectBasePoints=39, EffectDieSides=1, ImplicitTargetA=1),
            **effect(3, Effect=3, EffectBasePoints=119, EffectDieSides=1, ImplicitTargetA=1))),
        ("shellshield", dict(
            ID=160048, name="Stone Armor", sub="",
            desc=("The quilen's skin turns to stone, reducing all damage taken by $s1% and causes the quilen to "
                  "heal for $s2% of its maximum health every $t2 sec for $d."),
            aura="Damage taken reduced by $s1%.\r\nHealing for $s2% of maximum health every $t2 sec.",
            RecoveryTime=0, BaseLevel=0, SpellLevel=0, DurationIndex=8, SpellIconID=ICONS["stone"][0],
            SpellVisualID_1=5787,
            **effect(1, Effect=6, EffectAura=87, EffectBasePoints=-41, EffectDieSides=1, EffectMiscValue=127,
                     ImplicitTargetA=1),
            **effect(2, Effect=6, EffectAura=20, EffectBasePoints=2, EffectDieSides=1, EffectAuraPeriod=1000,
                     ImplicitTargetA=1))),
        ("poisonspit", dict(
            ID=288962, name="Blood Bolt", sub="Special Ability",
            desc="The blood beast belches blood at the target, reducing movement speed by $s1% for $d.",
            aura="Movement speed reduced by $s1%.",
            Category=0, CategoryRecoveryTime=0, RecoveryTime=10000, DispelType=0, Mechanic=11, AttributesExE=0,
            BaseLevel=14, SpellLevel=14, DurationIndex=32, ManaCost=0, RangeIndex=7, Speed=20,
            SpellIconID=ICONS["bloodbolt"][0], SpellVisualID_1=15168, DefenseType=2, PreventionType=2,
            SchoolMask=1,
            **effect(1, Effect=6, EffectAura=33, EffectBasePoints=-51, EffectDieSides=1, EffectMechanic=11,
                     ImplicitTargetA=6))),
    ]


def read_wdbc(path):
    d = open(path, "rb").read()
    magic, rc, fc, rs, ss = struct.unpack_from("<4s4I", d, 0)
    assert magic == b"WDBC", path
    recs = [d[20 + i * rs:20 + (i + 1) * rs] for i in range(rc)]
    return recs, fc, rs, d[20 + rc * rs:20 + rc * rs + ss]


def resolve(sb, off):
    return sb[off:sb.index(b"\0", off)].decode("utf-8", "replace")


def spell_gate(old_path, new_path, new_ids):
    """Every old record byte-identical except FEED_PET (Description_Lang_enUS only); exactly new_ids added."""
    old, fc, rs, osb = read_wdbc(old_path)
    new, fc2, rs2, nsb = read_wdbc(new_path)
    assert (fc, rs) == (fc2, rs2) == (234, 936), (fc, rs, fc2, rs2)
    str_idx = {s + k for s in (136, 153, 170, 187) for k in range(16)}
    old_ids = [struct.unpack_from("<I", r)[0] for r in old]
    new_ids_all = [struct.unpack_from("<I", r)[0] for r in new]
    assert new_ids_all[:len(old_ids)] == old_ids, "record order changed"
    assert sorted(new_ids_all[len(old_ids):]) == sorted(new_ids), "unexpected added ids"
    problems = []
    for i, sid in enumerate(old_ids):
        if old[i] == new[i]:
            continue
        a = struct.unpack("<234I", old[i])
        b = struct.unpack("<234I", new[i])
        for f in range(234):
            va = resolve(osb, a[f]) if f in str_idx else a[f]
            vb = resolve(nsb, b[f]) if f in str_idx else b[f]
            if va != vb and not (sid == FEED_PET and f == 170):
                problems.append((sid, f, va, vb))
        if sid != FEED_PET:
            problems.append((sid, "bytes", "changed", ""))
    if problems:
        raise SystemExit("SPELL.DBC GATE FAILED: %s" % problems[:20])
    print("Spell.dbc gate: %d old records intact (6991 description only), %d added" % (len(old_ids), len(new_ids)))


def append_spell_icons(path):
    b = open(path, "rb").read()
    magic, n, f, rs, ss = struct.unpack_from("<4s4I", b, 0)
    assert magic == b"WDBC" and f == 2 and rs == 8, (magic, f, rs)
    recs = [struct.unpack_from("<II", b, 20 + i * rs) for i in range(n)]
    strings = bytearray(b[20 + n * rs:20 + n * rs + ss])
    clash = [i for i, _ in ICONS.values() if i in {r[0] for r in recs}]
    if clash:
        raise SystemExit("REFUSING: SpellIcon ids already used: %s" % clash)
    for rid, name in sorted(ICONS.values()):
        recs.append((rid, len(strings)))
        strings += name.encode("ascii") + b"\0"
    bak = path + BAK
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(path, bak)
    out = struct.pack("<4s4I", b"WDBC", len(recs), 2, 8, len(strings))
    out += b"".join(struct.pack("<II", *r) for r in recs) + bytes(strings)
    open(path, "wb").write(out)
    print("SpellIcon.dbc: +%d rows (%d -> %d)" % (len(ICONS), n, len(recs)))


def skill_line_rows():
    recs, fc, rs, _ = read_wdbc(SLA_DBC)
    assert fc == 14, fc
    stock = [struct.unpack("<14I", r) for r in recs]
    rows, next_id = [], FIRST_SLA_ID
    for fam, name, line, line_name, _, _, special, passive, movement in FAMILIES:
        group = []
        for donor_line, spell_ids in (BITE, passive, movement):
            for sid in spell_ids:
                hits = [r for r in stock if r[1] == donor_line and r[2] == sid]
                assert len(hits) == 1, (name, donor_line, sid, len(hits))
                group.append(list(hits[0]))
        # the family special: learned with the skill line, single rank
        group.insert(len(BITE[1]), [0, 0, special, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0])
        for row in group:
            row[0], row[1] = next_id, line
            rows.append((line, line_name, row))
            next_id += 1
    assert next_id - 1 <= LAST_SLA_ID, next_id
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sql", required=True, help="pending_db_world rev file to write the server delta into")
    a = ap.parse_args()

    with open(SPELL_CSV, encoding="utf-8", newline="") as fh:
        rd = csv.reader(fh)
        hdr = next(rd)
        ix = {n: i for i, n in enumerate(hdr)}
        tpl, feed_pet = {}, None
        new_ids = {o["ID"] for _, o in spells()}
        for r in rd:
            sid = int(r[0])
            if sid in TEMPLATES:
                tpl[TEMPLATES[sid]] = r
            if sid in new_ids:
                raise SystemExit("REFUSING: spell %d already in Spell.csv" % sid)
            if sid == FEED_PET:
                feed_pet = r
    assert len(hdr) == 232, len(hdr)
    missing = set(TEMPLATES.values()) - set(tpl)
    if missing:
        raise SystemExit("template spells missing from Spell.csv: %s" % sorted(missing))

    loc_cols = [c for c in hdr if re.match(r"(Name|NameSubtext|Description|AuraDescription)_Lang_(?!Mask)", c)]
    reagent_cols = [c for c in hdr if c.startswith(("Reagent_", "ReagentCount_"))]
    # per-effect columns zeroed unless set; EffectChainAmplitude keeps the stock 1.0
    slot_cols = [c for c in hdr if re.match(r"(Effect|ImplicitTarget).*_[123]$", c)
                 and not c.startswith("EffectChainAmplitude")]

    rows = []
    for role, over in spells():
        r = list(tpl[role])
        for c in loc_cols:
            r[ix[c]] = ""
        for c in reagent_cols:
            r[ix[c]] = "0"
        for c in slot_cols:
            r[ix[c]] = "0"
        over = dict(over)
        r[ix["Name_Lang_enUS"]] = over.pop("name")
        r[ix["NameSubtext_Lang_enUS"]] = over.pop("sub")
        r[ix["Description_Lang_enUS"]] = over.pop("desc")
        r[ix["AuraDescription_Lang_enUS"]] = over.pop("aura")
        for k, v in over.items():
            r[ix[k]] = str(v)
        for s in (1, 2, 3):
            eff = int(r[ix["Effect_%d" % s]] or 0)
            aur = int(r[ix["EffectAura_%d" % s]] or 0)
            if eff >= 165 or aur >= 317:
                raise SystemExit("spell %s effect slot %d out of range: effect=%d aura=%d" % (r[0], s, eff, aur))
        rows.append(r)

    if feed_pet[ix["Description_Lang_enUS"]] != FEED_PET_OLD:
        raise SystemExit("REFUSING: Feed Pet description is not the stock text: %r"
                         % feed_pet[ix["Description_Lang_enUS"]])
    feed_new = list(feed_pet)
    feed_new[ix["Description_Lang_enUS"]] = FEED_PET_NEW

    with open(OUT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator="\n")
        w.writerow(hdr)
        w.writerows(rows + [feed_new])
    print("wrote %s (%d new rows + Feed Pet)" % (OUT_CSV, len(rows)))

    # ---- Spell.dbc: add the rows, replace 6991 in place, then prove nothing else moved ----
    bak = SPELL_DBC + BAK
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists" % bak)
    shutil.copy2(SPELL_DBC, bak)
    subprocess.check_call([sys.executable, APPEND, "--dbc", bak, "--csv", OUT_CSV, "--out", SPELL_DBC])
    try:
        spell_gate(bak, SPELL_DBC, [int(r[0]) for r in rows])
    except SystemExit:
        shutil.copy2(bak, SPELL_DBC)
        raise

    append_spell_icons(ICON_DBC)

    # ---- Spell.csv: append the new rows, swap 6991's description inside its own line ----
    shutil.copy2(SPELL_CSV, SPELL_CSV + BAK)
    raw = open(SPELL_CSV, "rb").read()
    start = raw.index(b'\n"%d","' % FEED_PET) + 1
    end = raw.index(b"\n", start)
    line = raw[start:end]
    old_cell, new_cell = ('"%s"' % FEED_PET_OLD).encode(), ('"%s"' % FEED_PET_NEW).encode()
    assert line.count(old_cell) == 1, line.count(old_cell)
    raw = raw[:start] + line.replace(old_cell, new_cell) + raw[end:]
    if not raw.endswith(b"\n"):
        raw += b"\n"
    buf = io.StringIO()
    csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(rows)
    open(SPELL_CSV, "wb").write(raw + buf.getvalue().encode("utf-8"))
    print("Spell.csv: +%d rows, Feed Pet description replaced" % len(rows))

    # ---- CreatureFamily.csv: final skill lines, talent trees and talent categories ----
    with open(FAMILY_CSV, encoding="utf-8", newline="") as fh:
        rd = csv.reader(fh)
        fhdr = next(rd)
        frows = list(rd)
    fix = {h: i for i, h in enumerate(fhdr)}
    by_id = {int(r[0]): r for r in frows}
    for fam, name, line, _, talent_type, enum, _, _, _ in FAMILIES:
        r = by_id[fam]
        assert r[fix["Name_Lang_enUS"]] == name, (fam, r[fix["Name_Lang_enUS"]])
        r[fix["SkillLine_1"]], r[fix["SkillLine_2"]] = str(line), "270"
        r[fix["PetTalentType"]], r[fix["CategoryEnumID"]] = str(talent_type), str(enum)
    with open(FAMILY_CSV, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_ALL, lineterminator="\n")
        w.writerow(fhdr)
        w.writerows(frows)
    print("CreatureFamily.csv: families %s updated" % [f[0] for f in FAMILIES])

    write_sql(a.sql, hdr, ix, rows)


def write_sql(path, hdr, ix, rows):
    src = io.open(WORGOBLIN_10, encoding="utf-8").read()
    m = re.search(r"INSERT INTO `spell_dbc` \((.*?)\) VALUES", src, re.S)
    cols = [c.strip().strip("`") for c in m.group(1).split(",")]
    assert len(cols) == 234, len(cols)

    def csv_name(col):
        m2 = re.fullmatch(r"AttributesEx([2-7])", col)
        if m2:
            return "AttributesEx" + "BCDEFG"[int(m2.group(1)) - 2]
        if col.startswith("unk_320"):
            return None
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
            v = v.replace("\\", "\\\\").replace("'", "''").replace("\r", "\\r").replace("\n", "\\n")
            return "'" + v + "'"

    sla = skill_line_rows()
    out = []
    out.append("-- Hunter pets: the real family abilities of the post-WotLK families, and the retail talent trees.")
    out.append("--")
    out.append("-- Generated by Custom/Custom feature SQLs/worlddb/Pets/tools/gen_pet_family_abilities.py, which")
    out.append("-- also writes the client side (Spell.dbc, SpellIcon.dbc, CreatureFamily.dbc). Needs the first pass")
    out.append("-- (worlddb/Pets/rev_1791304116069959900.sql) applied: it created creaturefamily_dbc rows 56-60.")
    out.append("--")
    out.append("--   808  Fox           Bite + Tailspin (Cata)          Ferocity")
    out.append("--   811  Dog           Bite + Lock Jaw (Cata, root)    Ferocity")
    out.append("--   817  Shale Spider  Bite + Web Wrap (Cata)          Tenacity")
    out.append("--   1305 Direhorn      Bite + Gore (retail)            Tenacity (was Ferocity)")
    out.append("--   2361 Feathermane   Bite + Feather Flurry (retail)  Tenacity (was Ferocity)")
    out.append("--   2189 Mechanical    Bite + Defense Matrix (retail)  Cunning  (was Ferocity)")
    out.append("--   986  Quilen        Bite + Stone Armor (retail)     Tenacity (was Ferocity)")
    out.append("--   2719 Blood Beast   Bite + Blood Bolt (retail)      Tenacity (was Ferocity)")
    out.append("-- Skill line ids are the Cata ones for 808/811/817 and the retail ones for the rest; they")
    out.append("-- replace the custom 30056-30060 of the first pass. No player owned a pet of these families.")
    out.append("-- Stone Armor's 40% health threshold is checked by spell_pet_quilen_stone_armor")
    out.append("-- (src/server/scripts/DC/Pets/dc_hunter_pet_abilities.cpp); spell_proc holds its 120 sec cooldown.")
    out.append("")
    ids = ", ".join(str(int(r[0])) for r in sorted(rows, key=lambda r: int(r[0])))
    out.append("DELETE FROM `spell_dbc` WHERE `ID` IN (%s);" % ids)
    out.append("INSERT INTO `spell_dbc` (%s) VALUES" % ", ".join("`%s`" % c for c in cols))
    srows = sorted(rows, key=lambda r: int(r[0]))
    for i, r in enumerate(srows):
        end = ";" if i == len(srows) - 1 else ","
        out.append("(" + ", ".join(sql_val(r, c) for c in cols) + ")" + end)
    out.append("")
    out.append("-- Stone Armor: damage taken (melee, ranged, spells, periodic), damage events only, triggered")
    out.append("-- spells may proc it (PROC_ATTR_TRIGGERED_CAN_PROC), once every 120 sec.")
    out.append("DELETE FROM `spell_proc` WHERE `SpellId` = 160049;")
    out.append("INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, "
               "`SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, "
               "`AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES")
    out.append("(160049, 0, 0, 0, 0, 0, 664232, 1, 0, 0, 2, 0, 0, 100, 120000, 0);")
    out.append("")
    out.append("DELETE FROM `spell_script_names` WHERE `spell_id` = 160049 AND `ScriptName` = '%s';"
               % STONE_ARMOR_SCRIPT)
    out.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (160049, '%s');"
               % STONE_ARMOR_SCRIPT)
    out.append("")
    out.append("-- Skill lines: Bite (all ranks), the special, the family's +5% Tamed Pet Passive (DND), and the")
    out.append("-- tree's movement talents (AcquireMethod 0, parity with the stock lines). Copied from stock rows.")
    out.append("DELETE FROM `skilllineability_dbc` WHERE `ID` BETWEEN %d AND %d;" % (FIRST_SLA_ID, LAST_SLA_ID))
    sla_cols = ["ID", "SkillLine", "Spell", "RaceMask", "ClassMask", "ExcludeRace", "ExcludeClass",
                "MinSkillLineRank", "SupercededBySpell", "AcquireMethod", "TrivialSkillLineRankHigh",
                "TrivialSkillLineRankLow", "CharacterPoints_1", "CharacterPoints_2"]
    out.append("INSERT INTO `skilllineability_dbc` (%s) VALUES" % ", ".join("`%s`" % c for c in sla_cols))
    names = {int(r[0]): r[ix["Name_Lang_enUS"]] for r in rows}
    with open(SPELL_CSV, encoding="utf-8", newline="") as fh:
        rd = csv.reader(fh)
        next(rd)
        wanted = {row[2] for _, _, row in sla}
        for r in rd:
            if int(r[0]) in wanted:
                names[int(r[0])] = (r[ix["Name_Lang_enUS"]] + " " + r[ix["NameSubtext_Lang_enUS"]]).strip()
    current = None
    for i, (line, line_name, row) in enumerate(sla):
        if line != current:
            out.append("-- %d %s" % (line, line_name))
            current = line
        end = ";" if i == len(sla) - 1 else ","
        out.append("(%s)%s -- %s" % (", ".join(str(v) for v in row), end, names.get(row[2], "?")))
    out.append("")
    out.append("-- Skill line, talent tree and (client-only) talent category; rows 50-60 exist since the first pass.")
    for fam, name, line, _, talent_type, enum, _, _, _ in FAMILIES:
        out.append("UPDATE `creaturefamily_dbc` SET `SkillLine_1` = %d, `SkillLine_2` = 270, `PetTalentType` = %d, "
                   "`CategoryEnumID` = %d WHERE `ID` = %d;" % (line, talent_type, enum, fam))
    io.open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote %s (%d spells, %d skill line rows)" % (path, len(rows), len(sla)))


if __name__ == "__main__":
    main()
