-- =====================================================================
-- Molten Front (map 861) -- 17  Interaction layer: kill-credit proxies,
--                               spellhit family audit, item obtain paths
-- ---------------------------------------------------------------------
-- Runs AFTER 16_mf_deep_layer.sql. 16_ clones the deep templates
-- (53073, 52490, 52495, 53056, 53196, 54163, 53366, 53055, 53759, 53771,
-- 53834, 53864, 52289, 53264, 53265, 53267, 53271, 53370, GO 208535, 40660)
-- together with their SOURCE smart_scripts, param-swept. NOTHING in this file
-- duplicates a source SmartAI row: every block below was checked against
-- nelt_world / cata_world first and only authors what the sources do NOT carry.
--
-- ASSUMPTIONS (each guarded with EXISTS so a partial apply cannot dangle):
--   * 16_ has created 3652289, 3653264, 3653265, 3653267, 3653271, 3653055,
--     3653759, 3653771, 3653834, 3653864, 3653370, 3654230 and GO 3808535.
--   * 16_ ported the nelt JUST_DIED -> kill-credit 54230 rows on the five deep
--     bosses with the +3,600,000 sweep applied. Section 1b is a labelled
--     REDUNDANT safety net for that, not a duplicate rule.
-- Verified live at authoring time: 3652300, 3652815, 3653084, 3653251,
--   3653263, 3653886, 3652804 (SmartAI, spawned), 3653240 (24 spawns),
--   3652660 (9), 3653245 (3), 3654343 (template only -- NOT spawned),
--   3652648 (24, lootid 52648), 3652981 (66, lootid 52981).
-- Free id bands used: smart_scripts action lists 5280400/5280401 (0 rows live),
--   creature guids 15,350,001+ (band 15,350,000-15,359,999 empty).
--
-- Cata "Generic Quest Invisibility" auras 87872 / 94223 / 80797 are phase-gating
-- and are deliberately NOT applied to anything in this file.
--
-- Idempotent (DELETE-before-INSERT, value-guarded UPDATEs). Worldserver restart.
-- =====================================================================
SET @OFF := 3600000;

-- ======================================================================
-- 1. KILL-CREDIT PROXIES THAT NOTHING CURRENTLY GRANTS
-- ======================================================================

-- ----------------------------------------------------------------------
-- 1a. Quest 29128 "The Protectors of Hyjal" -> 3652300 Seething Pyrelord (x6)
--
-- RETAIL MECHANISM FOUND: pure creature_template.KillCredit columns -- there is
-- NO SmartAI anywhere in nelt_world or cata_world granting 52300. Both sources
-- agree exactly:
--     52289 Fiery Behemoth   KillCredit1=52300  KillCredit2=52816
--     53264 Searris          KillCredit1=52816  KillCredit2=52300
--     53265 Kelbnar          KillCredit1=52816  KillCredit2=52300
--     53267 Andrazor         KillCredit1=52816  KillCredit2=52300
--     53271 Fah Jarakk       KillCredit1=52816  KillCredit2=52300
--     52300 Seething Pyrelord KillCredit1=52816
--
-- IMPLEMENTED: the +3,600,000 sweep never covered the KillCredit columns on the
-- passes that produced these clones, so 16_'s clone carries the RAW ids. This is
-- a MIXED convention on purpose, and the distinction matters:
--   * 52300 -> MUST be offset to 3652300: quest 29128 objective is 3652300.
--   * 52816 "Charred Invader" -> MUST STAY RAW: creature_template 52816 exists
--     here un-cloned, and the four live "Rage Against the Flames" dailies
--     (29123 / 29127 / 29149 / 29163) all name the RAW 52816 as their objective.
--     Offsetting it would break four working quests. Verified: 3652816 does not
--     exist. Live 3652300's own KillCredit1=52816 is therefore already CORRECT
--     and is intentionally left alone.
-- Guarded on the current raw value AND on the +3.6M target existing.
-- ----------------------------------------------------------------------
UPDATE acore_world.creature_template ct
SET ct.`KillCredit1` = ct.`KillCredit1` + @OFF
WHERE ct.`entry` = 3652289
  AND ct.`KillCredit1` = 52300
  AND EXISTS (SELECT 1 FROM acore_world.creature_template x WHERE x.`entry` = 3652300);

