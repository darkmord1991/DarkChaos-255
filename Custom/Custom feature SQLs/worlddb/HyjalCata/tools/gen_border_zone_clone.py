#!/usr/bin/env python3
"""
Clone the stock NPCs/GOs that 157_/161_/164_ imported onto map 750, so the
border zones can be edited without touching the real Winterspring, Moonglade,
Felwood, Darkshore, Azshara or Ashenvale.

THE PROBLEM
  Those three files imported stock creatures and gameobjects with their RAW
  entry ids, on the reasoning that cloning would orphan their loot and quest
  links.  That keeps the data correct but makes the two copies the SAME
  records: editing Innkeeper Vizzie on map 750 edits the real Everlook.

THE SCHEME  (mirrors the Cata downport's +3,600,000 convention)
    creature entry / loot ids / gossip menu ids   raw + 3,700,000
    gameobject entry / loot ids                   raw + 3,900,000
  Every one of those target ranges was verified EMPTY first.

  `smart_scripts` is the one exception, and an earlier revision of this file got
  it WRONG in a way that destroyed stock data.  3,700,000-3,799,999 already
  holds 148 source_type 9 rows, and they do NOT belong to the Hyjal port:
  AzerothCore numbers timed action lists `creature_entry * 100`, so Icecrown
  Citadel's entries 37000-37999 -- Darion Mograine, Blood-Queen Lana'thel, The
  Lich King -- own that band.  Deleting it wiped all ten of their lists.
  Cloned action lists now live at raw_list + 370,000,000 (= 100 x the creature
  offset, so the entry*100 convention still holds for the clones), a band
  verified empty, and the DELETE names the exact ids rather than a range.

WHAT IS DELIBERATELY SHARED
  * npc_text / broadcast_text -- a global string pool referenced from
    everywhere.  Gossip TEXT is shared; gossip STRUCTURE (menus/options) is not.
  * item_template -- vendor stock and loot reference real items on purpose.
  * ScriptName values carry across unchanged (20 templates) so the same C++
    drives the clone.  That is wanted, not a leak.

QUESTS ARE NOT TOUCHED HERE.  creature_queststarter/questender are left alone:
cloning ~200 quests means remapping PrevQuestID/NextQuestID/ExclusiveGroup
chains, and doing that in the same pass as the templates makes both harder to
verify.  Until that second pass runs the cloned NPCs offer no quests, which is
visible and harmless; the raw NPCs they came from keep theirs.

    python gen_border_zone_clone.py [outdir]

Writes 166_border_zone_clone.sql.  Idempotent: every block DELETEs its own id
range first.
"""
import sys, os

OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r34/"
C_OFF = 3700000     # creature side
G_OFF = 3900000     # gameobject side
L_OFF = 370000000   # SmartAI timed action lists -- 100x C_OFF, see below

# The source set must be STABLE across re-runs.  The last statement in this file
# repoints the spawn rows to the clones, so on a second run
# `SELECT id FROM creature WHERE guid BETWEEN ...` returns the CLONED ids -- and
# cloning those again would mint entries at raw + 7,400,000.  apply_all.sql
# re-runs everything, so that is not hypothetical.
#
# It is MATERIALISED into a real table rather than inlined as a subquery.  The
# stable definition has to read `creature_template` (to recover raw ids from
# clones that already exist), and several statements below UPDATE that same
# table -- MySQL rejects that with "You can't specify target table for update in
# FROM clause" (error 1093).  A plain table also sidesteps the temporary-table
# "can't reopen" limit, which would bite the moment one statement referenced the
# set twice.
SRC = "SELECT `id` FROM `_dc_clone_src`"
SRCG = "SELECT `id` FROM `_dc_clone_srcg`"
SRCA = "SELECT `id` FROM `_dc_clone_al`"

