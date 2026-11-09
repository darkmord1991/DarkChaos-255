-- ===========================================================================
-- HyjalCata r49a -- Darkshore (map 750): turn-in texts, quest starters, the
-- 13518 survivors and the three Great Spirits.
--
-- From the BFA-HavenCore Darkshore comparison of 2026-11-09. HavenCore fixed
-- the same symptoms on BfA; the data here comes from our own reference DBs:
--   * TC_Cata_world (Cata Classic 4.4.2) for the texts -- cata_world and
--     bfa_world have none of them;
--   * nelt_world for spawns, addons and the Item-sparse StartQuestID values.
--
-- APPLY ORDER: Item.dbc with the new 44927 row must be on the SERVER before
-- this file is loaded, or ObjectMgr silently drops item 44927 (section C2).
-- Everything else here has no DBC dependency. Spell-dependent rows (spirit
-- blessings, clicks, cages, Withered Ent) are in the r49b file.
--
-- Re-runnable: every id list is pinned, spawns use their own guid block.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A) quest_offer_reward -- 71 of the 73 map-750 Darkshore quests that have no
--    turn-in text. 13537 and 26383 have none in any reference DB either.
-- ---------------------------------------------------------------------------
-- (Emote columns are signed in TC, unsigned here; all 71 source rows are >= 0.)
DELETE FROM `quest_offer_reward` WHERE `ID` IN (13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513, 13514, 13515, 13519, 13520, 13522, 13523, 13525, 13526, 13527, 13529, 13544, 13545, 13546, 13554, 13557, 13560, 13561, 13562, 13563, 13564, 13565, 13566, 13567, 13568, 13569, 13570, 13572, 13578, 13582, 13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13831, 13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896, 13897, 13898, 13899, 13900, 13907, 13909, 13910, 13911, 13912, 13918, 13925, 13948, 13953, 28529);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT `ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`
FROM `TC_Cata_world`.`quest_offer_reward`
WHERE `ID` IN (
  13504, 13505, 13506, 13507, 13508, 13509, 13510, 13511, 13512, 13513, 13514, 13515,
  13519, 13520, 13522, 13523, 13525, 13526, 13527, 13529, 13544, 13545, 13546, 13554,
  13557, 13560, 13561, 13562, 13563, 13564, 13565, 13566, 13567, 13568, 13569, 13570,
  13572, 13578, 13582, 13589, 13590, 13591, 13596, 13597, 13598, 13599, 13601, 13831,
  13844, 13881, 13882, 13885, 13891, 13892, 13893, 13895, 13896, 13897, 13898, 13899,
  13900, 13907, 13909, 13910, 13911, 13912, 13918, 13925, 13948, 13953, 28529);

-- ---------------------------------------------------------------------------
-- B) quest_request_items -- the 4 quests with a progress step but no text.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_request_items` WHERE `ID` IN (13506, 13569, 13591, 28529);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT `ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`
FROM `TC_Cata_world`.`quest_request_items`
WHERE `ID` IN (13506, 13569, 13591, 28529);

-- ---------------------------------------------------------------------------
-- C1) Quest-starting items. 189_ imported these from Item.db2, which has no
--     StartQuestID, so all three dropped but could never start their quest.
--     The fourth DB-wide case, 3082 Dargol's Skull -> 25030, is deliberately
--     left alone: 3082 is a stock Tirisfal item and 25030 the Cata "Haunted
--     Mills" -- a Cata quest must not be bolted onto stock content.
-- ---------------------------------------------------------------------------
UPDATE `item_template` SET `startquest` = 13506 WHERE `entry` = 44979;  -- Overseer's Orders
UPDATE `item_template` SET `startquest` = 13591 WHERE `entry` = 46318;  -- Hellscream's Missive
UPDATE `item_template` SET `startquest` = 28529 WHERE `entry` = 64450;  -- Writings of the Dark Herald

-- ---------------------------------------------------------------------------
-- C2) 44927 Corruptor's Master Key -- the item that STARTS 13557 "Bearer of
--     Good Fortune". It never existed here (44925, the key handed out on
--     accept, did). Cloned from 44925 with the Item-sparse differences:
--     quest class, BoP, unique, no use-spell, StartQuestID 13557.
--     NEEDS the Item.dbc row 44927 on the server -- see the header.
--     REPLACE INTO rather than DELETE + INSERT: the SQL codestyle forbids
--     DELETE on item_template, and REPLACE keeps the file re-runnable.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_r49_item_44927`;
CREATE TEMPORARY TABLE `tmp_r49_item_44927` SELECT * FROM `item_template` WHERE `entry` = 44925;
UPDATE `tmp_r49_item_44927` SET `entry` = 44927, `class` = 12, `subclass` = 0, `Flags` = 2048, `bonding` = 1, `maxcount` = 1, `BagFamily` = 0, `startquest` = 13557, `spellid_1` = 0, `spelltrigger_1` = 0, `spellcharges_1` = 0, `spellcooldown_1` = -1, `spellcategory_1` = 0, `spellcategorycooldown_1` = -1, `description` = '';
REPLACE INTO `item_template` SELECT * FROM `tmp_r49_item_44927`;
DROP TEMPORARY TABLE `tmp_r49_item_44927`;

-- C3) Its drops, as in nelt_world: Vile Corruptor 60 %, Zenn Foulhoof 30 %.
-- Not quest-gated -- it is the item that starts the quest (HavenCore had to
-- remove the very same QuestRequired gate on BfA).
DELETE FROM `creature_loot_template` WHERE `Entry` IN (3733020, 3733022) AND `Item` = 44927;
INSERT INTO `creature_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`) VALUES
(3733022, 44927, 0, 60, 0, 1, 0, 1, 1, 'Vile Corruptor - Corruptor''s Master Key (starts 13557)'),
(3733020, 44927, 0, 30, 0, 1, 0, 1, 1, 'Zenn Foulhoof - Corruptor''s Master Key (starts 13557)');