UPDATE acore_world.creature_template ct
SET ct.`KillCredit2` = ct.`KillCredit2` + @OFF
WHERE ct.`entry` IN (3653264,3653265,3653267,3653271)
  AND ct.`KillCredit2` = 52300
  AND EXISTS (SELECT 1 FROM acore_world.creature_template x WHERE x.`entry` = 3652300);

-- ----------------------------------------------------------------------
-- 1b. Quests 29243 / 29305 "Strike at the Heart" -> 3654230 Lieutenant of Flame (x1)
--
-- RETAIL MECHANISM FOUND: nelt_world carries the grant as SmartAI --
--     53055 / 53759 / 53771 / 53834 / 53864, event 6 (JUST_DIED),
--     action 33 (KILL_CREDIT) param1 54230, target 18 (closest player, 50yd).
-- cata_world instead carries it as creature_template.KillCredit1=54230 on the
-- same five bosses. The two sources implement the same grant two different ways.
--
-- IMPLEMENTED: the SmartAI rows are 16_'s job (source-derived, param-swept) and
-- are deliberately NOT repeated here. What IS added is cata_world's column-side
-- grant, which a nelt-derived clone would leave at 0. It is a REDUNDANT SAFETY
-- NET: if 16_'s sweep offsets action 33 correctly the player simply gets the
-- same credit twice, and because both objectives require a count of 1 the second
-- KilledMonsterCredit is a no-op. If the sweep ever misses, the quests still work.
-- ----------------------------------------------------------------------
UPDATE acore_world.creature_template ct
SET ct.`KillCredit1` = 3654230
WHERE ct.`entry` IN (3653055,3653759,3653771,3653834,3653864)
  AND ct.`KillCredit1` = 0
  AND EXISTS (SELECT 1 FROM acore_world.creature_template x WHERE x.`entry` = 3654230);

-- ----------------------------------------------------------------------
-- 1c. Quest 29192 "The Wardens are Watching" -> 3652815 Captured Druid credit
--
-- RETAIL MECHANISM FOUND: Shadow Warden 52804 (LIVE here as 3652804, AIName
-- SmartAI, already spawned) carries the whole capture scene:
--     event 8 (SPELLHIT 98914) -> action 80 CALL_TIMED_ACTIONLIST 5280400
--     event 8 (SPELLHIT 98915) -> action 80 CALL_TIMED_ACTIONLIST 5280401
-- and list 5280401 id 3 is the grant: action 33 KILL_CREDIT 52815, target 18
-- (closest player 20yd). Both action lists were NEVER ported -- live has 0 rows
-- for 5280400/5280401, so 3652804's two spellhit branches call into nothing.
--
-- IMPLEMENTED: both lists ported with the param sweep (52815 -> 3652815). The
-- raw list ids 5280400/5280401 are kept (verified free live) exactly as 3652804's
-- already-live caller expects them.
--   DROPPED ACTIONS -- their spells do not exist in acore_world.spell_dbc and
--   would ship a boot error:  42716 (list 5280401 id 1), 97668 (list 5280400
--   ids 4 and 5), 97564 (list 5280400 id 8). Kept: 98916 (verified present).
--   Talk groups 1/2/3/4 all verified present in creature_text for 3652804.
--
--   !! STILL DORMANT -- see the DESIGN NOTE in section 2: nothing casts 98914 or
--   98915. They are server-side SPELL_EFFECT_DUMMY rows whose player-side caster
--   was a Cata quest item, and that item->spell wiring did not survive the
--   downport. The lists below are correct infrastructure that becomes live the
--   moment a caster exists; block 1c-bis adds a grant that works without one.
-- ----------------------------------------------------------------------
DELETE FROM acore_world.smart_scripts WHERE `entryorguid` IN (5280400,5280401) AND `source_type` = 9;

INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
-- list 5280400 -- warden engages the druid (spellhit 98914)
(5280400,9,0,0,0,0,100,0,0,0,0,0,64,1,0,0,0,0,0,7,0,0,0,0,0,0,'Shadow Warden - list A - store invoker as target 1'),
(5280400,9,1,0,0,0,100,0,0,0,0,0,11,98916,0,0,0,0,0,7,0,0,0,0,0,0,'Shadow Warden - list A - cast 98916 on invoker'),
(5280400,9,2,0,0,0,100,0,0,0,0,0,1,1,0,0,0,0,0,1,0,0,0,0,0,0,'Shadow Warden - list A - say text 1'),
(5280400,9,3,0,0,0,100,0,0,0,0,0,49,0,0,0,0,0,0,7,0,0,0,0,0,0,'Shadow Warden - list A - attack invoker'),
(5280400,9,4,0,0,0,100,0,2000,2000,0,0,1,2,0,0,0,0,0,1,0,0,0,0,0,0,'Shadow Warden - list A - say text 2 (src ids 4/5 cast 97668 - DROPPED, spell missing)'),
(5280400,9,5,0,0,0,100,0,4000,4000,0,0,1,3,0,0,0,0,0,1,0,0,0,0,0,0,'Shadow Warden - list A - say text 3 (src id 8 cast 97564 - DROPPED, spell missing)'),
-- list 5280401 -- druid subdued, credit handed out (spellhit 98915)
(5280401,9,0,0,0,0,100,0,0,0,0,0,20,0,0,0,0,0,0,1,0,0,0,0,0,0,'Shadow Warden - list B - stop combat/attack'),
(5280401,9,1,0,0,0,100,0,0,0,0,0,66,0,0,0,0,0,0,12,1,0,0,0,0,0,'Shadow Warden - list B - face stored target (src id 1 cast 42716 - DROPPED, spell missing)'),
(5280401,9,2,0,0,0,100,0,2000,2000,0,0,33,3652815,0,0,0,0,0,18,20,0,0,0,0,0,'Shadow Warden - list B - KILL CREDIT 3652815 to closest player 20yd (was raw 52815)'),
(5280401,9,3,0,0,0,100,0,0,0,0,0,1,4,0,0,0,0,0,1,0,0,0,0,0,0,'Shadow Warden - list B - say text 4'),
(5280401,9,4,0,0,0,100,0,0,0,0,0,41,8000,0,0,0,0,0,1,0,0,0,0,0,0,'Shadow Warden - list B - despawn in 8s');

-- 1c-bis. DC ADAPTATION for 29192 -- a grant that does not need the lost item spell.
-- The quest asks for a Druid of the Flame to be taken alive; the only live entity
-- that represents one is 3654343 Druid of the Flame (cloned, AIName SmartAI,
-- 3 source rows at ids 0-2). A high id (90) is used so it can never collide with
-- a source-derived row. NOTE: 3654343 currently has ZERO spawns on map 861, so
-- this rule is inert until it is placed -- quest 29142 needs that spawn too.
DELETE FROM acore_world.smart_scripts WHERE `entryorguid` = 3654343 AND `source_type` = 0 AND `id` = 90;

INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT 3654343,0,90,0,6,0,100,0,0,0,0,0,33,3652815,0,0,0,0,0,18,40,0,0,0,0,0,'DC ADAPTATION q29192 - Druid of the Flame death grants Captured Druid credit 3652815'
WHERE EXISTS (SELECT 1 FROM acore_world.creature_template WHERE `entry` = 3654343)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template WHERE `entry` = 3652815);

-- ----------------------------------------------------------------------
-- 1d. Quest 29249 "Planting Season" -> 3653084 Summon Lashling credit (x1)
--
-- RETAIL MECHANISM FOUND: the quest hands out StartItem 69675 "Dried Acorn"
-- (verified on quest_template) and the player plants it at the graveyard soil.
-- The plant action is the item's own use-spell -- and item 69675 has
-- spellid_1..5 = 0 in BOTH nelt_world and acore_world, because Cata moved item
-- spell wiring into the ItemEffect DB2 which was not downported. There is NO
-- SmartAI, no spell and no loot anywhere in either source that names 53084.
-- The only portable artefact is GO 208535 "Dried Acorn" (type 2 questgiver),
-- which 16_ clones as 3808535.
--
-- IMPLEMENTED (DC ADAPTATION, not retail): SmartAI on the cloned GO -- using it
-- grants the credit to the user. Requires AIName SmartGameObjectAI on the
-- template, set below. Both statements are EXISTS-guarded on 16_ having run.
-- ----------------------------------------------------------------------
UPDATE acore_world.gameobject_template gt
SET gt.`AIName` = 'SmartGameObjectAI'
WHERE gt.`entry` = 3808535
  AND gt.`AIName` = '';

DELETE FROM acore_world.smart_scripts WHERE `entryorguid` = 3808535 AND `source_type` = 1;

INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT 3808535,1,0,0,64,0,100,0,0,0,0,0,33,3653084,0,0,0,0,0,7,0,0,0,0,0,0,'DC ADAPTATION q29249 - using the Dried Acorn GO grants Summon Lashling credit 3653084'
WHERE EXISTS (SELECT 1 FROM acore_world.gameobject_template WHERE `entry` = 3808535)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template  WHERE `entry` = 3653084);

-- ----------------------------------------------------------------------
-- 1e. Quest 29299 "Some Like It Hot" -> 3653263 Ember Pool credit (x6)
--
-- RETAIL MECHANISM FOUND: none that is portable. The retail chain is
--   Emberspit Scorpion 53240 spews an ember pool (a Cata spell) -> the summoned
--   pool spawns the helper NPCs 53256 "Ember Pool Bunny" / 53387 "Ember Pool
--   Pulse" / 53388 "Ember Pool Pulse Pre-Load" -> the escorted Crimson Lasher
--   drinks -> credit 53263. NONE of 53256/53263/53387/53388 has a single
--   smart_scripts row in nelt_world or cata_world, and none of them has a spawn;
--   the whole loop lived in the pool spell + a C++/DB2 side that was not ported.
--   Portable anchor: Emberspit Scorpion is LIVE as 3653240 with 24 spawns at the
--   Magma Springs -- exactly the mob the quest text names.
--
-- IMPLEMENTED (DC ADAPTATION, not retail): killing an Emberspit Scorpion grants
-- one Ember Pool credit, so the daily reads as "kill 6 Emberspit Scorpions".
-- 3653240 has no smart_scripts of its own and is not touched by 16_, so id 90 is
-- used and AIName is set.
-- ----------------------------------------------------------------------
UPDATE acore_world.creature_template ct
SET ct.`AIName` = 'SmartAI'
WHERE ct.`entry` = 3653240
  AND ct.`AIName` = ''
  AND ct.`ScriptName` = '';

DELETE FROM acore_world.smart_scripts WHERE `entryorguid` = 3653240 AND `source_type` = 0 AND `id` = 90;

INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT 3653240,0,90,0,6,0,100,0,0,0,0,0,33,3653263,0,0,0,0,0,18,40,0,0,0,0,0,'DC ADAPTATION q29299 - Emberspit Scorpion death grants Ember Pool credit 3653263'
WHERE EXISTS (SELECT 1 FROM acore_world.creature_template WHERE `entry` = 3653263);