# The recovery arm is the important one.  The spawn rows are the only durable
# record of WHICH stock entries this map borrowed; the clone templates are not,
# because the DELETE that opens each block below removes them.  Derive the raw
# set from the spawns whether they still hold raw ids (first run) or have
# already been repointed (every run after), and the file heals a half-applied
# state instead of quietly cloning nothing.  It has to: a run that aborts
# between the DELETE and the final UPDATE leaves 2,832 spawns pointing at
# templates that no longer exist, and the templates-only lookup could not see
# them.  `EXISTS creature_template` keeps recovered ids honest -- a raw id that
# no longer resolves contributes nothing rather than a phantom row.
#
# The template arms are additionally gated on that same spawn block, because a
# clone band is NOT proof of ownership: DC's Legion Dalaran guild housing sits at
# 4,100,000-4,100,674, inside the gameobject clone span, and an ungated arm would
# read those as clones of raw 200,xxx and start cloning Dalaran into Hyjal.
SETUP = """DROP TABLE IF EXISTS `_dc_clone_src`;
CREATE TABLE `_dc_clone_src` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_clone_src` (`id`)
SELECT DISTINCT c.`id` FROM `creature` c
WHERE c.`guid` BETWEEN 15600000 AND 15899999 AND c.`id` < {C}
UNION SELECT DISTINCT c.`id` - {C} FROM `creature` c
WHERE c.`guid` BETWEEN 15600000 AND 15899999 AND c.`id` BETWEEN {C} AND {C2}
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = c.`id` - {C})
UNION SELECT `entry` - {C} FROM `creature_template` WHERE `entry` BETWEEN {C} AND {C2}
  AND `entry` IN (SELECT `id` FROM `creature` WHERE `guid` BETWEEN 15600000 AND 15899999);

DROP TABLE IF EXISTS `_dc_clone_srcg`;
CREATE TABLE `_dc_clone_srcg` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_clone_srcg` (`id`)
SELECT DISTINCT g.`id` FROM `gameobject` g
WHERE g.`guid` BETWEEN 15600000 AND 15899999 AND g.`id` < {G}
UNION SELECT DISTINCT g.`id` - {G} FROM `gameobject` g
WHERE g.`guid` BETWEEN 15600000 AND 15899999 AND g.`id` BETWEEN {G} AND {G2}
  AND EXISTS (SELECT 1 FROM `gameobject_template` t WHERE t.`entry` = g.`id` - {G})
UNION SELECT `entry` - {G} FROM `gameobject_template` WHERE `entry` BETWEEN {G} AND {G2}
  AND `entry` IN (SELECT `id` FROM `gameobject` WHERE `guid` BETWEEN 15600000 AND 15899999);

-- The timed action lists the cloned creatures call.  Materialised here, while
-- the source set is still raw, so the smart_scripts block can DELETE exactly
-- the ids it is about to write instead of guessing at a range.  Nested lists
-- (a source_type 9 row calling another list) are deliberately not followed --
-- the clone keeps calling the shared original, same as it keeps ScriptName.
DROP TABLE IF EXISTS `_dc_clone_al`;
CREATE TABLE `_dc_clone_al` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_clone_al` (`id`)
SELECT DISTINCT `action_param1` FROM `smart_scripts`
WHERE `source_type` = 0 AND `action_type` = 80 AND `action_param1` <> 0
  AND `entryorguid` IN (SELECT `id` FROM `_dc_clone_src`);""".format(
    C=C_OFF, C2=C_OFF + 99999, G=G_OFF, G2=G_OFF + 499999)

TEARDOWN = """DROP TABLE IF EXISTS `_dc_clone_src`;
DROP TABLE IF EXISTS `_dc_clone_srcg`;
DROP TABLE IF EXISTS `_dc_clone_al`;"""