-- ---------------------------------------------------------------------------
-- D) 13518 "The Last Wave of Survivors" -- the four survivors.
--    In nelt_world they are phaseMask 2 spawns, a layer 184_ (which read
--    cata_world) never saw, so the quest had nobody to rescue. Spawned here in
--    phase 1, always visible. Wounded pose and root as in nelt; the npc_text
--    rows 14297-14300 already exist, only the gossip_menu links were missing.
--    Credit: opening the gossip, exactly as nelt's SmartAI does it.
-- ---------------------------------------------------------------------------
DELETE FROM `gossip_menu` WHERE (`MenuID`, `TextID`) IN ((10293, 14297), (10294, 14298), (10295, 14299), (10296, 14300));
INSERT INTO `gossip_menu` (`MenuID`,`TextID`) VALUES
(10293, 14297), (10294, 14298), (10295, 14299), (10296, 14300);

DELETE FROM `creature_template_addon` WHERE `entry` IN (3732911, 3733093, 3733094, 3733095);
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(3732911, 0, 0, 7, 1, 0, 0, '42716'),
(3733093, 0, 0, 7, 1, 0, 0, '42716'),
(3733094, 0, 0, 7, 1, 0, 0, '42716'),
(3733095, 0, 0, 7, 1, 0, 0, '42716');

UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` IN (3732911, 3733093, 3733094, 3733095);

DELETE FROM `smart_scripts` WHERE `entryorguid` IN (3732911, 3733093, 3733094, 3733095) AND `source_type` = 0;
INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(3732911, 0, 0, 0, 64, 0, 100, 0, 0, 0, 0, 0, 33, 3732911, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Gershala Nightwhisper - On Gossip Hello - Quest Credit (13518)'),
(3733093, 0, 0, 0, 64, 0, 100, 0, 0, 0, 0, 0, 33, 3733093, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Cerellean Whiteclaw - On Gossip Hello - Quest Credit (13518)'),
(3733094, 0, 0, 0, 64, 0, 100, 0, 0, 0, 0, 0, 33, 3733094, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Volcor - On Gossip Hello - Quest Credit (13518)'),
(3733095, 0, 0, 0, 64, 0, 100, 0, 0, 0, 0, 0, 33, 3733095, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Shaldyn - On Gossip Hello - Quest Credit (13518)');

-- ---------------------------------------------------------------------------
-- E) The three Great Spirits (13567 Stag / 13568 Moonstalker / 13597 Thistle
--    Bear). Same story: nelt phaseMask 2, so never imported; the quests had
--    enders but no NPC to stand in for them and no starter at all.
--    Cata showed them through a trance (64198, a PHASE aura) during 13569
--    "The Ritual Bond". Without phasing they are spawned visible and gated by
--    the quest chain instead: PrevQuestID -13569 = only while The Ritual Bond
--    is in the log; ExclusiveGroup 13568 = only one spirit can be chosen
--    (both as in bfa_world, which gates by phase).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_addon` WHERE `entry` IN (3733131, 3733132, 3733133);
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(3733131, 0, 0, 3, 1, 0, 0, NULL),
(3733132, 0, 0, 0, 1, 0, 0, NULL),
(3733133, 0, 0, 0, 1, 0, 0, NULL);

DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3733131, 13568), (3733132, 13597), (3733133, 13567));
INSERT INTO `creature_queststarter` (`id`,`quest`) VALUES
(3733131, 13568), (3733132, 13597), (3733133, 13567);

UPDATE `quest_template_addon` SET `PrevQuestID` = -13569, `ExclusiveGroup` = 13568 WHERE `ID` IN (13567, 13568, 13597);

-- ---------------------------------------------------------------------------
-- F) Spawns for D and E. Positions are nelt's map-1 coordinates verbatim --
--    map 750 keeps the Kalimdor coordinate space. Own guid block 9025000+
--    (checked empty in creature and creature_addon on 2026-11-09, below the
--    16,777,215 spawn-id cap).
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9025000 AND 9025006 AND `id` IN (3732911, 3733093, 3733094, 3733095, 3733131, 3733132, 3733133) AND `map` = 750;
INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9025000, 3732911, 750, 0, 0, 1, 1, 0, 7455.9,  164.987, 2.81793,  5.96903, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - 13518 survivor (nelt phase 2)'),
(9025001, 3733093, 750, 0, 0, 1, 1, 0, 7365.81, 134.712, 11.7647,  2.96706, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - 13518 survivor (nelt phase 2)'),
(9025002, 3733094, 750, 0, 0, 1, 1, 0, 7439.78, 105.866, 0.273638, 6.21584, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - 13518 survivor (nelt phase 2)'),
(9025003, 3733095, 750, 0, 0, 1, 1, 0, 7294.86, 242.627, 1.86917,  5.7989,  300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - 13518 survivor (nelt phase 2)'),
(9025004, 3733131, 750, 0, 0, 1, 1, 0, 6491.19, 250.34,  6.02786,  2.47837, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - Great Moonstalker Spirit (nelt phase 2)'),
(9025005, 3733132, 750, 0, 0, 1, 1, 0, 6561.43, 272.294, 11.2011,  3.22886, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - Great Thistle Bear Spirit (nelt phase 2)'),
(9025006, 3733133, 750, 0, 0, 1, 1, 0, 6482.4,  205.913, 4.97718,  2.07808, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r49 - Great Stag Spirit (nelt phase 2)');