-- ----------------------------------------------------------------------
-- 1f. Quest 29297 "Bye Bye Burdy" -> 3653251 bird-form credit (x3)
--
-- RETAIL MECHANISM FOUND: the quest hands out StartItem 69832 "Burd Sticker"
-- (Damek's harpoon, verified on quest_template) and the player shoots the
-- fire-crow-form druids out of the sky. Same dead end as 1d: item 69832 has
-- spellid_1..5 = 0 in both source DBs. No SmartAI, spell or loot names 53251.
-- Portable anchors: the Wildflame Point birds are live as 3652660 "Fire Hawk"
-- (9 spawns) and 3653245 "Fire Hawk" (3 spawns).
--
-- IMPLEMENTED (DC ADAPTATION, not retail): killing either Fire Hawk grants one
-- credit. Neither entry has any smart_scripts and neither is touched by 16_.
-- ----------------------------------------------------------------------
UPDATE acore_world.creature_template ct
SET ct.`AIName` = 'SmartAI'
WHERE ct.`entry` IN (3652660,3653245)
  AND ct.`AIName` = ''
  AND ct.`ScriptName` = '';

DELETE FROM acore_world.smart_scripts WHERE `entryorguid` IN (3652660,3653245) AND `source_type` = 0 AND `id` = 90;

INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT v.e,0,90,0,6,0,100,0,0,0,0,0,33,3653251,0,0,0,0,0,18,40,0,0,0,0,0,'DC ADAPTATION q29297 - Fire Hawk death grants bird-form credit 3653251'
FROM (SELECT 3652660 AS e UNION ALL SELECT 3653245) v
WHERE EXISTS (SELECT 1 FROM acore_world.creature_template WHERE `entry` = 3653251);

-- ----------------------------------------------------------------------
-- 1g. Quest 29201 "Through the Gates of Hell" -> 3653370 Foothold credit (x1)
--
-- RETAIL MECHANISM FOUND: Obsidian Slaglord 53381, event 6 (JUST_DIED),
-- action 33 KILL_CREDIT 53370, target 18 (closest player 59yd) -- present in
-- nelt_world. 53381 is NOT cloned here and is NOT in 16_'s list, so that rule
-- cannot be ported.
--
-- ALSO FIXED HERE: quest 29201's objective still names the RAW 53370 while 16_
-- clones the proxy as 3653370 -- the same defect class 13_ fixed for seven other
-- dailies. Guarded on the current raw value and on the clone existing.
--
-- IMPLEMENTED (DC ADAPTATION, not retail): the credit proxy itself is spawned at
-- the Molten Front base camp (the coordinates are copied verbatim from the live
-- Malfurion Stormrage spawn, i.e. real data, nothing invented) as a fully
-- non-interactive trigger, and given an out-of-combat-LOS rule that hands the
-- foothold credit to anyone who arrives. That matches the quest's intent --
-- "we shall ensure that our foothold is secure" once through the portal.
-- ----------------------------------------------------------------------
UPDATE acore_world.quest_template q
SET q.`RequiredNpcOrGo1` = q.`RequiredNpcOrGo1` + @OFF
WHERE q.`ID` = 29201
  AND q.`RequiredNpcOrGo1` = 53370
  AND EXISTS (SELECT 1 FROM acore_world.creature_template ct WHERE ct.`entry` = 3653370);

-- ----------------------------------------------------------------------
-- 1h. Quest 29210 "Enduring the Heat" slot 1 -> 3653886 Igneous Depths Area Credit
--
-- RETAIL MECHANISM FOUND: a sub-area enter trigger. This CANNOT be reproduced on
-- this fork: the whole of map 861 reports a single area id (4925), so there is no
-- Igneous Depths area to enter. 53886 has no spawn, no SmartAI and no spell in
-- either source DB -- it is a pure area-credit shell.
--
-- IMPLEMENTED (DC ADAPTATION, not retail): 53886 IS a spawnable trigger shell, so
-- it is placed as a proximity trigger at the eastern edge of the Magma Springs --
-- the quest text puts the cavern entrance "east of the Magma Springs", and the
-- coordinates are copied verbatim from the easternmost live Emberspit Scorpion
-- spawn (guid 15300937) rather than invented. Walking up to it grants the credit.
--
-- OPEN GAP (NOT fixed here, flagged deliberately): quest 29210 slot 2 needs
-- 3652891 "Flame Runes Extinguished Credit", which has no live spawn and whose
-- retail source is the eight blue runes inside the cavern. Those rune GOs were
-- never ported, so 29210 stays incomplete until they are. Fabricating a second
-- proximity trigger for it would make the quest turn in without the content.
-- ----------------------------------------------------------------------
DELETE FROM acore_world.creature WHERE `guid` BETWEEN 15350000 AND 15359999;

-- unit_flags 33555202 = NON_ATTACKABLE | IMMUNE_TO_PC | IMMUNE_TO_NPC | NOT_SELECTABLE
INSERT INTO acore_world.creature
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT v.guid, v.id, 861, 4925, 4925, 1, 1, -1, v.x, v.y, v.z, v.o, 120, 0, 0, 1, 0, 0, 0, 33555202, 0, '', 0, 0, v.cmt
FROM (
  SELECT 15350001 AS guid, 3653370 AS id, 978.5 AS x, 376.5 AS y, 38.1054 AS z, 0.0 AS o,
         'MoltenFront-17-FootholdCreditTrigger' AS cmt UNION ALL
  SELECT 15350002, 3653886, 1392.74, 362.131, 24.9237, 1.7515,
         'MoltenFront-17-IgneousDepthsAreaTrigger'
) v
WHERE EXISTS (SELECT 1 FROM acore_world.creature_template ct WHERE ct.`entry` = v.id);

UPDATE acore_world.creature_template ct
SET ct.`AIName` = 'SmartAI'
WHERE ct.`entry` IN (3653370,3653886)
  AND ct.`AIName` = ''
  AND ct.`ScriptName` = '';

DELETE FROM acore_world.smart_scripts WHERE `entryorguid` IN (3653370,3653886) AND `source_type` = 0;

-- event 10 = OOC_LOS (param1 1 = react to non-hostile, param2 range, param3/4 cooldown)
INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT v.e,0,0,0,10,0,100,0,1,25,5000,10000,33,v.e,0,0,0,0,0,7,0,0,0,0,0,0,v.cmt
FROM (
  SELECT 3653370 AS e, 'DC ADAPTATION q29201 - proximity trigger grants Foothold credit 3653370' AS cmt UNION ALL
  SELECT 3653886, 'DC ADAPTATION q29210 - proximity trigger grants Igneous Depths area credit 3653886'
) v
WHERE EXISTS (SELECT 1 FROM acore_world.creature_template ct WHERE ct.`entry` = v.e);

-- ======================================================================
-- 2. SPELLHIT FAMILY 99587 / 99707 -- RESEARCHED, LEFT DORMANT
-- ======================================================================
-- WHAT IS THERE: seven mob families carry the branch (all cloned and spawned) --
--   3653308 Flamewaker Centurion, 3653309 Flamewaker Cauterizer,
--   3653310 Molten Lord, 3653469 Flamewaker Incinerator,
--   3653477 Cinderweb Skitterer, 3653478 Cinderweb Clutchkeeper,
--   3653479 Cinderweb Matriarch  (plus 3653718 and the 54252-54257 rare set)
-- each with  event 8 SPELLHIT 99587 -> CALL_TIMED_ACTIONLIST 5331000
--            event 8 SPELLHIT 99707 -> CALL_TIMED_ACTIONLIST 5331000
-- and list 5331000 / 5425200 do exactly one thing: action 86 CROSS_CAST 99589.
--
-- WHAT THE RESEARCH FOUND:
--   * acore_world.spell_dbc HAS 99587 (APPLY_AURA), 99707 (knockback + damage +
--     aura) and 99589 (damage) -- server side is complete.
--   * NOTHING casts 99587 or 99707. Checked: every item_template spellid_1..5 in
--     nelt_world (0 hits); every smart_scripts action in nelt_world and
--     acore_world (0 casters, only the spellhit receivers above);
--     gameobject_template Data fields (0 hits); spell_dbc EffectTriggerSpell (0).
--   * The caster was a Cata quest item. The strongest candidate is 69832
--     "Burd Sticker", the harpoon quest 29297 hands out -- 99707's knockback +
--     damage profile fits a harpoon exactly. But 69832, like every other Molten
--     Front quest item here (69675 Dried Acorn, 69808, 69809, 69845), has
--     spellid_1..5 = 0 in BOTH source DBs, because Cata stores item spells in the
--     ItemEffect DB2 rather than item_template. That mapping did not survive the
--     downport, so there is nothing to port.
--
-- DECISION: leave the branches dormant. Nothing is fabricated here -- guessing
-- which item casts which spell would risk wiring a harpoon onto the wrong daily.
--
-- DESIGN NOTE / RECOMMENDATION (needs a decision, then a follow-up file):
--   Option A (data only, cheapest): wire the use-spell onto the quest item, e.g.
--     UPDATE item_template SET spellid_1=99707, spelltrigger_1=0 WHERE entry=69832
--   plus a spell_script_target / conditions row limiting it to the seven mob
--   families. !! CLIENT PREREQUISITE: 99587 / 99707 / 99589 / 98914 / 98915 /
--   98916 are ALL ABSENT from the client's Custom/CSV DBC/Spell.csv (verified,
--   0 hits each). A player-castable item spell with no client Spell.dbc row
--   cannot be used at all -- those six rows must be added to Spell.csv and the
--   DBC repacked BEFORE option A does anything. No CSV was edited by this file.
--   Option B: a small C++ SpellScript in src/server/scripts/DC/ that grants the
--   quest items directly on mob death, sidestepping the client DBC entirely.
--   Option B needs no client patch and is the safer route for a live realm.
--
-- (The same client-DBC gap applies to 98914/98915, which is why section 1c's
--  action lists are correct infrastructure but still need 1c-bis to be playable.)