# ---------------------------------------------------------------------------
# VERIFIED COLUMN LISTS, read out of information_schema on this fork rather
# than assumed.  creature_template in particular drifts from stock AzerothCore:
# no `scale`, no `trainer_class`, and it adds speed_swim / speed_flight /
# detection_range / CreatureImmunitiesId.  An INSERT ... SELECT without an
# explicit column list silently shifts every field past the first difference --
# it type-checks and produces garbage.  smart_scripts likewise has a
# target_param4 that stock does not.
# ---------------------------------------------------------------------------
COLS = {
 "creature_template":
  "entry,difficulty_entry_1,difficulty_entry_2,difficulty_entry_3,KillCredit1,KillCredit2,name,subname,"
  "IconName,gossip_menu_id,minlevel,maxlevel,exp,faction,npcflag,speed_walk,speed_run,speed_swim,"
  "speed_flight,detection_range,rank,dmgschool,DamageModifier,BaseAttackTime,RangeAttackTime,BaseVariance,"
  "RangeVariance,unit_class,unit_flags,unit_flags2,dynamicflags,family,type,type_flags,lootid,"
  "pickpocketloot,skinloot,PetSpellDataId,VehicleId,mingold,maxgold,AIName,MovementType,HoverHeight,"
  "HealthModifier,ManaModifier,ArmorModifier,ExperienceModifier,RacialLeader,movementId,RegenHealth,"
  "CreatureImmunitiesId,flags_extra,ScriptName,VerifiedBuild",
 "creature_template_model": "CreatureID,Idx,CreatureDisplayID,DisplayScale,Probability,VerifiedBuild",
 "creature_template_addon": "entry,path_id,mount,bytes1,bytes2,emote,visibilityDistanceType,auras",
 "creature_equip_template": "CreatureID,ID,ItemID1,ItemID2,ItemID3,VerifiedBuild",
 "creature_loot_template": "Entry,Item,Reference,Chance,QuestRequired,LootMode,GroupId,MinCount,MaxCount,Comment",
 "pickpocketing_loot_template": "Entry,Item,Reference,Chance,QuestRequired,LootMode,GroupId,MinCount,MaxCount,Comment",
 "skinning_loot_template": "Entry,Item,Reference,Chance,QuestRequired,LootMode,GroupId,MinCount,MaxCount,Comment",
 "gameobject_loot_template": "Entry,Item,Reference,Chance,QuestRequired,LootMode,GroupId,MinCount,MaxCount,Comment",
 "npc_vendor": "entry,slot,item,maxcount,incrtime,ExtendedCost,VerifiedBuild",
 "creature_default_trainer": "CreatureId,TrainerId",
 "gossip_menu": "MenuID,TextID",
 "gossip_menu_option":
  "MenuID,OptionID,OptionIcon,OptionText,OptionBroadcastTextID,OptionType,OptionNpcFlag,ActionMenuID,"
  "ActionPoiID,BoxCoded,BoxMoney,BoxText,BoxBroadcastTextID,VerifiedBuild",
 "creature_text":
  "CreatureID,GroupID,ID,Text,Type,Language,Probability,Emote,Duration,Sound,BroadcastTextId,TextRange,comment",
 "quest_greeting": "ID,type,GreetEmoteType,GreetEmoteDelay,Greeting,VerifiedBuild",
 "creature_onkill_reputation":
  "creature_id,RewOnKillRepFaction1,RewOnKillRepFaction2,MaxStanding1,IsTeamAward1,RewOnKillRepValue1,"
  "MaxStanding2,IsTeamAward2,RewOnKillRepValue2,TeamDependent",
 "smart_scripts":
  "entryorguid,source_type,id,link,event_type,event_phase_mask,event_chance,event_flags,event_param1,"
  "event_param2,event_param3,event_param4,event_param5,event_param6,action_type,action_param1,action_param2,"
  "action_param3,action_param4,action_param5,action_param6,target_type,target_param1,target_param2,"
  "target_param3,target_param4,target_x,target_y,target_z,target_o,comment",
 "gameobject_template":
  "entry,type,displayId,name,IconName,castBarCaption,unk1,size,Data0,Data1,Data2,Data3,Data4,Data5,Data6,"
  "Data7,Data8,Data9,Data10,Data11,Data12,Data13,Data14,Data15,Data16,Data17,Data18,Data19,Data20,Data21,"
  "Data22,Data23,AIName,ScriptName,VerifiedBuild",
 "gameobject_template_addon": "entry,faction,flags,mingold,maxgold,artkit0,artkit1,artkit2,artkit3",
}