-- ======================================================================
-- 3. ITEMS WITH NO OBTAIN PATH
-- ======================================================================
-- 3a. 69808 "Flame Venom" -- quest 29276 "The Flame Spider Queen", 8 required.
--     RESEARCH: real, portable path found. nelt_world.creature_loot_template has
--     entry 52648 (Cinderweb Creeper) -> item 69808, ChanceOrQuestChance -65
--     (negative = quest-required drop), count 1. Live 3652648 uses the RAW
--     lootid 52648 (map-861 convention) and has 5 rows -- but 69808 was dropped
--     on import because the item shell did not exist yet. 24 live spawns.
--     IMPLEMENTED: the source row, converted to this fork's loot schema
--     (QuestRequired=1, Chance=65).
--     Cross-checked slot 2: 69809 "Searing Web Fluid" is ALREADY wired
--     (nelt entry 52981 -> live 3652981 Cinderweb Spinner, lootid 52981,
--     66 spawns, row present). No action needed there.
DELETE FROM acore_world.creature_loot_template WHERE `Entry` = 52648 AND `Item` = 69808;

INSERT INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 52648, 69808, 0, 65, 1, 1, 0, 1, 1
WHERE EXISTS (SELECT 1 FROM acore_world.item_template      WHERE `entry` = 69808)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template  WHERE `lootid` = 52648);

-- 3b. 69845 "Fire Hawk Hatchling" -- quest 29288 "Starting Young", 5 required.
--     RESEARCH: the retail path IS in the sources, but its anchor is missing here.
--       * creature 53275 "Fire Hawk Hatchling" carries SmartAI
--           event 73 (ON_SPELLCLICK) -> action 81, linked -> action 41 (despawn)
--       * nelt_world.npc_spellclick_spells: npc_entry 53275, spell_id 98725,
--         cast_flags 2  -- i.e. you spellclick the docile hatchling, it vanishes
--         and you receive the item. That matches the quest text exactly.
--       * No loot row for 69845 exists anywhere (nelt or cata), so the item is
--         handed over by spell 98725, not by looting.
--     BLOCKER: creature 53275 is NOT cloned (3653275 does not exist) and has no
--     spawns, and it is not in 16_'s clone list. Spell 98725 is likewise absent
--     from acore_world.spell_dbc. Wiring npc_spellclick_spells to a non-existent
--     NPC and a non-existent spell would ship two boot errors, so nothing is
--     written here.
--     RECOMMENDATION: clone 53275 (+ its two SmartAI rows, param-swept), spawn it
--     around Wildflame Point, and then EITHER port spell 98725 into spell_dbc and
--     add the npc_spellclick_spells row, OR (simpler, no client DBC needed)
--     give the clone SmartAI: event 73 ON_SPELLCLICK -> action 6 (ADD_ITEM 69845)
--     -> action 41 despawn. Flagged rather than guessed.

-- ======================================================================
-- POST-APPLY GUARD QUERIES (run manually after a restart; comments only)
-- ======================================================================
-- 1) Vehicle guard -- every VehicleId referenced by a map-861 clone must have a
--    vehicle_dbc row, or the client freezes on boarding:
--    SELECT DISTINCT ct.entry, ct.name, ct.VehicleId
--    FROM acore_world.creature_template ct
--    JOIN acore_world.creature c ON c.id = ct.entry AND c.map = 861
--    WHERE ct.VehicleId > 0
--      AND NOT EXISTS (SELECT 1 FROM acore_world.vehicle_dbc v WHERE v.ID = ct.VehicleId);
--
-- 2) Dangling KillCredit check -- after section 1a/1b every KillCredit must point
--    at a template that actually exists (52816 raw is EXPECTED and legitimate,
--    see 1a; anything else in the 40000-60000 band is a missed offset):
--    SELECT ct.entry, ct.name, ct.KillCredit1, ct.KillCredit2
--    FROM acore_world.creature_template ct
--    WHERE (ct.KillCredit1 > 0 AND NOT EXISTS
--             (SELECT 1 FROM acore_world.creature_template x WHERE x.entry = ct.KillCredit1))
--       OR (ct.KillCredit2 > 0 AND NOT EXISTS
--             (SELECT 1 FROM acore_world.creature_template x WHERE x.entry = ct.KillCredit2));
--
-- 3) Credit reachability -- every map-861 quest objective should be granted by
--    something. Expect only 3652891 (see 1h) to come back empty:
--    SELECT q.ID, q.LogTitle, q.RequiredNpcOrGo1
--    FROM acore_world.quest_template q
--    WHERE q.RequiredNpcOrGo1 > 3600000
--      AND NOT EXISTS (SELECT 1 FROM acore_world.creature c WHERE c.id = q.RequiredNpcOrGo1)
--      AND NOT EXISTS (SELECT 1 FROM acore_world.creature_template ct
--                      WHERE ct.KillCredit1 = q.RequiredNpcOrGo1 OR ct.KillCredit2 = q.RequiredNpcOrGo1)
--      AND NOT EXISTS (SELECT 1 FROM acore_world.smart_scripts ss
--                      WHERE ss.action_type = 33 AND ss.action_param1 = q.RequiredNpcOrGo1);