HEADER = """-- ---------------------------------------------------------------------------
-- 166  Hyjal round-34 -- clone the border-zone NPCs and objects
-- ---------------------------------------------------------------------------
-- 157_/161_/164_ imported stock creatures and gameobjects onto map 750 using
-- their RAW entry ids.  The data is correct, but it means the map-750 copy and
-- the real Winterspring / Moonglade / Felwood / Darkshore / Azshara / Ashenvale
-- copy are the SAME records -- editing one edits the other.
--
-- This clones them into private ranges so map 750 can be modified freely:
--     creature entry / loot / gossip   raw + 3,700,000
--     gameobject entry / loot          raw + 3,900,000
-- Both ranges were verified empty first.  smart_scripts is the exception and
-- needed a third namespace: 3,7xx,xxx already holds 148 source_type 9 rows
-- belonging to STOCK Icecrown Citadel (AzerothCore numbers action lists
-- entry*100, so ICC's 37000-37999 land there).  Cloned action lists go to
-- raw_list + 370,000,000 instead; 168_ restores what the earlier revision of
-- this file deleted from that band.
--
-- SHARED ON PURPOSE: npc_text / broadcast_text (a global string pool -- gossip
-- text shared, gossip structure not), item_template, and ScriptName values so
-- the same C++ still drives the cloned NPCs.
--
-- QUESTS ARE NOT CLONED HERE -- separate pass, because ~200 quests need
-- PrevQuestID / NextQuestID / ExclusiveGroup remapping and mixing it in would
-- make both halves harder to verify.  Until then the clones offer no quests;
-- the raw NPCs they came from still do.
--
-- Column lists below are read from information_schema, not assumed: this fork's
-- creature_template has no `scale` and no `trainer_class`, and adds speed_swim,
-- speed_flight, detection_range and CreatureImmunitiesId.  A bare
-- INSERT ... SELECT would shift every column past the first difference.
--
-- Generated by HyjalCata/tools/gen_border_zone_clone.py.  Idempotent.
-- ---------------------------------------------------------------------------

"""


def cl(t):
    return ["`%s`" % c for c in COLS[t].split(",")]


def clone(table, key, off, where, extra=None):
    """INSERT ... SELECT with the key column offset, every other column verbatim."""
    cols = cl(table)
    sel = []
    for c in cols:
        name = c.strip("`")
        if name == key:
            sel.append("`%s` + %d" % (name, off))
        elif extra and name in extra:
            sel.append(extra[name])
        else:
            sel.append("`%s`" % name)
    return ("INSERT INTO `%s` (%s)\nSELECT %s\nFROM `%s` WHERE %s;"
            % (table, ", ".join(cols), ", ".join(sel), table, where))


def block(title, body):
    return "-- --- %s %s\n%s\n\n" % (title, "-" * max(0, 72 - len(title)), body.strip())


def main():
    p = [HEADER]
    p.append(block("materialise the source set -- see the note in the generator", SETUP))
    CR = "`entry` BETWEEN %d AND %d" % (C_OFF, C_OFF + 99999)

    p.append(block("creature_template", """
DELETE FROM `creature_template` WHERE {CR};
{ins}

UPDATE `creature_template` SET `KillCredit1` = `KillCredit1` + {O}
WHERE {CR} AND `KillCredit1` <> 0 AND `KillCredit1` IN ({SRC});
UPDATE `creature_template` SET `KillCredit2` = `KillCredit2` + {O}
WHERE {CR} AND `KillCredit2` <> 0 AND `KillCredit2` IN ({SRC});
UPDATE `creature_template` SET `lootid` = `lootid` + {O} WHERE {CR} AND `lootid` <> 0;
UPDATE `creature_template` SET `pickpocketloot` = `pickpocketloot` + {O} WHERE {CR} AND `pickpocketloot` <> 0;
UPDATE `creature_template` SET `skinloot` = `skinloot` + {O} WHERE {CR} AND `skinloot` <> 0;
UPDATE `creature_template` SET `gossip_menu_id` = `gossip_menu_id` + {O} WHERE {CR} AND `gossip_menu_id` <> 0;
-- difficulty_entry_* would dangle at templates that were not cloned
UPDATE `creature_template` SET `difficulty_entry_1` = 0, `difficulty_entry_2` = 0, `difficulty_entry_3` = 0
WHERE {CR};
""".format(CR=CR, O=C_OFF, SRC=SRC,
           ins=clone("creature_template", "entry", C_OFF, "`entry` IN (%s)" % SRC))))

    p.append(block("creature_template_model / addon / equip", """
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN {A} AND {B};
{m}

DELETE FROM `creature_template_addon` WHERE {CR};
{a}

DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN {A} AND {B};
{e}
""".format(A=C_OFF, B=C_OFF + 99999, CR=CR,
           m=clone("creature_template_model", "CreatureID", C_OFF, "`CreatureID` IN (%s)" % SRC),
           a=clone("creature_template_addon", "entry", C_OFF, "`entry` IN (%s)" % SRC),
           e=clone("creature_equip_template", "CreatureID", C_OFF, "`CreatureID` IN (%s)" % SRC))))

    loot = []
    for tbl, col in (("creature_loot_template", "lootid"),
                     ("pickpocketing_loot_template", "pickpocketloot"),
                     ("skinning_loot_template", "skinloot")):
        w = ("`Entry` IN (SELECT DISTINCT `%s` FROM `creature_template` "
             "WHERE `entry` IN (%s) AND `%s` <> 0)" % (col, SRC, col))
        loot.append("DELETE FROM `%s` WHERE `Entry` BETWEEN %d AND %d;\n%s"
                    % (tbl, C_OFF, C_OFF + 99999, clone(tbl, "Entry", C_OFF, w)))
    p.append(block("loot tables -- Reference rows keep their raw target:\n"
                   "--     reference_loot_template is a shared pool, not per-creature data",
                   "\n\n".join(loot)))

    gm_where = ("`MenuID` IN (SELECT DISTINCT `gossip_menu_id` FROM `creature_template` "
                "WHERE `entry` IN (%s) AND `gossip_menu_id` <> 0)" % SRC)
    p.append(block("vendor / trainer / gossip / text / reputation", """
DELETE FROM `npc_vendor` WHERE {CR};
{v}

DELETE FROM `creature_default_trainer` WHERE `CreatureId` BETWEEN {A} AND {B};
{t}

DELETE FROM `gossip_menu` WHERE `MenuID` BETWEEN {A} AND {B};
{gm}

DELETE FROM `gossip_menu_option` WHERE `MenuID` BETWEEN {A} AND {B};
{go}

DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN {A} AND {B};
{ct}

-- quest_greeting.ID is a CREATURE entry when type = 0, not a quest id.  167_ got
-- this wrong -- it matched IDs against creature_queststarter.quest and wrote them
-- at +100,000, producing five rows keyed to creatures that do not exist.  It
-- belongs on the creature side, at the creature offset; 169_ clears the bad rows.
DELETE FROM `quest_greeting` WHERE `type` = 0 AND `ID` BETWEEN {A} AND {B};
{qg}

DELETE FROM `creature_onkill_reputation` WHERE `creature_id` BETWEEN {A} AND {B};
{rep}
""".format(A=C_OFF, B=C_OFF + 99999, CR=CR,
           v=clone("npc_vendor", "entry", C_OFF, "`entry` IN (%s)" % SRC),
           t=clone("creature_default_trainer", "CreatureId", C_OFF, "`CreatureId` IN (%s)" % SRC),
           gm=clone("gossip_menu", "MenuID", C_OFF, gm_where),
           go=clone("gossip_menu_option", "MenuID", C_OFF, gm_where,
                    extra={"ActionMenuID": "`ActionMenuID` + IF(`ActionMenuID` <> 0, %d, 0)" % C_OFF}),
           ct=clone("creature_text", "CreatureID", C_OFF, "`CreatureID` IN (%s)" % SRC),
           qg=clone("quest_greeting", "ID", C_OFF, "`type` = 0 AND `ID` IN (%s)" % SRC),
           rep=clone("creature_onkill_reputation", "creature_id", C_OFF, "`creature_id` IN (%s)" % SRC))))

    p.append(block("smart_scripts -- creature rows plus the action lists they call", """
-- The source_type 0 band is safe to clear wholesale: entryorguid there is a
-- creature entry, and nothing but these clones lives at 3,7xx,xxx.
--
-- source_type 9 is NOT.  AzerothCore numbers timed action lists
-- `creature_entry * 100`, so stock entries 37000-37999 -- Highlord Darion
-- Mograine, Blood-Queen Lana'thel, The Lich King and the rest of Icecrown
-- Citadel -- own 148 rows sitting squarely in 3,700,000-3,799,999.  An earlier
-- revision of this file deleted that band and destroyed all ten of those lists;
-- 168_ puts them back.  The clones therefore live at raw_list + 370,000,000,
-- which keeps the entry*100 convention intact (a clone at entry 3,7xx,xxx wants
-- list 370,xxx,xxx) and lands in a band verified completely empty.  The DELETE
-- targets the exact ids about to be written rather than a range, via the
-- scratch table -- a range guard is what caused the damage in the first place.
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN {A} AND {B};
DELETE FROM `smart_scripts` WHERE `source_type` = 9
  AND `entryorguid` IN (SELECT `id` + {L} FROM `_dc_clone_al`);

{s0}

{s9}

-- Repoint the action-list call, and any summon / kill-credit / target naming a
-- creature we also cloned.  References OUTSIDE the cloned set stay raw on
-- purpose: they point at world content that was not copied.
UPDATE `smart_scripts` SET `action_param1` = `action_param1` + {L}
WHERE `source_type` = 0 AND `entryorguid` BETWEEN {A} AND {B}
  AND `action_type` = 80 AND `action_param1` IN (SELECT `id` FROM `_dc_clone_al`);
-- Both bands, because the cloned rows no longer share one: creature rows are at
-- 3,7xx,xxx and their action lists at 370,xxx,xxx.  Matching only the first
-- would leave every summon and target inside a cloned action list pointing at
-- the raw NPC -- the exact leak this file exists to close.
UPDATE `smart_scripts` SET `action_param1` = `action_param1` + {O}
WHERE {BANDS}
  AND `action_type` IN (12,33) AND `action_param1` IN ({SRC});
UPDATE `smart_scripts` SET `target_param1` = `target_param1` + {O}
WHERE {BANDS}
  AND `target_type` IN (9,11,19) AND `target_param1` IN ({SRC});
""".format(A=C_OFF, B=C_OFF + 99999, O=C_OFF, L=L_OFF, SRC=SRC,
           BANDS="((`source_type` = 0 AND `entryorguid` BETWEEN {A} AND {B})\n"
                 "    OR (`source_type` = 9 AND `entryorguid` BETWEEN {L} AND {L2}))".format(
                     A=C_OFF, B=C_OFF + 99999, L=L_OFF, L2=L_OFF + 9999999),
           s0=clone("smart_scripts", "entryorguid", C_OFF,
                    "`source_type` = 0 AND `entryorguid` IN (%s)" % SRC),
           s9=clone("smart_scripts", "entryorguid", L_OFF,
                    "`source_type` = 9 AND `entryorguid` IN (%s)" % SRCA))))

    # NO RANGE GUARD HERE, for the same reason as smart_scripts source_type 9.
    # Gameobject ids reach 401,007, so raw + 3.9M runs up to 4,301,007 -- and DC's
    # Legion Dalaran guild-housing block (map 1413) occupies 4,100,000-4,100,674,
    # right in the middle of that span.  A `>= 3900000` guard deleted all 675 of
    # its templates and orphaned 714 spawns; no BETWEEN can separate the two sets
    # because they interleave.  Deleting exactly the ids about to be written is
    # the only correct form.  169_ restores what the range guard destroyed.
    GR = "`entry` IN (SELECT `id` + %d FROM `_dc_clone_srcg`)" % G_OFF
    p.append(block("gameobject_template + addon + loot", """
DELETE FROM `gameobject_template` WHERE {GR};
{gt}

DELETE FROM `gameobject_template_addon` WHERE {GR};
{ga}

-- type 3 (CHEST) holds its loot id in Data1
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (
  SELECT DISTINCT `Data1` + {O} FROM `gameobject_template`
  WHERE `entry` IN ({SRCG}) AND `type` = 3 AND `Data1` <> 0);
{gl}

UPDATE `gameobject_template` SET `Data1` = `Data1` + {O}
WHERE {GR} AND `type` = 3 AND `Data1` <> 0;

-- SmartGameobjectAI carries across with the template, so the scripts have to as
-- well -- 20 cloned objects had the AIName and no rows, which the core reports
-- as "has SmartGameobjectAI enabled but no SmartAI entries in the database".
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND {GR2};
{gs}
UPDATE `smart_scripts` SET `action_param1` = `action_param1` + {C}
WHERE `source_type` = 1 AND {GR2}
  AND `action_type` IN (12,33) AND `action_param1` IN ({SRC});
UPDATE `smart_scripts` SET `target_param1` = `target_param1` + {C}
WHERE `source_type` = 1 AND {GR2}
  AND `target_type` IN (9,11,19) AND `target_param1` IN ({SRC});
""".format(GR=GR, GR2=GR.replace("`entry`", "`entryorguid`"), A=G_OFF, B=G_OFF + 499999,
           O=G_OFF, C=C_OFF, SRC=SRC, SRCG=SRCG,
           gs=clone("smart_scripts", "entryorguid", G_OFF,
                    "`source_type` = 1 AND `entryorguid` IN (%s)" % SRCG),
           gt=clone("gameobject_template", "entry", G_OFF, "`entry` IN (%s)" % SRCG),
           ga=clone("gameobject_template_addon", "entry", G_OFF, "`entry` IN (%s)" % SRCG),
           gl=clone("gameobject_loot_template", "Entry", G_OFF,
                    "`Entry` IN (SELECT DISTINCT `Data1` FROM `gameobject_template` "
                    "WHERE `entry` IN (%s) AND `type` = 3 AND `Data1` <> 0)" % SRCG))))

    p.append(block("finally: point the imported spawns at the clones", """
-- Done LAST on purpose.  Every block above selects its source rows via
-- `WHERE ... IN (SELECT id FROM creature WHERE guid BETWEEN 15600000 AND
-- 15899999)`, so the spawn rows must still hold the RAW ids while they run.
-- Flipping them earlier makes every later block select nothing -- the file
-- would report success while cloning almost nothing.
UPDATE `creature` SET `id` = `id` + {C}
WHERE `guid` BETWEEN 15600000 AND 15899999 AND `id` < {C}
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = `creature`.`id` + {C});

UPDATE `gameobject` SET `id` = `id` + {G}
WHERE `guid` BETWEEN 15600000 AND 15899999 AND `id` < {G}
  AND EXISTS (SELECT 1 FROM `gameobject_template` t WHERE t.`entry` = `gameobject`.`id` + {G});
""".format(C=C_OFF, G=G_OFF)))

    p.append(block("drop the scratch tables", TEARDOWN))

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "166_border_zone_clone.sql")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(p))
    print("wrote %s (%d bytes)" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    main()
